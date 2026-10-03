local dlgbuilder = require "dlg_builder"

local struct = require "uitransblessequipability_struct"
local prefix_path = "UIGame/UIBlessEquip"

local _fromItemSlot = -1
local _toItemSlot = -1
local _fromSlotInfo = nil
local _toSlotInfo = nil
local _fromItemInfo = nil
local _toItemInfo = nil
local _fromEquipInfo = nil
local _toEquipInfo = nil
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

local function resetView()
    _dlg.FromEquip:SetImage("")
    _dlg.FromEquipMask:SetVisible(0)
    _dlg.ToEquip:SetImage("")
    _dlg.ToEquipMask:SetVisible(0)
    _dlg.FromEquipTip:ClearString()
    _dlg.ToEquipTip:ClearString()
    _dlg.TransLine:SetVisible(0)
    _dlg.TransWarn:SetVisible(0)
    _dlg.TransTip:ClearString()
    _dlg.NeedItem:SetVisible(0)
    _dlg.NeedItemBG:SetVisible(0)
    _dlg.MaterialItem1:SetVisible(0)
    _dlg.MaterialItem2:SetVisible(0)
    _dlg.MaterialItem3:SetVisible(0)
    _dlg.ConsumeExp:SetVisible(0)
    _dlg.ConsumeMoney:SetVisible(0)
    _dlg.TransAction:SetVisible(1)
    _dlg.TransAction:SetEnable(0)
    _dlg.SuccessEffect:SetVisible(0)
end

local function reset()
    _fromItemSlot = -1
    _toItemSlot = -1
    _fromSlotInfo = nil
    _toSlotInfo = nil
    _fromItemInfo = nil
    _toItemInfo = nil
    _material1Id = 0
    _material2Id = 0
    _material3Id = 0
    _waitResponse = false
end

--空置时的展示
local function showEmpty()
    resetView()

    _dlg.FromEquipMask:SetVisible(1)
    _dlg.FromEquipTip:ClearString()
    _dlg.FromEquipTip:AddString("#31727放入被赐福过的装备")

    _dlg.TransTip:ClearString()
    _dlg.TransTip:AddString("#02016通过灌注可将装备的#65504赐福等级#02016和#65504威能#55711完全转移#02016至\n#02016另外一件同类型的装备")
end

