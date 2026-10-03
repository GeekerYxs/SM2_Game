-- ================================================================
-- 神侍系统 - UI 渲染模块（客户端）
-- 服务端「精简」下发态只含每宠物动态量：pet_name / pet_species / pray_count / skills[]。
-- 神侍等级 gs_level 不再下发：由 godservant_data.SetState 按 pet_species 查 PetLib.csv 现算(=TPetLib.GodServantRank)，
--   补进 st.gs_level 后下游沿用。其余全部客户端本地查 CSV 现算：
--   阶/星/名        ← GodServantLevelLib.csv[gs_level]
--   圣痕图标/等级串/光环技能 ← PetLib.csv[species]→圣痕组ID，再 HolyMarkAuraLib.csv[组ID, gs_level]
--   归元消耗        ← GodServantResetCostLib.csv 基础量 × 归元消耗系数(gs_level)
--   can_pray/can_reset ← 神火库(PetLib) + gs_level/pray_count 现判
-- 技能名/图标/描述由 id_parse_tool.FindSkill 本地解析（skills 格仍由服务端下发 skillId+level）。
-- ================================================================

local Config    = require "ui.dlgs.godservant.GodServantConfig"
local Data      = require "ui.dlgs.godservant.godservant_data"
local idtool    = require "id_parse_tool"
local ErrorCode = require "ui.dlgs.godservant.GodServantErrorCode"

-- 源码 UTF-8，硬编码中文经 L() 转客户端编码(GBK) 再显示。
-- 注：gs_name(来自DB TSGodServantLevelLib)、技能名(来自 SkillLib.csv)本就是 GBK 字节，无需再转。
local L = function(s) return game:UTF8toASCII(s) end

local _dlg = nil

local function init(dlg)
    _dlg = dlg
    -- struct 里 txtResetErrTip 默认可见且带占位文案，先藏起来，交由 refresh 决定
    if _dlg.txtResetErrTip then _dlg.txtResetErrTip:SetVisible(0) end
    -- 圣痕光环「未解锁」标记同理：默认藏起来，由 _refreshAura 按是否达到光环最低门槛决定
    if _dlg.imgLockMark then _dlg.imgLockMark:SetVisible(0) end
    -- 神火来源说明（静态 tip，悬浮显示）：「1簇神火」四字用 #02016（十进制 RGB565）着色，其余白字
    if _dlg.imgAwakeFire then
        _dlg.imgAwakeFire:SetTipInfo(Config.Color.White .. L("神侍阶位每次提升可获得") .. "#02016" .. L("1簇神火"))
    end
end

-- 技能信息解析（先按传入等级，取不到回退 1 级；未拥有的技能也能出图标）
local function _skillInfo(skillId, level)
    if not skillId or skillId <= 0 then return nil end
    return idtool.FindSkill(skillId, level) or idtool.FindSkill(skillId, 1)
end

local function _skillIconPath(skillId, level)
    local info = _skillInfo(skillId, level)
    if info and info.Icon and info.Icon ~= "" then
        return "UIGame/Icon/" .. info.Icon .. ".mgff"
    end
    return ""
end

local function _skillName(skillId, level)
    local info = _skillInfo(skillId, level)
    return (info and info.Name) or ""
end

-- 圣痕图标路径：圣痕图标列（CSV，已是客户端编码字节，不再过 L()）→ 神侍面板「圣痕技能图标」目录
local function _holyMarkIconPath(icon)
    if not icon or icon == "" then return "" end
    return L("UIGame/神侍界面/圣痕技能图标/") .. icon .. ".mgff"
end

-- 宠物名 / 神侍阶名（名由 gs_level 本地查 GodServantLevelLib.csv 现算）
-- 注：txtPetLevel 已挪到根节点、不再有星（Star）展示。
local function _refreshHead(st)
    local lv = idtool.FindGodServantLevel(st.gs_level or 0)   -- {phase, star, name, ...}
    if _dlg.txtPetName then
        _dlg.txtPetName:ClearString()
        _dlg.txtPetName:AddString(st.pet_name or "")
    end
    if _dlg.txtPetLevel then
        -- 名称来自 CSV（GBK 字节，直接显示，勿再过 L）；缺名回退「神侍N阶」
        local levelText = (lv and lv.name and lv.name ~= "") and lv.name
            or L("神侍" .. ((lv and lv.phase) or 0) .. "阶")
        -- 展示颜色（GodServantLevelLib 第7列，十进制 RGB565）：>0 时用 #NNNNN 着色，否则沿用控件底色
        local color = (lv and lv.nameColor and lv.nameColor > 0) and ("#" .. lv.nameColor) or ""
        _dlg.txtPetLevel:ClearString()
        _dlg.txtPetLevel:AddString(color .. levelText)
    end
