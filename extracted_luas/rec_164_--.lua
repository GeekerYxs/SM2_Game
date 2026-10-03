-- ================================================================
-- 寄售-主对话框
-- ================================================================

local dlgbuilder   = require "dlg_builder"
local ScriptEvent  = require "script_event"
local idParseTool  = require "id_parse_tool"

local struct       = require "uiconsignment_struct"
local prefix_path  = "UIGame/UIConsignmentMain"

local Config       = require "ui.dlgs.consignment.ConsignmentConfig"
local Data         = require "ui.dlgs.consignment.consignment_data"
local network      = require "ui.dlgs.consignment.consignment_network"
local validators   = require "ui.dlgs.consignment.consignment_validators"
local uiUpdater    = require "ui.dlgs.consignment.consignment_ui_updater"
local dialogManager= require "ui.dlgs.consignment.consignment_dialog_manager"
local ErrorHandler = require "ui.dlgs.consignment.consignment_error_handler"
local ErrorCode    = require "ui.dlgs.consignment.ConsignmentErrorCode"
local Strings      = require "ui.dlgs.consignment.consignment_strings"
local NotifyRender = require "ui.dlgs.consignment.consignment_notify_render"
local Pacer        = require "ui.dlgs.consignment.consignment_request_pacer"
local events       = require "events"

-- 中文文案集中在 consignment_strings.lua（S.MAIN），此处取本地别名，正文保持不变
local T = Strings.MAIN
local MSG_ITEM_NOT_FOUND      = T.MSG_ITEM_NOT_FOUND
local MSG_SEARCH_TOO_SHORT    = T.MSG_SEARCH_TOO_SHORT
local MSG_SEARCH_NO_RESULT    = T.MSG_SEARCH_NO_RESULT
local MSG_APPLY_SUCCESS_FMT   = T.MSG_APPLY_SUCCESS
local MSG_BUY_SUCCESS         = T.MSG_BUY_SUCCESS
-- local MSG_CANCEL_SUCCESS      = T.MSG_CANCEL_SUCCESS
-- local MSG_CLAIM_ITEM_FMT      = T.MSG_CLAIM_ITEM
-- local MSG_CLAIM_YB_FMT        = T.MSG_CLAIM_YB
-- local MSG_CLAIM_REFUND_YB_FMT = T.MSG_CLAIM_REFUND_YB
local MSG_SYSTEM_CLOSED       = T.MSG_SYSTEM_CLOSED
local MSG_REQUEST_TOO_FAST    = T.MSG_REQUEST_TOO_FAST
local MSG_REFRESH_SUCCESS     = T.MSG_REFRESH_SUCCESS
local TIP_ORDER_ID_FMT        = T.TIP_ORDER_ID
local TIP_BTN_SEARCH          = T.TIP_BTN_SEARCH
local TIP_BTN_REFRESH         = T.TIP_BTN_REFRESH
local TIP_BTN_ADD             = T.TIP_BTN_ADD

local _dlg = nil
local _sortDropdownOpen = false
-- 用户从下拉里选了新排序、但还没按“搜索”按钮提交时存在这里。
-- 提交（applySearch）→ 写回 Data.SetSort 并清空；
-- 任何 refreshList / 切页签 / 重开对话框 → 丢弃。
local _draftSort = nil

-- ----------------------------------------------------------------
-- 玩家主动点「刷新」按钮的待确认标记：刷新请求发出后置 true，对应的
-- ListQueryResult 回包到达时弹"刷新成功"并清除（成功 / 失败都清，失败
-- 时不弹成功、由错误提示兜底）。列表常处于无变化状态，玩家会误以为没点
-- 上而连点，靠这条确认给出明确反馈。
-- 只在「刷新」按钮置位——切页签 / 翻页 / 搜索 / 动作后自动刷新都不置位，
-- 避免在那些场景误弹"刷新成功"。
local _pendingRefreshToast = false

-- ----------------------------------------------------------------
-- 玩家主动点「搜索」按钮的待确认标记：实际下发了过滤条件后置 true，对应的
-- ListQueryResult 回包到达时，若结果为空则提示"未找到相关寄售品"，非空静默；
-- 无论空非空都仅消费一次。只在 applySearch 真正应用了搜索过滤处置位——
-- 清空搜索 / 翻页 / 切页签 / 刷新 / 动作后自动刷新都不置位，避免在那些场景误弹。
local _pendingSearchToast = false

-- ----------------------------------------------------------------
-- 门禁闩锁（系统熔断 / 每日打烊 / 账号被拉黑）。
-- 这三种“门禁”状态下整个寄售功能不可用，服务端会拒绝一切寄售协议。玩家可能在
-- 界面【已经打开】的情况下才进入这些状态，此后停留在一个用不了的界面上没有意义
-- ——一旦判定进入门禁态，就直接关掉主界面 + 所有子对话框并置闩锁；闩锁期间界面里
-- 的任何点击都再次触发关闭（兜底）。
--
-- 置位来源（两条，互为兜底）：
--   ① Consignment_SystemClosed 推送 —— 熔断 / 打烊 / 拉黑的服务端主动通知，
--      按 obj.reason(Config.CloseReason) 选提示文案后关界面（拉黑只推被拉黑账号在线角色）；
--   ② 任一业务回包带门禁错误码（1001/1002/1003）—— 玩家在打烊/拉黑期间点了需要
--      请求服务端的操作，回包即触发关闭。
-- 复位：下次重新打开主界面（onShow show=true）时清零，开始一次全新会话。
-- ----------------------------------------------------------------
local _forceClose = false

