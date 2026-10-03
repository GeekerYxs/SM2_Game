-- ================================================================
-- 寄售-请求节流/排队器
-- ----------------------------------------------------------------
-- 服务端对「列表查询(ListQueryRequest)」与「通知翻页(NotifyPageRequest)」
-- 用同一个冷却桶限速（browse_cooldown_sec，默认 1 秒/角色，见服务端
-- Consignment.HandleListQuery / 通知翻页 + Cache.CheckBrowseCooldown）。
-- 两个协议共用一个节流，所以客户端这两类请求也必须共用同一个本地节流，
-- 否则会出现「先发 list 再发 notify、第二个被服务端拒掉」的情况
-- （典型：收到通知推送时同时重拉首页通知 + 刷新列表）。
--
-- 本模块就是这唯一的节流点：
--   * 玩家主动浏览（搜索/翻页/刷新/首次切页签）：用 Ready() 预判，过快直接
--     拒绝并提示，不入队（见主对话框 passBrowseCooldown）。
--   * 系统自动刷新（通知推送 / 动作完成后刷新）：用 Enqueue() 入队，按冷却
--     节流逐个派发（一次一个，天然 ≤1/冷却窗口），并按 kind 去重避免无效重复。
--
-- 计时基准：os.clock()（与服务端、既有浏览冷却一致，按本进程 wall-clock 秒处理）。
-- 约定：所有真正下发 list/notify 协议的函数，发包前都必须调用 M.Mark() 打点；
--       Tick() 自身不打点，依赖被派发的 fn 内部 Mark（队内只会排这两类发包函数）。
-- ================================================================

local Config = require "ui.dlgs.consignment.ConsignmentConfig"

local M = {}

local _lastClock = nil    -- 上次实际放行(发送)时刻，os.clock()；nil=尚未发过
local _queue = {}         -- 系统触发待发请求，按 kind 去重的 FIFO：{ {kind=, fn=}, ... }

-- ----------------------------------------------------------------
-- 冷却是否已过（可立即放行一次请求）。只读，不打点。
-- os.clock() 约 24.8 天回绕：回绕瞬间(now < _lastClock)按已过冷却处理。
-- ----------------------------------------------------------------
function M.Ready()
    local cd = Config.BROWSE_COOLDOWN_SEC
    if cd <= 0 then return true end
    if not _lastClock then return true end
    local now = os.clock()
    if now < _lastClock then return true end
    return (now - _lastClock) >= cd
end

-- 打点一次实际发送时刻。每个真正下发 list/notify 协议的函数发包前调用。
function M.Mark()
    _lastClock = os.clock()
end

-- ----------------------------------------------------------------
-- 队列操作
-- ----------------------------------------------------------------
local function indexOfKind(kind)
    for i = 1, #_queue do
        if _queue[i].kind == kind then return i end
    end
    return nil
end

-- 入队一个系统触发的请求；同 kind 已在队列中则忽略（去重，避免无效重复请求）。
-- fn 在被 Tick 派发时执行，其内部需自行 M.Mark() 并发包。
function M.Enqueue(kind, fn)
    if indexOfKind(kind) then return end
    _queue[#_queue + 1] = { kind = kind, fn = fn }
end

-- 移除队列里某 kind 的待发请求（玩家已主动发了同类请求时，丢弃重复的排队项）。
function M.Drop(kind)
    local i = indexOfKind(kind)
    if i then table.remove(_queue, i) end
end

-- 每帧驱动：冷却已过且队列非空时，FIFO 取一个派发（一次一个，天然 ≤1/冷却窗口）。
function M.Tick()
    if #_queue == 0 then return end
    if not M.Ready() then return end
    local e = table.remove(_queue, 1)
    e.fn()    -- fn 内部负责 M.Mark() + 发包
end

-- 清空待发队列（界面关闭 / 门禁触发 / 重开会话）。不动冷却基准。
function M.Clear()
    _queue = {}
end

-- 当前待发队列长度（调试用）。
function M.PendingCount()
    return #_queue
end

return M
