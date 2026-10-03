local dlgbuilder = require "dlg_builder"
local ScriptEvent = require "script_event"

local struct = require "uicompetitivepvpmatchpanel_struct"
local prefix_path = "UIGame/UIActivity/pvp"
local events = require("events")

local _matchNameImg
local _matchInfo
local _dlg = nil
local _waitTime = -1    -- 倒计时, -1表示不显示
local _ProgressMsg = '' -- 缓存进度信息字符串
local _ScoreMsg = ''        -- 缓存个人信息字符串

local _lastTime = 0    -- 最后一次更新的时间
local _isInFight

local function reset()
    _lastTime = 0
end


local function resetView()
    if _dlg then

    end
end

local function refreshView()
    local msg = "#6AF677#赛场状态：\n#C2F1C8#" .. _ProgressMsg
    msg = msg .. "\n"
    msg = msg .. "\n#ffff00#---------------------------------------"
    msg = msg .. "\n#6AF677#个人状态：\n#C2F1C8#" .. _ScoreMsg
    if _waitTime > 0 then
        local timestr = GetTimeRemainFormatString(_waitTime)
        msg = msg .. "(剩余:" .. timestr .. ")"
    end
    msg = msg .. "\n"
    msg = msg .. "\n#ffff00#---------------------------------------"

    if _dlg then
        _dlg.MatchInfo:ClearText()
        _dlg.MatchInfo:AddString(msg, false)
    end
end

local function onEventProc(luadlg,eventCode,ctrlId,ctrl)
    local mgr = game:LuaUIMgr()
    if eventCode==UIEventDef.TBN_CLICKED and ctrlId==luadlg.CloseBtn.CtrlID then
        luadlg.Raw:ShowDlg(false)
    elseif eventCode==UIEventDef.TBN_CLICKED and ctrlId==luadlg.FightTeams.CtrlID then
        local teamdlg = mgr:FindDlg("UICompetitivePVPFightTeam")
        if teamdlg then
            local isshow = teamdlg:GetVisible() == 1
            teamdlg:ShowDlg(not isshow)
        end
    elseif eventCode == UIEventDef.TBN_CLICKED and ctrlId == luadlg.FightJournal.CtrlID then
        local journaldlg = mgr:FindDlg("UICompetitivePVPFightJournal")
        if journaldlg then
            local isshow = journaldlg:GetVisible() == 1
            journaldlg:ShowDlg(not isshow)
        end
    end
end

local function onShow(luadlg,show)
    local mgr = game:LuaUIMgr()
    resetView()
    if show then
        refreshView()
    else
        local teamdlg = mgr:FindDlg("UICompetitivePVPFightTeam")
        if teamdlg then
            teamdlg:ShowDlg(false)
        end
        local journaldlg = mgr:FindDlg("UICompetitivePVPFightJournal")
        if journaldlg then
            journaldlg:ShowDlg(false)
        end
    end
end

local function OnMove(luadlg, offx, offy)
    local mgr = game:LuaUIMgr()

    local teamdlg = mgr:FindDlg("UICompetitivePVPFightTeam")
    if teamdlg and teamdlg:GetVisible() == 1 then
        teamdlg:SetPosition(luadlg.Raw:Right() - 16, luadlg.Raw:Bottom())
    end

    local journaldlg = mgr:FindDlg("UICompetitivePVPFightJournal")
    if journaldlg and journaldlg:GetVisible() == 1 then
        journaldlg:SetPosition(luadlg.Raw:Left() + 75, luadlg.Raw:Bottom())
    end

end

local function gameUpdate()
    local cur = os.clock()

    if _waitTime > 0 then
        if cur - _lastTime >= 1 then
            _waitTime = _waitTime - 1
            _lastTime = _lastTime + 1
            refreshView()
        end
    end

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


local function onCallScript(dlg,event,obj)
    Debug("pvp onCallScript event="..tostring(event))
    if event==ScriptEvent.UpdateCompetitivePVPInfo then

        local show = true
        -- cmd : 3 = 显示信息, 2 = 关闭
        if obj.cmd == 2 then
            show = false
        elseif obj.cmd == 3 then
             _ProgressMsg = obj.msg1
            _waitTime = obj.waitTime
            _lastTime = os.clock()
            _ScoreMsg = obj.msg2
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
    luadlg.OnMove = OnMove
    luadlg.OnCallScript = onCallScript

    HandleCallScript(ScriptEvent.UpdateCompetitivePVPInfo, luadlg)

    --luadlg.Raw:SetPosition(605, 660)
    luadlg.Raw.Anchor = 15
    if luadlg.MatchNameImg then
        luadlg.MatchNameImg:SetEnable(0)
    end

    _dlg = luadlg
    reset()
    refreshView()
    return luadlg
end

return {OnCreate=createDlg}
