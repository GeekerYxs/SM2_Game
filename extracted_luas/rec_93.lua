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
    self.startime = os.clock()
end

function Action:Update(executor)
    if gamestate.isInFight then
        return
    end

    if os.clock()-self.startime<1 then
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