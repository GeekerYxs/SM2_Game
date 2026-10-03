-- ================================================================
-- 鬼市数据管理模块
-- 作为鬼市所有数据的单一数据源 (Single Source of Truth)
-- 所有其他模块通过此模块访问和修改鬼市数据
-- ================================================================

local ConfigHelper = require "ui.dlgs.ghost_market.ghost_market_config_helper"
local Config = require "ui.dlgs.ghost_market.GhostMarketConfig"

-- 内部数据存储，所有鬼市数据
local _data = {}

local GhostMarketData = {}

-- ================================================================
-- 基础数据操作
-- ================================================================

--- 设置鬼市数据，通常在服务器返回数据时调用
-- @param serverData table 服务器返回的鬼市数据对象
function GhostMarketData.setData(serverData)
    _data = serverData or {}
    Debug("ghost market ...")
    for k,v in pairs(_data) do
        Debug(tostring(k).."="..tostring(v))
    end
end

--- 获取完整的数据对象
-- @return table 返回内部数据的引用
function GhostMarketData.getData()
    return _data
end

--- 重置所有数据
function GhostMarketData.reset()
    _data = {}
end

-- ================================================================
-- 数据访问方法 (供UI和验证器使用)
-- ================================================================

--- 获取当前签号ID
-- @return number|nil 当前签号ID
function GhostMarketData.getLotteryId()
    return _data.lotteryId
end

--- 获取商品列表
-- @return table|nil 商品列表数组
function GhostMarketData.getGoods()
    return _data.goods
end

--- 获取指定槽位的商品数据
-- @param slotIndex 商品槽位索引 (1-12)
-- @return table|nil 商品数据对象或nil
function GhostMarketData.getGoodData(slotIndex)
    if _data.goods and _data.goods[slotIndex] then
        return _data.goods[slotIndex]
    end
    return nil
end

-- 获取节日商店列表
-- @return table|nil 商品列表数组
function GhostMarketData.getFestivalGoods()
    return _data.festivalGoods
end

-- 获取指定槽位的节日商品数据
-- @param slotIndex 商品槽位索引 (1-12)
-- @return table|nil 商品数据对象或nil
function GhostMarketData.getFestivalGoodData(slotIndex)
    if _data.festivalGoods and _data.festivalGoods[slotIndex] then
        return _data.festivalGoods[slotIndex]
    end
    return nil
end

-- 获取节日Id
-- @return number 节日Id
function GhostMarketData.getFestivalId()
    return _data.festivalId
end

--- 检查当前签运是否包含指定运势
-- @param fortuneId 运势ID
-- @return boolean 是否包含该运势
function GhostMarketData.hasFortune(fortuneId)
    if not _data or not _data.lotteryId then
        return false
    end

    local lotteryConfig = ConfigHelper.GetLotteryConfig(_data.lotteryId)
    if not lotteryConfig then
        return false
    end

    return lotteryConfig.Fortune1 == fortuneId or lotteryConfig.Fortune2 == fortuneId
end

--- 获取改签的花费
-- @return number, string 花费银元宝(钻石)数，花费描述文本
function GhostMarketData.getResignCost()
    if not _data then
        return 0, "免费"
    end

    if _data.freeResignTimes and _data.freeResignTimes > 0 then
        return 0, "免费"
    end

    local paidResignTimes = _data.paidResignTimes or 0
    if paidResignTimes >= Config.MaxPaidResignTimes then
        return -1, "已达上限"
    end

    local cost = ConfigHelper.GetResignCost(paidResignTimes)
    return cost, cost .. "钻石"
end

--- 获取刷新秘藏的花费
-- @return number, number, string 贵客点花费, 金元宝花费, 花费描述文本
function GhostMarketData.getTreasureRefreshCost()
    if not _data then
        return 0, 0, "数据错误"
    end

    local refreshTimes = _data.treasureRefreshTimes or 0
    local guestPointCost, goldIngotCost = ConfigHelper.GetTreasureRefreshCost(refreshTimes)

    local costDesc = ""
    if guestPointCost > 0 then
        costDesc = "贵客点x" .. guestPointCost
    end
    if goldIngotCost > 0 then
        if costDesc ~= "" then
            costDesc = costDesc .. " + "
        end
        costDesc = costDesc .. "金元宝x" .. goldIngotCost
    end

    if costDesc == "" then
        costDesc = "免费"
    end

    return guestPointCost, goldIngotCost, costDesc
end

-- ================================================================
-- 业务逻辑相关方法
-- ================================================================

--- 获取当前玩家的金元宝数量
-- @return number 金元宝数量
function GhostMarketData.getGoldStone()
    local dataitem = game:UIDataItem()
    if dataitem then
        return dataitem:GetGoldStone() or 0
    end
    return 0
end

-- 获取当前玩家的银元宝数量
-- @return number 银元宝数量
function GhostMarketData.getSilverStone()
    local dataitem = game:UIDataItem()
    if dataitem then
        return dataitem:GetSilverStone() or 0
    end
    return 0
