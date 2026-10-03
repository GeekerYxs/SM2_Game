-- ================================================================
-- 鬼市UI更新模块
-- 负责更新界面显示，包括商品列表、签号运势、宝藏信息等
-- 直接使用 GhostMarketData 模块获取数据
-- ================================================================

local Config = require "ui.dlgs.ghost_market.GhostMarketConfig"
local ConfigHelper = require "ui.dlgs.ghost_market.ghost_market_config_helper"
local GhostMarketData = require "ui.dlgs.ghost_market.ghost_market_data"

local prefix_path = "UIGame/UIGhostMarket"

-- 模块内部状态
local _dlg = nil

-- ================================================================
-- 模块初始化
-- ================================================================

--- 初始化模块，设置对话框引用
-- @param dlg object 对话框对象
local function init(dlg)
    _dlg = dlg
end

-- ================================================================
-- UI更新函数
-- ================================================================

-- 更新无商品信息
local function updateNoGoodsInfo()
    -- 更新本期结束时间(只精确到小时)
    _dlg.NoBusinessPanel.RemainTime:ClearString()
    local endTime = GhostMarketData.getEndTime()
    if endTime > 0 then
        local remainSeconds = endTime - os.time()
        if remainSeconds > 0 then
            local hours = math.floor(remainSeconds / 3600)
            _dlg.NoBusinessPanel.RemainTime:AddString(string.format("距本期结束还有%d小时", hours))
        else
            _dlg.NoBusinessPanel.RemainTime:AddString("本期已结束")
        end
    end
    local festivalId = GhostMarketData.getFestivalId()
    if festivalId and festivalId > 0 then
        _dlg.NoBusinessPanel.FestivalTipBG:SetVisible(1)
        _dlg.NoBusinessPanel.FestivalTip:SetVisible(1)
        local festivalCfg = Config.Festivals[festivalId]
        _dlg.NoBusinessPanel.FestivalTip:ClearString()
        _dlg.NoBusinessPanel.FestivalTip:AddString(festivalCfg.Tip or "")
    else
        _dlg.NoBusinessPanel.FestivalTipBG:SetVisible(0)
        _dlg.NoBusinessPanel.FestivalTip:SetVisible(0)
    end
end

--- 更新商品列表UI的函数
-- 根据服务端返回的商品数据更新12个商品格子的显示
local function updateGoodsList(isShowFestival)
    local goods = nil

    if isShowFestival then
        goods = GhostMarketData.getFestivalGoods()
    else
        goods = GhostMarketData.getGoods()
    end
    if not goods then
        return
    end

    -- 按indexId排序商品列表,indexId为空或0的放到尾部
    table.sort(goods, function(a, b)
        local aId = (a and a.indexId) or 0
        local bId = (b and b.indexId) or 0
        
        -- 如果a的indexId为0,放到后面
        if aId == 0 and bId > 0 then
            return false
        end
        
        -- 如果b的indexId为0,放到后面
        if bId == 0 and aId > 0 then
            return true
        end
        
        -- 都为0或都不为0时,按indexId升序排列
        return aId < bId
    end)

    for i = 1, 12 do
        local itemCtrl = _dlg.BusinessPanel["Item" .. i]
        itemCtrl:SetTipInfo("")
        itemCtrl:SetEnable(0)
        local goodData = goods[i]
        if goodData and goodData.indexId and goodData.indexId > 0 then
            -- 先从配置表获取商品配置信息
            local goodConfig = ConfigHelper.GetGoodsConfig(goodData.indexId)
            Debug("itemId:"..tostring(goodConfig.ItemId))
            if goodConfig and goodConfig.ItemId then
                -- 再通过ItemID获取物品信息
                local itemInfo = game:StaticRes():GetItemInfo(goodConfig.ItemId)
                if itemInfo then
                    itemCtrl:SetImage(itemInfo:GetImageName())
                    itemCtrl:SetEnable(1)
                else
                    itemCtrl:SetImage("")
                end
            else
                itemCtrl:SetImage("")
            end
            -- 可以根据purchaseCount显示已购买状态
        else
            -- 清空格子
            itemCtrl:SetImage("")
        end
    end

    if GhostMarketData.getFestivalId() > 0 then
        _dlg.BusinessPanel.FestivalSwitch:SetVisible(1)
        if isShowFestival then
            _dlg.BusinessPanel.BusinessBG:SetImage(prefix_path .. "/卷轴 起货 节日.mgff")
            _dlg.BusinessPanel.GoodsContainer:SetImage(prefix_path .. "/ICON框 节日.mgff")
        else
            _dlg.BusinessPanel.BusinessBG:SetImage(prefix_path .. "/卷轴 起货.mgff")
            _dlg.BusinessPanel.GoodsContainer:SetImage(prefix_path .. "/ICON框.mgff")
        end
    else
        _dlg.BusinessPanel.FestivalSwitch:SetVisible(0)
        _dlg.BusinessPanel.BusinessBG:SetImage(prefix_path .. "/卷轴 起货.mgff")
        _dlg.BusinessPanel.GoodsContainer:SetImage(prefix_path .. "/ICON框.mgff")
    end

    -- 更新本期结束时间(只精确到小时)
    _dlg.BusinessPanel.RemainTime:ClearString()
    local endTime = GhostMarketData.getEndTime()
    if endTime > 0 then
        local remainSeconds = endTime - os.time()
        if remainSeconds > 0 then
            local hours = math.floor(remainSeconds / 3600)
            _dlg.BusinessPanel.RemainTime:AddString(string.format("距本期结束还有%d小时", hours))
        else
            _dlg.BusinessPanel.RemainTime:AddString("本期已结束")
        end
    end

    -- 更新贵客点(通过贵客等级配置获取最大值)
    local guestPoints = GhostMarketData.getGuestPoints()
    local guestLevel = GhostMarketData.getGuestLevel()
    local maxPoints = 10  -- 默认最大值
    local guestLevelConfig = ConfigHelper.GetGuestLevelConfig(guestLevel)
    if guestLevelConfig and guestLevelConfig.MaxPoints then
        maxPoints = guestLevelConfig.MaxPoints
    end
    _dlg.BusinessPanel.GuestPoint:ClearString()
    _dlg.BusinessPanel.GuestPoint:AddString(string.format("#47747贵客点:#00000 %d/%d", guestPoints, maxPoints))

    -- 更新金元宝(通过UIDataItem获取)
    local goldStone = GhostMarketData.getGoldStone()
    _dlg.BusinessPanel.GoldIngot:ClearString()
    _dlg.BusinessPanel.GoldIngot:AddString(string.format("#47747元宝额:#00000 %d", goldStone))
