-- ================================================================
-- 寄售-客户端状态（单一数据源）
-- ================================================================

local Config = require "ui.dlgs.consignment.ConsignmentConfig"

local M = {}

-- OpenResult 快照
local _systemState = nil    -- 系统状态 { is_open, daily_close_until }
local _playerInfo  = nil    -- 玩家信息 { player_id, player_name, daily_paid_yuanbao, daily_buy_count }
local _orderStats  = nil    -- 订单计数

-- ApplyOpenResult 快照
local _applyOpen = nil      -- { concurrent_listing, concurrent_listing_limit, daily_apply_total, daily_apply_limit, coin_per_yuanbao, player_coin, player_yuanbao }

-- ListQueryResult 快照
local _listResult = nil     -- 最近一次 ListQueryResult 完整表
-- 当前查询参数（刷新时按此重新下发）
local _query = {
    page_mode = Config.PageMode.OnSaleDisplay,
    page      = 1,
    sort      = Config.Sort.TimeDesc,
    item_ids  = nil,         -- 可选过滤：itemid 数组（精确匹配=1 个 / 模糊匹配=多个）
    search_text = nil,       -- 搜索框原始输入文本（刷新 / 切页签时回显，模糊匹配下无法由 itemid 反推名称）
    identity  = Config.Identity.All,
}

-- 各页签快照缓存：[page_mode] -> { listResult, page, sort, item_ids, search_text, identity }
-- 离开页签时写入；再次进入已访问过的页签时读取。
local _tabCache = {}

-- 订单物品属性快照缓存：[order_id] -> props 数组（可为空表）
-- 属性快照在服务端申请落单时写入、之后只读，所以一次会话内永不失效；
-- 不随页签缓存作废（InvalidateAllTabCaches 不清它），仅 Reset 时清空。
local _propsCache = {}
-- 已发出请求、尚未收到回包的订单ID集合（防止回包等待期内鼠标反复悬浮重复请求）。
-- 每次收到新的 ListQueryResult 时整体清空：丢包也能在下次悬浮时自愈重试。
local _propsPending = {}

-- 通知（服务端分页：本地只持有当前页 { total, page, page_size, items }）
local _notifyPage = { total = 0, page = 1, page_size = Config.NOTIFY_PAGE_SIZE, items = {} }

-- ----------------------------------------------------------------
-- OpenResult
-- ----------------------------------------------------------------
function M.SetOpenResult(obj)
    -- 新一次打开对话框时，清空上一次会话遗留的页签缓存。
    _tabCache = {}

    _systemState = obj.system_state or {}
    _playerInfo  = obj.player_info or {}
    _orderStats  = obj.order_stats or {}

    -- 通知首页（服务端分页下发）：{ total, page, page_size, items }
    M.SetNotifyPage(obj.notifications)

    -- 服务端指定的默认页签（1=OnSaleDisplay 等）
    if obj.default_page then
        _query.page_mode = obj.default_page
    end
end

--- 仅刷新统计字段（已打开的对话框收到 OpenResult 时使用）。
--- 与 SetOpenResult 不同：不清空页签缓存、不重置默认页签、不动 _query，
--- 保留玩家当前所在的页签和过滤/排序状态。
function M.SetOpenResultStats(obj)
    _systemState = obj.system_state or {}
    _playerInfo  = obj.player_info or {}
    _orderStats  = obj.order_stats or {}
    -- 通知首页仍以服务端最新快照为准（动作完成后的统计刷新会带最新首页）
    M.SetNotifyPage(obj.notifications)
end

function M.GetSystemState() return _systemState end
function M.GetPlayerInfo()  return _playerInfo  end
function M.GetOrderStats()  return _orderStats  end

function M.IsSystemOpen()
    return _systemState and _systemState.is_open == 1
end

-- ----------------------------------------------------------------
-- ApplyOpenResult（申请寄售对话框配额快照）
-- ----------------------------------------------------------------
function M.SetApplyOpenResult(obj)
    _applyOpen = obj or {}
end

function M.GetApplyOpen() return _applyOpen end

-- ----------------------------------------------------------------
-- 查询状态
-- ----------------------------------------------------------------
function M.GetQuery() return _query end
function M.GetPageMode() return _query.page_mode end
function M.GetPage() return _query.page end
function M.GetSort() return _query.sort end
function M.GetIdentity() return _query.identity end
function M.GetItemIdsFilter() return _query.item_ids end
function M.GetSearchText() return _query.search_text end

function M.SetPageMode(mode)
    _query.page_mode = mode
    _query.page      = 1
    -- 按规范要求：切换页签时重置排序。我的交易默认「分类排序」(select6)，其余默认上架时间降序(select0)。
    _query.sort      = (mode == Config.PageMode.MyOrders) and Config.Sort.Category or Config.Sort.TimeDesc
    _query.item_ids   = nil
    _query.search_text = nil
end

--- 仅更新 page_mode，不重置其他字段（由 ListQueryResult 回包使用）。
function M.SetPageModeOnly(mode)
    _query.page_mode = mode
end

function M.SetPage(page)  _query.page = page end
function M.SetSort(sort)  _query.sort = sort end
function M.SetIdentity(i) _query.identity = i end

--- 设置搜索过滤：itemIds 为 itemid 数组（精确=1 个 / 模糊=多个），text 为原始输入文本。
function M.SetSearchFilter(itemIds, text)
    _query.item_ids    = itemIds
    _query.search_text = text
end

--- 清空搜索过滤（搜索框留空时调用）。
function M.ClearSearchFilter()
    _query.item_ids    = nil
    _query.search_text = nil
