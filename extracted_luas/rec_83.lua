local gamestate = require("game_state")
local events = require("events")

local Action = {}
Action.__index = Action

function Action:New(taskId,posx,posy,next)
  local obj = {}
  setmetatable(obj, Action)
  obj.taskId = taskId
  obj.posx = posx
  obj.posy = posy
  obj.next = next
  return obj
end

function Action:Start(executor,...)
    self.args = {...}
    self.checkOK = false
    local x,y = game:ParseInstanceLoopPos(self.taskId)
    if x==self.posx and y==self.posy then
        self.checkOK = true
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
        executor:GotoNext(unpack(self.args))
    else
        executor:GotoAction(self.next,unpack(self.args))
    end
end

return Action