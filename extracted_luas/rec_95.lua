local gamestate = require("game_state")
local events = require("events")

local Action = {}
Action.__index = Action

function Action:New(menu)
  local obj = {}
  setmetatable(obj, Action)
  obj.menu = menu
  return obj
end

function Action:Start(executor,content,opts)
    self.handler = function()
        self:onLeaveFight()
    end
    events.LeaveFight:Add(self.handler)
    for k,v in pairs(opts) do
        if string.find(v,self.menu)~=nil then
            game:SelectNpcDialogEntry(k+1)
            break
        end
    end
end

function Action:Update(executor)
    if gamestate.isInFight then
        return
    end

    if self.complete then
        executor:GotoNext()
    end
end

function Action:onLeaveFight()
    self.complete = true
    if self.handler ~=nil then
        events.LeaveFight:Remove(self.handler)
        self.handler = nil
    end
end

function Action:Cancel()
    if self.handler then
        events.LeaveFight:Remove(self.handler)
        self.hanler = nil
    end
end

return Action