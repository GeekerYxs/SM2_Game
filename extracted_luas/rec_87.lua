local events = require("events")
local gamestate = require("game_state")

local Action = {}
Action.__index = Action

function Action:New(npcs)
  local obj = {}
  setmetatable(obj, Action)
  obj.npcs = npcs
  obj.idx = 1
  return obj
end

function Action:Start(executor)
    self.enterHandler = function()
        self:onEnterFight()
    end
    events.EnterFight:Add(self.enterHandler)
    game:ClickNpc(self.npcs[self.idx])
    self.idx = ((self.idx+1)%(#self.npcs))+1
    self.starttime = os.clock()
end

function Action:Update(executor)
    if gamestate.isInFight then
        return
    end

    if os.clock()-self.starttime<2 then
        return
    end

    if not self.checkOK then
        --没等到战斗
        --点击下一个npc
        game:ClickNpc(self.npcs[self.idx])
        self.idx = ((self.idx+1)%(#self.npcs))+1
        self.starttime = os.clock()
        return
    end

    if self.complete then
        executor:GotoNext()
    end
end

function Action:onEnterFight()
    self.checkOK = true
    if self.enterHandler ~=nil then
        events.EnterFight:Remove(self.enterHandler)
        self.enterHandler = nil
    end
    self.handler = function()
        self:onLeaveFight()
    end
    events.LeaveFight:Add(self.handler)
end

function Action:onLeaveFight()
    self.complete = true
    if self.handler ~=nil then
        events.LeaveFight:Remove(self.handler)
        self.handler = nil
    end
end

function Action:Cancel()
    if self.enterHandler then
        events.EnterFight:Remove(self.enterHandler)
        self.enterHandler = nil
    end
    if self.handler then
        events.LeaveFight:Remove(self.handler)
        self.hanler = nil
    end
end

return Action