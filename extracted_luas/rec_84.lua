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
    self.content = content
    self.opts = opts
    self.checkOK = false
    for k,v in pairs(opts) do
        if string.find(v,self.menu)~=nil then
            self.checkOK = true
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

    if self.checkOK then
        executor:GotoNext(self.content,self.opts)
    else
        Debug("content="..tostring(self.content).." opts="..tostring(self.opts))
        executor:GotoAction(self.next,self.content,self.opts)
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