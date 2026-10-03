--自动采集
require "math"

local gamestate = require("game_state")
local events = require("events")

local actionTime = 2
local defaultTime = 0.2
local waitTime = defaultTime   --表示多少时间间隔会觉察一次外部数据
local lastTime = 0

local HitDistance = 200

local function gameUpdate()
    local cur = os.clock()
    if(cur-lastTime<waitTime)then
        return
    end
    lastTime = cur

    if(not gamestate.isLogin)then
        return
    end
    if(gamestate.isInFight)then
        return
    end
    if(not gamestate.isCheatConfigLoaded)then
        return
    end

    local cheat = game:GetCheatScript()

    local doAction = false

    if(cheat:IsAutoGatherEnabled()~=0)then
        local playerObj = game:MainPlayerObj()
        local x = playerObj.X
        local y = playerObj.Y
        local npcs,names = game:GetAllNpcObjs()
        for id,name in pairs(names)do
            if(name==cheat:GetGatherName1() or name==cheat:GetGatherName2())then
                --看看距离
                local obj = npcs[id]
                if obj~=nil then
                    local npcx = obj.X
                    local npcy = obj.Y
                    if (x-npcx)*(x-npcx)+(y-npcy)*(y-npcy)<HitDistance*HitDistance then
                        Info("Click NPC "..name)
                        game:ClickNpc(id)
                    end
                end
            end
        end
    end

    if(doAction)then
        waitTime = actionTime
    else
        waitTime = defaultTime --恢复敏感度
    end
end

events.GameUpdate:Add(gameUpdate)