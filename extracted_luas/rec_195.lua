local dlgbuilder = require "dlg_builder"

local struct = require "uiblessequip_struct"
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
local _isRankUP = false

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

local function propName(propId)
    local baseId = game:BasePropID(propId)
    if baseId==EPropID.PropIDPhysicsAttUI then
        return "物攻"
    elseif baseId==EPropID.PropIDMagicAttUI then
        return "法攻"
    elseif baseId==EPropID.PropIDPhysicsDefUI then
        return "物防"
    elseif baseId==EPropID.PropIDMagicDefUI then
        return "法防"
    elseif baseId==EPropID.PropIDHPMaxUI then
        return "生命"
    end
    return ""
end

local function resetView()
    _dlg.Equip:SetImage("")
    _dlg.EquipErrTip:SetVisible(0)
    _dlg.EquipBlessAttrs:SetVisible(0)
    _dlg.EquipTip:ClearString()
    _dlg.BlessTip:ClearString()
    _dlg.NeedItem:SetVisible(0)
    _dlg.NeedItemBG:SetVisible(0)
    _dlg.MaterialItem1:SetVisible(0)
    _dlg.MaterialItem2:SetVisible(0)
    _dlg.MaterialItem3:SetVisible(0)
    _dlg.ConsumeExp:SetVisible(0)
    _dlg.ConsumeMoney:SetVisible(0)
    _dlg.RankUp:SetVisible(0)
    _dlg.Bless:SetVisible(0)
    _dlg.Bless:SetEnable(0)
    _dlg.SelectOrg:SetVisible(0)
    _dlg.SelectNew:SetVisible(0)
    _dlg.OrgAbility:SetVisible(0)
    _dlg.NewAbility:SetVisible(0)
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
    _isRankUP = false
end

--空置时的展示
local function showEmpty()
    resetView()
    _dlg.EquipTip:ClearString()
    _dlg.EquipTip:AddString("#31727请放入武器或护甲#65535")
    _dlg.BlessTip:ClearString()
    _dlg.BlessTip:AddString("#01439祈求古神为#65504武器和护甲#26592赐福#01439，获得神的力量。#65535")
    _dlg.Bless:SetVisible(1)
    _dlg.Bless:SetEnable(0)
end

local function showRankUp()
    local staticRes = game:StaticRes()
    local itemId = _slotInfo.ItemID
    local dataitem = game:UIDataItem()
    local gameplayer = game:GetGamePlayer()

    local blessRank = _slotInfo:GetPropValue(EPropID.MPropIDEquipBlessRank)
    local blessLevel = _slotInfo:GetPropValue(EPropID.MPropIDEquipBlessLevel)
    local eh = _slotInfo:GetPropValue(EPropID.MPropIDEnhanceTimes)
    local slotIdx = _itemInfo.Type --itemTypeToSlotIdx(_itemInfo.Type)

    local isItemOk = true

    local attrStr = "#65120觉醒后将获得\n#26592赐福次数增加10次\n#26592威能提升1级\n#26592可重新选择威能"

    local eh = _slotInfo:GetPropValue(EPropID.MPropIDEnhanceTimes)
    local nextRankInfo = staticRes:FindEquipBlessRank(slotIdx, blessRank+1)
    if eh<nextRankInfo.NeedEHLevel then
        isItemOk = false
        attrStr = "#53248强化至"..nextRankInfo.NeedEHLevel.."级才能被赐福"
    end
    _dlg.EquipBlessAttrs:SetVisible(1)
    _dlg.EquipBlessAttrs:ClearString()
    _dlg.EquipBlessAttrs:AddString(attrStr)

    _dlg.NeedItemBG:SetVisible(1)
    _dlg.NeedItem:SetVisible(1)
    
    local rankInfo = staticRes:FindEquipBlessRank(slotIdx, blessRank)
    local showMaterialItem = function(itemIndex, itemID, itemNum)
        local needItemInfo = staticRes:GetItemInfo(itemID)
        local materialItem = _dlg["MaterialItem" .. itemIndex]
        materialItem:SetVisible(1)
        materialItem.Item:SetImage(needItemInfo:GetImageName())
        materialItem.Count:SetEnable(0)
        materialItem.Count:ClearString()
        local count = dataitem:GetItemCount(itemID)
        if count < itemNum then
            materialItem.Count:AddString("#53248" .. count .. "/" .. itemNum)
            isItemOk = false
        else
            materialItem.Count:AddString("#26592"..count .. "/" .. itemNum)
        end
    end
    if rankInfo.ConsumeItemID1 ~= 0 then
        _material1Id = rankInfo.ConsumeItemID1
        showMaterialItem(1, rankInfo.ConsumeItemID1, rankInfo.ConsumeItemCount1)
    end
    if rankInfo.ConsumeItemID2 ~= 0 then
        _material2Id = rankInfo.ConsumeItemID2
        showMaterialItem(2, rankInfo.ConsumeItemID2, rankInfo.ConsumeItemCount2)
    end
    if rankInfo.ConsumeItemID3 ~= 0 then
        _material3Id = rankInfo.ConsumeItemID3
        showMaterialItem(3, rankInfo.ConsumeItemID3, rankInfo.ConsumeItemCount3)
    end

    _dlg.ConsumeExp:SetVisible(1)
    _dlg.ConsumeExp.ItemCount:ClearString()
    if gameplayer.GodhoodExp>=rankInfo.ConsumeGodhoodExp then
        _dlg.ConsumeExp.ItemCount:AddString("#26592"..tostring(rankInfo.ConsumeGodhoodExp))
    else
        _dlg.ConsumeExp.ItemCount:AddString("#53248"..tostring(rankInfo.ConsumeGodhoodExp))
        isItemOk = false
    end

    _dlg.ConsumeMoney:SetVisible(1)
    _dlg.ConsumeMoney.ItemCount:ClearString()
    if dataitem:GetMoney()>=rankInfo.ConsumeMoney then
        _dlg.ConsumeMoney.ItemCount:AddString("#26592"..tostring(rankInfo.ConsumeMoney))
    else
        _dlg.ConsumeMoney.ItemCount:AddString("#53248"..tostring(rankInfo.ConsumeMoney))
        isItemOk = false
    end

    _dlg.RankUp:SetVisible(1)
    if isItemOk then
        _dlg.RankUp:SetEnable(1)
    else
        _dlg.RankUp:SetEnable(0)
    end
