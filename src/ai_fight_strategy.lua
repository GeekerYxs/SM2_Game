-- ============================================================================
-- ai_fight_strategy.lua
-- 多智能体协同战斗AI策略大脑 (SMSM2 Multi-Agent Team Combat Brain)
--
-- 核心架构:
-- 1. 动态能力自省 (Capability Introspection): 0硬编码，严格排除Type==6被动技能
-- 2. 分布式战术看板 (Team Blackboard): 跨进程意图同步，消除伤害溢出(Anti-Overkill)
-- 3. 智能生命护航 (Heal Coordination): 紧急救助令牌派发，杜绝过量双重治疗
-- 4. 战术时序流水线: 群攻整体压血 -> 意图锁定点杀 -> 残局普攻控蓝蓄力
-- ============================================================================

local AI = {}

-- 动态加载并接入地图巡逻引擎 (战外自动巡逻，战内静默托管)
local MapPatrol = nil
pcall(function()
    package.loaded["map_patrol"] = nil
    local hasPatrol, patrolModule = pcall(require, "map_patrol")
    if hasPatrol and patrolModule then
        MapPatrol = patrolModule
        Info("[AI战斗] 地图巡逻引擎成功接入AI战术总线!")
    else
        Warn("[AI战斗] 地图巡逻引擎加载失败: " .. tostring(patrolModule))
    end
end)

-- 配置开关与战术阈值
AI.Config = {
    Enabled = true,                 -- AI 策略总开关
    DebugLog = true,                -- 是否输出详细战术日志
    AoeEnemyThreshold = 2,          -- 敌方存活数 >= 2 时优先群体技能 (如 扫射 803 / 连珠箭 310)
    FinishingHpThreshold = 180,     -- 敌方血量低于此值且只剩1只时，普攻收割省蓝省SP
    EmergencyHealRatio = 0.35,      -- 自身/队友生命比例低于 35% 时触发紧急治疗
    TeamHealRatio = 0.30,           -- 队友生命比例低于 30% 时触发团队护航
    TeamHealthyThreshold = 0.75,    -- 全队最低血量比 >= 75% 判定为安全健康状态 (小号自保隐匿/护盾，不产生治疗仇恨)
    BlackboardFile = "team_blackboard.txt", -- 本地共享战术看板路径
    ExperimentRapidShotLeader = false, -- 实验结束: 实测证明扫射清怪更快更稳，恢复全员扫射为主
}

-- 全技能库全集索引 (支持换号任意职业动态自省)
local ALL_PLAYER_SKILL_IDS = {
    101, 102, 103, 104, 105, 111, 112, 113, 201, 204, 206, 207, 208, 209, 210,
    301, 302, 306, 307, 308, 309, 310, 311, 312, 313,
    601, 602, 603, 604, 605, 606, 607, 608, 609,
    701, 702, 703, 704, 705, 706, 707, 708, 709, 710, 711,
    801, 802, 803, 804, 805, 806, 807,
    901, 902, 903, 904, 905, 906
}

local ALL_PLAYER_MAGIC_IDS = {
    204, 205, 206, 207, 208, 210, 211, 212, 213, 221, 222, 223, 224, 225,
    226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238,
    303, 304, 305, 306, 307, 308, 309, 310, 311, 312, 313, 314, 315, 316, 317,
    318, 319, 320, 330, 331, 332, 333, 334, 340, 341, 342, 343, 344,
    350, 351, 352, 353, 354, 355
}

local ALL_PET_ABILITY_IDS = {
    1501, 1502, 1503, 1504, 1506, 1511, 1514, 1601, 1602, 1603, 1604, 1605, 1606,
    1607, 1610, 1612, 1613, 1614, 1701, 1702, 1703, 1704, 1705, 1706, 1708,
    1717, 1718, 1719, 1720, 1721, 1723, 1724, 1801, 1804, 1805, 1809, 1811,
    4000, 4010, 4020, 4030, 4040, 5000, 5010,
    21451, 21452, 21551, 21552, 21651, 21652, 21751, 21752, 21851, 21852
}

-- 知名物理技能库 (SkillLib - 战士/格斗家/浪客/猎人/刺客)
local KNOWN_PHYSICAL_SKILLS = {
    -- 基础物理技能
    [104]  = { Name = "强力攻击", IsSingle = true, Priority = 60, BaseDmg = 180 },
    [105]  = { Name = "连击", IsSingle = true, Priority = 65, BaseDmg = 200 },
    -- 战士 / 勇者技能
    [206]  = { Name = "嘲讽", Priority = 50 },
    [207]  = { Name = "群体嘲讽", IsAOE = true, Priority = 55 },
    [208]  = { Name = "反戈一击", Priority = 50 },
    [209]  = { Name = "突击", IsSingle = true, Priority = 70, BaseDmg = 220 },
    [606]  = { Name = "怒气斩", IsSingle = true, Priority = 85, BaseDmg = 350 },
    -- 格斗家技能
    [702]  = { Name = "五雷穿心掌", IsSingle = true, Priority = 90, BaseDmg = 380 },
    [707]  = { Name = "元气斩", IsSingle = true, Priority = 85, BaseDmg = 320 },
    [710]  = { Name = "顺势劈", IsSingle = true, Priority = 80, BaseDmg = 280 },
    -- 浪客 / 猎人技能
    [307]  = { Name = "痛击", IsSingle = true, Priority = 65, BaseDmg = 200 },
    [308]  = { Name = "能量射击", IsSingle = true, Priority = 90, BaseDmg = 350 },
    [309]  = { Name = "精准射击", IsSingle = true, Priority = 98, BaseDmg = 550 }, -- 单体核心神技(满级Lv12附带530真伤+100%物攻，单怪绝对最优解)
    [310]  = { Name = "连珠箭", IsAOE = true, Priority = 92, BaseDmg = 400 },     -- 小范围3目标群攻(单怪100%物攻无附加，单怪弱于精准射击)
    [803]  = { Name = "扫射", IsAOE = true, Priority = 100, BaseDmg = 250 },      -- 全屏10目标群攻(>=2怪压制核心，但单怪仅40%物攻不可用于单怪)
    -- 刺客技能
    [902]  = { Name = "致残", IsSingle = true, Priority = 75, BaseDmg = 240 },
    [903]  = { Name = "刺杀", IsSingle = true, Priority = 95, BaseDmg = 450 },
    [904]  = { Name = "毒蛇之牙", IsSingle = true, Priority = 85, BaseDmg = 300 },
}

-- 知名法术库 (MagicLib - 术士/元素使/催眠师/学者/大夫/医仙 + 宠物专属)
local KNOWN_MAGICS = {
    -- 术士 / 元素使法术
    [101]  = { Name = "法术飞弹", IsSingle = true, Priority = 60, BaseDmg = 180 },
    [204]  = { Name = "魔法神箭", IsSingle = true, Priority = 90, BaseDmg = 380 },
    [205]  = { Name = "魔爆", IsAOE = true, Priority = 95, BaseDmg = 260 },
    [206]  = { Name = "魔法火焰", IsAOE = true, Priority = 90, BaseDmg = 240 },
    [212]  = { Name = "隐匿", IsBuff = true, Priority = 80 },
    [221]  = { Name = "冰箭", IsSingle = true, Priority = 88, BaseDmg = 320 },
    [222]  = { Name = "暴风雪", IsAOE = true, Priority = 100, BaseDmg = 350 },
    [232]  = { Name = "紫冥之箭", IsSingle = true, Priority = 85, BaseDmg = 280 },
    -- 学者 / 大夫 / 医仙法术
    [303]  = { Name = "治疗术", IsCure = true, Priority = 90, CureAmt = 600 },
    [304]  = { Name = "强愈术", IsCure = true, Priority = 95, CureAmt = 900 },
    [305]  = { Name = "群体治疗术", IsCure = true, IsAOE = true, Priority = 95, CureAmt = 350 },
    [306]  = { Name = "复活术", Priority = 100 },
    [307]  = { Name = "保护盾", IsBuff = true, Priority = 70 },
    [308]  = { Name = "神佑", IsBuff = true, Priority = 75 },
    [309]  = { Name = "回复术", IsCure = true, Priority = 80, CureAmt = 300 },
    [310]  = { Name = "心灵震撼", IsSingle = true, Priority = 85, BaseDmg = 260 },
    [313]  = { Name = "急救术", IsCure = true, Priority = 92, CureAmt = 700 },
    [354]  = { Name = "天之箭", IsSingle = true, Priority = 88, BaseDmg = 340 },
    [355]  = { Name = "魔法盾", IsBuff = true, Priority = 70 },
    -- 宠物专属法术 (烈焰爆发/烈焰风暴 明确为全屏AOE群攻，严禁当作单体或普攻)
    [1501] = { Name = "火球术", IsSingle = true, Priority = 80, BaseDmg = 200, SPCost = 1 },
    [1502] = { Name = "烈火", IsSingle = true, Priority = 85, BaseDmg = 280, SPCost = 1 },
    [1503] = { Name = "烈焰", IsSingle = true, Priority = 90, BaseDmg = 380, SPCost = 1 },
    [1504] = { Name = "烈焰爆发", IsAOE = true, Priority = 99, BaseDmg = 500, SPCost = 1 },
    [1506] = { Name = "烈焰风暴", IsAOE = true, Priority = 100, BaseDmg = 520, SPCost = 1 },
}

