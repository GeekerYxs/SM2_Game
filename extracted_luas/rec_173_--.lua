-- ================================================================
-- 鬼市错误处理模块
-- 统一管理错误码和错误提示信息
-- ================================================================

local ErrorCode = require "ui.dlgs.ghost_market.GhostMarketErrorCode"

-- ================================================================
-- 错误码映射表
-- ================================================================

--- 错误码到中文描述的映射表
local errorMessages = {
    [ErrorCode.SUCCESS] = "操作成功",
    [ErrorCode.PLAYER_BUSY] = "玩家忙碌,请稍后再试",
    
    -- 活动状态相关
    [ErrorCode.NOT_OPEN] = "活动尚未开放",
    [ErrorCode.PERIOD_MISMATCH] = "活动期数不一致,请刷新界面",
    
    -- 抽签相关
    [ErrorCode.NO_LOTTERY] = "尚未抽签",
    [ErrorCode.HAVE_LOTTERY] = "已经抽签过,无法重复抽签",
    [ErrorCode.RESIGN_TIMES_EXCEEDED] = "改签次数已达上限",
    [ErrorCode.RESIGN_CONFIG_ERROR] = "改签配置错误,请联系客服",
    [ErrorCode.NO_SILVER_FOR_RESIGN] = "钻石不足,无法改签",
    [ErrorCode.LOTTERY_FAILED] = "抽签失败,请重试",
    
    -- 上货相关
    [ErrorCode.ALREADY_STOCKED] = "已经上货,无需重复操作",
    [ErrorCode.NOT_STOCKED] = "尚未上货",
    [ErrorCode.LOTTERY_CONFIG_ERROR] = "签号配置错误,请联系客服",
    
    -- 购买商品相关
    [ErrorCode.INVALID_SLOT] = "商品槽位无效",
    [ErrorCode.NO_GOODS_IN_SLOT] = "该槽位没有商品",
    [ErrorCode.GOODS_CONFIG_ERROR] = "商品配置错误,请联系客服",
    [ErrorCode.GUEST_LEVEL_INSUFFICIENT] = "贵客等级不足,无法购买",
    [ErrorCode.LOTTERY_CONFIG_ERROR_BUY] = "签号配置错误,请联系客服",
    [ErrorCode.INVALID_PURCHASE_COUNT] = "购买数量无效",
    [ErrorCode.INSUFFICIENT_STOCK] = "库存不足",
    [ErrorCode.NO_BAG_SPACE] = "背包空间不足,请清理背包",
    [ErrorCode.NO_GOLD] = "银元宝不足",
    [ErrorCode.NO_GUEST_POINTS] = "贵客点不足",
    
    -- 秘藏相关
    [ErrorCode.REFRESH_COST_CONFIG_ERROR] = "刷新代价配置错误,请联系客服",
    [ErrorCode.NO_GUEST_POINTS_FOR_REFRESH] = "贵客点不足,无法刷新秘藏",
    [ErrorCode.NO_GOLD_FOR_REFRESH] = "金元宝不足,无法刷新秘藏",
    [ErrorCode.REFRESH_TREASURE_FAILED] = "刷新秘藏失败,请重试",
    [ErrorCode.NO_TREASURE] = "没有秘藏",
    [ErrorCode.TREASURE_CONFIG_ERROR] = "秘藏配置错误,请联系客服",
    [ErrorCode.TREASURE_PROGRESS_INSUFFICIENT] = "进度不足,无法领取秘藏",
    [ErrorCode.NO_BAG_SPACE_FOR_TREASURE] = "背包空间不足,无法领取秘藏",
    [ErrorCode.CREATE_ITEM_FAILED] = "创建物品失败,请重试",
}

-- ================================================================
-- 错误处理函数
-- ================================================================

--- 根据错误码获取可读的错误信息
-- @param errorCode number 错误码
-- @return string|nil 中文错误描述字符串，成功时返回nil
local function getErrorMessage(errorCode)
    -- 成功不返回错误信息
    if errorCode == ErrorCode.SUCCESS or errorCode == 0 then
        return nil
    end
    
    -- 查找映射表
    local message = errorMessages[errorCode]
    if message then
        return message
    end
    
    -- 未知错误码返回默认提示
    return "操作失败(错误码:" .. tostring(errorCode) .. ")"
end

--- 显示错误提示
-- @param errorCode number 错误码
-- @param customMessage string|nil 自定义错误信息（可选）
local function showError(errorCode, customMessage)
    local message = customMessage or getErrorMessage(errorCode)
    if message then
        game:ShowMessage("#d60000#" .. message)
    end
end

--- 显示成功提示
-- @param message string 成功提示信息
local function showSuccess(message)
    game:ShowMessage("#ffffff#" .. message)
end

--- 显示警告提示
-- @param message string 警告提示信息
local function showWarning(message)
    game:ShowMessage("#ffff00#" .. message)
end

-- ================================================================
-- 模块导出
-- ================================================================

return {
    GetErrorMessage = getErrorMessage,
    ShowError = showError,
    ShowSuccess = showSuccess,
    ShowWarning = showWarning
}

