local dlgbuilder = require "dlg_builder"
local idtool = require "id_parse_tool"
local ScriptEvent = require "script_event"

local struct = require "uimythicequipawake_struct"
local prefix_path = "UIGame/UIMythicEquipAwake"

local MAX_MATERIAL_COUNT = 5

local _dlg = nil
local _waitResponse = false
local _mainEquipSlot = -1
local _mainSlotInfo = nil   
local _mainEquipInfo = nil
local _assistiveEquipSlot = -1
local _assistiveSlotInfo = nil
local _assistiveEquipInfo = nil
local _targetEquipInfo = nil
local _meetRequire = false
local _materialIds = {}

local function reset()
    _waitResponse = false
    _mainEquipSlot = -1
    _assistiveEquipSlot = -1
    _mainSlotInfo = nil
    _mainEquipInfo = nil
    _assistiveSlotInfo = nil
    _assistiveEquipInfo = nil
    _targetEquipInfo = nil
    _meetRequire = false
    for i = 1, MAX_MATERIAL_COUNT do
        _materialIds[i] = 0
    end
end

local function resetView()
    _dlg.ConsumeMoney.ItemIcon:SetImage(prefix_path.."/金币.mgff")
    _dlg.ConsumeExp.ItemIcon:SetImage(prefix_path.."/神识.mgff")
    
    _dlg.MainEquip:SetImage("")
    _dlg.MainEquipTip:SetVisible(0)
    _dlg.AssistiveEquip:SetImage("")
    _dlg.AssistiveEquipTip:SetVisible(0)
    _dlg.TargetEquip:SetImage("")
    
    _dlg.MainEquipActive:SetVisible(0)
    _dlg.AssistiveEquipActive:SetVisible(0)
    _dlg.MainEquipLineActive:SetVisible(0)
    _dlg.AssistiveEquipLineActive:SetVisible(0)
    _dlg.TargetEquipBGActive:SetVisible(0)
    
    for i = 1, MAX_MATERIAL_COUNT do
        _dlg["MaterialItem"..i]:SetVisible(0)
    end
    
    _dlg.ConsumeExp:SetVisible(0)
    _dlg.ConsumeMoney:SetVisible(0)
    _dlg.AwakeBtn:SetEnable(0)
    _dlg.NeedItem:SetVisible(0)
    _dlg.NeedItemBG:SetVisible(0)
    _dlg.AwakeTip:SetVisible(1)

    _dlg.NeedLevel:ClearString()
    _dlg.NeedGodhood:ClearString()

    _dlg.MainEquip:SetTipInfo("")
    _dlg.AssistiveEquip:SetTipInfo("")
    _dlg.TargetEquip:SetTipInfo("")

    _dlg.NoItemWarnTip:SetVisible(0)
end

local function showMaterialItem(itemIndex, itemID, itemNum)
    if itemID == 0 then return true end
    
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

local function checkCanPutin(slot, isMain)
    local dataitem = game:UIDataItem()
    local staticRes = game:StaticRes()
    local slotData = dataitem:GetSlotData(slot)

    if not isMain and _mainSlotInfo==nil then
        return -3
    end
    
    if slotData == nil then return -1 end
    
    local itemId = slotData.ItemID
    local itemInfo = staticRes:GetItemInfo(itemId)
    
    if itemInfo == nil then return -1 end
    if game:MaskValue(itemInfo.Type, EItemType.Equip) == 0 then return -1 end
    
    local equipInfo = staticRes:GetEquipInfo(itemId)
    if equipInfo == nil then return -1 end

    if isMain then
        local awakeInfo = idtool.FindAwakeMythicEquip(itemId)
        if awakeInfo == nil then 
            Debug("main equip "..tostring(itemId).." awakeInfo == nil")
            return -1
        end
    else
        local awakeInfo = idtool.FindAwakeMythicEquip(_mainSlotInfo.ItemID)
        if awakeInfo == nil then 
            Debug("main equip "..tostring(_mainSlotInfo.ItemID).." awakeInfo == nil")
            return -1
        end
        if awakeInfo[itemId] == nil then return -1 end
        awakeInfo = awakeInfo[itemId]
        local meedProps = false
        local hasNonZeroProp = false
        for i = 1, #awakeInfo.assistProps do
            local prop = awakeInfo.assistProps[i]
            if prop.id ~= 0 then
                hasNonZeroProp = true
                if slotData:GetPropValue(prop.id) == prop.value then
                    meedProps = true
                    break
                else
                    return -2
                end
            end
        end
        if not hasNonZeroProp then
            meedProps = true
        end
        if not meedProps then return -2 end
    end

    if isMain then
        _mainEquipSlot = slot
        _mainSlotInfo = slotData
        _mainEquipInfo = itemInfo
    else
        _assistiveEquipSlot = slot
        _assistiveSlotInfo = slotData
        _assistiveEquipInfo = itemInfo
    end
    
    return 0
end

