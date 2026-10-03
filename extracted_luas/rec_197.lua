local dlgbuilder = require "dlg_builder"
local ScriptEvent = require "script_event"

local struct = require "uicompetitivepvpfightteam_struct"
local prefix_path = "UIGame/UIActivity/pvp"
local events = require("events")

local teamLoseImgPath = prefix_path .. "/骷髅.mgff"
local teamInMatchImgPath = prefix_path .. "/交战.mgff"



local _dlg = nil

local _lastTime = 0    -- 最后一次更新的时间
local _isInFight

-- 队伍信息: { state = 淘汰标记, namelist = namelist }
local _TeamInfoList = nil
local _StartItem = 0

local function reset()
    _lastTime = 0
    _TeamInfoList = nil
    _StartItem = 0
end


local function resetView()
    if _dlg then
        _dlg.Item1.icon:SetImage("")
        _dlg.Item2.icon:SetImage("")
        _dlg.Item3.icon:SetImage("")
        _dlg.Item4.icon:SetImage("")
        _dlg.Item5.icon:SetImage("")
        _dlg.Item6.icon:SetImage("")
        _dlg.Item7.icon:SetImage("")
        _dlg.Item8.icon:SetImage("")

        _dlg.Item1.opponent:ClearString()
        _dlg.Item2.opponent:ClearString()
        _dlg.Item3.opponent:ClearString()
        _dlg.Item4.opponent:ClearString()
        _dlg.Item5.opponent:ClearString()
        _dlg.Item6.opponent:ClearString()
        _dlg.Item7.opponent:ClearString()
        _dlg.Item8.opponent:ClearString()

        _dlg.PrePage:SetVisible(0)
        _dlg.NextPage:SetVisible(0)

    end
end

local function refreshView()
    resetView()
    if not _TeamInfoList then
        return
    end

    if _dlg then
        for i = 1, 8 do
            -- 队伍信息: { state = 淘汰标记, namelist = namelist }
            local teaminfo = _TeamInfoList[i + _StartItem]
            if teaminfo then
                local item = _dlg["Item" .. i]
                if item then
                    if teaminfo.state == 1 then
                        item.icon:SetImage(teamLoseImgPath)
                    else
                        item.icon:SetImage(teamInMatchImgPath)
                    end
                    item.opponent:ClearString()
                    item.opponent:AddString(teaminfo.namelist)
                end
            end
        end
        if #_TeamInfoList == 0 then
            local item = _dlg.Item1
            if item then
                item.opponent:ClearString()
                item.opponent:AddString("暂无数据")
            end
        end

        if #_TeamInfoList > 8 then
            _dlg.PrePage:SetVisible(1)
            _dlg.NextPage:SetVisible(1)
        end

        if _StartItem > 0 then
            _dlg.PrePage:SetEnable(1)
        else
            _dlg.PrePage:SetEnable(0)
        end

        if _StartItem + 8 >= #_TeamInfoList then
            _dlg.NextPage:SetEnable(0)
        else
            _dlg.NextPage:SetEnable(1)
        end

    end
end

local function onEventProc(luadlg,eventCode,ctrlId,ctrl)
    local mgr = game:LuaUIMgr()
    if eventCode==UIEventDef.TBN_CLICKED and ctrlId==luadlg.PrePage.CtrlID then
        _StartItem = math.max(0, _StartItem - 8)
        refreshView()
    elseif eventCode==UIEventDef.TBN_CLICKED and ctrlId==luadlg.NextPage.CtrlID then
        if _StartItem + 8 > #_TeamInfoList then
            _StartItem = _StartItem + 8
            refreshView()
        end
    end
end

local function onShow(luadlg,show)
    if show then
        _TeamInfoList = nil
        refreshView()

        local mgr = game:LuaUIMgr()
        local panel = mgr:FindDlg("UICompetitivePVPMatchPanel")
        if panel then
            local x, y = panel:Right(), panel:Bottom()
            luadlg.Raw:SetPosition(x-16, y)
        end

        -- 请求队伍信息
        game:SendCallScriptPacket(ScriptEvent.UpdateCompetitivePVPInfo, {cmd = 2})

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

        --Info("UICompetitivePVPFightTeam::onCallScript, Event ScriptEvent.UpdateCompetitivePVPInfo = " .. TableToString(obj))

        local show = false
        -- cmd : 4 = 队伍列表
        if obj.cmd == 4 then
            _TeamInfoList = obj.teaminfos
            if not _isInFight then
                show = true
            end
        elseif obj.cmd == 2 then
            show = false
        end
        refreshView()

    end
end

local function createDlg(dlgmgr)
    local luadlg = dlgbuilder(dlgmgr,struct,prefix_path,3000)
    luadlg.OnEventProc = onEventProc
    luadlg.OnShow = onShow
    luadlg.OnCallScript = onCallScript

    HandleCallScript(ScriptEvent.UpdateCompetitivePVPInfo, luadlg)

    luadlg.Raw:ShowDlg(false)

    luadlg.PrePage:SetWndText("上一页")
    luadlg.PrePage:ShowButtonName(1)
    luadlg.PrePage:SetBtnOffset(1)

    luadlg.NextPage:SetWndText("下一页")
    luadlg.NextPage:ShowButtonName(1)
    luadlg.NextPage:SetBtnOffset(1)

    _dlg = luadlg
    reset()
    refreshView()
    return luadlg
end

return {OnCreate=createDlg}
