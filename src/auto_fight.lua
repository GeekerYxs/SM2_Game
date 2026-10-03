-- ============================================================================
-- auto_fight.lua
-- 智能战斗驱动中枢 (SMSM2 Combat AI Master Controller)
-- 
-- 架构特性:
-- 1. 解除官方内挂死锁: 原生 Alt+Z 自动战斗与 F12 挂机勾选均可无缝激活 AI 思考
-- 2. 每回合开局 SP 重置感知，确保首回合毫秒级即时出手
-- 3. 完整向下兼容官方抓宠、复活、恢复流水线
-- ============================================================================

local Module = {}

local gamestate = require("game_state")
local events = require("events")
local CatchPet = require("catch_pet")
local AutoRelive = require("auto_relive")
local AutoRecover = require("auto_recover")
local SkillList = require("fight_skill_list")
local FightPrepare = require("fight_prepare")
local hasPatrol, err = pcall(require, "map_patrol")
if not hasPatrol then
    Warn("[auto_fight] 加载 map_patrol 异常: " .. tostring(err))
end

local isFightBegin = false
local lastSP = -1
local lastPetSP = -1
local playerActedInTurn = false
local petActedInTurn = false
local lastActionClock = 0
local lastPetActionClock = 0
local lastHpChecksum = -1
local lastFighterCount = -1

Module.AttackTarget = 2
Module.PetAttackTarget = 2

local function calcBattlefieldChecksum()
    local sum = 0
    local count = 0
    for pos = 0, 19 do
        local f = game:GetFighter(pos)
        if f ~= nil and f.IsDead == 0 and f.HP > 0 then
            sum = sum + f.HP
            count = count + 1
        end
    end
    return sum, count
end

local function start()
    Debug("fight ai start")
    -- 开始准备
    if FightPrepare.Start then
        FightPrepare.Start()
    end
    -- 复活
    if AutoRelive.Start then
        AutoRelive.Start()
    end
    -- 恢复
    if AutoRecover.Start then
        AutoRecover.Start()
    end
    -- 抓宠
    if CatchPet.Start then
        CatchPet.Start()
    end
    -- 技能列表与AI战术热重载
    pcall(function()
        package.loaded["fight_skill_list"] = nil
        local ok, mod = pcall(require, "fight_skill_list")
        if ok and mod then SkillList = mod end
    end)
    if SkillList.Start then
        SkillList.Start()
    end
end

local function myAction()
    -- 1. 战前准备
    if FightPrepare.DoAction and FightPrepare.DoAction() then
        return
    end
    -- 2. 紧急复活
    if AutoRelive.DoAction and AutoRelive.DoAction() then
        return
    end
    -- 3. 恢复
    if AutoRecover.DoAction and AutoRecover.DoAction() then
        return
    end
    -- 4. 抓宠优先
    if CatchPet.DoAction and CatchPet.DoAction() then
        return
    end
    -- 5. 核心技能与协同 AI 决策
    if SkillList.DoAction and SkillList.DoAction() then
        return
    end
end

local function myPetAction()
    -- 1. 战前准备
    if FightPrepare.DoPetAction and FightPrepare.DoPetAction() then
        return
    end
    -- 2. 紧急复活
    if AutoRelive.DoPetAction and AutoRelive.DoPetAction() then
        return
    end
    -- 3. 恢复
    if AutoRecover.DoPetAction and AutoRecover.DoPetAction() then
        return
    end
    -- 4. 宠物技能与收割 AI 决策
    if SkillList.DoPetAction and SkillList.DoPetAction() then
        return
    end
end

