local gamestate = require("game_state")

local MoveAction = {}
MoveAction.__index = MoveAction

function MoveAction:New(mapid,pos)
  local obj = {}
  setmetatable(obj, MoveAction)
  obj.mapid = mapid
  obj.pos = pos
  return obj
end

function MoveAction:checkDis()
    local playerObj = game:MainPlayerObj()
    if (playerObj.X-self.pos.x)*(playerObj.X-self.pos.x)+(playerObj.Y-self.pos.y)*(playerObj.Y-self.pos.y)<=50*50 then
        return true
    end
    return false
end

function MoveAction:moveTo()
    local cur = os.clock()
    if (self.lastMoveTime==nil) or cur-self.lastMoveTime>2 then
        local curmapid = game:GetMapID()
        if(curmapid~=self.mapid)then
            return
        end
        game:MoveTo(self.pos.x,self.pos.y);
        self.lastMoveTime = cur
        return
    end
end

function MoveAction:Start(executor,...)
    self:moveTo()
end

function MoveAction:Update(executor)
    if gamestate.isInFight then
        return
    end
   if self:checkDis() then
        --到达后延迟两秒
        if self.delayTime~=nil then
            if os.clock()>self.delayTime then
                executor:GotoNext()
            end
            return
        end
        self.delayTime = os.clock()+2
        return
    end
    self:moveTo()
end

function MoveAction:Pause()
    --停止移动
    local playerObj = game:MainPlayerObj()
    game:MoveTo(playerObj.X,playerObj.Y);
end

function MoveAction:Cancel()
    --停止移动
    local playerObj = game:MainPlayerObj()
    game:MoveTo(playerObj.X,playerObj.Y);
end

return MoveAction