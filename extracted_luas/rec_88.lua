local gamestate = require("game_state")
local events = require("events")

local Action = {}
Action.__index = Action

function Action:New()
  local obj = {}
  setmetatable(obj, Action)
  return obj
end

function Action:Start(executor)
    game:CloseDialog()
    self.starttiem = os.clock()
end

function Action:Update(executor)
    if gamestate.isInFight then
        return
    end

    if os.clock()-self.starttiem<2 then
        return
    end

    executor:GotoNext()
end

return Action