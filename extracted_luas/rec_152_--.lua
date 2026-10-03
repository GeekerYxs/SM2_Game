-- ================================================================
-- 寄售-网络层（8 个 C2S 协议）
-- ================================================================

local ScriptEvent = require "script_event"

local M = {}

-- 标志位归一化：调用方可能传布尔(true/false)，也可能传已转好的数字(1/0)。
-- 不能直接写 `v and 1 or 0` —— Lua 里只有 nil/false 是假，**数字 0 是真值**，
-- 那样写会把"关"的 0 再转成 1（匿名开关曾因此无论勾没勾都按匿名下发）。
local function toFlag(v)
    if v == true then return 1 end
    return (tonumber(v) == 1) and 1 or 0
end

--- 2.1 打开寄售主界面。
function M.SendOpenRequest()
    Debug("Consignment.SendOpenRequest")
    game:SendCallScriptPacket(ScriptEvent.Consignment_OpenRequest, {})
end

--- 3.1 列表查询。
-- @param params 查询参数 { page_mode, page, sort?, item_ids?, identity? }
--   item_ids 为 itemid 数组（精确匹配=1 个 / 模糊匹配=多个），按 CSV 字符串下发。
function M.SendListQueryRequest(params)
    local req = {
        page_mode = params.page_mode,
        page      = params.page or 1,
    }
    if params.sort then req.sort = params.sort end
    if params.item_ids and #params.item_ids > 0 then
        req.item_ids = table.concat(params.item_ids, ",")
    end
    if params.identity then req.identity = params.identity end
    Debug("Consignment.SendListQueryRequest pm=" .. tostring(req.page_mode)
        .. " page=" .. tostring(req.page)
        .. " sort=" .. tostring(req.sort)
        .. " items=" .. tostring(req.item_ids)
        .. " id=" .. tostring(req.identity))
    game:SendCallScriptPacket(ScriptEvent.Consignment_ListQueryRequest, req)
end

--- 3.2 订单物品属性查询。
-- 列表回包不带属性快照（防止整页合并下发超包）；列表渲染后对未缓存的订单补拉。
-- 服务端按订单逐包回 Consignment_ItemPropsResult。
-- @param orderIds 订单ID数组（≤ 一页 8 个）
function M.SendItemPropsRequest(orderIds)
    if not orderIds or #orderIds == 0 then return end
    local csv = table.concat(orderIds, ",")
    Debug("Consignment.SendItemPropsRequest ids=" .. csv)
    game:SendCallScriptPacket(ScriptEvent.Consignment_ItemPropsRequest, {
        order_ids = csv,
    })
end

--- 4.2 打开申请对话框（拉取配额 / 手续费率）。
function M.SendApplyOpenRequest()
    Debug("Consignment.SendApplyOpenRequest")
    game:SendCallScriptPacket(ScriptEvent.Consignment_ApplyOpenRequest, {})
end

--- 4.4 提交寄售申请。
-- @param params 申请参数 { slotIdx, count, totalPrice, secret?, sellerAnonymous? }
--   sellerAnonymous：卖家匿名开关（boolean 或 1/0，缺省=不匿名）；开时其它用户看不到本单卖家名。
function M.SendApplyRequest(params)
    local req = {
        slotIdx         = params.slotIdx,
        count           = params.count,
        totalPrice      = params.totalPrice,
        sellerAnonymous = toFlag(params.sellerAnonymous),
    }
    if params.secret and params.secret ~= "" then
        req.secret = params.secret
    end
    Debug("Consignment.SendApplyRequest slot=" .. tostring(req.slotIdx)
        .. " count=" .. tostring(req.count)
        .. " price=" .. tostring(req.totalPrice)
        .. " secret=" .. tostring(req.secret ~= nil)
        .. " anon=" .. tostring(req.sellerAnonymous))
    game:SendCallScriptPacket(ScriptEvent.Consignment_ApplyRequest, req)
end

--- 5.1 购买
-- @param orderId number 订单号
-- @param secretInput string|nil 口令（带口令订单需要）
-- @param buyerAnonymous boolean|number|nil 买家匿名开关（boolean 或 1/0）；开时卖家看不到本次买家名。
--   普通购买 / 带口令购买两个对话框都有开关；传 nil → 按不匿名。
function M.SendBuyRequest(orderId, secretInput, buyerAnonymous)
    local req = {
        OrderID        = orderId,
        buyerAnonymous = toFlag(buyerAnonymous),
    }
    if secretInput and secretInput ~= "" then
        req.secretInput = secretInput
    end
    Debug("Consignment.SendBuyRequest order=" .. tostring(orderId)
        .. " secret=" .. tostring(secretInput ~= nil)
        .. " anon=" .. tostring(req.buyerAnonymous))
    game:SendCallScriptPacket(ScriptEvent.Consignment_BuyRequest, req)
end

--- 5.2 领取（1=卖家收款，2=买家收货，3=卖家退货，4=买家退款）
function M.SendClaimRequest(claimType, orderId)
    Debug("Consignment.SendClaimRequest type=" .. tostring(claimType)
        .. " order=" .. tostring(orderId))
    game:SendCallScriptPacket(ScriptEvent.Consignment_ClaimRequest, {
        type    = claimType,
        OrderID = orderId,
    })
end

--- 5.3 撤销
function M.SendCancelRequest(orderId)
    Debug("Consignment.SendCancelRequest order=" .. tostring(orderId))
    game:SendCallScriptPacket(ScriptEvent.Consignment_CancelRequest, {
        OrderID = orderId,
    })
end

--- 6.1 通知历史翻页：请求第 page 页（1 基）。回包 Consignment_NotifyPageResult。
function M.SendNotifyPageRequest(page)
    Debug("Consignment.SendNotifyPageRequest page=" .. tostring(page))
    game:SendCallScriptPacket(ScriptEvent.Consignment_NotifyPageRequest, {
        page = page or 1,
    })
end

return M
