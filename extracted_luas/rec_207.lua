local dlgbuilder = require "dlg_builder"
local idtool = require "id_parse_tool"
local ScriptEvent = require "script_event"
local propinfo = require "item_prop_info"

local struct = require "uiresetequipeffect_struct"
local prefix_path = "UIGame/UIResetEquipAwakeEffect"
local maxLine = 19 
local MAX_MATERIAL_COUNT = 5

local _dlg = nil
local _waitResponse = false
local _itemSlot = -1
local _slotInfo
local _itemInfo
local _equipInfo
local _meetRequire = false
local _materialIds = {}

local function reset()
    _waitResponse = false
    _itemSlot = -1
    _slotInfo = nil
    _itemInfo = nil
    _equipInfo = nil
    _meetRequire = false
    for i = 1, MAX_MATERIAL_COUNT do
        _materialIds[i] = 0
    end
end

local function resetView()
    _dlg.ConsumeMoney.ItemIcon:SetImage(prefix_path.."/金币.mgff")
    _dlg.ConsumeExp.ItemIcon:SetImage(prefix_path.."/神识.mgff")
    _dlg.Equip:SetImage("")
    _dlg.EquipTip:SetVisible(1)
    _dlg.NeedLevel:ClearString()
    _dlg.NeedGodhood:ClearString()
    for i = 1, 5 do
        _dlg["MaterialItem" .. i]:SetVisible(0)
    end
    _dlg.ConsumeExp:SetVisible(0)
    _dlg.ConsumeMoney:SetVisible(0)
    _dlg.NoItemWarnTip:SetVisible(0)
    _dlg.ResetAction:SetEnable(0)
    _dlg.NeedItem:SetVisible(0)
    _dlg.NeedItemBG:SetVisible(0)
    _dlg.Equip:SetTipInfo("")

    _dlg.EffectScrollBar:SetVisible(0)
    _dlg.EffectsBG:SetVisible(0)
    _dlg.EquipEffects:SetVisible(0)
    _lineOffset = 0
end

local function showMaterialItem(itemIndex, itemID, itemNum)
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
        materialItem.Count:AddString("#26592"..count .. "/" .. itemNum)
        return true
    end
end

local function getRarityDesc(rarity)
    local rarityInfos = {
        {properbility=0.0198, desc="#FF0000#浮云 "},
        {properbility=0.0498, desc="#DE30FF#罕见 "},
        {properbility=0.0998, desc="#FFAE00#稀有 "},
        {properbility=0.1998, desc="#FFFF00#难得 "},
        {properbility=0.9998, desc="#52FFFF#常见 "},
        {properbility=1, desc="#63FF4A#必出 "},
    }
    for _, info in ipairs(rarityInfos) do
        if rarity <= info.properbility then
            return info.desc
        end
    end
end

