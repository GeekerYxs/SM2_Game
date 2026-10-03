-- ================================================================
-- 神侍-主对话框（单弹窗，针对单只宠物）
--
-- 打开方式（不绑 NPC；入口后续由宠物面板按钮接线）：
--   local dlg = game:LuaUIMgr():FindDlg("GodServant")
--   dlg.Raw:ShowDlg(true)      -- 显示
--   dlg:SetInfo(petIdx)        -- 指定宠物并拉取状态
-- 服务端 Activity1004 在任意地图处理请求（GodServant_*Request）。
-- ================================================================

local dlgbuilder  = require "dlg_builder"
local ScriptEvent = require "script_event"

local struct      = require "uigodservant_struct"

-- 源码写 UTF-8，经 L() = game:UTF8toASCII 转成客户端编码(GBK)后再交给引擎（显示文案 + 资源路径都要过）
local L = function(s) return game:UTF8toASCII(s) end
local prefix_path = L("UIGame/神侍界面")

local Config       = require "ui.dlgs.godservant.GodServantConfig"
local Data         = require "ui.dlgs.godservant.godservant_data"
local network      = require "ui.dlgs.godservant.godservant_network"
local uiUpdater    = require "ui.dlgs.godservant.godservant_ui_updater"
local ErrorHandler = require "ui.dlgs.godservant.godservant_error_handler"
local idtool       = require "id_parse_tool"   -- 圣痕光环技能 tip、归元材料本地查（PetLib+HolyMarkAuraLib+GodServantResetCostLib）
local gamestate    = require "game_state"      -- 战斗态门禁：战斗中禁止打开神侍界面（isInFight）

local _dlg = nil

-- ----------------------------------------------------------------
-- 悬浮 tip：神火技能格 / 圣痕光环 / 归元材料
-- ----------------------------------------------------------------
local function _trySkillTip(ctrlId)
    local st = Data.GetState()
    local slots = (st and st.slots) or {}
    -- 可解锁格数 = 当前神侍等级对应的品阶 phase（与 uiUpdater._refreshSkills 同源）；超此格数=锁定格。
    local lv      = st and idtool.FindGodServantLevel(st.gs_level or 0) or nil
    local maxOpen = (lv and lv.phase) or 0
    for i = 1, Config.MAX_SKILL_SLOTS do
        local slot = _dlg["Skill" .. i]
        if slot then
            -- 超品阶锁定格 Lock 显示、盖在上层，悬浮命中的是 Lock；已得命中的是 Icon。两者都认。
            local onIcon = slot.Icon and ctrlId == slot.Icon.CtrlID
            local onLock = slot.Lock and ctrlId == slot.Lock.CtrlID
            if onIcon or onLock then
                local sk = slots[i]   -- 第 i 条已得神火(或 nil=未领悟)
                local target = (onLock and slot.Lock) or slot.Icon
                if sk then
                    target:SetTipInfo(game:GetSkillTip(sk.skill_id, sk.level))
                elseif i > maxOpen then
                    -- 超品阶锁定格：第 i 格需神侍品阶达到 i → 取该段位第一个神侍名（GBK 字节，勿再过 L）
                    local needName = idtool.FindGodServantNameByPhase(i)
                    if needName and needName ~= "" then
                        target:SetTipInfo(L("需要神侍位阶达到") .. needName)
                    else
                        target:SetTipInfo(L("神侍位阶不足，无法解锁"))
                    end
                else
                    target:SetTipInfo("")   -- 可解锁但未领悟：不弹 tip
                end
                return true
            end
        end
    end
    return false
end

local function _tryMaterialTip(ctrlId)
    -- 归元材料本地配置（GodServantResetCostLib.csv → { {itemId, baseCount}, ... }）；与 _refreshResetCost 同源
    local materials = idtool.GetGodServantResetBase().materials or {}
    for i = 1, Config.MAX_MATERIAL_SLOTS do
        local mslot = _dlg["Material" .. i]
        if mslot and mslot.Item and ctrlId == mslot.Item.CtrlID then
            local m = materials[i]
            local itemId = m and m[1] or 0
            if itemId > 0 then
                mslot.Item:SetTipInfo(game:GetItemTip(itemId))
            end
            return true
        end
    end
    return false
end

