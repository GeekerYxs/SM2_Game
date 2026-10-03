-- ============================================================================
-- 纯净 Lua 独立地图巡逻引擎 (Pure Lua Map Patrol Engine v2.1)
--
-- 核心设计:
-- 1. 彻底解耦: 100% 独立于官方 F12 挂机脚本，绝不触碰 cheat 自动攻击宏
-- 2. 队长自适应: 自动识别队长 (火法/伏地魔1/主号位17)，队员安心跟随，杜绝竞争
-- 3. 智能就地定点 (Auto-Anchor): 自动四向避障探测生成安全往返坐标 (Point A <-> Point B)
-- 4. 战态无缝隔离: 战外寻路往返，切入战斗瞬间自动挂起，战斗结束无缝恢复
-- 5. 跨目录通信中枢: 多候选路径自动发现 patrol_config.ini / patrol_status.ini
-- 6. 热重载幂等保护: 全局分发守卫，杜绝事件重复监听累积
-- ============================================================================

local events = require("events")
local gamestate = require("game_state")

local MapPatrol = {}
MapPatrol.__index = MapPatrol

-- 默认配置
MapPatrol.Config = {
    Enabled = false,                -- 是否开启巡逻
    LeaderName = "伏地魔1",         -- 队长角色名
    Mode = "AutoAnchor",            -- "AutoAnchor" (就地定点) 或 "Custom" (自定义点)
    AutoAnchorRadius = 160,         -- 就地定点半径 (像素)
    PointA = { x = 0, y = 0 },      -- 巡逻点 A
    PointB = { x = 0, y = 0 },      -- 巡逻点 B
    CurrentMapID = 0,               -- 巡逻绑定的地图ID
    CurrentTarget = "B",            -- 当前朝向目标点 ("A" 或 "B")
    ReachDistanceSq = 45 * 45,      -- 到达判定半径平方 (像素)
    MoveInterval = 1.2,             -- 发送 MoveTo 的最小间隔 (秒)
    TurnDelay = 0.4,                -- 到达折返等待时间 (秒)
    ConfigFile = "patrol_config.ini",
    StatusFile = "patrol_status.ini",
}

-- 运行时状态
local runtime = {
    lastMoveTime = 0,
    nextMoveTime = 0,
    lastConfigCheckTime = 0,
    lastStatusReportTime = 0,
    isLeader = nil,                 -- nil: 未决, true: 本号是队长, false: 本号是队员
    cachedName = "",
    lastReportedState = "",
    hasLoggedDiag = false,
}

-- ----------------------------------------------------------------------------
-- 候选路径解析器 (兼容各种工作目录启动与多开实例)
-- ----------------------------------------------------------------------------
local function getCandidatePaths(filename)
    return {
        filename,
        "v2.1/" .. filename,
        "../" .. filename,
        "../../" .. filename,
        "D:/什么什么大冒险2.0/" .. filename,
        "D:/什么什么大冒险2.0/v2.1/" .. filename,
        "D:/什么什么大冒险2.0/v2.1/win32/" .. filename,
    }
end

-- ----------------------------------------------------------------------------
-- 1. 健壮 INI 文件解析器
-- ----------------------------------------------------------------------------
local function parseIni(filename)
    local data = {}
    if io == nil or io.open == nil then return data end

    local f = nil
    local activePath = nil
    for _, path in ipairs(getCandidatePaths(filename)) do
        local testF = io.open(path, "r")
        if testF then
            f = testF
            activePath = path
            break
        end
    end
    if not f then return data end

    for line in f:lines() do
        local k, v = string.match(line, "^%s*([%w_]+)%s*=%s*(.-)%s*$")
        if k and v then
            v = string.match(v, "^([^;#]+)")
            if v then
                v = string.match(v, "^%s*(.-)%s*$")
                if v == "true" then
                    data[k] = true
                elseif v == "false" then
                    data[k] = false
                elseif tonumber(v) then
                    data[k] = tonumber(v)
                else
                    data[k] = v
                end
            end
        end
    end
    f:close()
    data.__activePath = activePath
    return data
