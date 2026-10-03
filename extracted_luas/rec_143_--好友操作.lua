--ºÃÓÑ²Ù×÷
require "math"

local gamestate = require("game_state")
local events = require("events")

local HitDistance = 400

local function createTeam()
    Debug("check for join team")

    local playerObj = game:MainPlayerObj()
    local x = playerObj.X
    local y = playerObj.Y

    local cheat = game:GetCheatScript()
    local friendCount = cheat:GetFriendCount()
    for i=0,friendCount-1 do
        local friendConfig = cheat:GetFriendByIdx(i)
        if friendConfig.Checked ~= 0 then
            Debug("try request" .. friendConfig.Name)
            local friendObj = game:FindPlayerObj(friendConfig.PlayerID)
            if friendObj ~= nil then
                local fx = friendObj.X
                local fy = friendObj.Y
                if (x - fx) * (x - fx) + (y - fy) * (y - fy) < HitDistance * HitDistance then
                    Info("requst " .. friendConfig.Name)
                    game:RequestTeamJoin(friendConfig.PlayerID, friendConfig.Level, friendConfig.Profession,
                        friendConfig.Name)
                end
            end
        end
    end
end

local function onButtonClicked(wndname, buttonId)
    if buttonId==302 then
        createTeam()
    end
end

local function onRequestJoinTeam(playerID)
    Debug("onRequestJoinTeam "..tostring(playerID))
    local cheat = game:GetCheatScript()
    local friendCount = cheat:GetFriendCount()
    for i=0,friendCount-1 do
        local friendConfig = cheat:GetFriendByIdx(i)
        if friendConfig.Checked ~= 0 then
            if friendConfig.PlayerID==playerID then
                game:AcceptJoinTeam()
            end
        end
    end
end

events.ButtonClicked:Add(onButtonClicked)
events.RequestJoinTeam:Add(onRequestJoinTeam)