-- ============================================================================
-- 1. 分布式战术看板 (Team Blackboard IPC Engine)
-- ============================================================================
local Blackboard = {}

function Blackboard.GetTime()
    if os ~= nil and os.time ~= nil then
        return os.time()
    end
    return 0
end

-- 读取共享看板数据 (防崩溃 pcall 封装)
function Blackboard.ReadState()
    local state = {
        reserved_dmg = {},      -- [targetPos] = total_reserved_dmg
        healer_pos = -1,        -- 已接单单体急救者的客户端位号
        group_healer_pos = -1,  -- 已接单群疗者的客户端位号
        revive_targets = {},    -- [deadPos] = doctor_pos 已接单复活的客户端位号
        silenced_fighters = {}, -- [pos] = true 被封魔控制的战斗者
        sealed_fighters = {},   -- [pos] = true 被封技控制的战斗者
        record_count = 0,
    }

    if io == nil or io.open == nil then
        return state
    end

    local now = Blackboard.GetTime()

    pcall(function()
        local f = io.open(AI.Config.BlackboardFile, "r")
        if not f then return end

        for line in f:lines() do
            -- 格式: timestamp,type,targetPos,val,sourcePos
            local parts = {}
            for p in string.gmatch(line, "([^,]+)") do
                table.insert(parts, p)
            end

            if #parts >= 5 then
                local ts = tonumber(parts[1]) or 0
                local recType = parts[2]
                local targetPos = tonumber(parts[3]) or -1
                local val = tonumber(parts[4]) or 0
                local srcPos = tonumber(parts[5]) or -1

                -- 仅保留最近 15 秒内的有效战斗记录 (避免上一场残余)
                if (now - ts) <= 15 and (now - ts) >= -2 then
                    if recType == "DMG" and targetPos >= 0 then
                        state.reserved_dmg[targetPos] = (state.reserved_dmg[targetPos] or 0) + val
                        state.record_count = state.record_count + 1
                    elseif recType == "HEAL" then
                        state.healer_pos = srcPos
                    elseif recType == "GROUP_HEAL" then
                        -- 群疗互斥令牌有效窗口设为 6 秒 (覆盖单回合出招窗口)
                        if (now - ts) <= 6 and (now - ts) >= -1 then
                            state.group_healer_pos = srcPos
                        end
                    elseif recType == "REVIVE" then
                        -- 复活互斥令牌有效窗口设为 6 秒
                        if (now - ts) <= 6 and (now - ts) >= -1 and targetPos >= 0 then
                            state.revive_targets[targetPos] = srcPos
                        end
                    elseif recType == "RELEASE_GROUP_HEAL" then
                        if state.group_healer_pos == srcPos then
                            state.group_healer_pos = -1
                        end
                    elseif recType == "SILENCED" then
                        if (now - ts) <= 8 and (now - ts) >= -1 and srcPos >= 0 then
                            state.silenced_fighters[srcPos] = true
                        end
                    elseif recType == "SEALED" then
                        if (now - ts) <= 8 and (now - ts) >= -1 and srcPos >= 0 then
                            state.sealed_fighters[srcPos] = true
                        end
                    end
                end
            end
        end
        f:close()
    end)

    return state
end

-- 登记战斗者受控状态 (如 封魔 SILENCED 或 封技 SEALED)
function Blackboard.ReportFighterStatus(srcPos, statusType)
    if io == nil or io.open == nil then return end
    local now = Blackboard.GetTime()
    pcall(function()
        local f = io.open(AI.Config.BlackboardFile, "a")
        if f then
            f:write(string.format("%d,%s,-1,0,%d\n", now, statusType, srcPos))
            f:close()
        end
    end)
end

-- 释放群疗令牌 (受控或无法施法时主动放弃，让健康队友接管)
function Blackboard.ReleaseGroupHealToken(srcPos)
    if io == nil or io.open == nil then return end
    local now = Blackboard.GetTime()
    pcall(function()
        local f = io.open(AI.Config.BlackboardFile, "a")
        if f then
            f:write(string.format("%d,RELEASE_GROUP_HEAL,-1,0,%d\n", now, srcPos))
            f:close()
        end
    end)
end

-- 登记攻击伤害预定 (宣告该目标将承受预期伤害)
function Blackboard.ReserveDamage(targetPos, dmg, srcPos)
    if io == nil or io.open == nil then return end
    local now = Blackboard.GetTime()

    pcall(function()
        local f = io.open(AI.Config.BlackboardFile, "a")
        if f then
            f:write(string.format("%d,DMG,%d,%d,%d\n", now, targetPos, math.floor(dmg), srcPos))
            f:close()
        end
    end)
end

-- 申请紧急治疗令牌 (只有拿到令牌的唯一医生施放单体急救)
function Blackboard.TryClaimHealToken(srcPos)
    local state = Blackboard.ReadState()
    if state.healer_pos >= 0 and state.healer_pos ~= srcPos then
        return false -- 已被其他队友认领
    end

    if io ~= nil and io.open ~= nil then
        local now = Blackboard.GetTime()
        pcall(function()
            local f = io.open(AI.Config.BlackboardFile, "a")
            if f then
                f:write(string.format("%d,HEAL,-1,0,%d\n", now, srcPos))
                f:close()
            end
        end)
    end
    return true
end

-- 申请全队健康时的群疗令牌 (当全队血量健康时，仅允许一位医生释放群体治疗术，另一位待命)
function Blackboard.TryClaimGroupHealToken(srcPos)
    local state = Blackboard.ReadState()
    if state.group_healer_pos >= 0 and state.group_healer_pos ~= srcPos then
        return false, state.group_healer_pos -- 已被另一位医仙认领
    end

    if io ~= nil and io.open ~= nil then
        local now = Blackboard.GetTime()
        pcall(function()
            local f = io.open(AI.Config.BlackboardFile, "a")
            if f then
                f:write(string.format("%d,GROUP_HEAL,-1,0,%d\n", now, srcPos))
                f:close()
            end
        end)
    end
    return true, srcPos
end

-- 申请紧急复活令牌 (防止多位医仙对同一阵亡队友重复释放复活术)
function Blackboard.TryClaimReviveToken(srcPos, targetPos)
    local state = Blackboard.ReadState()
    if state.revive_targets and state.revive_targets[targetPos] and state.revive_targets[targetPos] ~= srcPos then
        return false, state.revive_targets[targetPos] -- 已被另一位医仙接单施救
    end

    if io ~= nil and io.open ~= nil then
        local now = Blackboard.GetTime()
        pcall(function()
            local f = io.open(AI.Config.BlackboardFile, "a")
            if f then
                f:write(string.format("%d,REVIVE,%d,0,%d\n", now, targetPos, srcPos))
                f:close()
            end
        end)
    end
    return true, srcPos
end

-- 新回合/战斗开始时清理过期看板 (防竞争保护: 仅队长执行，且仅清理陈旧条目，杜绝队员间互删令牌)
function Blackboard.ClearStale()
    if io == nil or io.open == nil then return end
    pcall(function()
        local myPos = game and game:GetMyPos() or -1
        if myPos ~= 17 then
            return -- 非队长绝不操作看板文件
        end

        local f = io.open(AI.Config.BlackboardFile, "r")
        if not f then return end
        local content = f:read("*a") or ""
        f:close()

        -- 仅当文件体积超过 16KB 时执行按时间戳收缩
        if #content > 16384 then
            local now = Blackboard.GetTime()
            local keep = {}
            for line in string.gmatch(content, "[^\r\n]+") do
                local ts = tonumber(string.match(line, "^(%d+)")) or 0
                if (now - ts) <= 15 then
                    table.insert(keep, line)
                end
            end
            local fw = io.open(AI.Config.BlackboardFile, "w")
            if fw then
                if #keep > 0 then
                    fw:write(table.concat(keep, "\n") .. "\n")
                end
                fw:close()
            end
        end
    end)
end