-- 门禁错误码集合：熔断(1001) / 打烊(1002) / 拉黑(1003)。
local GATE_ERROR_CODES = {
    [ErrorCode.E_SYSTEM_CLOSED]    = true,
    [ErrorCode.E_IN_DAILY_CLOSE]   = true,
    [ErrorCode.E_PLAYER_BLACKLIST] = true,
}

-- 直接关掉主界面 + 所有子对话框，并置门禁闩锁。
local function forceCloseAll(luadlg)
    _forceClose = true
    -- 丢弃所有待发的系统刷新：界面都关了，排队中的刷新没有意义。
    Pacer.Clear()
    if luadlg and luadlg.Raw then
        luadlg.Raw:ShowDlg(false)
    end
    dialogManager.CloseAllSubDialogs()
end

-- 业务回包门禁判定：ret=false 且带门禁错误码时，提示原因并直接关界面。
-- 命中返回 true（调用方据此 return，不再走各自的常规失败逻辑）。
local function consumeGateRejection(luadlg, obj)
    if obj.ret == false and GATE_ERROR_CODES[obj.errCode] then
        ErrorHandler.ShowError(obj.errCode, obj)
        forceCloseAll(luadlg)
        return true
    end
    return false
end

-- ----------------------------------------------------------------
-- 玩家主动浏览操作本地冷却：搜索 / 翻页 / 刷新 / 首次切页签 四者共用一个冷却（防连点）。
-- 时长读 Config.BROWSE_COOLDOWN_SEC，统一由 Pacer 计时——与「系统自动刷新」排队队列
-- 共用同一个冷却基准（服务端 list 查询与通知翻页共用同一个节流桶）。
-- 这里只做「玩家主动点击」的预判：冷却未过一律提示"请求间隔过短"并拒绝，不入队
-- （避免把玩家的连点全堆进队列里事后补发）。动作完成 / 通知推送触发的自动刷新
-- 走 Pacer.Enqueue 排队，不走这里。真正发包时由各发包函数 Pacer.Mark() 打点。
-- ----------------------------------------------------------------
local function passBrowseCooldown()
    if Pacer.Ready() then return true end
    game:ShowMessage("#d60000#" .. MSG_REQUEST_TOO_FAST)
    return false
end

-- ----------------------------------------------------------------
-- 搜索框占位提示：搜索框为空时显示 txtSearchPlacehold（“输入物品名”），
-- 有输入时隐藏。该控件 enable=0（见 createDlg），点击会穿透到下面的
-- 输入框，不影响搜索框自身的事件。
-- knownText 已知时直接传入，省去一次 GetInputText 回读；否则实时读取
-- 输入框内容判断。
-- ----------------------------------------------------------------
local function updateSearchPlaceholder(knownText)
    if not (_dlg and _dlg.Search and _dlg.Search.txtSearchPlacehold) then return end
    local txt = knownText
    if txt == nil then
        if _dlg.Search.editSearch then
            txt = _dlg.Search.editSearch:GetInputText() or ""
        else
            txt = ""
        end
    end
    _dlg.Search.txtSearchPlacehold:SetVisible((txt == "") and 1 or 0)
end

-- ----------------------------------------------------------------
-- 把搜索输入框同步成当前过滤器对应的搜索文本（无过滤则清空）。
-- 每次 refreshList / 切页签都会调用，保证“眼前看到的输入框文字”始终
-- 等于“实际发出去的过滤条件”。模糊匹配下过滤是多个 itemid，无法由
-- itemid 反推名称，所以统一回显玩家原始输入文本（Data.search_text）。
-- ----------------------------------------------------------------
local function syncSearchInputFromFilter()
    if not (_dlg and _dlg.Search and _dlg.Search.editSearch) then return end
    local edit = _dlg.Search.editSearch
    local text = Data.GetSearchText()
    edit:Clear()
    if text and text ~= "" then
        edit:AddString(text)
    end
    updateSearchPlaceholder(text or "")
end

-- ----------------------------------------------------------------
-- 把 itemId 对应的物品名【覆盖式】写入搜索框（右键列表物品图标用）。
-- 只写文字、不触发搜索，玩家可继续编辑后再点搜索。名称取自 ItemLib
-- （与精确匹配同源），保证写进去的名字能被 ResolveItemIdByName 精确命中。
-- ----------------------------------------------------------------
local function writeItemNameToSearch(itemId)
    if not (_dlg and _dlg.Search and _dlg.Search.editSearch) then return end
    if not itemId then return end
    local info = idParseTool.FindItem(itemId)
    local name = info and info.Name
    if not name or name == "" then return end
    local edit = _dlg.Search.editSearch
    edit:Clear()
    edit:AddString(name)
    updateSearchPlaceholder(name)
end

-- ----------------------------------------------------------------
-- 丢弃用户未提交的排序草稿，并把排序标签恢复成 Data 里实际生效的
-- 排序。任何"重新发查询请求 / 切换页签"的入口都应先调一次。
-- ----------------------------------------------------------------
local function discardDraftSort()
    _draftSort = nil
    uiUpdater.UpdateSortLabel()
end

