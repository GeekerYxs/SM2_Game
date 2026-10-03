local json = require ("dkjson")


-- 一般数据

function EncodeCheatScriptGeneralConfig(config)
    local c = {}

    --好友
    c.Friends = {}
    local friendCount = config:GetFriendCount()
    for i=0,friendCount-1 do
        local item = config:GetFriendByIdx(i)
        table.insert(c.Friends,{PlayerID=item.PlayerID,Checked=item.Checked})
    end

    --任务
    c.Tasks = {}
    local taskCount = config:GetTaskCount()
    for i=0,taskCount-1 do
        local item = config:GetTaskByIdx(i)
        table.insert(c.Tasks,{ID=item.ID,Checked=item.Checked})
    end

    --物品
    c.Items = {}
    local itemCount = config:GetItemCount()
    for i=0,itemCount-1 do
        local item = config:GetItemByIdx(i)
        table.insert(c.Items,{Name=item.Name,Checked=item.Checked})
    end

    c.GatherName1=config:GetGatherName1()
    c.GatherName2=config:GetGatherName2()
    c.HpRate=config:GetHpRate()
    c.MpRate=config:GetMpRate()
    c.PetHpRate=config:GetPetHpRate()
    c.PetMpRate=config:GetPetMpRate()
    c.PetRpRate=config:GetPetRpRate()
    c.AutoDiscardEnabled=config:IsAutoDiscardEnabled()
    c.AutoSellEnabled=config:IsAutoSellEnabled()
    c.AutoGatherEnabled=config:IsAutoGatherEnabled()
    c.AutoRecoverHpEnabled=config:IsAutoRecoverHpEnabled()
    c.AutoRecoverMpEnabled=config:IsAutoRecoverMpEnabled()
    c.AutoRecoverPetHpEnabled=config:IsAutoRecoverPetHpEnabled()
    c.AutoRecoverPetMpEnabled=config:IsAutoRecoverPetMpEnabled()
    c.AutoRecoverPetRpEnabled=config:IsAutoRecoverPetRpEnabled()

    return json.encode(c)
end

function DecodeCheatScriptGeneralConfig(data,config)
    game:Reportv(1,data)

    local c = json.decode(data)
    if(c==nil)then
        return
    end

    game:Reportv(1,  TableToString(c))

    --好友列表
    config:ClearFriends()
    if(c.Friends~=nil and type(c.Friends)=="table")then
        for k,v in pairs(c.Friends) do
            local item = config:CreateFriend(v.PlayerID)
            item.Checked = v.Checked
        end
    end

    --任务
    if(c.Tasks~=nil and type(c.Tasks)=="table")then
        for k,v in pairs(c.Tasks) do
            local item = config:CreateTask(v.ID)
            item.Checked = v.Checked
        end
    end

    --物品
    if (c.Tasks ~= nil and type(c.Tasks) == "table") then
        for k, v in pairs(c.Items) do
            local item = config:CreateItem(v.Name)
            item.Checked = v.Checked
        end
    end

    if c.GatherName1 ~= nil then config:SetGatherName1(c.GatherName1) end
    if c.GatherName2 ~= nil then config:SetGatherName2(c.GatherName2) end
    if c.HpRate ~= nil then config:SetHpRate(c.HpRate) end
    if c.MpRate ~= nil then config:SetMpRate(c.MpRate) end
    if c.PetHpRate ~= nil then config:SetPetHpRate(c.PetHpRate) end
    if c.PetMpRate ~= nil then config:SetPetMpRate(c.PetMpRate) end
    if c.PetRpRate ~= nil then config:SetPetRpRate(c.PetRpRate) end
    if c.AutoDiscardEnabled ~= nil then config:SetAutoDiscardEnabled(c.AutoDiscardEnabled) end
    if c.AutoSellEnabled ~= nil then config:SetAutoSellEnabled(c.AutoSellEnabled) end
    if c.AutoGatherEnabled ~= nil then config:SetAutoGatherEnabled(c.AutoGatherEnabled) end
    if c.AutoRecoverHpEnabled ~= nil then config:SetAutoRecoverHpEnabled(c.AutoRecoverHpEnabled) end
    if c.AutoRecoverMpEnabled ~= nil then config:SetAutoRecoverMpEnabled(c.AutoRecoverMpEnabled) end
    if c.AutoRecoverPetHpEnabled ~= nil then config:SetAutoRecoverPetHpEnabled(c.AutoRecoverPetHpEnabled) end
    if c.AutoRecoverPetMpEnabled ~= nil then config:SetAutoRecoverPetMpEnabled(c.AutoRecoverPetMpEnabled) end
    if c.AutoRecoverPetRpEnabled ~= nil then config:SetAutoRecoverPetRpEnabled(c.AutoRecoverPetRpEnabled) end

