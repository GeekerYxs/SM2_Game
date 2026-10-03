local dlgbuilder = require "dlg_builder"
local idParseTool = require "id_parse_tool"
local events = require "events"

local struct = require "uiartifactlist_struct"
local prefix_path = "UIGame/UIArtifact"

-- 赋能挂件部位定义
-- ctrl  : 该部位在 PendantHead.HeroEquip / PendantHead.PetEquip 下的控件名
-- img   : 部位按钮在 struct 中使用的图片序号(0~11), 仅用于拼图片名, 与部位id无关
-- typeId: 部位id, 即奇物的 TargetTypeId, 列表按它过滤
-- 人物部位 id 直接取 EMslFEquipSlot 枚举值
-- tip: 该部位右上角的提示点控件名, 该部位有已启用奇物时显示
local HeroSlots = {
    { ctrl = "Weapon",   tip = "WeaponTip",   img = 0, typeId = 2 }, -- 武器 EquipSlot_Weapon
    { ctrl = "Hat",      tip = "HatTip",      img = 1, typeId = 0 }, -- 帽子 EquipSlot_Hat
    { ctrl = "Cloth",    tip = "ClothTip",    img = 2, typeId = 8 }, -- 衣服 EquipSlot_Cloth
    { ctrl = "Trousers", tip = "TrousersTip", img = 3, typeId = 6 }, -- 裤子 EquipSlot_Trousers
    { ctrl = "Belt",     tip = "BeltTip",     img = 4, typeId = 7 }, -- 腰带 EquipSlot_Belt
    { ctrl = "Shoes",    tip = "ShoesTip",    img = 5, typeId = 3 }, -- 鞋子 EquipSlot_Shoes
}
-- 宠物部位 id = EMslFPetEquipSlot 枚举值(人物/宠物已由 TargetType 区分)
local PetSlots = {
    { ctrl = "Weapon",   tip = "WeaponTip",  img = 6,  typeId = 0   }, -- 宠物武器 PetEquipSlot_Weapon
    { ctrl = "Wristlet", tip = "WrisletTip", img = 7,  typeId = 1   }, -- 宠物护腕 PetEquipSlot_Wristlet
    { ctrl = "Collar",   tip = "CollarTip",  img = 8,  typeId = 2   }, -- 项圈 PetEquipSlot_Collar
    { ctrl = "Armor",    tip = "ArmorTip",   img = 9,  typeId = 3   }, -- 宠物铠甲 PetEquipSlot_Armor
    { ctrl = "Belt",     tip = "BeltTip",    img = 10, typeId = 4   }, -- 宠物腰带 PetEquipSlot_Belt
    { ctrl = "Vest",     tip = "VestTip",    img = 11, typeId = 5   }, -- 宠物背心 PetEquipSlot_Vest
}

local _dlg = nil

local showType = 1
local startIndex = 1
local inEditMode = false
local editingCtrl = nil
local editingArtifact = nil

-- 赋能挂件页(showType==2)的子状态
local equipSet = 1                          -- 1=主角(HeroEquip) 2=宠物(PetEquip)
local selectedSlotTypeId = HeroSlots[1].typeId -- 当前选中部位的 typeId, 默认武器

local PlayerArtifacts = {}
local currentList = {}  -- 当前列表实际展示的奇物(已按页签/部位过滤)

local function buildArtifactTip(artifactInfo)
    local target
    if artifactInfo.TargetType == 1 then
        target = "主角"
    elseif artifactInfo.TargetType == 2 then
        target = "宠物"
    end
    if target == nil then
        return artifactInfo.Desc
    end
    -- 类型后缀: 赋能挂件(Type==2) 展示"挂件", 万象秘宝展示"秘宝"
    local suffix = (artifactInfo.Type == 2) and "挂件" or "秘宝"
    return target .. suffix .. "\n" .. artifactInfo.Desc
end

