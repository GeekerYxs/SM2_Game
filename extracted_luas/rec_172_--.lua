-- ================================================================
-- 鬼市对话框管理模块
-- 负责打开各种子对话框
-- 直接使用 GhostMarketData 模块获取数据
-- ================================================================

local ScriptEvent = require "script_event"
local validators = require "ui.dlgs.ghost_market.ghost_market_validators"
local Config = require "ui.dlgs.ghost_market.GhostMarketConfig"
local ConfigHelper = require "ui.dlgs.ghost_market.ghost_market_config_helper"
local GhostMarketData = require "ui.dlgs.ghost_market.ghost_market_data"

-- ================================================================
-- 辅助函数
-- ================================================================

--- 获取LuaUIMgr实例
-- @return object|nil UI管理器实例，失败返回nil
local function getLuaUIMgr()
    local mgr = game:LuaUIMgr()
    if not mgr then
        Debug("LuaUIMgr not found")
        return nil
    end
    return mgr
end

--- 打开指定对话框
-- @param dialogName string 对话框名称
-- @return object|nil 返回对话框对象
local function openDialog(dialogName)
    local mgr = getLuaUIMgr()
    if not mgr then
        return nil
    end

    local dlg = mgr:FindDlg(dialogName)
    if dlg then
        dlg:ShowDlg(true)
        return dlg
    else
        Debug(dialogName .. " dialog not found")
        return nil
    end
end

-- ================================================================
-- 对话框打开函数
-- ================================================================

--- 打开改签对话框
-- 验证改签条件是否满足,包括免费次数、付费次数限制和金元宝余额
local function openChangeLotDlg()
    -- 验证活动状态
    if not validators.ValidateActivity() then
        return
    end

    -- 检查是否已上货
    if GhostMarketData.isStocked() then
        game:ShowMessage("#d60000#已上货后无法改签")
        return
    end

    -- 检查是否还有免费改签次数
    local freeResignTimes = GhostMarketData.getFreeResignTimes()
    local hasFreeCount = freeResignTimes > 0

    if not hasFreeCount then
        -- 没有免费次数，需要检查付费改签
        local paidResignTimes = GhostMarketData.getPaidResignTimes()

        -- 检查付费改签次数是否已达上限(10次)
        if paidResignTimes >= Config.MaxPaidResignTimes then
            game:ShowMessage("#d60000#今日改签次数已达上限")
            return
        end

        -- 计算付费改签需要的金元宝
        local cost = ConfigHelper.GetResignCost(paidResignTimes)

        -- 检查金元宝是否足够
        local goldStone = GhostMarketData.getSilverStone()
        if goldStone < cost then
            game:ShowMessage("#d60000#钻石不足，需要" .. cost .. "个")
            return
        end
    end

    -- 打开对话框，对话框内部会自动从 GhostMarketData 获取数据
    openDialog("GhostMarketChangeFortune")
end

--- 开上货确认对话框
local function openOpenBusinessDlg()
    -- 验证活动状态
    if not validators.ValidateActivity() then
        return
    end
    openDialog("GhostMarketOpenBusiness")
end

--- 打开系统规则功能对话框
local function openRulesDlg()
    openDialog("GhostMarketInfo")
end

--- 打开财运说明对话框
local function openFortuneInfoDlg()
    openDialog("GhostMarketFortuneInfo")
end

--- 打开更换宝藏确认对话框
local function openChangeTreasureDlg()
    -- 验证活动状态和上货状态
    if not validators.ValidateActivity() or not validators.ValidateBusiness() then
        return
    end

    -- 打开对话框，对话框内部会自动从 GhostMarketData 获取数据
    openDialog("GhostMarketChangeTreasure")
end

--- 打开购买对话框
--- @param isFestival boolean 是否为节日商店
-- @param itemIndex number 商品索引(1-12)
-- @param quant number 购买数量
local function openBuyDlg(isFestival, itemIndex, quant)
    -- 验证活动状态和上货状态
    if not validators.ValidateActivity() or not validators.ValidateBusiness() then
        return
    end

    -- 验证商品索引
    if not validators.ValidateItemIndex(itemIndex) then
        Debug("Invalid item index for buy dialog: " .. tostring(itemIndex))
        return
    end

    local mgr = getLuaUIMgr()
    if not mgr then
        return
    end

    local buyDlg = mgr:FindDlg("GhostMarketBuy")
    if buyDlg then
        local goods = GhostMarketData.getGoods()
        if isFestival then
            goods = GhostMarketData.getFestivalGoods()
        end
        if not goods then
            Debug("Ghost market goods not available")
            return
        end

        local luadlg = FindLuaDlg(buyDlg)
        if not luadlg then
            Debug("Failed to get lua dialog for GhostMarketBuy")
            return
        end

        local goodData = goods[itemIndex]
        if goodData and goodData.indexId and goodData.indexId > 0 then
            -- 根据配置表获取商品配置
            local goodsConfig = ConfigHelper.GetGoodsConfig(goodData.indexId)
            if goodsConfig then
                -- 设置商品信息并打开对话框，对话框内部会自动从 ghostMarketData 获取数据
                luadlg.SetGoodsInfo(isFestival, quant, {
                    goodIndex = goodData.indexId,
                    itemIndex = itemIndex,
                    purchaseCount = goodData.purchaseCount or 0,
                })
            else
                Debug("Goods config not found for indexId: " .. tostring(goodData.indexId))
            end
        else
            Debug("Invalid goods data for item index: " .. tostring(itemIndex))
        end

        buyDlg:ShowDlg(true)
    else
        Debug("UIGhostMarketBuy dialog not found")
    end
end

--- 关闭所有鬼市相关对话框
local function closeAllDialogs()
    local mgr = getLuaUIMgr()
    if not mgr then
        return
    end

    -- 定义所有鬼市相关对话框名称
    local dialogNames = {
        "GhostMarketChangeFortune", -- 改签对话框
        "GhostMarketOpenBusiness",  -- 上货确认对话框
        "GhostMarketInfo",          -- 系统规则对话框
        "GhostMarketFortuneInfo",   -- 财运说明对话框
        "GhostMarketChangeTreasure",-- 更换秘藏对话框
        "GhostMarketBuy",           -- 购买对话框
    }

    -- 逐个关闭对话框
    for _, dialogName in ipairs(dialogNames) do
        local dlg = mgr:FindDlg(dialogName)
        if dlg then
            dlg:ShowDlg(false)
        end
    end
end

-- ================================================================
-- 模块导出
-- ================================================================

return {
    OpenChangeLotDlg = openChangeLotDlg,
    OpenOpenBusinessDlg = openOpenBusinessDlg,
    OpenRulesDlg = openRulesDlg,
    OpenFortuneInfoDlg = openFortuneInfoDlg,
    OpenChangeTreasureDlg = openChangeTreasureDlg,
    OpenBuyDlg = openBuyDlg,
    CloseAllDialogs = closeAllDialogs,
}