local gamestate = require("game_state")
local events = require("events")

local Action = {}
Action.__index = Action

function Action:New(delay)
  local obj = {}
  setmetatable(obj, Action)
  obj.delay = delay
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

    if os.clock()-self.starttiem<self.delay then
        return
    end

    executor:GotoNext(unpack(self.args))
end

return Action