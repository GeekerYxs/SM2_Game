local Module = {}

local CatchPetItems = {
    {ItemId=8702,Level=10},
    {ItemId=8703,Level=15},
    {ItemId=8704,Level=20},
    {ItemId=8705,Level=25},
    {ItemId=8706,Level=30},
    {ItemId=8707,Level=35},
    {ItemId=8708,Level=40},
    {ItemId=8709,Level=45},
    {ItemId=8710,Level=50},
    {ItemId=8711,Level=55},
    {ItemId=8712,Level=60},
    {ItemId=8713,Level=65},
    {ItemId=8714,Level=70},
    {ItemId=8720,Level=80},
}

local function catchPet(pos)
    Debug("catchpet pos="..tostring(pos))
    --看看是否有抓宠道具
    local items = game:GetItemBar()
    local level = game:GetFighterLevel(pos)
    for _,v in pairs(CatchPetItems) do
        if v.Level>=level then
            --可以捕捉的最低的物品了
            for slot,item in pairs(items)do
                if item.ItemID==v.ItemId then
                    Debug("find catch pet item.slot="..tostring(slot))
                    game:UseItemToFighter(pos,slot)
                    return true
                end
            end
        end
    end
    return false
end

--执行动作，不执行就返回false
local function doAction()
    local cheat = game:GetCheatScript()
    local fightCfgIdx = cheat:GetFightConfigIndex()
    local petName = cheat:GetCatchPetName(fightCfgIdx)
    if cheat:IsAutoCatchPetEnabled(fightCfgIdx)==0 then
        return false
    end
    Debug("try catch pet")
    local myPos = game:GetMyPos()
    local fighter = game:GetFighter(myPos)
    if fighter.SP<1 then
        Debug("抓宠蓄力点不足")
        return false
    end
    for pos = 0, 9 do
        --是否有宠物可以抓
        local fighter = game:GetFighter(pos)
        if fighter~=nil and fighter.HP>0 then
            local fighterName = game:GetFighterName(pos)
            if fighterName == petName and game:IsFighterCanBeCatch(pos) then
                if catchPet(pos) then
                    return true
                end
            end
        end
    end
    return false
end
Module.DoAction = doAction

return Module 