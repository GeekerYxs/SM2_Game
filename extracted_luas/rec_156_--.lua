-- ================================================================
-- 寄售-主界面渲染
-- 卡片展示模型：
--   公共信息层 + 顶角状态标签(imgSellState+txtSellState)
--   + 大角标印章(imgWaitPublic/imgWaitShip/imgSoldOut/imgBuyed/imgSold)
--   + 操作区分组(BuyInfo/UndoInfo/Pickup/Pickuped/ReceivePayment/ReceivedPayment/WaitReceivePayment)
--   + 退角标修饰(imgReturn) + 口令标识(imgPasswd)
-- ================================================================

local Config  = require "ui.dlgs.consignment.ConsignmentConfig"
local Data    = require "ui.dlgs.consignment.consignment_data"
local Strings = require "ui.dlgs.consignment.consignment_strings"
local NotifyRender = require "ui.dlgs.consignment.consignment_notify_render"

local L = function(s) return game:UTF8toASCII(s) end

local M = {}
local _dlg = nil

-- UI 文案集中在 consignment_strings.lua（S.RENDER）；键名/用途见该文件
local TXT = Strings.RENDER

local SORT_LABEL = {
    [Config.Sort.TimeDesc]  = TXT.SORT_TIME_DESC,
    [Config.Sort.PriceAsc]  = TXT.SORT_PRICE_ASC,
    [Config.Sort.PriceDesc] = TXT.SORT_PRICE_DESC,
    [Config.Sort.CountAsc]  = TXT.SORT_COUNT_ASC,
    [Config.Sort.CountDesc] = TXT.SORT_COUNT_DESC,
    [Config.Sort.Mine]      = TXT.SORT_MINE,
    [Config.Sort.Category]  = TXT.SORT_CATEGORY,
}

-- imgSellState 图标资源（5 态）。与 ui_consignment_dlg.lua 中的 prefix_path 对应；
-- C++ 资源路径按 ANSI/GBK 读取，因此中文文件名必须经过 L() 转换（数字为 ASCII 不受影响）。
local IMG_PREFIX = "UIGame/UIConsignmentMain/"
local IMG = {
    ONSALE  = IMG_PREFIX .. L("交易状态1") .. ".mgff",  -- 状态1：在售中 / 交易审核
    OFFSALE = IMG_PREFIX .. L("交易状态2") .. ".mgff",  -- 状态2：售罄 / 过期下架 / 交易取消(可取货可取款)
    PUBLIC  = IMG_PREFIX .. L("交易状态3") .. ".mgff",  -- 状态3：公示中
    SUCCESS = IMG_PREFIX .. L("交易状态4") .. ".mgff",  -- 状态4：交易成功(可取货可取款)
    DONE    = IMG_PREFIX .. L("交易状态5") .. ".mgff",  -- 状态5：已取物品 / 已取款
}

-- ----------------------------------------------------------------
function M.Init(dlg)
    _dlg = dlg
end

-- ----------------------------------------------------------------
-- 工具函数
-- ----------------------------------------------------------------
local function setLabel(ctrl, text)
    if not ctrl then return end
    ctrl:ClearString()
    if text ~= nil then
        ctrl:AddString(tostring(text))
    end
end

local function safeSetVisible(ctrl, vis)
    if ctrl then ctrl:SetVisible(vis) end
end

local function safeSetEnable(ctrl, en)
    if ctrl then ctrl:SetEnable(en) end
end

-- 把时间格式化为 "MM/DD HH:MM"。支持两种输入：
--   * "YYYY-MM-DD HH:MM:SS" 字符串
--   * Lua time 表 { year, month, day, hour, min, sec, ... }（服务端实际下发的格式）
local function formatShortTime(t)
    if type(t) == "table" and t.year then
        return string.format("%02d/%02d %02d:%02d",
            t.month or 0, t.day or 0, t.hour or 0, t.min or 0)
    end
    if type(t) == "string" and #t >= 16 then
        return t:sub(6, 7) .. "/" .. t:sub(9, 10)
            .. " " .. t:sub(12, 13) .. ":" .. t:sub(15, 16)
    end
    return ""
end