local function refreshView()
    resetView()

    local gameplayer = game:GetGamePlayer()
    local dataitem = game:UIDataItem()

    if _mainEquipSlot >= 0 then
        _dlg.MainEquip:SetImage(_mainSlotInfo:GetImagePath())
        _dlg.MainEquipActive:SetVisible(0)
        _dlg.MainEquipLineActive:SetVisible(1)
    else
        _dlg.MainEquip:SetImage("")
        _dlg.MainEquipActive:SetVisible(1)
        _dlg.MainEquipTip:SetVisible(1)
        _dlg.MainEquipLineActive:SetVisible(0)
        _meetRequire = false
    end
    
    if _assistiveEquipSlot >= 0 then
        _dlg.AssistiveEquip:SetImage(_assistiveSlotInfo:GetImagePath())
        _dlg.AssistiveEquipActive:SetVisible(0)
    else
        _dlg.AssistiveEquip:SetImage("")
        if _mainSlotInfo ~= nil then
            _dlg.AssistiveEquipActive:SetVisible(1)
            _dlg.AssistiveEquipTip:SetVisible(1)
        else
            _dlg.AssistiveEquipActive:SetVisible(0)
        end
    end
    
    if _mainEquipSlot >= 0 and _assistiveEquipSlot >= 0 then
        _meetRequire = true
        _dlg.TargetEquipBGActive:SetVisible(1)
        local awakeInfo = idtool.FindAwakeMythicEquip(_mainSlotInfo.ItemID)[_assistiveSlotInfo.ItemID]
        local productInfo = game:StaticRes():GetItemInfo(awakeInfo.productId)
        _dlg.TargetEquip:SetImage(productInfo:GetImageName())
        _targetEquipInfo = productInfo

        _dlg.NeedLevel:ClearString()
        if gameplayer.Grade>=awakeInfo.needLevel then
            _dlg.NeedLevel:AddString("#65504需要等级达到 #65535"..awakeInfo.needLevel)
        else
            _dlg.NeedLevel:AddString("#65504需要等级达到 #65535"..awakeInfo.needLevel.." #63488（未达成）")
            _meetRequire = false
        end

        _dlg.NeedGodhood:ClearString()
        if awakeInfo.needGodLevel>0 then
            local godhoodInfo = idtool.FindGodhoodLevel(awakeInfo.needGodLevel)
            if gameplayer.GodhoodLevel>=awakeInfo.needGodLevel then
                _dlg.NeedGodhood:AddString("#65504需要神格达到 #65535"..godhoodInfo.name)
            else
                _dlg.NeedGodhood:AddString("#65504需要神格达到 #65535"..godhoodInfo.name.." #63488（未达成）")
                _meetRequire = false
            end
        end

        -- 显示材料需求
        _dlg.NeedItem:SetVisible(1)
        _dlg.NeedItemBG:SetVisible(1)
        
        local noNeedItem = true
        for i = 1, MAX_MATERIAL_COUNT do
            if awakeInfo.materials[i].id~=0 then
                noNeedItem = false
                break
            end
        end
        if noNeedItem then
            _dlg.NoItemWarnTip:SetVisible(1)
            _meetRequire = false
        else
            for i = 1, MAX_MATERIAL_COUNT do
                if i<= #awakeInfo.materials and awakeInfo.materials[i].id~=0 then
                    _materialIds[i] = awakeInfo.materials[i].id
                    if not showMaterialItem(i, awakeInfo.materials[i].id,awakeInfo.materials[i].count) then
                        _meetRequire = false
                    end
                end
            end

            _dlg.ConsumeMoney:SetVisible(1)
            _dlg.ConsumeMoney.ItemCount:ClearString()
            if dataitem:GetMoney() >= awakeInfo.needMoney then
                _dlg.ConsumeMoney.ItemCount:AddString("#26592" .. tostring(awakeInfo.needMoney))
            else
                _dlg.ConsumeMoney.ItemCount:AddString("#53248" .. tostring(awakeInfo.needMoney))
                _meetRequire = false
            end

            _dlg.ConsumeExp:SetVisible(1)
            _dlg.ConsumeExp.ItemCount:ClearString()
            if gameplayer.GodhoodExp >= awakeInfo.needGodExp then
                _dlg.ConsumeExp.ItemCount:AddString("#26592" .. tostring(awakeInfo.needGodExp))
            else
                _dlg.ConsumeExp.ItemCount:AddString("#53248" .. tostring(awakeInfo.needGodExp))
                _meetRequire = false
            end
        end
        
        if _meetRequire then
            _dlg.AwakeBtn:SetEnable(1)
        end
    end
end

local function onMainEquipSlotEvent(luadlg,eventCode,ctrlId,ctrl)
    if(eventCode==UIEventDef.TIN_MOUSEMOVE) then
        if _mainEquipSlot<0 then
            return
        end
        luadlg.MainEquip:SetTipInfo(game:UIDataItem():GetSlotTip(_mainEquipSlot, false))
    elseif(eventCode==UIEventDef.TIN_MOUSECLICK) then
        local cmd = game:GetCursorOperationCmd()
        if cmd~=EOperationCmd.Item_Pickup then
            return
        end
        local slot = game:GetCursorOperationCmdParam()
        game:ClearCursorOperation()
        local ret = checkCanPutin(slot, true)
        if ret ~= 0 then
            game:ShowMessage("#d60000#该物品不能被觉醒")
            return
        end
        refreshView()
    elseif(eventCode==UIEventDef.TIN_MOUSERCLICK) then
        reset()
        refreshView()
    end
