--技能列表
local Module = {}

local skillIdx = 0
local petSkillIdx = 0

local function start()
    skillIdx = 0
    petSkillIdx = 0
end

local function getAssistTarget(myPos,myPetPos,skillCfg)
    --优先自己，然后队友，然后自己宠物，然后队友宠物
    if skillCfg.TargetType == 1 or skillCfg.TargetType == 3 or skillCfg.TargetType == 4 or skillCfg.TargetType == 12 then
        local fighter = game:GetFighter(myPos)
        if fighter ~= nil then
            return myPos
        end
    end
    if skillCfg.TargetType == 1 or skillCfg.TargetType == 3 then
        for pos = 15, 19 do
            local fighter = game:GetFighter(pos)
            if fighter ~= nil then
                return pos
            end
        end
    end
    if skillCfg.TargetType == 2 or skillCfg.TargetType == 3 or skillCfg.TargetType == 8 or skillCfg.TargetType == 12 then
        local fighter = game:GetFighter(myPetPos)
        if fighter ~= nil then
            return myPetPos
        end
    end
    if skillCfg.TargetType == 2 or skillCfg.TargetType == 3 then
        for pos = 10, 14 do
            local fighter = game:GetFighter(pos)
            if fighter ~= nil then
                return pos
            end
        end
    end
    return -1
end

local function getLowHPFighter(myPos, myPetPos, skillCfg)
    --优先自己，然后队友，然后自己宠物，然后队友宠物
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

