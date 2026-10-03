--自动补给
local gamestate = require("game_state")
local events = require("events")

local actionTime = 2
local defaultTime = 0.2
local waitTime = defaultTime   --表示多少时间间隔会觉察一次外部数据
local lastTime = 0

-- 是否存在ID范围的物品
local function checkHasItemInIDRange(items, BeginItemID, EndItemID)
    for slot,item in pairs(items)do
        if item.ItemID >= BeginItemID and item.ItemID <= EndItemID then
            return true
        end
    end

    return false
end

-- 是否存在ID列表的物品
-- ItemIDList = {1,2,3,4,}
local function checkHasItemInIDList(items, ItemIDList)
    for slot,item in pairs(items)do
        for c, id in pairs(ItemIDList) do
            if item.ItemID == id then
                return true
            end
        end
    end

    return false
end

local function GameUpdate()
    if(not gamestate.isLogin)then
        return
    end
    if(gamestate.isInFight)then
        return
    end
    if(not gamestate.isCheatConfigLoaded)then
        return
    end
    
    local curmapid = game:GetMapID()
    if curmapid == 305 then
        return
    end
    
    local cur = os.clock()
    if(cur-lastTime<waitTime)then
        return
    end
    lastTime = cur

    local cheat = game:GetCheatScript()

    local items = game:GetItemBar()

    local doAction = false
    --检测hp
    if(cheat:IsAutoRecoverHpEnabled()~=0)then
        if(game:GetHp()/game:GetHpMax()<=cheat:GetHpRate()/100)then
            if checkHasItemInIDRange(items, 8400, 8407) or checkHasItemInIDRange(items, 64002, 64003) then
                Debug("FillHp")
                game:FillHp()
                doAction = true
            end
        end
    end
    --检测mp
    if(cheat:IsAutoRecoverMpEnabled()~=0)then
        if(game:GetMp()/game:GetMpMax()<=cheat:GetMpRate()/100)then
            if checkHasItemInIDRange(items, 8450, 8457) or checkHasItemInIDList(items, {63954, 63960}) then
                Debug("FillMp")
                game:FillMp()
                doAction = true
            end
        end
    end
    --检测宠物hp
    if(cheat:IsAutoRecoverPetHpEnabled()~=0)then
        if(game:GetPetHp()/game:GetPetHpMax()<=cheat:GetPetHpRate()/100)then
            if checkHasItemInIDRange(items, 8400, 8407) or checkHasItemInIDRange(items, 64002, 64003) then
                Debug("FillPetHp")
                game:FillPetHp()
                doAction = true
            end
        end
    end
    --检测宠物mp
    if(cheat:IsAutoRecoverPetMpEnabled()~=0)then
        if(game:GetPetMp()/game:GetPetMpMax()<=cheat:GetPetMpRate()/100)then
            if checkHasItemInIDRange(items, 8450, 8457) or checkHasItemInIDList(items, {63954, 63960}) then
                Debug("FillPetMp")
                game:FillPetMp()
                doAction = true
            end
        end
    end
    --检测宠物rp
    if(cheat:IsAutoRecoverPetRpEnabled()~=0)then
        if(game:GetPetRp()/game:GetPetRpMax()<=cheat:GetPetRpRate()/100)then
            if checkHasItemInIDList(items, {8571, 8572, 8573, 63955, 63962, 63970, 63978, 63989, 64000, 64023, 64029}) then
                Debug("FillPetRp")
                game:FillPetRp()
                doAction = true
            end
        end
    end

    if(doAction)then
        waitTime = actionTime
    else
        waitTime = defaultTime --恢复敏感度
    end
end

events.GameUpdate:Add(GameUpdate)