-- ----------------------------------------------------------------
-- 按当前查询参数下发一次 ListQueryRequest（真正发包，发包前 Pacer 打点）。
-- 既用于玩家主动刷新/翻页/搜索/首次切页签（调用方已过 passBrowseCooldown），
-- 也作为 Pacer 队列里 "list" kind 的派发函数（系统自动刷新经 queueListRefresh 入队）。
-- 已主动发了 list，丢弃队列里可能排着的重复 list 项（避免无效重复请求）。
-- ----------------------------------------------------------------
local function refreshList()
    discardDraftSort()
    syncSearchInputFromFilter()
    local q  = Data.GetQuery()
    local pm = q.page_mode
    local req = {
        page_mode = pm,
        page      = q.page,
        -- 排序各页签均下发：在售/即将上架用上架时间/单价/数量(select0~4)+我的订单(select5)，
        -- 我的交易默认分类排序(select6)、也支持上架时间/单价/数量(select0~4)。
        sort      = q.sort,
    }
    if q.item_ids then req.item_ids = q.item_ids end
    if pm == Config.PageMode.MyOrders then
        req.identity = q.identity or Config.Identity.All
    end
    Pacer.Mark()
    Pacer.Drop("list")
    network.SendListQueryRequest(req)
end

-- 通知翻页发包（与 list 查询共用服务端冷却桶，发包前同样 Pacer 打点）。
-- 既用于玩家主动翻通知页，也作为队列里 "notify" kind 的派发函数。
local function sendNotifyPage(page)
    Pacer.Mark()
    Pacer.Drop("notify")
    network.SendNotifyPageRequest(page)
end

-- 队列里 "notify" kind 的派发函数：系统触发时重拉通知首页。
local function refreshNotifyFirstPage()
    sendNotifyPage(1)
end

-- ----------------------------------------------------------------
-- 系统自动刷新入口（动作完成 / 通知推送触发）：不立即发包，入 Pacer 队列按
-- 冷却节流逐个派发，并按 kind 去重（多次触发只保留一份），避免过快/重复请求。
-- ----------------------------------------------------------------
local function queueListRefresh()
    Pacer.Enqueue("list", refreshList)
end

local function queueNotifyFirstPage()
    Pacer.Enqueue("notify", refreshNotifyFirstPage)
end

-- ----------------------------------------------------------------
-- 页签切换辅助函数
-- ----------------------------------------------------------------
local function switchTab(pageMode)
    -- 首次访问该页签需向服务端查询（无缓存→稍后 refreshList）：先过浏览冷却。
    -- 过快则不切换、提示"请求间隔过短"，且不改任何状态（缓存命中的页签只渲染
    -- 本地缓存、不发请求，不受此冷却限制，可自由切换）。
    if not Data.HasTabCache(pageMode) then
        if not passBrowseCooldown() then return end
    end
    -- 离开当前页签时缓存其状态，下次回到此页签时无需重新查询。
    Data.SaveCurrentTabCache()

    local hadCache = Data.RestoreTabCache(pageMode)
    if not hadCache then
        -- 首次访问该页签：使用干净状态，稍后向服务端查询。
        Data.SetPageMode(pageMode)
    end

    _sortDropdownOpen = false
    uiUpdater.SetSortDropdownVisible(0)
    -- 切页签时丢弃未提交的排序草稿
    _draftSort = nil
    uiUpdater.UpdateTabs()
    uiUpdater.UpdateSortLabel()

    if hadCache then
        -- 之前查询过：直接渲染缓存。
        -- 搜索框同步成此页签缓存里的 item_id 对应的名字（缓存未命中
        -- 路径会经由 refreshList 内部完成同步）。
        syncSearchInputFromFilter()
        uiUpdater.RefreshList()
    else
        -- 首次访问：主动查询。
        refreshList()
    end
end

-- ----------------------------------------------------------------
-- 搜索按钮：把物品名称解析成 item_id，并把"草稿排序"一并提交，
-- 然后重新查询。
-- ----------------------------------------------------------------
local function applySearch()
    if not _dlg or not _dlg.Search then return end
    local txt = ""
    if _dlg.Search.editSearch then
        txt = _dlg.Search.editSearch:GetInputText() or ""
    end
    if txt == "" then
        Data.ClearSearchFilter()
    else
        local itemId = validators.ResolveItemIdByName(txt)
        if itemId then
            -- 精确匹配到：按单个 itemid 过滤
            Data.SetSearchFilter({ itemId }, txt)
        else
            -- 精确匹配不到：回退“只要包含即可”模糊匹配。回退前先拦截过短输入
            -- （GBK 下需 ≥4 字节 = 2 个中文），避免过短关键字匹配过多物品。
            if not validators.IsSearchTextLongEnoughForFuzzy(txt) then
                game:ShowMessage("#d60000#" .. MSG_SEARCH_TOO_SHORT)
                return
            end
            -- 模糊匹配命中过多时只取 ItemLib 前面匹配的 MAX_SEARCH_ITEM_IDS 个
            local ids = validators.ResolveItemIdsByNameFuzzy(txt)
            if not ids or #ids == 0 then
                game:ShowMessage("#d60000#" .. MSG_ITEM_NOT_FOUND)
                return
            end
            Data.SetSearchFilter(ids, txt)
        end
        -- 实际下发了搜索过滤：标记本次为玩家主动搜索，回包为空时提示"未找到相关寄售品"
        _pendingSearchToast = true
    end
    -- 提交未提交的排序草稿
    if _draftSort then
        Data.SetSort(_draftSort)
        _draftSort = nil
    end
    Data.SetPage(1)
    refreshList()
end

-- ----------------------------------------------------------------
-- 排序下拉项选择（1..4）。
-- 这里只更新"草稿排序"和标签显示，不写回 Data、不发查询请求；
-- 真正生效要等到玩家点搜索按钮（applySearch 会一并提交）；
-- 若直接点刷新 / 切页签，草稿会被丢弃。
-- ----------------------------------------------------------------
local function pickSort(sortVal)
    _draftSort = sortVal
    _sortDropdownOpen = false
    uiUpdater.SetSortDropdownVisible(0)
    uiUpdater.UpdateSortLabel(_draftSort)
