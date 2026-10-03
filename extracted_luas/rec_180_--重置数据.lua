local dlgbuilder = require "dlg_builder"
local network = require "ui.dlgs.ghost_market.ghost_market_network"
local GhostMarketData = require "ui.dlgs.ghost_market.ghost_market_data"

local struct = require "uighostmarketchangefortune_struct"
local prefix_path = "UIGame/UIGhostMarket"

local _dlg = nil

-- 重置数据
local function reset()
    -- 不再需要重置局部数据，使用统一的数据模块
end

-- 获取换签消耗
local function getChangeCost()
    return GhostMarketData.getResignCost()
end

-- 刷新界面
local function refreshView()
    if not _dlg then return end

    local data = GhostMarketData.getData()
    if not data then
        _dlg.info:ClearString()
        return
    end

    -- 构建提示信息
    local infoText = "#33186改签必换一运，结果不可预期！\n"

    -- 显示剩余免费改签次数
    local freeCount = GhostMarketData.getFreeResignTimes()
    infoText = infoText .. "#04739当前免费改签次数：" .. freeCount .. "\n"
    infoText = infoText .. "#65535\n"
    infoText = infoText .. "#30989掌柜提示\n"
    infoText = infoText .. "#30989·每期开市将自动恢复免费改签次数\n"
    infoText = infoText .. "#30989·免费次数用尽后，需付代价方可改签\n"
    infoText = infoText .. "#33186----------------------------------\n"

    -- 显示本次换签消耗
    local cost, costDesc = getChangeCost()
    if cost == -1 then
        infoText = infoText .. "#04739本期改签次数已达上限\n"
    elseif cost == 0 then
        infoText = infoText .. "#04739本次消耗：#63488免费次数-1\n"
    else
        infoText = infoText .. "#04739本次消耗：#63488" .. costDesc .. "\n"
    end

    _dlg.info:ClearString()
    _dlg.info:AddString(infoText)
end

-- 事件处理
local function onEventProc(luadlg, eventCode, ctrlId, ctrl)
    if eventCode == UIEventDef.TBN_CLICKED then
        if ctrlId == luadlg.Confirm.CtrlID then
            -- 确认按钮
            -- 先检查银元宝是否足够
            local cost, _ = getChangeCost()
            if cost > 0 then
                -- 需要消耗银元宝，检查是否足够
                local dataitem = game:UIDataItem()
                if dataitem:GetSilverStone() < cost then
                    game:ShowMessage("#ff6565#改签本金不足，请备好再来")
                    return
                end
            end
            
            -- 银元宝足够或使用免费次数，执行改签
            local uimgr = game:LuaUIMgr()
            local marketDlg = FindLuaDlg(uimgr:FindDlg("GhostMarket"))
            luadlg.Raw:ShowDlg(false)
            marketDlg.ChangeLottery()
        elseif ctrlId == luadlg.Cancel.CtrlID then
            -- 取消按钮
            luadlg.Raw:ShowDlg(false)
        elseif ctrlId == luadlg.Close.CtrlID then
            -- 关闭按钮
            luadlg.Raw:ShowDlg(false)
        end
    end
end

-- 显示状态改变
local function onShow(luadlg, show)
    if show then
        refreshView()
    else
        reset()
    end
end

-- 创建对话框
local function createDlg(dlgmgr)
    local luadlg = dlgbuilder(dlgmgr, struct, prefix_path, 3000)
    _dlg = luadlg

    luadlg.OnEventProc = onEventProc
    luadlg.OnShow = onShow

    reset()
    refreshView()

    return luadlg
end

return {
    OnCreate = createDlg, 
}

