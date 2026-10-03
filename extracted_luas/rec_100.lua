local gamestate = require("game_state")

local Action = {}
Action.__index = Action

function Action:New(mapid,pos,tomapid)
  local obj = {}
  setmetatable(obj, Action)
  obj.mapid = mapid
  obj.pos = pos
  obj.tomapid = tomapid
  return obj
end

function Action:checkDis()
    local playerObj = game:MainPlayerObj()
    if (playerObj.Y-self.pos.x)*(playerObj.Y-self.pos.x)+(playerObj.Y-self.pos.y)*(playerObj.Y-self.pos.y)<=50*50 then
        return true
    end
    return false
end

function Action:moveTo()
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

function Action:Start(executor,...)
    self:moveTo()
end

function Action:Update(executor)
    if gamestate.isInFight then
        return
    end
    local curmapid = game:GetMapID()
    if curmapid==self.tomapid then
        executor:GotoNext()
        return
    end
    self:moveTo()
end

function Action:Pause()
    --Í£Ö¹ÒÆ¶¯
    local playerObj = game:MainPlayerObj()
    game:MoveTo(playerObj.X,playerObj.Y);
end

function Action:Cancel()
    --Í£Ö¹ÒÆ¶¯
    local playerObj = game:MainPlayerObj()
    game:MoveTo(playerObj.X,playerObj.Y);
end

return Action