-- 圣痕光环 tip：未解锁时 imgLockMark 盖在 Aura 图标上层，悬浮命中的是锁标；两者 tip 内容相同
-- （都取当前展示行的技能说明：已解锁=当前生效行，未解锁=该光环组最低门槛行，与 uiUpdater._refreshAura 同源）。
local function _tryAuraTip(ctrlId)
    local onAura = _dlg.Aura and ctrlId == _dlg.Aura.CtrlID
    local onLock = _dlg.imgLockMark and ctrlId == _dlg.imgLockMark.CtrlID
    if not (onAura or onLock) then return false end
    local target = (onLock and _dlg.imgLockMark) or _dlg.Aura
    local st = Data.GetState()
    -- 圣痕光环技能本地算：种族→PetLib.csv 圣痕组ID，再按 (组ID, 神侍等级) 查 HolyMarkAuraLib.csv
    if st then
        local auraId = idtool.FindPetHolyMarkID(st.pet_species or 0)
        local hm = (auraId > 0) and idtool.FindHolyMarkAuraForDisplay(auraId, st.gs_level or 0) or nil
        if hm and hm.skillId and hm.skillId > 0 then
            target:SetTipInfo(game:GetSkillTip(hm.skillId, hm.skillLevel or 1))
        end
    end
    return true
end

-- ----------------------------------------------------------------
-- 事件处理
-- ----------------------------------------------------------------
local function onEventProc(luadlg, eventCode, ctrlId, ctrl)
    if not luadlg then return end

    if eventCode == UIEventDef.TBN_CLICKED then
        -- 领悟/祈愿（免费）：点击反馈 —— 先本地校验，不通过弹提示、不发请求
        if luadlg.btnAwake and ctrlId == luadlg.btnAwake.CtrlID then
            -- ① 还可领悟次数=0：没有神火可领悟
            if Data.GetLeftAwakeCount() <= 0 then
                ErrorHandler.ShowError(nil, L("没有神火了，不能领悟"))
                return
            end
            network.SendPrayRequest(Data.GetPetIdx())
            return
        end
        -- 归元（有消耗，不可逆）：不直接发请求，先弹二次确认框（GodServantConfirm），
        -- 用户在确认框点「确定」时才真正发出 GodServant_ResetRequest。
        if luadlg.btnReset and ctrlId == luadlg.btnReset.CtrlID then
            local confirmDlg = game:LuaUIMgr():FindDlg("GodServantConfirm")
            if confirmDlg then confirmDlg:ShowDlg(true) end
            return
        end
    elseif eventCode == UIEventDef.TIN_MOUSEMOVE then
        if _trySkillTip(ctrlId) then return end
        if _tryMaterialTip(ctrlId) then return end
        if _tryAuraTip(ctrlId) then return end
    end
end

-- ----------------------------------------------------------------
-- 显示：渲染当前状态（数据由 SetInfo 触发的 OpenResult 填充）
-- ----------------------------------------------------------------
local function onShow(luadlg, show)
    if show then
        uiUpdater.Refresh()
    end
end

-- ----------------------------------------------------------------
-- 资源变化 → 刷新（归元消耗的金币/神识/材料红绿可负担态实时跟随）
--   物品变化：引擎 OnUpdateItemBar/OnUpdateItemCount（原生已下发）
--   金币/神识变化：CUILuaDlgMgr 新增 money/godexp updater → OnUpdateMoney/OnUpdateGodhoodExp
--     （客户端 C++ 改动，需重编译；老客户端只是不触发这两条，不报错）
--   仅在界面可见且已有宠物状态时刷新，避免隐藏时空转。刷新只重读本地数值，不发网络请求。
-- ----------------------------------------------------------------
local function onResourceChanged()
    if not _dlg or not _dlg.Raw then return end
    if not _dlg.Raw:GetVisible() then return end
    if not Data.GetState() then return end
    uiUpdater.Refresh()
end

-- ----------------------------------------------------------------
-- 战斗态门禁：战斗中禁止打开神侍详细界面（读 game_state.isInFight，与移动/菜单等操作一致）。
-- 命中战斗则弹提示并返回 true，调用方据此中止打开。
-- ----------------------------------------------------------------
local function _blockedInFight()
    if gamestate.isInFight then
        ErrorHandler.ShowWarning(L("战斗中无法打开神侍界面"))
        return true
    end
    return false
end

-- ----------------------------------------------------------------
-- 对外入口：指定宠物并拉取其神侍状态
-- ----------------------------------------------------------------
local function setInfo(petIdx)
    if _blockedInFight() then return end
    Data.SetPetIdx(petIdx)
    Data.Reset()
    network.SendOpenRequest(petIdx)
end

