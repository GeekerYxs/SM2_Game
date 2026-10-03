-- ================================================================
-- 地图场景突进按钮（PlayerDash 1070 C2S / 1071 S2C）。
--
-- 在地图桌面显示一个常驻小按钮（当前为固定坐标，见下方 DashX/DashY）。
-- 点击行为：
--   1. 玩家忙时忽略点击（战斗中 / NPC 对话 / 玩家交易 / NPC 买卖，
--      引擎侧 game:IsPlayerBusy 判定）；
--   2. 发起突进冷却 1 秒，并把剩余秒数显示在按钮上；
--   3. 发包前仅当朝向方向 DashBlockWarnDist（100px）内有阻挡才提示并拦截；
--      更远处有阻挡则放行，由服务端把突进停在阻挡边缘（部分突进）；
--   4. 发送一条 DashRequest { dir = 朝向 }，再处理服务端 DashResult
--      （服务端冷却剩余 / 各错误码提示）。
--
-- 本 luas 树编码约定：
--   源码文件可为 UTF-8，凡需要上屏的中文字符串必须经
--   L() = game:UTF8toASCII 转成客户端显示编码（GBK）后再交给引擎。
-- ================================================================

local dlgbuilder  = require "dlg_builder"
local ScriptEvent = require "script_event"
local struct      = require "ui_dashbutton_struct"
local events      = require "events"
local gamestate   = require "game_state"

-- 源码 UTF-8 -> 客户端显示编码（GBK），所有 UI 字符串都要过这里
local L = function(s) return game:UTF8toASCII(s) end

-- ------------------------------------------------------------------
-- 可调参数
-- ------------------------------------------------------------------
local DashX            = 200   -- HUD 坐标（临时；后续放到快捷栏下方）
local DashY            = 100
local DashDefaultDir   = 2     -- 取不到朝向时的默认方向（2 = 右）
local DashBlockWarnDist = 100  -- 仅当前方 100px 内有阻挡才提示“阻挡”；更远阻挡放行（服务端停在阻挡边缘）
local LocalInitiateCdMs = 1000 -- 两次发起突进的最小间隔（1 秒）

-- 8 方向偏移表，与服务端 OnCallScript.lua 的 DashDirOffset 约定一致：
-- 0=上、顺时针；客户端地图像素 +x=右、+y=下
local DashDirOffset = {
    [0] = { x = 0,  y = -1 },  -- 上
    [1] = { x = 1,  y = -1 },  -- 右上
    [2] = { x = 1,  y = 0  },  -- 右
    [3] = { x = 1,  y = 1  },  -- 右下
    [4] = { x = 0,  y = 1  },  -- 下
    [5] = { x = -1, y = 1  },  -- 左下
    [6] = { x = -1, y = 0  },  -- 左
    [7] = { x = -1, y = -1 },  -- 左上
}

local START_CTRL_ID    = 6000 -- 控件 ID 起始段，避开既有对话框号段（3000~4800）

local _dlg        = nil
local _login      = false
local _cdUntilMs  = 0      -- os.clock()*1000 的冷却截止时刻（绝对时间）
local _lastTick   = 0
local _lastDir    = DashDefaultDir

-- ------------------------------------------------------------------
-- 小工具
-- ------------------------------------------------------------------
local function showMessage(hexColor, text)
    if text and text ~= "" then
        game:ShowMessage(hexColor .. text)
    end
end