end

-- ----------------------------------------------------------------
-- 卡片按钮点击分发
-- ----------------------------------------------------------------
-- 新 struct 把退货/退款合并进 Pickup/ReceivePayment 组，点击后按订单状态分流到对应子对话框。
local function tryDispatchCardButton(ctrlId)
    for i = 1, 8 do
        local card = _dlg["Product" .. i]
        if card and card.Product then
            local p = card.Product
            local order = Data.GetItems()[i]
            local function isCtrl(ctrl)
                return ctrl and ctrlId == ctrl.CtrlID
            end
            -- 购买（BuyInfo.btnBuy）：OpenBuyDlg 内部据 secret_protected 选口令版/无口令版
            if p.BuyInfo and isCtrl(p.BuyInfo.btnBuy) then
                if order then dialogManager.OpenBuyDlg(order) end
                return true
            end
            -- 撤销（UndoInfo.btnUndo）：我的在售/我的公示单
            if p.UndoInfo and isCtrl(p.UndoInfo.btnUndo) then
                if order then dialogManager.OpenUndoDlg(order) end
                return true
            end
            -- 取物（Pickup.btnPickup）：卖家退货取回 / 买家收货
            if p.Pickup and isCtrl(p.Pickup.btnPickup) then
                if order then
                    local who = Data.GetMyIdentityIn(order)
                    local et  = order.end_type or 0
                    local cancelled = (et == Config.EndType.PlayerCancel) or (et == Config.EndType.AdminCancel)
                    local isReturn  = (who == 1) and (cancelled or (order.expired == 1))
                    if isReturn then
                        dialogManager.OpenPickUpReturnDlg(order)   -- 卖家退货取回
                    else
                        dialogManager.OpenPickUpDlg(order)         -- 买家收货
                    end
                end
                return true
            end
            -- 取款（ReceivePayment.btnReceivePayment）：买家退款 / 卖家收款
            if p.ReceivePayment and isCtrl(p.ReceivePayment.btnReceivePayment) then
                if order then
                    local who = Data.GetMyIdentityIn(order)
                    local et  = order.end_type or 0
                    local cancelled = (et == Config.EndType.PlayerCancel) or (et == Config.EndType.AdminCancel)
                    local isRefund  = (who == 2) and cancelled
                        and (order.trade_phase == Config.TradePhase.Audit
                          or order.trade_phase == Config.TradePhase.TradeSuccess)
                    if isRefund then
                        dialogManager.OpenClaimRefundDlg(order)    -- 买家退款
                    else
                        dialogManager.OpenWithdrawalDlg(order)     -- 卖家收款
                    end
                end
                return true
            end
        end
    end
    return false
end

-- ----------------------------------------------------------------
-- 事件处理
-- ----------------------------------------------------------------
-- 通知区按钮：翻页(btnPreHistory/btnNextHistory) + 单条点击(History*.btnClick → 详情)
local function tryDispatchNotifyButton(luadlg, ctrlId)
    local side = luadlg.Side
    if not side then return false end
    if side.btnPreHistory and ctrlId == side.btnPreHistory.CtrlID then
        local cur = Data.GetNotifyCurPage()
        if cur > 1 then
            if not passBrowseCooldown() then return true end
            sendNotifyPage(cur - 1)
        end
        return true
    end
    if side.btnNextHistory and ctrlId == side.btnNextHistory.CtrlID then
        local cur = Data.GetNotifyCurPage()
        if cur < Data.GetNotifyTotalPages() then
            if not passBrowseCooldown() then return true end
            sendNotifyPage(cur + 1)
        end
        return true
    end
    local items = Data.GetNotifyItems()
    for i = 1, 6 do
        local slot = side["History" .. i]
        if slot and slot.btnClick and ctrlId == slot.btnClick.CtrlID then
            if items[i] then
                dialogManager.OpenNotifyDetailDlg(items, i)
            end
            return true
        end
    end
    return false
end

