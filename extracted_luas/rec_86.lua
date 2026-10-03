local events = require("events")
local gamestate = require("game_state")

local Action = {}
Action.__index = Action

function Action:New(npcid,tomapid)
  local obj = {}
  setmetatable(obj, Action)
  obj.npcid = npcid
  obj.tomapid = tomapid
  return obj
end


function Action:Start(executor)
    game:ClickNpc(self.npcid)
end

function Action:Update(executor)
    if gamestate.isInFight then
        return
    end

    local curmapid = game:GetMapID()
    if curmapid==self.tomapid then
        executor:GotoNext()
        return
    end
end

return Action