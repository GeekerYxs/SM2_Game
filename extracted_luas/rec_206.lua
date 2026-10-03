local dlgbuilder = require "dlg_builder"

local struct = require "uiresetblessequipability_struct"
local prefix_path = "UIGame/UIBlessEquip"

local _itemSlot = -1
local _slotInfo = nil
local _itemInfo = nil
local _equipInfo = nil
local _material1Id = 0
local _material2Id = 0
local _material3Id = 0
local _dlg = nil
local _waitResponse = false

local showMaterialItem = function(itemIndex, itemID, itemNum)
    local staticRes = game:StaticRes()
    local dataitem = game:UIDataItem()
    local needItemInfo = staticRes:GetItemInfo(itemID)
    local materialItem = _dlg["MaterialItem" .. itemIndex]
    materialItem:SetVisible(1)
    materialItem.Item:SetImage(needItemInfo:GetImageName())
    materialItem.Count:SetEnable(0)
    materialItem.Count:ClearString()
    local count = dataitem:GetItemCount(itemID)
    if count < itemNum then
        materialItem.Count:AddString("#53248" .. count .. "/" .. itemNum)
        return false
    else
        materialItem.Count:AddString("#26592" .. count .. "/" .. itemNum)
    end
    return true
end

local function itemTypeToSlotIdx(itemType)
    if EItemType.Hat == itemType then return EEquipSlot.Hat -- 帽子
    elseif EItemType.Respirator == itemType then return EEquipSlot.Face -- 口罩
    elseif EItemType.Weapon == itemType then return EEquipSlot.Weapon -- 武器
    elseif EItemType.Shoes == itemType then return EEquipSlot.Shoes -- 鞋子
    elseif EItemType.Ring == itemType then return EEquipSlot.Ring -- 戒指
    elseif EItemType.Necklace == itemType then return EEquipSlot.Necklace -- 项链
    elseif EItemType.Trousers == itemType then return EEquipSlot.Trousers -- 裤子
    elseif EItemType.Waistband then return EEquipSlot.Belt -- 腰带
    elseif EItemType.Cloth then return EEquipSlot.Cloth -- 衣服
    elseif EItemType.CarL == itemType or -- 低级交通工具
           EItemType.CarM == itemType or -- 中级交通工具
           EItemType.CarH == itemType or -- 高级交通工具
           EItemType.CarS == itemType then return EEquipSlot.Car -- 超级交通工具
    elseif EItemType.Fashion == itemType then return EEquipSlot.Fashion
    elseif EItemType.Wing == itemType then return EEquipSlot.Wing
    elseif EItemType.Relic == itemType then return EEquipSlot.Relic -- 圣物
    else
        return -1
    end
end

local function resetCBState()
    _dlg.CBNewAbility:SetCurStatus(0)
    _dlg.CBOrgAbility:SetCurStatus(0)
end

local function resetView()
    _dlg.Equip:SetImage("")
    _dlg.ResetInfo:ClearString()
    _dlg.EquipTip:ClearString()
    _dlg.ResetTip:ClearString()
    _dlg.ResetTip:SetAlign(0)
    _dlg.NeedItem:SetVisible(0)
    _dlg.NeedItemBG:SetVisible(0)
    _dlg.MaterialItem1:SetVisible(0)
    _dlg.MaterialItem2:SetVisible(0)
    _dlg.MaterialItem3:SetVisible(0)
    _dlg.ConsumeExp:SetVisible(0)
    _dlg.ConsumeMoney:SetVisible(0)
    _dlg.ResetAction:SetVisible(0)
    _dlg.SelectOrg:SetVisible(0)
    _dlg.SelectNew:SetVisible(0)
    _dlg.OrgAbility:SetVisible(0)
    _dlg.NewAbility:SetVisible(0)
    _dlg.ResetWarn:SetVisible(0)
    _dlg.ResetWarnFlag:SetVisible(0)
    _dlg.ResetWarnBG:SetVisible(0)
    _dlg.CBNewAbility:SetVisible(0)
    _dlg.CBOrgAbility:SetVisible(0)
    _dlg.Effect:SetVisible(0)
end

local function reset()
    _itemSlot = -1
    _slotInfo = nil
    _itemInfo = nil
    _equipInfo = nil
    _material1Id = 0
    _material2Id = 0
    _material3Id = 0
    _waitResponse = false
    resetCBState()