-- 卖家收款净额（应得款）。与服务端 Consignment.lua 取款扣费公式保持一致：
--   fee = total - floor(total*(100-rate)/100)，再钳到 [feeMin, total]；净额 = total - fee。
-- 仅用于卡片"应得款/即将到账"的展示估算；真实到账以领取回包(ClaimResult.amount)为准。
local function netPayout(total)
    total = total or 0
    local rate = Config.FEE_RATE_PERCENT or 5
    local feeMin = Config.FEE_MIN_YUANBAO or 1
    local fee = total - math.floor(total * (100 - rate) / 100)
    if fee < feeMin then fee = feeMin end
    if fee > total then fee = total end
    return total - fee
end

-- 今日剩余撤销次数（撤销入口随单迁到「在售货品/即将上架」的我方卡片，UndoInfo 展示）。
-- 数据来自 OpenResult.player_info（daily_cancel_used / daily_cancel_limit），见服务端 HandleOpen。
local function undoLeft()
    local info  = Data.GetPlayerInfo() or {}
    local used  = tonumber(info.daily_cancel_used)  or 0
    local limit = tonumber(info.daily_cancel_limit) or Config.DAILY_CANCEL_LIMIT or 4
    local left  = limit - used
    if left < 0 then left = 0 end
    return left
end

-- ----------------------------------------------------------------
-- 页签（ShelfSelect）选中/未选中图片切换
-- ----------------------------------------------------------------
function M.UpdateTabs()
    if not _dlg or not _dlg.ShelfSelect then return end
    local pm  = Data.GetPageMode()
    local tab = _dlg.ShelfSelect

    -- 按当前 page_mode 显示“选中态”或“普通态”
    safeSetVisible(tab.btnTabSelling,        pm == Config.PageMode.OnSaleDisplay and 0 or 1)
    safeSetVisible(tab.btnTabSellingActive,  pm == Config.PageMode.OnSaleDisplay and 1 or 0)

    safeSetVisible(tab.btnWaiting,           pm == Config.PageMode.ComingSoon and 0 or 1)
    safeSetVisible(tab.btnWaitingActive,     pm == Config.PageMode.ComingSoon and 1 or 0)

    safeSetVisible(tab.btnSelf,              pm == Config.PageMode.MyOrders and 0 or 1)
    safeSetVisible(tab.btnSelfActive,        pm == Config.PageMode.MyOrders and 1 or 0)

    -- 排序按钮在所有页签都可用：我的交易页签也需打开下拉以显示 txtOrderSelect6（分类排序）。
    if _dlg.Search and _dlg.Search.btnSort then
        safeSetEnable(_dlg.Search.btnSort, 1)
    end
end

-- ----------------------------------------------------------------
-- 排序下拉框-当前选中文案。
-- 可传入 overrideSort 显示一个尚未提交到 Data 的“草稿”排序（例如
-- 用户刚点完下拉项但还没按搜索按钮提交时）。不传则按 Data 中实际
-- 生效的排序渲染。
-- ----------------------------------------------------------------
function M.UpdateSortLabel(overrideSort)
    if not _dlg or not _dlg.Search then return end
    local sort  = overrideSort or Data.GetSort()
    local label = SORT_LABEL[sort] or SORT_LABEL[Config.Sort.TimeDesc]
    setLabel(_dlg.Search.txtOrder, label)
end

-- ----------------------------------------------------------------
-- 排序下拉框-展开/收起
-- ----------------------------------------------------------------
function M.SetSortDropdownVisible(vis)
    if not _dlg or not _dlg.Search then return end
    safeSetVisible(_dlg.Search.orderSelect, vis)
    -- 下拉第 5 行随页签切换：在售/即将上架显示 txtOrderSelect5（我的订单），
    -- 我的交易页签显示 txtOrderSelect6（分类排序）。两者在 struct 里位置重叠、互斥。
    -- 当前只做显隐，点击功能后续再开发。
    if vis == 1 then
        local sel = _dlg.Search.orderSelect
        if sel then
            local isMyOrders = (Data.GetPageMode() == Config.PageMode.MyOrders)
            safeSetVisible(sel.txtOrderSelect5, isMyOrders and 0 or 1)
            safeSetVisible(sel.txtOrderSelect6, isMyOrders and 1 or 0)
        end
    end