local function showTrans()
    resetView()
    local staticRes = game:StaticRes()
    local dataitem = game:UIDataItem()
    local gameplayer = game:GetGamePlayer()

    local fromok = true
    local blessRankInfo = nil
    local blessLevelInfo = nil
    local fromSlotIdx = 0

    if _fromSlotInfo==nil then
        _dlg.FromEquipMask:SetVisible(1)
        _dlg.FromEquipTip:ClearString()
        _dlg.FromEquipTip:AddString("#31727放入被赐福过的装备")
        fromok = false
    else
        local fromBlessLevel = _fromSlotInfo:GetPropValue(EPropID.MPropIDEquipBlessLevel)
        local fromBlessRank = _fromSlotInfo:GetPropValue(EPropID.MPropIDEquipBlessRank)
        local rankAbility = _fromSlotInfo:GetPropValue(EPropID.MPropIDEquipBlessCandidateAbility)
        local resetAbility = _fromSlotInfo:GetPropValue(EPropID.MPropIDEquipBlessCandidateAbility2)
        _dlg.FromEquip:SetImage(_fromSlotInfo:GetImagePath())
        if fromBlessLevel==0 and fromBlessRank==0 then
            _dlg.FromEquipTip:ClearString()
            _dlg.FromEquipTip:AddString("#31727未获得赐福#65535")
            _dlg.TransTip:ClearString()
            _dlg.TransTip:AddString("#02016请放入#65120被赐福过#02016的装备")
            fromok = false
        elseif resetAbility~=0 then
            _dlg.FromEquipTip:ClearString()
            _dlg.FromEquipTip:AddString("#53248重塑威能尚未选择")
            _dlg.TransTip:ClearString()
            _dlg.TransTip:AddString("#02016装备#65120重塑#02016后还#65120未选择威能#02016，不能转移")
            fromok = false
        elseif rankAbility~=0 then
            _dlg.FromEquipTip:ClearString()
            _dlg.FromEquipTip:AddString("#53248觉醒威能尚未选择")
            _dlg.TransTip:ClearString()
            _dlg.TransTip:AddString("#02016装备#65120觉醒#02016后还#65120未选择威能#02016，不能转移")
            fromok = false
        else
            _dlg.FromEquipTip:ClearString()
            local colorMap = {"65535", "02016", "01439", "65504", "64864", "55711"}
            _dlg.FromEquipTip:AddString("#"..colorMap[fromBlessRank+1]..fromBlessRank.."阶"..fromBlessLevel.."级")
            fromSlotIdx = _fromItemInfo.Type --itemTypeToSlotIdx(_fromItemInfo.Type)
            blessRankInfo  = staticRes:FindEquipBlessRank(fromSlotIdx, fromBlessRank)
            blessLevelInfo = staticRes:FindEquipBlessLevel(fromSlotIdx, fromBlessRank, fromBlessLevel)
        end
    end

    local took = true
    if _toSlotInfo==nil then
        if fromok then
            _dlg.ToEquipMask:SetVisible(1)
            _dlg.ToEquipTip:ClearString()
            _dlg.ToEquipTip:AddString("#31727放入未被赐福的装备")
            _dlg.TransTip:ClearString()
            _dlg.TransTip:AddString("#02016请放入#65120同类型#02016的另一件装备\n#02016该装备必须#65120可被赐福\n#02016该装备#65120强化等级#02016需要至少#65120 "..blessRankInfo.NeedEHLevel.."#02016级")
        end
        took =false
    else
        local toSlotIdx = _toItemInfo.Type --itemTypeToSlotIdx(_toItemInfo.Type)
        local toEH = _toSlotInfo:GetPropValue(EPropID.MPropIDEnhanceTimes)
        local toBlessLevel = _toSlotInfo:GetPropValue(EPropID.MPropIDEquipBlessLevel)
        local toBlessRank = _toSlotInfo:GetPropValue(EPropID.MPropIDEquipBlessRank)
        _dlg.ToEquip:SetImage(_toSlotInfo:GetImagePath())
        if fromok and fromSlotIdx~=toSlotIdx then
            _dlg.ToEquipTip:ClearString()
            _dlg.ToEquipTip:AddString("#53248装备类型不匹配")
            _dlg.TransTip:ClearString()
            _dlg.TransTip:AddString("#02016原装备和被灌注的装备#65120装备位置#02016必须一致")
            took = false
        elseif _toEquipInfo.BlessPoolID==0 then
            _dlg.ToEquipTip:ClearString()
            _dlg.ToEquipTip:AddString("#53248不能被赐福")
            if fromok then
                _dlg.TransTip:ClearString()
                _dlg.TransTip:AddString("#02016被灌注的装备品质过低，不能被#65120赐福")
            end
            took = false
        elseif toBlessLevel~=0 or toBlessRank~=0 then
            _dlg.ToEquipTip:ClearString()
            local colorMap = {"65535", "02016", "01439", "65504", "64864", "55711"}
            _dlg.ToEquipTip:AddString("#"..colorMap[toBlessRank+1]..toBlessRank.."阶"..toBlessLevel.."级")
            if fromok then
                _dlg.TransTip:ClearString()
                _dlg.TransTip:AddString("#02016被灌注的装备必须#65120未被赐福#02016过")
            end
            took = false
        elseif fromok and toEH<blessRankInfo.NeedEHLevel then
            _dlg.ToEquipTip:ClearString()
            _dlg.ToEquipTip:AddString("#53248需要强化至"..blessRankInfo.NeedEHLevel.."级")
            _dlg.TransTip:ClearString()
            _dlg.TransTip:AddString("#02016新装备#65120强化等级#02016不满足需求")
            took = false
        else
            _dlg.ToEquipTip:ClearString()
            _dlg.ToEquipTip:AddString("#02016可被灌注")
            if fromok then
                _dlg.TransTip:ClearString()
                _dlg.TransTip:AddString("#02016原装备的#65504赐福等级#02016和#65504威能#02016将被#55711完整转移")
            end
        end
    end

    if not (fromok and took) then
        _dlg.TransWarn:SetVisible(1)
        return
    else
        _dlg.TransLine:SetVisible(1)
        _dlg.FromEquipMask:SetVisible(1)
        _dlg.ToEquipMask:SetVisible(1)
    end

    local isItemOk = true
    _dlg.NeedItem:SetVisible(1)
    _dlg.NeedItemBG:SetVisible(1)

    local consumeId1=blessLevelInfo.TransConsumeItemID1
    local consumeCount1=blessLevelInfo.TransConsumeItemCount1
    local consumeId2=blessLevelInfo.TransConsumeItemID2
    local consumeCount2=blessLevelInfo.TransConsumeItemCount2
    local consumeId3=blessLevelInfo.TransConsumeItemID3
    local consumeCount3=blessLevelInfo.TransConsumeItemCount3
    local consumeExp = blessLevelInfo.TransConsumeGodhoodExp
    local consumeMoney = blessLevelInfo.TransConsumeMoney

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

    if isItemOk then
        _dlg.TransAction:SetEnable(1)
    else
        _dlg.TransAction:SetEnable(0)
    end