end

-- 圣痕光环（全部客户端本地算）：种族(pet_species)→PetLib.csv 得圣痕组ID，
--   再按 (圣痕组ID, 当前神侍等级) 查 HolyMarkAuraLib.csv 得 图标/光环技能(id+level)。
-- 并非所有神侍等级都有光环：光环组可从某个 gsLevel 起才配行，未达该组最低门槛 → 尚未解锁，
--   此时 imgLockMark 显示（盖在 Aura 图标上），光环信息一律按【最低门槛行】展示（图标/技能名/tip 都是它），
--   只有 txtNextAuraLevelTip 改口径：升级提示 →「进阶至X将自动解锁」。
-- 展示精简为两行：txtAuraSkillName「技能名 等级N (唯一)」+ txtNextAuraLevelTip「进阶至X将自动升级/解锁」。
local function _refreshAura(st)
    local gsLevel = st.gs_level or 0
    local auraId  = idtool.FindPetHolyMarkID(st.pet_species or 0)
    -- hm = 展示行（已解锁=当前生效行；未解锁=该组最低门槛行）；locked=true 表示尚未解锁
    local hm, locked
    if auraId > 0 then
        hm, locked = idtool.FindHolyMarkAuraForDisplay(auraId, gsLevel)
    end
    local hasAura = hm and hm.skillId and hm.skillId > 0

    -- 圣痕图标（圣痕图标列）
    if _dlg.Aura then
        _dlg.Aura:SetImage(hm and _holyMarkIconPath(hm.icon) or "")
    end
    -- 未解锁标记：盖在圣痕图标上（tip 与图标一致，见 dlg._tryAuraTip）
    if _dlg.imgLockMark then
        _dlg.imgLockMark:SetVisible(locked and 1 or 0)
    end
    -- 光环技能名+等级+(唯一) 合并一行：「铮铮铁胆 等级7 (唯一)」；「唯一」恒显
    if _dlg.txtAuraSkillName then
        _dlg.txtAuraSkillName:ClearString()
        if hasAura then
            _dlg.txtAuraSkillName:AddString(
                _skillName(hm.skillId, hm.skillLevel) .. L(" 等级") .. (hm.skillLevel or 0) .. L(" (唯一)"))
        end
    end
    -- 目标阶段提示：阶段名 X 按 GodServantLevelLib 展示颜色着色，其余文字回控件底色(灰 7F7F7F)。
    --   未解锁 → 目标=最低门槛行（即当前展示的这项）：「进阶至X将自动解锁」；
    --   已解锁 → 目标=本组 gsLevel>当前 的最低升级行：「进阶至X将自动升级」；
    --   无目标（已达最高 / 该种族无圣痕组）则隐藏本组件。
    if _dlg.txtNextAuraLevelTip then
        local nextHm = locked and hm
            or ((auraId > 0) and idtool.FindNextHolyMarkAura(auraId, gsLevel) or nil)
        local nextLv   = nextHm and idtool.FindGodServantLevel(nextHm.gsLevel) or nil
        local nextName = nextLv and nextLv.name
        if nextName and nextName ~= "" then
            local tail = locked and L("#33840将自动解锁") or L("#33840将自动升级")
            _dlg.txtNextAuraLevelTip:ClearString()
            _dlg.txtNextAuraLevelTip:AddString(L("#33840进阶至#65504") .. nextName .. tail)
            _dlg.txtNextAuraLevelTip:SetVisible(1)
        else
            _dlg.txtNextAuraLevelTip:SetVisible(0)
        end
    end
end

