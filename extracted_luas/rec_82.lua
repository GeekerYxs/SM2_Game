local gamestate = require("game_state")
local events = require("events")

local Action = {}
Action.__index = Action

function Action:New(content,next)
  local obj = {}
  setmetatable(obj, Action)
  obj.content = content
  obj.next = next
  return obj
end

function Action:Start(executor,content,opts)
    self.checkOK = false
    if string.find(content,self.content)~=nil then
        self.checkOK = true
    else
        self.content = content
        self.opts = opts
    end
    self.starttime = os.clock()
end

function Action:Update(executor)
    if gamestate.isInFight then
        return
    end

    if os.clock()-self.starttime<2 then
        return
    end

    if self.checkOK then
        executor:GotoNext(self.content,self.opts)
    else
        executor:GotoAction(self.next,self.content,self.opts)
    end
end

return Action