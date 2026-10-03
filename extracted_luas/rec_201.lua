local dlgbuilder = require "dlg_builder"
local idtool = require "id_parse_tool"
local ScriptEvent = require "script_event"

local struct = require "uienhanceequipawake_struct"
local prefix_path = "UIGame/UIEnhanceEquipAwake"

local MAX_MATERIAL_COUNT = 5

local _dlg = nil
local _waitResponse = false
local _srcEquipSlot = -1
local _srcEquipInfo = nil
local _srcSlotInfo = nil
local _dstEquipInfo = nil
local _meetRequire = false
local _materialIds = {}

local function reset()
    _waitResponse = false
    _srcEquipSlot = -1
    _srcEquipInfo = nil
    _srcSlotInfo = nil
    _dstEquipInfo = nil
    _meetRequire = false
    for i = 1, MAX_MATERIAL_COUNT do
        _materialIds[i] = 0
    end
end

local function resetView()
    _dlg.ConsumeMoney.ItemIcon:SetImage(prefix_path.."/金币.mgff")
    _dlg.ConsumeExp.ItemIcon:SetImage(prefix_path.."/神识.mgff")
    
    _dlg.SrcEquip:SetImage("")
    _dlg.DstEquip:SetImage("")
    
    for i = 1, MAX_MATERIAL_COUNT do
        _dlg["MaterialItem"..i]:SetVisible(0)
    end
    
    _dlg.ConsumeExp:SetVisible(0)
    _dlg.ConsumeMoney:SetVisible(0)
    _dlg.EnhanceEquip:SetEnable(0)
    _dlg.NeedItem:SetVisible(0)
    _dlg.NeedItemBG:SetVisible(0)
    _dlg.EnhanceTip:SetVisible(1)

    _dlg.NeedLevel:ClearString()
    _dlg.NeedGodhood:ClearString()

    _dlg.NoItemWarnTip:SetVisible(0)

    _dlg.SrcEquip:SetTipInfo("")
    _dlg.DstEquip:SetTipInfo("")
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

local function checkCanPutin(slot)
    local dataitem = game:UIDataItem()
    local staticRes = game:StaticRes()
    local slotData = dataitem:GetSlotData(slot)
    
    if slotData == nil then return -1 end
    
    local itemId = slotData.ItemID
    local itemInfo = staticRes:GetItemInfo(itemId)
    
    if itemInfo == nil then return -1 end
    if game:MaskValue(itemInfo.Type, EItemType.Equip) == 0 then return -1 end
    
    local equipInfo = staticRes:GetEquipInfo(itemId)
    if equipInfo == nil then return -1 end

    -- 检查是否可以觉醒
    local awakeInfo = idtool.Datas['EnhanceEquipAwakeLib'][itemId]
    if awakeInfo == nil then return -1 end

    -- 检测属性至少要满足一项
    local meetProp = false
    local hasNonZeroProp = false
    for i = 1, #awakeInfo.equipProps do
        local prop = awakeInfo.equipProps[i]
        if prop.id ~= 0 then
            hasNonZeroProp = true
            if slotData:GetPropValue(prop.id) == prop.value then
                meetProp = true
                break
            end
        end
    end
    if not hasNonZeroProp then
        meetProp = true
    end
    if not meetProp then return -2 end

    _srcEquipSlot = slot
    _srcSlotInfo = slotData
    _srcEquipInfo = itemInfo
    
    return 0
end

local function refreshView()
    resetView()

    local gameplayer = game:GetGamePlayer()
    local dataitem = game:UIDataItem()

    if _srcEquipSlot < 0 then
        return
    end
    _meetRequire = true
    _dlg.SrcEquip:SetImage(_srcSlotInfo:GetImagePath())

    local awakeInfo = idtool.Datas['EnhanceEquipAwakeLib'][_srcSlotInfo.ItemID]
    if awakeInfo then
        local productInfo = game:StaticRes():GetItemInfo(awakeInfo.productId)
        _dlg.DstEquip:SetImage(productInfo:GetImageName())
        _dstEquipInfo = productInfo

        -- 显示材料需求
        _dlg.NeedItem:SetVisible(1)
        _dlg.NeedItemBG:SetVisible(1)

        _dlg.NeedLevel:ClearString()
        if gameplayer.Grade >= awakeInfo.needLevel then
            _dlg.NeedLevel:AddString("#65504需要等级达到 #65535" .. awakeInfo.needLevel)
        else
            _dlg.NeedLevel:AddString("#65504需要等级达到 #65535" .. awakeInfo.needLevel .. " #63488（未达成）")
            _meetRequire = false
        end

        _dlg.NeedGodhood:ClearString()
        if awakeInfo.needGodLevel > 0 then
            local godhoodInfo = idtool.FindGodhoodLevel(awakeInfo.needGodLevel)
            if gameplayer.GodhoodLevel >= awakeInfo.needGodLevel then
                _dlg.NeedGodhood:AddString("#65504需要神格达到 #65535" .. godhoodInfo.name)
            else
                _dlg.NeedGodhood:AddString("#65504需要神格达到 #65535" .. godhoodInfo.name .. " #63488（未达成）")
                _meetRequire = false
            end
        end

        -- 检查材料
        -- 没有材料需求
        local noMaterial = true
        for i = 1, MAX_MATERIAL_COUNT do
            if awakeInfo.materials[i] and awakeInfo.materials[i].id ~= 0 then
                noMaterial = false
                break
            end
        end
        if noMaterial then
            _dlg.NoItemWarnTip:SetVisible(1)
            _meetRequire = false
        else
            for i = 1, MAX_MATERIAL_COUNT do
                if awakeInfo.materials[i] and awakeInfo.materials[i].id ~= 0 then
                    _materialIds[i] = awakeInfo.materials[i].id
                    if not showMaterialItem(i, awakeInfo.materials[i].id, awakeInfo.materials[i].count) then
                        _meetRequire = false
                    end
                end
            end

            -- 检查金钱和经验
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
    end
    if _meetRequire then
        _dlg.EnhanceEquip:SetEnable(1)
    end