--使用技能
--返回:
--  0表示跳过这个技能到下一个
--  1表示选择好了该技能，但需要等待使用
--  2表示选择好了该技能，但当前无法使用，外部可以使用更好的选择
--  3表示选择好了该技能，并下了指令
local function castSkill(fighter, skillInfo, isPet)
    local type = skillInfo.type
    local id = skillInfo.id
    local level = skillInfo.level
    if isPet then
        Debug("pet fighter castskill skill="..tostring(id))
    else
        Debug("fighter castskill skill="..tostring(id))
    end
    local myPos = game:GetMyPos()
    local myPetPos = game:GetMyPetPos()
    local AutoFight = require("auto_fight")
    local cheat = game:GetCheatScript()
    local fightCfgIdx = cheat:GetFightConfigIndex()
    local attackTarget = -1
    if isPet and cheat:IsSelectPetFirstTargetEnabled(fightCfgIdx)~=0 then
        attackTarget = AutoFight.PetAttackTarget
    elseif not isPet and cheat:IsSelectPlayerFirstTargetEnabled(fightCfgIdx)~=0 then
        attackTarget = AutoFight.AttackTarget
    end
    if isPet then
        if not game:HasFightPetHasAbility(id, level) then
            Debug("pet fighter not have ability")
            return 0
        end
        if game:IsFightPetAbilityInCD(id) then
            Debug("pet ability is in cd")
            return 2
        end
    end
    if type == 0 then --skill
        if not isPet then 
            if not game:HasSkill(id, level) then
                Debug("fighter not have skill")
                return 0
            end
            if game:IsSkillInCD(id) then
                Debug("fighter skill is in cd")
                return 2
            end
        end
        local skillCfg = game:ParseSpecifySkill(id,level)
        if fighter.SP < skillCfg.SP then
            --SP不足
            Debug("skill sp no satisfy sp="..tostring(fighter.SP)..",needsp="..tostring(skillCfg.SP))
            return 1 --等待
        end
        if isPet then 
            if not game:IsSatisfyFightPetSkillConsume(id, level) then
                --消耗不足
                Debug("pet ability no satisfy consume")
                return 2
            end

        else
            if not game:IsSatisfySkillConsume(id, level) then
                --消耗不足
                Debug("pet skill no satisfy consume")
                return 2
            end
        end
        Debug("use skill,type="..tostring(skillCfg.Type))
        if skillCfg.Type==1 --近程攻击技能
            or skillCfg.Type==2 --远程攻击技能
            or skillCfg.Type==5 --诅咒技能
            then 
                if isPet then
                    Debug("pet use attack skill")
                    game:CastPetSkillToFighter(attackTarget, id, level);
                else
                    Debug("fighter use attack skill")
                    game:CastSkillToFighter(attackTarget, id, level);
                end
            return 3
        elseif skillCfg.Type==3 then --补血技能
            local pos = getLowHPFighter(myPos,myPetPos,skillCfg)
            if pos>=0 then
                if isPet then
                    Debug("pet use cure skill to"..tostring(pos))
                    game:CastPetSkillToFighter(pos, id, level);
                else
                    Debug("fighter use cure skill to"..tostring(pos))
                    game:CastSkillToFighter(pos, id, level);
                end
                return 3
            end
        elseif skillCfg.Type==4 then --辅助
            local pos = getAssistTarget(myPos,myPetPos,skillCfg)
            if pos>=0 then
                if isPet then
                    Debug("pet use assist skill to"..tostring(pos))
                    game:CastPetSkillToFighter(pos, id, level);
                else
                    Debug("fighter use assist skill to"..tostring(pos))
                    game:CastSkillToFighter(pos, id, level);
                end
                return 3
            end
        end
        return 0
    else     --magic
        if not isPet then
            if not game:HasMagic(id, level) then
                Debug("fighter not have magic")
                return 0
            end
            if game:IsMagicInCD(id) then
                Debug("fighter magic in cd")
                return 2
            end
        end
        local magicCfg = game:ParseSpecifyMagic(id, level)
        if fighter.SP < magicCfg.SP then
            --SP不足
            Debug("magic sp no satisfy,sp="..tostring(fighter.SP)..",needsp="..tostring(magicCfg.SP))
            return 1
        end
        if isPet then
            if not game:IsSatisfyFightPetMagicConsume(id, level) then
                --消耗不足
                Debug("pet magic no satisfy consume")
                return 2
            end
        else
            if not game:IsSatisfyMagicConsume(id, level) then
                --消耗不足
                Debug("magic no satisfy consume")
                return 2
            end
        end
        Debug("use magic,type="..tostring(magicCfg.Type))
        if magicCfg.Type==1 --攻击魔法
            or magicCfg.Type==4 --诅咒法术
            or magicCfg.Type==5 --召唤法术
            then 
                if isPet then
                    Debug("pet use attack magic")
                    game:CastPetMagicToFighter(attackTarget, id, level);
                else
                    Debug("fighter use attack magic")
                    game:CastMagicToFighter(attackTarget, id, level);
                end
            return 3
        elseif magicCfg.Type==2 then --补血法术
            local pos = getLowHPFighter(myPos,myPetPos,magicCfg)
            if pos>=0 then
                if isPet then
                    Debug("pet use cure magic to "..tostring(pos))
                    game:CastPetMagicToFighter(pos, id, level);
                else
                    Debug("fighter use cure magic to "..tostring(pos))
                    game:CastMagicToFighter(pos, id, level);
                end
                return 3
            end
        elseif magicCfg.Type==3 then --辅助法术
            local pos = getAssistTarget(myPos,myPetPos,magicCfg)
            if pos>=0 then
                if isPet then
                    Debug("pet use assist magic to "..tostring(pos))
                    game:CastPetMagicToFighter(pos, id, level);
                else
                    Debug("fighter use assist magic to "..tostring(pos))
                    game:CastMagicToFighter(pos, id, level);
                end
                return 3
            end
        end
        return 0
    end
end

local function normalAttack(fighter, isPet)
    if fighter.SP<1 then
        Debug("normalattack sp not satisfy")
        return false
    end
    local AutoFight = require("auto_fight")
    local cheat = game:GetCheatScript()
    local fightCfgIdx = cheat:GetFightConfigIndex()
    local attackTarget = -1
    if isPet and cheat:IsSelectPetFirstTargetEnabled(fightCfgIdx)~=0 then
        attackTarget = AutoFight.PetAttackTarget
    elseif not isPet and cheat:IsSelectPlayerFirstTargetEnabled(fightCfgIdx)~=0 then
        attackTarget = AutoFight.AttackTarget
    end
    if isPet then
        Debug("pet use normalattack")
        game:PetNormalAttack(attackTarget)
    else
        Debug("use normalattack")
        game:NormalAttack(attackTarget)
    end
    return true
end

local function getEnemyCount()
    local count = 0;
    for k = 0, 19 do
        local fighter = game:GetFighter(k)
        if fighter~=nil then
            count = count+1
        end
    end
    return count