end

-- ----------------------------------------------------------------------------
-- 2. 状态上报同步写入
-- ----------------------------------------------------------------------------
local function reportStatus(stateStr, playerX, playerY, mapId)
    if io == nil or io.open == nil then return end
    local now = os.time and os.time() or 0
    local content = string.format(
        "LeaderName = %s\nMapID = %d\nPlayerX = %d\nPlayerY = %d\nEnabled = %s\nState = %s\nTarget = %s\nInFight = %s\nPointAX = %d\nPointAY = %d\nPointBX = %d\nPointBY = %d\nLastUpdated = %d\n",
        MapPatrol.Config.LeaderName or "伏地魔1",
        mapId or 0,
        math.floor(playerX or 0),
        math.floor(playerY or 0),
        MapPatrol.Config.Enabled and "true" or "false",
        stateStr or "Idle",
        MapPatrol.Config.CurrentTarget or "B",
        (gamestate and gamestate.isInFight) and "true" or "false",
        math.floor(MapPatrol.Config.PointA.x or 0),
        math.floor(MapPatrol.Config.PointA.y or 0),
        math.floor(MapPatrol.Config.PointB.x or 0),
        math.floor(MapPatrol.Config.PointB.y or 0),
        now
    )

    -- 写入所有可访问的候选路径，确保 UI 面板与批处理均可无缝读取
    for _, path in ipairs(getCandidatePaths("patrol_status.ini")) do
        pcall(function()
            local f = io.open(path, "w")
            if f then
                f:write(content)
                f:close()
            end
        end)
    end
end

-- ----------------------------------------------------------------------------
-- 3. 队长身份精准自省 (Leader Introspection)
-- ----------------------------------------------------------------------------
function MapPatrol.IsLeader()
    -- 若已有确凿缓存判定，直接返回
    if runtime.isLeader ~= nil then
        return runtime.isLeader
    end

    -- 策略 A: 战斗态位号与名称直接判定 (权威)
    if gamestate and gamestate.isInFight then
        local myPos = game:GetMyPos()
        if myPos == 17 then
            runtime.isLeader = true
            local name = game:GetFighterName(myPos)
            if name and name ~= "" then runtime.cachedName = name end
            Info(string.format("[地图巡逻] 队长身份已由战斗位号(17)确认! 角色名:%s", tostring(runtime.cachedName)))
            return true
        elseif myPos >= 0 then
            runtime.isLeader = false
            return false
        end
    end

    -- 策略 B: 战外核心法术/职业技能自省
    -- 伏地魔1 为烈火法师，独占烈爆术 (ID:1504) 或流火 (ID:1501)
    local isFireMage = false
    if game.HasMagic then
        local ok1, has1504 = pcall(function() return game:HasMagic(1504, 1) end)
        local ok2, has1501 = pcall(function() return game:HasMagic(1501, 1) end)
        if (ok1 and has1504) or (ok2 and has1501) then
            isFireMage = true
        end
    end

    if isFireMage then
        runtime.isLeader = true
        Info("[地图巡逻] 队长身份已由职业技能(烈火法师)自省确认!")
        return true
    end

    -- 策略 C: 若配置显式允许全员 (如 "all" 或 "auto")
    local targetLeader = MapPatrol.Config.LeaderName
    if targetLeader == "all" then
        return true
    end

    -- 首次输出诊断日志
    if not runtime.hasLoggedDiag then
        runtime.hasLoggedDiag = true
        Info(string.format("[地图巡逻诊断] 队长自省待决: isFireMage=%s, targetLeader=%s",
            tostring(isFireMage), tostring(targetLeader)))
    end

    -- 尚未进战斗且非火法时，暂不驱动移动，避免队员反客为主
    return false
end