end

local function showLevelUp()
    local staticRes = game:StaticRes()
    local itemId = _slotInfo.ItemID
    local dataitem = game:UIDataItem()
    local gameplayer = game:GetGamePlayer()

    local blessRank = _slotInfo:GetPropValue(EPropID.MPropIDEquipBlessRank)
    local blessLevel = _slotInfo:GetPropValue(EPropID.MPropIDEquipBlessLevel)
    local eh = _slotInfo:GetPropValue(EPropID.MPropIDEnhanceTimes)
    local slotIdx = _itemInfo.Type --itemTypeToSlotIdx(_itemInfo.Type)

    if blessRank == 0 and blessLevel==0 then
        _dlg.EquipTip:ClearString()
        _dlg.EquipTip:AddString("#31727未获得赐福#65535")
        local rankInfo = staticRes:FindEquipBlessRank(slotIdx, 0)
        Debug("eh="..tostring(rankInfo.NeedEHLevel))
        if eh<rankInfo.NeedEHLevel then
            _dlg.EquipErrTip:SetVisible(1)
            _dlg.EquipErrTip:ClearString()
            _dlg.EquipErrTip:AddString("#65120强化至"..rankInfo.NeedEHLevel.."级#53248才能被赐福")
            return
        end
    end
    
    local attrStr = "#65120赐福后获得\n#26592赐福等级增加1级\n#26592"..propName(_equipInfo.BlessPropID1).." + ".._equipInfo.BlessPropValue1.."\n#26592"
        ..propName(_equipInfo.BlessPropID2).." + ".._equipInfo.BlessPropValue2
    _dlg.EquipBlessAttrs:SetVisible(1)
    _dlg.EquipBlessAttrs:ClearString()
    _dlg.EquipBlessAttrs:AddString(attrStr)
    
    local blessTip = ""
    if blessRank==0 then
        blessTip = "#31727赐福达到10级将可以觉醒进阶，获得神力威能"
    elseif blessRank>0 and blessRank<5 then
        blessTip = "#31727赐福达到10级将可以觉醒进阶，升级神力威能"
    else
        blessTip = ""
    end
    _dlg.BlessTip:ClearString()
    _dlg.BlessTip:AddString(blessTip)
    
    _dlg.NeedItemBG:SetVisible(1)
    _dlg.NeedItem:SetVisible(1)
    
    local isItemOk = true
    local blessInfo = staticRes:FindEquipBlessLevel(slotIdx, blessRank, blessLevel)

    local showMaterialItem = function(itemIndex, itemID, itemNum)
        local needItemInfo = staticRes:GetItemInfo(itemID)
        local materialItem = _dlg["MaterialItem" .. itemIndex]
        materialItem:SetVisible(1)
        materialItem.Item:SetImage(needItemInfo:GetImageName())
        materialItem.Count:SetEnable(0)
        materialItem.Count:ClearString()
        local count = dataitem:GetItemCount(itemID)
        if count < itemNum then
            materialItem.Count:AddString("#53248" .. count .. "/" .. itemNum)
            isItemOk = false
        else
            materialItem.Count:AddString("#26592"..count .. "/" .. itemNum)
        end
    end
    if blessInfo.ConsumeItemID1 ~= 0 then
        _material1Id = blessInfo.ConsumeItemID1
        showMaterialItem(1, blessInfo.ConsumeItemID1, blessInfo.ConsumeItemCount1)
    end
    if blessInfo.ConsumeItemID2 ~= 0 then
        _material2Id = blessInfo.ConsumeItemID2
        showMaterialItem(2, blessInfo.ConsumeItemID2, blessInfo.ConsumeItemCount2)
    end
    if blessInfo.ConsumeItemID3 ~= 0 then
        _material3Id = blessInfo.ConsumeItemID3
        showMaterialItem(3, blessInfo.ConsumeItemID3, blessInfo.ConsumeItemCount3)
    end

    _dlg.ConsumeExp:SetVisible(1)
    _dlg.ConsumeExp.ItemCount:ClearString()
    if gameplayer.GodhoodExp>=blessInfo.ConsumeGodhoodExp then
        _dlg.ConsumeExp.ItemCount:AddString("#26592"..tostring(blessInfo.ConsumeGodhoodExp))
    else
        _dlg.ConsumeExp.ItemCount:AddString("#53248"..tostring(blessInfo.ConsumeGodhoodExp))
        isItemOk = false
    end

    _dlg.ConsumeMoney:SetVisible(1)
    _dlg.ConsumeMoney.ItemCount:ClearString()
    if dataitem:GetMoney()>=blessInfo.ConsumeMoney then
        _dlg.ConsumeMoney.ItemCount:AddString("#26592"..tostring(blessInfo.ConsumeMoney))
    else
        _dlg.ConsumeMoney.ItemCount:AddString("#53248"..tostring(blessInfo.ConsumeMoney))
        isItemOk = false
    end

    _dlg.Bless:SetVisible(1)
    if isItemOk then
        _dlg.Bless:SetEnable(1)
    else
        _dlg.Bless:SetEnable(0)
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

