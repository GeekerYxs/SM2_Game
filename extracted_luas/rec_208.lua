local dlgbuilder = require "dlg_builder"
local idtool = require "id_parse_tool"
local ScriptEvent = require "script_event"

local struct = require "uiresetequipprops_struct"
local prefix_path = "UIGame/UIResetEquipProps"
local maxLine = 19 

local _dlg = nil
local _waitResponse = false
local _itemSlot = -1
local _slotInfo
local _itemInfo
local _equipInfo
local _meetRequire = false
local _material1Id = 0
local _material2Id = 0
local _material3Id = 0
local _lineOffset = 0
local _lineCount = 0
local _propLines = {}

local function reset()
    _waitResponse = false
    _itemSlot = -1
    _slotInfo = nil
    _itemInfo = nil
    _equipInfo = nil
    _meetRequire = false
    _material1Id = 0
    _material2Id = 0
    _material3Id = 0
    _lineOffset = 0
end

local function destroyAllPropLines()
    for _, child in ipairs(_propLines) do
        _dlg.Raw:DestroyCtrl(child:BaseCtrl())
    end
    _propLines = {}
end

local function resetView()
    _dlg.ConsumeMoney.ItemIcon:SetImage(prefix_path.."/金币.mgff")
    _dlg.ConsumeExp.ItemIcon:SetImage(prefix_path.."/神识.mgff")
    _dlg.Equip:SetImage("")
    _dlg.EquipTip:SetVisible(1)
    --_dlg.ResetTip:ClearString()
    --_dlg.ResetTip:AddString("#01439恒星之力可让装备焕发新生，#26592部分属性获得重置\n#65504强化等级\\赐福等级\\威能属性\\特效属性#26592将保留")
    _dlg.NeedLevel:ClearString()
    _dlg.NeedGodhood:ClearString()
    _dlg.MaterialItem1:SetVisible(0)
    _dlg.MaterialItem2:SetVisible(0)
    _dlg.MaterialItem3:SetVisible(0)
    _dlg.ConsumeExp:SetVisible(0)
    _dlg.ConsumeMoney:SetVisible(0)
    _dlg.NoItemWarnTip:SetVisible(0)
    _dlg.ResetAction:SetEnable(0)
    _dlg.NeedItem:SetVisible(0)
    _dlg.NeedItemBG:SetVisible(0)

    _dlg.Equip:SetTipInfo("")

    _dlg.PropScrollBar:SetVisible(0)
    _dlg.EffectsBG:SetVisible(0)
    destroyAllPropLines()
    _lineOffset = 0
    _lineCount = 0
end

local function getRarityDesc(rarity)
    local rarityInfos = {
        {properbility=0.0198, desc="#63488浮云 "},
        {properbility=0.0498, desc="#55711罕见 "},
        {properbility=0.0998, desc="#64864稀有 "},
        {properbility=0.1998, desc="#65504难得 "},
        {properbility=0.9998, desc="#22527常见 "},
        {properbility=1, desc="#26601必出 "},
    }
    for _, info in ipairs(rarityInfos) do
        if rarity <= info.properbility then
            return info.desc
        end
    end
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

