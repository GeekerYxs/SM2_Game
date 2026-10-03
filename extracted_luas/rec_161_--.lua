-- ================================================================
-- 寄售-购买对话框（无口令版）
-- ================================================================

local dlgbuilder   = require "dlg_builder"

local struct       = require "uiconsignmentbuy_struct"
local prefix_path  = "UIGame/UIConsignmentSub"

local network = require "ui.dlgs.consignment.consignment_network"
local Data    = require "ui.dlgs.consignment.consignment_data"

local Strings = require "ui.dlgs.consignment.consignment_strings"

-- 中文文案集中在 consignment_strings.lua（S.BUY）
local TIP_NORMAL = Strings.BUY.TIP_NORMAL
local TIP_NO_YB  = Strings.BUY.TIP_NO_YB

local _dlg   = nil
local _order = nil
local _anonymous = false   -- 买家匿名开关：开时卖家看不到本次买家名（购买时随请求下发）

-- 确认发包防抖：拦住同一订单 SEND_DEBOUNCE_SEC 秒内的快速重复点击（双击只发一个包）。
-- 购买有服务端 BuyerID 状态守卫，双击不会重复扣元宝，但第二个包会被拒并闪一条迷惑红错；
-- 去抖消掉这条假错。不同订单不拦；超窗口可重发。
local SEND_DEBOUNCE_SEC = 1
local _lastSendOrder    = nil   -- 上次确认发包的订单号
local _lastSendClock    = nil   -- 上次确认发包时刻(os.clock 秒)；nil=未发过

local function setLabel(ctrl, text)
    if not ctrl then return end
    ctrl:ClearString()
    if text ~= nil then ctrl:AddString(tostring(text)) end
end

-- 匿名开关视觉刷新：开→显示 imgAnonymousSelect（选中态叠层），关→隐藏。
local function refreshAnonymous()
    if _dlg and _dlg.imgAnonymousSelect then
        _dlg.imgAnonymousSelect:SetVisible(_anonymous and 1 or 0)
    end
end

local function setOrder(luadlg, order)
    _order = order
    -- 每次打开购买框重置匿名开关为关
    _anonymous = false
    refreshAnonymous()
    if not luadlg or not order then return end

    -- 物品图标
    if luadlg.imgIcon then
        local info = order.item_id and game:StaticRes():GetItemInfo(order.item_id)
        if info then
            luadlg.imgIcon:SetImage(info:GetImageName())
            -- 属性快照不随列表下发，从属性缓存读（列表渲染时已补拉，正常已就绪）
            luadlg.imgIcon:SetTipInfo(game:GetItemTipEx(order.item_id, order.item_endurance or 0, Data.GetItemProps(order.order_id) or {}))
        else
            luadlg.imgIcon:SetImage("")
        end
    end

    local cnt = order.item_count or 1
    if cnt < 1 then cnt = 1 end
    local total = order.total_price or 0
    setLabel(luadlg.txtCount, cnt)
    setLabel(luadlg.txtPrice, math.floor(total / cnt))
    setLabel(luadlg.txtGold,  total)

    -- 提示文字：检查元宝是否足够（寄售系统对应 GoldStone）
    local di = game:UIDataItem()
    local yb = di and (di:GetGoldStone() or 0) or 0
    if yb < total then
        setLabel(luadlg.txtBuyTip, TIP_NO_YB)
    else
        setLabel(luadlg.txtBuyTip, TIP_NORMAL)
    end
end

local function onEventProc(luadlg, eventCode, ctrlId, ctrl)
    -- 匿名开关：点击背景或选中态任一切换（仅左键）。关时选中态隐藏、点击落到背景；开时选中态在上。
    if eventCode == UIEventDef.TIN_MOUSECLICK then
        if (luadlg.imgAnonymousBG and ctrlId == luadlg.imgAnonymousBG.CtrlID)
            or (luadlg.imgAnonymousSelect and ctrlId == luadlg.imgAnonymousSelect.CtrlID) then
            _anonymous = not _anonymous
            refreshAnonymous()
        end
        return
    end
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
        network.SendBuyRequest(_order.order_id, nil, _anonymous and 1 or 0)
        return
    end
end

local function createDlg(dlgmgr)
    local luadlg = dlgbuilder(dlgmgr, struct, prefix_path, 4100)
    _dlg = luadlg
    luadlg.OnEventProc = onEventProc
    luadlg.SetOrder    = setOrder

    -- 启用匿名开关（背景 + 选中态）鼠标事件；初始按 _anonymous 隐藏选中态
    if luadlg.imgAnonymousBG     then luadlg.imgAnonymousBG:SetEnable(1)     end
    if luadlg.imgAnonymousSelect then luadlg.imgAnonymousSelect:SetEnable(1) end
    refreshAnonymous()

    return luadlg
end

return { OnCreate = createDlg }