end



-- 战斗数据

function EncodeCheatScriptFightConfig(config)
    local c = {}

    c.AutoFight = config:IsAutoFightEnabled()
    -- 战斗
    c.FightConfigIndex = config:GetFightConfigIndex()
    c.FightConfigs = {}
    for i = 0, 2 do
        c.FightConfigs[i+1] = {}
        c.FightConfigs[i+1].PlayerUseSkillEnabled = config:IsPlayerUseSkillEnabled(i)
        c.FightConfigs[i+1].PlayerUseNormalAttackEnabled = config:IsPlayerUseNormalAttackEnabled(i)
        c.FightConfigs[i+1].PetUseSkillEnabled = config:IsPetUseSkillEnabled(i)
        c.FightConfigs[i+1].PetUseNormalAttackEnabled = config:IsPetUseNormalAttackEnabled(i)

        c.FightConfigs[i+1].PlayerSkillMagics = {}
        c.FightConfigs[i+1].PetSkillMagics = {}
        for j = 0, 3 do
            -- {type, id, level}
            local sm = config:GetPlayerSkillMagicInfo(i, j)
            table.insert(c.FightConfigs[i+1].PlayerSkillMagics,{type = sm.type, id = sm.id, level = sm.level })
            local sm2 = config:GetPetSkillMagicInfo(i, j)
            table.insert(c.FightConfigs[i+1].PetSkillMagics,{type = sm2.type, id = sm2.id, level = sm2.level})
        end

        -- catchpet
        c.FightConfigs[i+1].AutoCatchPetEnabled = config:IsAutoCatchPetEnabled(i)
        c.FightConfigs[i+1].CatchPetName = config:GetCatchPetName(i)

        -- first target
        c.FightConfigs[i+1].SelectPlayerFirstTargetEnabled = config:IsSelectPlayerFirstTargetEnabled(i)
        c.FightConfigs[i+1].SelectPetFirstTargetEnabled = config:IsSelectPetFirstTargetEnabled(i)
        c.FightConfigs[i+1].PlayerDelayActionEnabled = config:IsPlayerDelayActionEnabled(i)
        c.FightConfigs[i+1].PetDelayActionEnabled = config:IsPetDelayActionEnabled(i)
        c.FightConfigs[i+1].PlayerFirstTargetIndex = config:GetPlayerFirstTargetIndex(i)
        c.FightConfigs[i+1].PetFirstTargetIndex = config:GetPetFirstTargetIndex(i)
        c.FightConfigs[i+1].PlayerDelayActionSP = config:GetPlayerDelayActionSP(i)
        c.FightConfigs[i+1].PetDelayActionSP = config:GetPetDelayActionSP(i)

        -- rescue
        c.FightConfigs[i+1].RescueIgnorePetEnabled = config:IsRescueIgnorePetEnabled(i)
        c.FightConfigs[i+1].RescueAutoReliveEnabled = config:IsRescueAutoReliveEnabled(i)
        c.FightConfigs[i+1].RescueAutoHpRecoverEnabled = config:IsRescueAutoHpRecoverEnabled(i)
        c.FightConfigs[i+1].RescueAutoHpRecoverRate = config:GetRescueAutoHpRecoverRate(i)

        local sm = config:GetRescueRelivePlayerSkillMagicInfo(i)
        c.FightConfigs[i+1].RescueRelivePlayerSkillMagic = { type = sm.type, id = sm.id, level = sm.level }
        sm = config:GetRescueRelivePetSkillMagicInfo(i)
        c.FightConfigs[i+1].RescueRelivePetSkillMagic = { type = sm.type, id = sm.id, level = sm.level }
        sm = config:GetRescueHpRecoverPlayerSkillMagicInfo(i)
        c.FightConfigs[i+1].RescueHpRecoverPlayerSkillMagic = { type = sm.type, id = sm.id, level = sm.level }
        sm = config:GetRescueHpRecoverPetSkillMagicInfo(i)
        c.FightConfigs[i+1].RescueHpRecoverPetSkillMagic = { type = sm.type, id = sm.id, level = sm.level }

    end
    

    return json.encode(c)
end

