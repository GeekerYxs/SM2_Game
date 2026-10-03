local Executor = {}
Executor.__index = Executor

function Executor:New(actions,completeAction)
  local obj = {}
  setmetatable(obj, Executor)
  obj.actions = actions
  obj.completeAction = completeAction
  return obj
end

function Executor:Start()
    if #self.actions==0 then
        if self.completeAction then
            self.completeAction(true)
        end
        return
    end
    Debug("execute "..self.actions[1].Name)
    self.actions[1]:Start()
end

function Executor:Update()
    if #self.actions==0 then
        return
    end
    self.actions[1]:Update(self)
end

function Executor:GotoNext(...)
    if #self.actions==0 then
        return
    end
    table.remove(self.actions,1)
    if #self.actions==0 then
        if self.completeAction then
            self.completeAction(...)
        end
        return
    else
        Debug("execute "..self.actions[1].Name)
        self.actions[1]:Start(self,...)
    end
end

function Executor:GotoAction(next,...)
    --ÒÆ³ýÄ¿Ç°µÄ
    table.remove(self.actions,1)
    local nextAct = nil
    while #self.actions>0 do
        local act = self.actions[1]
        if act.Name==next then
            nextAct = act
            break
        end
        Debug("Ignore "..act.Name)
        table.remove(self.actions,1)
    end
    if nextAct~=nil then
        nextAct:Start(self,...)
    end
end

function Executor:Complete(...)
    self.actions = {}
    if self.completeAction then
        self.completeAction(...)
    end
end

function Executor:Cancel()
    if self.actions and #self.actions>=1 then
        if self.actions[1].Cancel then
            self.actions[1]:Cancel()
        end
    end
end

function Executor:Pause()
    if self.actions and #self.actions>=1 then
        if self.actions[1].Pause then
            self.actions[1]:Pause()
        end
    end
end

function Executor:Continue()
    if self.actions and #self.actions>=1 then
        if self.actions[1].Continue then
            self.actions[1]:Continue()
        end
    end
end

return Executor