end

--空置时的展示
local function showEmpty()
    resetView()
    _dlg.EquipTip:ClearString()
    _dlg.EquipTip:AddString("#31727请放入武器或护甲#65535")
    _dlg.ResetTip:ClearString()
    _dlg.ResetTip:AddString("#01439祈求古神重塑装备的威能，重塑后#26592若选择新威能#01439需\n#65504供奉祭品。#65535")
    _dlg.ResetAction:SetVisible(1)
    _dlg.ResetAction:SetEnable(0)
end

local function showNoAbility()
    _dlg.ResetAction:SetVisible(1)
    _dlg.ResetAction:SetEnable(0)
    _dlg.ResetTip:ClearString()
    _dlg.ResetTip:AddString("#01439祈求古神重塑装备的威能，重塑后#26592若选择新威能#01439需\n#65504供奉祭品。#65535")
    _dlg.ResetInfo:SetVisible(1)
    _dlg.ResetInfo:ClearString()
    _dlg.ResetInfo:AddString("#53248装备还未被赐予威能，无法重塑")
end

local function showRankUpAbilityNoSelect()
    _dlg.ResetAction:SetVisible(1)
    _dlg.ResetAction:SetEnable(0)
    _dlg.ResetTip:ClearString()
    _dlg.ResetTip:AddString("#01439祈求古神重塑装备的威能，重塑后#26592若选择新威能#01439需\n#65504供奉祭品。#65535")
    _dlg.ResetInfo:SetVisible(1)
    _dlg.ResetInfo:ClearString()
    _dlg.ResetInfo:AddString("#53248装备有威能尚未选择，无法重塑")
end

local function descAbilityRarity(rarity)
    if rarity==1 then
        return "#22527(常见)"
    elseif rarity==2 then
        return "#65504(难得)"
    elseif rarity==3 then
        return "#64864(稀有)"
    elseif rarity==4 then
        return "#55711(罕见)"
    elseif rarity==5 then
        return "#63488(浮云)"
    end
    return ""
end

local function showReset()
    local staticRes = game:StaticRes()
    local itemId = _slotInfo.ItemID
    local dataitem = game:UIDataItem()
    local gameplayer = game:GetGamePlayer()

    local blessRank = _slotInfo:GetPropValue(EPropID.MPropIDEquipBlessRank)
    local ability = _slotInfo:GetPropValue(EPropID.MPropIDEquipBlessAbility)
    local abilityInfo = staticRes:FindEquipBlessAbility(ability)
    _dlg.OrgAbility:SetVisible(1)
    _dlg.OrgAbility:ClearString()
    _dlg.OrgAbility:AddString("#65120现威能  #65535"..abilityInfo :GetName().."#02016 "..blessRank.."级"..descAbilityRarity(abilityInfo.Rarity))

    _dlg.ResetInfo:ClearString()
    _dlg.ResetInfo:AddString("#65504重塑可获得重新选择威能的机会。")

    _dlg.ResetTip:ClearString()
    _dlg.ResetTip:SetAlign(2)
    _dlg.ResetTip:AddString("#31727鼠标左键移动到威能名称上可查看详细描述")

    _dlg.ResetWarn:SetVisible(1)
    _dlg.ResetWarn:ClearString()
    _dlg.ResetWarn:AddString("#64447重塑后如选择新威能需要供奉祭品。")
    _dlg.ResetWarnBG:SetVisible(1)
    _dlg.ResetWarnFlag:SetVisible(1)

    local blessRank = _slotInfo:GetPropValue(EPropID.MPropIDEquipBlessRank)
    local slotIdx = _itemInfo.Type --itemTypeToSlotIdx(_itemInfo.Type)
    local isItemOk = true

    local rankInfo = staticRes:FindEquipBlessRank(slotIdx, blessRank)

    _dlg.NeedItemBG:SetVisible(1)
    _dlg.NeedItem:SetVisible(1)
    
    local consumeId1=rankInfo.ReshapeConsumeItemID
    local consumeCount1=rankInfo.ReshapeConsumeItemCount
    local consumeId2=0
    local consumeCount2=1
    local consumeId3=0
    local consumeCount3=1
    local consumeExp = rankInfo.ReshapeConsumeGodhoodExp
    local consumeMoney = rankInfo.ReshapeConsumeMoney

    if consumeId1 ~= 0 then
        _material1Id = consumeId1
        if not showMaterialItem(1, consumeId1, consumeCount1) then
            isItemOk = false
        end
    end
    if consumeId2 ~= 0 then
        _material2Id = consumeId2
        if not showMaterialItem(2, consumeId2, consumeCount2) then
            isItemOk = false
        end
    end
    if consumeId3 ~= 0 then
        _material3Id = consumeId3
        if not showMaterialItem(3, consumeId3, consumeCount3) then
            isItemOk = false
        end
    end

    _dlg.ConsumeMoney:SetVisible(1)
    _dlg.ConsumeMoney.ItemCount:ClearString()
    if dataitem:GetMoney()>=consumeMoney then
        _dlg.ConsumeMoney.ItemCount:AddString("#26592"..tostring(consumeMoney))
    else
        _dlg.ConsumeMoney.ItemCount:AddString("#53248"..tostring(consumeMoney))
        isItemOk = false
    end

    _dlg.ConsumeExp:SetVisible(1)
    _dlg.ConsumeExp.ItemCount:ClearString()
    if gameplayer.GodhoodExp>=consumeExp then
        _dlg.ConsumeExp.ItemCount:AddString("#26592"..tostring(consumeExp))
    else
        _dlg.ConsumeExp.ItemCount:AddString("#53248"..tostring(consumeExp))
        isItemOk = false
    end

    _dlg.ResetAction:SetVisible(1)
    if isItemOk then
        _dlg.ResetAction:SetEnable(1)
    else
        _dlg.ResetAction:SetEnable(0)
    end
