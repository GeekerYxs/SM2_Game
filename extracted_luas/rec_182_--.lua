-- ================================================================
-- 鬼市主对话框
-- 显示鬼市活动的主界面，包括抽签、上货、购买等功能
-- ================================================================

local dlgbuilder = require "dlg_builder"
local events = require "events"
local ScriptEvent = require "script_event"

local struct = require "uighostmarket_struct"
local prefix_path = "UIGame/UIGhostMarket"

-- 依赖模块
local GhostMarketData = require "ui.dlgs.ghost_market.ghost_market_data"
local validators = require "ui.dlgs.ghost_market.ghost_market_validators"
local uiUpdater = require "ui.dlgs.ghost_market.ghost_market_ui_updater"
local network = require "ui.dlgs.ghost_market.ghost_market_network"
local dialogManager = require "ui.dlgs.ghost_market.ghost_market_dialog_manager"
local Config = require "ui.dlgs.ghost_market.GhostMarketConfig"
local ConfigHelper = require "ui.dlgs.ghost_market.ghost_market_config_helper"
local ErrorHandler = require "ui.dlgs.ghost_market.ghost_market_error_handler"

local _dlg = nil

-- 事件ID定义
local EVENT_OPEN_UI = ScriptEvent.GhostMarket_OpenUI
local EVENT_LOTTERY_RESULT = ScriptEvent.GhostMarket_LotteryResult
local EVENT_STOCK_RESULT = ScriptEvent.GhostMarket_StockResult
local EVENT_BUY_RESULT = ScriptEvent.GhostMarket_BuyResult
local EVENT_REFRESH_TREASURE_RESULT = ScriptEvent.GhostMarket_RefreshTreasureResult
local EVENT_CLAIM_TREASURE_RESULT = ScriptEvent.GhostMarket_ClaimTreasureResult

-- 常量定义：商品槽位数量
local MAX_GOODS_SLOTS = 12

local isShowFestival = false

-- ================================================================
-- UI面板管理
-- ================================================================

--- 隐藏所有面板
local function hideAllPanels()
    if not _dlg then return end
    _dlg.NoDrawLotPanel:SetVisible(0)
    _dlg.NoDrawLotPanel:SetEnable(0)
    _dlg.DrawLotPanel:SetVisible(0)
    _dlg.DrawLotPanel:SetEnable(0)
    _dlg.NoBusinessPanel:SetVisible(0)
    _dlg.NoBusinessPanel:SetEnable(0)
    _dlg.BusinessPanel:SetVisible(0)
    _dlg.BusinessPanel:SetEnable(0)
    _dlg.TreasurePanel:SetVisible(0)
    _dlg.TreasurePanel:SetEnable(0)
end

