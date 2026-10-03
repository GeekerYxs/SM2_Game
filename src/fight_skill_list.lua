-- ============================================================================
-- fight_skill_list.lua
-- 智能战斗技能与策略控制器 (Intelligent Combat Skill Controller)
-- 
-- 架构设计:
-- 1. 优先挂接 AI 智能决策策略引擎 (ai_fight_strategy)
-- 2. 具备完整的官方逻辑降级保护兜底机制，杜绝任何卡死风险
-- ============================================================================

local Module = {}

-- 引入智能 AI 决策模块
local AIStrategy = nil
local hasAI, aiModule = pcall(require, "ai_fight_strategy")
if hasAI and aiModule then
    AIStrategy = aiModule
    Info("[AI战斗] 智能AI策略引擎加载成功!")
else
    Warn("[AI战斗] 未找到 ai_fight_strategy 模块，回退至原生模式")
end

local skillIdx = 0
local petSkillIdx = 0

local function start()
    skillIdx = 0
    petSkillIdx = 0
    -- 战前安全热重载 AI 策略模块，确保策略调整即刻生效
    pcall(function()
        for k, _ in pairs(package.loaded) do
            if string.find(tostring(k), "ai_fight_strategy") then
                package.loaded[k] = nil
            end
        end
        package.loaded["ai_fight_strategy"] = nil
        package.loaded["fight.ai_fight_strategy"] = nil
        package.loaded["luas.ai_fight_strategy"] = nil
        package.loaded["luas/ai_fight_strategy"] = nil
        local hasAI, aiModule = pcall(require, "ai_fight_strategy")
        if hasAI and aiModule then
            AIStrategy = aiModule
            Info("[AI战术] ai_fight_strategy 模块热重载成功!")
        else
            Warn("[AI战术] ai_fight_strategy 模块热重载失败: " .. tostring(aiModule))
        end
    end)
    -- 确保巡逻引擎在战斗中也完成加载与就位
    pcall(function()
        package.loaded["map_patrol"] = nil
        pcall(require, "map_patrol")
    end)
    if AIStrategy and AIStrategy.Blackboard and AIStrategy.Blackboard.ClearStale then
        pcall(AIStrategy.Blackboard.ClearStale)
    end
end

-- ============================================================================
-- 原生辅助函数 (官方兜底)
-- ============================================================================
local function getAssistTarget(myPos, myPetPos, skillCfg)
    if skillCfg.TargetType == 1 or skillCfg.TargetType == 3 or skillCfg.TargetType == 4 or skillCfg.TargetType == 12 then
        local fighter = game:GetFighter(myPos)
        if fighter ~= nil then return myPos end
    end
    if skillCfg.TargetType == 1 or skillCfg.TargetType == 3 then
        for pos = 15, 19 do
            local fighter = game:GetFighter(pos)
            if fighter ~= nil then return pos end
        end
    end
    if skillCfg.TargetType == 2 or skillCfg.TargetType == 3 or skillCfg.TargetType == 8 or skillCfg.TargetType == 12 then
        local fighter = game:GetFighter(myPetPos)
        if fighter ~= nil then return myPetPos end
    end
    if skillCfg.TargetType == 2 or skillCfg.TargetType == 3 then
        for pos = 10, 14 do
            local fighter = game:GetFighter(pos)
            if fighter ~= nil then return pos end
        end
    end
    return -1
end

local function getLowHPFighter(myPos, myPetPos, skillCfg)
    local minpos = -1
    local minhp = 100.0
    if skillCfg.TargetType == 1 or skillCfg.TargetType == 3 or skillCfg.TargetType == 4 or skillCfg.TargetType == 12 then
        local fighter = game:GetFighter(myPos)
        if fighter ~= nil and fighter.HP > 0 then
            if fighter.HP / fighter.HPMax < minhp then
                minpos = myPos
                minhp = fighter.HP / fighter.HPMax
            end
        end
    end
    if skillCfg.TargetType == 1 or skillCfg.TargetType == 3 then
        for pos = 15, 19 do
            local fighter = game:GetFighter(pos)
            if fighter ~= nil and fighter.HP > 0 then
                if fighter.HP / fighter.HPMax < minhp then
                    minpos = pos
                    minhp = fighter.HP / fighter.HPMax
                end
            end
        end
    end
    if skillCfg.TargetType == 2 or skillCfg.TargetType == 3 or skillCfg.TargetType == 8 or skillCfg.TargetType == 12 then
        local fighter = game:GetFighter(myPetPos)
        if fighter ~= nil and fighter.HP > 0 then
            if fighter.HP / fighter.HPMax < minhp then
                minpos = myPetPos
                minhp = fighter.HP / fighter.HPMax
            end
        end
    end
    if skillCfg.TargetType == 2 or skillCfg.TargetType == 3 then
        for pos = 10, 14 do
            local fighter = game:GetFighter(pos)
            if fighter ~= nil and fighter.HP > 0 then
                if fighter.HP / fighter.HPMax < minhp then
                    minpos = pos
                    minhp = fighter.HP / fighter.HPMax
                end
            end
        end
    end
    return minpos