-- pcall 保护：老客户端没有下面这些新 C++ Lua 接口时（GetPlayerDir /
-- IsPlayerBusy / IsMapPointBlocked / IsLineBlocked）自动降级，不抛错。
local function safeCall(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, a, b = pcall(fn, ...)
    if ok then
        return a, b
    end
    return nil
end

-- ------------------------------------------------------------------
-- 视图刷新
-- ------------------------------------------------------------------
local function refreshView()
    if not _dlg or not _dlg.Raw then return end

    local cdMs = _cdUntilMs - os.clock() * 1000
    local inCd = cdMs > 0

    if _dlg.btnDash then
        _dlg.btnDash:SetEnable(inCd and 0 or 1)
    end
    if _dlg.txtMain then
        _dlg.txtMain:ClearString()
        _dlg.txtMain:AddString(L("突进"))
    end
    if _dlg.txtCd then
        _dlg.txtCd:ClearString()
        if inCd then
            _dlg.txtCd:AddString(string.format("%.1f", cdMs / 1000))
        end
    end
end

-- ------------------------------------------------------------------
-- 点击处理
-- ------------------------------------------------------------------
local function tryDash()
    if not _dlg or not _dlg.Raw then return end
    if not _login or gamestate.isInFight then return end

    local nowMs = os.clock() * 1000

    -- 1 秒发起冷却（倒计时期间静默忽略点击，按钮上已有倒计时显示）
    if nowMs < _cdUntilMs then
        refreshView()
        return
    end

    -- 忙判定：战斗中 / NPC 对话 / 玩家交易 / NPC 买卖
    if gamestate.isInFight then
        showMessage("#ffff00#", L("战斗中，无法突进"))
        return
    end
    if safeCall(game.IsPlayerBusy, game) == true then
        showMessage("#ffff00#", L("忙碌中，无法突进"))
        return
    end

    -- 取朝向（0~7，0=上、顺时针，与服务端 DashRequest 编号一致）
    local dir = safeCall(game.GetPlayerDir, game)
    if not dir or dir < 0 or dir > 7 then
        dir = _lastDir or DashDefaultDir
    end
    _lastDir = dir

    -- 前方预检（用两个通用 C++ 接口，只看短距离）：
    -- 只有 DashBlockWarnDist 内的阻挡才按“前方阻挡”提示并拦截；
    -- 更远处的阻挡放行，服务端会把突进停在阻挡边缘。
    local pl = game:MainPlayerObj()
    local off = pl and DashDirOffset[dir]
    if pl == nil or off == nil then
        showMessage("#ffff00#", L("无法判定前方，请稍后再试"))
        return
    end
    local px = math.floor(pl.X or 0)
    local py = math.floor(pl.Y or 0)
    local ex = math.floor(px + off.x * DashBlockWarnDist)
    local ey = math.floor(py + off.y * DashBlockWarnDist)
    local blockedPt   = safeCall(game.IsMapPointBlocked, game, ex, ey)
    local blockedLine = safeCall(game.IsLineBlocked, game, px, py, ex, ey)
    if blockedPt == true or blockedLine == true then
        showMessage("#ffff00#", L("前方有阻挡，无法突进"))
        return
    end

    game:SendCallScriptPacket(ScriptEvent.PlayerDashRequest, { dir = dir })
    _cdUntilMs = nowMs + LocalInitiateCdMs
    refreshView()
end

-- ------------------------------------------------------------------
-- 对话框回调
-- ------------------------------------------------------------------
local function onEventProc(luadlg, eventCode, ctrlId, ctrl)
    if not luadlg then return end
    if eventCode == UIEventDef.TBN_CLICKED then
        if luadlg.btnDash and ctrlId == luadlg.btnDash.CtrlID then
            tryDash()
        end
    end
end

local function onShow(luadlg, show)
    if show then
        refreshView()
    end
end

local function onCallScript(luadlg, event, obj)
    if not luadlg or obj == nil then return end
    if event ~= ScriptEvent.PlayerDashResult then return end

    local nowMs = os.clock() * 1000

    if obj.ret == false then
        local code = tonumber(obj.errCode) or 0
        if code == 1 then
            -- 服务端仍在冷却：把剩余冷却时间显示到按钮上
            local cd = tonumber(obj.cooldown_ms) or 0
            if cd > 0 then
                _cdUntilMs = nowMs + cd
            end
            refreshView()
        elseif code == 2 then
            showMessage("#ffff00#", L("方向异常，无法突进"))
        elseif code == 3 then
            showMessage("#ffff00#", L("前方有阻挡，无法突进"))
        else
            showMessage("#d60000#", L("突进失败(错误码:") .. tostring(code) .. L(")"))
        end
        return
    end

    -- 成功：只保留 1 秒发起冷却。若服务端仍在它自己的冷却里，
    -- 下次点击会收到 errCode=1 并在上面分支里显示/采纳剩余时间，
    -- 按钮不会长时间静默无响应。
    _cdUntilMs = nowMs + LocalInitiateCdMs
    refreshView()
end

-- ------------------------------------------------------------------
-- 显隐控制 / 每帧刷新
-- ------------------------------------------------------------------
local function updateVisible()
    if not _dlg or not _dlg.Raw then return end
    local wantShow = _login and (not gamestate.isInFight)
    if _dlg.Raw:GetVisible() ~= (wantShow and 1 or 0) then
        _dlg.Raw:ShowDlg(wantShow)
    end
end

local function gameUpdate()
    if not _dlg or not _dlg.Raw then return end
    local now = os.clock()
    if _cdUntilMs > 0 then
        if now * 1000 >= _cdUntilMs then
            _cdUntilMs = 0
            refreshView()
        elseif now - _lastTick >= 0.1 then
            _lastTick = now
            refreshView()
        end
    end
end

-- 登录后显示
events.GameLogin:Add(function()
    _login = true
    updateVisible()
    refreshView()
end)

-- 下线隐藏
events.GameLogout:Add(function()
    _login = false
    _cdUntilMs = 0
    updateVisible()
end)

-- 进战斗隐藏
events.EnterFight:Add(function()
    updateVisible()
end)

-- 出战斗恢复
events.LeaveFight:Add(function()
    updateVisible()
    refreshView()
end)

-- 每帧驱动冷却倒计时刷新
events.GameUpdate:Add(gameUpdate)

-- ------------------------------------------------------------------
-- 创建
-- ------------------------------------------------------------------
local function createDlg(dlgmgr)
    local luadlg = dlgbuilder(dlgmgr, struct, "", START_CTRL_ID, true)
    _dlg = luadlg

    luadlg.ignoreEsc = true   -- 按 ESC 不应关闭这个 HUD 按钮
    luadlg.OnEventProc  = onEventProc
    luadlg.OnShow       = onShow
    luadlg.OnCallScript = onCallScript

    HandleCallScript(ScriptEvent.PlayerDashResult, luadlg)

    luadlg.Raw:SetPosition(DashX, DashY)
    _login = gamestate.isLogin
    _cdUntilMs = 0
    refreshView()
    updateVisible()
    return luadlg
end

return { OnCreate = createDlg }