-- 神火技能格（顺序格，8 格常驻）。slots[i] = 第 i 条已得神火（Data.SetState 排好）。三态：
--   ① 已领悟(slots[i]，i<=已得数)           => 图标+等级、隐锁、悬浮技能说明；
--   ② 可解锁但未领悟(已得数<i<=可解锁数)     => 空图标/等级、隐锁、无 tip（继续祈愿即可获得，不再显锁）；
--   ③ 超出当前神侍品阶(i>可解锁数)           => 空图标、显锁、悬浮「品阶不足」tip。
-- 可解锁格数 maxOpen = 当前神侍等级(gs_level)对应的【品阶 phase】：每跨一品阶多解锁 1 格神火，
--   与 C++ PetGodServantPray 的抽取门槛同源（一次品阶跨越 = 抽一条新神火 = 占一格）。
--   ∴ rank 3(=契约,phase 2) → 前 2 格可解锁不显锁、其余显锁。
local function _refreshSkills(st)
    local slots = st.slots or {}
    local lv      = idtool.FindGodServantLevel(st.gs_level or 0)
    local maxOpen = (lv and lv.phase) or 0
    for i = 1, Config.MAX_SKILL_SLOTS do
        local slot = _dlg["Skill" .. i]
        if slot then
            slot:SetVisible(1)
            local sk     = slots[i]              -- 第 i 条已得神火(或 nil)
            local locked = (not sk) and (i > maxOpen)   -- 未领悟且超品阶 → 显锁；可解锁未领悟不显锁
            if slot.Icon then
                slot.Icon:SetImage(sk and _skillIconPath(sk.skill_id, sk.level) or "")
            end
            if slot.Level then
                slot.Level:ClearString()
                if sk and (sk.level or 0) > 0 then
                    slot.Level:AddString(Config.Color.White .. "Lv" .. sk.level)
                end
            end
            if slot.Lock then
                slot.Lock:SetVisible(locked and 1 or 0)
            end
        end
    end
end

-- 归元消耗（金币 + 神识 + 材料），返回本地是否买得起
--   消耗 = 基础量(GodServantResetCostLib.csv) × 归元消耗系数(当前神侍等级，查 GodServantLevelLib.csv)。
--   与服务端同公式、同数据源（该 csv 镜像 DB 表 TSGodServantResetCostLib），展示值一致；
--   真正扣减由服务端 Activity1004 GodServant.HandleReset 权威执行。
local function _refreshResetCost(st)
    local lv   = idtool.FindGodServantLevel(st.gs_level or 0)
    local F    = (lv and lv.coefficient) or 0          -- 归元消耗系数
    local base = idtool.GetGodServantResetBase()
    local dataitem = game:UIDataItem()
    local gameplayer = game:GetGamePlayer()
    local haveMoney  = dataitem:GetMoney()
    local haveGodExp = gameplayer.GodhoodExp
    local afford = true

    -- 金币/神识数值文案现挂在 NeedMoney / NeedGodExp 容器里（容器含图标+数值，便于整组显隐）
    local txtMoney  = _dlg.NeedMoney  and _dlg.NeedMoney.txtNeedMoney
    local txtGodExp = _dlg.NeedGodExp and _dlg.NeedGodExp.txtNeedGodExp

    -- 金币
    if txtMoney then
        local moneyCost = base.money * F
        txtMoney:ClearString()
        local c = (haveMoney >= moneyCost) and Config.Color.Enough or Config.Color.Lack
        txtMoney:AddString(c .. moneyCost)
        if haveMoney < moneyCost then afford = false end
    end

    -- 神识
    if txtGodExp then
        local godexpCost = base.godexp * F
        txtGodExp:ClearString()
        local c = (haveGodExp >= godexpCost) and Config.Color.Enough or Config.Color.Lack
        txtGodExp:AddString(c .. godexpCost)
        if haveGodExp < godexpCost then afford = false end
    end

    -- 材料（F<=0 或 itemId=0 的格隐藏）；need = 基础数量 × F
    for i = 1, Config.MAX_MATERIAL_SLOTS do
        local mslot = _dlg["Material" .. i]
        if mslot then
            local m = base.materials[i]
            local itemId    = m and m[1] or 0
            local baseCount = m and m[2] or 0
            if F > 0 and itemId > 0 and baseCount > 0 then
                local need = baseCount * F
                mslot:SetVisible(1)
                local itemInfo = game:StaticRes():GetItemInfo(itemId)
                if mslot.Item and itemInfo then mslot.Item:SetImage(itemInfo:GetImageName()) end
                local have = dataitem:GetItemCount(itemId)
                if mslot.Count then
                    mslot.Count:ClearString()
                    local c = (have >= need) and Config.Color.Enough or Config.Color.Lack
                    mslot.Count:AddString(c .. have .. "/" .. need)
                end
                if have < need then afford = false end
            else
                mslot:SetVisible(0)
            end
        end
    end

    return afford