end

local function officialCastSkill(fighter, skillInfo, isPet)
    local type = skillInfo.type
    local id = skillInfo.id
    local level = skillInfo.level
    local myPos = game:GetMyPos()
    local myPetPos = game:GetMyPetPos()
    local AutoFight = require("auto_fight")
    local cheat = game:GetCheatScript()
    local fightCfgIdx = cheat:GetFightConfigIndex()
    local attackTarget = -1
    if isPet and cheat:IsSelectPetFirstTargetEnabled(fightCfgIdx) ~= 0 then
        attackTarget = AutoFight.PetAttackTarget
    elseif not isPet and cheat:IsSelectPlayerFirstTargetEnabled(fightCfgIdx) ~= 0 then
        attackTarget = AutoFight.AttackTarget
    end

    if isPet then
        if not game:HasFightPetHasAbility(id, level) then return 0 end
        if game:IsFightPetAbilityInCD(id) then return 2 end
    end

    if type == 0 then -- skill
        if not isPet then
            if not game:HasSkill(id, level) then return 0 end
            if game:IsSkillInCD(id) then return 2 end
        end
        local skillCfg = game:ParseSpecifySkill(id, level)
        if fighter.SP < skillCfg.SP then return 1 end
        if isPet then
            if not game:IsSatisfyFightPetSkillConsume(id, level) then return 2 end
        else
            if not game:IsSatisfySkillConsume(id, level) then return 2 end
        end

        if skillCfg.Type == 1 or skillCfg.Type == 2 or skillCfg.Type == 5 then
            if isPet then
                game:CastPetSkillToFighter(attackTarget, id, level)
            else
                game:CastSkillToFighter(attackTarget, id, level)
            end
            return 3
        elseif skillCfg.Type == 3 then
            local pos = getLowHPFighter(myPos, myPetPos, skillCfg)
            if pos >= 0 then
                if isPet then game:CastPetSkillToFighter(pos, id, level) else game:CastSkillToFighter(pos, id, level) end
                return 3
            end
        elseif skillCfg.Type == 4 then
            local pos = getAssistTarget(myPos, myPetPos, skillCfg)
            if pos >= 0 then
                if isPet then game:CastPetSkillToFighter(pos, id, level) else game:CastSkillToFighter(pos, id, level) end
                return 3
            end
        end
        return 0
    else -- magic
        if not isPet then
            if not game:HasMagic(id, level) then return 0 end
            if game:IsMagicInCD(id) then return 2 end
        end
        local magicCfg = game:ParseSpecifyMagic(id, level)
        if fighter.SP < magicCfg.SP then return 1 end
        if isPet then
            if not game:IsSatisfyFightPetMagicConsume(id, level) then return 2 end
        else
            if not game:IsSatisfyMagicConsume(id, level) then return 2 end
        end

        if magicCfg.Type == 1 or magicCfg.Type == 4 or magicCfg.Type == 5 then
            if isPet then
                game:CastPetMagicToFighter(attackTarget, id, level)
            else
                game:CastMagicToFighter(attackTarget, id, level)
            end
            return 3
        elseif magicCfg.Type == 2 then
            local pos = getLowHPFighter(myPos, myPetPos, magicCfg)
            if pos >= 0 then
                if isPet then game:CastPetMagicToFighter(pos, id, level) else game:CastMagicToFighter(pos, id, level) end
                return 3
            end
        elseif magicCfg.Type == 3 then
            local pos = getAssistTarget(myPos, myPetPos, magicCfg)
            if pos >= 0 then
                if isPet then game:CastPetMagicToFighter(pos, id, level) else game:CastMagicToFighter(pos, id, level) end
                return 3
            end
        end
        return 0
    end
end

local function officialNormalAttack(fighter, isPet)
    if fighter.SP < 1 then return false end
    local AutoFight = require("auto_fight")
    local cheat = game:GetCheatScript()
    local fightCfgIdx = cheat:GetFightConfigIndex()
    local attackTarget = -1
    if isPet and cheat:IsSelectPetFirstTargetEnabled(fightCfgIdx) ~= 0 then
        attackTarget = AutoFight.PetAttackTarget
    elseif not isPet and cheat:IsSelectPlayerFirstTargetEnabled(fightCfgIdx) ~= 0 then
        attackTarget = AutoFight.AttackTarget
    end
    if isPet then
        game:PetNormalAttack(attackTarget)
    else
        game:NormalAttack(attackTarget)
    end
    return true
end

