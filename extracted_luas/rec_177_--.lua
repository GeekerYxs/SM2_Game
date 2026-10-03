-- ================================================================
-- 鬼市活动配置文件 (Config.lua)
-- 本文件定义鬼市活动的所有配置数据，客户端和服务端共用
-- ================================================================

local Config = {}

-- ================================================================
-- 2. 活动时间配置
-- ================================================================
-- 活动期数时间配置，每周三期
Config.ActivityTime = {
    -- 期数1: 周一 08:00:00 - 周三 00:00:00
    [1] = {
        StartWeekday = 1, -- 周一
        StartHour = 8,
        StartMinute = 0,
        StartSecond = 0,
        EndWeekday = 3, -- 周三
        EndHour = 0,
        EndMinute = 0,
        EndSecond = 0,
    },
    -- 期数2: 周三 08:00:00 - 周五 00:00:00
    [2] = {
        StartWeekday = 3, -- 周三
        StartHour = 8,
        StartMinute = 0,
        StartSecond = 0,
        EndWeekday = 5, -- 周五
        EndHour = 0,
        EndMinute = 0,
        EndSecond = 0,
    },
    -- 期数3: 周五 08:00:00 - 周日 00:00:00
    [3] = {
        StartWeekday = 5, -- 周五
        StartHour = 8,
        StartMinute = 0,
        StartSecond = 0,
        EndWeekday = 7, -- 周日
        EndHour = 23,
        EndMinute = 0,
        EndSecond = 0,
    },
}

-- ================================================================
-- 3. 贵客等级配置
-- ================================================================
-- 贵客等级配置表
-- 字段说明: LevelName=等级代称, RequireClaimCount=升级所需秘藏领取次数, RecoverPoints=每期恢复贵客点, MaxPoints=贵客点存储上限, FreeResignTimes=免费改签次数
Config.GuestLevel = {
    [1] = {
        LevelName = "新客",
        RequireClaimCount = 0,
        RecoverPoints = 6,
        MaxPoints = 12,
        FreeResignTimes = 3,
        Tip = [[· 每期开张回点：贵客点+6
· 贵客点存储上限：12
· 每期免费改签数：3次
· 每周清盘重算次数：1次
· 可购买无贵客等级要求的货品
]]
    },
    [2] = {
        LevelName = "熟客",
        RequireClaimCount = 5,
        RecoverPoints = 8,
        MaxPoints = 15,
        FreeResignTimes = 4,
        Tip = [[· 每期开张回点：贵客点+8		
· 贵客点存储上限：15
· 每期免费改签数：4次
· 签运加成：小幅增加鸿运签概率
· 每周清盘重算次数：1次
· 可购买[熟客]专享商品
]]
    },
    [3] = {
        LevelName = "尊客",
        RequireClaimCount = 17,
        RecoverPoints = 10,
        MaxPoints = 18,
        FreeResignTimes = 6,
        Tip = [[· 每期开张回点：贵客点+10		
· 贵客点存储上限：18
· 每期免费改签数：6次
· 签运加成：增加鸿运签概率
· 每周清盘重算次数：2次
· 可购买[尊客][熟客]专享商品
]]
    },
    [4] = {
        LevelName = "上宾",
        RequireClaimCount = 62,
        RecoverPoints = 12,
        MaxPoints = 21,
        FreeResignTimes = 8,
        Tip = [[· 每期开张回点：贵客点+12		
· 贵客点存储上限：21
· 每期免费改签数：8次
· 签运加成：大幅增加鸿运签概率
· 每周清盘重算次数：2次
· 可购买[上宾][尊客][熟客]专享商品
]]
},
    [5] = {
        LevelName = "合伙人",
        RequireClaimCount = 212,
        RecoverPoints = 15,
        MaxPoints = 25,
        FreeResignTimes = 10,
        Tip = [[· 每期开张回点：贵客点+15		
· 贵客点存储上限：25
· 每期免费改签数：10次
· 签运加成：大幅增加鸿运签概率
· 每周清盘重算次数：3次
· 可购买所有商品
]]
    },
}

-- ================================================================
-- 4. 改签消耗配置
-- ================================================================
-- 付费改签消耗配置
-- 字段说明: MinTimes=最小次数(含), MaxTimes=最大次数(含), Cost=银元宝消耗
Config.ResignCost = {
    [1] = { MinTimes = 1, MaxTimes = 3, Cost = 2 },
    [2] = { MinTimes = 4, MaxTimes = 6, Cost = 3 },
    [3] = { MinTimes = 7, MaxTimes = 10, Cost = 5 },
}

-- 付费改签次数上限
Config.MaxPaidResignTimes = 10

-- ================================================================
-- 5. 运势配置
-- ================================================================
-- 运势效果配置
-- 字段说明: FortuneName=运势代称, Description=效果说明
Config.Fortune = {
    [1] = { FortuneName = "惠至", Description = "商品的售价更低", Img="签 惠至" },
    [2] = { FortuneName = "见臻", Description = "稀有货品更常出现", Img="签 见臻" },
    [3] = { FortuneName = "盈仓", Description = "货品的库存更增加", Img="签 盈仓" },
    [4] = { FortuneName = "捷成", Description = "秘藏进度增长更快", Img="签 捷成" },
    [5] = { FortuneName = "添物", Description = "上架货品的种类增加", Img="签 添物" },
    [6] = { FortuneName = "尊免", Description = "稀有商品所需贵客点减少", Img="签 尊免" },
}