local function showOneArtifact(i, artifact)
    local artifactInfo = artifact.info
    local artifactCtrl = _dlg["Artifact" .. i]
    artifactCtrl:SetVisible(1)
    artifactCtrl.ShortCutNum:SetVisible(0)
    artifactCtrl.Name:ClearString()
    artifactCtrl.Name:AddString(artifactInfo.Name)
    local skillInfo = game:ParseSpecifySkill(artifactInfo.SkillId, artifactInfo.SkillLevel)
    if skillInfo ~= nil then
        artifactCtrl.SkillDesc:ClearString()
        artifactCtrl.SkillDesc:AddString(skillInfo.Desc)
    else
        artifactCtrl.SkillDesc:ClearString()
        artifactCtrl.SkillDesc:AddString("缺少技能描述")
    end
    artifactCtrl.Icon:SetImage(prefix_path .. "/icons/" .. artifactInfo.Icon .. ".mgff")
    if artifactInfo.TargetType == 1 then
        -- player
        artifactCtrl.PlayerType:SetVisible(1)
        artifactCtrl.PetType:SetVisible(0)
    elseif artifactInfo.TargetType == 2 then
        -- pet
        artifactCtrl.PlayerType:SetVisible(0)
        artifactCtrl.PetType:SetVisible(1)
    end
    artifactCtrl.ShortCut:ClearString()
    if artifact.shortcutNum > 0 then
        artifactCtrl.ShortCut:AddString("Ctrl+   " .. artifact.shortcutNum)
    else
        artifactCtrl.ShortCut:AddString("Ctrl+")
    end
    artifactCtrl.ShortCutEditBG:SetVisible(0)
    artifactCtrl.EditTip:SetVisible(0)
    -- 选中蒙版: 仅赋能挂件页生效, 由服务端下发的 isEnable 决定(已启用即为选中)
    if showType == 2 and artifact.isEnable then
        artifactCtrl.SelectedMask:SetVisible(1)
    else
        artifactCtrl.SelectedMask:SetVisible(0)
    end
end

local function refreshData()
    PlayerArtifacts = {}
    local artifacts = game:GetAllArtifacts()
    for i, artifact in ipairs(artifacts) do
        local artifactInfo = idParseTool.FindArtifact(artifact.id)
        artifact.info = artifactInfo
        Info("artifactInfo.Type: " .. artifactInfo.Type)
        if PlayerArtifacts[artifactInfo.Type] == nil then
            PlayerArtifacts[artifactInfo.Type] = {}
        end
        table.insert(PlayerArtifacts[artifactInfo.Type], artifact)
    end
end

-- 返回当前选中页(主角/宠物)的部位容器控件与部位定义表
local function getCurEquipObj()
    if equipSet == 2 then
        return _dlg.PendantHead.PetEquip, PetSlots
    end
    return _dlg.PendantHead.HeroEquip, HeroSlots
end

-- 重新计算当前应展示的奇物列表
-- 万象秘宝(showType==1): 展示该类型全部奇物
-- 赋能挂件(showType==2): 按 TargetType(人物/宠物) 和 TargetTypeId(选中部位) 过滤奇物
local function rebuildCurrentList()
    local all = PlayerArtifacts[showType] or {}
    if showType ~= 2 then
        currentList = all
        return
    end
    currentList = {}
    -- 人物/宠物由 TargetType 区分(1=人物 2=宠物)
    for _, artifact in ipairs(all) do
        if artifact.info.TargetType == equipSet and artifact.info.TargetTypeId == selectedSlotTypeId then
            table.insert(currentList, artifact)
        end
    end
end

-- 赋能挂件页(showType==2): 第一格 Artifact1 固定留空, 列表从 Artifact2 起、每页只展示4项;
-- 其它页: 从 Artifact1 起、每页展示5项
local function slotOffset()
    return (showType == 2) and 1 or 0
end

-- Artifact 控件号(1..5) 对应的 currentList 奇物
local function artifactAtSlot(slotNum)
    return currentList[startIndex + (slotNum - 1) - slotOffset()]
end

