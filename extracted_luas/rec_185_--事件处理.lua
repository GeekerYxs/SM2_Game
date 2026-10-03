local dlgbuilder = require "dlg_builder"
local network = require "ui.dlgs.ghost_market.ghost_market_network"

local struct = require "uighostmarketopenbusiness_struct"
local prefix_path = "UIGame/UIGhostMarket"

local _dlg = nil

-- 事件处理
local function onEventProc(luadlg, eventCode, ctrlId, ctrl)
    if eventCode == UIEventDef.TBN_CLICKED then
        if ctrlId == luadlg.Confirm.CtrlID then
            -- 确认按钮
            network.SendStockRequest()
            luadlg.Raw:ShowDlg(false)
            local uimgr = game:LuaUIMgr()
            local marketDlg = FindLuaDlg(uimgr:FindDlg("GhostMarket"))
            marketDlg.PlayEffect("起货 卷轴升起.mgff")
            marketDlg.PlayEffect2("起货 弹出底部面板.mgff")
        elseif ctrlId == luadlg.Cancel.CtrlID then
            -- 取消按钮
            luadlg.Raw:ShowDlg(false)
        elseif ctrlId == luadlg.Close.CtrlID then
            -- 关闭按钮
            luadlg.Raw:ShowDlg(false)
        end
    end
end

-- 创建对话框
local function createDlg(dlgmgr)
    local luadlg = dlgbuilder(dlgmgr, struct, prefix_path, 3000)
    _dlg = luadlg
    
    luadlg.OnEventProc = onEventProc
    
    return luadlg
end

return {
    OnCreate = createDlg, 
}
