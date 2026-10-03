--自动出售物品
local events = require("events")

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
    --强化物品不可以卖店
    --if item:GetPropValue(60361)~=0 then
    --    return false
    --end
    Debug("sell slot="..tostring(slot).." itemid="..tostring(item.ItemID))
    game:AddItemSlotToSale(slot)
    return true
end

local function checkOneCheatItem(cheatItem,items)
    local autoItemInfo = game:GetCSAutoItem(cheatItem.Name)
    if(autoItemInfo==nil)then
        return false
    end

    Debug("check sell "..autoItemInfo.Name)
    local sellCount = 0
    for slot,item in pairs(items)do
        if checkOneItem(slot,item,cheatItem,autoItemInfo) then
            sellCount = sellCount+1
        end
        if sellCount>= 20 then
            break
        end
    end

    return sellCount>0
end

local function onNpcTradeSale()
    local cheat = game:GetCheatScript()
    Debug("auto sell="..tostring(cheat:IsAutoSellEnabled()))
    if(cheat:IsAutoSellEnabled()~=0)then
        Debug("Check Auto Sell")
        local autoItemCount = cheat:GetItemCount()
        local items = game:GetItemBar()
        for i=0,autoItemCount-1 do
            local cheatItem = cheat:GetItemByIdx(i)
            Debug(tostring(i).." checked is "..tostring(cheatItem.Checked))
            if cheatItem.Checked~=0 then
                checkOneCheatItem(cheatItem,items)
            end
        end
    end
end

events.NpcTradeSale:Add(onNpcTradeSale)