-- ----------------------------------------------------------------------------
-- 4. 智能四向避障就地定点 (Auto-Anchor with Obstacle Clearance)
-- ----------------------------------------------------------------------------
function MapPatrol.AnchorAtCurrentPosition()
    local player = game:MainPlayerObj()
    if player == nil then return false end

    local mapId = game:GetMapID()
    local curX = player.X
    local curY = player.Y
    local r = MapPatrol.Config.AutoAnchorRadius or 160

    -- 点 A 固定为当前脚下坐标
    MapPatrol.Config.PointA = { x = curX, y = curY }

    -- 四向候选探测: 优先 +X (右), -X (左), +Y (下), -Y (上)
    local candidates = {
        { x = curX + r, y = curY },
        { x = curX - r, y = curY },
        { x = curX, y = curY + r },
        { x = curX, y = curY - r },
    }

    local chosenB = candidates[1]
    if game.IsMapPointBlocked then
        for _, cand in ipairs(candidates) do
            local ok, blocked = pcall(function() return game:IsMapPointBlocked(cand.x, cand.y) end)
            if ok and not blocked then
                chosenB = cand
                break
            end
        end
    end

    MapPatrol.Config.PointB = chosenB
    MapPatrol.Config.CurrentMapID = mapId
    MapPatrol.Config.CurrentTarget = "B"
    MapPatrol.Config.Enabled = true
    runtime.lastMoveTime = 0
    runtime.nextMoveTime = 0

    Info(string.format("[地图巡逻] 智能就地定点成功! 地图:%d, 点A(%d,%d) <-> 点B(%d,%d)",
        mapId, math.floor(MapPatrol.Config.PointA.x), math.floor(MapPatrol.Config.PointA.y),
        math.floor(MapPatrol.Config.PointB.x), math.floor(MapPatrol.Config.PointB.y)))

    reportStatus("Patrolling", curX, curY, mapId)
    return true
end

-- ----------------------------------------------------------------------------
-- 5. 外部配置与指令轮询
-- ----------------------------------------------------------------------------
local function checkExternalConfig()
    local now = os.clock()
    if now - runtime.lastConfigCheckTime < 1.0 then return end
    runtime.lastConfigCheckTime = now

    local ini = parseIni(MapPatrol.Config.ConfigFile)
    if ini.LeaderName and ini.LeaderName ~= "" then
        MapPatrol.Config.LeaderName = ini.LeaderName
    end
    if ini.AutoAnchorRadius and ini.AutoAnchorRadius > 0 then
        MapPatrol.Config.AutoAnchorRadius = ini.AutoAnchorRadius
    end

    -- 仅队长号响应外部指令与巡逻驱动
    if not MapPatrol.IsLeader() then
        return
    end

    -- 处理特殊即时指令 (START / STOP / ANCHOR)
    if ini.Command and ini.Command ~= "" then
        local cmd = ini.Command
        if cmd == "START" or cmd == "ANCHOR" then
            MapPatrol.AnchorAtCurrentPosition()
        elseif cmd == "STOP" then
            MapPatrol.Stop()
        end
        -- 清理已消费指令
        if ini.__activePath then
            pcall(function()
                local content = ""
                local f = io.open(ini.__activePath, "r")
                if f then
                    content = f:read("*a")
                    f:close()
                end
                content = string.gsub(content, "Command%s*=%s*[%w_]+", "Command = ")
                local fw = io.open(ini.__activePath, "w")
                if fw then
                    fw:write(content)
                    fw:close()
                end
            end)
        end
        return
    end

    -- 处理常规开关变更
    if ini.Enabled ~= nil then
        if ini.Enabled == true and not MapPatrol.Config.Enabled then
            if ini.PointAX and ini.PointAX > 0 and ini.PointBX and ini.PointBX > 0 then
                MapPatrol.Start(ini.PointAX, ini.PointAY, ini.PointBX, ini.PointBY)
            else
                MapPatrol.AnchorAtCurrentPosition()
            end
        elseif ini.Enabled == false and MapPatrol.Config.Enabled then
            MapPatrol.Stop()
        end
    end
