-- ================================================================
-- 鬼市网络请求模块
-- 负责向服务端发送各种操作请求
-- ================================================================

local ScriptEvent = require "script_event"

-- ================================================================
-- 网络请求函数 - 向服务端发送操作请求
-- ================================================================

--- 发送抽签请求到服务端
-- 用于玩家首次抽签或改签操作
-- @param isResign boolean 是否为改签操作
local function sendLotteryRequest(isResign)
    Debug("sendLotteryRequest isResign=" .. tostring(isResign))
    game:SendCallScriptPacket(ScriptEvent.GhostMarket_LotteryRequest, { isResign = isResign or false })
end

--- 发送上货请求到服务端
-- 无参数，服务端根据当前签号生成商品列表
local function sendStockRequest()
    Debug("sendStockRequest")
    game:SendCallScriptPacket(ScriptEvent.GhostMarket_StockRequest, {})
end

--- 发送购买商品请求到服务端
-- @param goodsIndexId number 商品编号
-- @param count number 购买数量
-- @param isFestival boolean 是否为节日商店
local function sendBuyGoodsRequest(goodsIndexId, count, isFestival)
    Debug("sendBuyGoodsRequest goodsIndexId=" .. tostring(goodsIndexId) .. " count=" .. tostring(count))
    game:SendCallScriptPacket(ScriptEvent.GhostMarket_BuyGoodsRequest, {
        goodsIndexId = goodsIndexId,
        count = count,
        isFestival = isFestival
    })
end

--- 发送刷新秘藏请求到服务端
-- 无参数，服务端根据刷新次数计算消耗
local function sendRefreshTreasureRequest()
    Debug("sendRefreshTreasureRequest")
    game:SendCallScriptPacket(ScriptEvent.GhostMarket_RefreshTreasureRequest, {})
end

--- 发送领取秘藏请求到服务端
-- 无参数，服务端验证进度是否足够
local function sendClaimTreasureRequest()
    Debug("sendClaimTreasureRequest")
    game:SendCallScriptPacket(ScriptEvent.GhostMarket_ClaimTreasureRequest, {})
end

-- ================================================================
-- 模块导出
-- ================================================================

return {
    SendLotteryRequest = sendLotteryRequest,
    SendStockRequest = sendStockRequest,
    SendBuyGoodsRequest = sendBuyGoodsRequest,
    SendRefreshTreasureRequest = sendRefreshTreasureRequest,
    SendClaimTreasureRequest = sendClaimTreasureRequest
}