local function refreshView()
    _dlg.Artifact1:SetVisible(0)
    _dlg.Artifact2:SetVisible(0)
    _dlg.Artifact3:SetVisible(0)
    _dlg.Artifact4:SetVisible(0)
    _dlg.Artifact5:SetVisible(0)
    _dlg.BtnGoDown:SetEnable(0)
    _dlg.BtnGoUp:SetEnable(0)

    -- 获取用户所有的奇物数据
    if #currentList == 0 then
        _dlg.EmptyBG:SetVisible(1)
        return
    end
    _dlg.EmptyBG:SetVisible(0)

    local offset = slotOffset()
    local pageSize = 5 - offset
    for i, artifact in ipairs(currentList) do
        if i >= startIndex and i <= startIndex + pageSize - 1 then
            showOneArtifact(i - startIndex + 1 + offset, artifact)
        end
    end
    if startIndex == 1 then
        _dlg.BtnGoUp:SetEnable(0)
    else
        _dlg.BtnGoUp:SetEnable(1)
    end
    if startIndex + pageSize - 1 >= #currentList then
        _dlg.BtnGoDown:SetEnable(0)
    else
        _dlg.BtnGoDown:SetEnable(1)
    end
end

-- 某部位是否有已启用的赋能挂件奇物(TargetType: 1=主角 2=宠物, 与 equipSet 一致)
-- 赋能挂件属于 Type==2, isEnable 由服务端下发
local function slotHasEnabledArtifact(targetType, typeId)
    local charms = PlayerArtifacts[2] or {}
    for _, artifact in ipairs(charms) do
        if artifact.isEnable
            and artifact.info.TargetType == targetType
            and artifact.info.TargetTypeId == typeId then
            return true
        end
    end
    return false
end

-- 刷新挂件页头: 主角/宠物激活态、HeroEquip/PetEquip 显隐、各部位选中态图片、各部位提示点
local function refreshPendantHead()
    local head = _dlg.PendantHead
    if equipSet == 1 then
        head.Hero:SetImage(prefix_path .. "/挂件/主角 激活.mgff")
        head.Pet:SetImage(prefix_path .. "/挂件/宠物 未激活.mgff")
        head.HeroEquip:SetVisible(1)
        head.PetEquip:SetVisible(0)
    else
        head.Hero:SetImage(prefix_path .. "/挂件/主角 未激活.mgff")
        head.Pet:SetImage(prefix_path .. "/挂件/宠物 激活.mgff")
        head.HeroEquip:SetVisible(0)
        head.PetEquip:SetVisible(1)
    end
    local equipObj, slots = getCurEquipObj()
    for _, slot in ipairs(slots) do
        local suffix = (slot.typeId == selectedSlotTypeId) and " 已激活" or " 未激活"
        equipObj[slot.ctrl]:SetImage(prefix_path .. "/挂件/" .. slot.img .. suffix .. ".mgff")
        -- 该部位有已启用奇物时显示提示点, 否则隐藏
        equipObj[slot.tip]:SetVisible(slotHasEnabledArtifact(equipSet, slot.typeId) and 1 or 0)
    end
end

-- 切换主角/宠物页, 默认选中第一个部位(武器)
local function switchEquipSet(set)
    equipSet = set
    local _, slots = getCurEquipObj()
    selectedSlotTypeId = slots[1].typeId
    startIndex = 1
    refreshPendantHead()
    rebuildCurrentList()
    refreshView()
end

-- 选中某个部位
local function selectSlot(typeId)
    selectedSlotTypeId = typeId
    startIndex = 1
    refreshPendantHead()
    rebuildCurrentList()
    refreshView()
end

-- 选中某个奇物(仅赋能挂件页): 通知服务端启用该奇物(同部位互斥由服务端处理),
-- 之后等待 OnUpdateArtifact 回包, 列表里 isEnable 翻转后再展示选中态
local function selectArtifact(artifact)
    if showType ~= 2 or artifact == nil then
        return
    end
    local pkg = game:PrepareSendBuffer()
    pkg:WriteUInt32(0)          -- playerid 占位
    pkg:WriteInt32(artifact.id)
    local enable = 1
    if artifact.isEnable then
        enable = 0  -- toggle off: click enabled artifact again to cancel
    end
    pkg:WriteUInt8(enable)
    game:SendPackage(EPackageType.MSLGP_C_TYPE_SETARTIFACTENABLE)
end