-- 替换描述中的占位字母A; 反斜杠(\)后的字符原样输出, 不参与替换(如\DNA显示DNA, \中文显示中文), \n换行标记原样保留
local function replaceDescA(desc, value)
    local out = {}
    local i = 1
    local len = #desc
    while i <= len do
        local ch = desc:sub(i, i)
        if ch == "\\" and i < len then
            local nx = desc:sub(i + 1, i + 1)
            if nx == "A" then
                out[#out + 1] = "A" -- 转义: 原样输出, 不参与替换
                i = i + 2
            elseif nx == "n" then
                out[#out + 1] = ch .. nx -- 换行标记\n原样保留
                i = i + 2
            else
                local code = nx:byte()
                if code and code >= 0x81 and i + 2 <= len then
                    out[#out + 1] = nx .. desc:sub(i + 2, i + 2) -- 双字节字符(中文)完整原样输出
                    i = i + 3
                else
                    out[#out + 1] = nx -- 其他字符(如\D,\\)原样输出, 反斜杠不再显示
                    i = i + 2
                end
            end
        elseif ch == "A" then
            out[#out + 1] = tostring(value)
            i = i + 1
        else
            out[#out + 1] = ch
            i = i + 1
        end
    end
    return table.concat(out)
end
local function parsePropDesc(prop, value, color)
    if prop.id >= 400*64 then
        return nil
    end
    local descInfo = idtool.FindEquipPropDesc(prop.id)
    if descInfo == nil then
        return nil
    end
    local desc = descInfo.desc
    if value~=0 then
        desc = getRarityDesc((prop.maxrate-prop.minrate)/9999)..color..replaceDescA(desc, value)
        if prop.maxvalue~=0 and prop.value~=prop.maxvalue then
            desc = desc.."#31727（"..prop.value.."~"..(prop.maxvalue-1).."）"
        end
    else
        if prop.maxvalue~=0 and prop.value~=prop.maxvalue then
            desc = getRarityDesc((prop.maxrate-prop.minrate)/9999).."#31727"..replaceDescA(desc, "（"..prop.value.."~"..(prop.maxvalue-1).."）")
        else
            desc = getRarityDesc((prop.maxrate-prop.minrate)/9999).."#31727"..replaceDescA(desc, prop.value)
        end
    end
    return desc
end

local function checkIntervalCoverage(group)
    -- 如果为空，直接返回0
    if #group == 0 then return 0 end

    -- 按minrate排序
    table.sort(group, function(a, b) 
        return a.minrate < b.minrate 
    end)

    -- 检查是否有重叠
    for i = 2, #group do
        if group[i].minrate <= group[i-1].maxrate then
            return -1  -- 存在区间重叠
        end
    end

    -- 检查是否从0开始且无间隙
    local currentMax = 0
    for _, prop in ipairs(group) do
        -- 检查是否有间隙
        if prop.minrate > currentMax+1 then
            return 0  -- 存在未覆盖区间
        end
        
        -- 更新最大值
        currentMax = math.max(currentMax, prop.maxrate)
    end

    -- 检查是否覆盖到9999
    return currentMax == 9999 and 1 or 0
end

local function showPropGroupDesc(name,props,idx)
    local offsetx = 17
    local offsety = 5 
    local width = 140
    local height = 20
    local labelHeight = 15

    local sortedProps = {}
    for _, prop in ipairs(props) do
        local sortInfo = idtool.FindEQPropSort(prop.id)
        if sortInfo ~= nil then
            table.insert(sortedProps, {prop=prop, order=sortInfo.order, color=sortInfo.colorvalue})
        else
            table.insert(sortedProps, {prop=prop, order=0, color="#65535"})
        end
    end
    table.sort(sortedProps, function(a, b) return a.order < b.order end)
 
    if name~=nil then
        if idx-_lineOffset>=0 and idx-_lineOffset<=maxLine then
            local line = _propLines[idx-_lineOffset+1]
            if line==nil then
                line = _dlg.Raw:CreateLabelCtrlInParent('line', offsetx, offsety + height * idx, width, labelHeight, -1,
                        _dlg.EffectsBG:BaseCtrl())
                table.insert(_propLines, line)
            end
            line:ClearString()
            line:AddString(name)
            line:SetAlign(2)
        end
        idx=idx+1
    end
    for _, prop in ipairs(sortedProps) do
        local value = _slotInfo:GetPropValue(prop.prop.id)
        local desc = parsePropDesc(prop.prop, value, prop.color)
        if desc ~= nil then
            if idx-_lineOffset>=0 and idx-_lineOffset<=maxLine then
                local line = _propLines[idx-_lineOffset+1]
                if line == nil then
                    line = _dlg.Raw:CreateLabelCtrlInParent('line', offsetx, offsety + height * idx, width, labelHeight, -1,
                        _dlg.EffectsBG:BaseCtrl())
                    table.insert(_propLines, line)
                end
                line:ClearString()
                line:AddString(desc)
                line:SetAlign(0)
            end
            idx=idx+1
        end
    end
    return idx
end

local function showProps()
    if _slotInfo==nil then
        return
    end
    local curLineIdx = 0

    local maxProps = {} --必出
    local oneProps = {} --单出
    local groupOneProps = {}    --组内单出
    local groupOneOrZeroProps = {}    --组内可能单出

    local descs = {}
    local propsInGroup = {}
    local propList = game:GetItemProps(_slotInfo.ItemID)
    --属性分组
    for _, prop in ipairs(propList) do
        if prop.id < 400 * 64 then
            if propsInGroup[prop.group] == nil then
                propsInGroup[prop.group] = {}
            end
            table.insert(propsInGroup[prop.group], prop)
        end
    end

    -- 将字典转换为数组
    local propsInGroupArray = {}
    for _, group in pairs(propsInGroup) do
        table.insert(propsInGroupArray, group)
    end
    propsInGroup = propsInGroupArray

    --必出的属性
    for _, group in ipairs(propsInGroup) do
        for i = #group, 1, -1 do
            local prop = group[i]
            Debug("Group: " .. tostring(prop.group) .. ", ID: " .. tostring(prop.id) .. ", minrate: " .. tostring(prop.minrate) .. ", maxrate: " .. tostring(prop.maxrate))
            if prop.minrate == 0 and prop.maxrate == 9999 then
                Debug("必出"..tostring(prop.id))
                table.insert(maxProps, prop)
                table.remove(group, i)
            end
        end
    end
    --单条的
    for i=#propsInGroup, 1, -1 do
        local group = propsInGroup[i]
        if #group==0 then
            table.remove(propsInGroup, i)
        elseif #group == 1 and not (group[1].minrate == 0 and group[1].maxrate == 9999) then
            Debug("单出"..tostring(group[1].id))
            table.insert(oneProps, group[1])
            table.remove(propsInGroup, i)
        end
    end
    --组
    for _,group in ipairs(propsInGroup) do
        local ret = checkIntervalCoverage(group)
        if ret == 0 then
            local g = {}
            for _, prop in ipairs(group) do
                Debug("可能组内单出"..tostring(prop.id))
                table.insert(g, prop)
            end
            table.insert(groupOneOrZeroProps, g)
        elseif ret == 1 then
            local g = {}
            for _, prop in ipairs(group) do
                Debug("必定组内单出"..tostring(prop.id))
                table.insert(g, prop)
            end
            table.insert(groupOneProps, g)
        end
    end

    local idx = 0
    idx = showPropGroupDesc("#65504重铸预览结果", maxProps, idx)
    idx = showPropGroupDesc(nil, oneProps, idx)
    for _, g in ipairs(groupOneProps)do
        idx = showPropGroupDesc("#65494以下属性随机其一#26601【必出】", g, idx)
    end
    for _, g in ipairs(groupOneOrZeroProps)do
        idx = showPropGroupDesc("#65494以下属性随机其一#63488【非必出】", g, idx)
    end
    _lineCount = idx
end

local function refreshView()
    resetView()
    if _itemSlot<0 then
        return
    end
    _meetRequire = true
    local gameplayer = game:GetGamePlayer()
    local dataitem = game:UIDataItem()

    _dlg.Equip:SetImage(_slotInfo:GetImagePath())
    _dlg.EquipTip:SetVisible(0)
    _dlg.NeedLevel:ClearString()
    local resetInfo = idtool.FindEquipResetProp(_slotInfo.ItemID)
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

    if resetInfo.material1Id == 0 and resetInfo.material2Id == 0 and resetInfo.material3Id == 0 then
        _dlg.NoItemWarnTip:SetVisible(1)
        _meetRequire = false
    else
        if resetInfo.material1Id ~= 0 then
            _material1Id = resetInfo.material1Id
            if not showMaterialItem(1, resetInfo.material1Id, resetInfo.material1Count) then
                _meetRequire = false
            end
        end
        if resetInfo.material2Id ~= 0 then
            _material2Id = resetInfo.material2Id
            if not showMaterialItem(2, resetInfo.material2Id, resetInfo.material2Count) then
                _meetRequire = false
            end
        end
        if resetInfo.material3Id ~= 0 then
            _material3Id = resetInfo.material3Id
            if not showMaterialItem(3, resetInfo.material3Id, resetInfo.material3Count) then
                _meetRequire = false
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
    end
    showProps()
    _dlg.PropScrollBar:SetVisible(1)
    _dlg.EffectsBG:SetVisible(1)
    if _meetRequire then
        _dlg.ResetAction:SetEnable(1)
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
    local resetInfo = idtool.FindEquipResetProp(itemId)
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
            game:ShowMessage("#d60000#该物品不能被重铸")
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
    game:SendCallScriptPacket(ScriptEvent.ResetEquipProps, {itemslot=_itemSlot})
    _waitResponse = true
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
    elseif eventCode==UIEventDef.TBN_CLICKED and ctrlId==luadlg.ResetAction.CtrlID then
        sendResetCmd()
    end
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

local function getScrollVMaxLen(dlg,listener)
    return _lineCount-maxLine-1
end

local function getScrollVPageLen(dlg,listener)
    return maxLine
end

local function setScrollVStart(dlg,listener,start)
    _lineOffset = start
    showProps()
end

local function getScrollVCurrent(dlg,listener)
    return _lineOffset
end

local function onCallScript(dlg,event,obj)
    Debug("reset equip props onCallScript event="..tostring(event))
    if event==ScriptEvent.ResetEquipPropsResult then
        if obj.ret==0 then
            game:ShowMessage("#ffffff#重铸成功")
        elseif obj.ret==-99 then
            game:ShowMessage("玩家繁忙中")
        else
            game:ShowMessage("#d60000#重铸失败")
        end
        _waitResponse = false
        refreshView()
    elseif event==ScriptEvent.OpenResetEquipPropsDlg then
        _waitResponse = false
        _dlg.Raw:ShowDlg(true)
    end
end

local function createDlg(dlgmgr)
    local luadlg = dlgbuilder(dlgmgr,struct,prefix_path,3000,true)
    luadlg.Raw:SetCloseWhenMove(true)
    luadlg.PropScrollBar:SetListener(luadlg.Raw:CreateScrollVListener(luadlg.EffectsBG:BaseCtrl()))
    luadlg.OnEventProc = onEventProc
    luadlg.OnShow = onShow
    luadlg.OnUpdateItemBar = onRefresh
    luadlg.OnUpdateItemCount = onRefresh
    luadlg.GetScrollVMaxLen = getScrollVMaxLen
    luadlg.GetScrollVPageLen = getScrollVPageLen
    luadlg.SetScrollVStart = setScrollVStart
    luadlg.GetScrollVCurrent = getScrollVCurrent
    luadlg.OnCallScript = onCallScript
    HandleCallScript(ScriptEvent.OpenResetEquipPropsDlg,luadlg)
    HandleCallScript(ScriptEvent.ResetEquipPropsResult,luadlg)
    _dlg = luadlg
    reset()
    refreshView()
    return luadlg
end

return {OnCreate=createDlg}