-- ================================================================
-- 鬼市购买对话框
-- 显示商品详情和确认界面，包括价格和贵客点消耗
-- ================================================================

local dlgbuilder = require "dlg_builder"
local ScriptEvent = require "script_event"
local Network = require "ui.dlgs.ghost_market.ghost_market_network"
local ConfigHelper = require "ui.dlgs.ghost_market.ghost_market_config_helper"
local Config = require "ui.dlgs.ghost_market.GhostMarketConfig"
local GhostMarketData = require "ui.dlgs.ghost_market.ghost_market_data"

local struct = require "uighostmarketbuy_struct"
local prefix_path = "UIGame/UIGhostMarket"

local _dlg = nil
local _itemData = nil
local _quantity = 1
local _isFestival = false

--- 重置数据
local function reset()
    _itemData = nil
    _quantity = 1
end

--- 设置商品信息，由外部调用时初始化对话框数据
-- @param quant number 购买数量
-- @param itemData table 商品相关数据，包含 itemIndex, goodIndex, purchaseCount 等字段
local function setBuyInfo(isFestival, quant, itemData)
    _itemData = itemData
    _quantity = quant
    _isFestival = isFestival
end

--- 刷新界面显示
-- 根据设置读取商品信息，计算价格和贵客点消耗
local function refreshView()
    if not _dlg then return end

    if not _itemData or not _itemData.itemIndex then
        _dlg.ItemIcon:SetImage("")
        _dlg.Quantity:ClearString()
        _dlg.TotalPrice:ClearString()
        _dlg.GuestPoint:ClearString()
        return
    end

    -- 从配置获取商品详细信息
    local goodsConfig = ConfigHelper.GetGoodsConfig(_itemData.goodIndex)
    if not goodsConfig then
        Debug("获取商品配置失败, goodIndex=" .. tostring(_itemData.goodIndex))
        _dlg.ItemIcon:SetImage("")
        _dlg.Quantity:ClearString()
        _dlg.TotalPrice:ClearString()
        _dlg.GuestPoint:ClearString()
        return
    end

    -- 显示商品图标
    if goodsConfig.ItemId then
        local itemInfo = game:StaticRes():GetItemInfo(goodsConfig.ItemId)
        if itemInfo then
            _dlg.ItemIcon:SetImage(itemInfo:GetImageName())
        end
    end

    -- 显示数量
    _dlg.Quantity:ClearString()
    _dlg.Quantity:AddString("#33186添购数量：#04739" .. _quantity)

    -- 根据财运(运势ID=1)判断使用哪个价格
    local hasFortuneDiscount = GhostMarketData.hasFortune(Config.FortuneId.WEALTH)  -- 财运
    local unitPrice = hasFortuneDiscount and goodsConfig.PriceFortune or goodsConfig.PriceNormal
    local totalPrice = unitPrice * _quantity

    _dlg.TotalPrice:ClearString()
    _dlg.TotalPrice:AddString("#33186应付总价：#63488" .. totalPrice .. "元宝")

    -- 根据天眷(运势ID=6)判断贵客点消耗
    local hasTianYuan = GhostMarketData.hasFortune(Config.FortuneId.BLESSING)  -- 天眷
    local pointsCost = hasTianYuan and goodsConfig.PointsBlessing or goodsConfig.PointsNormal
    pointsCost = pointsCost*_quantity

    _dlg.GuestPoint:ClearString()
    if pointsCost > 0 then
        _dlg.GuestPoint:AddString("#33186扣除贵客点：#63488" .. pointsCost)
    else
        _dlg.GuestPoint:AddString("#33186扣除贵客点：无需消耗")
    end
end