-- 运势ID枚举
Config.FortuneId = {
    WEALTH = 1,      -- 惠至
    RARE_GOODS = 2,  -- 见臻
    BUSINESS = 3,    -- 盈仓
    TREASURE = 4,    -- 捷成
    ABUNDANCE = 5,   -- 添物
    BLESSING = 6,    -- 尊免
}

-- ================================================================
-- 6. 抽签配置
-- ================================================================
-- 抽签配置表
-- 字段说明: LotteryName=签代称, Fortune1=运势1, Fortune2=运势2(0表示无), Weight1-5=不同贵客等级下的权重
Config.LotteryConfig = {
	
	[1] = { LotteryName = "鸿运", Fortune1 = 2, Fortune2 = 6, Weight1 = 10, Weight2 = 10, Weight3 = 12, Weight4 = 13, Weight5 = 13, LotteryImg = "运势 平运" },
	[2] = { LotteryName = "鸿运", Fortune1 = 2, Fortune2 = 5, Weight1 = 15, Weight2 = 15, Weight3 = 18, Weight4 = 20, Weight5 = 20, LotteryImg = "运势 鸿运" },
	[3] = { LotteryName = "鸿运", Fortune1 = 2, Fortune2 = 1, Weight1 = 14, Weight2 = 14, Weight3 = 16, Weight4 = 18, Weight5 = 18, LotteryImg = "运势 鸿运" },
	[4] = { LotteryName = "鸿运", Fortune1 = 1, Fortune2 = 6, Weight1 = 16, Weight2 = 19, Weight3 = 19, Weight4 = 21, Weight5 = 24, LotteryImg = "运势 鸿运" },
	[5] = { LotteryName = "鸿运", Fortune1 = 2, Fortune2 = 3, Weight1 = 19, Weight2 = 22, Weight3 = 22, Weight4 = 25, Weight5 = 28, LotteryImg = "运势 鸿运" },
	[6] = { LotteryName = "鸿运", Fortune1 = 2, Fortune2 = 4, Weight1 = 23, Weight2 = 27, Weight3 = 27, Weight4 = 31, Weight5 = 35, LotteryImg = "运势 鸿运" },
	[7] = { LotteryName = "鸿运", Fortune1 = 1, Fortune2 = 5, Weight1 = 25, Weight2 = 30, Weight3 = 30, Weight4 = 34, Weight5 = 39, LotteryImg = "运势 鸿运" },
	[8] = { LotteryName = "鸿运", Fortune1 = 1, Fortune2 = 4, Weight1 = 26, Weight2 = 31, Weight3 = 31, Weight4 = 35, Weight5 = 40, LotteryImg = "运势 鸿运" },
	[9] = { LotteryName = "鸿运", Fortune1 = 1, Fortune2 = 3, Weight1 = 28, Weight2 = 33, Weight3 = 33, Weight4 = 37, Weight5 = 42, LotteryImg = "运势 鸿运" },
	[10] = { LotteryName = "平运", Fortune1 = 1, Fortune2 = 0, Weight1 = 44, Weight2 = 44, Weight3 = 44, Weight4 = 44, Weight5 = 44, LotteryImg = "运势 平运" },
	[11] = { LotteryName = "平运", Fortune1 = 2, Fortune2 = 0, Weight1 = 48, Weight2 = 48, Weight3 = 48, Weight4 = 48, Weight5 = 48, LotteryImg = "运势 平运" },	
	[12] = { LotteryName = "顺运", Fortune1 = 6, Fortune2 = 5, Weight1 = 51, Weight2 = 51, Weight3 = 51, Weight4 = 51, Weight5 = 51, LotteryImg = "运势 顺运" },
	[13] = { LotteryName = "顺运", Fortune1 = 6, Fortune2 = 4, Weight1 = 54, Weight2 = 54, Weight3 = 54, Weight4 = 54, Weight5 = 54, LotteryImg = "运势 顺运" },
	[14] = { LotteryName = "顺运", Fortune1 = 6, Fortune2 = 3, Weight1 = 57, Weight2 = 57, Weight3 = 57, Weight4 = 57, Weight5 = 57, LotteryImg = "运势 顺运" },	
	[15] = { LotteryName = "平运", Fortune1 = 6, Fortune2 = 0, Weight1 = 64, Weight2 = 64, Weight3 = 64, Weight4 = 64, Weight5 = 64, LotteryImg = "运势 平运" },	
	[16] = { LotteryName = "顺运", Fortune1 = 5, Fortune2 = 4, Weight1 = 83, Weight2 = 83, Weight3 = 83, Weight4 = 83, Weight5 = 83, LotteryImg = "运势 顺运" },
	[17] = { LotteryName = "顺运", Fortune1 = 5, Fortune2 = 3, Weight1 = 83, Weight2 = 83, Weight3 = 83, Weight4 = 83, Weight5 = 83, LotteryImg = "运势 顺运" },	
	[18] = { LotteryName = "平运", Fortune1 = 5, Fortune2 = 0, Weight1 = 83, Weight2 = 83, Weight3 = 83, Weight4 = 83, Weight5 = 83, LotteryImg = "运势 平运" },	
	[19] = { LotteryName = "顺运", Fortune1 = 3, Fortune2 = 4, Weight1 = 83, Weight2 = 83, Weight3 = 83, Weight4 = 83, Weight5 = 83, LotteryImg = "运势 顺运" },	
	[20] = { LotteryName = "平运", Fortune1 = 4, Fortune2 = 0, Weight1 = 83, Weight2 = 83, Weight3 = 83, Weight4 = 83, Weight5 = 83, LotteryImg = "运势 平运" },	
	[21] = { LotteryName = "平运", Fortune1 = 3, Fortune2 = 0, Weight1 = 83, Weight2 = 83, Weight3 = 83, Weight4 = 83, Weight5 = 83, LotteryImg = "运势 平运" },
		
	
}



