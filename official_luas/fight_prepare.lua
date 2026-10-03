local Module = {}

local delay = -1
local petDelay = -1
local isPrepareOK = false
local isPetPrepareOK = false

local function start()
    local AutoFight = require("auto_fight")
    isPrepareOK = false
    isPetPrepareOK = false
    local cheat = game:GetCheatScript()
    local fightCfgIdx = cheat:GetFightConfigIndex()
    if cheat:IsSelectPlayerFirstTargetEnabled(fightCfgIdx)~=0 then
        AutoFight.AttackTarget = cheat:GetPlayerFirstTargetIndex(fightCfgIdx)
    end
    if cheat:IsSelectPetFirstTargetEnabled(fightCfgIdx)~=0 then
        AutoFight.PetAttackTarget = cheat:GetPetFirstTargetIndex(fightCfgIdx)
    end
end

local function doAction()
    delay = -1
    local cheat = game:GetCheatScript()
    local fightCfgIdx = cheat:GetFightConfigIndex()
    if cheat:IsPlayerDelayActionEnabled(fightCfgIdx)~=0 then
        delay = cheat:GetPlayerDelayActionSP(fightCfgIdx)
    end

    if delay <= 0 then
        return false
    end
    if isPrepareOK then
        return false
    end

    local myPos = game:GetMyPos()
    local fighter = game:GetFighter(myPos)
    if fighter.SP < delay then
        --锟斤拷锟斤拷锟饺达拷锟斤拷
        return true
    end

    isPrepareOK = true
    return false
end

local function doPetAction()
    petDelay = -1
    local cheat = game:GetCheatScript()
    local fightCfgIdx = cheat:GetFightConfigIndex()

    if cheat:IsPetDelayActionEnabled(fightCfgIdx)~=0 then
        petDelay = cheat:GetPetDelayActionSP(fightCfgIdx)
    end

    if petDelay <= 0 then
        return false
    end
    if isPetPrepareOK then
        return false
    end

    local myPetPos = game:GetMyPetPos()
    local fighter = game:GetFighter(myPetPos)
    if fighter.SP < petDelay then
        --锟斤拷锟斤拷锟饺达拷锟斤拷
        return true
    end

    isPetPrepareOK = true
    return false
end

Module.Start = start
Module.DoAction = doAction
Module.DoPetAction = doPetAction

return Module