end

-- ----------------------------------------------------------------------------
-- 6. 启停控制接口
-- ----------------------------------------------------------------------------
function MapPatrol.Start(x1, y1, x2, y2)
    MapPatrol.Config.PointA = { x = x1, y = y1 }
    MapPatrol.Config.PointB = { x = x2, y = y2 }
    MapPatrol.Config.CurrentTarget = "B"
    MapPatrol.Config.Enabled = true
    runtime.lastMoveTime = 0
    runtime.nextMoveTime = 0
    Info(string.format("[地图巡逻] 启动巡逻: A(%d, %d) <-> B(%d, %d)", x1, y1, x2, y2))
end

function MapPatrol.Stop()
    MapPatrol.Config.Enabled = false
    local player = game:MainPlayerObj()
    if player ~= nil and not (gamestate and gamestate.isInFight) then
        pcall(function() game:MoveTo(player.X, player.Y) end)
    end
    Info("[地图巡逻] 停止巡逻")
    if player ~= nil then
        reportStatus("Stopped", player.X, player.Y, game:GetMapID())
    end
end

-- ----------------------------------------------------------------------------
-- 7. 主循环驱动 (GameUpdate)
-- ----------------------------------------------------------------------------
function MapPatrol.onGameUpdate()
    -- 周期读取外部控制配置 (1秒/次)
    checkExternalConfig()

    if not MapPatrol.Config.Enabled then
        return
    end

    -- ------------------------------------------------------------------------
    -- 核心安全哨兵: 战外全员极速自检补血 + 队长绝对防暴毙待命
    -- 铁律: 任何成员血量不满立即极速吃药补满；若队伍生命未恢复，队长绝不起步撞怪！
    -- ------------------------------------------------------------------------
    local myHp = game.GetHp and game:GetHp() or 0
    local myHpMax = game.GetHpMax and game:GetHpMax() or 1
    if myHp > 0 and myHpMax > 0 and (myHp / myHpMax < 0.90) then
        pcall(function()
            if game.FillHp then game:FillHp() end
        end)
    end

    local petHp = game.GetPetHp and game:GetPetHp() or 0
    local petHpMax = game.GetPetHpMax and game:GetPetHpMax() or 1
    if petHp > 0 and petHpMax > 0 and (petHp / petHpMax < 0.90) then
        pcall(function()
            if game.FillPetHp then game:FillPetHp() end
        end)
    end

    -- 只有队长号负责移动
    if not MapPatrol.IsLeader() then
        return
    end

    -- 队长哨兵检查: 若自身或宠物生命低于 85%，原地驻足回血，绝对不撞怪！
    if (myHp > 0 and myHpMax > 0 and myHp / myHpMax < 0.85) or
       (petHp > 0 and petHpMax > 0 and petHp / petHpMax < 0.85) then
        runtime.nextMoveTime = now + 1.5
        if AI and AI.Config and AI.Config.DebugLog then
            Info("[巡逻安全哨兵] 队长或宠物生命值未达安全线，队长就地驻足回血，绝不残血进战!")
        end
        return
    end

    -- 若处于战斗中，绝对不执行地图寻路移动 (静默交由战斗AI接管)
    if gamestate and gamestate.isInFight then
        return
    end

    local now = os.clock()
    if now < runtime.nextMoveTime then
        return
    end

    local player = game:MainPlayerObj()
    if player == nil then
        return
    end

    local targetPos = (MapPatrol.Config.CurrentTarget == "A") and MapPatrol.Config.PointA or MapPatrol.Config.PointB
    if targetPos.x == 0 and targetPos.y == 0 then
        MapPatrol.AnchorAtCurrentPosition()
        return
    end

    -- 计算与目标点的距离平方
    local dx = player.X - targetPos.x
    local dy = player.Y - targetPos.y
    local distSq = dx * dx + dy * dy

    -- 若到达目标点附近，切换目标点并稍作等待
    if distSq <= MapPatrol.Config.ReachDistanceSq then
        if MapPatrol.Config.CurrentTarget == "A" then
            MapPatrol.Config.CurrentTarget = "B"
            targetPos = MapPatrol.Config.PointB
        else
            MapPatrol.Config.CurrentTarget = "A"
            targetPos = MapPatrol.Config.PointA
        end
        runtime.nextMoveTime = now + MapPatrol.Config.TurnDelay
        Info(string.format("[地图巡逻] 到达目标点，折返前往点 %s (%d, %d)",
            MapPatrol.Config.CurrentTarget, math.floor(targetPos.x), math.floor(targetPos.y)))
        return
    end

    -- 周期性发起寻路 (1.2秒/次)
    if now - runtime.lastMoveTime >= MapPatrol.Config.MoveInterval then
        runtime.lastMoveTime = now
        pcall(function()
            game:MoveTo(targetPos.x, targetPos.y)
        end)

        -- 状态上报 (每3秒上报一次活跃状态)
        if now - runtime.lastStatusReportTime >= 3.0 then
            runtime.lastStatusReportTime = now
            reportStatus("Patrolling", player.X, player.Y, game:GetMapID())
        end
    end