end

--- 更新签号和运势信息的函数
-- 显示当前抽到的签号及对应的运势效果
local function updateLotteryInfo()
    local lotteryId = GhostMarketData.getLotteryId()
    if not lotteryId or lotteryId == 0 then
        return
    end

    -- 获取签号配置
    local lotteryConfig = ConfigHelper.GetLotteryConfig(lotteryId)
    if not lotteryConfig then
        return
    end

    -- 设置签号图标
    if lotteryConfig.LotteryImg then
        local lotIconPath = prefix_path .. "/" .. lotteryConfig.LotteryImg .. ".mgff"
        _dlg.DrawLotPanel.LotIcon:SetImage(lotIconPath)
    end

    -- 处理运势1
    local fortune1Config = ConfigHelper.GetFortuneConfig(lotteryConfig.Fortune1)
    if fortune1Config then
        -- 设置运势1图标
        if fortune1Config.Img then
            _dlg.DrawLotPanel.Fortune1:SetImage(prefix_path .. "/" .. fortune1Config.Img .. ".mgff")
        end

        -- 设置运势1效果文本
        if lotteryConfig.Fortune2 ~= 0 then
            _dlg.DrawLotPanel.FortuneEffect1:ClearString()
            _dlg.DrawLotPanel.FortuneEffect1:AddString(fortune1Config.Description or "")
        else
            _dlg.DrawLotPanel.FortuneEffect1:ClearString()
            _dlg.DrawLotPanel.FortuneEffect2:ClearString()
            _dlg.DrawLotPanel.FortuneEffect2:AddString(fortune1Config.Description or "")
        end
    end

    -- 处理运势2(可选)
    local fortune2Config = ConfigHelper.GetFortuneConfig(lotteryConfig.Fortune2)
    if fortune2Config then
        -- 设置运势2图标
        if fortune2Config.Img then
            _dlg.DrawLotPanel.Fortune2:SetImage(prefix_path .. "/" .. fortune2Config.Img .. '.mgff')
        end

        -- 设置运势2效果文本
        _dlg.DrawLotPanel.FortuneEffect2:ClearString()
        _dlg.DrawLotPanel.FortuneEffect2:AddString(fortune2Config.Description or "")
    else
        -- 清空运势2显示
        _dlg.DrawLotPanel.Fortune2:SetImage(prefix_path .. "/无兆.mgff")
        --_dlg.DrawLotPanel.FortuneEffect2:ClearString()
    end

    -- 更新换签消耗提示
    _dlg.DrawLotPanel.ChangeLot:SetVisible(0)
    _dlg.DrawLotPanel.ChangeCost:ClearString()

    local freeResignTimes = GhostMarketData.getFreeResignTimes()
    local isStocked = GhostMarketData.isStocked()

    if not isStocked then
        _dlg.DrawLotPanel.ChangeLot:SetVisible(1)
        if freeResignTimes > 0 then
            _dlg.DrawLotPanel.ChangeLot:SetEnable(1)
            _dlg.DrawLotPanel.ChangeCost:AddString("免费换签次数:" .. freeResignTimes)
        else
            local paidResignTimes = GhostMarketData.getPaidResignTimes()
            if paidResignTimes >= Config.MaxPaidResignTimes then
                _dlg.DrawLotPanel.ChangeLot:SetEnable(0)
                _dlg.DrawLotPanel.ChangeCost:AddString("本期换签次数耗尽")
            else
                _dlg.DrawLotPanel.ChangeLot:SetEnable(1)
                -- 使用统一方法获取付费改签所需金元宝
                local cost = ConfigHelper.GetResignCost(paidResignTimes)
                _dlg.DrawLotPanel.ChangeCost:AddString("消耗钻石:" .. cost)
            end
        end
    end