-- ============================================================================
-- 2. 战场态势全景感知 (Battlefield State Perception)
-- ============================================================================
function AI.AnalyzeBattlefield()
    local state = {
        -- 敌方信息 (0..9)
        enemies = {},
        enemy_count = 0,
        lowest_enemy_pos = -1,
        lowest_enemy_hp = 999999999,
        lowest_enemy_hp_ratio = 1.0,
        highest_enemy_pos = -1,
        highest_enemy_hp = -1,
        catchable_pos = -1,
        
        -- 友方信息 (10..19)
        allies = {},
        ally_count = 0,
        dead_allies = {},
        dead_player_pos = -1,
        dead_player_name = "",
        dead_pet_pos = -1,
        dead_pet_name = "",
        lowest_ally_pos = -1,
        lowest_ally_hp_ratio = 1.0,
        my_pos = -1,
        my_name = "Player",
        my_level = 0,
        my_hp = 0,
        my_hp_max = 1,
        my_hp_ratio = 1.0,
        my_mp = 0,
        my_mp_max = 1,
        my_sp = 0,
        my_att = 0,
        my_def = 0,
        my_matt = 0,
        my_mdef = 0,
        pet_pos = -1,
        pet_name = "Pet",
        pet_level = 0,
        pet_hp = 0,
        pet_hp_max = 1,
        pet_hp_ratio = 1.0,
        pet_mp = 0,
        pet_mp_max = 1,
        pet_sp = 0,
    }

    state.my_pos = game:GetMyPos()
    state.pet_pos = game:GetMyPetPos()

    -- 扫描主角自身状态与属性
    local myFighter = game:GetFighter(state.my_pos)
    if myFighter ~= nil and myFighter.IsDead == 0 then
        state.my_hp = myFighter.HP
        state.my_hp_max = math.max(1, myFighter.HPMax)
        state.my_hp_ratio = state.my_hp / state.my_hp_max
        state.my_sp = myFighter.SP
    end
    state.my_name = game:GetFighterName(state.my_pos) or "Player"
    state.my_level = game:GetFighterLevel(state.my_pos) or 0
    state.my_mp = game:GetMp() or 0
    state.my_mp_max = math.max(1, game:GetMpMax() or 1)

    pcall(function()
        local player = game:GetGamePlayer()
        if player ~= nil then
            if player.Grade and player.Grade > 0 then state.my_level = player.Grade end
            local sec = player:GetSecondProperty()
            if sec ~= nil then
                state.my_att = sec.PhysicsAtt or 0
                state.my_def = sec.PhysicsDef or 0
                state.my_matt = sec.MagicAtt or 0
                state.my_mdef = sec.MagicDef or 0
            end
        end
    end)

    -- 扫描出战宠物自身状态与属性
    local petFighter = game:GetFighter(state.pet_pos)
    if petFighter ~= nil and petFighter.IsDead == 0 then
        state.pet_hp = petFighter.HP
        state.pet_hp_max = math.max(1, petFighter.HPMax)
        state.pet_hp_ratio = state.pet_hp / state.pet_hp_max
        state.pet_sp = petFighter.SP
    end
    state.pet_name = game:GetFighterName(state.pet_pos) or "Pet"
    state.pet_level = game:GetFighterLevel(state.pet_pos) or 0
    state.pet_mp = game:GetPetMp() or 0
    state.pet_mp_max = math.max(1, game:GetPetMpMax() or 1)

    -- 扫描敌方 (位置 0 到 9)
    for pos = 0, 9 do
        local f = game:GetFighter(pos)
        if f ~= nil and f.IsDead == 0 and f.HP > 0 then
            state.enemy_count = state.enemy_count + 1
            local hp = f.HP
            local hpMax = math.max(1, f.HPMax)
            local ratio = hp / hpMax
            local lvl = game:GetFighterLevel(pos)
            local name = game:GetFighterName(pos) or "Enemy"
            local fType = f.Type or 0
            local isCatch = game:IsFighterCanBeCatch(pos)

            local enemyInfo = {
                pos = pos,
                hp = hp,
                hp_max = hpMax,
                hp_ratio = ratio,
                sp = f.SP,
                level = lvl,
                name = name,
                type = fType,
                catchable = isCatch,
                is_controller = false,
            }

            -- 识别具有封印/控制/法术威胁的怪物 (如 术士/元素/魔/妖/Boss)
            if name ~= nil and (string.find(name, "术") or string.find(name, "法") or string.find(name, "魔") or string.find(name, "妖") or string.find(name, "巫") or string.find(name, "仙") or string.find(name, "Boss") or string.find(name, "BOSS")) then
                enemyInfo.is_controller = true
            end
            table.insert(state.enemies, enemyInfo)

            -- 最低血量敌方
            if hp < state.lowest_enemy_hp then
                state.lowest_enemy_hp = hp
                state.lowest_enemy_hp_ratio = ratio
                state.lowest_enemy_pos = pos
            end

            -- 最高血量敌方
            if hp > state.highest_enemy_hp then
                state.highest_enemy_hp = hp
                state.highest_enemy_pos = pos
            end

            -- 稀有宠物/宝宝检测保护
            if isCatch then
                state.catchable_pos = pos
            end
        end
    end

    -- 按当前血量从小到大排序敌方列表，为防溢出集火做铺垫
    table.sort(state.enemies, function(a, b)
        return a.hp < b.hp
    end)

    -- 扫描友方 (10..19: 15..19为玩家，10..14为宠物)
    for pos = 10, 19 do
        local f = game:GetFighter(pos)
        if f ~= nil then
            if f.IsDead ~= 0 or f.HP <= 0 then
                local dName = game:GetFighterName(pos) or "DeadAlly"
                table.insert(state.dead_allies, {
                    pos = pos,
                    is_player = (pos >= 15),
                    name = dName,
                    level = game:GetFighterLevel(pos) or 0
                })
                if pos >= 15 and state.dead_player_pos < 0 then
                    state.dead_player_pos = pos
                    state.dead_player_name = dName
                elseif pos < 15 and state.dead_pet_pos < 0 then
                    state.dead_pet_pos = pos
                    state.dead_pet_name = dName
                end
            else
                state.ally_count = state.ally_count + 1
                local hp = f.HP
                local hpMax = math.max(1, f.HPMax)
                local ratio = hp / hpMax
                if ratio < state.lowest_ally_hp_ratio then
                    state.lowest_ally_hp_ratio = ratio
                    state.lowest_ally_pos = pos
                end
                table.insert(state.allies, {
                    pos = pos,
                    hp = hp,
                    hp_max = hpMax,
                    hp_ratio = ratio,
                    sp = f.SP,
                    level = game:GetFighterLevel(pos),
                    name = game:GetFighterName(pos) or "Ally"
                })
            end
        end
    end

    return state
end

-- ============================================================================
-- 3. 战斗控制状态感知层 (Control State Perception: Silence & Seal)
-- ============================================================================

-- 检测角色自身是否处于【封魔】（Silence Magic）阻断状态
-- 封魔底层机制: 严禁一切魔法 (MagicLib, type == 1，如群疗305、烈焰爆发1504)
function AI.IsSilenced(isPet)
    if not isPet then
        local mp = game:GetMp() or 0
        -- 医仙小号核心检测 305 群体治疗术 或 304 强愈术
        if mp >= 60 and (game:HasMagic(305, 1) or game:HasMagic(304, 1)) then
            local testMid = game:HasMagic(305, 1) and 305 or 304
            local canConsume = game:IsSatisfyMagicConsume(testMid, 1)
            if not canConsume then
                return true -- 蓝量充足且掌握法术，但底层拒绝消耗，确认为身受封魔
            end
        end
    else
        local petMp = game:GetPetMp() or 0
        -- 宠物布老虎核心检测 1504 烈焰爆发 或 1503 烈焰
        if petMp >= 30 and (game:HasFightPetHasAbility(1504, 1) or game:HasFightPetHasAbility(1503, 1)) then
            local testPid = game:HasFightPetHasAbility(1504, 1) and 1504 or 1503
            local canConsume = game:IsSatisfyFightPetMagicConsume(testPid, 1)
            if not canConsume then
                return true -- 宠物蓝量充足且掌握法术，但底层拒绝消耗，确认为身受封魔
            end
        end
    end
    return false
end

-- 检测角色自身是否处于【封技】（Seal Skill）阻断状态
-- 封技底层机制: 严禁一切主动物理技能 (SkillLib, type == 0，如扫射803、连珠箭310)
function AI.IsSkillSealed(isPet)
    if isPet then
        return false -- 宠物输出全为魔法，不受封技限制
    end
    local mp = game:GetMp() or 0
    -- 猎人核心检测 803 扫射 或 310 连珠箭 或 104 强力攻击
    local testSid = nil
    if game:HasSkill(803, 1) then testSid = 803
    elseif game:HasSkill(310, 1) then testSid = 310
    elseif game:HasSkill(104, 1) then testSid = 104 end

    if testSid ~= nil and mp >= 60 then
        local canConsume = game:IsSatisfySkillConsume(testSid, 1)
        if not canConsume then
            return true -- 蓝量充足且掌握物理技能，但底层拒绝消耗，确认为身受封技
        end
    end
    return false
end