local function onEventProc(luadlg, eventCode, ctrlId, ctrl)
    if not luadlg then return end

    -- 门禁闩锁已置位（熔断/打烊/拉黑）：界面里的任何点击都直接关闭界面。
    if _forceClose then
        if eventCode == UIEventDef.TBN_CLICKED or eventCode == UIEventDef.TTN_MOUSECLICK then
            forceCloseAll(luadlg)
        end
        return
    end

    if eventCode == UIEventDef.TBN_CLICKED then
        -- 关闭
        if luadlg.btnClose and ctrlId == luadlg.btnClose.CtrlID then
            luadlg.Raw:ShowDlg(false)
            dialogManager.CloseAllSubDialogs()
            return
        end
        -- 页签
        local tab = luadlg.ShelfSelect
        if tab then
            if tab.btnTabSelling and ctrlId == tab.btnTabSelling.CtrlID then
                switchTab(Config.PageMode.OnSaleDisplay); return
            end
            if tab.btnTabSellingActive and ctrlId == tab.btnTabSellingActive.CtrlID then
                return -- 已经处于选中态
            end
            if tab.btnWaiting and ctrlId == tab.btnWaiting.CtrlID then
                switchTab(Config.PageMode.ComingSoon); return
            end
            if tab.btnWaitingActive and ctrlId == tab.btnWaitingActive.CtrlID then
                return
            end
            if tab.btnSelf and ctrlId == tab.btnSelf.CtrlID then
                switchTab(Config.PageMode.MyOrders); return
            end
            if tab.btnSelfActive and ctrlId == tab.btnSelfActive.CtrlID then
                return
            end
        end
        -- 搜索栏
        local search = luadlg.Search
        if search then
            if search.btnSort and ctrlId == search.btnSort.CtrlID then
                -- 我的交易页签也允许展开下拉（用于显示 txtOrderSelect6 分类排序，功能后续再开发）。
                _sortDropdownOpen = not _sortDropdownOpen
                uiUpdater.SetSortDropdownVisible(_sortDropdownOpen and 1 or 0)
                return
            end
            if search.btnSearch and ctrlId == search.btnSearch.CtrlID then
                if not passBrowseCooldown() then return end
                applySearch(); return
            end
            if search.btnRefresh and ctrlId == search.btnRefresh.CtrlID then
                if not passBrowseCooldown() then return end
                -- 标记这是玩家主动刷新：回包到达时弹"刷新成功"
                _pendingRefreshToast = true
                refreshList(); return
            end
            if search.btnAdd and ctrlId == search.btnAdd.CtrlID then
                network.SendApplyOpenRequest(); return
            end
        end
        -- 翻页栏
        local nav = luadlg.Nav
        if nav then
            if nav.btnUp and ctrlId == nav.btnUp.CtrlID then
                local cur = Data.GetPage()
                if cur > 1 then
                    if not passBrowseCooldown() then return end
                    Data.SetPage(cur - 1)
                    refreshList()
                end
                return
            end
            if nav.btnDown and ctrlId == nav.btnDown.CtrlID then
                local cur   = Data.GetPage()
                local total = Data.GetTotalPageCount()
                if cur < total then
                    if not passBrowseCooldown() then return end
                    Data.SetPage(cur + 1)
                    refreshList()
                end
                return
            end
        end
        -- 卡片按钮
        if tryDispatchCardButton(ctrlId) then return end
        -- 通知区按钮（翻页 / 单条点开详情）
        if tryDispatchNotifyButton(luadlg, ctrlId) then return end
    elseif eventCode == UIEventDef.TEN_CHANGE then
        -- 搜索框文本变化：实时切换占位提示显隐
        local search = luadlg.Search
        if search and search.editSearch and ctrlId == search.editSearch.CtrlID then
            updateSearchPlaceholder()
            return
        end
    elseif eventCode == UIEventDef.TTN_MOUSECLICK then
        -- 排序下拉项是 atxt（可点击的活动文本），通过文字点击事件分发
        local search = luadlg.Search
        if search and search.orderSelect then
            local sel = search.orderSelect
            -- select0「上架时间」：上架时间降序（最新→最旧），浏览页默认排序。
            if sel.txtOrderSelect0 and ctrlId == sel.txtOrderSelect0.CtrlID then pickSort(Config.Sort.TimeDesc);  return end
            if sel.txtOrderSelect1 and ctrlId == sel.txtOrderSelect1.CtrlID then pickSort(Config.Sort.PriceAsc);  return end
            if sel.txtOrderSelect2 and ctrlId == sel.txtOrderSelect2.CtrlID then pickSort(Config.Sort.PriceDesc); return end
            if sel.txtOrderSelect3 and ctrlId == sel.txtOrderSelect3.CtrlID then pickSort(Config.Sort.CountAsc);  return end
            if sel.txtOrderSelect4 and ctrlId == sel.txtOrderSelect4.CtrlID then pickSort(Config.Sort.CountDesc); return end
            -- select5「我的订单」：只看自己挂的货 + 上架时间降序（仅在售/即将上架页签可见，见 SetSortDropdownVisible）。
            -- 与 1~4 一致走草稿排序，点「搜索」后由 applySearch 提交、refreshList 下发 sort=5。
            if sel.txtOrderSelect5 and ctrlId == sel.txtOrderSelect5.CtrlID then pickSort(Config.Sort.Mine);      return end
            -- select6「分类排序」：仅我的交易页签可见（默认排序），待处理分组+组内时间降序、操作完毕时间降序。
            if sel.txtOrderSelect6 and ctrlId == sel.txtOrderSelect6.CtrlID then pickSort(Config.Sort.Category);  return end
        end
    elseif eventCode == UIEventDef.TIN_MOUSEMOVE then
        -- 鼠标首次悬浮到物品图标：属性快照未缓存且不在途时才补拉
        -- （MarkPropsRequestPending 内部去重，请求在途/已缓存都返回 false）。
        -- 回包到达后由 onCallScript 的 ItemPropsResult 分支单卡重设 tip。
        local items = Data.GetItems()
        for i = 1, 8 do
            local card = luadlg["Product" .. i]
            local p = card and card.Product
            if p and p.imgItemIcon and ctrlId == p.imgItemIcon.CtrlID then
                local order = items[i]
                if order and order.order_id
                   and Data.MarkPropsRequestPending(order.order_id) then
                    network.SendItemPropsRequest({ order.order_id })
                end
                return
            end
        end
    elseif eventCode == UIEventDef.TIN_MOUSERCLICK then
        -- 右键点击列表物品图标：把该物品名【覆盖式】写入搜索框（不自动搜索）
        local items = Data.GetItems()
        for i = 1, 8 do
            local card = luadlg["Product" .. i]
            local p = card and card.Product
            if p and p.imgItemIcon and ctrlId == p.imgItemIcon.CtrlID then
                local order = items[i]
                if order then
                    writeItemNameToSearch(order.item_id)
                end
                return
            end
        end
    elseif eventCode == UIEventDef.TTN_MOUSEMOVE then
        -- 鼠标悬浮在卡片时间标签上时，显示订单号 tip
        local items = Data.GetItems()
        for i = 1, 8 do
            local card = luadlg["Product" .. i]
            local p = card and card.Product
            if p and p.txtTime and ctrlId == p.txtTime.CtrlID then
                local order = items[i]
                if order and order.order_id then
                    p.txtTime:SetTipInfo(string.format(TIP_ORDER_ID_FMT, order.order_id))
                end
                return
            end
        end
    end