local function refreshTabButtons()
    if showType == 2 then
        _dlg.BtnRelic:SetImage(prefix_path .. "/万象秘宝按钮 灰色.mgff")
        _dlg.BtnCharm:SetImage(prefix_path .. "/赋能挂件按钮 未激活.mgff")
        _dlg.PendantHead:SetVisible(1)
    else
        _dlg.BtnRelic:SetImage(prefix_path .. "/万象秘宝按钮 未激活.mgff")
        _dlg.BtnCharm:SetImage(prefix_path .. "/赋能挂件按钮 灰色.mgff")
        _dlg.PendantHead:SetVisible(0)
    end
end

local function sendSetShortcut(artifact, shortcutNum)
    Info("-----sendSetShortcut-----")
    -- 通知服务端设置快捷键
    local pkg = game:PrepareSendBuffer()
    pkg:WriteUInt32(0)
    pkg:WriteInt32(artifact.id)
    pkg:WriteUInt8(shortcutNum)
    game:SendPackage(EPackageType.MSLGP_C_TYPE_SETARTIFACTSHORTCUT)
end

local function enterEditMode(ctrl, artifact)
    Info("-----enterEditMode-----")
    ctrl.ShortCutEditBG:SetVisible(1)
    ctrl.ShortCutNum:SetVisible(1)
    ctrl.ShortCutNum:Clear()
    ctrl.ShortCut:ClearString()
    ctrl.ShortCut:AddString("Ctrl+")
    _dlg.Raw:RequestFocus(ctrl.ShortCutNum:BaseCtrl())
    ctrl.EditTip:SetVisible(1)
    inEditMode = true
    editingCtrl = ctrl
    editingArtifact = artifact
end

local function exitEditMode(ctrl, artifact)
    if not inEditMode then
        return
    end
    Info("-----exitEditMode-----")
    inEditMode = false
    ctrl.EditTip:SetVisible(0)
    ctrl.ShortCutEditBG:SetVisible(0)
    local inputText = ctrl.ShortCutNum:GetInputText()
    Info("inputText: " .. inputText)
    local shortcutNum = -1
    -- 输入必须是0-9的单个数字
    if inputText:match("^%d$") then
        shortcutNum = tonumber(inputText)
    elseif inputText ~= nil and inputText ~= "" then
        ctrl.ShortCutNum:Clear()
        game:ShowMessage("#d60000#只能输入数字0~9")
    end
    Info("shortcutNum: " .. shortcutNum)
    if shortcutNum>=0 then
        -- 通知服务端设置快捷键
        sendSetShortcut(artifact, shortcutNum)
    end
    ctrl.ShortCutNum:SetVisible(0)
    ctrl.ShortCut:ClearString()
    if artifact.shortcutNum > 0 then
        ctrl.ShortCut:AddString("Ctrl+   " .. artifact.shortcutNum)
    else
        ctrl.ShortCut:AddString("Ctrl+")
    end
end

local function onHandleMessage(luadlg, eventCode)
    if eventCode == MOUSEEVENT.MS_RCLICK then
        if inEditMode and editingCtrl ~= nil then
            -- 编辑态:取消编辑(清空输入,走exitEditMode即可,不会触发提交)
            editingCtrl.ShortCutNum:Clear()
            exitEditMode(editingCtrl, editingArtifact)
        end
        return true
    end
    return false
end