local function showSelectRankAbility()
    local staticRes = game:StaticRes()

    _dlg.NewAbility:SetVisible(1)
    _dlg.OrgAbility:SetVisible(1)

    local blessRank = _slotInfo:GetPropValue(EPropID.MPropIDEquipBlessRank)
    local orgAbility = _slotInfo:GetPropValue(EPropID.MPropIDEquipBlessAbility)
    local newAbility = _slotInfo:GetPropValue(EPropID.MPropIDEquipBlessCandidateAbility)
    local orgAbilityInfo = staticRes:FindEquipBlessAbility(orgAbility)
    local newAbilityInfo = staticRes:FindEquipBlessAbility(newAbility)

    _dlg.OrgAbility:ClearString()
    _dlg.OrgAbility:AddString("#65120原威能  #65535"..orgAbilityInfo:GetName().."#02016 "..blessRank.."级"..descAbilityRarity(orgAbilityInfo.Rarity))
    _dlg.NewAbility:ClearString()
    _dlg.NewAbility:AddString("#65120新威能  #65535"..newAbilityInfo:GetName().."#02016 "..blessRank.."级"..descAbilityRarity(newAbilityInfo.Rarity))

    _dlg.EquipBlessAttrs:SetVisible(1)
    _dlg.EquipBlessAttrs:ClearString()
    _dlg.EquipBlessAttrs:AddString("觉醒获得#26592新的威能#65535，\n请决定是否要#26592替换已有的威能")

    _dlg.BlessTip:SetVisible(1)
    _dlg.BlessTip:ClearString()
    _dlg.BlessTip:AddString("#31727鼠标左键移动到威能名称上可查看详细描述")

    _dlg.SelectNew:SetVisible(1)
    _dlg.SelectOrg:SetVisible(1)
end

