-- =====================================================
-- 鬼市活动系统 - 错误码定义模块
-- 统一管理所有鬼市相关的错误码常量
-- =====================================================

local ErrorCode = {}

-- =====================================================
-- 通用错误码 (-1 ~ -20)
-- =====================================================
ErrorCode.SUCCESS = 0                    -- 操作成功
ErrorCode.PLAYER_BUSY = -1               -- 玩家忙碌
ErrorCode.NOT_OPEN = -2                  -- 活动未开放
ErrorCode.PERIOD_MISMATCH = -3           -- 活动期数不一致

-- =====================================================
-- 抽签相关错误码 (-21 ~ -40)
-- =====================================================
ErrorCode.NO_LOTTERY = -21               -- 尚未抽签
ErrorCode.HAVE_LOTTERY = -22             -- 已经抽签了
ErrorCode.LOTTERY_FAILED = -23           -- 抽签失败
ErrorCode.LOTTERY_CONFIG_ERROR = -24     -- 签号配置错误
ErrorCode.RESIGN_TIMES_EXCEEDED = -25    -- 改签次数已满
ErrorCode.RESIGN_CONFIG_ERROR = -26      -- 改签配置错误
ErrorCode.NO_SILVER_FOR_RESIGN = -27     -- 银元宝不足(改签)

-- =====================================================
-- 上货相关错误码 (-41 ~ -60)
-- =====================================================
ErrorCode.NOT_STOCKED = -41              -- 尚未上货
ErrorCode.ALREADY_STOCKED = -42          -- 已经上货

-- =====================================================
-- 购买商品相关错误码 (-61 ~ -80)
-- =====================================================
ErrorCode.INVALID_SLOT = -61             -- 槽位无效
ErrorCode.NO_GOODS_IN_SLOT = -62         -- 该槽位无商品
ErrorCode.GOODS_CONFIG_ERROR = -63       -- 商品配置错误
ErrorCode.GUEST_LEVEL_INSUFFICIENT = -64 -- 贵客等级不足
ErrorCode.INVALID_PURCHASE_COUNT = -65   -- 购买数量无效
ErrorCode.INSUFFICIENT_STOCK = -66       -- 库存不足
ErrorCode.NO_BAG_SPACE = -67             -- 背包空间不足
ErrorCode.NO_GOLD = -68                  -- 金元宝不足
ErrorCode.NO_GUEST_POINTS = -69          -- 贵客点不足
ErrorCode.LOTTERY_CONFIG_ERROR_BUY = -70 -- 签号配置错误(购买)

-- =====================================================
-- 秘藏相关错误码 (-81 ~ -100)
-- =====================================================
ErrorCode.NO_TREASURE = -81              -- 没有秘藏
ErrorCode.TREASURE_CONFIG_ERROR = -82    -- 秘藏配置错误
ErrorCode.TREASURE_PROGRESS_INSUFFICIENT = -83  -- 进度不足
ErrorCode.NO_BAG_SPACE_FOR_TREASURE = -84    -- 背包空间不足(秘藏)
ErrorCode.CREATE_ITEM_FAILED = -85       -- 创建物品失败
ErrorCode.REFRESH_COST_CONFIG_ERROR = -86    -- 刷新代价配置错误
ErrorCode.NO_GUEST_POINTS_FOR_REFRESH = -87  -- 贵客点不足(刷新)
ErrorCode.NO_GOLD_FOR_REFRESH = -88          -- 金元宝不足(刷新)
ErrorCode.REFRESH_TREASURE_FAILED = -89      -- 随机秘藏失败

return ErrorCode