end

-- ----------------------------------------------------------------
-- 侧边栏（统计数据）
-- ----------------------------------------------------------------
function M.UpdateSidePanel()
    if not _dlg or not _dlg.Side then return end
    local side  = _dlg.Side
    local stats = Data.GetOrderStats() or {}

    -- 元宝 - OpenResult 不会下发，直接从本地接口实时读取。
    -- 寄售系统里的"元宝"对应 GoldStone (金元宝)，不是 SilverStone。
    local yuanbao = 0
    local dataitem = game:UIDataItem()
    if dataitem then
        yuanbao = dataitem:GetGoldStone() or 0
    end
    setLabel(side.txtGold,           yuanbao)

    setLabel(side.txtTotalBuy,       stats.lifetime_bought_count or 0)
    setLabel(side.txtTotalSell,      stats.lifetime_sold_count or 0)
    setLabel(side.txtSelling,        stats.selling_count or 0)
    setLabel(side.txtPublic,         stats.public_count or 0)
    setLabel(side.txtFrozen,         stats.frozen_count or 0)
    setLabel(side.txtWaitAudit,      stats.audit_count or 0)

    -- 待领取计数：把“领取”和“退还”合并显示，因为 UI 没有独立的退还槽位
    -- （依据开发清单 K 项的决策）。
    local pendingItem = (stats.pending_claim_item or 0) + (stats.pending_refund_item or 0)
    local pendingYB   = (stats.pending_claim_yuanbao or 0) + (stats.pending_refund_yuanbao or 0)
    setLabel(side.txtWaitPickUp,     pendingItem)
    setLabel(side.txtWaitWithdrawal, pendingYB)
end

-- ----------------------------------------------------------------
-- 通知列表（History1..6 + 滚动偏移）
-- ----------------------------------------------------------------
-- 通知列表：固定 6 槽位（History1..6），渲染当前页 items 的 2 行标题；
-- 翻页指示 txtHistoryPage；btnPreHistory/btnNextHistory 始终保持可点
-- （首/末页不禁用，点击由 onEventProc 的边界判断直接吞掉、不发请求）。
-- 每条 btnClick 透明覆盖按钮 → 主 dlg onEventProc 据 i 打开详情。
local HISTORY_SLOTS = 6

function M.UpdateNotificationList()
    if not _dlg or not _dlg.Side then return end
    local side  = _dlg.Side
    local items = Data.GetNotifyItems()

    for i = 1, HISTORY_SLOTS do
        local slot = side["History" .. i]
        if slot then
            local n = items[i]
            if n then
                slot:SetVisible(1)
                if slot.txtHistory then
                    setLabel(slot.txtHistory, NotifyRender.Title(n))
                end
            else
                slot:SetVisible(0)
            end
        end
    end

    -- 翻页指示（按钮始终可点：首/末页不禁用，越界点击在 onEventProc 里被吞掉）
    local cur        = Data.GetNotifyCurPage()
    local totalPages = Data.GetNotifyTotalPages()
    if side.txtHistoryPage then
        setLabel(side.txtHistoryPage, string.format("%d/%d", cur, totalPages))
    end
    if side.btnPreHistory  then safeSetEnable(side.btnPreHistory,  1) end
    if side.btnNextHistory then safeSetEnable(side.btnNextHistory, 1) end
end

-- ----------------------------------------------------------------
-- 翻页栏（页码 + 上下按钮）
-- ----------------------------------------------------------------
function M.UpdateNav()
    if not _dlg or not _dlg.Nav then return end
    local cur   = Data.GetPage()
    local total = Data.GetTotalPageCount()
    if cur < 1 then cur = 1 end
    if cur > total then cur = total end
    setLabel(_dlg.Nav.txtPage, string.format(TXT.PAGE_FMT, cur, total))
    -- 启用/禁用翻页箭头
    safeSetEnable(_dlg.Nav.btnUp,   cur > 1 and 1 or 0)
    safeSetEnable(_dlg.Nav.btnDown, cur < total and 1 or 0)