end

-- 已领悟(owned==1)的神火技能数
local function _ownedSkillCount(st)
    local n = 0
    for _, sk in ipairs(st.skills or {}) do
        if sk and sk.owned == 1 then n = n + 1 end
    end
    return n
end

-- 归元不可用原因（结构性门槛，按指定优先级判定；返回红字文案，nil=门槛已满足可展示消耗）：
--   ① 还未领悟任何神火技能  ② 仍有可觉悟次数未用尽  ③ 神侍等级未达【契约】(gs_level < MIN_RESET_GS_LEVEL)
-- 门槛比服务端更严（服务端归元只要祈愿>0、不要求觉悟满），确保界面不会「可点却被服务端拒」。
-- 「买得起」不算结构性阻断：门槛通过后由消耗节点红/绿 + 按钮 enable 表达（见 refresh）。
local function _resetBlockReason(st, leftAwake)
    if _ownedSkillCount(st) <= 0 then
        return L("还未领悟神火技能，不能归元")
    end
    if (leftAwake or 0) > 0 then
        return L("还有神火尚未使用，不能归元")
    end
    if (st.gs_level or 0) < Config.MIN_RESET_GS_LEVEL then
        return L("需要达到【契约】及以上品阶")
    end
    return nil
end

-- 隐藏全部归元消耗节点（金币/神识容器含图标+数值、材料格）——展示错误提示时用
local function _hideResetCost()
    if _dlg.NeedGodExp then _dlg.NeedGodExp:SetVisible(0) end
    if _dlg.NeedMoney  then _dlg.NeedMoney:SetVisible(0) end
    for i = 1, Config.MAX_MATERIAL_SLOTS do
        local mslot = _dlg["Material" .. i]
        if mslot then mslot:SetVisible(0) end
    end
end

-- 归元失败：服务端回错误码（材料不足时附带不足物品 item_id），这里补名字转成玩家可读提示。
-- 未覆盖的码返回 nil，交 ErrorHandler 通用映射。宠物名(st.pet_name)/物品名(GetItemInfo().Name)都是 GBK 字节，
-- 勿再过 L；只有硬编码中文文案过 L。
local function _resetErrorMessage(errCode, itemId)
    local st = Data.GetState()
    local petName = (st and st.pet_name) or ""
    if errCode == ErrorCode.NOT_ENOUGH_MONEY then
        return L("您的金币不够哦")
    elseif errCode == ErrorCode.NOT_ENOUGH_GODEXP then
        return L("您的神识不够哦")
    elseif errCode == ErrorCode.NOT_ENOUGH_ITEM then
        local info = (itemId and itemId > 0) and game:GetItemInfo(itemId) or nil
        local itemName = (info and info.Name) or ""
        if itemName == "" then return L("归元材料数量不够哦") end
        return L("【") .. itemName .. L("】数量不够哦")
    elseif errCode == ErrorCode.NOT_CONTRACT then
        return L("【") .. petName .. L("】神侍位阶不满足条件")
    elseif errCode == ErrorCode.NOT_FULL_AWAKE then
        return L("【") .. petName .. L("】还有神火尚未使用，不能执行归元指令")
    end
    return nil
end

