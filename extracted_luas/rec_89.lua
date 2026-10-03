local gamestate = require("game_state")
local events = require("events")

local Action = {}
Action.__index = Action

function Action:New(complete)
  local obj = {}
  setmetatable(obj, Action)
  obj.complete = complete
  return obj
end

function Action:Start(executor)
end

function Action:Update(executor)
    if gamestate.isInFight then
        return
    end

    executor:Complete(self.complete)
end

return Action