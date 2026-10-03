local Module = {}

local gamestate = require("game_state")
local events = require("events")
local CatchPet = require("catch_pet")
local AutoRelive = require("auto_relive")
local AutoRecover = require("auto_recover")
local SkillList = require("fight_skill_list")
local FightPrepare = require("fight_prepare")

local isFightBegin = false
local lastSP = -1
local lastPetSP = -1

Module.AttackTarget = 2
Module.PetAttackTarget = 2

local function start()
    Debug("fight ai start")
    --开始准备
    if FightPrepare.Start then
        FightPrepare.Start()
    end
    --复活
    if AutoRelive.Start then
        AutoRecover.Start()
    end
    --恢复
    if AutoRecover.Start then
        AutoRecover.Start()
    end
    --抓宠
    if CatchPet.Start then
        CatchPet.Start()
    end
    --技能列表
    if SkillList.Start then
        SkillList.Start()
    end
end

local function myAction()
    --开始准备
    if FightPrepare.DoAction() then
        return
    end
    --复活
    if AutoRelive.DoAction() then
        return
    end
    --恢复
    if AutoRecover.DoAction() then
        return
    end
    --抓宠
    if CatchPet.DoAction() then
        return
    end
    --技能列表
    if SkillList.DoAction() then
        return
    end
end

local function myPetAction()
    --开始准备
    if FightPrepare.DoPetAction() then
        return
    end
    --复活
    if AutoRelive.DoPetAction() then
        return
    end
    --恢复
    if AutoRecover.DoPetAction() then
        return
    end
    --技能列表
    if SkillList.DoPetAction() then
        return
    end
end

local function gameUpdate()
    if not isFightBegin then
        return
    end
    if not game:IsEnableAutoFight() then
        return
    end
    local cheat = game:GetCheatScript()
    if cheat:IsAutoFightEnabled()==0 then
        return
    end
    --战斗中才思考
    local myPos = game:GetMyPos()
    local myPetPos = game:GetMyPetPos()
    local my = game:GetFighter(myPos)
    local myPet = game:GetFighter(myPetPos)
    if my~=nil and my.IsDead==0 and my.SP~=lastSP then
        lastSP = my.SP
        myAction()
    end
    if myPet~=nil and myPet.IsDead==0 and myPet.SP~=lastPetSP then
        lastPetSP = myPet.SP
        myPetAction()
    end
end

local function onFightBegin()
    if game:IsPKFight() then
        return
    end
    if game:IsWatchFight() then
        return
    end
    isFightBegin = true
    start()
end

local function onFightLeave()
    isFightBegin = false
end

events.GameUpdate:Add(gameUpdate)
events.BeginFight:Add(onFightBegin)
events.LeaveFight:Add(onFightLeave)

return Module