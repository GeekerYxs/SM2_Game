-- ================================================================
-- 鬼市配置辅助模块
-- 提供安全的配置数据访问接口,避免重复配置查询和验证逻辑
-- ================================================================

local Config = require "ui.dlgs.ghost_market.GhostMarketConfig"

-- ================================================================
-- 配置访问函数 - 安全获取配置数据
-- ================================================================

-- 安全获取签文配置
-- @param lotteryId 签文ID
-- @return table|nil 签文配置,不存在返回nil
local function getLotteryConfig(lotteryId)
    if not lotteryId or lotteryId <= 0 then
        return nil
    end
    return Config.LotteryConfig[lotteryId]
end

-- 安全获取运势配置
-- @param fortuneId 运势ID
-- @return table|nil 运势配置,不存在返回nil
local function getFortuneConfig(fortuneId)
    if not fortuneId or fortuneId <= 0 then
        return nil
    end
    return Config.Fortune[fortuneId]
end

-- 安全获取秘藏配置
-- @param treasureId 秘藏ID
-- @return table|nil 秘藏配置,不存在返回nil
local function getTreasureConfig(treasureId)
    if not treasureId or treasureId <= 0 then
        return nil
    end
    if treasureId > #Config.TreasurePool then
        return nil
    end
    return Config.TreasurePool[treasureId]
end

-- 安全获取贵客等级配置
-- @param guestLevel 贵客等级
-- @return table|nil 等级配置,不存在返回nil
local function getGuestLevelConfig(guestLevel)
    if not guestLevel or guestLevel <= 0 then
        return nil
    end
    return Config.GuestLevel[guestLevel]
end

-- 安全获取商品配置
-- @param goodsIndexId 商品索引ID
-- @return table|nil 商品配置,不存在返回nil
local function getGoodsConfig(goodsIndexId)
    if not goodsIndexId or goodsIndexId <= 0 then
        return nil
    end
    for _, goods in ipairs(Config.GoodsLibrary) do
        if goods.Id == goodsIndexId then
            return goods
        end
    end
end

-- 安全获取改签花费
-- @param paidTimes 已付费改签次数
-- @return number 本次的银元宝花费
local function getResignCost(paidTimes)
    if not paidTimes or paidTimes < 0 then
        return 0
    end
    
    for _, config in ipairs(Config.ResignCost) do
        if paidTimes+1 >= config.MinTimes and paidTimes+1 <= config.MaxTimes then
            return config.Cost
        end
    end
    return Config.ResignCost[#Config.ResignCost].Cost
end

-- 安全获取秘藏刷新花费
-- @param refreshTimes 已刷新次数
-- @return number,number 贵客点花费,金元宝花费
local function getTreasureRefreshCost(refreshTimes)
    if not refreshTimes or refreshTimes < 0 then
        return 0, 0
    end
    
    for _, config in ipairs(Config.TreasureRefreshCost) do
        if refreshTimes >= config.MinTimes and (config.MaxTimes == -1 or refreshTimes <= config.MaxTimes) then
            return config.PointsCost, config.GoldCost
        end
    end
    return 0, 0
end

local function getGoodMaxNum(goodId, lotteryId)
    local goodsConfig = getGoodsConfig(goodId)
    if not goodsConfig then
        return 0
    end
    local lotteryConfig = getLotteryConfig(lotteryId)
    if not lotteryConfig then
        return 0
    end
    if lotteryConfig.Fortune1 == Config.FortuneId.BUSINESS  or lotteryConfig.Fortune2 == Config.FortuneId.BUSINESS then
        return goodsConfig.StockBusiness
    else
        return goodsConfig.StockNormal
    end
end

-- ================================================================
-- 模块导出
-- ================================================================

return {
    GetLotteryConfig = getLotteryConfig,
    GetFortuneConfig = getFortuneConfig,
    GetTreasureConfig = getTreasureConfig,
    GetGuestLevelConfig = getGuestLevelConfig,
    GetGoodsConfig = getGoodsConfig,
    GetResignCost = getResignCost,
    GetTreasureRefreshCost = getTreasureRefreshCost,
    GetGoodMaxNum = getGoodMaxNum,
}