end

--- 更新宝藏信息的函数
-- 显示当前宝藏、进度条、客点等级等信息
local function updateTreasureInfo()
    local treasureId = GhostMarketData.getTreasureId()
    if not treasureId then
        return
    end

    -- 更新宝藏图标
    local treasureConfig = ConfigHelper.GetTreasureConfig(treasureId)
    if treasureConfig then
        local itemInfo = game:StaticRes():GetItemInfo(treasureConfig.ItemId)
        if itemInfo then
            _dlg.TreasurePanel.TreasureIcon:SetImage(itemInfo:GetImageName())
            _dlg.TreasurePanel.TreasureCount:ClearString()
            if treasureConfig.ItemCount>1 then
                _dlg.TreasurePanel.TreasureCount:AddString(tostring(treasureConfig.ItemCount))
            end
        end
    end

    -- 更新进度文本和进度条
    local treasureProgress = GhostMarketData.getTreasureProgress()
    _dlg.TreasurePanel.TreasureProgress:ClearString()

    -- 从配置表获取最大进度值
    local maxProgress = 500  -- 默认值
    if treasureConfig and treasureConfig.ProgressRequire then
        maxProgress = treasureConfig.ProgressRequire
    end

    _dlg.TreasurePanel.TreasureProgress:AddString("领取进度:" .. treasureProgress .. "/" .. maxProgress)

    -- 更新进度条宽度
    if maxProgress > 0 then
        _dlg.TreasurePanel.ProcessBar:SetProcessBarDataMaxValue(maxProgress)
        _dlg.TreasurePanel.ProcessBar:SetProcessBarDataCurValue(treasureProgress)
    end

    if treasureProgress >= maxProgress then
        _dlg.TreasurePanel.ClaimTreasure:SetEnable(1)
    else
        _dlg.TreasurePanel.ClaimTreasure:SetEnable(0)
    end

    -- 更新升级提示
    local guestLevel = GhostMarketData.getGuestLevel()
    local treasureClaimedTimes = GhostMarketData.getTreasureClaimedTimes()
    _dlg.TreasurePanel.LevelUpTip:ClearString()

    -- 获取下一级贵客等级配置
    local nextLevel = guestLevel + 1
    local nextLevelConfig = ConfigHelper.GetGuestLevelConfig(nextLevel)

    if nextLevelConfig and nextLevelConfig.RequireClaimCount then
        -- 计算还需要多少次才能升级
        local remainingTimes = nextLevelConfig.RequireClaimCount - treasureClaimedTimes
        if remainingTimes > 0 then
            local tipText = string.format("#00000再领取#65504 %d #00000次可升级为本店#29075[%s]",
                remainingTimes,
                nextLevelConfig.LevelName or "")
            _dlg.TreasurePanel.LevelUpTip:AddString(tipText)
        end
    end
end

-- ================================================================
-- 模块导出
-- ================================================================

return {
    Init = init,
    UpdateGoodsList = updateGoodsList,
    UpdateNoGoodsInfo = updateNoGoodsInfo,
    UpdateLotteryInfo = updateLotteryInfo,
    UpdateTreasureInfo = updateTreasureInfo
}