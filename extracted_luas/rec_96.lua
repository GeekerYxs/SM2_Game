local gamestate = require("game_state")
local events = require("events")

local Action = {}
Action.__index = Action

function Action:New(menu,next)
  local obj = {}
  setmetatable(obj, Action)
  obj.menu = menu
  obj.next = next
  return obj
end

function Action:Start(executor,content,opts)
    self.enterHandler = function()
        self:onEnterFight()
    end
    events.EnterFight:Add(self.enterHandler)
    for k,v in pairs(opts) do
        if string.find(v,self.menu)~=nil then
            game:SelectNpcDialogEntry(k+1)
            break
        end
    end
    self.starttime = os.clock()
end

function Action:Update(executor)
    if gamestate.isInFight then
        return
    end

    if os.clock()-self.starttime < 2 then
        return
    end

    if not self.checkOK then
        --没等到战斗
        executor:GotoAction(self.next)
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