end

-- ----------------------------------------------------------------
-- 顶角状态标签 文字（txtSellState）。撤销/管理员取消统一「已撤销」。
-- 审核态：在售陈列页从浏览视角等同售罄；其它页签显示「交易审核」。
-- ----------------------------------------------------------------
local function stateLabelOf(order, pageMode)
    if order.order_run == Config.OrderRun.Frozen then
        return TXT.PHASE_FROZEN
    end
    if order.end_type == Config.EndType.PlayerCancel or
       order.end_type == Config.EndType.AdminCancel then
        return TXT.PHASE_CANCEL
    end
    if order.expired == 1 then
        return TXT.PHASE_EXPIRED
    end
    if order.trade_phase == Config.TradePhase.Public then
        return TXT.PHASE_PUBLIC
    elseif order.trade_phase == Config.TradePhase.OnSale then
        return TXT.PHASE_ONSALE
    elseif order.trade_phase == Config.TradePhase.Audit then
        if pageMode == Config.PageMode.OnSaleDisplay then
            return TXT.SOLD_OUT
        end
        return TXT.PHASE_AUDIT
    elseif order.trade_phase == Config.TradePhase.TradeSuccess then
        return TXT.PHASE_SUCCESS
    end
    return ""
end

-- 「我」在该单里待领取（取货 / 取款）动作是否还没完成 —— 按当前视角(who)判定。
-- 每张卡片只属于买家或卖家一方，谁看就只看谁那一侧的领取：卖家领了货款就算完成、
-- 买家领了货物就算完成，互不等对家。分支口径与 decideDisplay 一致：
--   * 交易成功：买家取货(item_claimed) / 卖家取款(yuanbao_claimed)
--   * 审核期被取消：买家退款(yuanbao_claimed) / 卖家退货(item_claimed)
--   * 过期下架 / 公示·在售期撤销：仅卖家退货(item_claimed)
local function myClaimPending(order, who)
    local itDone = (order.item_claimed    or 0) == 1
    local ybDone = (order.yuanbao_claimed or 0) == 1
    local cancelled = order.end_type == Config.EndType.PlayerCancel
                   or order.end_type == Config.EndType.AdminCancel
    if order.trade_phase == Config.TradePhase.TradeSuccess and not cancelled then
        if who == 2 then return not itDone end   -- 买家取货
        if who == 1 then return not ybDone end   -- 卖家取款
    elseif cancelled and order.trade_phase == Config.TradePhase.Audit then
        if who == 2 then return not ybDone end   -- 买家退款
        if who == 1 then return not itDone end   -- 卖家退货
    end
    -- 过期 / 公示·在售期撤销（仅卖家退货），及无关视角兜底
    return not itDone
end

-- 顶角状态标签 底图（imgSellState，5 态）。自己那一侧领取完成后切到「已取」终态(状态5)。
-- 审核态需区分页签视角，故与 stateLabelOf 一样接收 pageMode。
local function stateImageOf(order, pageMode)
    local who = Data.GetMyIdentityIn(order)
    local cancelled = order.end_type == Config.EndType.PlayerCancel
                   or order.end_type == Config.EndType.AdminCancel

    -- 交易取消（可取货可取款）/ 过期下架：自己那侧领完 -> 状态5；否则 -> 状态2
    if cancelled or order.expired == 1 then
        return myClaimPending(order, who) and IMG.OFFSALE or IMG.DONE
    end
    if order.trade_phase == Config.TradePhase.Public then
        return IMG.PUBLIC                                   -- 状态3：公示中
    elseif order.trade_phase == Config.TradePhase.OnSale then
        return IMG.ONSALE                                   -- 状态1：在售中
    elseif order.trade_phase == Config.TradePhase.Audit then
        -- 审核态：陈列页浏览视角=售罄(状态2)；其它页签=交易审核(状态1)
        if pageMode == Config.PageMode.OnSaleDisplay then
            return IMG.OFFSALE
        end
        return IMG.ONSALE
    elseif order.trade_phase == Config.TradePhase.TradeSuccess then
        -- 交易成功：自己那侧已取货/取款 -> 状态5；否则（可取货可取款）-> 状态4
        return myClaimPending(order, who) and IMG.SUCCESS or IMG.DONE
    end
    return IMG.ONSALE
