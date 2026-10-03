-- ================================================================
-- 寄售-申请对话框
-- ================================================================

local dlgbuilder   = require "dlg_builder"

local struct       = require "uiconsignmentapply_struct"
local prefix_path  = "UIGame/UIConsignmentSub"

local Config       = require "ui.dlgs.consignment.ConsignmentConfig"
local Data         = require "ui.dlgs.consignment.consignment_data"
local network      = require "ui.dlgs.consignment.consignment_network"
local validators   = require "ui.dlgs.consignment.consignment_validators"
local ErrorHandler = require "ui.dlgs.consignment.consignment_error_handler"

local Strings = require "ui.dlgs.consignment.consignment_strings"
local L = function(s) return game:UTF8toASCII(s) end

-- 中文文案集中在 consignment_strings.lua（S.APPLY），此处取本地别名
local A = Strings.APPLY
local MSG_NO_ITEM         = A.MSG_NO_ITEM
local MSG_NOT_TRADABLE    = A.MSG_NOT_TRADABLE
local MSG_COUNT_INVALID   = A.MSG_COUNT_INVALID
local MSG_PRICE_INVALID   = string.format(A.MSG_PRICE_INVALID, Config.MIN_TOTAL_PRICE, Config.MAX_TOTAL_PRICE)
local MSG_SECRET_INVALID  = A.MSG_SECRET_INVALID
local MSG_COIN_NOT_ENOUGH = A.MSG_COIN_NOT_ENOUGH
local MSG_UNIT_PRICE_CAPPED = string.format(A.MSG_UNIT_PRICE_CAPPED, Config.MAX_TOTAL_PRICE)
local LBL_MAX_FMT         = A.LBL_MAX
local LBL_SHELF_FMT       = L("%d / %d")   -- 纯格式串（无中文），保留本地
local LBL_APPLY_FMT       = L("%d / %d")   -- 纯格式串（无中文），保留本地

local _dlg     = nil
local _slotIdx = -1
local _count   = 1
local _unitPrice = 1
local _stackMax = 1           -- 叠加上限：min(持有数, 堆叠上限)，仅随物品变化
local _maxCount = 1           -- 数量上限：min(_stackMax, floor(总价上限/单价))，随单价动态变化
local _priceCapWarned = false -- 单价越界提示去重：越界期间只提示一次
local _suppressEdit = false   -- 防止程序化写入触发递归的 TEN_CHANGE
local _anonymous = false      -- 卖家匿名开关：开时其它用户看不到本单卖家名（提交时随申请下发）

-- 提交发包防抖：拦住相同申请(同槽位+同数量+同单价) SEND_DEBOUNCE_SEC 秒内的快速重复点击。
-- 申请无服务端幂等键（每次 GenerateID 新建订单 + 扣手续费），双击最坏会重复扣费/重复挂单
-- （可叠放物品槽内余量足时），故客户端去抖是主要防线。不同申请参数不拦；超窗口可重发。
local SEND_DEBOUNCE_SEC = 1
local _lastApplyKey   = nil   -- 上次提交的申请指纹(slot:count:unit)
local _lastApplyClock = nil   -- 上次提交时刻(os.clock 秒)；nil=未发过

local function setEditText(ctrl, text)
    if not ctrl then return end
    _suppressEdit = true
    ctrl:Clear()
    ctrl:AddString(text)
    _suppressEdit = false
end

-- ----------------------------------------------------------------
local function getSlotItem(slot)
    if slot == nil or slot < 0 then return nil end
    local items = game:GetItemBar()
    if not items then return nil end
    return items[slot]
end

-- 数量上限（动态）= min（叠加上限，floor(总价上限 / 当前单价)），至少 1。
-- 「保价格不保数量」：单价是玩家意志、系统不动；数量随单价被动收紧。
-- 单价为空/0 时按 1 计算（floor(上限/1) = 上限），即暂不因数量收紧。
local function recomputeMaxCount()
    local p = math.max(1, _unitPrice)
    local byPrice = math.floor(Config.MAX_TOTAL_PRICE / p)
    if byPrice < 1 then byPrice = 1 end
    _maxCount = math.min(_stackMax, byPrice)
    if _maxCount < 1 then _maxCount = 1 end
end