end

local function onAssistiveEquipSlotEvent(luadlg,eventCode,ctrlId,ctrl)
    if(eventCode==UIEventDef.TIN_MOUSEMOVE) then
        if _assistiveEquipSlot<0 then
            return
        end
        luadlg.AssistiveEquip:SetTipInfo(game:UIDataItem():GetSlotTip(_assistiveEquipSlot, false))
    elseif(eventCode==UIEventDef.TIN_MOUSECLICK) then
        local cmd = game:GetCursorOperationCmd()
        if cmd~=EOperationCmd.Item_Pickup then
            return
        end
        local slot = game:GetCursorOperationCmdParam()
        game:ClearCursorOperation()
        local ret = checkCanPutin(slot, false)
        if ret~=0 then
            if ret == -1 then
                game:ShowMessage("#d60000#该物品不是觉醒【".._mainSlotInfo.Name.."】的辅助装备")
            elseif ret == -2 then
                game:ShowMessage("#d60000#该装备没有变异属性，不能作为辅助装备")
            elseif ret == -3 then
                game:ShowMessage("#d60000#请先放入核心装备")
            end
            return
        end
        refreshView()
    elseif(eventCode==UIEventDef.TIN_MOUSERCLICK) then
        _assistiveEquipSlot = -1
        _assistiveSlotInfo = nil
        _assistiveEquipInfo = nil
        for i = 1, MAX_MATERIAL_COUNT do
            _materialIds[i] = 0
        end
        refreshView()
    end
end

local function sendAwakeCmd()
    if _waitResponse then
        return
    end
    game:SendCallScriptPacket(ScriptEvent.AwakeMythicEquip, {
        mainEquipSlot=_mainEquipSlot,
        assistEquipSlot=_assistiveEquipSlot
    })
    _waitResponse = true
end

local function onEventProc(luadlg,eventCode,ctrlId,ctrl)
    if ctrlId==luadlg.MainEquip.CtrlID then
        onMainEquipSlotEvent(luadlg,eventCode,ctrlId,ctrl)
    elseif ctrlId==luadlg.AssistiveEquip.CtrlID then
        onAssistiveEquipSlotEvent(luadlg,eventCode,ctrlId,ctrl)
    elseif eventCode==UIEventDef.TIN_MOUSEMOVE then
        for i = 1, MAX_MATERIAL_COUNT do
            if ctrlId==luadlg["MaterialItem"..i].Item.CtrlID then
                if _materialIds[i] ~= 0 then
                    _dlg["MaterialItem"..i].Item:SetTipInfo(game:GetItemTip(_materialIds[i]))
                end
            end
        end
        if ctrlId==luadlg.TargetEquip.CtrlID then
            if _targetEquipInfo ~= nil then
                _dlg.TargetEquip:SetTipInfo(game:GetItemTip(_targetEquipInfo.ItemID))
            end
        end
    elseif eventCode==UIEventDef.TBN_CLICKED and ctrlId==luadlg.AwakeBtn.CtrlID then
        sendAwakeCmd()
    end
end

local function onShow(luadlg,show)
    reset()
    if show then
        refreshView()
    end
end

local function onRefresh(dlg)
    if _mainEquipSlot >= 0 then
        if checkCanPutin(_mainEquipSlot, true) ~= 0 then
            reset()
            refreshView()
            return
        end
    end
    if _assistiveEquipSlot >= 0 then
        if checkCanPutin(_assistiveEquipSlot, false) ~= 0 then
            reset()
            refreshView()
            return
        end
    end
    refreshView()
end

local function onCallScript(dlg,event,obj)
    if event==ScriptEvent.AwakeMythicEquipResult then
        if obj.ret==0 then
            game:ShowMessage("#ffffff#觉醒成功")
        elseif obj.ret==-99 then
            game:ShowMessage("玩家繁忙中")
        else
            game:ShowMessage("#d60000#觉醒失败")
        end
        _waitResponse = false
        reset()
        refreshView()
    elseif event==ScriptEvent.OpenMythicEquipAwakeDlg then
        _waitResponse = false
        _dlg.Raw:ShowDlg(true)
    end
end

local function createDlg(dlgmgr)
    local luadlg = dlgbuilder(dlgmgr,struct,prefix_path,3000,true)
    luadlg.Raw:SetCloseWhenMove(true)
    luadlg.OnEventProc = onEventProc
    luadlg.OnShow = onShow
    luadlg.OnUpdateItemBar = onRefresh
    luadlg.OnUpdateItemCount = onRefresh
    luadlg.OnCallScript = onCallScript
    HandleCallScript(ScriptEvent.OpenMythicEquipAwakeDlg,luadlg)
    HandleCallScript(ScriptEvent.AwakeMythicEquipResult,luadlg)
    _dlg = luadlg
    reset()
    refreshView()
    return luadlg
end

return {OnCreate=createDlg}