-- ============================================================================
-- 4. 动态能力自省与技能评估 (Capability Introspection & Evaluation)
-- ============================================================================
function AI.EvaluateSkill(skillInfo, isPet)
    if skillInfo == nil or skillInfo.id == nil or skillInfo.id <= 0 then
        return nil
    end

    local id = skillInfo.id
    local level = skillInfo.level or 1
    local isMagic = (skillInfo.type == 1)

    local eval = {
        id = id,
        level = level,
        isMagic = isMagic,
        isValid = false,
        isAvailable = false,
        isAOE = false,
        isSingle = false,
        isCure = false,
        isBuff = false,
        spCost = 1,
        priority = 10,
        estDamage = 200,
        name = "Skill_" .. tostring(id),
        cfg = nil,
    }

    -- 结合知名物理技能与法术特性字典 (严格按 isMagic 隔离，彻底避免弓手连珠箭与医仙心灵震撼同ID重叠)
    local known = nil
    if isMagic then
        known = KNOWN_MAGICS[id]
    else
        known = KNOWN_PHYSICAL_SKILLS[id]
    end

    if known ~= nil then
        if known.Name then eval.name = known.Name end
        if known.IsAOE then eval.isAOE = true end
        if known.IsSingle then eval.isSingle = true end
        if known.IsCure then eval.isCure = true end
        if known.IsBuff then eval.isBuff = true end
        if known.Priority then eval.priority = known.Priority end
        if known.BaseDmg then eval.estDamage = known.BaseDmg + (level * 25) end

        -- B组实验分支: 当开启队长连珠箭测试时，伏地魔1 (Pos 17) 的连珠箭 (310) 优先级提至 105 (超越扫射 100)
        if AI.Config.ExperimentRapidShotLeader and not isPet and id == 310 then
            local myPos = game and game:GetMyPos() or -1
            if myPos == 17 then
                eval.priority = 105
            end
        end
    end

    -- 掌握情况检查
    if isPet then
        if not game:HasFightPetHasAbility(id, level) then
            return nil
        end
        eval.isValid = true
        eval.isAvailable = not game:IsFightPetAbilityInCD(id)
    else
        if not isMagic then
            if not game:HasSkill(id, level) then
                return nil
            end
            eval.isValid = true
            eval.isAvailable = not game:IsSkillInCD(id)
        else
            if not game:HasMagic(id, level) then
                return nil
            end
            eval.isValid = true
            eval.isAvailable = not game:IsMagicInCD(id)
        end
    end

    -- 解析静态配置
    local cfg = nil
    if not isMagic then
        cfg = game:ParseSpecifySkill(id, level)
    else
        cfg = game:ParseSpecifyMagic(id, level)
    end
    eval.cfg = cfg

    if cfg ~= nil then
        -- 严格过滤被动技能 (SkillLib 中 Type == 6 为被动技能，绝不可主动施放!)
        if not isMagic and cfg.Type == 6 then
            return nil
        end

        if not isMagic then
            eval.spCost = cfg.SP or 1
        else
            eval.spCost = cfg.SP or 0
        end
        if cfg.Name and cfg.Name ~= "" then
            eval.name = cfg.Name
        end

        -- 标签识别
        if not isMagic then
            if cfg.Type == 3 then
                eval.isCure = true
            elseif cfg.Type == 4 then
                eval.isBuff = true
            elseif cfg.Type == 1 or cfg.Type == 2 or cfg.Type == 5 then
                if cfg.Range and cfg.Range > 0 then
                    eval.isAOE = true
                    eval.isSingle = false
                else
                    eval.isSingle = true
                    eval.isAOE = false
                end
            elseif cfg.Range and cfg.Range > 0 then
                eval.isAOE = true
                eval.isSingle = false
            else
                eval.isSingle = true
                eval.isAOE = false
            end
        else
            if cfg.Type == 2 then
                eval.isCure = true
            elseif cfg.Type == 3 then
                eval.isBuff = true
            elseif cfg.Type == 1 or cfg.Type == 4 then
                if cfg.Range and cfg.Range > 0 then
                    eval.isAOE = true
                    eval.isSingle = false
                else
                    eval.isSingle = true
                    eval.isAOE = false
                end
            elseif cfg.Range and cfg.Range > 0 then
                eval.isAOE = true
                eval.isSingle = false
            else
                eval.isSingle = true
                eval.isAOE = false
            end
        end

        -- 若在已知技能字典中有显式配置，则优先应用已知配置（如特别指定优先级、AOE或单体属性）
        if known ~= nil then
            if known.IsAOE ~= nil then eval.isAOE = known.IsAOE end
            if known.IsSingle ~= nil then eval.isSingle = known.IsSingle end
            if known.Priority ~= nil then eval.priority = known.Priority end
        end
    else
        -- 若非 SkillLib/MagicLib 静态项 (例如宠物专属能力)
        if known ~= nil then
            if known.SPCost then eval.spCost = known.SPCost end
            if known.IsMagic ~= nil then
                eval.isMagic = known.IsMagic
                isMagic = eval.isMagic
            end
        else
            eval.isSingle = true
        end
    end

    -- 未在知名表中的技能按等级和SP计算优先级
    if known == nil then
        eval.priority = level * 5 + (eval.spCost * 10)
        if eval.isAOE then
            eval.estDamage = 160 + (level * 20)
        else
            eval.estDamage = 260 + (level * 30)
        end
    end

    return eval
end

-- 玩家技能全自动自省扫描 (换号0修改自适应)
function AI.IntrospectPlayerSkills(fighter)
    local availableSkills = {}
    local cheat = game:GetCheatScript()
    local fightCfgIdx = cheat:GetFightConfigIndex()

    -- 优先检查 F12 是否专门配置了技能
    for slot = 0, 3 do
        local info = cheat:GetPlayerSkillMagicInfo(fightCfgIdx, slot)
        if info and info.id > 0 then
            local eval = AI.EvaluateSkill(info, false)
            if eval and eval.isValid then
                table.insert(availableSkills, eval)
            end
        end
    end

    -- 若内挂未配置，则自省探测全部掌握技能库
    if #availableSkills == 0 then
        -- 扫描物理技能
        for _, sid in ipairs(ALL_PLAYER_SKILL_IDS) do
            if game:HasSkill(sid, 1) then
                local maxLv = 1
                for lv = 20, 1, -1 do
                    if game:HasSkill(sid, lv) then
                        maxLv = lv
                        break
                    end
                end
                local eval = AI.EvaluateSkill({ id = sid, level = maxLv, type = 0 }, false)
                if eval and eval.isValid then
                    table.insert(availableSkills, eval)
                end
            end
        end

        -- 检测当前角色是否为专职物理输出职业 (如猎人803扫射/310连珠箭、战士606怒气斩/209突击、刺客903刺杀等)
        local isDedicatedPhysicalDps = game:HasSkill(803, 1) or game:HasSkill(310, 1) or game:HasSkill(606, 1) or game:HasSkill(903, 1) or game:HasSkill(209, 1)

        -- 物理输出职业严格禁止扫描或获取任何魔法技能 (彻底屏蔽101新手飞弹等一切法术)
        -- 非纯物理职业 (医仙/学者/术士/元素使等) 均正常自省掌握的魔法技能库
        if not isDedicatedPhysicalDps then
            -- 仅非物理系纯法系/医疗职业(医仙/学者/术士/元素使)才进行魔法库自省
            for _, mid in ipairs(ALL_PLAYER_MAGIC_IDS) do
                if game:HasMagic(mid, 1) then
                    local maxLv = 1
                    for lv = 20, 1, -1 do
                        if game:HasMagic(mid, lv) then
                            maxLv = lv
                            break
                        end
                    end
                    local eval = AI.EvaluateSkill({ id = mid, level = maxLv, type = 1 }, false)
                    if eval and eval.isValid then
                        table.insert(availableSkills, eval)
                    end
                end
            end
        end
    else
        -- 若当前角色是明确的物理主力输出职业(如猎人/刺客/战士，掌握803扫射/310连珠箭/606怒气斩/903刺杀)，清洗剔除误配的魔法技能
        local isDedicatedPhysicalDps = game:HasSkill(803, 1) or game:HasSkill(310, 1) or game:HasSkill(606, 1) or game:HasSkill(903, 1) or game:HasSkill(209, 1)
        if isDedicatedPhysicalDps then
            local filtered = {}
            for _, s in ipairs(availableSkills) do
                if not s.isMagic then
                    table.insert(filtered, s)
                end
            end
            availableSkills = filtered
        end
    end

    -- 控制状态感知: 检测主角是否身受【封技】或【封魔】
    local myPos = game:GetMyPos()
    local isSealed = AI.IsSkillSealed(false)
    local isSilenced = AI.IsSilenced(false)
    if isSealed then
        Blackboard.ReportFighterStatus(myPos, "SEALED")
        if AI.Config.DebugLog then
            Info(string.format("[AI自省-主角] 主角(位号:%d) 当前身受【封技】控制状态，物理主动技能全面封禁！将无缝切换为5966物攻弓箭普攻输出！", myPos))
            Info(string.format("[BATTLE_EVENT][STATE] role=Player, pos=%d, state=Sealed, effect=SealSkill, duration=Active", myPos))
        end
    end
    if isSilenced then
        Blackboard.ReportFighterStatus(myPos, "SILENCED")
        if AI.Config.DebugLog then
            Info(string.format("[AI自省-主角] 主角(位号:%d) 当前身受【封魔】控制状态，法术技能全面禁用！", myPos))
            Info(string.format("[BATTLE_EVENT][STATE] role=Player, pos=%d, state=Silenced, effect=SilenceMagic, duration=Active", myPos))
        end
    end

    -- 过滤当前 CD、SP与蓝量满足的即时可用项 (受控技能直接剔除)
    local readySkills = {}
    for _, eval in ipairs(availableSkills) do
        local isBlocked = false
        if not eval.isMagic and isSealed then
            isBlocked = true -- 物理技能被封技阻断
        elseif eval.isMagic and isSilenced then
            isBlocked = true -- 魔法法术被封魔阻断
        end

        if not isBlocked then
            local canConsume = false
            if not eval.isMagic then
                canConsume = game:IsSatisfySkillConsume(eval.id, eval.level)
            else
                canConsume = game:IsSatisfyMagicConsume(eval.id, eval.level)
            end

            local spCost = eval.isMagic and 0 or (eval.spCost or 0)
            if eval.isAvailable and fighter.SP >= spCost and canConsume then
                table.insert(readySkills, eval)
            end
        end
    end

    if AI.Config.DebugLog and #readySkills > 0 then
        local names = {}
        for _, s in ipairs(readySkills) do
            table.insert(names, string.format("%s[Lv%d,SP%d,Prio%d]", s.name, s.level, s.spCost, s.priority))
        end
        Info(string.format("[AI自省-主角] 可用技能: %s", table.concat(names, ", ")))
    end

    return readySkills
