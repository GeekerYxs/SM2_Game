local ActionEcecutor = require("action_executor")
local ActionCreator = require("action_creator")
local Task = {}
Task.__index = Task

function Task:New(data,completeAction)
  local obj = {}
  setmetatable(obj, Task)
  obj.data = data
  obj.completeAction = completeAction
  obj.state = "pre"
  obj.actionExecutor = nil
  return obj
end

function Task:gotoMainState()
    self.state = "main"
    local actions = {}
    for _, v in pairs(self.data.steps) do
        table.insert(actions, ActionCreator.CreateAction(v))
    end
    self.actionExecutor = ActionEcecutor:New(actions, function(isCompleted)
        if isCompleted then
            self:gotoMainState()
        else
            self:gotoEndState()
        end
    end)
    self.actionExecutor:Start()
end

function Task:gotoEndState()
    self.state = "end"
    local actions = {}
    for _, v in pairs(self.data.endsteps) do
        table.insert(actions, ActionCreator.CreateAction(v))
    end
    self.actionExecutor = ActionEcecutor:New(actions, function(isCompleted)
        self.actionExecutor = nil
        if self.completeAction ~= nil then
            self.completeAction()
        end
    end)
end

function Task:Start()
    if self.data.presteps ~= nil then
        local actions = {}
        for _,v in pairs(self.data.presteps) do
            table.insert(actions,ActionCreator.CreateAction(v))
        end
        self.actionExecutor = ActionEcecutor:New(actions,function ()
            self:gotoMainState()
        end)
        self.actionExecutor:Start()
    else
        self:gotoMainState()
    end
end

function Task:Update()
    if self.actionExecutor~=nil then
        self.actionExecutor:Update()
    end
end

function Task:Cancel()
    if self.actionExecutor~=nil then
        self.actionExecutor:Cancel()
    end
end

function Task:Pause()
    if self.actionExecutor~=nil then
        self.actionExecutor:Pause()
    end
end

function Task:Continue()
    if self.actionExecutor~=nil then
        self.actionExecutor:Continue()
    end
end

return Task