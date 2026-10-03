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
    --Debug("menu="..self.menu)
    --Debug("content="..content)
    for k,v in pairs(opts) do
        --Debug("opt["..tostring(k).."]"..v)
        if string.find(v,self.menu)~=nil then
            game:SelectNpcDialogEntry(k+1)
            break
        end
    end
    self.startTime = os.clock()
end

function Action:Update(executor)
    if gamestate.isInFight then
        return
    end

    if os.clock()-self.startTime>2 then
        executor:GotoNext(self.content,self.opts)
        return
    end
end

return Action