local function onEventProc(luadlg,eventCode,ctrlId,ctrl)
    if eventCode==UIEventDef.TBN_CLICKED then
        if ctrlId==_dlg.BtnClose.CtrlID then
            luadlg.Raw:ShowDlg(false)
        elseif ctrlId == _dlg.BtnGoUp.CtrlID then
            startIndex = startIndex - 1
            refreshView()
        elseif ctrlId == _dlg.BtnGoDown.CtrlID then
            startIndex = startIndex + 1
            refreshView()
        elseif ctrlId==_dlg.Artifact1.Setting.CtrlID then
            enterEditMode(_dlg.Artifact1, artifactAtSlot(1))
        elseif ctrlId==_dlg.Artifact2.Setting.CtrlID then
            enterEditMode(_dlg.Artifact2, artifactAtSlot(2))
        elseif ctrlId==_dlg.Artifact3.Setting.CtrlID then
            enterEditMode(_dlg.Artifact3, artifactAtSlot(3))
        elseif ctrlId==_dlg.Artifact4.Setting.CtrlID then
            enterEditMode(_dlg.Artifact4, artifactAtSlot(4))
        elseif ctrlId==_dlg.Artifact5.Setting.CtrlID then
            enterEditMode(_dlg.Artifact5, artifactAtSlot(5))
        end
    elseif eventCode==UIEventDef.TIN_MOUSECLICK then
        if ctrlId==_dlg.BtnRelic.CtrlID then
            if showType ~= 1 then
                showType = 1
                startIndex = 1
                refreshTabButtons()
                rebuildCurrentList()
                refreshView()
            end
        elseif ctrlId==_dlg.BtnCharm.CtrlID then
            if showType ~= 2 then
                showType = 2
                startIndex = 1
                equipSet = 1
                selectedSlotTypeId = HeroSlots[1].typeId
                refreshTabButtons()
                refreshPendantHead()
                rebuildCurrentList()
                refreshView()
            end
        elseif ctrlId==_dlg.BtnMorph.CtrlID then
            game:ShowMessage("尚未开放")
        elseif ctrlId==_dlg.PendantHead.Hero.CtrlID then
            if equipSet ~= 1 then
                switchEquipSet(1)
            end
        elseif ctrlId==_dlg.PendantHead.Pet.CtrlID then
            if equipSet ~= 2 then
                switchEquipSet(2)
            end
        elseif ctrlId==_dlg.Artifact1.BG.CtrlID then
            selectArtifact(artifactAtSlot(1))
        elseif ctrlId==_dlg.Artifact2.BG.CtrlID then
            selectArtifact(artifactAtSlot(2))
        elseif ctrlId==_dlg.Artifact3.BG.CtrlID then
            selectArtifact(artifactAtSlot(3))
        elseif ctrlId==_dlg.Artifact4.BG.CtrlID then
            selectArtifact(artifactAtSlot(4))
        elseif ctrlId==_dlg.Artifact5.BG.CtrlID then
            selectArtifact(artifactAtSlot(5))
        else
            -- 部位按钮点击: 仅在当前显示的页(主角/宠物)里匹配
            local equipObj, slots = getCurEquipObj()
            for _, slot in ipairs(slots) do
                if ctrlId == equipObj[slot.ctrl].CtrlID then
                    if selectedSlotTypeId ~= slot.typeId then
                        selectSlot(slot.typeId)
                    end
                    break
                end
            end
        end
    elseif eventCode==UIEventDef.TIN_MOUSEMOVE then
        if ctrlId==_dlg.Artifact1.Icon.CtrlID then
            local artifact = artifactAtSlot(1)
            if artifact ~= nil then
                _dlg.Artifact1.Icon:SetTipInfo(buildArtifactTip(artifact.info))
            end
        elseif ctrlId==_dlg.Artifact2.Icon.CtrlID then
            local artifact = artifactAtSlot(2)
            if artifact ~= nil then
                _dlg.Artifact2.Icon:SetTipInfo(buildArtifactTip(artifact.info))
            end
        elseif ctrlId==_dlg.Artifact3.Icon.CtrlID then
            local artifact = artifactAtSlot(3)
            if artifact ~= nil then
                _dlg.Artifact3.Icon:SetTipInfo(buildArtifactTip(artifact.info))
            end
        elseif ctrlId==_dlg.Artifact4.Icon.CtrlID then
            local artifact = artifactAtSlot(4)
            if artifact ~= nil then
                _dlg.Artifact4.Icon:SetTipInfo(buildArtifactTip(artifact.info))
            end
        elseif ctrlId==_dlg.Artifact5.Icon.CtrlID then
            local artifact = artifactAtSlot(5)
            if artifact ~= nil then
                _dlg.Artifact5.Icon:SetTipInfo(buildArtifactTip(artifact.info))
            end
        elseif ctrlId==_dlg.ShowTip.CtrlID then
            _dlg.ShowTip:SetTipInfo("#FFC000#此葫乃上古黑科技打造，内含乾坤，可收纳[万象秘宝] 、[赋能挂件] 、[幻型模组]  三类奇物。\n\n#00B0F0#[万象秘宝]特性:\n#DEEBF7#◆ 为主角或宠物提供额外属性\n◆ 拥有即生效，无需装备或激活\n◆ 不同奇物效果可叠加，多多益善\n\n#00B0F0#[赋能挂件]特性:\n#DEEBF7#◆ 为主角或宠物身上的装备提供特定属性比例放大\n◆ 需手动选定并激活后才能生效\n◆ 每件装备仅可享受一个挂件效果\n\n#FF66FF#※设置快捷，可随时高调展示奇物")
        end
    elseif eventCode==UIEventDef.TEN_LOSTFOCUS then
        if ctrlId==_dlg.Artifact1.ShortCutNum.CtrlID then
            exitEditMode(_dlg.Artifact1, artifactAtSlot(1))
        elseif ctrlId==_dlg.Artifact2.ShortCutNum.CtrlID then
            exitEditMode(_dlg.Artifact2, artifactAtSlot(2))
        elseif ctrlId==_dlg.Artifact3.ShortCutNum.CtrlID then
            exitEditMode(_dlg.Artifact3, artifactAtSlot(3))
        elseif ctrlId==_dlg.Artifact4.ShortCutNum.CtrlID then
            exitEditMode(_dlg.Artifact4, artifactAtSlot(4))
        elseif ctrlId==_dlg.Artifact5.ShortCutNum.CtrlID then
            exitEditMode(_dlg.Artifact5, artifactAtSlot(5))
        end
    elseif eventCode==UIEventDef.TEN_CHANGE then
        if ctrlId==_dlg.Artifact1.ShortCutNum.CtrlID then
            exitEditMode(_dlg.Artifact1, artifactAtSlot(1))
        elseif ctrlId==_dlg.Artifact2.ShortCutNum.CtrlID then
            exitEditMode(_dlg.Artifact2, artifactAtSlot(2))
        elseif ctrlId==_dlg.Artifact3.ShortCutNum.CtrlID then
            exitEditMode(_dlg.Artifact3, artifactAtSlot(3))
        elseif ctrlId==_dlg.Artifact4.ShortCutNum.CtrlID then
            exitEditMode(_dlg.Artifact4, artifactAtSlot(4))
        elseif ctrlId==_dlg.Artifact5.ShortCutNum.CtrlID then
            exitEditMode(_dlg.Artifact5, artifactAtSlot(5))
        end
    end
