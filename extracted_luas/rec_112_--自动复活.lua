--自动复活
local Module = {}

local function reliveFighter(pos, ignorePet, isPet)
    local fighter = game:GetFighter(pos)
    if fighter == nil or fighter.HP > 0 then
        return false
    end

    Debug("check relive fighter. pos=" .. tostring(pos)..",ignore pet="..tostring(ignorePet))
    if pos < 15 then
        --宠物
        if ignorePet then
            Debug("ignore pet")
            return false
        end
    end
    --取出技能
    local cheat = game:GetCheatScript()
    local fightCfgIdx = cheat:GetFightConfigIndex()
    if not isPet then
        local skillInfo = cheat:GetRescueRelivePlayerSkillMagicInfo(fightCfgIdx)
        if skillInfo ~= nil and skillInfo.id ~= 0 then
            local type = skillInfo.type
            local id = skillInfo.id
            local level = skillInfo.level
            local myPos = game:GetMyPos()
            local fighter = game:GetFighter(myPos)
            if fighter.HP <= 0 then
                Debug("fighter is dead")
                return false
            end
            if type == 0 then --skill
                if not game:HasSkill(id, level) then
                    Debug("fighter not have skill")
                    return false
                end
                local skillCfg = game:ParseSpecifySkill(id, level)
                if skillCfg.Type == 1    --近程攻击技能
                    or skillCfg.Type == 2 --远程攻击技能
                    or skillCfg.Type == 5 then --诅咒技能
                    Debug("skill type is invalid")
                    return false
                end
                if game:IsSkillInCD(id) then
                    Debug("skill is in cd")
                    return false
                end
                if fighter.SP < skillCfg.SP then
                    --SP不足
                    Debug("skill sp no satisfy")
                    return false
                end
                if not game:IsSatisfySkillConsume(id, level) then
                    --消耗不足
                    Debug("skill no satisfy consume")
                    return false
                end
                Debug("use skill to relive")
                game:CastSkillToFighter(pos, id, level);
                return true
            else --magic
                if not game:HasMagic(id, level) then
                    Debug("fighter not have magic")
                    return false
                end
                local magicCfg = game:ParseSpecifyMagic(id, level)
                if magicCfg.Type == 1    --攻击魔法
                    or magicCfg.Type == 4 then --诅咒魔法
                    Debug("magic type is invalid")
                    return false
                end
                if game:IsMagicInCD(id) then
                    Debug("magic in cd")
                    return false
                end
                if fighter.SP < magicCfg.SP then
                    --SP不足
                    Debug("magic sp no satisfy")
                    return false
                end
                if not game:IsSatisfyMagicConsume(id, level) then
                    --消耗不足
                    Debug("magic no satisfy consume")
                    return false
                end
                Debug("use magic to relive fighter.magicid=" .. tostring(id) .. ",target=" .. tostring(pos))
                game:CastMagicToFighter(pos, id, level);
                return true
            end
        end
    else
        local petSkillInfo = cheat:GetRescueRelivePetSkillMagicInfo(fightCfgIdx)
        if petSkillInfo ~= nil and petSkillInfo.id ~= 0 then
            local type = petSkillInfo.type
            local id = petSkillInfo.id
            local level = petSkillInfo.level
            local myPos = game:GetMyPetPos()
            local fighter = game:GetFighter(myPos)
            if fighter.HP <= 0 then
                Debug("fighter is dead")
                return false
            end
            if not game:HasFightPetHasAbility(id, level) then
                Debug("not have ability")
                return false
            end
            if not game:IsFightPetAbilityInCD(id) then
                Debug("ability is in cd")
                return false
            end
            if type == 0 then            --skill
                local skillCfg = game:ParseSpecifySkill(id, level)
                if skillCfg.Type == 1    --近程攻击技能
                    or skillCfg.Type == 2 --远程攻击技能
                    or skillCfg.Type == 5 then --诅咒技能
                    Debug("pet skill type is invalid")
                    return false
                end
                if fighter.SP < skillCfg.SP then
                    --SP不足
                    Debug("pet skill sp is no satisfy")
                    return false
                end
                if not game:IsSatisfyFightPetSkillConsume(id, level) then
                    --消耗不足
                    Debug("pet skill consume is no satisfy")
                    return false
                end
                Debug("pet use skill to relive fighter")
                game:CastPetSkillToFighter(pos, id, level);
                return true
            else                         --magic
                local magicCfg = game:ParseSpecifyMagic(id, level)
                if magicCfg.Type == 1    --攻击魔法
                    or magicCfg.Type == 4 then --诅咒魔法
                    Debug("pet magic type is invalid")
                    return false
                end
                if fighter.SP < magicCfg.SP then
                    --SP不足
                    Debug("pet magic sp is no satisfy")
                    return false
                end
                if not game:IsSatisfyFightPetMagicConsume(id, level) then
                    --消耗不足
                    Debug("pet magic consume is no satisfy")
                    return false
                end
                Debug("pet use magic to relive fighter")
                game:CastPetMagicToFighter(pos, id, level);
                return true
            end
        end
    end
    return false
end

--执行动作，不执行就返回false
local function doAction()
    local cheat = game:GetCheatScript()
    local fightCfgIdx = cheat:GetFightConfigIndex()
    --是否自动复活
    if cheat:IsRescueAutoReliveEnabled(fightCfgIdx)==0 then
        return false
    end
    local ignorePet = cheat:IsRescueIgnorePetEnabled(fightCfgIdx)~=0
    --优先自身
    if reliveFighter(game:GetMyPos(), ignorePet, false) then
        return true
    end
    --队友
    for pos = 15, 19 do
        if reliveFighter(pos, ignorePet, false) then
            return true
        end
    end
    --自身宠物
    if reliveFighter(game:GetMyPetPos(), ignorePet, false) then
        return true
    end
    --队友宠物
    for pos = 10, 14 do
        if reliveFighter(pos, ignorePet, false) then
            return true
        end
    end
    return false
end

--执行动作，不执行就返回false
local function doPetAction()
    local cheat = game:GetCheatScript()
    local fightCfgIdx = cheat:GetFightConfigIndex()
    --是否自动复活
    if cheat:IsRescueAutoReliveEnabled(fightCfgIdx)==0 then
        return false
    end
    local ignorePet = cheat:IsRescueIgnorePetEnabled(fightCfgIdx)~=0
    --优先自身
    if reliveFighter(game:GetMyPos(), ignorePet, false) then
        return true
    end
    --队友
    for pos = 15, 19 do
        if reliveFighter(pos, ignorePet, false) then
            return true
        end
    end
    --自身宠物
    if reliveFighter(game:GetMyPetPos(), ignorePet, false) then
        return true
    end
    --队友宠物
    for pos = 10, 14 do
        if reliveFighter(pos, ignorePet, false) then
            return true
        end
    end
    return false
end

Module.DoAction = doAction
Module.DoPetAction = doPetAction

return Module 

