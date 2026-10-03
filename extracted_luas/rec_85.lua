local events = require("events")
local gamestate = require("game_state")

local Action = {}
Action.__index = Action

function Action:New(npcid)
  local obj = {}
  setmetatable(obj, Action)
  obj.npcid = npcid
  return obj
end


function Action:Start(executor)
    self.handler = function(content,opts)
        self:onShowDialog(content,opts)
    end
    events.ShowDialog:Add(self.handler)
    game:ClickNpc(self.npcid)
    self.starttime = os.clock()
end

function Action:Update(executor)
    if gamestate.isInFight then
        return
    end

    if os.clock()-self.starttime<1 then
        return
    end

    if self.content ~= nil then
        executor:GotoNext(self.content,self.opts)
    end
end

function Action:onShowDialog(content,opts)
    self.content = content
    self.opts = opts
    if self.handler then
        events.ShowDialog:Remove(self.handler)
        self.hanler = nil
    end
end

function Action:Cancel()
    if self.handler then
        events.ShowDialog:Remove(self.handler)
        self.hanler = nil
    end
end

return Action