-- ================================================================
-- 7. 商品库配置
-- ================================================================
-- 商品库配置表
-- 字段说明:
--   LibraryId=推销库ID(1=基础库,10=默认高级库)
--   LibraryType=库类型("基础库"/"高级库")
--   ItemId=商品ID
--   Rarity=稀有度(1-3)
--   StockNormal=标准库存
--   StockBusiness=商运库存
--   PriceNormal=标准价格(金元宝)
--   PriceFortune=财运价格(金元宝)
--   Weight=抽取权重
--   PointsNormal=标准贵客点消耗
--   PointsBlessing=天眷贵客点消耗
--   RequireLevel=贵客等级要求(0=无要求)
Config.GoodsLibrary = {

    -- 基础库 (LibraryId = 1)
	{ Id = 1, LibraryId = 1, LibraryType = 0, ItemId = 100502, Rarity = 0, StockNormal = 10, StockBusiness = 20, PriceNormal = 8, PriceFortune = 6, Weight = 44, PointsNormal = 0, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 2, LibraryId = 1, LibraryType = 0, ItemId = 100500, Rarity = 0, StockNormal = 10, StockBusiness = 20, PriceNormal = 8, PriceFortune = 6, Weight = 44, PointsNormal = 0, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 3, LibraryId = 1, LibraryType = 0, ItemId = 100134, Rarity = 0, StockNormal = 5, StockBusiness = 10, PriceNormal = 20, PriceFortune = 16, Weight = 44, PointsNormal = 0, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 4, LibraryId = 1, LibraryType = 0, ItemId = 100039, Rarity = 0, StockNormal = 10, StockBusiness = 20, PriceNormal = 8, PriceFortune = 6, Weight = 44, PointsNormal = 0, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 5, LibraryId = 1, LibraryType = 0, ItemId = 100148, Rarity = 0, StockNormal = 5, StockBusiness = 10, PriceNormal = 30, PriceFortune = 24, Weight = 44, PointsNormal = 0, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 6, LibraryId = 1, LibraryType = 0, ItemId = 100050, Rarity = 0, StockNormal = 10, StockBusiness = 20, PriceNormal = 8, PriceFortune = 6, Weight = 44, PointsNormal = 0, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 7, LibraryId = 1, LibraryType = 0, ItemId = 32771, Rarity = 0, StockNormal = 100, StockBusiness = 200, PriceNormal = 1, PriceFortune = 1, Weight = 44, PointsNormal = 0, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 8, LibraryId = 1, LibraryType = 0, ItemId = 100536, Rarity = 0, StockNormal = 5, StockBusiness = 10, PriceNormal = 30, PriceFortune = 24, Weight = 44, PointsNormal = 0, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 9, LibraryId = 1, LibraryType = 0, ItemId = 100539, Rarity = 0, StockNormal = 5, StockBusiness = 10, PriceNormal = 30, PriceFortune = 24, Weight = 44, PointsNormal = 0, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 10, LibraryId = 1, LibraryType = 0, ItemId = 100542, Rarity = 0, StockNormal = 5, StockBusiness = 10, PriceNormal = 30, PriceFortune = 24, Weight = 44, PointsNormal = 0, PointsBlessing = 0, RequireLevel = 0 },
	
	{ Id = 11, LibraryId = 1, LibraryType = 0, ItemId = 100527, Rarity = 0, StockNormal = 10, StockBusiness = 20, PriceNormal = 10, PriceFortune = 8, Weight = 44, PointsNormal = 0, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 12, LibraryId = 1, LibraryType = 0, ItemId = 100530, Rarity = 0, StockNormal = 10, StockBusiness = 20, PriceNormal = 10, PriceFortune = 8, Weight = 44, PointsNormal = 0, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 13, LibraryId = 1, LibraryType = 0, ItemId = 100533, Rarity = 0, StockNormal = 10, StockBusiness = 20, PriceNormal = 10, PriceFortune = 8, Weight = 44, PointsNormal = 0, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 14, LibraryId = 1, LibraryType = 0, ItemId = 100090, Rarity = 0, StockNormal = 1, StockBusiness = 2, PriceNormal = 300, PriceFortune = 240, Weight = 44, PointsNormal = 0, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 15, LibraryId = 1, LibraryType = 0, ItemId = 100095, Rarity = 0, StockNormal = 2, StockBusiness = 4, PriceNormal = 100, PriceFortune = 80, Weight = 44, PointsNormal = 0, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 16, LibraryId = 1, LibraryType = 0, ItemId = 37316, Rarity = 0, StockNormal = 2, StockBusiness = 4, PriceNormal = 60, PriceFortune = 48, Weight = 44, PointsNormal = 0, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 17, LibraryId = 1, LibraryType = 0, ItemId = 37306, Rarity = 0, StockNormal = 2, StockBusiness = 4, PriceNormal = 30, PriceFortune = 24, Weight = 44, PointsNormal = 0, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 18, LibraryId = 1, LibraryType = 0, ItemId = 100501, Rarity = 1, StockNormal = 10, StockBusiness = 20, PriceNormal = 14, PriceFortune = 12, Weight = 107, PointsNormal = 0, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 19, LibraryId = 1, LibraryType = 0, ItemId = 100523, Rarity = 1, StockNormal = 15, StockBusiness = 30, PriceNormal = 11, PriceFortune = 9, Weight = 107, PointsNormal = 0, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 20, LibraryId = 1, LibraryType = 0, ItemId = 100586, Rarity = 1, StockNormal = 5, StockBusiness = 10, PriceNormal = 28, PriceFortune = 24, Weight = 107, PointsNormal = 0, PointsBlessing = 0, RequireLevel = 0 },
	
	{ Id = 21, LibraryId = 1, LibraryType = 0, ItemId = 32773, Rarity = 1, StockNormal = 5, StockBusiness = 10, PriceNormal = 28, PriceFortune = 24, Weight = 107, PointsNormal = 0, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 22, LibraryId = 1, LibraryType = 0, ItemId = 32775, Rarity = 1, StockNormal = 2, StockBusiness = 4, PriceNormal = 56, PriceFortune = 48, Weight = 107, PointsNormal = 1, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 23, LibraryId = 1, LibraryType = 0, ItemId = 100138, Rarity = 1, StockNormal = 1, StockBusiness = 2, PriceNormal = 455, PriceFortune = 410, Weight = 107, PointsNormal = 3, PointsBlessing = 2, RequireLevel = 0 },
	{ Id = 24, LibraryId = 1, LibraryType = 0, ItemId = 100140, Rarity = 1, StockNormal = 1, StockBusiness = 2, PriceNormal = 280, PriceFortune = 260, Weight = 107, PointsNormal = 2, PointsBlessing = 1, RequireLevel = 0 },
	{ Id = 25, LibraryId = 1, LibraryType = 0, ItemId = 100037, Rarity = 0, StockNormal = 3, StockBusiness = 6, PriceNormal = 80, PriceFortune = 65, Weight = 100, PointsNormal = 1, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 26, LibraryId = 1, LibraryType = 0, ItemId = 38832, Rarity = 0, StockNormal = 2, StockBusiness = 4, PriceNormal = 100, PriceFortune = 80, Weight = 50, PointsNormal = 0, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 27, LibraryId = 1, LibraryType = 0, ItemId = 100545, Rarity = 0, StockNormal = 1, StockBusiness = 2, PriceNormal = 250, PriceFortune = 200, Weight = 50, PointsNormal = 0, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 28, LibraryId = 1, LibraryType = 0, ItemId = 100548, Rarity = 0, StockNormal = 1, StockBusiness = 2, PriceNormal = 250, PriceFortune = 200, Weight = 50, PointsNormal = 0, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 29, LibraryId = 1, LibraryType = 0, ItemId = 100551, Rarity = 0, StockNormal = 1, StockBusiness = 2, PriceNormal = 250, PriceFortune = 200, Weight = 50, PointsNormal = 0, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 30, LibraryId = 1, LibraryType = 0, ItemId = 38834, Rarity = 0, StockNormal = 5, StockBusiness = 10, PriceNormal = 30, PriceFortune = 24, Weight = 50, PointsNormal = 0, PointsBlessing = 0, RequireLevel = 0 },
	
	{ Id = 31, LibraryId = 1, LibraryType = 0, ItemId = 37317, Rarity = 1, StockNormal = 1, StockBusiness = 2, PriceNormal = 140, PriceFortune = 126, Weight = 188, PointsNormal = 2, PointsBlessing = 1, RequireLevel = 0 },
	{ Id = 32, LibraryId = 1, LibraryType = 0, ItemId = 37307, Rarity = 1, StockNormal = 2, StockBusiness = 4, PriceNormal = 70, PriceFortune = 63, Weight = 188, PointsNormal = 1, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 33, LibraryId = 1, LibraryType = 0, ItemId = 37734, Rarity = 1, StockNormal = 1, StockBusiness = 2, PriceNormal = 168, PriceFortune = 152, Weight = 188, PointsNormal = 2, PointsBlessing = 1, RequireLevel = 0 },
	
	-- 高级库 (LibraryId = 10，默认高级库)	
	{ Id = 34, LibraryId = 10, LibraryType = 1, ItemId = 32535, Rarity = 0, StockNormal = 2, StockBusiness = 4, PriceNormal = 100, PriceFortune = 80, Weight = 125, PointsNormal = 2, PointsBlessing = 1, RequireLevel = 2 },
	{ Id = 35, LibraryId = 10, LibraryType = 1, ItemId = 32976, Rarity = 0, StockNormal = 3, StockBusiness = 6, PriceNormal = 70, PriceFortune = 56, Weight = 125, PointsNormal = 1, PointsBlessing = 0, RequireLevel = 2 },
	{ Id = 36, LibraryId = 10, LibraryType = 1, ItemId = 33625, Rarity = 0, StockNormal = 1, StockBusiness = 2, PriceNormal = 252, PriceFortune = 227, Weight = 125, PointsNormal = 3, PointsBlessing = 2, RequireLevel = 2 },
	{ Id = 37, LibraryId = 10, LibraryType = 1, ItemId = 33635, Rarity = 0, StockNormal = 1, StockBusiness = 2, PriceNormal = 168, PriceFortune = 152, Weight = 125, PointsNormal = 3, PointsBlessing = 2, RequireLevel = 2 },
	{ Id = 38, LibraryId = 10, LibraryType = 1, ItemId = 100100, Rarity = 0, StockNormal = 1, StockBusiness = 2, PriceNormal = 450, PriceFortune = 380, Weight = 250, PointsNormal = 3, PointsBlessing = 2, RequireLevel = 3 },
	{ Id = 39, LibraryId = 10, LibraryType = 1, ItemId = 38836, Rarity = 0, StockNormal = 2, StockBusiness = 4, PriceNormal = 220, PriceFortune = 178, Weight = 250, PointsNormal = 2, PointsBlessing = 1, RequireLevel = 3 },
	{ Id = 40, LibraryId = 10, LibraryType = 1, ItemId = 37318, Rarity = 1, StockNormal = 1, StockBusiness = 2, PriceNormal = 560, PriceFortune = 510, Weight = 250, PointsNormal = 5, PointsBlessing = 3, RequireLevel = 3 },
	
	{ Id = 41, LibraryId = 10, LibraryType = 1, ItemId = 37308, Rarity = 1, StockNormal = 2, StockBusiness = 4, PriceNormal = 280, PriceFortune = 252, Weight = 250, PointsNormal = 4, PointsBlessing = 2, RequireLevel = 3 },
	{ Id = 42, LibraryId = 10, LibraryType = 1, ItemId = 33605, Rarity = 1, StockNormal = 1, StockBusiness = 2, PriceNormal = 420, PriceFortune = 378, Weight = 125, PointsNormal = 6, PointsBlessing = 4, RequireLevel = 3 },
	{ Id = 43, LibraryId = 10, LibraryType = 1, ItemId = 33615, Rarity = 1, StockNormal = 1, StockBusiness = 2, PriceNormal = 168, PriceFortune = 152, Weight = 125, PointsNormal = 6, PointsBlessing = 4, RequireLevel = 3 },
	
	-- 基础库 (LibraryId = 1，补充可交易的升级品)		
	{ Id = 44, LibraryId = 1, LibraryType = 0, ItemId = 100587, Rarity = 0, StockNormal = 15,StockBusiness = 30, PriceNormal = 55, PriceFortune = 46, Weight = 100, PointsNormal = 0, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 45, LibraryId = 1, LibraryType = 0, ItemId = 31851, Rarity = 1, StockNormal = 1, StockBusiness = 2, PriceNormal = 500,PriceFortune = 420,Weight = 188,PointsNormal = 3, PointsBlessing = 2, RequireLevel = 0 },
	{ Id = 46, LibraryId = 1, LibraryType = 0, ItemId = 39487, Rarity = 0, StockNormal = 2, StockBusiness = 4, PriceNormal = 275,PriceFortune = 230,Weight = 100, PointsNormal = 1, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 47, LibraryId = 1, LibraryType = 0, ItemId = 39489, Rarity = 0, StockNormal = 2, StockBusiness = 4, PriceNormal = 275,PriceFortune = 230,Weight = 100, PointsNormal = 1, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 48, LibraryId = 1, LibraryType = 0, ItemId = 39491, Rarity = 0, StockNormal = 2, StockBusiness = 4, PriceNormal = 275,PriceFortune = 230,Weight = 100, PointsNormal = 1, PointsBlessing = 0, RequireLevel = 0 },
	
	-- 基础库 (LibraryId = 2，双十二节日特卖)		
	{ Id = 49, LibraryId = 2, LibraryType = 0, ItemId = 37735, Rarity = 0, StockNormal = 1, StockBusiness = 2, PriceNormal = 384, PriceFortune = 338, Weight = 26, PointsNormal = 4, PointsBlessing = 2, RequireLevel = 0 },
	{ Id = 50, LibraryId = 2, LibraryType = 0, ItemId = 100047, Rarity = 0, StockNormal = 10, StockBusiness = 20, PriceNormal = 42, PriceFortune = 37, Weight = 19, PointsNormal = 0, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 51, LibraryId = 2, LibraryType = 0, ItemId = 100137, Rarity = 0, StockNormal = 5, StockBusiness = 10, PriceNormal = 140, PriceFortune = 120, Weight = 19, PointsNormal = 0, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 52, LibraryId = 2, LibraryType = 0, ItemId = 100707, Rarity = 0, StockNormal = 10, StockBusiness = 20, PriceNormal = 20, PriceFortune = 15, Weight = 19, PointsNormal = 0, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 53, LibraryId = 2, LibraryType = 0, ItemId = 100717, Rarity = 0, StockNormal = 10, StockBusiness = 20, PriceNormal = 10, PriceFortune = 7, Weight = 19, PointsNormal = 0, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 54, LibraryId = 2, LibraryType = 0, ItemId = 100634, Rarity = 0, StockNormal = 5, StockBusiness = 10, PriceNormal = 30, PriceFortune = 25, Weight = 6, PointsNormal = 2, PointsBlessing = 1, RequireLevel = 0 },
	{ Id = 55, LibraryId = 2, LibraryType = 0, ItemId = 100590, Rarity = 0, StockNormal = 10, StockBusiness = 20, PriceNormal = 10, PriceFortune = 8, Weight = 13, PointsNormal = 2, PointsBlessing = 1, RequireLevel = 0 },
	{ Id = 56, LibraryId = 2, LibraryType = 0, ItemId = 100588, Rarity = 0, StockNormal = 5, StockBusiness = 10, PriceNormal = 48, PriceFortune = 42, Weight = 13, PointsNormal = 2, PointsBlessing = 1, RequireLevel = 0 },
	{ Id = 57, LibraryId = 2, LibraryType = 0, ItemId = 30099, Rarity = 0, StockNormal = 3, StockBusiness = 6, PriceNormal = 20, PriceFortune = 14, Weight = 13, PointsNormal = 2, PointsBlessing = 1, RequireLevel = 2 },
	{ Id = 58, LibraryId = 2, LibraryType = 0, ItemId = 100074, Rarity = 1, StockNormal = 1, StockBusiness = 2, PriceNormal = 350, PriceFortune = 280, Weight = 37, PointsNormal = 2, PointsBlessing = 1, RequireLevel = 2 },
	{ Id = 59, LibraryId = 2, LibraryType = 0, ItemId = 100079, Rarity = 1, StockNormal = 1, StockBusiness = 2, PriceNormal = 350, PriceFortune = 280, Weight = 37, PointsNormal = 2, PointsBlessing = 1, RequireLevel = 2 },
	{ Id = 60, LibraryId = 2, LibraryType = 0, ItemId = 100591, Rarity = 1, StockNormal = 2, StockBusiness = 4, PriceNormal = 120, PriceFortune = 100, Weight = 75, PointsNormal = 1, PointsBlessing = 0, RequireLevel = 2 },
	
	-- 高级库 (LibraryId = 12，双十二高级库)		
	{ Id = 61, LibraryId = 12, LibraryType = 1, ItemId = 100502, Rarity = 0, StockNormal = 50, StockBusiness = 100, PriceNormal = 5, PriceFortune = 4, Weight = 23, PointsNormal = 0, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 62, LibraryId = 12, LibraryType = 1, ItemId = 100500, Rarity = 0, StockNormal = 50, StockBusiness = 100, PriceNormal = 5, PriceFortune = 4, Weight = 23, PointsNormal = 0, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 63, LibraryId = 12, LibraryType = 1, ItemId = 100718, Rarity = 0, StockNormal = 5, StockBusiness = 10, PriceNormal = 80, PriceFortune = 68, Weight = 34, PointsNormal = 1, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 64, LibraryId = 12, LibraryType = 1, ItemId = 32538, Rarity = 0, StockNormal = 1, StockBusiness = 2, PriceNormal = 450, PriceFortune = 380, Weight = 23, PointsNormal = 3, PointsBlessing = 2, RequireLevel = 0 },
	{ Id = 65, LibraryId = 12, LibraryType = 1, ItemId = 100589, Rarity = 0, StockNormal = 2, StockBusiness = 4, PriceNormal = 500, PriceFortune = 400, Weight = 23, PointsNormal = 1, PointsBlessing = 0, RequireLevel = 0 },
	{ Id = 66, LibraryId = 12, LibraryType = 1, ItemId = 121002, Rarity = 0, StockNormal = 1, StockBusiness = 2, PriceNormal = 30, PriceFortune = 25, Weight = 11, PointsNormal = 4, PointsBlessing = 2, RequireLevel = 0 },
	{ Id = 67, LibraryId = 12, LibraryType = 1, ItemId = 121005, Rarity = 0, StockNormal = 1, StockBusiness = 2, PriceNormal = 30, PriceFortune = 25, Weight = 11, PointsNormal = 4, PointsBlessing = 2, RequireLevel = 0 },
	{ Id = 68, LibraryId = 12, LibraryType = 1, ItemId = 120502, Rarity = 1, StockNormal = 1, StockBusiness = 2, PriceNormal = 750, PriceFortune = 600, Weight = 12, PointsNormal = 5, PointsBlessing = 3, RequireLevel = 2 },
	{ Id = 69, LibraryId = 12, LibraryType = 1, ItemId = 120506, Rarity = 1, StockNormal = 1, StockBusiness = 2, PriceNormal = 750, PriceFortune = 600, Weight = 12, PointsNormal = 5, PointsBlessing = 3, RequireLevel = 2 },
	{ Id = 70, LibraryId = 12, LibraryType = 1, ItemId = 120510, Rarity = 1, StockNormal = 1, StockBusiness = 2, PriceNormal = 750, PriceFortune = 600, Weight = 12, PointsNormal = 5, PointsBlessing = 3, RequireLevel = 2 },
	{ Id = 71, LibraryId = 12, LibraryType = 1, ItemId = 120514, Rarity = 1, StockNormal = 1, StockBusiness = 2, PriceNormal = 750, PriceFortune = 600, Weight = 12, PointsNormal = 5, PointsBlessing = 3, RequireLevel = 2 },
	{ Id = 72, LibraryId = 12, LibraryType = 1, ItemId = 120518, Rarity = 1, StockNormal = 1, StockBusiness = 2, PriceNormal = 750, PriceFortune = 600, Weight = 12, PointsNormal = 5, PointsBlessing = 3, RequireLevel = 2 },
	{ Id = 73, LibraryId = 12, LibraryType = 1, ItemId = 120522, Rarity = 1, StockNormal = 1, StockBusiness = 2, PriceNormal = 750, PriceFortune = 600, Weight = 12, PointsNormal = 5, PointsBlessing = 3, RequireLevel = 2 },
	{ Id = 74, LibraryId = 12, LibraryType = 1, ItemId = 121003, Rarity = 1, StockNormal = 1, StockBusiness = 2, PriceNormal = 100, PriceFortune = 80, Weight = 37, PointsNormal = 4, PointsBlessing = 2, RequireLevel = 3 },
	{ Id = 75, LibraryId = 12, LibraryType = 1, ItemId = 121006, Rarity = 1, StockNormal = 1, StockBusiness = 2, PriceNormal = 100, PriceFortune = 80, Weight = 37, PointsNormal = 4, PointsBlessing = 2, RequireLevel = 3 },
	
	-- 基础库 (LibraryId = 1，补充可交易耗材)		
	{ Id = 76, LibraryId = 1, LibraryType = 0, ItemId = 100721, Rarity = 1, StockNormal = 5, StockBusiness = 10, PriceNormal = 120, PriceFortune = 90, Weight = 250, PointsNormal = 2, PointsBlessing = 1, RequireLevel = 3 },	
	
	-- 高级库 (LibraryId = 10，补充可交易耗材)		
	{ Id = 77, LibraryId = 10, LibraryType = 1, ItemId = 100720, Rarity = 1, StockNormal = 5, StockBusiness = 10, PriceNormal = 160, PriceFortune = 120, Weight = 350, PointsNormal = 2, PointsBlessing = 1, RequireLevel = 3 },
	
	-- 高级库 (LibraryId = 1，补充可交易耗材\假面王的印章I\孽妖女的魔药I\瓦鲁的圣甲虫I)		
	{ Id = 78, LibraryId = 10, LibraryType = 1, ItemId = 100726, Rarity = 0, StockNormal = 4, StockBusiness = 8, PriceNormal = 30, PriceFortune = 20, Weight = 40, PointsNormal = 1, PointsBlessing = 0, RequireLevel = 3 },	
	{ Id = 79, LibraryId = 10, LibraryType = 1, ItemId = 100731, Rarity = 0, StockNormal = 4, StockBusiness = 8, PriceNormal = 30, PriceFortune = 20, Weight = 40, PointsNormal = 1, PointsBlessing = 0, RequireLevel = 3 },
	{ Id = 80, LibraryId = 10, LibraryType = 1, ItemId = 100736, Rarity = 0, StockNormal = 4, StockBusiness = 8, PriceNormal = 30, PriceFortune = 20, Weight = 40, PointsNormal = 1, PointsBlessing = 0, RequireLevel = 3 },	
}