end

-- 宠物技能全自动自省扫描
function AI.IntrospectPetSkills(fighter)
    local availableSkills = {}
    local cheat = game:GetCheatScript()
    local fightCfgIdx = cheat:GetFightConfigIndex()

    for slot = 0, 3 do
        local info = cheat:GetPetSkillMagicInfo(fightCfgIdx, slot)
        if info and info.id > 0 then
            local eval = AI.EvaluateSkill(info, true)
            if eval and eval.isValid then
                table.insert(availableSkills, eval)
            end
        end
    end

    if #availableSkills == 0 then
        for _, aid in ipairs(ALL_PET_ABILITY_IDS) do
            if game:HasFightPetHasAbility(aid, 1) then
                local maxLv = 1
                for lv = 20, 1, -1 do
                    if game:HasFightPetHasAbility(aid, lv) then
                        maxLv = lv
                        break
                    end
                end
                -- 大多数宠物主攻能力(如 1501..1504)为魔法，先试魔法
                local eval = AI.EvaluateSkill({ id = aid, level = maxLv, type = 1 }, true)
                if not eval or not eval.isValid then
                    eval = AI.EvaluateSkill({ id = aid, level = maxLv, type = 0 }, true)
                end
                if eval and eval.isValid then
                    table.insert(availableSkills, eval)
                end
            end
        end
    end

    -- 控制状态感知: 检测宠物是否身受【封魔】
    local myPetPos = game:GetMyPetPos()
    local isPetSilenced = AI.IsSilenced(true)
    if isPetSilenced then
        Blackboard.ReportFighterStatus(myPetPos, "SILENCED")
        if AI.Config.DebugLog then
            Info(string.format("[AI自省-宠物] 宠物(位号:%d) 当前身受【封魔】控制状态，火系法术技能全面哑火！坚决执行战术待命，杜绝普攻破戒！", myPetPos))
            Info(string.format("[BATTLE_EVENT][STATE] role=Pet, pos=%d, state=Silenced, effect=SilenceMagic, duration=Active", myPetPos))
        end
    end

    local readySkills = {}
    for _, eval in ipairs(availableSkills) do
        local isBlocked = false
        if eval.isMagic and isPetSilenced then
            isBlocked = true -- 宠物火系群攻被封魔阻断
        end

        if not isBlocked then
            local canConsume = false
            if not eval.isMagic then
                canConsume = game:IsSatisfyFightPetSkillConsume(eval.id, eval.level)
            else
                canConsume = game:IsSatisfyFightPetMagicConsume(eval.id, eval.level)
            end

            local spCost = eval.isMagic and 0 or (eval.spCost or 0)
            if eval.isAvailable and fighter.SP >= spCost and canConsume then
                table.insert(readySkills, eval)
            end
        end
    end

    if AI.Config.DebugLog and #readySkills > 0 then
        local names = {}
        for _, s in ipairs(readySkills) do
            table.insert(names, string.format("%s[Lv%d,SP%d,Prio%d]", s.name, s.level, s.spCost, s.priority))
        end
        Info(string.format("[AI自省-宠物] 可用能力: %s", table.concat(names, ", ")))
    end

    return readySkills
end

-- ============================================================================
-- 4. 施法执行封装 (Execution Wrappers)
-- ============================================================================
function AI.ExecuteCast(evalSkill, targetPos, isPet, rationale)
    local id = evalSkill.id
    local level = evalSkill.level
    local isMagic = evalSkill.isMagic
    local rat = rationale or "AI战术施法"
    local myPos = isPet and game:GetMyPetPos() or game:GetMyPos()

    if AI.Config.DebugLog then
        Info(string.format("[AI施法-%s] 目标位号:%d, 释放%s: %s (ID:%d, Lv:%d) | 原因: %s",
            isPet and "宠物" or "主角", targetPos, isMagic and "法术" or "技能", evalSkill.name, id, level, rat))
        Info(string.format("[BATTLE_EVENT][ACTION] role=%s, pos=%d, act=Cast, type=%s, id=%d, name=%s, lv=%d, target=%d, reason=%s",
            isPet and "Pet" or "Player", myPos, isMagic and "Magic" or "Skill", id, evalSkill.name, level, targetPos, rat))
    end

    if isPet then
        if not isMagic then
            game:CastPetSkillToFighter(targetPos, id, level)
        else
            game:CastPetMagicToFighter(targetPos, id, level)
        end
    else
        if not isMagic then
            game:CastSkillToFighter(targetPos, id, level)
        else
            game:CastMagicToFighter(targetPos, id, level)
        end
    end
    return true
end

function AI.ExecuteNormalAttack(targetPos, isPet, rationale)
    local myPos = isPet and game:GetMyPetPos() or game:GetMyPos()
    local rat = rationale or "普通攻击收割"

    -- 绝对防御铁律: 宠物严禁执行普通攻击!
    if isPet then
        Warn(string.format("[BATTLE_EVENT][ANOMALY] 拦截宠物普攻异常! 位号:%d 试图普通攻击目标 %d, 已被AI安全护盾就地拦截并转为战术待命!", myPos, targetPos))
        return true
    end

    if AI.Config.DebugLog then
        Info(string.format("[AI普攻-主角] 目标位号:%d, 执行普通攻击 | 原因: %s", targetPos, rat))
        Info(string.format("[BATTLE_EVENT][ACTION] role=Player, pos=%d, act=NormalAttack, type=None, id=0, name=普通攻击, lv=1, target=%d, reason=%s",
            myPos, targetPos, rat))
    end

    game:NormalAttack(targetPos)
    return true
end