-- 发送购买命令
local function sendBuyCmd()
    if not _itemData then
        game:ShowMessage("#d60000#商品信息错误")
        return
    end

    -- 获取商品配置
    local goodsConfig = ConfigHelper.GetGoodsConfig(_itemData.goodIndex)
    if not goodsConfig then
        game:ShowMessage("#d60000#商品配置错误")
        return
    end

    -- 检查贵客等级
    if goodsConfig.RequireLevel > 0 then
        local currentLevel = GhostMarketData.getGuestLevel()
        if currentLevel < goodsConfig.RequireLevel then
            local requiredLevelConfig = Config.GuestLevel[goodsConfig.RequireLevel]
            local requiredLevelName = requiredLevelConfig and requiredLevelConfig.LevelName or ("等级" .. goodsConfig.RequireLevel)
            game:ShowMessage("#d60000#贵客等级不足，需要[" .. requiredLevelName .. "]")
            return
        end
    end

    -- 检查金元宝价格
    local hasFortuneDiscount = GhostMarketData.hasFortune(Config.FortuneId.WEALTH)
    local unitPrice = hasFortuneDiscount and goodsConfig.PriceFortune or goodsConfig.PriceNormal
    local totalPrice = unitPrice * _quantity

    if totalPrice > 0 then
        local currentGold = GhostMarketData.getGoldStone()
        if currentGold < totalPrice then
            game:ShowMessage("#d60000#金元宝不足，需要" .. totalPrice .. "金元宝")
            return
        end
    end

    -- 检查贵客点
    local hasTianYuan = GhostMarketData.hasFortune(Config.FortuneId.BLESSING)
    local pointsCost = hasTianYuan and goodsConfig.PointsBlessing or goodsConfig.PointsNormal
    pointsCost = pointsCost*_quantity

    if pointsCost > 0 then
        local currentGuestPoint = GhostMarketData.getGuestPoints()
        if currentGuestPoint < pointsCost then
            game:ShowMessage("#d60000#贵客点不足，需要" .. pointsCost .. "贵客点")
            return
        end
    end

    Debug("sendBuyCmd, goodIndex=" .. tostring(_itemData.goodIndex) .. ", quantity=" .. tostring(_quantity))
    Network.SendBuyGoodsRequest(_itemData.goodIndex, _quantity, _isFestival)

    -- 关闭对话框
    _dlg.Raw:ShowDlg(false)
end

-- 处理UI事件
local function onEventProc(luadlg, eventCode, ctrlId, ctrl)
    if eventCode == UIEventDef.TBN_CLICKED then
        if ctrlId == luadlg.Buy.CtrlID then
            -- 购买按钮
            sendBuyCmd()
        elseif ctrlId == luadlg.Close.CtrlID then
            -- 关闭按钮
            luadlg.Raw:ShowDlg(false)
        end
    elseif eventCode == UIEventDef.TIN_MOUSEMOVE then
        if ctrlId == luadlg.ItemIcon.CtrlID then
            -- 显示物品提示
            if _itemData and _itemData.itemIndex then
                local goodsConfig = ConfigHelper.GetGoodsConfig(_itemData.goodIndex)
                if goodsConfig and goodsConfig.ItemId then
                    luadlg.ItemIcon:SetTipInfo(game:GetItemTip(goodsConfig.ItemId))
                end
            end
        end
    end
end

-- 对话框显示回调
local function onShow(luadlg, show)
    if show then
        refreshView()
    else
        reset()
    end
end

-- 设置商品信息的方法，由外部对话框管理器调用
-- quant: 购买数量
-- itemData: 商品数据表，必须包含 itemIndex 字段
local function setGoodsInfo(isFestival, quant, itemData)
    setBuyInfo(isFestival, quant, itemData)
    refreshView()
end


-- 创建对话框
-- 初始化所有购买对话框实例
local function createDlg(dlgmgr)
    local luadlg = dlgbuilder(dlgmgr, struct, prefix_path, 3000)
    _dlg = luadlg

    luadlg.OnEventProc = onEventProc
    luadlg.OnShow = onShow
    luadlg.SetGoodsInfo = setGoodsInfo

    reset()
    refreshView()

    return luadlg
end

return {OnCreate = createDlg}