Config.DefaultHighLibraryId = 10
Config.DefaultNormalLibraryId = 1

-- ================================================================
-- 8. 秘藏池配置
-- ================================================================
-- 秘藏池配置表
-- 字段说明: ItemId=奖励物品ID, ItemCount=奖励数量, Rarity=稀有度(1-3), ProgressRequire=进度需求, Weight=抽取权重
Config.TreasurePool = {

	{ Id = 1,  ItemId = 32538, ItemCount = 1, Rarity = 1, ProgressRequire = 2500, Weight = 65 },
	{ Id = 2,  ItemId = 38842, ItemCount = 1, Rarity = 1, ProgressRequire = 4000, Weight = 87 },
	{ Id = 3,  ItemId = 33604, ItemCount = 1, Rarity = 1, ProgressRequire = 1000, Weight = 19 },
	{ Id = 4,  ItemId = 33614, ItemCount = 2, Rarity = 1, ProgressRequire = 1000, Weight = 69 },
	{ Id = 5,  ItemId = 33624, ItemCount = 1, Rarity = 1, ProgressRequire = 600,  Weight = 19 },
	{ Id = 6,  ItemId = 33634, ItemCount = 2, Rarity = 1, ProgressRequire = 1000, Weight = 46 },
	{ Id = 7,  ItemId = 38502, ItemCount = 1, Rarity = 1, ProgressRequire = 600,  Weight = 46 },
	{ Id = 8,  ItemId = 38500, ItemCount = 5, Rarity = 1, ProgressRequire = 1200, Weight = 76 },
	{ Id = 9,  ItemId = 100590, ItemCount = 4, Rarity = 1, ProgressRequire = 700,  Weight = 46 },
	{ Id = 10, ItemId = 100161, ItemCount = 1, Rarity = 1, ProgressRequire = 1000, Weight = 56 },
	
	{ Id = 11, ItemId = 100162, ItemCount = 1, Rarity = 1, ProgressRequire = 1000, Weight = 56 },
	{ Id = 12, ItemId = 100163, ItemCount = 1, Rarity = 1, ProgressRequire = 1000, Weight = 56 },
	{ Id = 13, ItemId = 100074, ItemCount = 1, Rarity = 1, ProgressRequire = 3000, Weight = 164 },
	{ Id = 14, ItemId = 100079, ItemCount = 1, Rarity = 1, ProgressRequire = 2400, Weight = 65 },
	{ Id = 15, ItemId = 11532, ItemCount = 2, Rarity = 1, ProgressRequire = 2400, Weight = 131 },
	{ Id = 16, ItemId = 11534, ItemCount = 3, Rarity = 1, ProgressRequire = 1000, Weight = 69 },
	{ Id = 17, ItemId = 30092, ItemCount = 3, Rarity = 1, ProgressRequire = 800,  Weight = 69 },
	{ Id = 18, ItemId = 37790, ItemCount = 1, Rarity = 1, ProgressRequire = 1300, Weight = 41 },
	{ Id = 19, ItemId = 33303, ItemCount = 1, Rarity = 1, ProgressRequire = 1300, Weight = 76 },
	{ Id = 20, ItemId = 33092, ItemCount = 1, Rarity = 1, ProgressRequire = 1300, Weight = 41 },
	
	{ Id = 21, ItemId = 100034, ItemCount = 8, Rarity = 1, ProgressRequire = 400,  Weight = 46 },
	{ Id = 22, ItemId = 32450, ItemCount = 1, Rarity = 1, ProgressRequire = 1000, Weight = 25 },
	{ Id = 23, ItemId = 32460, ItemCount = 1, Rarity = 1, ProgressRequire = 1000, Weight = 25 },
	{ Id = 24, ItemId = 32470, ItemCount = 1, Rarity = 1, ProgressRequire = 1000, Weight = 41 },
	{ Id = 25, ItemId = 32480, ItemCount = 1, Rarity = 1, ProgressRequire = 1300, Weight = 76 },
	{ Id = 26, ItemId = 39375, ItemCount = 3, Rarity = 1, ProgressRequire = 800,  Weight = 19 },
	{ Id = 27, ItemId = 39376, ItemCount = 1, Rarity = 1, ProgressRequire = 1000, Weight = 25 },
	{ Id = 28, ItemId = 100587, ItemCount = 2, Rarity = 1, ProgressRequire = 600,  Weight = 46 },
	{ Id = 29, ItemId = 101003, ItemCount = 1, Rarity = 1, ProgressRequire = 5500, Weight = 164 },
	{ Id = 30, ItemId = 100588, ItemCount = 2, Rarity = 1, ProgressRequire = 3200, Weight = 131 },
	
	{ Id = 31, ItemId = 37371, ItemCount = 1, Rarity = 1, ProgressRequire = 4000, Weight = 87 },

	
}
	