local function refreshIcon()
    if not _dlg then return end
    local item = getSlotItem(_slotIdx)
    if item then
        local info = game:GetItemInfo(item.ItemID)
        if info then
            _dlg.imgIcon:SetImage(info:GetImageName())
            _dlg.imgIcon:SetVisible(1)
            _dlg.imgIcon:SetTipInfo(game:GetItemTip(item.ItemID))
            -- 叠加上限 = min(持有数, 堆叠上限)
            local stackMax = info.Overlap or 1
            if stackMax < 1 then stackMax = 1 end
            _stackMax = math.min(item.Count or 1, stackMax)
        else
            _dlg.imgIcon:SetImage("")
            _dlg.imgIcon:SetVisible(0)
            _stackMax = 1
        end
        -- 拖入物品后按当前单价重算数量上限，再把数量夹回区间内
        recomputeMaxCount()
        if _count > _maxCount then _count = _maxCount end
        if _count < 1 then _count = 1 end
    else
        _dlg.imgIcon:SetImage("")
        _dlg.imgIcon:SetVisible(0)
        _stackMax = 1
        recomputeMaxCount()
        _count = 1
    end
end

-- 仅刷新只读 txt 字段（totalPrice / fee / maxCount）。
-- 用于输入过程中——绝对不要回写 editCount/editPrice（会导致光标跳位）。
-- 计算时把 _count/_unitPrice = 0（空字段）视作 1，但不写回输入框。
local function refreshDerived()
    if not _dlg then return end
    -- 数量上限随单价变化，每次刷新派生字段时同步重算，使「(最大)」提示及时更新
    recomputeMaxCount()
    local c = math.max(1, _count)
    local p = math.max(1, _unitPrice)
    local totalPrice = c * p
    local fee = totalPrice * Config.COIN_PER_YUANBAO
    _dlg.txtTotalPrice:ClearString(); _dlg.txtTotalPrice:AddString(tostring(totalPrice))
    _dlg.txtFee:ClearString();        _dlg.txtFee:AddString(tostring(fee))
    _dlg.txtMaxCount:ClearString();   _dlg.txtMaxCount:AddString(string.format(LBL_MAX_FMT, _maxCount))
end

-- 全量归一化：回写编辑框、刷新派生字段。用于状态需要规范化时
--（换槽位、+/- 按钮、失焦、提交）。
-- 「保价格不保数量」：单价仅夹到 [1, 总价上限]，绝不为塞下数量而压低；
-- 数量按动态上限（含单价约束）收紧。
local function refreshNumbers()
    if not _dlg then return end
    if _unitPrice < 1 then _unitPrice = 1 end
    if _unitPrice > Config.MAX_TOTAL_PRICE then _unitPrice = Config.MAX_TOTAL_PRICE end
    recomputeMaxCount()
    if _count < 1 then _count = 1 end
    if _count > _maxCount then _count = _maxCount end
    setEditText(_dlg.editCount, tostring(_count))
    setEditText(_dlg.editPrice, tostring(_unitPrice))
    refreshDerived()
end

-- editCount 的 TEN_CHANGE 处理：过滤非数字、强制数量上限、同步派生字段。
-- 这里不强制下限（1），允许用户在输入过程中暂时清空字段。
-- 「保价格不保数量」：改数量绝不回头动单价，只把数量夹到动态上限内。
local function onEditCountChanged()
    if _suppressEdit or not _dlg or not _dlg.editCount then return end
    local raw = _dlg.editCount:GetInputText() or ""
    local filtered = (raw:gsub("[^%d]", ""))
    if filtered ~= raw then
        setEditText(_dlg.editCount, filtered)
        raw = filtered
    end
    local n = tonumber(raw) or 0
    -- 数量上限随当前单价而定（floor(总价上限/单价) 与叠加上限取小）
    recomputeMaxCount()
    if n > _maxCount then
        n = _maxCount
        setEditText(_dlg.editCount, tostring(n))
    end
    _count = n
    refreshDerived()
end

-- editPrice 的 TEN_CHANGE 处理：单价是玩家意志，系统不为塞下数量压低它。
--   输入 > 总价上限：单价钳到上限、数量归 1，并提示（越界期间只提示一次）。
--   输入 ≤ 总价上限：采纳新单价，再按动态上限把数量收紧（不上调）。
local function onEditPriceChanged()
    if _suppressEdit or not _dlg or not _dlg.editPrice then return end
    local raw = _dlg.editPrice:GetInputText() or ""
    local filtered = (raw:gsub("[^%d]", ""))
    if filtered ~= raw then
        setEditText(_dlg.editPrice, filtered)
        raw = filtered
    end
    local n = tonumber(raw) or 0
    if n > Config.MAX_TOTAL_PRICE then
        n = Config.MAX_TOTAL_PRICE
        setEditText(_dlg.editPrice, tostring(n))
        _unitPrice = n
        _count = 1
        setEditText(_dlg.editCount, tostring(_count))
        if not _priceCapWarned then
            ErrorHandler.ShowWarning(MSG_UNIT_PRICE_CAPPED)
            _priceCapWarned = true
        end
        refreshDerived()
        return
    end
    _priceCapWarned = false
    _unitPrice = n
    -- 采纳新单价后：数量上限 = min(叠加上限, floor(总价上限/新单价))，
    -- 超出则下调，保证总价不超上限；不足不上调（保留玩家原数量意图）。
    recomputeMaxCount()
    if _count > _maxCount then
        _count = _maxCount
        setEditText(_dlg.editCount, tostring(_count))
    end
    refreshDerived()