--- 刷新视图
-- 根据当前数据状态更新界面显示
local function refreshView()
    if not _dlg then return end

    local data = GhostMarketData.getData()
    if not data then
        hideAllPanels()
        return
    end


    -- 根据状态显示不同面板
    local lotteryId = GhostMarketData.getLotteryId()
    Debug("refreshView lotteryId="..tostring(lotteryId))
    local isStocked = GhostMarketData.isStocked()

    if not lotteryId or lotteryId == 0 then
        -- 未抽签状态
        hideAllPanels()
        _dlg.NoDrawLotPanel:SetVisible(1)
        _dlg.NoDrawLotPanel:SetEnable(1)
        _dlg.NoDrawLotPanel.DrawLot:SetEnable(1)
        _dlg.NoBusinessPanel:SetVisible(1)
        _dlg.NoBusinessPanel:SetEnable(1)
        _dlg.NoBusinessPanel.StartBusiness:SetEnable(0)
        _dlg.NoBusinessPanel.EmptyTip:ClearString()
        _dlg.NoBusinessPanel.EmptyTip:AddString("无签运不起货")
        uiUpdater.UpdateNoGoodsInfo()
    elseif not isStocked then
        -- 已抽签但未上货状态
        hideAllPanels()
        _dlg.DrawLotPanel:SetVisible(1)
        _dlg.DrawLotPanel:SetEnable(1)
        _dlg.DrawLotPanel.Ding:SetVisible(0)
        uiUpdater.UpdateLotteryInfo()
        _dlg.NoBusinessPanel:SetVisible(1)
        _dlg.NoBusinessPanel:SetEnable(1)
        _dlg.NoBusinessPanel.StartBusiness:SetEnable(1)
        _dlg.NoBusinessPanel.EmptyTip:ClearString()
        _dlg.NoBusinessPanel.EmptyTip:AddString("起货即定，签运不改")
        uiUpdater.UpdateNoGoodsInfo()
    else
        -- 已上货状态
        hideAllPanels()
        _dlg.NoBusinessPanel.StartBusiness:SetEnable(0)
        -- 更新剩余时间
        _dlg.DrawLotPanel:SetVisible(1)
        _dlg.DrawLotPanel:SetEnable(1)
        _dlg.DrawLotPanel.Ding:SetVisible(1)
        uiUpdater.UpdateLotteryInfo()

        _dlg.BusinessPanel:SetVisible(1)
        _dlg.BusinessPanel:SetEnable(1)
        uiUpdater.UpdateGoodsList(isShowFestival)

        _dlg.TreasurePanel:SetVisible(1)
        _dlg.TreasurePanel:SetEnable(1)
        uiUpdater.UpdateTreasureInfo()
    end
end

--- 打开购买数量对话框
-- @param itemIndex number 商品索引(1-12)
local function openItemNumDlg(itemIndex)
    local goodData = GhostMarketData.getGoodData(itemIndex)
    if isShowFestival then
        goodData = GhostMarketData.getFestivalGoodData(itemIndex)
    end
    if not goodData then
        Debug("Invalid good data for item index: " .. itemIndex)
        return
    end

    local buyCount = goodData.purchaseCount or 0
    local lotteryId = GhostMarketData.getLotteryId()
    local maxCount = ConfigHelper.GetGoodMaxNum(goodData.indexId, lotteryId)
    Debug("maxCount=" .. maxCount .. ",buyCount=" .. buyCount)

    if buyCount >= maxCount then
        ErrorHandler.ShowWarning("已达购买上限")
        return
    end

    _dlg.OnLuaQuantDlgOK = function(quant)
        Debug("openItemNumDlg, quant=" .. tostring(quant))
        dialogManager.OpenBuyDlg(isShowFestival, itemIndex, quant)
        _dlg.OnLuaQuantDlgOK = nil
        _dlg.OnLuaQuantDlgCancel = nil
        local uimgr = game:LuaUIMgr()
        uimgr:CloseQuantDlg()
    end

    _dlg.OnLuaQuantDlgCancel = function()
        _dlg.OnLuaQuantDlgOK = nil
        _dlg.OnLuaQuantDlgCancel = nil
        local uimgr = game:LuaUIMgr()
        uimgr:CloseQuantDlg()
    end

    local uimgr = game:LuaUIMgr()
    uimgr:OpenQuantDlg(maxCount - buyCount, 1)
end

local callback = nil
local function playEffect(mov, cb)
    callback = cb
    _dlg.Effect:SetImage(prefix_path.."/"..mov)
    _dlg.Effect:SetVisible(1)
    _dlg.Effect:Rewind()
    _dlg.Effect:Play()
end

local function playEffect2(mov)
    _dlg.Effect2:SetImage(prefix_path.."/"..mov)
    _dlg.Effect2:SetVisible(1)
    _dlg.Effect2:Rewind()
    _dlg.Effect2:Play()
end