local updateTick = 0
local function gameUpdate()
    if not isFightBegin then
        return
    end

    updateTick = updateTick + 1

    local isNativeAuto = game:IsEnableAutoFight()
    local cheat = game:GetCheatScript()
    local isCheatAuto = (cheat ~= nil and cheat.IsAutoFightEnabled and cheat:IsAutoFightEnabled() ~= 0)

    if updateTick % 60 == 1 then
        local myPos = game:GetMyPos()
        local my = game:GetFighter(myPos)
        local curSP = my and my.SP or -99
        Info(string.format("[auto_fight诊断] nativeAuto=%s, cheatAuto=%s, myPos=%d, SP=%d, lastSP=%d, acted=%s",
            tostring(isNativeAuto), tostring(isCheatAuto), myPos, curSP, lastSP, tostring(playerActedInTurn)))
    end

    -- AI 智能接管: 进入正式战斗后默认全自动接管出招，避免Alt+Z被点消或未勾选导致的30秒超时普攻死锁
    local curClock = os.clock()
    local curHpSum, curFighterCount = calcBattlefieldChecksum()

    -- 感知回合更迭与战斗动画结束:
    -- 1. 战场血量或存活人数变动 (说明回合动画已播放完毕并扣血结算) 且距离上次出招已超 2.0 秒
    -- 2. 快速重试兜底 (若有玩家阵亡或待命蓄力，超 1.5 秒即释放动作锁，防止12秒死锁延误复活)
    -- 3. 常规 6.0 秒绝对兜底 (缩短至6秒，防止战斗动画僵死)
    local hasDeadPlayer = false
    for checkPos = 15, 19 do
        local cf = game:GetFighter(checkPos)
        if cf ~= nil and (cf.IsDead ~= 0 or cf.HP <= 0) then
            hasDeadPlayer = true
            break
        end
    end

    local actionTimeout = hasDeadPlayer and 1.5 or 6.0

    if playerActedInTurn then
        if (curClock - lastActionClock >= 2.0) and lastHpChecksum >= 0 and (curHpSum ~= lastHpChecksum or curFighterCount ~= lastFighterCount) then
            playerActedInTurn = false
            lastHpChecksum = curHpSum
            lastFighterCount = curFighterCount
        elseif (curClock - lastActionClock >= actionTimeout) then
            playerActedInTurn = false
            lastHpChecksum = curHpSum
            lastFighterCount = curFighterCount
        end
    end

    if petActedInTurn then
        if (curClock - lastPetActionClock >= 2.0) and lastHpChecksum >= 0 and (curHpSum ~= lastHpChecksum or curFighterCount ~= lastFighterCount) then
            petActedInTurn = false
        elseif (curClock - lastPetActionClock >= actionTimeout) then
            petActedInTurn = false
        end
    end

    -- 战斗中才思考
    local myPos = game:GetMyPos()
    local myPetPos = game:GetMyPetPos()
    local my = game:GetFighter(myPos)
    local myPet = game:GetFighter(myPetPos)

    if my ~= nil and my.IsDead == 0 then
        local needAction = false
        if my.SP ~= lastSP then
            lastSP = my.SP
            needAction = true
        elseif not playerActedInTurn and (curClock - lastActionClock >= 2.0 or lastActionClock == 0) then
            needAction = true
        end

        if needAction then
            playerActedInTurn = true
            lastActionClock = curClock
            lastHpChecksum = curHpSum
            lastFighterCount = curFighterCount
            myAction()
        end
    end

    if myPet ~= nil and myPet.IsDead == 0 then
        local needPetAction = false
        if myPet.SP ~= lastPetSP then
            lastPetSP = myPet.SP
            needPetAction = true
        elseif not petActedInTurn and (curClock - lastPetActionClock >= 2.0 or lastPetActionClock == 0) then
            needPetAction = true
        end

        if needPetAction then
            petActedInTurn = true
            lastPetActionClock = curClock
            myPetAction()
        end
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
    lastSP = -1
    lastPetSP = -1
    playerActedInTurn = false
    petActedInTurn = false
    lastActionClock = 0
    lastPetActionClock = 0
    lastHpChecksum = -1
    lastFighterCount = -1
    start()
end

local function onFightLeave()
    isFightBegin = false
    lastSP = -1
    lastPetSP = -1
    playerActedInTurn = false
    petActedInTurn = false
    lastActionClock = 0
    lastPetActionClock = 0
    lastHpChecksum = -1
    lastFighterCount = -1
end

events.GameUpdate:Add(gameUpdate)
events.BeginFight:Add(onFightBegin)
events.LeaveFight:Add(onFightLeave)

return Module