end

local function refreshQuota()
    if not _dlg then return end
    local ao = Data.GetApplyOpen() or {}
    _dlg.txtShelf:ClearString()
    _dlg.txtShelf:AddString(string.format(LBL_SHELF_FMT,
        ao.concurrent_listing or 0, ao.concurrent_listing_limit or Config.CONCURRENT_LISTING_LIMIT))
    _dlg.txtApplyed:ClearString()
    _dlg.txtApplyed:AddString(string.format(LBL_APPLY_FMT,
        ao.daily_apply_total or 0, ao.daily_apply_limit or Config.DAILY_APPLY_LIMIT))
end

-- ----------------------------------------------------------------
-- 交易口令占位提示：editPasswd 为空时显示 txtPasswdPlaceholder
--（“留空表示公开销售（任何玩家可购买）”），有输入时隐藏。该控件
-- enable=0（见 createDlg），点击会穿透到下面的输入框，不影响口令框自身
-- 的事件。knownText 已知时直接传入，省去一次 GetInputText 回读。
-- ----------------------------------------------------------------
local function updatePasswdPlaceholder(knownText)
    if not (_dlg and _dlg.txtPasswdPlaceholder) then return end
    local txt = knownText
    if txt == nil then
        if _dlg.editPasswd then
            txt = _dlg.editPasswd:GetInputText() or ""
        else
            txt = ""
        end
    end
    _dlg.txtPasswdPlaceholder:SetVisible((txt == "") and 1 or 0)
end

-- 匿名开关视觉刷新：开→显示 imgAnonymousSelect（选中态叠层），关→隐藏。
local function refreshAnonymous()
    if _dlg and _dlg.imgAnonymousSelect then
        _dlg.imgAnonymousSelect:SetVisible(_anonymous and 1 or 0)
    end
end

local function resetState()
    _slotIdx = -1
    _count = 1
    _unitPrice = 1
    _stackMax = 1
    _maxCount = 1
    _priceCapWarned = false
    _anonymous = false
end

-- ----------------------------------------------------------------
-- 物品槽点击（通过光标命令拖入）
-- ----------------------------------------------------------------
local function onSlotEvent(eventCode)
    if eventCode == UIEventDef.TIN_MOUSECLICK then
        local cmd = game:GetCursorOperationCmd()
        if cmd ~= EOperationCmd.Item_Pickup then return end
        local slot = game:GetCursorOperationCmdParam()
        game:ClearCursorOperation()
        local ok = validators.CanConsign(slot)
        if not ok then
            ErrorHandler.ShowWarning(MSG_NOT_TRADABLE)
            return
        end
        _slotIdx = slot
        refreshIcon()
        refreshNumbers()
    elseif eventCode == UIEventDef.TIN_MOUSERCLICK then
        resetState()
        refreshIcon()
        refreshNumbers()
    end
end