end

-- ----------------------------------------------------------------
-- 卡片复位：隐藏全部大角标 / 操作组 / 口令标识。
-- 隐藏分组 obj 会连带隐藏其子控件（含组内 imgReturn）；点亮时再按需显示 imgReturn。
-- ----------------------------------------------------------------
local function resetCard(p)
    safeSetVisible(p.imgWaitPublic, 0)
    safeSetVisible(p.imgWaitShip,   0)
    safeSetVisible(p.imgSoldOut,    0)
    safeSetVisible(p.imgBuyed,      0)
    safeSetVisible(p.imgSold,       0)

    safeSetVisible(p.BuyInfo,            0)
    safeSetVisible(p.UndoInfo,           0)
    safeSetVisible(p.Pickup,             0)
    safeSetVisible(p.Pickuped,           0)
    safeSetVisible(p.ReceivePayment,     0)
    safeSetVisible(p.ReceivedPayment,    0)
    safeSetVisible(p.WaitReceivePayment, 0)

    safeSetVisible(p.imgPasswd, 0)
end

-- ----------------------------------------------------------------
-- 决定卡片的大角标印章 + 操作区分组。
-- 返回 { stamp, group, groupBtn, showReturn, price }：
--   stamp      = 要点亮的大角标控件（或 nil）
--   group      = 要点亮的操作组 obj（或 nil）
--   groupBtn   = 组内可点按钮（被动组为 nil）
--   showReturn = 组内 imgReturn 是否显示（退货/退款=true，正常收货/收款=false）
--   price      = 组内 txtTotalPrice 要显示的金额（购买/退款=总价，收款/到账=净额）
-- ----------------------------------------------------------------
local function decideDisplay(p, order, pageMode)
    local who   = Data.GetMyIdentityIn(order)   -- 1=卖家 2=买家 0=无关
    local phase = order.trade_phase     or 0
    local et    = order.end_type        or 0
    local ybCl  = order.yuanbao_claimed or 0
    local itCl  = order.item_claimed    or 0
    local total = order.total_price     or 0
    local cancelled = (et == Config.EndType.PlayerCancel) or (et == Config.EndType.AdminCancel)

    local d = { stamp = nil, group = nil, groupBtn = nil, showReturn = false, price = nil }

    if pageMode == Config.PageMode.OnSaleDisplay then
        if phase == Config.TradePhase.OnSale then
            if who == 1 then
                -- 我的在售单：撤销（入口随单迁到本页）
                d.group    = p.UndoInfo
                d.groupBtn = d.group and d.group.btnUndo
            else
                -- 别人在售·可购买
                d.group    = p.BuyInfo
                d.groupBtn = d.group and d.group.btnBuy
                d.price    = total
            end
        elseif phase == Config.TradePhase.Audit then
            -- 售罄：按身份选印章；无操作（操作在「我的交易」）
            if who == 2 then
                d.stamp = p.imgBuyed
            elseif who == 1 then
                d.stamp = p.imgSold
            else
                d.stamp = p.imgSoldOut
            end
        end

    elseif pageMode == Config.PageMode.ComingSoon then
        if who == 1 then
            -- 我的公示单：展示撤销入口（入口随单迁到本页）；
            -- 自己的单已有 UndoInfo，不再叠加「待公示」大角标。
            d.group    = p.UndoInfo
            d.groupBtn = d.group and d.group.btnUndo
        else
            -- 别人的公示单：只显示「待公示」大角标
            d.stamp = p.imgWaitPublic
        end

    elseif pageMode == Config.PageMode.MyOrders then
        if phase == Config.TradePhase.Audit and not cancelled then
            -- 交易审核（未取消）
            if who == 2 then
                d.stamp = p.imgWaitShip                       -- 即将发货（买家等收货）
            elseif who == 1 then
                d.group = p.WaitReceivePayment                -- 即将到账（卖家等收款，被动无按钮）
                d.price = netPayout(total)
            end

        elseif cancelled and (phase == Config.TradePhase.Audit
                              or phase == Config.TradePhase.TradeSuccess) then
            -- 审核期 或 成交后（双方都未领取）被撤销：买家退款 / 卖家退货
            if who == 2 then
                if ybCl == 0 then
                    d.group    = p.ReceivePayment
                    d.groupBtn = d.group and d.group.btnReceivePayment
                else
                    d.group    = p.ReceivedPayment
                end
                d.showReturn = true
                d.price      = total                          -- 退款全额
            elseif who == 1 then
                if itCl == 0 then
                    d.group    = p.Pickup
                    d.groupBtn = d.group and d.group.btnPickup
                else
                    d.group    = p.Pickuped
                end
                d.showReturn = true
            end

        elseif phase == Config.TradePhase.TradeSuccess and not cancelled then
            -- 交易成功：买家收货 / 卖家收款
            if who == 2 then
                if itCl == 0 then
                    d.group    = p.Pickup
                    d.groupBtn = d.group and d.group.btnPickup
                else
                    d.group    = p.Pickuped
                end
                d.showReturn = false
            elseif who == 1 then
                if ybCl == 0 then
                    d.group    = p.ReceivePayment
                    d.groupBtn = d.group and d.group.btnReceivePayment
                else
                    d.group    = p.ReceivedPayment
                end
                d.showReturn = false
                d.price      = netPayout(total)               -- 收款净额（应得款）
            end

        else
            -- 过期 / 公示在售期被撤销取消：卖家退货
            if who == 1 then
                if itCl == 0 then
                    d.group    = p.Pickup
                    d.groupBtn = d.group and d.group.btnPickup
                else
                    d.group    = p.Pickuped
                end
                d.showReturn = true
            end
        end
    end

    return d