--- 显示商品提示信息
-- @param itemIndex number 商品索引(1-12)
local function showStoreItemTip(itemIndex)
    local goodData = nil
    if isShowFestival then
        goodData = GhostMarketData.getFestivalGoodData(itemIndex)
    else
        goodData = GhostMarketData.getGoodData(itemIndex)
    end
    if not goodData or not goodData.indexId or goodData.indexId<=0 then
        return
    end

    local config = ConfigHelper.GetGoodsConfig(goodData.indexId)
    if not config or not config.ItemId then
        return
    end

    local tip = game:GetItemTip(config.ItemId)

    -- 显示库存信息
    local purchaseCount = goodData.purchaseCount or 0
    local lotteryId = GhostMarketData.getLotteryId()
    local maxCount = ConfigHelper.GetGoodMaxNum(goodData.indexId, lotteryId)
    tip = tip .. "\n#13926库存：#55193 " .. (maxCount - purchaseCount) .. "/" .. maxCount

    -- 显示贵客等级要求
    if config.RequireLevel and config.RequireLevel > 0 then
        local levelConfig = ConfigHelper.GetGuestLevelConfig(config.RequireLevel)
        local levelName = levelConfig and levelConfig.LevelName or ("等级" .. config.RequireLevel)
        tip = tip .. "\n#55193成为#64925[" .. levelName .. "]#55193后可购买"
    end

    -- 显示贵客点消耗信息
    local hasTianYuan = GhostMarketData.hasFortune(Config.FortuneId.BLESSING)  -- 天眷运势
    local pointsNormal = config.PointsNormal
    local pointsWithFortune = config.PointsBlessing

    if pointsNormal > 0 or pointsWithFortune > 0 then
        if hasTianYuan and pointsNormal ~= pointsWithFortune then
            tip = tip .. "\n#55193扣除贵客点：#65504 " .. pointsNormal .. "->" .. pointsWithFortune .. "#64032(尊免运势生效)"
        else
            tip = tip .. "\n#55193扣除贵客点：#65504 " .. (hasTianYuan and pointsWithFortune or pointsNormal)
        end
    end

    -- 显示价格信息
    local hasFortuneDiscount = GhostMarketData.hasFortune(Config.FortuneId.WEALTH)  -- 财运
    local priceNormal = config.PriceNormal
    local priceWithFortune = config.PriceFortune

    if hasFortuneDiscount then
        tip = tip .. "\n#48631原价：" .. priceNormal .. " 元宝"
        tip = tip .. "\n#65184现价：" .. (hasFortuneDiscount and priceWithFortune or priceNormal) .. " 元宝"
    else
        tip = tip .. "\n#65184售价：" .. priceNormal .. " 元宝"
    end

    _dlg.BusinessPanel["Item" .. itemIndex]:SetTipInfo(tip)
end

-- 改签
local function changeLottery()
    _dlg.DrawLotPanel.ChangeLot:SetEnable(0)
    _dlg.DrawLotPanel.Fortune1:SetImage("")
    _dlg.DrawLotPanel.Fortune2:SetImage("")
    _dlg.DrawLotPanel.LotIcon:SetImage("")
    _dlg.DrawLotPanel.FortuneEffect1:ClearString()
    _dlg.DrawLotPanel.FortuneEffect2:ClearString()
    playEffect("摇签动画.mgff",function()
        network.SendLotteryRequest(true)
    end)
end

-- ================================================================
-- 事件处理
-- ================================================================

