local events = {}

local Event = {}
Event.__index = Event

function Event:New()
  local obj = {}
  setmetatable(obj, Event)
  obj.handlers = {}
  return obj
end

function Event:Add(handler)
    table.insert(self.handlers,handler)
end

function Event:Remove(handler)
    for k,v in ipairs(self.handlers) do
        if v==handler then
            self.handlers[k] = nil
            return
        end
    end
end

function Event:Trigger(...)
    for k,v in ipairs(self.handlers) do
        v(...)
    end
end

events.GameLogin = Event:New()
function OnGameLogin()
    Info("OnGameLogin")
    events.GameLogin:Trigger()
end

events.GameLogout = Event:New()
function OnGameLogout()
    Info("OnGameLogout")
    events.GameLogout:Trigger()
end

events.CheatConfigLoaded = Event:New()
function OnCheatConfigLoaded()
    Info("OnCheatConfigLoaded")
    events.CheatConfigLoaded:Trigger()
end

events.LuaReload = Event:New()
function OnReload()
    Info("OnReload")
    events.LuaReload:Trigger()
end

events.ButtonClicked = Event:New()
function OnButtonClicked(wndname, buttonId)
    events.ButtonClicked:Trigger(wndname,buttonId)
end

events.OnShowUIWindow = Event:New()
function OnShowUIWindow(wndname, bShow)
    events.OnShowUIWindow:Trigger(wndname,bShow)
end

events.GameUpdate = Event:New()
function OnGameUpdate()
    events.GameUpdate:Trigger()
end

events.NpcTradeSale = Event:New()
function OnNpcTradeSale()
    Info("OnNpcTradeSale")
    events.NpcTradeSale:Trigger()
end 

events.RequestJoinTeam = Event:New()
function OnRequestJoinTeam(playerID)
    Info("OnRequestJoinTeam playerID="..tostring(playerID))
    events.RequestJoinTeam:Trigger(playerID)
end

events.EnterFight = Event:New()
function OnEnterFight()
    Info("OnEnterFight")
    events.EnterFight:Trigger()
end

events.BeginFight = Event:New()
function OnBeginFight()
    Info("OnBeginFight")
    events.BeginFight:Trigger()
end

events.LeaveFight = Event:New()
function OnLeaveFight()
    Info("OnLeaveFight")
    events.LeaveFight:Trigger()
end

events.ShowDialog = Event:New()
function OnShowDialog(content,opts)
    if content == nil then
        content = ""
    end
    Info("OnShowDialog")
    --Debug("content="..content)
    --for k,v in pairs(opts) do
    --    Debug(tostring(k)..":"..v)
    --end
    events.ShowDialog:Trigger(content,opts)
end

events.UpdateMapBuff = Event:New()
function OnUpdateMapBuff(buffs)
    Info("OnUpdateMapBuff")
    events.UpdateMapBuff:Trigger(buffs)
end

events.UpdateArtifact = Event:New()
function OnUpdateArtifact(artifacts)
    Info("OnUpdateArtifact")
    events.UpdateArtifact:Trigger(artifacts)
end

return events