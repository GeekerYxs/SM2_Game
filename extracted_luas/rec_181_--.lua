-- ================================================================
-- 鬼市更换秘藏对话框
-- 显示更换秘藏的确认界面，包括消耗说明
-- ================================================================

local dlgbuilder = require "dlg_builder"
local ScriptEvent = require "script_event"
local ConfigHelper = require "ui.dlgs.ghost_market.ghost_market_config_helper"
local GhostMarketData = require "ui.dlgs.ghost_market.ghost_market_data"

local struct = require "uighostmarketchangetreasure_struct"
local prefix_path = "UIGame/UIGhostMarket"

local _dlg = nil

-- 重置数据
local function reset()
    -- 不再需要重置局部数据，使用统一的数据模块
end

-- 获取更换秘藏的花费
local function getChangeTreasureCost()
    return GhostMarketData.getTreasureRefreshCost()
end

-- 刷新界面
local function refreshView()
    if not _dlg then return end

    local data = GhostMarketData.getData()
    if not data then
        _dlg.Info:ClearString()
        return
    end

    -- 构建提示文本
    local infoText = "#33186若当前秘藏不合心意，本店可为你更换。\n"
	infoText = infoText .. "#33186新品定与原物不同，好坏仍看客官当下运势。\n"
    infoText = infoText .. "\n"
    infoText = infoText .. "#30989掌柜提示\n"
    infoText = infoText .. "#30989·更换不影响已取得的领取进度\n"
    infoText = infoText .. "#30989·更换次数越多，代价越高，请合理安排\n"
    infoText = infoText .. "#33186-----------------------------------------\n"

    -- 显示本次更换的花费
    local refreshTimes = data.treasureRefreshTimes or 0
    local guestPointCost, goldIngotCost, costDesc = getChangeTreasureCost()
    infoText = infoText .. string.format("#04739本期已更换：#63488 %d次#04739 | 本次消耗：#63488 %s\n", refreshTimes, costDesc)

    _dlg.Info:ClearString()
    _dlg.Info:AddString(infoText)
end

-- 发送更换秘藏命令
local function sendChangeTreasureCmd()
    local data = GhostMarketData.getData()
    if not data then
        game:ShowMessage("#d60000#数据错误")
        return
    end

    -- 检查是否有足够的资源
    local guestPointCost, goldIngotCost, costDesc = getChangeTreasureCost()

    if guestPointCost > 0 then
        local currentGuestPoint = GhostMarketData.getGuestPoints()
        if currentGuestPoint < guestPointCost then
            game:ShowMessage("#d60000#贵客点不足")
            return
        end
    end

    if goldIngotCost > 0 then
        -- 检查金元宝是否足够
        local goldStone = GhostMarketData.getGoldStone()
        if goldStone < goldIngotCost then
            game:ShowMessage("#d60000#金元宝不足")
            return
        end
    end

    Debug("sendChangeTreasureCmd")
    game:SendCallScriptPacket(ScriptEvent.GhostMarket_RefreshTreasureRequest, {})

    -- 关闭对话框
    _dlg.Raw:ShowDlg(false)
end

-- 处理UI事件
local function onEventProc(luadlg, eventCode, ctrlId, ctrl)
    if eventCode == UIEventDef.TBN_CLICKED then
        if ctrlId == luadlg.Change.CtrlID then
            -- 更换秘藏按钮
            sendChangeTreasureCmd()
        elseif ctrlId == luadlg.Close.CtrlID then
            -- 关闭按钮
            luadlg.Raw:ShowDlg(false)
        end
    end
end

-- 对话框显示回调
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

return {OnCreate = createDlg}