-- ----------------------------------------------------------------
-- 提交
-- ----------------------------------------------------------------
local function submit()
    -- 先提交编辑框中已输入但未确认的内容，再做归一化。
    onEditCountChanged(); onEditPriceChanged(); refreshNumbers()
    -- 校验物品槽
    if _slotIdx < 0 then
        ErrorHandler.ShowWarning(MSG_NO_ITEM); return
    end
    -- 校验数量
    if not validators.IsCountValid(_count, _maxCount) then
        ErrorHandler.ShowWarning(MSG_COUNT_INVALID); return
    end
    local totalPrice = _count * _unitPrice
    if not validators.IsTotalPriceValid(totalPrice) then
        ErrorHandler.ShowWarning(MSG_PRICE_INVALID); return
    end
    -- 校验口令
    local secret = ""
    if _dlg.editPasswd then
        secret = _dlg.editPasswd:GetInputText() or ""
    end
    if not validators.IsSecretValid(secret) then
        ErrorHandler.ShowWarning(MSG_SECRET_INVALID); return
    end
    -- 校验金币（手续费 = totalPrice * COIN_PER_YUANBAO）
    local fee = totalPrice * Config.COIN_PER_YUANBAO
    local dataitem = game:UIDataItem()
    if dataitem then
        local coin = dataitem:GetMoney() or 0
        if coin < fee then
            ErrorHandler.ShowWarning(MSG_COIN_NOT_ENOUGH); return
        end
    end

    -- 提交去抖：相同申请指纹 + SEND_DEBOUNCE_SEC 秒内重复点击只发一个包
    -- （os.clock 约 24.8 天回绕：回绕瞬间 now<_lastApplyClock 按已过窗口放行）
    local applyKey = string.format("%d:%d:%d", _slotIdx, _count, _unitPrice)
    local now = os.clock()
    if _lastApplyKey == applyKey and _lastApplyClock
        and now >= _lastApplyClock and (now - _lastApplyClock) < SEND_DEBOUNCE_SEC then
        return
    end
    _lastApplyKey   = applyKey
    _lastApplyClock = now

    network.SendApplyRequest({
        slotIdx         = _slotIdx,
        count           = _count,
        totalPrice      = totalPrice,
        secret          = secret ~= "" and secret or nil,
        sellerAnonymous = _anonymous and 1 or 0,
    })
end

-- ----------------------------------------------------------------
-- 事件处理
-- ----------------------------------------------------------------
local function onEventProc(luadlg, eventCode, ctrlId, ctrl)
    if eventCode == UIEventDef.TBN_CLICKED then
        if ctrlId == luadlg.btnClose.CtrlID or ctrlId == luadlg.btnCancel.CtrlID then
            luadlg.Raw:ShowDlg(false); return
        end
        if ctrlId == luadlg.btnConfirm.CtrlID then submit(); return end
        if ctrlId == luadlg.btnDecCount.CtrlID then
            onEditCountChanged()  -- 把最新输入拉到 _count
            if _count > 1 then _count = _count - 1 end
            refreshNumbers()
            return
        end
        if ctrlId == luadlg.btnIncCount.CtrlID then
            onEditCountChanged()
            if _count < _maxCount then _count = _count + 1 end
            refreshNumbers()
            return
        end
        if ctrlId == luadlg.btnDecPrice.CtrlID then
            onEditPriceChanged()
            if _unitPrice > 1 then _unitPrice = _unitPrice - 1 end
            refreshNumbers()
            return
        end
        if ctrlId == luadlg.btnIncPrice.CtrlID then
            onEditPriceChanged()
            _unitPrice = _unitPrice + 1
            refreshNumbers()
            return
        end
    elseif eventCode == UIEventDef.TEN_CHANGE then
        if luadlg.editCount and ctrlId == luadlg.editCount.CtrlID then
            onEditCountChanged(); return
        end
        if luadlg.editPrice and ctrlId == luadlg.editPrice.CtrlID then
            onEditPriceChanged(); return
        end
        if luadlg.editPasswd and ctrlId == luadlg.editPasswd.CtrlID then
            updatePasswdPlaceholder(); return
        end
    elseif eventCode == UIEventDef.TEN_LOSTFOCUS or eventCode == UIEventDef.TEN_RETURN then
        -- 先提交已输入的文本（防止当前宿主没有逐字符触发 TEN_CHANGE），
        -- 然后通过 refreshNumbers 把空/0 归一化为 1。
        if luadlg.editCount and ctrlId == luadlg.editCount.CtrlID then
            onEditCountChanged(); refreshNumbers(); return
        end
        if luadlg.editPrice and ctrlId == luadlg.editPrice.CtrlID then
            onEditPriceChanged(); refreshNumbers(); return
        end
        if luadlg.editPasswd and ctrlId == luadlg.editPasswd.CtrlID then
            updatePasswdPlaceholder(); return
        end
    elseif eventCode == UIEventDef.TIN_MOUSECLICK or eventCode == UIEventDef.TIN_MOUSERCLICK then
        if luadlg.imgIconBG and ctrlId == luadlg.imgIconBG.CtrlID then
            onSlotEvent(eventCode); return
        end
        if luadlg.imgIcon and ctrlId == luadlg.imgIcon.CtrlID then
            onSlotEvent(eventCode); return
        end
        -- 匿名开关：点击背景或选中态任一切换（仅左键）。关时选中态隐藏、点击落到背景；开时选中态在上、点击落到选中态。
        if eventCode == UIEventDef.TIN_MOUSECLICK
            and ((luadlg.imgAnonymousBG and ctrlId == luadlg.imgAnonymousBG.CtrlID)
              or (luadlg.imgAnonymousSelect and ctrlId == luadlg.imgAnonymousSelect.CtrlID)) then
            _anonymous = not _anonymous
            refreshAnonymous()
            return
        end
    elseif eventCode == UIEventDef.TIN_MOUSEMOVE then
        if luadlg.imgIcon and ctrlId == luadlg.imgIcon.CtrlID and _slotIdx >= 0 then
            local di = game:UIDataItem()
            if di then luadlg.imgIcon:SetTipInfo(di:GetSlotTip(_slotIdx, false)) end
        end
    end
