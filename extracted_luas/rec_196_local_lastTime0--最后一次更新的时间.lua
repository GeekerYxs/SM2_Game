local dlgbuilder = require "dlg_builder"
local ScriptEvent = require "script_event"

local struct = require "uicompetitivepvpfightjournal_struct"
local prefix_path = "UIGame/UIActivity/pvp"
local events = require("events")

local _dlg = nil

local _lastTime = 0    -- 最后一次更新的时间
local _isInFight

-- 对战信息: { round = i, pairNames = pairNames, result = 0}
-- 结果(0=失败,1=胜利)
local _FightResultInfoList = nil


local function reset()
    _lastTime = 0
    _FightResultInfoList = nil
end


local function resetView()
    if _dlg then
        _dlg.Item1.fightRes:ClearString()
        _dlg.Item2.fightRes:ClearString()
        _dlg.Item3.fightRes:ClearString()
        _dlg.Item4.fightRes:ClearString()
        _dlg.Item5.fightRes:ClearString()

        _dlg.Item1.opponent:ClearString()
        _dlg.Item2.opponent:ClearString()
        _dlg.Item3.opponent:ClearString()
        _dlg.Item4.opponent:ClearString()
        _dlg.Item5.opponent:ClearString()
    end
end

local function refreshView()
    resetView()
    if not _FightResultInfoList then
        return
    end
    if _dlg then
        for i = 1, 5 do
            -- { round = 1, roundName = winRoundName, pairNames = pairNames, result = 0}
            -- 结果(0=失败,1=胜利)
            local resultlog = _FightResultInfoList[i]
            if resultlog then
                local item = _dlg["Item" .. i]
                if item then
                    item.opponent:ClearString()
                    item.opponent:AddString(resultlog.roundName .. "对手:#0070C0#" .. resultlog.pairNames)

                    item.fightRes:ClearString()
                    if resultlog.result == 1 then
                        item.fightRes:AddString("对战结果:#FF0000#胜利")
                    else
                        item.fightRes:AddString("对战结果:#FF0000#失败")
                    end
                end
            end
        end
        if #_FightResultInfoList == 0 then
            local item = _dlg.Item1
            if item then
                item.opponent:ClearString()
                item.opponent:AddString("暂无数据")
            end
        end
    end
end

local function onEventProc(luadlg,eventCode,ctrlId,ctrl)

end

local function onShow(luadlg,show)
    if show then

        reset();
        refreshView()

        local mgr = game:LuaUIMgr()
        local panel = mgr:FindDlg("UICompetitivePVPMatchPanel")
        if panel then
            local x, y = panel:Left(), panel:Bottom()
            luadlg.Raw:SetPosition(x + 75, y)
        end

        -- 请求对战日志信息
        game:SendCallScriptPacket(ScriptEvent.UpdateCompetitivePVPInfo, {cmd = 1})

    end
end

local function gameUpdate()
    local cur = os.clock()


end
events.GameUpdate:Add(gameUpdate)

local function onFightBegin()
    if game:IsWatchFight() then
        return
    end
    _isInFight = true

end

local function onFightLeave()
    _isInFight = false

end

events.BeginFight:Add(onFightBegin)
events.LeaveFight:Add(onFightLeave)

local function OnGameLogout()
    if _dlg then
        _dlg.Raw:ShowDlg(false)
    end
end
events.GameLogout:Add(OnGameLogout)

local function onCallScript(dlg,event,obj)
    Debug("pvp onCallScript event="..tostring(event))
    if event==ScriptEvent.UpdateCompetitivePVPInfo then

        local show = false
        -- cmd : 5 = 作战日志
        if obj.cmd == 5 then
            _FightResultInfoList = obj.fightLogs
            if not _isInFight then
                show = true
            end
        elseif obj.cmd == 2 then
            show = false
        end
        refreshView()

        local isshow = dlg.Raw:GetVisible() == 1
        if show ~= isshow then
            --dlg.Raw:ShowDlg(show)
        end
    end
end

local function createDlg(dlgmgr)
    local luadlg = dlgbuilder(dlgmgr,struct,prefix_path,3000)
    luadlg.OnEventProc = onEventProc
    luadlg.OnShow = onShow
    luadlg.OnCallScript = onCallScript

    HandleCallScript(ScriptEvent.UpdateCompetitivePVPInfo, luadlg)

    --luadlg.Raw:SetPosition(605, 660)
    luadlg.Raw.Anchor = 15

    _dlg = luadlg
    reset()
    refreshView()
    return luadlg
end

return {OnCreate=createDlg}