-- ============================================================================
-- 动作入口 (DoAction / DoPetAction)
-- ============================================================================
local function doAction()
    local myPos = game:GetMyPos()
    local fighter = game:GetFighter(myPos)
    if fighter == nil or fighter.HP <= 0 then
        return false
    end

    -- 优先尝试智能 AI 决策
    if AIStrategy and AIStrategy.Config.Enabled then
        local success, result = pcall(AIStrategy.DecideAction, fighter, false)
        if success then
            if result == true then
                return true
            else
                -- AI 系统接管战斗时，若 AI 判定无技能或执行防御，彻底阻断官方盲目普攻
                return false
            end
        else
            Warn("[AI战斗] AI决策执行异常: " .. tostring(result))
        end
    end

    -- 官方兜底循环
    local cheat = game:GetCheatScript()
    local fightCfgIdx = cheat:GetFightConfigIndex()
    if cheat:IsPlayerUseSkillEnabled(fightCfgIdx) == 0 then
        return false
    end

    for k = 1, 4 do
        local skillInfo = cheat:GetPlayerSkillMagicInfo(fightCfgIdx, skillIdx)
        if skillInfo == nil or skillInfo.id == 0 then
            if cheat:IsPlayerUseNormalAttackEnabled(fightCfgIdx) ~= 0 then
                if officialNormalAttack(fighter, false) then
                    skillIdx = (skillIdx + 1) % 4
                    return true
                else
                    return false
                end
            else
                skillIdx = (skillIdx + 1) % 4
            end
        else
            local ret = officialCastSkill(fighter, skillInfo, false)
            if ret == 0 then
                if cheat:IsPlayerUseNormalAttackEnabled(fightCfgIdx) ~= 0 then
                    if officialNormalAttack(fighter, false) then
                        skillIdx = (skillIdx + 1) % 4
                        return true
                    else
                        return false
                    end
                else
                    skillIdx = (skillIdx + 1) % 4
                end
            elseif ret == 1 then
                return false
            elseif ret == 2 then
                if cheat:IsPlayerUseNormalAttackEnabled(fightCfgIdx) ~= 0 then
                    if officialNormalAttack(fighter, false) then
                        skillIdx = (skillIdx + 1) % 4
                        return true
                    else
                        return false
                    end
                else
                    return false
                end
            elseif ret == 3 then
                skillIdx = (skillIdx + 1) % 4
                return true
            else
                skillIdx = (skillIdx + 1) % 4
            end
        end
    end
    return false
end

local function doPetAction()
    local myPos = game:GetMyPetPos()
    local fighter = game:GetFighter(myPos)
    if fighter == nil or fighter.HP <= 0 then
        return false
    end

    -- 优先尝试智能 AI 决策
    if AIStrategy and AIStrategy.Config.Enabled then
        local success, result = pcall(AIStrategy.DecideAction, fighter, true)
        if success then
            if result == true then
                return true
            else
                -- AI 系统接管战斗时，彻底阻断宠物盲目普攻
                return false
            end
        else
            Warn("[AI战斗] 宠物AI决策执行异常: " .. tostring(result))
        end
    end

    -- 官方兜底循环
    local cheat = game:GetCheatScript()
    local fightCfgIdx = cheat:GetFightConfigIndex()
    if cheat:IsPetUseSkillEnabled(fightCfgIdx) == 0 then
        return false
    end

    for k = 1, 4 do
        local skillInfo = cheat:GetPetSkillMagicInfo(fightCfgIdx, petSkillIdx)
        if skillInfo == nil or skillInfo.id == 0 then
            if cheat:IsPetUseNormalAttackEnabled(fightCfgIdx) ~= 0 then
                if officialNormalAttack(fighter, true) then
                    petSkillIdx = (petSkillIdx + 1) % 4
                    return true
                else
                    return false
                end
            else
                petSkillIdx = (petSkillIdx + 1) % 4
            end
        else
            local ret = officialCastSkill(fighter, skillInfo, true)
            if ret == 0 then
                if cheat:IsPetUseNormalAttackEnabled(fightCfgIdx) ~= 0 then
                    if officialNormalAttack(fighter, true) then
                        petSkillIdx = (petSkillIdx + 1) % 4
                        return true
                    else
                        return false
                    end
                else
                    petSkillIdx = (petSkillIdx + 1) % 4
                end
            elseif ret == 1 then
                return false
            elseif ret == 2 then
                if cheat:IsPetUseNormalAttackEnabled(fightCfgIdx) ~= 0 then
                    if officialNormalAttack(fighter, true) then
                        petSkillIdx = (petSkillIdx + 1) % 4
                        return true
                    else
                        return false
                    end
                else
                    return false
                end
            elseif ret == 3 then
                petSkillIdx = (petSkillIdx + 1) % 4
                return true
            else
                petSkillIdx = (petSkillIdx + 1) % 4
            end
        end
    end
    return false
end

Module.DoAction = doAction
Module.DoPetAction = doPetAction
Module.Start = start

return Module