end

-- ----------------------------------------------------------------
-- 申请界面与装备背包面板的联动布局
-- 打开申请界面时，左侧一并打开装备背包（供玩家从背包拖入待寄售物品），
-- 关闭时一并收起。两窗左右并排（装备 x=35 / 申请 x=571），不会重叠。
-- game:GetEquipDlg() 返回 CUIEquipDlg（继承 wsDialogBase）；其 ShowDlg 参数是
-- number 0/1（区别于 CUILuaDlg:ShowDlg 的 boolean），故传 1/0 显隐。
-- ----------------------------------------------------------------
local EQUIP_DLG_X, EQUIP_DLG_Y = 35,  170
local APPLY_DLG_X, APPLY_DLG_Y = 480, 170

local function showEquipDlg(show)
    local equipdlg = game:GetEquipDlg()
    if not equipdlg then return end
    if show then
        equipdlg:SetPosition(EQUIP_DLG_X, EQUIP_DLG_Y)
        equipdlg:ShowDlg(1)
    else
        equipdlg:ShowDlg(0)
    end
end

-- 由 dialog_manager 在 ShowDlg(true) 之前调用
local function onOpenWithApplyData(luadlg)
    resetState()
    refreshIcon()
    refreshNumbers()
    refreshQuota()
    -- 每次打开重置匿名开关为关（resetState 已置 _anonymous=false，这里同步视觉）
    refreshAnonymous()
    -- 每次打开清空交易口令，避免沿用上次输入
    if _dlg and _dlg.editPasswd then _dlg.editPasswd:Clear() end
    -- 口令已清空，占位提示需重新显示
    updatePasswdPlaceholder("")
    -- 申请界面固定到右侧，并在左侧一并打开装备背包面板
    if _dlg and _dlg.Raw then _dlg.Raw:SetPosition(APPLY_DLG_X, APPLY_DLG_Y) end
    showEquipDlg(true)
end

local function onShow(luadlg, show)
    if show then
        -- 无需额外操作；数据已由 onOpenWithApplyData 设置
    else
        resetState()
        -- 申请界面关闭时一并收起装备背包面板
        showEquipDlg(false)
    end
end

-- ----------------------------------------------------------------
-- 创建
-- ----------------------------------------------------------------
local function createDlg(dlgmgr)
    local luadlg = dlgbuilder(dlgmgr, struct, prefix_path, 4000)
    _dlg = luadlg

    luadlg.OnEventProc = onEventProc
    luadlg.OnShow      = onShow
    luadlg.OnOpenWithApplyData = onOpenWithApplyData

    -- 启用图标槽位的鼠标事件
    if luadlg.imgIconBG then luadlg.imgIconBG:SetEnable(1); luadlg.imgIconBG:SetMouseMoveEvent(1) end
    if luadlg.imgIcon   then luadlg.imgIcon:SetEnable(1);   luadlg.imgIcon:SetMouseMoveEvent(1)   end

    -- 启用匿名开关（背景 + 选中态）鼠标事件；初始按 _anonymous 隐藏选中态
    if luadlg.imgAnonymousBG     then luadlg.imgAnonymousBG:SetEnable(1)     end
    if luadlg.imgAnonymousSelect then luadlg.imgAnonymousSelect:SetEnable(1) end
    refreshAnonymous()

    -- 交易口令占位提示：禁用控件（enable=0）使其不拦截事件，点击穿透到
    -- 下面的口令输入框；初始无输入，先显示。后续由 updatePasswdPlaceholder
    -- 按输入框内容切换显隐。
    if luadlg.txtPasswdPlaceholder then
        luadlg.txtPasswdPlaceholder:SetEnable(0)
        luadlg.txtPasswdPlaceholder:SetVisible(1)
    end

    return luadlg
end

return { OnCreate = createDlg }