end

-- ----------------------------------------------------------------
-- ListQueryResult（列表查询结果）
-- ----------------------------------------------------------------
function M.SetListResult(obj)
    _listResult = obj or {}
    -- 新一轮列表到达：清掉上一轮悬空的属性请求标记，
    -- 让上一轮丢失的回包可以随本轮渲染重新补拉。
    _propsPending = {}
end

function M.GetListResult() return _listResult end
function M.GetItems()
    return (_listResult and _listResult.items) or {}
end
function M.GetTotal()
    return (_listResult and _listResult.total) or 0
end
function M.GetTotalPageCount()
    local total = M.GetTotal()
    local size  = Config.PAGE_SIZE
    if total <= 0 then return 1 end
    return math.floor((total + size - 1) / size)
end

function M.GetItemByOrderId(orderId)
    if not _listResult or not _listResult.items then return nil end
    for _, it in ipairs(_listResult.items) do
        if it.order_id == orderId then return it end
    end
    return nil
end

-- ----------------------------------------------------------------
-- 订单物品属性快照（ItemPropsResult 回包逐单写入）
-- ----------------------------------------------------------------
--- 取某订单的属性快照；未到达/未请求时返回 nil（调用方回退空表渲染）。
function M.GetItemProps(orderId)
    if not orderId then return nil end
    return _propsCache[orderId]
end

--- ItemPropsResult 回包写入（空表也写：零属性是合法结果，缓存住避免反复补拉）。
function M.SetItemProps(orderId, props)
    if not orderId then return end
    _propsCache[orderId] = props or {}
    _propsPending[orderId] = nil
end

--- 鼠标悬浮懒加载用：该订单属性"未缓存且未在途"时标记在途并返回 true，
--- 调用方应随即发起 ItemPropsRequest；已缓存或在途中返回 false（不重复请求）。
function M.MarkPropsRequestPending(orderId)
    if not orderId then return false end
    if _propsCache[orderId] ~= nil or _propsPending[orderId] then
        return false
    end
    _propsPending[orderId] = true
    return true
end

-- ----------------------------------------------------------------
-- 各页签缓存（切回此前查询过的页签时无需重新向服务端请求即可渲染）
-- ----------------------------------------------------------------
function M.SaveCurrentTabCache()
    if not _listResult then return end -- 还没有可缓存的有效结果
    _tabCache[_query.page_mode] = {
        listResult  = _listResult,
        page        = _query.page,
        sort        = _query.sort,
        item_ids    = _query.item_ids,
        search_text = _query.search_text,
        identity    = _query.identity,
    }
end

function M.HasTabCache(mode)
    return _tabCache[mode] ~= nil
end

--- 恢复此前缓存过的页签。命中返回 true，未命中返回 false。
function M.RestoreTabCache(mode)
    local snap = _tabCache[mode]
    if not snap then return false end
    _query.page_mode = mode
    _query.page      = snap.page
    _query.sort      = snap.sort
    _query.item_ids    = snap.item_ids
    _query.search_text = snap.search_text
    _query.identity  = snap.identity
    _listResult      = snap.listResult
    return true
end

function M.InvalidateAllTabCaches()
    _tabCache = {}
end

-- ----------------------------------------------------------------
-- 通知
-- ----------------------------------------------------------------
--- 写入服务端下发的某页通知（OpenResult 首页 / NotifyPageResult 翻页）。
function M.SetNotifyPage(pageObj)
    pageObj = pageObj or {}
    _notifyPage = {
        total     = tonumber(pageObj.total) or 0,
        page      = tonumber(pageObj.page) or 1,
        page_size = tonumber(pageObj.page_size) or Config.NOTIFY_PAGE_SIZE,
        items     = pageObj.items or {},
    }
end

function M.GetNotifyItems()    return _notifyPage.items end
function M.GetNotifyCurPage()  return _notifyPage.page end
function M.GetNotifyTotal()    return _notifyPage.total end
function M.GetNotifyPageSize() return _notifyPage.page_size end
function M.GetNotifyTotalPages()
    local size = _notifyPage.page_size
    if not size or size < 1 then size = 1 end
    return math.max(1, math.ceil((_notifyPage.total or 0) / size))
end

-- ----------------------------------------------------------------
-- 工具函数 - 判断玩家在订单中的身份
-- ----------------------------------------------------------------
function M.GetMyPlayerId()
    return _playerInfo and _playerInfo.player_id
end

--- 0 = 无关；1 = 卖家；2 = 买家
function M.GetMyIdentityIn(order)
    if not order then return 0 end
    local myId = M.GetMyPlayerId()
    if not myId then return 0 end
    if order.seller_id == myId then return 1 end
    if order.buyer_id == myId then return 2 end
    return 0
end

-- ----------------------------------------------------------------
-- 重置所有状态（供重新打开使用）
-- ----------------------------------------------------------------
function M.Reset()
    _systemState   = nil
    _playerInfo    = nil
    _orderStats    = nil
    _applyOpen     = nil
    _listResult    = nil
    _tabCache      = {}
    _propsCache    = {}
    _propsPending  = {}
    _notifyPage    = { total = 0, page = 1, page_size = Config.NOTIFY_PAGE_SIZE, items = {} }
    _query.page_mode = Config.PageMode.OnSaleDisplay
    _query.page      = 1
    _query.sort      = Config.Sort.TimeDesc
    _query.item_ids    = nil
    _query.search_text = nil
    _query.identity  = Config.Identity.All
end

return M