local function refreshView()
    if _itemSlot<0 then
        showEmpty()
        return
    else
        resetView()
        _dlg.Equip:SetImage(_slotInfo:GetImagePath())
        showBlessLevel()
        --检测是否有未选择的重置祝福能力
        local resetAbility = _slotInfo:GetPropValue(EPropID.MPropIDEquipBlessCandidateAbility2)
        if resetAbility ~= 0 then
            _dlg.EquipErrTip:SetVisible(1)
            _dlg.EquipErrTip:ClearString()
            _dlg.EquipErrTip:AddString("#53248威能重置尚未完成，无法被赐福")
            return
        end
        --检测是否有未选择的突破能力
        local rankAbility = _slotInfo:GetPropValue(EPropID.MPropIDEquipBlessCandidateAbility)
        if rankAbility~=0 then
            showSelectRankAbility()
            return
        end
        --是否是最高等级了
        local slotIdx = _itemInfo.Type --itemTypeToSlotIdx(_itemInfo.Type)
        local blessRank = _slotInfo:GetPropValue(EPropID.MPropIDEquipBlessRank)
        local blessLevel = _slotInfo:GetPropValue(EPropID.MPropIDEquipBlessLevel)
        local nextLevelInfo = game:StaticRes():FindEquipBlessLevel(slotIdx, blessRank, blessLevel+1)
        if nextLevelInfo==nil then
            --是否有下一阶
            local nextRankInfo = game:StaticRes():FindEquipBlessLevel(slotIdx, blessRank+1, 0)
            if nextRankInfo==nil then
                _dlg.EquipErrTip:SetVisible(1)
                _dlg.EquipErrTip:ClearString()
                _dlg.EquipErrTip:AddString("#53248已达到最高赐福等级")
                return
            end
        end
        --是否突破
        if nextLevelInfo==nil then
            showRankUp()
        else
            showLevelUp()
        end
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

local function onAbilityTip(isNew)
    local ability = 0
    if isNew then
        ability = _slotInfo:GetPropValue(EPropID.MPropIDEquipBlessCandidateAbility)
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

local function sendBlessEquip()
    if _waitResponse then
        return
    end
    _waitResponse = true
    Debug("sendBlessEquip itemslot="..tostring(_itemSlot))
    local pkg = game:PrepareSendBuffer()
    pkg:WriteUInt32(0)
    pkg:WriteUInt32(_itemSlot)
    game:SendPackage(EPackageType.MSLGP_C_TYPE_BLESSEQUIP)
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
    elseif eventCode==UIEventDef.TBN_CLICKED and ctrlId==luadlg.Bless.CtrlID then
        sendBlessEquip()
        --赐福
    elseif eventCode==UIEventDef.TBN_CLICKED and ctrlId==luadlg.RankUp.CtrlID then
        --突破
        _isRankUP = true
        sendBlessEquip()
    elseif eventCode==UIEventDef.TBN_CLICKED and ctrlId==luadlg.SelectNew.CtrlID then
        sendSelectAbility(true)
    elseif eventCode==UIEventDef.TBN_CLICKED and ctrlId==luadlg.SelectOrg.CtrlID then
        sendSelectAbility(false)
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
    if pkgType==EPackageType.MSLGP_M_TYPE_OPENBLESSEQUIPDLG then
        luadlg.Raw:ShowDlg(true);
        return
    end
    if not luadlg.Raw:GetVisible() then
        return
    end
    if pkgType==EPackageType.MSLGP_M_TYPE_BLESSEQUIPRESULT then
        local _ = buffer:ReadUInt32()
        local result = buffer:ReadInt32()
        Debug("get bless result="..result)
        if result==0 then
            if _isRankUP then
                game:ShowMessage("觉醒成功")
                playEffect("觉醒进阶光效.mgff")
            else
                game:ShowMessage("赐福成功")
                playEffect("祈求赐福光效.mgff")
            end
        else
            game:ShowMessage("赐福失败")
        end
    elseif pkgType==EPackageType.MSLGP_M_TYPE_SELECTEQUIPBLESSABILITYRESULT then
        local _ = buffer:ReadUInt32()
        local result = buffer:ReadInt32()
        Debug("get select ability result="..result)
        if result==0 then
            playEffect("选择光效.mgff")
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
    local luadlg = dlgbuilder(dlgmgr,struct,prefix_path,3000,true)
    luadlg.Raw:SetCloseWhenMove(true)
    luadlg.OnEventProc = onEventProc
    luadlg.OnUIPackage = onUIPackage
    luadlg.OnShow = onShow
    luadlg.OnUpdateItemBar = onRefresh
    luadlg.OnUpdateItemCount = onRefresh
    HandlePackage(EPackageType.MSLGP_M_TYPE_BLESSEQUIPRESULT,luadlg)
    HandlePackage(EPackageType.MSLGP_M_TYPE_SELECTEQUIPBLESSABILITYRESULT,luadlg)
    HandlePackage(EPackageType.MSLGP_M_TYPE_OPENBLESSEQUIPDLG,luadlg)
    luadlg.ConsumeMoney.ItemIcon:SetImage(prefix_path.."/金币.mgff")
    luadlg.ConsumeExp.ItemIcon:SetImage(prefix_path.."/神识.mgff")
    _dlg = luadlg
    reset()
    refreshView()
    return luadlg
end

return {OnCreate=createDlg}