local function refreshView()
    resetView()
    if _itemSlot < 0 then
        return
    end
    _meetRequire = true
    local gameplayer = game:GetGamePlayer()
    local dataitem = game:UIDataItem()

    _dlg.Equip:SetImage(_slotInfo:GetImagePath())
    _dlg.EquipTip:SetVisible(0)
    _dlg.NeedLevel:ClearString()
    local resetInfo = idtool.FindResetEquipAwakeEffect(_slotInfo.ItemID)
    if gameplayer.Grade >= resetInfo.needLevel then
        _dlg.NeedLevel:AddString("#65504需要等级达到 #65535" .. resetInfo.needLevel)
    else
        _dlg.NeedLevel:AddString("#65504需要等级达到 #65535" .. resetInfo.needLevel .. " #63488（未达成）")
        _meetRequire = false
    end

    _dlg.NeedGodhood:ClearString()
    if resetInfo.needGodLevel > 0 then
        local godhoodInfo = idtool.FindGodhoodLevel(resetInfo.needGodLevel)
        if gameplayer.GodhoodLevel >= resetInfo.needGodLevel then
            _dlg.NeedGodhood:AddString("#65504需要神格达到 #65535" .. godhoodInfo.name)
        else
            _dlg.NeedGodhood:AddString("#65504需要神格达到 #65535" .. godhoodInfo.name .. " #63488（未达成）")
            _meetRequire = false
        end
    end

    _dlg.NeedItem:SetVisible(1)
    _dlg.NeedItemBG:SetVisible(1)

    -- 检查材料
    local noMaterial = true
    for i = 1, MAX_MATERIAL_COUNT do
        if resetInfo.materials[i] and resetInfo.materials[i].id ~= 0 then
            noMaterial = false
            break
        end
    end
    if noMaterial then
        _dlg.NoItemWarnTip:SetVisible(1)
        _meetRequire = false
    else
        for i = 1, MAX_MATERIAL_COUNT do
            if resetInfo.materials[i] and resetInfo.materials[i].id ~= 0 then
                _materialIds[i] = resetInfo.materials[i].id
                if not showMaterialItem(i, resetInfo.materials[i].id, resetInfo.materials[i].count) then
                    _meetRequire = false
                end
            end
        end
    end

    _dlg.ConsumeMoney:SetVisible(1)
    _dlg.ConsumeMoney.ItemCount:ClearString()
    if dataitem:GetMoney() >= resetInfo.needMoney then
        _dlg.ConsumeMoney.ItemCount:AddString("#26592" .. tostring(resetInfo.needMoney))
    else
        _dlg.ConsumeMoney.ItemCount:AddString("#53248" .. tostring(resetInfo.needMoney))
        _meetRequire = false
    end

    _dlg.ConsumeExp:SetVisible(1)
    _dlg.ConsumeExp.ItemCount:ClearString()
    if gameplayer.GodhoodExp >= resetInfo.needGodExp then
        _dlg.ConsumeExp.ItemCount:AddString("#26592" .. tostring(resetInfo.needGodExp))
    else
        _dlg.ConsumeExp.ItemCount:AddString("#53248" .. tostring(resetInfo.needGodExp))
        _meetRequire = false
    end

    if _meetRequire then
        _dlg.ResetAction:SetEnable(1)
    end

    -- 右边的属性展示框
    _dlg.EquipEffects:SetVisible(1)
    _dlg.EffectScrollBar:SetVisible(1)
    _dlg.EffectsBG:SetVisible(1)
    Debug("BasePropIDPassiveSkill=" .. tostring(propinfo.PropID.BasePropIDPassiveSkill))
    local skillProps = _slotInfo:GetPropsByBaseID(propinfo.PropID.BasePropIDPassiveSkill)
    local skillId = 0
    local skillLevel = 0
    for _, prop in ipairs(skillProps) do
        skillId = math.floor(prop.value / 65536)
        skillLevel = prop.value % 65536
        break
    end
    _dlg.EquipEffects:ClearText()
    local pool = idtool.FindEquipAwakeEffectPool(_equipInfo.AwakeEffectPool)
    if pool then
        local totalWeight = 0
        for _, item in ipairs(pool) do
            totalWeight = totalWeight + item.weight
        end
        for _, item in ipairs(pool) do
            local rarity = item.weight / totalWeight
            local skillInfo = game:ParseSpecifySkill(item.skillId, item.skillLevel)
            if skillId == item.skillId and skillLevel == item.skillLevel then
                _dlg.EquipEffects:AddString(getRarityDesc(rarity) .. "#D3D61F#" .. skillInfo.Desc .. "\n", false)
            else
                _dlg.EquipEffects:AddString(getRarityDesc(rarity) .. "#7B7D7B#" .. skillInfo.Desc .. "\n", false)
            end
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
    local resetInfo = idtool.FindResetEquipAwakeEffect(itemId)
    if resetInfo==nil then
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
            game:ShowMessage("#d60000#该物品不能被重置特效")
            return
        end
        _itemSlot = slot
        refreshView()
    elseif(eventCode==UIEventDef.TIN_MOUSERCLICK) then
        reset()
        refreshView()
    end
end

local function sendResetCmd()
    if _waitResponse then
        return
    end
    Debug("sendResetCmd, itemSlot="..tostring(_itemSlot))
    game:SendCallScriptPacket(ScriptEvent.ResetEquipAwakeEffect, {itemslot=_itemSlot})
    _waitResponse = true
end

local function onShow(luadlg,show)
    reset()
    if show then
        refreshView()
    end
end

local function onRefresh(dlg)
    if not checkCanPutin(_itemSlot) then
        reset()
    end
    refreshView()
end

local function onEventProc(luadlg, eventCode, ctrlId, ctrl)
    if ctrlId == luadlg.Equip.CtrlID then
        onEquipSlotEvent(luadlg, eventCode, ctrlId, ctrl)
    elseif eventCode == UIEventDef.TIN_MOUSEMOVE then
        for i = 1, 5 do
            if ctrlId == luadlg["MaterialItem" .. i].Item.CtrlID then
                _dlg["MaterialItem" .. i].Item:SetTipInfo(game:GetItemTip(_materialIds[i]))
            end
        end
    elseif eventCode == UIEventDef.TBN_CLICKED and ctrlId == luadlg.ResetAction.CtrlID then
        sendResetCmd()
    end
end

local function onCallScript(dlg,event,obj)
    Debug("reset equip awake effect onCallScript event="..tostring(event))
    if event==ScriptEvent.ResetEquipAwakeEffectResult then
        if obj.ret==0 then
            game:ShowMessage("#ffffff#重置成功")
        elseif obj.ret==-99 then
            game:ShowMessage("玩家繁忙中")
        else
            game:ShowMessage("#d60000#重置失败 "..tostring(obj.ret))
        end
        _waitResponse = false
        refreshView()
    elseif event==ScriptEvent.OpenResetEquipAwakeEffectDlg then
        _waitResponse = false
        _dlg.Raw:ShowDlg(true)
    end
end

local function createDlg(dlgmgr)
    local luadlg = dlgbuilder(dlgmgr, struct, prefix_path, 3000, true)
    luadlg.Raw:SetCloseWhenMove(true)
    luadlg.EffectScrollBar:SetListener(luadlg.EquipEffects:ToScrollVListener())
    luadlg.OnEventProc = onEventProc
    luadlg.OnShow = onShow
    luadlg.OnUpdateItemBar = onRefresh
    luadlg.OnUpdateItemCount = onRefresh
    luadlg.OnCallScript = onCallScript
    HandleCallScript(ScriptEvent.OpenResetEquipAwakeEffectDlg, luadlg)
    HandleCallScript(ScriptEvent.ResetEquipAwakeEffectResult, luadlg)
    _dlg = luadlg
    reset()
    refreshView()
    return luadlg
end

return {OnCreate = createDlg}