end

local function refreshView()
    if _fromItemSlot<0 and _toItemSlot<0 then
        showEmpty()
        return
    else
        showTrans()
    end
end

local function resetFromInfo()
    _fromItemSlot = -1
    _fromSlotInfo = nil
    _fromItemInfo = nil
    _fromEquipInfo = nil
end

local function resetToInfo()
    _toItemSlot = -1
    _toSlotInfo = nil
    _toItemInfo = nil
    _toEquipInfo = nil
end

local function checkFromCanPutin(slot)
    if slot==_toItemSlot then
        --取消toslot
        resetToInfo()
    end
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
    _fromItemSlot = slot
    _fromSlotInfo = slotData
    _fromItemInfo = itemInfo
    _fromEquipInfo = equipInfo
    return true
end

local function onFromEquipSlotEvent(luadlg,eventCode,ctrlId,ctrl)
    if(eventCode==UIEventDef.TIN_MOUSEMOVE) then
        --显示物品tip信息
        if _fromItemSlot<0 then
            return
        end
        luadlg.FromEquip:SetTipInfo(game:UIDataItem():GetSlotTip(_fromItemSlot, false))
    elseif(eventCode==UIEventDef.TIN_MOUSECLICK) then
        local cmd = game:GetCursorOperationCmd()
        Debug("cmd="..tostring(cmd))
        if cmd~=EOperationCmd.Item_Pickup then
            return
        end
        local slot = game:GetCursorOperationCmdParam()
        Debug("slot="..tostring(slot))
        game:ClearCursorOperation()
        if not checkFromCanPutin(slot) then
            game:ShowMessage("该物品不能用于灌注")
            return
        end
        refreshView()
    elseif(eventCode==UIEventDef.TIN_MOUSERCLICK) then
        _fromItemSlot = -1 
        _fromSlotInfo = nil
        _fromItemInfo = nil
        _fromEquipInfo = nil
        refreshView()
    end
end

local function checkToCanPutin(slot)
    if slot==_fromItemSlot then
        resetFromInfo()
    end
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
    _toItemSlot = slot
    _toSlotInfo = slotData
    _toItemInfo = itemInfo
    _toEquipInfo = equipInfo
    return true
end

local function onToEquipSlotEvent(luadlg,eventCode,ctrlId,ctrl)
    if(eventCode==UIEventDef.TIN_MOUSEMOVE) then
        --显示物品tip信息
        if _toItemSlot<0 then
            return
        end
        luadlg.ToEquip:SetTipInfo(game:UIDataItem():GetSlotTip(_toItemSlot, false))
    elseif(eventCode==UIEventDef.TIN_MOUSECLICK) then
        local cmd = game:GetCursorOperationCmd()
        Debug("cmd="..tostring(cmd))
        if cmd~=EOperationCmd.Item_Pickup then
            return
        end
        local slot = game:GetCursorOperationCmdParam()
        Debug("slot="..tostring(slot))
        game:ClearCursorOperation()
        if not checkToCanPutin(slot) then
            game:ShowMessage("该物品不能被灌注")
            return
        end
        refreshView()
    elseif(eventCode==UIEventDef.TIN_MOUSERCLICK) then
        _toItemSlot = -1 
        _toSlotInfo = nil
        _toItemInfo = nil
        _toEquipInfo = nil
        refreshView()
    end