end
local function onSrcEquipSlotEvent(luadlg, eventCode, ctrlId, ctrl)
    if(eventCode==UIEventDef.TIN_MOUSEMOVE) then
        if _srcEquipSlot < 0 then return end
        luadlg.SrcEquip:SetTipInfo(game:UIDataItem():GetSlotTip(_srcEquipSlot, false))
    elseif(eventCode==UIEventDef.TIN_MOUSECLICK) then
        local cmd = game:GetCursorOperationCmd()
        if cmd~=EOperationCmd.Item_Pickup then return end
        local slot = game:GetCursorOperationCmdParam()
        game:ClearCursorOperation()
        local ret = checkCanPutin(slot)
        if ret ~= 0 then
            if ret == -1 then
                game:ShowMessage("#d60000#该物品不能被强化觉醒")
            elseif ret == -2 then
                game:ShowMessage("#d60000#该装备没有变异属性，不能进阶")
            end
            return
        end
        refreshView()
    elseif(eventCode==UIEventDef.TIN_MOUSERCLICK) then
        reset()
        refreshView()
    end
end

local function sendEnhanceCmd()
    if _waitResponse then return end
    game:SendCallScriptPacket(ScriptEvent.EnhanceEquipAwake, {
        srcEquipSlot=_srcEquipSlot
    })
    _waitResponse = true
end

local function onEventProc(luadlg, eventCode, ctrlId, ctrl)
    if ctrlId==luadlg.SrcEquip.CtrlID then
        onSrcEquipSlotEvent(luadlg, eventCode, ctrlId, ctrl)
    elseif eventCode==UIEventDef.TIN_MOUSEMOVE then
        if ctrlId==luadlg.DstEquip.CtrlID then
            if _dstEquipInfo ~= nil then
                luadlg.DstEquip:SetTipInfo(game:GetItemTip(_dstEquipInfo.ItemID))
            end
        end
        for i = 1, MAX_MATERIAL_COUNT do
            if ctrlId==luadlg["MaterialItem"..i].Item.CtrlID then
                _dlg["MaterialItem"..i].Item:SetTipInfo(game:GetItemTip(_materialIds[i]))
            end
        end
    elseif eventCode==UIEventDef.TBN_CLICKED and ctrlId==luadlg.EnhanceEquip.CtrlID then
        sendEnhanceCmd()
    end
end

local function onShow(luadlg, show)
    reset()
    if show then
        refreshView()
    end
end

local function onRefresh(dlg)
    if checkCanPutin(_srcEquipSlot) ~= 0 then
        reset()
    end
    refreshView()
end

local function onCallScript(dlg, event, obj)
    if event==ScriptEvent.EnhanceEquipAwakeResult then
        if obj.ret==0 then
            game:ShowMessage("#ffffff#强化觉醒成功")
        elseif obj.ret==-99 then
            game:ShowMessage("玩家繁忙中")
        else
            game:ShowMessage("#d60000#强化觉醒失败")
        end
        _waitResponse = false
        reset()
        refreshView()
    elseif event==ScriptEvent.OpenEnhanceEquipAwakeDlg then
        _waitResponse = false
        _dlg.Raw:ShowDlg(true)
    end
end

local function createDlg(dlgmgr)
    local luadlg = dlgbuilder(dlgmgr, struct, prefix_path, 3000, true)
    luadlg.Raw:SetCloseWhenMove(true)
    luadlg.OnEventProc = onEventProc
    luadlg.OnShow = onShow
    luadlg.OnUpdateItemBar = onRefresh
    luadlg.OnUpdateItemCount = onRefresh
    luadlg.OnCallScript = onCallScript
    HandleCallScript(ScriptEvent.OpenEnhanceEquipAwakeDlg, luadlg)
    HandleCallScript(ScriptEvent.EnhanceEquipAwakeResult, luadlg)
    _dlg = luadlg
    reset()
    refreshView()
    return luadlg
end

return {OnCreate=createDlg}