-- ================================================================
-- 9. 秘藏刷新代价配置
-- ================================================================
-- 秘藏刷新代价配置表
-- 字段说明: MinTimes=最小次数(含), MaxTimes=最大次数(含,-1表示无上限), PointsCost=贵客点消耗, GoldCost=金元宝消耗
Config.TreasureRefreshCost = {
    [1] = { MinTimes = 0, MaxTimes = 5, PointsCost = 1, GoldCost = 0 },
    [2] = { MinTimes = 6, MaxTimes = 10, PointsCost = 2, GoldCost = 0 },
    [3] = { MinTimes = 11, MaxTimes = -1, PointsCost = 2, GoldCost = 10 },
}

-- 最小充值元宝
Config.MinRecharge = 1000

-- 最小修炼等级
Config.MinXiulianLevel = 20

-- 累计充值
Config.MinTotalRecharge = 5000

-- 最大重置市场次数
Config.MaxResetMarketCounts = {
	[1] = 1,
	[2] = 1,
	[3] = 2,
	[4] = 2,
	[5] = 3,
}

-- 重置市场所需道具id1
Config.ResetMarketItemId1 = 39641
-- 重置市场所需道具id2
Config.ResetMarketItemId2 = 39640

-- 节日配置
Config.Festivals = {
	{ Id = 1, Name = "双旦购物节", Start= "2025/12/26 00:00:00", End = "2026/1/1 23:59:59", BaseLibraryId = 2, HighLibraryId = 12, Tip= "#99FFCC#本期加开#FFFF00#[双旦]#99FFCC#特卖", EntryTip="#CBFFFF#如今正逢双旦，本掌柜特地挑选了些应景好物。客官可随缘挑日常货，也可直奔节日专柜", DetailTip="#9DC3E6#本期“定运起货”将额外开启#FFFF00#双旦特卖#9DC3E6#。包含不限于以下稀有品：\n #FFF2CC#腐化系列宠装  古老者遗物 \n 神牌进阶秘材  神装合成材料 \n\n#CC99FF#掌柜提示：\n节日特卖货品同样受签运影响" },
}

return Config