end

--执行动作，不执行就返回false
local function doAction()
    Debug("skill list do action")
    local cheat = game:GetCheatScript()
    local fightCfgIdx = cheat:GetFightConfigIndex()
    --是否开启人物技能循环
    if cheat:IsPlayerUseSkillEnabled(fightCfgIdx)==0 then
        return false
    end
    local myPos = game:GetMyPos()
    local fighter = game:GetFighter(myPos)
    if fighter.HP<=0 then
        Debug("fighter is dead")
        return false
    end
    for k = 1, 4 do
        local skillInfo = cheat:GetPlayerSkillMagicInfo(fightCfgIdx, skillIdx)
        if skillInfo == nil or skillInfo.id == 0 then
            if cheat:IsPlayerUseNormalAttackEnabled(fightCfgIdx) ~= 0 then
                if normalAttack(fighter, false) then
                    skillIdx = (skillIdx + 1) % 4
                    return true
                else
                    return false
                end
            else
                skillIdx = (skillIdx + 1) % 4
            end
        else
            local ret = castSkill(fighter, skillInfo, false)
            if ret == 0 then
                if cheat:IsPlayerUseNormalAttackEnabled(fightCfgIdx) ~= 0 then
                    if normalAttack(fighter, false) then
                        skillIdx = (skillIdx + 1) % 4
                        return true
                    else
                        return false
                    end
                else
                    --跳到下一个
                    skillIdx = (skillIdx + 1) % 4
                end
            elseif ret == 1 then
                --等待
                return false
            elseif ret == 2 then
                --无法使用，但可以使用普攻
                if cheat:IsPlayerUseNormalAttackEnabled(fightCfgIdx) ~= 0 then
                    if normalAttack(fighter, false) then
                        skillIdx = (skillIdx + 1) % 4
                        return true
                    else
                        return false
                    end
                else
                    --等待
                    return false
                end
            elseif ret == 3 then
                --使用了当前技能
                skillIdx = (skillIdx + 1) % 4
                return true
            else
                skillIdx = (skillIdx + 1) % 4
            end
        end
    end
    return false
end

--执行宠物动作，不执行就返回false
local function doPetAction()
    Debug("skill list do petaction")
    local cheat = game:GetCheatScript()
    local fightCfgIdx = cheat:GetFightConfigIndex()
    --是否开启宠物技能循环
    if cheat:IsPetUseSkillEnabled(fightCfgIdx)==0 then
        return false
    end
    local myPos = game:GetMyPetPos()
    local fighter = game:GetFighter(myPos)
    if fighter==nil then
        return false
    end
    if fighter.HP<=0 then
        Debug("pet fighter is dead")
        return false
    end
    for k = 1, 4 do
        local skillInfo = cheat:GetPetSkillMagicInfo(fightCfgIdx, petSkillIdx)
        if skillInfo == nil or skillInfo.id == 0 then
            --无法使用，但可以使用普攻
            if cheat:IsPetUseNormalAttackEnabled(fightCfgIdx) ~= 0 then
                if normalAttack(fighter, true) then
                    petSkillIdx = (petSkillIdx + 1) % 4
                    return true
                else
                    return false
                end
            else
                petSkillIdx = (petSkillIdx + 1) % 4
            end
        else
            local ret = castSkill(fighter, skillInfo, true)
            if ret == 0 then
                if cheat:IsPetUseNormalAttackEnabled(fightCfgIdx) ~= 0 then
                    if normalAttack(fighter, true) then
                        petSkillIdx = (petSkillIdx + 1) % 4
                        return true
                    else
                        return false
                    end
                else
                    --跳到下一个
                    petSkillIdx = (petSkillIdx + 1) % 4
                end
            elseif ret == 1 then
                --等待
                return false
            elseif ret == 2 then
                --无法使用，但可以使用普攻
                if cheat:IsPetUseNormalAttackEnabled(fightCfgIdx) ~= 0 then
                    if normalAttack(fighter, true) then
                        petSkillIdx = (petSkillIdx + 1) % 4
                        return true
                    else
                        return false
                    end
                else
                    --等待
                    return false
                end
            elseif ret == 3 then
                --使用了当前技能
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