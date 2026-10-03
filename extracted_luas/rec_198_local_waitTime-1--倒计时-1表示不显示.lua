local dlgbuilder = require "dlg_builder"
local ScriptEvent = require "script_event"

local struct = require "uicompetitivepvpinfobar_struct"
local prefix_path = "UIGame/UIActivity"
local events = require("events")

local _dlg = nil
local _showdlg = false
local _waitTime = -1    -- 倒计时, -1表示不显示
local _ProgressMsg = '' -- 缓存进度信息字符串
local _ScoreMsg = ''        -- 缓存个人信息字符串

local _lastTime = 0    -- 最后一次更新的时间
local _isInFight

local function reset()
    _waitTime = -1
    _lastTime = 0
    _ProgressMsg = ''
    _ScoreMsg = ''
end


local function resetView()
    if _dlg then
        _dlg.progress:ClearString()
        _dlg.score:ClearString()
    end
end

local function refreshView()
    local msg = _ProgressMsg
    if _waitTime > 0 then
        local timestr = GetTimeRemainFormatString(_waitTime)
        msg = AlignTextWithSpace(_ProgressMsg, 28) .. AlignTextWithSpace(timestr, 8, 8)
    end
    if _dlg then
        _dlg.progress:ClearString()
        _dlg.progress:AddString(msg)

        _dlg.score:ClearString()
        _dlg.score:AddString(_ScoreMsg)
    end
end

local function onEventProc(luadlg,eventCode,ctrlId,ctrl)
    local mgr = game:LuaUIMgr()

    if ctrlId==luadlg.bigbtn.CtrlID then

        local panel = mgr:FindDlg("UICompetitivePVPMatchPanel")
        if panel then
            panel:ShowDlg(true)
        end
    end
end

local function onShow(luadlg,show)
    resetView()
    if show then
        refreshView()
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
    if _dlg then
        _dlg.Raw:ShowDlg(false)
    end
end

local function onFightLeave()
    _isInFight = false
    if _dlg and _showdlg then
        _dlg.Raw:ShowDlg(true)
    end
end

events.BeginFight:Add(onFightBegin)
events.LeaveFight:Add(onFightLeave)

local function OnGameLogout()
    if _dlg then
        _dlg.Raw:ShowDlg(false)
        _showdlg = false
    end
end
events.GameLogout:Add(OnGameLogout)


local function onCallScript(dlg,event,obj)
    Debug("pvp onCallScript event="..tostring(event))
    if event==ScriptEvent.UpdateCompetitivePVPInfo then

        -- cmd : 1 = 显示信息, 2 = 关闭
        if obj.cmd == 1 then
            _ProgressMsg = obj.msg1
            _waitTime = obj.waitTime
            _lastTime = os.clock()
            _ScoreMsg = obj.msg2

            if not _isInFight then
                _showdlg = true
            end
        elseif obj.cmd == 2 then
            _showdlg = false
        end
        refreshView()

        local isshow = dlg.Raw:GetVisible() == 1
        if _showdlg ~= isshow then
            dlg.Raw:ShowDlg(_showdlg)
        end

    elseif event == ScriptEvent.PlayCompetitivePVPMagicEffect then
        local nMagicID = obj.magicid
        local x, y = game:GetPlayerPosition()
        game:PlayMagic(nMagicID, x, y+300)
    end
end

local function createDlg(dlgmgr)
    local luadlg = dlgbuilder(dlgmgr,struct,prefix_path,3000)
    luadlg.OnEventProc = onEventProc
    luadlg.OnShow = onShow
    luadlg.OnCallScript = onCallScript

    HandleCallScript(ScriptEvent.UpdateCompetitivePVPInfo, luadlg)
    HandleCallScript(ScriptEvent.PlayCompetitivePVPMagicEffect, luadlg)

    luadlg.Raw:SetPosition(605, 660)
    luadlg.Raw.Anchor = 4+8

    _dlg = luadlg
    reset()
    refreshView()
    return luadlg
end

return {OnCreate=createDlg}