-- ============================================================================
-- 5. 核心多智能体决策树 (Multi-Agent Team Combat Decision Tree)
-- ============================================================================
function AI.DecideAction(fighter, isPet)
    local state = AI.AnalyzeBattlefield()
    if state.enemy_count == 0 then
        return false
    end

    -- 输出结构化遥测快照 (敌情全景 + 我方快照)
    if AI.Config.DebugLog and state.enemy_count > 0 then
        local enemyItems = {}
        for _, em in ipairs(state.enemies) do
            table.insert(enemyItems, string.format("pos:%d,name:%s,type:%d,lvl:%d,hp:%d/%d,sp:%d,catch:%s",
                em.pos, em.name, em.type, em.level, em.hp, em.hp_max, em.sp, tostring(em.catchable)))
        end
        Info(string.format("[BATTLE_EVENT][OPPONENT] count=%d, enemies=[%s]", state.enemy_count, table.concat(enemyItems, "; ")))

        local allyItems = {}
        for _, al in ipairs(state.allies) do
            table.insert(allyItems, string.format("pos:%d,name:%s,lvl:%d,hp:%d/%d,sp:%d",
                al.pos, al.name, al.level, al.hp, al.hp_max, al.sp))
        end
        Info(string.format("[BATTLE_EVENT][TEAM_LINEUP] count=%d, allies=[%s]", state.ally_count, table.concat(allyItems, "; ")))

        Info(string.format("[BATTLE_EVENT][ALLY_SNAPSHOT] myPos=%d, name=%s, lvl=%d, hp=%d/%d, mp=%d/%d, sp=%d, pAtt=%d, pDef=%d, mAtt=%d, mDef=%d, petPos=%d, petName=%s, petLvl=%d, petHp=%d/%d, petMp=%d/%d, petSp=%d",
            state.my_pos, state.my_name, state.my_level, state.my_hp, state.my_hp_max, state.my_mp, state.my_mp_max, state.my_sp,
            state.my_att, state.my_def, state.my_matt, state.my_mdef,
            state.pet_pos, state.pet_name, state.pet_level, state.pet_hp, state.pet_hp_max, state.pet_mp, state.pet_mp_max, state.pet_sp))
    end

    local myPos = isPet and state.pet_pos or state.my_pos

    -- 1. 扫描当前可用技能全集
    local readySkills = {}
    if not isPet then
        readySkills = AI.IntrospectPlayerSkills(fighter)
    else
        readySkills = AI.IntrospectPetSkills(fighter)
    end

    -- 分类归纳技能
    local aoeSkills = {}
    local singleSkills = {}
    local cureSkills = {}
    local buffSkills = {}

    for _, s in ipairs(readySkills) do
        if s.isCure then
            table.insert(cureSkills, s)
        elseif s.isBuff then
            table.insert(buffSkills, s)
        else
            if s.isAOE then
                table.insert(aoeSkills, s)
            end
            if s.isSingle then
                table.insert(singleSkills, s)
            end
        end
    end

    -- 技能按优先级从高到低排序 (强力核心技能优先出手)
    local sortByPriority = function(a, b)
        if (a.priority or 0) ~= (b.priority or 0) then
            return (a.priority or 0) > (b.priority or 0)
        end
        return a.level > b.level
    end
    table.sort(aoeSkills, sortByPriority)
    table.sort(singleSkills, sortByPriority)
    table.sort(cureSkills, sortByPriority)
    table.sort(buffSkills, sortByPriority)

    -- 2. 读取跨进程分布式战术看板
    local blackboard = Blackboard.ReadState()

    -- ------------------------------------------------------------------------
    -- 核心决策 0: 全员紧急停火与绝对复活协议 (Emergency Ceasefire & Absolute Revival Protocol)
    -- 铁律: 一旦检测到有队友玩家倒地 (pos: 15..19 且 HP <= 0)，全队除施救医仙外，
    -- 猎人大号与所有宠物立即全面停火，严禁任何攻击，转为战术待命保留怪物维持战局，
    -- 绝不提前清怪结束战斗，直至医仙成功施放【306 复活术】将倒地队友起死回生！
    -- ------------------------------------------------------------------------
    if state.dead_player_pos >= 0 then
        local deadTargetPos = state.dead_player_pos
        local deadTargetName = state.dead_player_name

        -- 动态扫描场上是否还有存活的医仙具备复活能力 (扫描 15..19 存活玩家)
        local hasLivingDoctor = false
        for checkDocPos = 15, 19 do
            local docFighter = game:GetFighter(checkDocPos)
            if docFighter ~= nil and docFighter.IsDead == 0 and docFighter.HP > 0 then
                if checkDocPos == myPos then
                    if game:HasMagic(306, 1) then
                        hasLivingDoctor = true
                        break
                    end
                else
                    -- 其他队友：只要不是纯猎人主力(拥有扫射)，即视作可能拥有医仙救命能力
                    hasLivingDoctor = true
                    break
                end
            end
        end

        -- 1. 出战宠物: 坚决停火待命，杜绝全屏火雨秒怪提前结算
        if isPet then
            if hasLivingDoctor then
                if AI.Config.DebugLog then
                    Info(string.format("[紧急停火协议] 队友玩家(位号:%d, 角色:%s)阵亡，宠物(位号:%d)坚决停火待命，保留怪物等待医仙复活!",
                        deadTargetPos, deadTargetName, myPos))
                    Info(string.format("[BATTLE_EVENT][ACTION] role=Pet, pos=%d, act=Standby, type=None, id=0, name=待命, lv=0, target=%d, reason=队友阵亡全员停火待命等待医仙复活",
                        myPos, deadTargetPos))
                end
                return true
            end
        else
            -- 2. 玩家主角:
            local reviveSpellId = 306
            local has306 = false
            local reviveLv = 1
            for lv = 20, 1, -1 do
                if game:HasMagic(reviveSpellId, lv) then
                    has306 = true
                    reviveLv = lv
                    break
                end
            end

            if has306 then
                -- 施救医仙分支:
                local mySp = state.my_sp or 0
                if mySp >= 1 and not game:IsMagicInCD(reviveSpellId) and game:IsSatisfyMagicConsume(reviveSpellId, reviveLv) then
                    if AI.Config.DebugLog then
                        Info(string.format("[紧急停火抢救] 队友玩家(位号:%d, 角色:%s)阵亡，医仙(位号:%d, SP:%d)瞬间施放【306 复活术(Lv%d)】抢救起死回生!",
                            deadTargetPos, deadTargetName, myPos, mySp, reviveLv))
                        Info(string.format("[BATTLE_EVENT][ACTION] role=Player, pos=%d, act=Cast, type=Magic, id=306, name=复活术, lv=%d, target=%d, reason=紧急复活阵亡队友起死回生",
                            myPos, reviveLv, deadTargetPos))
                    end
                    game:CastMagicToFighter(deadTargetPos, reviveSpellId, reviveLv)
                    return true
                elseif mySp < 1 then
                    -- SP 尚不足 1 点 (蓄力读秒中，每 3.9 秒 1 点 SP): 严格待命蓄力，杜绝普攻与无效刷血！
                    if AI.Config.DebugLog then
                        Info(string.format("[紧急停火抢救] 队友玩家(位号:%d, 角色:%s)阵亡，医仙(位号:%d)当前 SP=0，坚决待命蓄力等待满SP复活!",
                            deadTargetPos, deadTargetName, myPos))
                        Info(string.format("[BATTLE_EVENT][ACTION] role=Player, pos=%d, act=Standby, type=None, id=0, name=待命, lv=0, target=%d, reason=等待SP满1复活阵亡队友",
                            myPos, deadTargetPos))
                    end
                    return true
                elseif game:IsMagicInCD(reviveSpellId) then
                    -- 复活术在 CD 中: 待命等待冷却
                    if AI.Config.DebugLog then
                        Info(string.format("[紧急停火抢救] 复活术冷却中，医仙(位号:%d)战术待命等待CD复活!", myPos))
                        Info(string.format("[BATTLE_EVENT][ACTION] role=Player, pos=%d, act=Standby, type=None, id=0, name=待命, lv=0, target=%d, reason=复活术CD战术待命",
                            myPos, deadTargetPos))
                    end
                    return true
                end
            else
                -- 猎人大号分支 (伏地魔1/2/3):
                if hasLivingDoctor then
                    if AI.Config.DebugLog then
                        Info(string.format("[紧急停火协议] 队友玩家(位号:%d, 角色:%s)阵亡，大号猎人(位号:%d)严禁攻击，全面停火待命，保留怪物等待医仙复活!",
                            deadTargetPos, deadTargetName, myPos))
                        Info(string.format("[BATTLE_EVENT][ACTION] role=Player, pos=%d, act=Standby, type=None, id=0, name=待命, lv=0, target=%d, reason=队友阵亡猎人大号全面停火待命等待医仙复活",
                            myPos, deadTargetPos))
                    end
                    return true
                else
                    -- 极端灾难熔断: 两个医仙全部阵亡，无人能复活，猎人被迫全力输出歼敌自保
                    if AI.Config.DebugLog then
                        Warn(string.format("[AI战局告急] 医仙小号全员阵亡无法施救，大号猎人(位号:%d)全力歼灭残敌脱离战斗!", myPos))
                    end
                end
            end
        end
    end

    -- ------------------------------------------------------------------------
    -- 核心策略定制: 3大带2小 专职保姆模式
    -- 2小账号 (医仙/学者) 专职负责守护全队与自保
    -- ------------------------------------------------------------------------
    local isSmallHealer = false
    if not isPet then
        local healSpellId = 305
        local has305 = false
        local healLv = 1
        for lv = 20, 1, -1 do
            if game:HasMagic(healSpellId, lv) then
                has305 = true
                healLv = lv
                break
            end
        end

        -- 判定当前角色是否为专职保姆小号:
        -- 核心铁律: 必须掌握 305 群体治疗术，且不能是大号主力输出(无 803 扫射 / 310 连珠箭)
        if has305 then
            local hasCarrySkill = game:HasSkill(803, 1) or game:HasSkill(310, 1) -- 扫射 / 连珠箭
            if AI.Config.DedicatedGroupHealer then
                isSmallHealer = true
            elseif hasCarrySkill then
                -- 拥有大号主力群攻技能 (如 扫射/连珠箭)，明确是大号，绝不能当作保姆
                isSmallHealer = false
            else
                -- 拥有 305 且无大号主力群攻，确认为 2 小账号专职保姆
                isSmallHealer = true
            end
        end

        if isSmallHealer then
            -- 前置检测: 医仙自身是否身受【封魔】控制
            local isSilenced = AI.IsSilenced(false)
            if isSilenced then
                if AI.Config.DebugLog then
                    Info(string.format("[AI群疗协同] 医仙(位号:%d) 身受【封魔】控制无法施法，战术待命蓄力！", myPos))
                    Info(string.format("[BATTLE_EVENT][ACTION] role=Player, pos=%d, act=Standby, type=None, id=0, name=待命, lv=0, target=%d, reason=医仙受封魔控制战术待命",
                        myPos, myPos))
                end
                return true
            end

            -- 1. 小号医仙互助单体定向急救 (救自己，更救残血/被封魔的队友小号！)
            -- 扫描医仙小号 (pos: 18 与 19)
            local targetDangerPos = -1
            local minDangerRatio = 1.0
            local dangerName = ""

            for _, checkPos in ipairs({ 18, 19 }) do
                local cf = game:GetFighter(checkPos)
                if cf ~= nil and cf.IsDead == 0 and cf.HP > 0 then
                    local hpRatio = cf.HP / math.max(1, cf.HPMax)
                    -- 触发条件: 小号生命值 < 60% (残血危急)
                    if hpRatio < 0.60 and hpRatio < minDangerRatio then
                        minDangerRatio = hpRatio
                        targetDangerPos = checkPos
                        dangerName = game:GetFighterName(checkPos) or "小号"
                    end
                end
            end

            -- 若存在危急小号 (自己或被封魔残血的队友)，立即施放高额单体急救 (强愈术304/急救术313/治疗术303)，一发回血700~900+瞬间拉满！
            if targetDangerPos >= 0 then
                for _, emergencyId in ipairs({ 304, 313, 303 }) do
                    if game:HasMagic(emergencyId, 1) and not game:IsMagicInCD(emergencyId) and game:IsSatisfyMagicConsume(emergencyId, 1) then
                        local emLv = 1
                        for lv = 20, 1, -1 do if game:HasMagic(emergencyId, lv) then emLv = lv break end end
                        local isSelf = (targetDangerPos == myPos)
                        local actDesc = isSelf and "自身濒死紧急单加" or string.format("跨队友定向急救残血小号(%s,位号:%d)", dangerName, targetDangerPos)
                        if AI.Config.DebugLog then
                            Info(string.format("[AI医仙互助] 医仙(位号:%d)发现小号(%s)残血(%.1f%%)，紧急施放单体高额急救 [%d(Lv%d)] 目标位号:%d! (%s)",
                                myPos, dangerName, minDangerRatio * 100, emergencyId, emLv, targetDangerPos, actDesc))
                            Info(string.format("[BATTLE_EVENT][ACTION] role=Player, pos=%d, act=Cast, type=Magic, id=%d, name=单体急救, lv=%d, target=%d, reason=%s",
                                myPos, emergencyId, emLv, targetDangerPos, actDesc))
                        end
                        game:CastMagicToFighter(targetDangerPos, emergencyId, emLv)
                        return true
                    end
                end
            end

            -- 1.5 医仙开局/首要【隐匿自保】(Invisibility Defense)
            -- 核心铁律: 优先施放隐匿规避怪物仇恨，杜绝被怪集火打残或暴毙!
            -- 仅消耗 1 点 SP，隐匿成功后怪物 100% 无法选中该小号，并在后续回合安全回满 SP！
            if game:HasMagic(212, 1) and not game:IsMagicInCD(212) and game:IsSatisfyMagicConsume(212, 1) then
                local stealthLv = 1
                for lv = 20, 1, -1 do if game:HasMagic(212, lv) then stealthLv = lv break end end
                if AI.Config.DebugLog then
                    Info(string.format("[AI隐匿自保] 医仙小号(位号:%d) 施放【隐匿 212(Lv%d)】规避怪物集火，隐身自保!", myPos, stealthLv))
                    Info(string.format("[BATTLE_EVENT][ACTION] role=Player, pos=%d, act=Cast, type=Magic, id=212, name=隐匿, lv=%d, target=%d, reason=小号隐匿规避集火",
                        myPos, stealthLv, myPos))
                end
                game:CastMagicToFighter(myPos, 212, stealthLv)
                return true
            end

            -- 2. 全队血量检测 (< 80% 触发群疗；>= 80% 彻底待命存 SP)
            if state.lowest_ally_hp_ratio >= 0.80 then
                -- 【用户核心策略】：全队血量健康时，两小号彻底躺平待命，死死保留满额SP！
                if AI.Config.DebugLog then
                    Info(string.format("[AI极致待命] 全队健康(%.1f%% >= 80%%)，小号医仙(位号:%d)原地待命蓄力储备满额SP!",
                        state.lowest_ally_hp_ratio * 100, myPos))
                    Info(string.format("[BATTLE_EVENT][ACTION] role=Player, pos=%d, act=Standby, type=None, id=0, name=待命, lv=0, target=%d, reason=全队健康极致待命储备SP",
                        myPos, myPos))
                end
                return true
            else
                -- 3. 全队掉血低于 80%，进入群疗判定
                -- 主副医严格分工 + 封魔智能接管：
                -- 检查另一位小号是否被封魔或残血
                local peerPos = (myPos == 18 and 19 or 18)
                local peerFighter = game:GetFighter(peerPos)
                local isPeerSilenced = false
                if peerFighter ~= nil and (peerFighter.IsDead ~= 0 or peerFighter.HP <= 0) then
                    isPeerSilenced = true
                end

                -- 主医判定: 位号<=18 (自由四号) 为默认主医；若四号阵亡或被封，五号无缝接管成为主医！
                local isPrimaryDoctor = (myPos <= 18) or isPeerSilenced
                local isCritical = (state.lowest_ally_hp_ratio < 0.45) -- 极端重创双医齐开

                local canConsume = game:IsSatisfyMagicConsume(305, healLv)
                local inCD = game:IsMagicInCD(305)

                if isPrimaryDoctor or isCritical then
                    if not inCD and canConsume then
                        local roleDesc = isPrimaryDoctor and (isPeerSilenced and "队友受制接管主医群疗" or "主医群疗抬血") or "全队危急双医紧急群疗"
                        if AI.Config.DebugLog then
                            Info(string.format("[AI群疗抬血] 队伍血量低于80%%(最低:%.1f%%)，医仙(位号:%d)施放【群体治疗术(Lv%d)】! (%s)",
                                state.lowest_ally_hp_ratio * 100, myPos, healLv, roleDesc))
                            Info(string.format("[BATTLE_EVENT][ACTION] role=Player, pos=%d, act=Cast, type=Magic, id=305, name=群体治疗术, lv=%d, target=%d, reason=%s",
                                myPos, healLv, myPos, roleDesc))
                        end
                        game:CastMagicToFighter(myPos, 305, healLv)
                        return true
                    end
                else
                    -- 副医(自由五号)：主医健在且队伍未跌破45%，副医继续待命蓄力，保留SP防猝死
                    if AI.Config.DebugLog then
                        Info(string.format("[AI副医护航] 队伍掉血(最低:%.1f%%)，由主医负责群疗，副医(位号:%d)坚决待命蓄力保留SP防猝死!",
                            state.lowest_ally_hp_ratio * 100, myPos))
                        Info(string.format("[BATTLE_EVENT][ACTION] role=Player, pos=%d, act=Standby, type=None, id=0, name=待命, lv=0, target=%d, reason=副医待命保留SP防猝死",
                            myPos, myPos))
                    end
                    return true
                end
            end
            -- 保姆小号坚决不执行普攻，默认战术待命
            return true
        end
    end

    -- ------------------------------------------------------------------------
    -- 核心决策 0.5: 小号濒死残血护航保护 (Critical Doctor Health Protection)
    -- 场景: 某个小号被打到危急残血 (血量 < 25% 甚至剩个位数血)
    -- 机制: 若场上有存活未封魔的医仙具备单加能力，且场上怪已被大幅压制(<=2只)，
    -- 主力输出暂缓秒怪(待命1回合)，给医仙腾出单加抬血窗口，把小号奶满再结束战斗！
    -- ------------------------------------------------------------------------
    local criticalSmallFighterPos = -1
    for _, spPos in ipairs({ 18, 19 }) do
        local sf = game:GetFighter(spPos)
        if sf ~= nil and sf.IsDead == 0 and sf.HP > 0 then
            local ratio = sf.HP / math.max(1, sf.HPMax)
            if ratio < 0.25 then
                criticalSmallFighterPos = spPos
                break
            end
        end
    end

    if criticalSmallFighterPos >= 0 and state.enemy_count <= 2 then
        local canHealDoctor = false
        for _, docP in ipairs({ 18, 19 }) do
            local df = game:GetFighter(docP)
            if df ~= nil and df.IsDead == 0 and df.HP > 0 then
                if game.IsSatisfyMagicConsume and (game:HasMagic(304, 1) or game:HasMagic(313, 1) or game:HasMagic(305, 1)) then
                    canHealDoctor = true
                    break
                end
            end
        end
        if canHealDoctor then
            if AI.Config.DebugLog then
                Info(string.format("[AI护航控场] 小号(位号:%d)生命垂危(<25%%)，主力(位号:%d)暂缓秒怪待命1回合，等待医仙抬血!",
                    criticalSmallFighterPos, myPos))
                Info(string.format("[BATTLE_EVENT][ACTION] role=%s, pos=%d, act=Standby, type=None, id=0, name=待命, lv=0, target=%d, reason=小号垂危主力控场等待抬血",
                    isPet and "Pet" or "Player", myPos, criticalSmallFighterPos))
            end
            return true
        end
    end

    -- ------------------------------------------------------------------------
    -- 决策 1: 宝宝/稀有怪保护协议 (Pet Protection)
    -- ------------------------------------------------------------------------
    local suppressAOE = false
    if state.catchable_pos >= 0 then
        suppressAOE = true
        if AI.Config.DebugLog then
            Info(string.format("[AI协同] 发现可捕捉怪物 [位号:%d]，全面抑制群攻!", state.catchable_pos))
        end
    end

    -- ------------------------------------------------------------------------
    -- 决策 2: 动态生命救援 (Heal Coordination via Token)
    -- ------------------------------------------------------------------------
    if #cureSkills > 0 then
        local needHeal = false
        local healTarget = -1

        if state.my_hp_ratio < AI.Config.EmergencyHealRatio then
            needHeal = true
            healTarget = state.my_pos
        elseif state.lowest_ally_hp_ratio < AI.Config.TeamHealRatio and state.lowest_ally_pos >= 0 then
            needHeal = true
            healTarget = state.lowest_ally_pos
        end

        if needHeal and healTarget >= 0 then
            -- 尝试申请急救令牌，防止多个医生同时过量抢救同一个人
            if Blackboard.TryClaimHealToken(myPos) then
                local cure = cureSkills[1]
                if AI.Config.DebugLog then
                    Info(string.format("[AI协同] 认领急救令牌，对位号 %d 施放救援技能 [%s]!", healTarget, cure.name))
                end
                return AI.ExecuteCast(cure, healTarget, isPet)
            else
                if AI.Config.DebugLog then
                    Info("[AI协同] 队友已被其他医疗单位认领救助，本单位转入攻击轮次!")
                end
            end
        end
    end

    -- ------------------------------------------------------------------------
    -- 决策 3: 隐匿避险 (Aggro Drop / Invisibility)
    -- ------------------------------------------------------------------------
    if not isPet and state.my_hp_ratio < 0.40 then
        for _, b in ipairs(buffSkills) do
            if b.id == 212 then -- 隐匿
                if AI.Config.DebugLog then
                    Info("[AI协同] 游侠血量低于 40%，立即施放 [隐匿] 规避怪物仇恨与集火!")
                end
                return AI.ExecuteCast(b, state.my_pos, false)
            end
        end
    end

    -- ------------------------------------------------------------------------
    -- 决策 4: 战术集火目标选定 (Anti-Overkill & Controller-First Selection)
    -- ------------------------------------------------------------------------
    local chosenTargetPos = -1
    local chosenEnemyHp = 0
    local isTargetController = false

    -- 优先寻找尚未被队友预定击杀的控制怪 (Controller First: 集中火力先秒控制怪)
    for _, enemy in ipairs(state.enemies) do
        local alreadyReserved = blackboard.reserved_dmg[enemy.pos] or 0
        local effectiveHp = enemy.hp - alreadyReserved
        if effectiveHp > 0 and enemy.is_controller then
            chosenTargetPos = enemy.pos
            chosenEnemyHp = effectiveHp
            isTargetController = true
            break
        end
    end

    -- 若无存活控制怪，则按血量从小到大寻找有效残血目标
    if chosenTargetPos < 0 then
        for _, enemy in ipairs(state.enemies) do
            local alreadyReserved = blackboard.reserved_dmg[enemy.pos] or 0
            local effectiveHp = enemy.hp - alreadyReserved
            if effectiveHp > 0 then
                chosenTargetPos = enemy.pos
                chosenEnemyHp = effectiveHp
                break
            end
        end
    end

    -- 如果所有怪物都已经被预定击杀，则兜底瞄准血量最多的怪补充保险伤害
    if chosenTargetPos < 0 then
        chosenTargetPos = state.highest_enemy_pos >= 0 and state.highest_enemy_pos or 2
        chosenEnemyHp = state.highest_enemy_hp
    end

    -- ------------------------------------------------------------------------
    -- 决策 5: 残局控蓝与蓄力 (Finishing Resource Conservation)
    -- 核心铁律: 仅允许主角在单怪濒死时普攻收割，大号宠物严禁普攻收割!
    -- ------------------------------------------------------------------------
    if not isPet and state.enemy_count == 1 and state.lowest_enemy_hp <= AI.Config.FinishingHpThreshold and state.lowest_enemy_hp > 0 then
        if AI.Config.DebugLog then
            Info(string.format("[AI协同] 敌方濒死 (残余HP:%d)，主角普攻收割并储备SP (当前SP:%d)!", state.lowest_enemy_hp, fighter.SP or 0))
        end
        Blackboard.ReserveDamage(chosenTargetPos, 120, myPos)
        return AI.ExecuteNormalAttack(chosenTargetPos, false, "残局单怪濒死控蓝收割并储备SP")
    end

    -- ------------------------------------------------------------------------
    -- 决策 6: 群攻压制阶段 (AOE Suppression Phase)
    -- ------------------------------------------------------------------------
    if state.enemy_count >= AI.Config.AoeEnemyThreshold and not suppressAOE and #aoeSkills > 0 then
        local aoe = aoeSkills[1]
        local rat = string.format("敌方存活%d只(>=%d)，群体压制狂轰全场", state.enemy_count, AI.Config.AoeEnemyThreshold)
        if AI.Config.DebugLog then
            Info(string.format("[AI协同] %s，选用技能 [%s(Lv%d)]", rat, aoe.name, aoe.level))
        end
        -- 群攻对场上所有怪物登记预期承伤
        for _, em in ipairs(state.enemies) do
            Blackboard.ReserveDamage(em.pos, aoe.estDamage, myPos)
        end
        return AI.ExecuteCast(aoe, chosenTargetPos, isPet, rat)
    end

    -- ------------------------------------------------------------------------
    -- 决策 7: 智能点杀收割 (Single-Target Execution - No Overkill)
    -- ------------------------------------------------------------------------
    local chosenAttack = nil
    if #singleSkills > 0 then
        -- 优先施放单体高爆技能 (满级精准射击 309: 100%物攻+530附加真伤，单怪最优解)
        chosenAttack = singleSkills[1]
    elseif #aoeSkills > 0 and not suppressAOE then
        -- 若无纯单体攻击技能，从群体技能中挑选单体倍率最高者兜底 (连珠箭 100% > 扫射 40%)
        local bestSingleAoe = aoeSkills[1]
        for _, aoe in ipairs(aoeSkills) do
            if aoe.id == 310 then -- 连珠箭打单怪 100% 满额物理伤害，远优于扫射 40%
                bestSingleAoe = aoe
                break
            end
        end
        chosenAttack = bestSingleAoe
    end

    if chosenAttack ~= nil then
        local ratPrefix = isTargetController and "优先点杀控制威胁怪" or "集火有效残血目标"
        local rat = string.format("%s[位号:%d,有效HP:%d]，定点爆发快速减员", ratPrefix, chosenTargetPos, chosenEnemyHp)
        if AI.Config.DebugLog then
            Info(string.format("[AI协同] %s，释放技能 [%s(Lv%d)]!", rat, chosenAttack.name, chosenAttack.level))
        end
        Blackboard.ReserveDamage(chosenTargetPos, chosenAttack.estDamage, myPos)
        return AI.ExecuteCast(chosenAttack, chosenTargetPos, isPet, rat)
    end

    -- ------------------------------------------------------------------------
    -- 决策 8: 任何可用备选技能
    -- ------------------------------------------------------------------------
    if #readySkills > 0 then
        local fallback = readySkills[1]
        if not (suppressAOE and fallback.isAOE) then
            local rat = string.format("主攻技能不可用，选用备用技能[%s(Lv%d)]输出", fallback.name, fallback.level)
            if AI.Config.DebugLog then
                Info(string.format("[AI协同] %s 至位号 %d", rat, chosenTargetPos))
            end
            Blackboard.ReserveDamage(chosenTargetPos, fallback.estDamage, myPos)
            return AI.ExecuteCast(fallback, chosenTargetPos, isPet, rat)
        end
    end

    -- ------------------------------------------------------------------------
    -- 决策 9: 兜底动作 (绝不让保姆小号与大号宠物执行普通攻击)
    -- ------------------------------------------------------------------------
    -- 1. 保姆小号保持待命状态，绝不普攻
    if not isPet and isSmallHealer then
        if AI.Config.DebugLog then
            Info(string.format("[AI协同] 保姆小号保持待命状态(位号:%d)，杜绝普攻", myPos))
            Info(string.format("[BATTLE_EVENT][ACTION] role=Player, pos=%d, act=Standby, type=None, id=0, name=待命, lv=0, target=%d, reason=保姆小号技能冷却中待命杜绝普攻", myPos, myPos))
        end
        return true
    end

    -- 2. 宠物绝对防御: 宠物严禁执行普通攻击! 若无可用技能则战术待命蓄力
    if isPet then
        if #readySkills > 0 then
            return AI.ExecuteCast(readySkills[1], chosenTargetPos, true, "宠物兜底技能输出")
        end
        if AI.Config.DebugLog then
            Info(string.format("[AI战术待命] 宠物(位号:%d) 技能冷却、SP不足或身受封魔，坚决执行待命蓄力，绝对杜绝普攻!", myPos))
            Info(string.format("[BATTLE_EVENT][ACTION] role=Pet, pos=%d, act=Standby, type=None, id=0, name=待命, lv=0, target=%d, reason=宠物技能冷却或受封魔战术待命蓄力", myPos, chosenTargetPos))
        end
        return true
    end

    -- 3. 主角在无技能可用或开局SP不足时，以强力弓箭普通攻击起手/兜底 (伤害高达 3000+，并为下回合积攒 SP)
    local isSealed = AI.IsSkillSealed(false)
    local normalReason = isSealed and "主角身受封技无技能可用，执行5966物攻强力弓箭普攻点杀蓄力SP"
        or "开局SP不足或技能全在CD，弓箭普攻抢先输出并蓄力SP"
    if AI.Config.DebugLog then
        Info(string.format("[AI协同] 主角(位号:%d) %s，目标位号 %d (物攻:%d)", myPos, normalReason, chosenTargetPos, state.my_att))
    end
    Blackboard.ReserveDamage(chosenTargetPos, math.max(120, math.floor(state.my_att * 0.5)), myPos)
    return AI.ExecuteNormalAttack(chosenTargetPos, false, normalReason)
end

AI.Blackboard = Blackboard

return AI