-- 下次领悟说明（txtAwakeTip）：预测下一次觉悟(pray_count+1)的结果，与服务端 PetGodServantPray 同规则——
--   跨阶段(phase(next) > phase(next-1)) 或 尚无神火 → 解锁新技能；否则升级已有技能。
-- 所有神火耗尽（还可领悟次数 leftAwake<=0，含无神火库的宠物）时：无「本次觉悟」可预告 → 隐藏本组件。
local function _refreshAwakeTip(st, leftAwake)
    if not _dlg.txtAwakeTip then return end
    if (leftAwake or 0) <= 0 then
        _dlg.txtAwakeTip:SetVisible(0)
        return
    end
    local nextCount = (st.pray_count or 0) + 1
    local curLv     = idtool.FindGodServantLevel(nextCount)
    local prevLv    = (nextCount > 1) and idtool.FindGodServantLevel(nextCount - 1) or nil
    local crossed   = ((curLv and curLv.phase) or 0) > ((prevLv and prevLv.phase) or 0)
    local unlock    = crossed or _ownedSkillCount(st) <= 0

    -- 仍可觉悟：描述本次觉悟的效果
    local tip = unlock
        and (Config.Color.White .. L("觉悟后") .. Config.Color.Highlight .. L("解锁新技能"))
        or  (Config.Color.White .. L("觉悟后已有技能") .. Config.Color.Highlight .. L("升级"))
    _dlg.txtAwakeTip:ClearString()
    _dlg.txtAwakeTip:AddString(tip)
    _dlg.txtAwakeTip:SetVisible(1)
end

-- 全量刷新
local function refresh()
    if not _dlg then return end
    local st = Data.GetState()
    if not st then return end

    _refreshHead(st)
    _refreshAura(st)
    _refreshSkills(st)

    -- 剩余可觉悟次数（与 btnAwake 点击反馈共用 Data.GetLeftAwakeCount，判定一致）
    local leftAwake = Data.GetLeftAwakeCount()
    if _dlg.txtLeftAwakeCount then
        _dlg.txtLeftAwakeCount:ClearString()
        _dlg.txtLeftAwakeCount:AddString(tostring(leftAwake))
    end
    -- 祈愿按钮常开可点：能否领悟改由点击时校验并反馈（还可领悟次数=0 等，见 dlg onEventProc）
    if _dlg.btnAwake then
        _dlg.btnAwake:SetEnable(1)
    end

    -- 下次领悟说明（升级已有技能 / 解锁新技能）
    _refreshAwakeTip(st, leftAwake)

    -- 归元已消耗的资源系数（服务端下发 reset_cost = pet:GetGodFireResetCost()，历次归元累加）
    --   该值=0（从未归元过）时不显示，>0 才显示。
    if _dlg.txtResetCost then
        local resetCost = tonumber(st.reset_cost) or 0
        if resetCost > 0 then
            _dlg.txtResetCost:ClearString()
            _dlg.txtResetCost:AddString(L("资源系数:") .. resetCost)
            _dlg.txtResetCost:SetVisible(1)
        else
            _dlg.txtResetCost:SetVisible(0)
        end
    end

    -- 归元：先判结构性阻断原因（优先级 未领悟→觉悟未尽→未达契约）。
    --   有阻断 → 显示 txtResetErrTip、隐藏消耗节点、按钮置灰；
    --   无阻断 → 隐藏提示、展示消耗(红/绿) + 按钮按本地「买得起」决定。
    local blockTip = _resetBlockReason(st, leftAwake)
    Debug("GodServant.refresh species=" .. tostring(st.pet_species) .. " gs_level=" .. tostring(st.gs_level)
        .. " pray=" .. tostring(st.pray_count) .. " leftAwake=" .. tostring(leftAwake)
        .. " ownedSkills=" .. tostring(_ownedSkillCount(st)) .. " blocked=" .. tostring(blockTip ~= nil))
    if blockTip then
        if _dlg.txtResetErrTip then
            _dlg.txtResetErrTip:ClearString()
            _dlg.txtResetErrTip:AddString(blockTip)   -- 无内联色码 → 用控件底色(红 D9001B)
            _dlg.txtResetErrTip:SetVisible(1)
        end
        _hideResetCost()
        if _dlg.btnReset then _dlg.btnReset:SetEnable(0) end
    else
        if _dlg.txtResetErrTip then _dlg.txtResetErrTip:SetVisible(0) end
        if _dlg.NeedGodExp then _dlg.NeedGodExp:SetVisible(1) end
        if _dlg.NeedMoney  then _dlg.NeedMoney:SetVisible(1) end
        local afford = _refreshResetCost(st)
        if _dlg.btnReset then _dlg.btnReset:SetEnable(afford and 1 or 0) end
    end
end

return {
    Init              = init,
    Refresh           = refresh,
    ResetErrorMessage = _resetErrorMessage,
}