end

--- 获取当前贵客等级
-- @return number 贵客等级
function GhostMarketData.getGuestLevel()
    return _data.guestLevel or 1
end

--- 获取当前贵客点
-- @return number 贵客点
function GhostMarketData.getGuestPoints()
    return _data.guestPoints or 0
end

--- 获取秘藏ID
-- @return number|nil 秘藏ID
function GhostMarketData.getTreasureId()
    return _data.treasureId
end

--- 获取秘藏进度
-- @return number 秘藏进度
function GhostMarketData.getTreasureProgress()
    return _data.treasureProgress or 0
end

--- 获取是否已上货
-- @return boolean 是否已上货
function GhostMarketData.isStocked()
    return _data.stocked and _data.stocked ~= 0
end

--- 获取免费改签次数
-- @return number 免费改签次数
function GhostMarketData.getFreeResignTimes()
    return _data.freeResignTimes or 0
end

--- 获取付费改签次数
-- @return number 付费改签次数
function GhostMarketData.getPaidResignTimes()
    return _data.paidResignTimes or 0
end

-- 获取抽签次数
-- @return number 抽签次数
function GhostMarketData.getLotteryTimes()
    return _data.lotteryTimes or 0
end

--- 获取活动开始时间
-- @return number 开始时间戳
function GhostMarketData.getStartTime()
    return _data.startTime or 0
end

--- 获取活动结束时间
-- @return number 结束时间戳
function GhostMarketData.getEndTime()
    return _data.endTime or 0
end

--- 获取秘藏已领取次数
-- @return number 已领取次数
function GhostMarketData.getTreasureClaimedTimes()
    return _data.treasureClaimedTimes or 0
end

-- ================================================================
-- 数据更新方法
-- ================================================================

--- 更新抽签结果
-- @param lotteryId number 签号ID
-- @param freeResignTimes number 免费改签次数
-- @param paidResignTimes number 付费改签次数
-- @param lotteryTimes number 抽签次数
function GhostMarketData.updateLotteryResult(lotteryId, freeResignTimes, paidResignTimes, lotteryTimes)
    _data.lotteryId = lotteryId
    _data.freeResignTimes = freeResignTimes
    _data.paidResignTimes = paidResignTimes
    _data.lotteryTimes = lotteryTimes
end

--- 更新上货结果
-- @param goods table 商品列表
-- @param festivalGoods table 节日商品列表
function GhostMarketData.updateStockResult(goods, festivalGoods)
    _data.goods = goods
    _data.festivalGoods = festivalGoods
    _data.stocked = 1
end

--- 更新购买结果
-- @param goodsIndex number 商品编号
-- @param purchaseCount number 购买数量
-- @param guestPoints number 贵客点
-- @param treasureProgress number 秘藏进度
-- @param isFestival boolean 是否是节日商品
function GhostMarketData.updateBuyResult(goodsIndexId, purchaseCount, guestPoints, treasureProgress, isFestival)
    local goodsSlot = 0
    if isFestival then
        for i, goods in pairs(_data.festivalGoods) do
            if goods.indexId == goodsIndexId then
                goodsSlot = i
            end
        end
        if goodsSlot and _data.festivalGoods and _data.festivalGoods[goodsSlot] then
            _data.festivalGoods[goodsSlot].purchaseCount = purchaseCount
        end
    else
        for i, goods in pairs(_data.goods) do
            if goods.indexId == goodsIndexId then
                goodsSlot = i
            end
        end
        if goodsSlot and _data.goods and _data.goods[goodsSlot] then
            _data.goods[goodsSlot].purchaseCount = purchaseCount
        end
    end
    _data.guestPoints = guestPoints
    _data.treasureProgress = treasureProgress
end

--- 更新刷新秘藏结果
-- @param treasureId number 秘藏ID
-- @param guestPoints number 贵客点
-- @param refreshTimes number 刷新次数
function GhostMarketData.updateRefreshTreasureResult(treasureId, guestPoints, refreshTimes)
    _data.treasureId = treasureId
    _data.guestPoints = guestPoints
    _data.treasureRefreshTimes = refreshTimes
end

--- 更新领取秘藏结果
-- @param treasureId number 秘藏ID
-- @param treasureProgress number 秘藏进度
-- @param treasureClaimedTimes number 领取次数
-- @param guestLevel number 贵客等级
-- @param guestPoints number 贵客点
function GhostMarketData.updateClaimTreasureResult(treasureId, treasureProgress, treasureClaimedTimes, guestLevel, guestPoints)
    _data.treasureId = treasureId
    _data.treasureProgress = treasureProgress
    _data.treasureClaimedTimes = treasureClaimedTimes
    _data.guestLevel = guestLevel
    _data.guestPoints = guestPoints
end

--- 重置签号ID
function GhostMarketData.resetLotteryId()
    _data.lotteryId = 0
end

return GhostMarketData