end

-- ----------------------------------------------------------------
-- onShow：首次显示（或通过主动按钮触发）时拉取数据。
-- NPC 入口会在显示前先推送 OpenResult，所以 onShow 触发时数据可能
-- 已经填充——这里无论如何都刷新一次。
--
-- 每次打开都视作一次全新会话：重置易变 UI 状态（搜索输入、排序下拉）。
-- Data 层的重置发生得更早——在 OpenResult 处理器里、SetOpenResult
-- 重新填充之前。
-- ----------------------------------------------------------------
local function onShow(luadlg, show)
    if show then
        -- 新会话：清门禁闩锁（熔断/打烊/拉黑）+ 清空上次遗留的待发刷新队列。
        _forceClose = false
        Pacer.Clear()
        if luadlg.Search and luadlg.Search.editSearch then
            luadlg.Search.editSearch:Clear()
        end
        -- 清空后输入框为空，显示占位提示
        updateSearchPlaceholder("")
        _sortDropdownOpen = false
        uiUpdater.SetSortDropdownVisible(0)
        -- 重新打开对话框时丢弃任何遗留的排序草稿
        _draftSort = nil
        uiUpdater.RefreshAfterOpen()
        uiUpdater.RefreshList()
    end
end

-- ----------------------------------------------------------------
-- 调试：递归序列化任意值（嵌套 table 展开，userdata 等 tostring）
-- ----------------------------------------------------------------
local function dumpValue(v, depth)
    depth = depth or 0
    if type(v) ~= "table" then return tostring(v) end
    if depth > 4 then return "{...}" end
    local parts = {}
    for k, val in pairs(v) do
        parts[#parts + 1] = tostring(k) .. "=" .. dumpValue(val, depth + 1)
    end
    return "{" .. table.concat(parts, ", ") .. "}"
end

-- ----------------------------------------------------------------
-- 调试：把列表查询回包里的每条订单完整打印到日志
-- ----------------------------------------------------------------
local function dumpListResult(obj)
    local items = obj.items or {}
    Info(string.format("Consignment.ListResult 回包: page_mode=%s page=%s total=%s identity=%s items=%d",
        tostring(obj.page_mode), tostring(obj.page), tostring(obj.total),
        tostring(obj.identity), #items))
    for i, order in ipairs(items) do
        Info(string.format("Consignment.ListResult 订单[%d]: %s", i, dumpValue(order)))
    end
end

-- ----------------------------------------------------------------
-- OnCallScript：分发所有服务端推送
-- ----------------------------------------------------------------
local function onCallScript(luadlg, event, obj)
    if obj == nil then return end

    -- 门禁错误（熔断/打烊/拉黑）统一拦截：除属性补拉（ItemPropsResult，鼠标悬浮
    -- 触发、失败静默）外，任何业务回包带门禁错误码都提示原因并直接关界面。
    if event ~= ScriptEvent.Consignment_ItemPropsResult
       and consumeGateRejection(luadlg, obj) then
        return
    end

    if event == ScriptEvent.Consignment_OpenResult then
        if obj.ret == false then
            ErrorHandler.ShowError(obj.errCode, obj)
            return
        end
        if luadlg.Raw:GetVisible() == 1 then
            -- 已打开的对话框收到 OpenResult：这是动作（领取/购买/撤销/申请）
            -- 完成后请求的统计刷新。只更新统计字段，保留玩家当前所在的页签
            -- 和查询参数；列表已由动作分支自己 refreshList 过了。
            Data.SetOpenResultStats(obj)
            uiUpdater.RefreshAfterOpen()
        else
            -- 首次打开：丢弃残留的查询状态（排序、item_id 过滤、身份、
            -- 页签缓存），使界面以默认页签 / 默认排序 / 无过滤打开。
            Data.Reset()
            Data.SetOpenResult(obj)
            uiUpdater.RefreshAfterOpen()
            -- 对默认页签发起首次列表查询
            Data.SetPage(1)
            refreshList()
            luadlg.Raw:ShowDlg(true)
        end

    elseif event == ScriptEvent.Consignment_ListQueryResult then
        if obj.ret == false then
            -- 失败也消费待确认标记：不弹"刷新成功"/"未找到相关寄售品"，由错误提示兜底反馈
            _pendingRefreshToast = false
            _pendingSearchToast  = false
            ErrorHandler.ShowError(obj.errCode, obj)
            return
        end
        -- 玩家主动刷新的回包：无论列表是否有变化，都给一条"刷新成功"确认，
        -- 避免无变化时玩家以为没点上而连点。仅消费一次。
        if _pendingRefreshToast then
            _pendingRefreshToast = false
            ErrorHandler.ShowSuccess(MSG_REFRESH_SUCCESS)
        end
        -- 调试日志：打印列表回包收到的全部订单字段
        dumpListResult(obj)
        -- 把服务端回包中的查询参数回写本地（以服务端为权威）
        if obj.page_mode then Data.SetPageModeOnly(obj.page_mode) end
        if obj.page     then Data.SetPage(obj.page)     end
        if obj.sort     then Data.SetSort(obj.sort)     end
        if obj.identity then Data.SetIdentity(obj.identity) end
        Data.SetListResult(obj)
        uiUpdater.UpdateTabs()
        uiUpdater.UpdateSortLabel()
        uiUpdater.RefreshList()
        -- 玩家主动搜索的回包：结果为空时提示"未找到相关寄售品"，非空静默。仅消费一次。
        if _pendingSearchToast then
            _pendingSearchToast = false
            if Data.GetTotal() <= 0 then
                ErrorHandler.ShowWarning(MSG_SEARCH_NO_RESULT)
            end
        end

    elseif event == ScriptEvent.Consignment_ItemPropsResult then
        -- 属性补拉回包（每订单一包）。失败只记日志：这是 tip 渲染的锦上添花数据，
        -- 不值得为它弹错误框打断玩家浏览。
        if obj.ret == false then
            Debug("Consignment.ItemPropsResult failed errCode=" .. tostring(obj.errCode))
            return
        end
        if not obj.order_id then return end
        Data.SetItemProps(obj.order_id, obj.item_props or {})
        uiUpdater.UpdateCardTipForOrder(obj.order_id)

    elseif event == ScriptEvent.Consignment_ApplyOpenResult then
        if obj.ret == false then
            ErrorHandler.ShowError(obj.errCode, obj)
            return
        end
        Data.SetApplyOpenResult(obj)
        dialogManager.OpenApplyDlg()

    elseif event == ScriptEvent.Consignment_ApplyResult then
        if obj.ret == false then
            ErrorHandler.ShowError(obj.errCode, obj)
            -- 保留申请对话框打开，让用户修正后重试
            return
        end
        ErrorHandler.ShowSuccess(string.format(MSG_APPLY_SUCCESS_FMT, tostring(obj.sale_open_time or "")))
        -- 关闭申请对话框
        local mgr = game:LuaUIMgr()
        if mgr then
            local applyDlg = mgr:FindDlg(dialogManager.DIALOG_NAMES.Apply)
            if applyDlg then applyDlg:ShowDlg(false) end
        end
        -- 自动切到“即将上架”页签，让用户看到自己的新单；新单会改变
        -- 服务端状态，所以已有的页签缓存都已失效。
        Data.InvalidateAllTabCaches()
        Data.SetPageMode(Config.PageMode.ComingSoon)
        uiUpdater.UpdateTabs()
        queueListRefresh()
        -- 同时刷新统计（OpenRequest 不在 list/notify 冷却桶内，照常立即下发）
        network.SendOpenRequest()

    elseif event == ScriptEvent.Consignment_BuyResult then
        if obj.ret == false then
            ErrorHandler.ShowError(obj.errCode, obj)
            -- 即便购买失败也刷新列表，以反映并发抢购的最新结果
            Data.InvalidateAllTabCaches()
            queueListRefresh()
            return
        end
        ErrorHandler.ShowSuccess(MSG_BUY_SUCCESS)
        -- 关闭所有已打开的购买类对话框
        local mgr = game:LuaUIMgr()
        if mgr then
            local d1 = mgr:FindDlg(dialogManager.DIALOG_NAMES.Buy)
            if d1 then d1:ShowDlg(false) end
            local d2 = mgr:FindDlg(dialogManager.DIALOG_NAMES.BuyToken)
            if d2 then d2:ShowDlg(false) end
        end
        Data.InvalidateAllTabCaches()
        queueListRefresh()
        network.SendOpenRequest()

    elseif event == ScriptEvent.Consignment_ClaimResult then
        if obj.ret == false then
            ErrorHandler.ShowError(obj.errCode, obj)
            return
        end
        if obj.type == Config.ClaimType.Yuanbao then
            -- ErrorHandler.ShowSuccess(string.format(MSG_CLAIM_YB_FMT, obj.amount or 0, obj.fee or 0))
        elseif obj.type == Config.ClaimType.Item then
            -- ErrorHandler.ShowSuccess(string.format(MSG_CLAIM_ITEM_FMT, obj.count or 0))
        elseif obj.type == Config.ClaimType.RefundItem then
            -- ErrorHandler.ShowSuccess(string.format(MSG_CLAIM_ITEM_FMT, obj.count or 0))
        elseif obj.type == Config.ClaimType.RefundYuanbao then
            -- ErrorHandler.ShowSuccess(string.format(MSG_CLAIM_REFUND_YB_FMT, obj.amount or 0))
        end
        -- 关闭所有领取 / 退款 / 收货 / 收款对话框
        local mgr = game:LuaUIMgr()
        if mgr then
            for _, name in ipairs({
                dialogManager.DIALOG_NAMES.PickUp,
                dialogManager.DIALOG_NAMES.PickUpReturn,
                dialogManager.DIALOG_NAMES.Withdrawal,
                dialogManager.DIALOG_NAMES.ClaimRefund,
            }) do
                local d = mgr:FindDlg(name)
                if d then d:ShowDlg(false) end
            end
        end
        Data.InvalidateAllTabCaches()
        queueListRefresh()
        network.SendOpenRequest()

    elseif event == ScriptEvent.Consignment_CancelResult then
        if obj.ret == false then
            ErrorHandler.ShowError(obj.errCode, obj)
            return
        end
        --ErrorHandler.ShowSuccess(MSG_CANCEL_SUCCESS)
        local mgr = game:LuaUIMgr()
        if mgr then
            local d = mgr:FindDlg(dialogManager.DIALOG_NAMES.Undo)
            if d then d:ShowDlg(false) end
        end
        Data.InvalidateAllTabCaches()
        queueListRefresh()
        network.SendOpenRequest()

    elseif event == ScriptEvent.Consignment_NotifyPageResult then
        -- 通知翻页回包：覆盖当前页并重渲染。
        if obj.ret == false then
            ErrorHandler.ShowError(obj.errCode, obj)
            return
        end
        Data.SetNotifyPage(obj)
        uiUpdater.UpdateNotificationList()

    elseif event == ScriptEvent.Consignment_NotifyPush then
        -- 新通知推送：toast 已由服务端 ReceiveSysNotiry 屏显，这里只刷新历史列表与订单页签。
        -- 注意：通知翻页与列表查询共用服务端同一个冷却桶，直接两个一起发第二个必被拒；
        -- 一律入 Pacer 队列（按 kind 去重 + 节流逐个派发），避免过快/重复请求。
        -- 仅当前停在第 1 页时重拉第 1 页以显示最新条目（其余页不打扰玩家阅读）。
        if Data.GetNotifyCurPage() <= 1 then
            queueNotifyFirstPage()
        end
        -- 推送意味着服务端状态可能已变（公示转开售/售出/过期等）：刷新当前页签，
        -- 其余页签缓存作废，下次切过去再查。
        if luadlg.Raw:GetVisible() == 1 then
            Data.InvalidateAllTabCaches()
            queueListRefresh()
        end

    elseif event == ScriptEvent.Consignment_SystemClosed then
        -- 强制关闭界面控制推送：按 reason 选文案（熔断/打烊/拉黑）后关界面并置闩锁。
        forceCloseAll(luadlg)
        ErrorHandler.ShowWarning(NotifyRender.CloseReasonText(obj.reason) or MSG_SYSTEM_CLOSED)
    end
end

-- ----------------------------------------------------------------
-- 创建
-- ----------------------------------------------------------------
local function createDlg(dlgmgr)
    local luadlg = dlgbuilder(dlgmgr, struct, prefix_path, 3000)
    _dlg = luadlg

    luadlg.OnEventProc  = onEventProc
    luadlg.OnShow       = onShow
    luadlg.OnCallScript = onCallScript

    -- 排序下拉默认隐藏
    if luadlg.Search and luadlg.Search.orderSelect then
        luadlg.Search.orderSelect:SetVisible(0)
    end

    -- 搜索框占位提示：禁用控件（enable=0）使其不拦截事件，点击穿透到
    -- 下面的输入框；初始无输入，先显示。后续由 updateSearchPlaceholder
    -- 按输入框内容切换显隐。
    if luadlg.Search and luadlg.Search.txtSearchPlacehold then
        luadlg.Search.txtSearchPlacehold:SetEnable(0)
        luadlg.Search.txtSearchPlacehold:SetVisible(1)
    end

    -- 搜索栏按钮悬浮提示
    if luadlg.Search then
        if luadlg.Search.btnSearch  then luadlg.Search.btnSearch:SetTipInfo(TIP_BTN_SEARCH)   end
        if luadlg.Search.btnRefresh then luadlg.Search.btnRefresh:SetTipInfo(TIP_BTN_REFRESH) end
        if luadlg.Search.btnAdd     then luadlg.Search.btnAdd:SetTipInfo(TIP_BTN_ADD)         end
    end

    -- 通知列表改为翻页（btnPreHistory / btnNextHistory + txtHistoryPage）：
    -- 旧的滚动条监听器(Side.History scroll)已移除；列表由 UpdateNotificationList
    -- 渲染服务端下发的当前页，翻页走 Consignment_NotifyPageRequest。

    -- 注册所有 S2C 事件
    HandleCallScript(ScriptEvent.Consignment_OpenResult,      luadlg)
    HandleCallScript(ScriptEvent.Consignment_ListQueryResult, luadlg)
    HandleCallScript(ScriptEvent.Consignment_ItemPropsResult, luadlg)
    HandleCallScript(ScriptEvent.Consignment_ApplyOpenResult, luadlg)
    HandleCallScript(ScriptEvent.Consignment_ApplyResult,     luadlg)
    HandleCallScript(ScriptEvent.Consignment_BuyResult,       luadlg)
    HandleCallScript(ScriptEvent.Consignment_ClaimResult,     luadlg)
    HandleCallScript(ScriptEvent.Consignment_CancelResult,    luadlg)
    HandleCallScript(ScriptEvent.Consignment_NotifyPush,      luadlg)
    HandleCallScript(ScriptEvent.Consignment_NotifyPageResult, luadlg)
    HandleCallScript(ScriptEvent.Consignment_SystemClosed,    luadlg)

    uiUpdater.Init(luadlg)

    -- 暴露接口，便于其他模块通过按钮 / 快捷键触发打开
    luadlg.SendOpenRequest = network.SendOpenRequest
    luadlg.RefreshList     = refreshList

    return luadlg
end

-- ----------------------------------------------------------------
-- 每帧驱动 Pacer 待发队列：界面可见时按冷却节流逐个派发排队中的「系统自动刷新」
-- （通知推送 / 动作完成触发），实现「多个请求排队、≤1/秒下发」；界面不可见时
-- 直接清空队列（停留期间排进来的刷新没有意义，重开会话会重新拉取）。
-- 注册在模块文件作用域（require 仅一次），不在 createDlg 内，避免热重载重复注册。
-- ----------------------------------------------------------------
local function onGameUpdate()
    if not _dlg or not _dlg.Raw then return end
    if _dlg.Raw:GetVisible() ~= 1 then
        Pacer.Clear()
        return
    end
    Pacer.Tick()
end
events.GameUpdate:Add(onGameUpdate)

return { OnCreate = createDlg }