end

local function sendTrans()
    if _waitResponse then
        return
    end
    _waitResponse = true
    local pkg = game:PrepareSendBuffer()
    pkg:WriteUInt32(0)
    pkg:WriteUInt32(_fromItemSlot)
    pkg:WriteUInt32(_toItemSlot)
    game:SendPackage(EPackageType.MSLGP_C_TYPE_TRANSEQUIPBLESS)
end

local function playSuccessEffect()
    _dlg.SuccessEffect:SetVisible(1)
    _dlg.SuccessEffect:Rewind()
    _dlg.SuccessEffect:Play()
end

local function onEventProc(luadlg,eventCode,ctrlId,ctrl)
    if ctrlId==luadlg.FromEquip.CtrlID then
        onFromEquipSlotEvent(luadlg,eventCode,ctrlId,ctrl)
    elseif ctrlId==luadlg.ToEquip.CtrlID then
        onToEquipSlotEvent(luadlg,eventCode,ctrlId,ctrl)
    elseif eventCode==UIEventDef.TIN_MOUSEMOVE then
        if ctrlId==luadlg.MaterialItem1.Item.CtrlID then
            _dlg.MaterialItem1.Item:SetTipInfo(game:GetItemTip(_material1Id))
        elseif ctrlId==luadlg.MaterialItem2.Item.CtrlID then
            _dlg.MaterialItem2.Item:SetTipInfo(game:GetItemTip(_material2Id))
        elseif ctrlId==luadlg.MaterialItem3.Item.CtrlID then
            _dlg.MaterialItem3.Item:SetTipInfo(game:GetItemTip(_material3Id))
        end
    elseif eventCode==UIEventDef.TBN_CLICKED and ctrlId == luadlg.TransAction.CtrlID then
        sendTrans()
    elseif eventCode==UIEventDef.TPIN_END and ctrlId==luadlg.SuccessEffect.CtrlID then
        --播放结束
        _waitResponse = false
        _dlg.SuccessEffect:SetVisible(0)
        game:ShowMessage("转移成功")
        reset()
        resetView()
    end
end

local function onUIPackage(luadlg,pkgType,buffer)
    if pkgType==EPackageType.MSLGP_M_TYPE_OPENTRANSBLESSEQUIPDLG then
        luadlg.Raw:ShowDlg(true)
        return
    end
    if not luadlg.Raw:GetVisible() then
        return
    end
    if pkgType==EPackageType.MSLGP_M_TYPE_TRANSEQUIPBLESSRESULT then
        local _ = buffer:ReadUInt32()
        local result = buffer:ReadInt32()
        Debug("get bless result="..result)
        if result==0 then
            playSuccessEffect()
        else
            game:ShowMessage("转移失败")
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
    local fromSlot = _fromItemSlot
    local toSlot = _toItemSlot
    reset()
    if fromSlot>=0 then
        checkFromCanPutin(fromSlot)
    end
    if toSlot>=0 then
        checkToCanPutin(toSlot)
    end
    refreshView()
end

local function createDlg(dlgmgr)
    local luadlg = dlgbuilder(dlgmgr,struct,prefix_path,3100,true)
    luadlg.Raw:SetCloseWhenMove(true)
    luadlg.OnEventProc = onEventProc
    luadlg.OnUIPackage = onUIPackage
    luadlg.OnShow = onShow
    luadlg.OnUpdateItemBar = onRefresh
    luadlg.OnUpdateItemCount = onRefresh
    HandlePackage(EPackageType.MSLGP_M_TYPE_TRANSEQUIPBLESSRESULT,luadlg)
    HandlePackage(EPackageType.MSLGP_M_TYPE_OPENTRANSBLESSEQUIPDLG,luadlg)
    luadlg.ConsumeMoney.ItemIcon:SetImage(prefix_path.."/金币.mgff")
    luadlg.ConsumeExp.ItemIcon:SetImage(prefix_path.."/神识.mgff")
    _dlg = luadlg
    reset()
    refreshView()
    return luadlg
end

return {OnCreate=createDlg}