-- 处理UI控件事件
-- 响应按钮点击、鼠标移动等交互事件
local function onEventProc(luadlg, eventCode, ctrlId, ctrl)
    if eventCode == UIEventDef.TBN_CLICKED then
        -- 关闭按钮
        if ctrlId == luadlg.Close.CtrlID then
            luadlg.Raw:ShowDlg(false)
            local uimgr = game:LuaUIMgr()
            uimgr:CloseQuantDlg()
            dialogManager.CloseAllDialogs()
        -- 店规按钮
        elseif ctrlId == luadlg.ShopRulesPanel.RulesHelp.CtrlID then
            dialogManager.OpenRulesDlg()
        -- 抽签信息
        elseif ctrlId == luadlg.NoDrawLotPanel.LotHelp.CtrlID then
            dialogManager.OpenFortuneInfoDlg()
        elseif ctrlId == luadlg.DrawLotPanel.LotHelp.CtrlID then
            dialogManager.OpenFortuneInfoDlg()
        -- 抽签按钮
        elseif ctrlId == luadlg.NoDrawLotPanel.DrawLot.CtrlID then
            luadlg.NoDrawLotPanel.DrawLot:SetEnable(0)
            playEffect("摇签动画.mgff", function()
                network.SendLotteryRequest(false)
            end)
        -- 改签按钮
        elseif ctrlId == luadlg.DrawLotPanel.ChangeLot.CtrlID then
            Debug("changelottery")
            dialogManager.OpenChangeLotDlg()
        -- 开业按钮
        elseif ctrlId == luadlg.NoBusinessPanel.StartBusiness.CtrlID then
            dialogManager.OpenOpenBusinessDlg()
        -- 领取秘藏
        elseif ctrlId == luadlg.TreasurePanel.ClaimTreasure.CtrlID then
            network.SendClaimTreasureRequest()
        end
    elseif eventCode == UIEventDef.TIN_MOUSEMOVE then
        if ctrlId == luadlg.TreasurePanel.TreasureIcon.CtrlID then
            local treasureId = GhostMarketData.getTreasureId()
            local treasure = ConfigHelper.GetTreasureConfig(treasureId)
            if treasure and treasure.ItemId then
                luadlg.TreasurePanel.TreasureIcon:SetTipInfo(game:GetItemTip(treasure.ItemId))
            end
        elseif ctrlId == luadlg.GuestLevelTip.CtrlID then
            local level = GhostMarketData.getGuestLevel()
            local levelCfg = ConfigHelper.GetGuestLevelConfig(level)
            luadlg.GuestLevelTip:SetTipInfo("#64800您当前为本店["..levelCfg.LevelName.."]#65535\n#13926可享以下权益：#65535\n"..levelCfg.Tip)
        elseif ctrlId == luadlg.NoBusinessPanel.FestivalTipBG.CtrlID then
            local festivalId = GhostMarketData.getFestivalId()
            if festivalId > 0 then
                local festivalCfg = Config.Festivals[festivalId]
                luadlg.NoBusinessPanel.FestivalTipBG:SetTipInfo(festivalCfg.DetailTip or "")
            end
        else
            for i = 1, MAX_GOODS_SLOTS do
                if ctrlId == luadlg.BusinessPanel["Item" .. i].CtrlID then
                    showStoreItemTip(i)
                    break
                end
            end
        end
    elseif eventCode == UIEventDef.TTN_MOUSEMOVE then
        if ctrlId == luadlg.TreasurePanel.LevelUpTip.CtrlID then
            local level = GhostMarketData.getGuestLevel()
            local levelCfg = ConfigHelper.GetGuestLevelConfig(level+1)
            luadlg.TreasurePanel.LevelUpTip:SetTipInfo("#64800"..levelCfg.LevelName.."权益：#65535\n"..levelCfg.Tip)
        end
    elseif eventCode == UIEventDef.TIN_MOUSECLICK then
        if ctrlId == luadlg.TreasurePanel.TreasureIcon.CtrlID then
            dialogManager.OpenChangeTreasureDlg()
        elseif ctrlId == luadlg.BusinessPanel.FestivalSwitch.CtrlID then
            -- 切换节日
            local festivalId = GhostMarketData.getFestivalId()
            if festivalId > 0 then
                isShowFestival = not isShowFestival
                refreshView()
            end
        else
            for i = 1, MAX_GOODS_SLOTS do
                if ctrlId == luadlg.BusinessPanel["Item" .. i].CtrlID then
                    openItemNumDlg(i)
                    break
                end
            end
        end
    elseif eventCode==UIEventDef.TPIN_END then
        if ctrlId==luadlg.Effect.CtrlID then
            _dlg.Effect:SetVisible(0)
            if callback then
                callback()
            end
        elseif ctrlId==luadlg.Effect2.CtrlID then
            _dlg.Effect2:SetVisible(0)
        end
    end
end

-- 显示状态改变事件
-- 对话框显示或隐藏时调用
local function onShow(luadlg, show)
    if show then
        isShowFestival = false
        refreshView()
    end
end