-- ----------------------------------------------------------------
-- S2C 回包分发
-- ----------------------------------------------------------------
local function onCallScript(luadlg, event, obj)
    if obj == nil then return end

    if event == ScriptEvent.GodServant_OpenResult then
        Debug("GodServant.OpenResult ret=" .. tostring(obj.ret) .. " errCode=" .. tostring(obj.errCode)
            .. " species=" .. tostring(obj.pet_species) .. " pray=" .. tostring(obj.pray_count)
            .. " skills=" .. tostring(obj.skills and #obj.skills or "nil"))
        if obj.ret == false then
            ErrorHandler.ShowError(obj.errCode)
            return
        end
        Data.SetState(obj)
        uiUpdater.Refresh()

    elseif event == ScriptEvent.GodServant_PrayResult then
        if obj.ret == false then
            ErrorHandler.ShowError(obj.errCode)
            return
        end
        -- 祈愿成功文案：区分「获得新神火技能」与「已有技能升级」。
        --   服务端下发整库候选（owned=1 表示已拥有）：跨阶段抽新神火 → 已拥有条数 +1；
        --   未跨阶段升级 → 条数不变、某条等级 +1。故以「已拥有条数」是否增加区分二者。
        --   必须在 Data.SetState(obj) 覆盖旧态之前取旧的已拥有条数。
        local oldState = Data.GetState()
        local oldOwned = (oldState and oldState.slots) and #oldState.slots or 0
        Data.SetState(obj)                          -- 构建 obj.slots（已拥有神火格）
        local newOwned = (obj.slots and #obj.slots) or 0
        -- 宠物名着色（obj.pet_name 服务端下发，已是 GBK 字节，勿再过 L）；ShowMessage 走 #RRGGBB#
        -- 六位十六进制通知格式，65504(RGB565 十进制) 对应黄色 #ffff00#，名字后用 #ffffff# 复位为白。
        local petName = obj.pet_name or ""
        local tail = (newOwned > oldOwned)
            and L("献祭了一簇神火，觉悟了新的神火技能")
            or  L("献祭了一簇神火，现有的神火技能升级了")
        ErrorHandler.ShowSuccess("#ffff00#" .. petName .. "#ffffff#" .. tail)
        uiUpdater.Refresh()

    elseif event == ScriptEvent.GodServant_ResetResult then
        if obj.ret == false then
            -- 归元失败：带宠物名/物品名的定制提示（材料不足时 obj.item_id 由服务端权威给出；未覆盖码回退通用映射）
            ErrorHandler.ShowError(obj.errCode, uiUpdater.ResetErrorMessage(obj.errCode, obj.item_id))
            return
        end
        -- 成功提示带宠物名（obj.pet_name 服务端下发，已是 GBK 字节，勿再过 L）
        ErrorHandler.ShowSuccess((obj.pet_name or "") .. L("聚拢了离散的神火，可以重新领悟神火技能了！"))
        Data.SetState(obj)
        uiUpdater.Refresh()
    end
end

-- ----------------------------------------------------------------
-- 创建
-- ----------------------------------------------------------------
local function createDlg(dlgmgr)
    -- 第 5 个参数 true：本界面所有文本统一加描边（提升深色背景上的可读性）
    local luadlg = dlgbuilder(dlgmgr, struct, prefix_path, 3000, true)
    _dlg = luadlg

    luadlg.OnEventProc  = onEventProc
    luadlg.OnShow       = onShow
    luadlg.OnCallScript = onCallScript

    -- 监测物品 / 金币 / 神识变化 → 刷新界面（归元消耗可负担态实时跟随）
    luadlg.OnUpdateItemBar    = onResourceChanged
    luadlg.OnUpdateItemCount  = onResourceChanged
    luadlg.OnUpdateMoney      = onResourceChanged
    luadlg.OnUpdateGodhoodExp = onResourceChanged

    -- 注册 S2C 事件
    HandleCallScript(ScriptEvent.GodServant_OpenResult, luadlg)
    HandleCallScript(ScriptEvent.GodServant_PrayResult, luadlg)
    HandleCallScript(ScriptEvent.GodServant_ResetResult, luadlg)

    uiUpdater.Init(luadlg)

    -- 对外入口：宠物面板按钮 → dlg:SetInfo(petIdx)
    luadlg.SetInfo = function(_self, petIdx)
        -- 兼容 dlg:SetInfo(idx) 与 dlg.SetInfo(idx) 两种调用
        if type(_self) == "number" then petIdx = _self end
        setInfo(petIdx)
    end

    return luadlg
end

-- ----------------------------------------------------------------
-- 原生客户端入口（全局函数，供 C++ 调用）：
--   点击 UIPetBaseProperty 的宠物头像 →
--   CGameLua::Instance()->CallFunc("OpenGodServantDlg", m_nPetIdx)
-- 显示神侍界面并拉取该宠物状态（回包 GodServant_OpenResult 填充+刷新）。
-- 用模块本地 _dlg（FindDlg 返回的是原生 CUILuaDlg，没有 Lua 侧 SetInfo）。
-- ----------------------------------------------------------------

function OpenGodServantDlg(petIdx)
    if not _dlg or not _dlg.Raw then return end
    if _blockedInFight() then return end   -- 战斗中拦截，且先于 ShowDlg，避免弹出空窗
    _dlg.Raw:ShowDlg(true)
    setInfo(petIdx)
end

return { OnCreate = createDlg }
