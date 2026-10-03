-- ================================================================
-- 寄售-卖家收款对话框（Claim type=1）
-- ================================================================

local dlgbuilder   = require "dlg_builder"

local struct       = require "uiconsignmentwithdrawal_struct"
local prefix_path  = "UIGame/UIConsignmentSub"

local Config  = require "ui.dlgs.consignment.ConsignmentConfig"
local network = require "ui.dlgs.consignment.consignment_network"
local idParseTool = require "id_parse_tool"

local _dlg   = nil
local _order = nil

-- 确认发包防抖：拦住同一订单 SEND_DEBOUNCE_SEC 秒内的快速重复点击（双击只发一个包，
-- 避免第二个包到服务端被幂等判定回 1022 而闪一条红错）。不同订单不拦；超过窗口可重发，
-- 以保留服务端「背包满→清包重试」流程（取款无背包依赖，但四个领取对话框统一同款防抖）。
local SEND_DEBOUNCE_SEC = 1
local _lastSendOrder    = nil   -- 上次确认发包的订单号
local _lastSendClock    = nil   -- 上次确认发包时刻(os.clock 秒)；nil=未发过

local function setLabel(ctrl, text)
    if not ctrl then return end
    ctrl:ClearString()
    if text ~= nil then ctrl:AddString(tostring(text)) end
end

local function setOrder(luadlg, order)
    _order = order
    if not luadlg or not order then return end

    local cnt = order.item_count or 1
    if cnt < 1 then cnt = 1 end
    local total = order.total_price or 0
    local fee = total - math.floor(total * (100 - Config.FEE_RATE_PERCENT) / 100)
    if fee < Config.FEE_MIN_YUANBAO then fee = Config.FEE_MIN_YUANBAO end  -- 手续费下限：保证至少收 1 元宝
    if fee > total then fee = total end                                   -- 极端小额单兜底：手续费不超过总价，payout 不为负
    local payout = total - fee

    local info     = order.item_id and idParseTool.FindItem(order.item_id)
    local itemName = (info and info.Name) or ""

    setLabel(luadlg.txtItem,  string.format("%s x%d", itemName, cnt))
    setLabel(luadlg.txtPrice, total)
    setLabel(luadlg.txtFee,   "-" .. fee)   -- 手续费是扣减项，显示负号
    setLabel(luadlg.txtGold,  payout)
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
        network.SendClaimRequest(Config.ClaimType.Yuanbao, _order.order_id)
    end
end

local function createDlg(dlgmgr)
    local luadlg = dlgbuilder(dlgmgr, struct, prefix_path, 4500)
    _dlg = luadlg
    luadlg.OnEventProc = onEventProc
    luadlg.SetOrder    = setOrder
    return luadlg
end

return { OnCreate = createDlg }