end

-- 展示赐福等级
local function showBlessLevel()
    local blessRank = _slotInfo:GetPropValue(EPropID.MPropIDEquipBlessRank)
    local blessLevel =_slotInfo:GetPropValue(EPropID.MPropIDEquipBlessLevel)
    if blessRank == 0 and blessLevel==0 then
        _dlg.EquipTip:ClearString()
        _dlg.EquipTip:AddString("#31727未获得赐福#65535")
    else
        _dlg.EquipTip:ClearString()
        local colorMap = {"65535", "02016", "01439", "65504", "64864", "55711"}
        Debug("bless rank="..tostring(blessRank))
        --_dlg.EquipTip:AddString("#"..colorMap[blessRank+1]..blessRank.."阶"..blessLevel.."级")
        _dlg.EquipTip:AddString("#"..colorMap[blessRank+1]..blessRank.."阶"..blessLevel.."级")
    end
end

local function showSelectAbility()
    local staticRes = game:StaticRes()

    _dlg.NewAbility:SetVisible(1)
    _dlg.OrgAbility:SetVisible(1)
    _dlg.CBNewAbility:SetVisible(1)
    _dlg.CBOrgAbility:SetVisible(1)

    local blessRank = _slotInfo:GetPropValue(EPropID.MPropIDEquipBlessRank)
    local orgAbility = _slotInfo:GetPropValue(EPropID.MPropIDEquipBlessAbility)
    local newAbility = _slotInfo:GetPropValue(EPropID.MPropIDEquipBlessCandidateAbility2)
    local orgAbilityInfo = staticRes:FindEquipBlessAbility(orgAbility)
    local newAbilityInfo = staticRes:FindEquipBlessAbility(newAbility)

    _dlg.OrgAbility:ClearString()
    _dlg.OrgAbility:AddString("#65120原威能  #65535"..orgAbilityInfo:GetName().."#02016 "..blessRank.."级"..descAbilityRarity(orgAbilityInfo.Rarity))
    _dlg.NewAbility:ClearString()
    _dlg.NewAbility:AddString("#65120新威能  #65535"..newAbilityInfo:GetName().."#02016 "..blessRank.."级"..descAbilityRarity(newAbilityInfo.Rarity))

    _dlg.ResetInfo:SetVisible(1)
    _dlg.ResetInfo:ClearString()
    _dlg.ResetInfo:AddString("古神赋予了#26592新威能#65535的征兆，请决定是否要#26592替换#65535已有的威能")

    _dlg.ResetTip:SetVisible(1)
    _dlg.ResetTip:SetAlign(2)
    _dlg.ResetTip:ClearString()
    _dlg.ResetTip:AddString("#31727鼠标左键移动到威能名称上可查看详细描述")

    local selectNew = _dlg.CBNewAbility:GetCurStatus()==1
    local selectOrg = _dlg.CBOrgAbility:GetCurStatus()==1

    _dlg.SelectOrg:SetVisible(1)
    _dlg.SelectNew:SetVisible(1)
    _dlg.SelectOrg:SetEnable(0)
    _dlg.SelectNew:SetEnable(0)
    if selectNew then
        local isItemOK = true
        _dlg.SelectNew:SetEnable(1)
        _dlg.NeedItemBG:SetVisible(1)
        _dlg.NeedItem:SetVisible(1)

        if newAbilityInfo.ConsumeItemID1 ~= 0 then
            _material1Id = newAbilityInfo.ConsumeItemID1
            if not showMaterialItem(1, _material1Id, newAbilityInfo.ConsumeItemCount1) then
                isItemOk = false
            end
        end
        if newAbilityInfo.ConsumeItemID2 ~= 0 then
            _material2Id = newAbilityInfo.ConsumeItemID2
            if not showMaterialItem(2, _material2Id, newAbilityInfo.ConsumeItemCount2) then
                isItemOk = false
            end
        end
        if newAbilityInfo.ConsumeItemID3 ~= 0 then
            _material3Id = newAbilityInfo.ConsumeItemID3
            if not showMaterialItem(3, _material3Id, newAbilityInfo.ConsumeItemCount3) then
                isItemOk = false
            end
        end

        local dataitem = game:UIDataItem()
        local gameplayer = game:GetGamePlayer()
        _dlg.ConsumeMoney:SetVisible(1)
        _dlg.ConsumeMoney.ItemCount:ClearString()
        if dataitem:GetMoney() >= newAbilityInfo.ConsumeMoney then
            _dlg.ConsumeMoney.ItemCount:AddString("#26592" .. tostring(newAbilityInfo.ConsumeMoney))
        else
            _dlg.ConsumeMoney.ItemCount:AddString("#53248" .. tostring(newAbilityInfo.ConsumeMoney))
            isItemOk = false
        end

        _dlg.ConsumeExp:SetVisible(1)
        _dlg.ConsumeExp.ItemCount:ClearString()
        if gameplayer.GodhoodExp >= newAbilityInfo.ConsumeGodhoodExp then
            _dlg.ConsumeExp.ItemCount:AddString("#26592" .. tostring(newAbilityInfo.ConsumeGodhoodExp))
        else
            _dlg.ConsumeExp.ItemCount:AddString("#53248" .. tostring(newAbilityInfo.ConsumeGodhoodExp))
            isItemOk = false
        end
        if isItemOK then
            _dlg.SelectNew:SetEnable(1)
        else
            _dlg.SelectNew:SetEnable(0)
        end
    elseif selectOrg then
        _dlg.SelectOrg:SetEnable(1)
    end
