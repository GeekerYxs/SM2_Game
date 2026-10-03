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
    self.handler = function(ncontent,nopts)
        self:onShowDialog(ncontent,nopts)
    end
    events.ShowDialog:Add(self.handler)
    for k,v in pairs(opts) do
        if string.find(v,self.menu)~=nil then
            game:SelectNpcDialogEntry(k+1)
            break
        end
    end
    self.starttiem = os.clock()
end

function Action:Update(executor)
    if gamestate.isInFight then
        return
    end

    if os.clock()-self.starttiem<2 then
        return
    end

    if self.content ~= nil then
        executor:GotoNext(self.content,self.opts)
        return
    end

    --等不到预期的结果
    events.ShowDialog:Remove(self.handler)
    self.handler = nil
    executor:GotoAction(self.next)
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