end

-- ----------------------------------------------------------------
-- 卡片时间行：统一展示订单创建时间（apply_time），仅日期+时间，无前缀描述。
-- ----------------------------------------------------------------
local function pickCardTime(order)
    return formatShortTime(order.apply_time or "")
end

-- ----------------------------------------------------------------
-- 名称栏（txtName）：
--   与我相关 -> 我是卖家「我的寄售」/ 我是买家「我的购买」；他人单 -> 卖家名。
-- ----------------------------------------------------------------
local function pickCardName(order)
    local who = Data.GetMyIdentityIn(order)
    if who == 1 then
        return TXT.NAME_MY_SELL
    elseif who == 2 then
        return TXT.NAME_MY_BUY
    end
    return order.seller_name or ""
end

-- ----------------------------------------------------------------
-- 渲染单张卡片（order 可能为 nil）
-- ----------------------------------------------------------------
local function renderCard(idx, order, pageMode)
    local card = _dlg["Product" .. idx]
    if not card then return end

    if not order then
        safeSetVisible(card.imgEmpty, 1)
        safeSetVisible(card.Product,  0)
        return
    end

    safeSetVisible(card.imgEmpty, 0)
    safeSetVisible(card.Product,  1)

    local p = card.Product
    if not p then return end

    resetCard(p)

    -- 物品图标（通过 StaticRes 解析）
    local itemId = order.item_id
    if p.imgItemIcon then
        local info = itemId and game:StaticRes():GetItemInfo(itemId)
        if info then
            p.imgItemIcon:SetImage(info:GetImageName())
        else
            p.imgItemIcon:SetImage("")
        end
        if itemId then
            -- 用订单快照的真实耐久(打包值)+属性快照渲染。属性快照不随列表下发（防超包），
            -- 从本地缓存读；未缓存时先按空属性渲染，鼠标首次悬浮图标时才发 ItemPropsRequest
            -- 懒加载，回包后由 UpdateCardTipForOrder 单卡重设 tip。
            p.imgItemIcon:SetTipInfo(game:GetItemTipEx(itemId, order.item_endurance or 0,
                Data.GetItemProps(order.order_id) or {}))
        end
    end

    -- 数量 / 单价
    setLabel(p.txtItemCount, order.item_count or 0)
    local totalPrice = order.total_price or 0
    local count = order.item_count or 1
    if count < 1 then count = 1 end
    setLabel(p.txtSinglePrice, math.floor(totalPrice / count))

    -- 时间 / 名称
    setLabel(p.txtTime, pickCardTime(order))
    setLabel(p.txtName, pickCardName(order))

    -- 顶角状态标签
    if p.txtSellState then
        setLabel(p.txtSellState, stateLabelOf(order, pageMode))
    end
    if p.imgSellState then
        p.imgSellState:SetImage(stateImageOf(order, pageMode))
    end

    -- 口令标识（带口令订单显示，独立于其它层）
    safeSetVisible(p.imgPasswd, order.secret_protected and 1 or 0)

    -- 大角标印章 + 操作区分组
    local d = decideDisplay(p, order, pageMode)
    if d.stamp then
        safeSetVisible(d.stamp, 1)
    end
    if d.group then
        d.group:SetVisible(1)
        -- 退角标修饰（仅 Pickup/Pickuped/ReceivePayment/ReceivedPayment 组内有）
        if d.group.imgReturn then
            safeSetVisible(d.group.imgReturn, d.showReturn and 1 or 0)
        end
        -- 组内金额（BuyInfo/ReceivePayment/ReceivedPayment/WaitReceivePayment 有 txtTotalPrice）
        if d.group.txtTotalPrice and d.price ~= nil then
            setLabel(d.group.txtTotalPrice, d.price)
        end
        -- 撤销剩余次数（UndoInfo）
        if d.group == p.UndoInfo and d.group.txtLeftUndoCount then
            setLabel(d.group.txtLeftUndoCount, string.format(TXT.UNDO_LEFT_FMT, undoLeft()))
        end
        -- 显式启用可点按钮（按钮在多张卡片间复用，避免残留禁用态）
        if d.groupBtn then
            safeSetEnable(d.groupBtn, 1)
        end
    end