end

local function refreshView()
    if _itemSlot<0 then
        showEmpty()
        return
    else
        resetView()
        _dlg.Equip:SetImage(_slotInfo:GetImagePath())
        showBlessLevel()
        local ability = _slotInfo:GetPropValue(EPropID.MPropIDEquipBlessAbility)
        if ability == 0 then
            showNoAbility()
            return
        end
        local rankAbility = _slotInfo:GetPropValue(EPropID.MPropIDEquipBlessCandidateAbility)
        if rankAbility ~= 0 then
            showRankUpAbilityNoSelect()
            return
        end
        local resetAbility = _slotInfo:GetPropValue(EPropID.MPropIDEquipBlessCandidateAbility2)
        Debug("resetAbility="..resetAbility)
        if resetAbility~=0 then
            showSelectAbility()
            return
        end
        showReset()
    end
end

local function checkCanPutin(slot)
    local dataitem = game:UIDataItem()
    local staticRes = game:StaticRes()
    local slotData = dataitem:GetSlotData(slot)
    if slotData==nil then
        return false
    end
    local itemId = slotData.ItemID
    local itemInfo = staticRes:GetItemInfo(itemId)
    if itemInfo==nil then
        return false
    end
    --需要是装备
    if game:MaskValue(itemInfo.Type,EItemType.Equip)==0 then
        return false
    end
    local equipInfo = staticRes:GetEquipInfo(itemId)
    if equipInfo==nil then
        return false
    end
    Debug("BlessPoolID="..tostring(equipInfo.BlessPoolID))
    if equipInfo.BlessPoolID<=0 then
        return false
    end
    _itemSlot = slot
    _slotInfo = slotData
    _itemInfo = itemInfo
    _equipInfo = equipInfo
    return true
