local gamestate = require("game_state")
local events = require("events")

local Action = {}
Action.__index = Action

function Action:New(menu,tomapid)
  local obj = {}
  setmetatable(obj, Action)
  obj.menu = menu
  obj.tomapid = tomapid
  return obj
end

function Action:Start(executor,content,opts)
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

    local curmapid = game:GetMapID()
    if curmapid==self.tomapid then
        executor:GotoNext()
        return
    end
end

return Action