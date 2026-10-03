--自动丢弃物品
local gamestate = require("game_state")
local events = require("events")

local actionTime = 2
local defaultTime = 2 
local waitTime = defaultTime   --表示多少时间间隔会觉察一次外部数据
local lastTime = 0

local function checkOneItem(slot,item,cheatItem,autoItemInfo)

    local typeMatch = false
    for c, v in pairs(autoItemInfo.ItemTypes) do
        if v == item.Type then
            typeMatch = true
        end
    end

    if not typeMatch then
        return false
    end
    
    local itemInfo = game:GetItemInfo(item.ItemID)
    if(itemInfo==nil)then
        return false
    end
    if itemInfo.Quality~=autoItemInfo.Quality then
        return false
    end
    --强化物品不可以丢弃
    --if item:GetPropValue(60361)~=0 then
    --    return false
    --end
    Debug("drop slot="..tostring(slot).." itemid="..tostring(item.ItemID))
    local msg = "自动丢弃了"..tostring(item.Count).."个"..item.Name
    game:ShowMessage(msg)
    game:ShowChatMessage(msg)
    game:DropItem(slot,item.Count)
    return true
end

local function checkOneCheatItem(cheatItem,items)
    local autoItemInfo = game:GetCSAutoItem(cheatItem.Name)
    if(autoItemInfo==nil)then
        return false
    end

    local doAction = false;
    for slot,item in pairs(items)do
        if checkOneItem(slot,item,cheatItem,autoItemInfo) then
            doAction = true
        end
    end

    return doAction
end

local function gameUpdate()
    local cur = os.clock()
    if(cur-lastTime<waitTime)then
        return
    end
    lastTime = cur

    if(not gamestate.isLogin)then
        return
    end
    if(gamestate.isInFight)then
        return
    end
    if(not gamestate.isCheatConfigLoaded)then
        return
    end

    local cheat = game:GetCheatScript()

    local doAction = false

    if(cheat:IsAutoDiscardEnabled()~=0)then
        --Debug("Check Auto Drop")
        local autoItemCount = cheat:GetItemCount()
        local items = game:GetItemBar()
        for i=0,autoItemCount-1 do
            local cheatItem = cheat:GetItemByIdx(i)
            if cheatItem.Checked~=0 then
                if checkOneCheatItem(cheatItem,items) then
                    doAction = true
                end
            end
        end
    end

    if(doAction)then
        waitTime = actionTime
    else
        waitTime = defaultTime --恢复敏感度
    end
end

events.GameUpdate:Add(gameUpdate)