end
local function onAbilityTip(isNew)
    local ability = 0
    if isNew then
        ability = _slotInfo:GetPropValue(EPropID.MPropIDEquipBlessCandidateAbility2)
    else
        ability = _slotInfo:GetPropValue(EPropID.MPropIDEquipBlessAbility)
    end
    if ability==0 then
        return
    end
    local blessRank = _slotInfo:GetPropValue(EPropID.MPropIDEquipBlessRank)
    local staticRes = game:StaticRes()
    local abilityInfo = staticRes:FindEquipBlessAbility(ability)
    if abilityInfo==nil then
        return
    end
    local skillId = abilityInfo.SkillID
    local skillTip = game:GetSkillTip(skillId,blessRank)
    if isNew then
        _dlg.NewAbility:SetTipInfo(skillTip)
    else
        _dlg.OrgAbility:SetTipInfo(skillTip)
    end
end

local function onEquipSlotEvent(luadlg,eventCode,ctrlId,ctrl)
    if(eventCode==UIEventDef.TIN_MOUSEMOVE) then
        --显示物品tip信息
        if _itemSlot<0 then
            return
        end
        luadlg.Equip:SetTipInfo(game:UIDataItem():GetSlotTip(_itemSlot, false))
    elseif(eventCode==UIEventDef.TIN_MOUSECLICK) then
        local cmd = game:GetCursorOperationCmd()
        Debug("cmd="..tostring(cmd))
        if cmd~=EOperationCmd.Item_Pickup then
            return
        end
        local slot = game:GetCursorOperationCmdParam()
        Debug("slot="..tostring(slot))
        game:ClearCursorOperation()
        if not checkCanPutin(slot) then
            game:ShowMessage("该物品不能被赐福")
            return
        end
        _itemSlot = slot
        refreshView()
    elseif(eventCode==UIEventDef.TIN_MOUSERCLICK) then
        reset()
        refreshView()
    end
end

local function playEffect(mov)
    _dlg.Effect:SetImage(prefix_path.."/"..mov)
    _dlg.Effect:SetVisible(1)
    _dlg.Effect:Rewind()
    _dlg.Effect:Play()
end

local function sendResetAbility()
    if _waitResponse then
        return
    end
    Debug("sendResetAbility")
    _waitResponse = true
    local pkg = game:PrepareSendBuffer()
    pkg:WriteUInt32(0)
    pkg:WriteUInt32(_itemSlot)
    game:SendPackage(EPackageType.MSLGP_C_TYPE_RESETEQUIPBLESSABILITY)
end

local function sendSelectAbility(isSelectNew)
    if _waitResponse then
        return
    end
    _waitResponse = true
    local pkg = game:PrepareSendBuffer()
    pkg:WriteUInt32(0)
    pkg:WriteUInt32(_itemSlot)
    if isSelectNew then
        pkg:WriteUInt8(1)
    else
        pkg:WriteUInt8(0)
    end
    game:SendPackage(EPackageType.MSLGP_C_TYPE_SELECTEQUIPBLESSABILITY)

end

