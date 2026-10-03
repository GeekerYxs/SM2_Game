local gamestate = require("game_state")
local events = require("events")

local Action = {}
Action.__index = Action

function Action:New(next)
  local obj = {}
  setmetatable(obj, Action)
  obj.next = next 
  return obj
end

function Action:Start(executor,...)
    self.args = {...}
    self.starttiem = os.clock()
end

function Action:Update(executor)
    if gamestate.isInFight then
        return
    end

    if os.clock()-self.starttiem<2 then
        return
    end

    executor:GotoAction(self.next,unpack(self.args))
end

return Action