function DecodeCheatScriptFightConfig(data,config)
    game:Reportv(1,data)

    local c = json.decode(data)
    if(c==nil)then
        return
    end

    game:Reportv(1,  TableToString(c))

    -- 战斗
    if c.AutoFight then config:SetAutoFightEnabled(c.AutoFight)  end
    if c.FightConfigIndex then config:SetFightConfigIndex(c.FightConfigIndex) end

    if c.FightConfigs then

        for i, v in ipairs(c.FightConfigs) do

            if v.PlayerUseSkillEnabled then config:SetPlayerUseSkillEnabled(i-1, v.PlayerUseSkillEnabled) end
            if v.PlayerUseNormalAttackEnabled then config:SetPlayerUseNormalAttackEnabled(i-1, v.PlayerUseNormalAttackEnabled) end
            if v.PetUseSkillEnabled then config:SetPetUseSkillEnabled(i-1, v.PetUseSkillEnabled) end
            if v.PetUseNormalAttackEnabled then config:SetPetUseNormalAttackEnabled(i-1, v.PetUseNormalAttackEnabled) end

            if v.PlayerSkillMagics then

                for j, s in ipairs(v.PlayerSkillMagics) do
                     if s and s.type and s.id > 0 and s.level > 0 then
                        config:SetPlayerSkillMagicInfo(i-1, j-1, s.type, s.id, s.level)
                     end
                end
                

            end

            if v.PetSkillMagics then
                for j, s in ipairs(v.PetSkillMagics) do
                     if s and s.type and s.id > 0 and s.level > 0 then
                        config:SetPetSkillMagicInfo(i-1, j-1, s.type, s.id, s.level)
                     end
                end
            end

            -- catchpet
            if v.AutoCatchPetEnabled then config:SetAutoCatchPetEnabled(i-1, v.AutoCatchPetEnabled) end
            if v.CatchPetName then config:SetCatchPetName(i-1, v.CatchPetName) end

            -- first target
            if v.SelectPlayerFirstTargetEnabled then config:SetSelectPlayerFirstTargetEnabled(i-1, v.SelectPlayerFirstTargetEnabled) end
            if v.SelectPetFirstTargetEnabled then config:SetSelectPetFirstTargetEnabled(i-1, v.SelectPetFirstTargetEnabled) end
            if v.PlayerDelayActionEnabled then config:SetPlayerDelayActionEnabled(i-1, v.PlayerDelayActionEnabled) end
            if v.PetDelayActionEnabled then config:SetPetDelayActionEnabled(i-1, v.PetDelayActionEnabled) end
            if v.PlayerFirstTargetIndex then config:SetPlayerFirstTargetIndex(i-1, v.PlayerFirstTargetIndex) end
            if v.PetFirstTargetIndex then config:SetPetFirstTargetIndex(i-1, v.PetFirstTargetIndex) end
            if v.PlayerDelayActionSP then config:SetPlayerDelayActionSP(i-1, v.PlayerDelayActionSP) end
            if v.PetDelayActionSP then config:SetPetDelayActionSP(i-1, v.PetDelayActionSP) end

            -- rescue
            if v.RescueIgnorePetEnabled then config:SetRescueIgnorePetEnabled(i-1, v.RescueIgnorePetEnabled) end
            if v.RescueAutoReliveEnabled then config:SetRescueAutoReliveEnabled(i-1, v.RescueAutoReliveEnabled) end
            if v.RescueAutoHpRecoverEnabled then config:SetRescueAutoHpRecoverEnabled(i-1, v.RescueAutoHpRecoverEnabled) end
            if v.RescueAutoHpRecoverRate then config:SetRescueAutoHpRecoverRate(i-1, v.RescueAutoHpRecoverRate) end

            if v.RescueRelivePlayerSkillMagic and v.RescueRelivePlayerSkillMagic.id > 0 then
                config:SetRescueRelivePlayerSkillMagicInfo(i-1, v.RescueRelivePlayerSkillMagic.type, v.RescueRelivePlayerSkillMagic.id, v.RescueRelivePlayerSkillMagic.level)
            end
            if v.RescueRelivePetSkillMagic and v.RescueRelivePetSkillMagic.id > 0 then
                config:SetRescueRelivePetSkillMagicInfo(i-1, v.RescueRelivePetSkillMagic.type, v.RescueRelivePetSkillMagic.id, v.RescueRelivePetSkillMagic.level)
            end
            if v.RescueHpRecoverPlayerSkillMagic and v.RescueHpRecoverPlayerSkillMagic.id > 0 then
                config:SetRescueHpRecoverPlayerSkillMagicInfo(i-1, v.RescueHpRecoverPlayerSkillMagic.type, v.RescueHpRecoverPlayerSkillMagic.id, v.RescueHpRecoverPlayerSkillMagic.level)
            end
            if v.RescueHpRecoverPetSkillMagic and v.RescueHpRecoverPetSkillMagic.id > 0 then
                config:SetRescueHpRecoverPetSkillMagicInfo(i-1, v.RescueHpRecoverPetSkillMagic.type, v.RescueHpRecoverPetSkillMagic.id, v.RescueHpRecoverPetSkillMagic.level)
            end

        end

    end

end