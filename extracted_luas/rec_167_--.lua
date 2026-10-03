-- ================================================================
-- 寄售-卖家退货对话框（Claim type=3）
-- 注意：根据 struct 此处使用 imgItemIcon（而不是 imgIcon）。
-- ================================================================

local dlgbuilder   = require "dlg_builder"

local struct       = require "uiconsignmentpickupreturn_struct"
local prefix_path  = "UIGame/UIConsignmentSub"

local Config  = require "ui.dlgs.consignment.ConsignmentConfig"
local network = require "ui.dlgs.consignment.consignment_network"
local Data    = require "ui.dlgs.consignment.consignment_data"
local Strings = require "ui.dlgs.consignment.consignment_strings"

local CLR_REASON = "#53248"   -- 退货原因用红字
local CLR_NORMAL = "#65535"   -- 后缀恢复正常色

local _dlg   = nil
local _order = nil

-- 确认发包防抖：拦住同一订单 SEND_DEBOUNCE_SEC 秒内的快速重复点击（双击只发一个包，
-- 避免第二个包到服务端被幂等判定回 1022 而闪一条红错）。不同订单不拦；超过窗口可重发，
-- 以保留服务端「背包满→清包重试」流程。
local SEND_DEBOUNCE_SEC = 1
local _lastSendOrder    = nil   -- 上次确认发包的订单号
local _lastSendClock    = nil   -- 上次确认发包时刻(os.clock 秒)；nil=未发过

local function setLabel(ctrl, text)
    if not ctrl then return end
    ctrl:ClearString()
    if text ~= nil then ctrl:AddString(tostring(text)) end
end

-- 退货提示：红字「原因」+ 共用后缀「，请取回寄售物品」。
-- 原因三选一，口径同主界面 tryDispatchCardButton 的退货分流：
--   expired==1          → 寄售超时
--   trade_phase==Audit  → 成交后交易审核未通过（交易回退）
--   其余（撤销/系统撤销）→ 寄售单撤销
local function buildReasonTip(order)
    local S = Strings.PICKUP_RETURN
    local reason
    if order.expired == 1 then
        reason = S.REASON_EXPIRED
    elseif order.trade_phase == Config.TradePhase.Audit then
        reason = S.REASON_AUDIT_FAIL
    else
        reason = S.REASON_CANCEL
    end
    return CLR_REASON .. reason .. CLR_NORMAL .. S.TIP_SUFFIX
end

local function setOrder(luadlg, order)
    _order = order
    if not luadlg or not order then return end
    setLabel(luadlg.ReasonTip, buildReasonTip(order))
    if luadlg.imgItemIcon then
        local info = order.item_id and game:StaticRes():GetItemInfo(order.item_id)
        if info then
            luadlg.imgItemIcon:SetImage(info:GetImageName())
            -- 属性快照不随列表下发，从属性缓存读（列表渲染时已补拉，正常已就绪）
            luadlg.imgItemIcon:SetTipInfo(game:GetItemTipEx(order.item_id, order.item_endurance or 0, Data.GetItemProps(order.order_id) or {}))
        else
            luadlg.imgItemIcon:SetImage("")
        end
    end
    local cnt = order.item_count or 1
    if cnt < 1 then cnt = 1 end
    local total = order.total_price or 0
    setLabel(luadlg.txtCount, cnt)
    setLabel(luadlg.txtPrice, math.floor(total / cnt))
end

local function onEventProc(luadlg, eventCode, ctrlId, ctrl)
    if eventCode ~= UIEventDef.TBN_CLICKED then return end
    if ctrlId == luadlg.btnClose.CtrlID or ctrlId == luadlg.btnCancel.CtrlID then
        luadlg.Raw:ShowDlg(false); return
    end
    if ctrlId == luadlg.btnConfirm.CtrlID then
        if not _order then return end
        -- os.clock 约 24.8 天回绕：回绕瞬间 now<_lastSendClock 按已过窗口放行
        local now = os.clock()
        if _lastSendOrder == _order.order_id and _lastSendClock
            and now >= _lastSendClock and (now - _lastSendClock) < SEND_DEBOUNCE_SEC then
            return
        end
        _lastSendOrder = _order.order_id
        _lastSendClock = now
        network.SendClaimRequest(Config.ClaimType.RefundItem, _order.order_id)
    end
end

local function createDlg(dlgmgr)
    local luadlg = dlgbuilder(dlgmgr, struct, prefix_path, 4400)
    _dlg = luadlg
    luadlg.OnEventProc = onEventProc
    luadlg.SetOrder    = setOrder
    return luadlg
end

return { OnCreate = createDlg }