-- 服务器回调事件处理
-- 处理来自服务器的各种事件消息
local function onCallScript(dlg, event, obj)
    Debug("ghost market onCallScript event=" .. tostring(event))

    if event == EVENT_OPEN_UI then
        GhostMarketData.setData(obj)
        for k, v in pairs(obj) do
            if type(v) ~= "table" then
                Debug(tostring(k) .. "=" .. tostring(v))
            end
        end
        dlg.Raw:ShowDlg(true)

    elseif event == EVENT_LOTTERY_RESULT then
        if obj.ret == 0 then
            Debug("lottery result lotteryId="..tostring(obj.lotteryId)..",ret="..tostring(obj.ret).. 
            ",freeResignTimes="..obj.freeResignTimes..",paidResignTimes="..obj.paidResignTimes..",lotteryTimes="..obj.lotteryTimes)
            GhostMarketData.updateLotteryResult(obj.lotteryId, obj.freeResignTimes, obj.paidResignTimes, obj.lotteryTimes)
            refreshView()
        else
            ErrorHandler.ShowError(obj.ret)
        end

    elseif event == EVENT_STOCK_RESULT then
        if obj.ret == 0 then
            GhostMarketData.updateStockResult(obj.goods, obj.festivalGoods)
            refreshView()
        else
            ErrorHandler.ShowError(obj.ret)
        end

    elseif event == EVENT_BUY_RESULT then
        if obj.ret == 0 then
            GhostMarketData.updateBuyResult(obj.goodsIndexId, obj.purchaseCount, obj.guestPoints, obj.treasureProgress, obj.isFestival)
            refreshView()
        else
            ErrorHandler.ShowError(obj.ret)
        end

    elseif event == EVENT_REFRESH_TREASURE_RESULT then
        if obj.ret == 0 then
            GhostMarketData.updateRefreshTreasureResult(obj.treasureId, obj.guestPoints, obj.refreshTimes)
            refreshView()
        else
            ErrorHandler.ShowError(obj.ret)
        end

    elseif event == EVENT_CLAIM_TREASURE_RESULT then
        if obj.ret == 0 then
            GhostMarketData.updateClaimTreasureResult(obj.treasureId, obj.treasureProgress, obj.treasureClaimedTimes, obj.guestLevel, obj.guestPoints)

            refreshView()
        else
            ErrorHandler.ShowError(obj.ret)
        end
    end
end

-- ================================================================
-- 对话框创建
-- ================================================================

--- 创建对话框
-- 初始化对话框和各个模块
local function createDlg(dlgmgr)
    local luadlg = dlgbuilder(dlgmgr, struct, prefix_path, 3000)
    _dlg = luadlg

    _dlg.TreasurePanel.ProcessBar:SetBarChangeDir(6)
    _dlg.TreasurePanel.ProcessBar:SetBarArangeDir(1)
    _dlg.ShopRulesPanel.ShopRules:SetWrap(true)
    _dlg.NoBusinessPanel.FestivalTip:SetEnable(0)

    -- 设置事件处理函数
    luadlg.OnEventProc = onEventProc
    luadlg.OnShow = onShow
    luadlg.OnCallScript = onCallScript
    luadlg.PlayEffect = playEffect
    luadlg.PlayEffect2 = playEffect2
    luadlg.ChangeLottery = changeLottery 

    -- 注册服务器事件
    HandleCallScript(EVENT_OPEN_UI, luadlg)
    HandleCallScript(EVENT_LOTTERY_RESULT, luadlg)
    HandleCallScript(EVENT_STOCK_RESULT, luadlg)
    HandleCallScript(EVENT_BUY_RESULT, luadlg)
    HandleCallScript(EVENT_REFRESH_TREASURE_RESULT, luadlg)
    HandleCallScript(EVENT_CLAIM_TREASURE_RESULT, luadlg)

    -- 初始化UI更新模块
    uiUpdater.Init(luadlg)

    -- 重置数据
    GhostMarketData.reset()
    refreshView()

    return luadlg
end

return {OnCreate = createDlg}