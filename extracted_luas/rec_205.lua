local dlgbuilder = require "dlg_builder"

local struct = require "uipropertylist_struct"
local prefix_path = "UIGame/UIPropertyList"

local _dlg = nil
local _index = 1

local att_properties = {
    '攻击',
    {"MagicDeadlyHarmScale", "魔法爆伤","发动魔法类攻击并发生致命时，造成x%d%%的伤害", true, function(v) return v+200 end},
    {"PhysicsDeadlyHarmScale", "物理爆伤", "发动魔法类攻击并发生致命时，造成x%d%%的伤害", true, function(v) return v+200 end},
    {"HarmScaleInRange", "范围伤害加成", "释放范围攻击法术和技能时，额外造成%d%%的伤害", true},
    {"SkillHarmScale", "施法伤害加成", "释放法术和技能时，额外造成%d%%的伤害", true},
    {"PhyHarmAddition", "物理伤害加成", "发动物理类攻击，额外造成%d%%的伤害", true},
    {"MagicHarmAddition", "魔法伤害加成", "发动魔法类攻击，额外造成%d%%的伤害", true},
    {"HarmAddition", "伤害加成", "发动攻击时，额外造成%d%%的伤害", true},
    {"ShieldCollapse", "护盾瓦解", "对生命护盾造成%d%%的额外伤害", true},
    {"BreakArmor", "破甲率", "发动物理类攻击时，忽视目标%d%%的护甲", true},
    {"NormalAttackHarmAddition", "普攻伤害加成", "普通攻击，额外造成%d%%的伤害", true},
    {"NearHarmAddition", "近战伤害加成", "近战攻击，额外造成%d%%的伤害", true},
    {"FarHarmAddition", "远程伤害加成", "远程攻击，额外造成%d%%的伤害", true},
}

local def_properties = {
    '防护',
    {"PhysicTenacity", "物理韧性", "受到物理类攻击时，减少%d%%的致命发生"},
    {"MagicTenacity", "法术韧性", "受到魔法类攻击时，减少%d%%的致命发生"},
    {"RDeadlyHarmScale", "爆伤抗性", "受到致命攻击时，减免一定伤害"},
    {"PhyHarmRemission", "物理伤害抗性", "能承受的物理伤害提升%d%%"},
    {"MagicHarmRemission", "魔法伤害抗性", "能承受的法术伤害提升%d%%"},
    {"HarmRemission", "伤害抗性", "能承受的攻击伤害提升%d%%"},
    {"NormalAttackHarmRemission", "普攻伤害抗性", "能承受的普攻伤害提升%d%%"},
    {"BlockEnhance", "格挡强化", "格挡的伤害抵消效果提升%d%%"},
    {"NearHarmRemission", "近战伤害抗性", "能承受的近战伤害提升%d%%"},
    {"FarHarmRemission", "远程伤害抗性", "能承受的远程伤害提升%d%%"},
    {"SkillHarmRemission", "施法伤害抗性", "能承受的法术伤害提升%d%%"},
}

local effect_properties = {
    '效能',
    {"VigorMax", "精力", "耗光所有精力会使你陷入疲劳"},
    {"TiredDuration", "疲劳时间", "摆脱疲劳状态所需的时间，疲劳状态下的蓄力时间变慢，受到的伤害增加"},
    {"ExpAmplification", "经验获取加成", "战斗后获得的主角和宠物经验值，额外增加%d%%", true},
    {"GodExpAmplification", "神识获取加成", "战斗后获得的神识，额外增加%d%%", true},
    {"MoveSpeed", "移动速度", "主角在地图移动速度", true, function(v) return v*100/160 end},
}

local common_properties = {
    '通用',
    {"EnmityScale", "仇恨烈度", "行动造成的仇恨值，额外增加%d%%，仅对怪物有效"},
    {"IgnoreResist", "忽略抗性", "释放法术或技能时，可忽视目标%d点抗性值"},
    {"MPCostReduceScale", "法力节能", "释放法术和技能消耗的法力需求降低%d%%", true},
    {"StealHP", "攻击吸血", "发动攻击时，可将%d%%的伤害转化为生命回复"},
    {"CureEffect", "治疗效果", "释放治疗类效果时，额外增加%d%%的治疗量"},
    {"BeCureEffect", "被治疗效果", "受到治疗类效果时，额外增加%d%%的恢复量"},
    {"SkillCDSpeed", "冷却加速", "法术和技能冷却所需的时间减少%d%%"},
    {"IntonateBoost", "吟唱加速", "吟唱时间减少%d%%"},
    {"MPLose", "法力损毁", "攻击命中并造成伤害时，削去目标法力值，消减量为造成伤害的%d%%"},
}

local properties = {
    att_properties,
    def_properties,
    effect_properties,
    common_properties
}

local function refreshView()
    for i=1, 12 do
        local propertyitem = _dlg['property'..i]
        propertyitem:SetVisible(0)
    end
    local ps = properties[_index]
    _dlg.Caption:ClearString()
    _dlg.Caption:AddString(ps[1])
    local idx = 1
    local playerdata = game:GetGamePlayer()
    local propdata = playerdata:GetSecondProperty()
    for n,p in pairs(ps) do
        if n~=1 then
            local pctrl = _dlg['property'..idx]
            pctrl:SetVisible(1)
            pctrl.name:ClearString()
            pctrl.name:AddString(p[2])
            pctrl.value:ClearString()
            local surfix = ''
            if p[4] then
                surfix='%'
            end
            local value = propdata[p[1]]
            if p[5] then
                value = p[5](value)
            end
            pctrl.value:AddString(tostring(value)..surfix)
            idx = idx+1
        end
    end
end

local function onEventProc(luadlg,eventCode,ctrlId,ctrl)
    if eventCode==UIEventDef.TNM_CLICK then
        local idx = luadlg.propertyGroup:GetActiveTab()
        _index = idx+1
        refreshView()
    elseif eventCode==UIEventDef.TTN_MOUSEMOVE then
        local idx = ctrlId-_dlg.property1.value.CtrlID+1
        local textctrl = _dlg['property'..idx].value
        local prop = properties[_index][idx+1]
        local playerdata = game:GetGamePlayer()
        local propdata = playerdata:GetSecondProperty()
        local value = propdata[prop[1]]
        if prop[5] then
            value = prop[5](value)
        end
        textctrl:SetTipInfo(string.format(prop[3],value))
    end
end

local function onUIPackage(luadlg,pkgType,buffer)
    if pkgType==EPackageType.MSLGP_G_TYPE_UPDATEPLAYERPROP then
        if _dlg~=nil and _dlg.Raw:GetVisible()==1 then
            refreshView();
            return
        end
    end
end

local function onShow(luadlg,show)
    if show then
        refreshView()
    end
end

local function createDlg(dlgmgr)
    local luadlg = dlgbuilder(dlgmgr,struct,prefix_path,3000)
    _dlg = luadlg
    luadlg.OnUIPackage = onUIPackage
    luadlg.OnEventProc = onEventProc
    luadlg.OnShow = onShow
    HandlePackage(EPackageType.MSLGP_G_TYPE_UPDATEPLAYERPROP,luadlg)
    refreshView()
    return luadlg
end

return {OnCreate=createDlg}