end

-- 进战斗事件: 自动自省位号并标记战态
function MapPatrol.onFightBegin()
    if game.GetMyPos then
        local myPos = game:GetMyPos()
        if myPos == 17 then
            runtime.isLeader = true
        elseif myPos >= 0 then
            runtime.isLeader = false
        end
    end

    local player = game:MainPlayerObj()
    if player ~= nil and MapPatrol.IsLeader() then
        reportStatus("InFight", player.X, player.Y, game:GetMapID())
    end
end

-- 出战斗事件: 出战斗后极速吃药补满，恢复上报
function MapPatrol.onFightLeave()
    pcall(function()
        local hp = game.GetHp and game:GetHp() or 0
        local hpMax = game.GetHpMax and game:GetHpMax() or 1
        if hp > 0 and hpMax > 0 and (hp / hpMax < 0.95) then
            if game.FillHp then game:FillHp() end
        end
        local php = game.GetPetHp and game:GetPetHp() or 0
        local phpMax = game.GetPetHpMax and game:GetPetHpMax() or 1
        if php > 0 and phpMax > 0 and (php / phpMax < 0.95) then
            if game.FillPetHp then game:FillPetHp() end
        end
    end)

    local player = game:MainPlayerObj()
    if player ~= nil and MapPatrol.IsLeader() then
        reportStatus(MapPatrol.Config.Enabled and "Patrolling" or "Stopped", player.X, player.Y, game:GetMapID())
    end
end

-- ----------------------------------------------------------------------------
-- 8. 幂等全局事件注册守卫
-- ----------------------------------------------------------------------------
if not __MAP_PATROL_DISPATCHER__ then
    __MAP_PATROL_DISPATCHER__ = true
    events.GameUpdate:Add(function()
        if __ACTIVE_MAP_PATROL__ and __ACTIVE_MAP_PATROL__.onGameUpdate then
            __ACTIVE_MAP_PATROL__.onGameUpdate()
        end
    end)
    events.BeginFight:Add(function()
        if __ACTIVE_MAP_PATROL__ and __ACTIVE_MAP_PATROL__.onFightBegin then
            __ACTIVE_MAP_PATROL__.onFightBegin()
        end
    end)
    events.LeaveFight:Add(function()
        if __ACTIVE_MAP_PATROL__ and __ACTIVE_MAP_PATROL__.onFightLeave then
            __ACTIVE_MAP_PATROL__.onFightLeave()
        end
    end)
end
__ACTIVE_MAP_PATROL__ = MapPatrol

Info("[地图巡逻] Pure Lua Map Patrol Engine v2.1 加载成功!")

pcall(function()
    package.loaded["ai_fight_strategy"] = nil
    pcall(require, "ai_fight_strategy")
end)

return MapPatrol