end

-- ----------------------------------------------------------------
-- 卡片列表
-- ----------------------------------------------------------------
function M.UpdateCards()
    if not _dlg then return end
    local items    = Data.GetItems()
    local pageMode = Data.GetPageMode()
    local isEmpty  = (#items == 0)

    safeSetVisible(_dlg.imgEmpty, isEmpty and 1 or 0)
    safeSetVisible(_dlg.Nav,      isEmpty and 0 or 1)

    if isEmpty then
        for i = 1, 8 do
            local card = _dlg["Product" .. i]
            if card then
                safeSetVisible(card.imgEmpty, 0)
                safeSetVisible(card.Product,  0)
                safeSetVisible(card,          0)
            end
        end
        return
    end

    for i = 1, 8 do
        local card = _dlg["Product" .. i]
        if card then safeSetVisible(card, 1) end
        renderCard(i, items[i], pageMode)
    end
    -- 属性快照不在这里批量补拉：鼠标首次悬浮到物品图标时才按单懒加载
    -- （见 ui_consignment_dlg.lua 的 TIN_MOUSEMOVE 分支）。
end

-- ----------------------------------------------------------------
-- ItemPropsResult 回包后：只重设展示该订单的那张卡片的物品 tip
-- ----------------------------------------------------------------
function M.UpdateCardTipForOrder(orderId)
    if not _dlg or not orderId then return end
    local items = Data.GetItems()
    for i = 1, 8 do
        local order = items[i]
        if order and order.order_id == orderId then
            local card = _dlg["Product" .. i]
            local p = card and card.Product
            if p and p.imgItemIcon and order.item_id then
                p.imgItemIcon:SetTipInfo(game:GetItemTipEx(order.item_id,
                    order.item_endurance or 0, Data.GetItemProps(orderId) or {}))
            end
            return
        end
    end
end

-- ----------------------------------------------------------------
-- 刷新所有与 ListQueryResult 相关的内容
-- ----------------------------------------------------------------
function M.RefreshList()
    M.UpdateCards()
    M.UpdateNav()
end

-- ----------------------------------------------------------------
-- 刷新所有与 OpenResult 相关的内容
-- ----------------------------------------------------------------
function M.RefreshAfterOpen()
    M.UpdateTabs()
    M.UpdateSortLabel()
    M.UpdateSidePanel()
    M.UpdateNotificationList()
end

return M