local function onEventProc(luadlg,eventCode,ctrlId,ctrl)
    if ctrlId==luadlg.Equip.CtrlID then
        onEquipSlotEvent(luadlg,eventCode,ctrlId,ctrl)
    elseif eventCode==UIEventDef.TIN_MOUSEMOVE then
        if ctrlId==luadlg.MaterialItem1.Item.CtrlID then
            _dlg.MaterialItem1.Item:SetTipInfo(game:GetItemTip(_material1Id))
        elseif ctrlId==luadlg.MaterialItem2.Item.CtrlID then
            _dlg.MaterialItem2.Item:SetTipInfo(game:GetItemTip(_material2Id))
        elseif ctrlId==luadlg.MaterialItem3.Item.CtrlID then
            _dlg.MaterialItem3.Item:SetTipInfo(game:GetItemTip(_material3Id))
        end
    elseif eventCode==UIEventDef.TTN_MOUSEMOVE and ctrlId==luadlg.NewAbility.CtrlID then
        onAbilityTip(true)
    elseif eventCode==UIEventDef.TTN_MOUSEMOVE and ctrlId==luadlg.OrgAbility.CtrlID then
        onAbilityTip(false)
    elseif eventCode==UIEventDef.TBN_CLICKED and ctrlId == luadlg.ResetAction.CtrlID then
        sendResetAbility()
    elseif eventCode==UIEventDef.TBN_CLICKED and ctrlId == luadlg.SelectOrg.CtrlID then
        sendSelectAbility(false)
    elseif eventCode==UIEventDef.TBN_CLICKED and ctrlId == luadlg.SelectNew.CtrlID then
        sendSelectAbility(true)
    elseif eventCode==UIEventDef.TBN_CLICKED and ctrlId == luadlg.CBNewAbility.CtrlID then
        if _dlg.CBNewAbility:GetCurStatus()==1 then
            _dlg.CBOrgAbility:SetCurStatus(0)
        end
        refreshView()
    elseif eventCode==UIEventDef.TBN_CLICKED and ctrlId == luadlg.CBOrgAbility.CtrlID then
        if _dlg.CBOrgAbility:GetCurStatus()==1 then
            _dlg.CBNewAbility:SetCurStatus(0)
        end
        refreshView()
    elseif eventCode==UIEventDef.TPIN_END and ctrlId==luadlg.Effect.CtrlID then
        _waitResponse = false
        _dlg.Effect:SetVisible(0)
        local slot = _itemSlot
        reset()
        checkCanPutin(slot)
        refreshView()
    end
end

local function onUIPackage(luadlg,pkgType,buffer)
    if pkgType==EPackageType.MSLGP_M_TYPE_OPENRESETBLESSEQUIPDLG then
        luadlg.Raw:ShowDlg(true)
        return
    end
    if not luadlg.Raw:GetVisible() then
        return
    end
    if pkgType==EPackageType.MSLGP_M_TYPE_RESETEQUIPBLESSABILITYRESULT then
        local _ = buffer:ReadUInt32()
        local result = buffer:ReadInt32()
        Debug("get bless result="..result)
        if result==0 then
            game:ShowMessage("重塑成功")
            playEffect("重塑光效.mgff")
        else
            game:ShowMessage("重塑失败")
        end
    elseif pkgType==EPackageType.MSLGP_M_TYPE_SELECTEQUIPBLESSABILITYRESULT then
        local _ = buffer:ReadUInt32()
        local result = buffer:ReadInt32()
        Debug("get select ability result="..result)
        if result==0 then
            playEffect("激活新威能光效.mgff")
        else
            game:ShowMessage("选择威能失败")
        end
    end
end

local function onShow(luadlg,show)
    reset()
    if show then
        refreshView()
    end
end

local function onRefresh(dlg)
    local slot = _itemSlot
    reset()
    if slot>=0 then
        checkCanPutin(slot)
    end
    refreshView()
end

local function createDlg(dlgmgr)
    local luadlg = dlgbuilder(dlgmgr,struct,prefix_path,3050,true)
    luadlg.Raw:SetCloseWhenMove(true)
    luadlg.OnEventProc = onEventProc
    luadlg.OnUIPackage = onUIPackage
    luadlg.OnShow = onShow
    luadlg.OnUpdateItemBar = onRefresh
    luadlg.OnUpdateItemCount = onRefresh
    HandlePackage(EPackageType.MSLGP_M_TYPE_RESETEQUIPBLESSABILITYRESULT,luadlg)
    HandlePackage(EPackageType.MSLGP_M_TYPE_SELECTEQUIPBLESSABILITYRESULT,luadlg)
    HandlePackage(EPackageType.MSLGP_M_TYPE_OPENRESETBLESSEQUIPDLG,luadlg)
    luadlg.ConsumeMoney.ItemIcon:SetImage(prefix_path.."/金币.mgff")
    luadlg.ConsumeExp.ItemIcon:SetImage(prefix_path.."/神识.mgff")
    _dlg = luadlg
    reset()
    refreshView()
    return luadlg
end

return {OnCreate=createDlg}