end

local function onUpdateArtifact(artifacts)
    refreshData()
    rebuildCurrentList()
    refreshView()
    -- 启用状态可能变化, 刷新各部位提示点(仅挂件页可见)
    if showType == 2 then
        refreshPendantHead()
    end
end

local function onShow(luadlg,show)
    if show then
        startIndex = 1
        showType = 1
        equipSet = 1
        selectedSlotTypeId = HeroSlots[1].typeId
        inEditMode = false
        refreshTabButtons()
        refreshPendantHead()
        refreshData()
        rebuildCurrentList()
        refreshView()
    end
end

local function createDlg(dlgmgr)
    local luadlg = dlgbuilder(dlgmgr,struct,prefix_path,3000)
    _dlg = luadlg
    -- txt ctrls keep mouse events by default (see dlg_builder buildLabelCtrl),
    -- which blocks clicks from reaching BG; turn them off
    for i = 1, 5 do
        local card = luadlg["Artifact" .. i]
        card.Name:SetMouseMoveEvent(0)
        card.Name:SetEnable(0)
        card.SkillDesc:SetMouseMoveEvent(0)
        card.SkillDesc:SetEnable(0)
    end
    luadlg.OnEventProc = onEventProc
    luadlg.OnShow = onShow
    luadlg.OnHandleMessage = onHandleMessage
    luadlg.Raw:SetHandleMsg(1)  -- 开启 OnDlgHandleMessage 回调(用于响应鼠标左右键点击)
    events.UpdateArtifact:Add(onUpdateArtifact)
    -- _dlg.artifactGroup:SetPageAlign(2)  -- 垂直
    refreshTabButtons()
    refreshPendantHead()
    refreshData()
    rebuildCurrentList()
    refreshView()
    return luadlg
end

return {OnCreate=createDlg}
