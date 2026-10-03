-- ================================================================
-- 鬼市验证模块
-- 提供统一的前置条件验证功能,包括活动状态、抽签状态、上货状态等
-- 直接使用 GhostMarketData 模块获取数据，无需外部传入
-- ================================================================

local GhostMarketData = require "ui.dlgs.ghost_market.ghost_market_data"

-- ================================================================
-- 数据与状态检查函数
-- ================================================================

--- 检查活动是否开放
-- @return boolean 活动是否开放
local function isActivityOpen()
    local startTime = GhostMarketData.getStartTime()
    local endTime = GhostMarketData.getEndTime()

    if startTime == 0 or endTime == 0 then
        return false
    end

    local currentTime = dtNowTime()
    Debug("isActivityOpen currentTime=" .. tostring(currentTime) ..
          ",startTime=" .. tostring(startTime) ..
          ",endTime=" .. tostring(endTime))
    return currentTime >= startTime and currentTime < endTime
end

--- 获取剩余时间（小时）
-- @return number 剩余小时数
local function getRemainHours()
    local endTime = GhostMarketData.getEndTime()
    if endTime == 0 then
        return 0
    end

    local currentTime = dtNowTime()
    local remainSeconds = endTime - currentTime
    return math.max(0, math.floor(remainSeconds / 3600))
end

-- ================================================================
-- 验证辅助函数 - 提供统一的前置条件检查
-- ================================================================

--- 验证活动是否开放,未开放时显示提示
-- @return boolean 活动是否开放
local function validateActivity()
    if not isActivityOpen() then
        game:ShowMessage("#d60000#活动未开放")
        return false
    end
    return true
end

--- 验证是否已抽签,未抽签时显示提示
-- @return boolean 是否已抽签
local function validateLottery()
    local lotteryId = GhostMarketData.getLotteryId()
    if not lotteryId or lotteryId == 0 then
        game:ShowMessage("#d60000#请先抽签")
        return false
    end
    return true
end

--- 验证是否已上货,未上货时显示提示
-- @return boolean 是否已上货
local function validateBusiness()
    if not GhostMarketData.isStocked() then
        game:ShowMessage("#d60000#请先上货")
        return false
    end
    return true
end

--- 验证商品索引是否有效
-- @param itemIndex number 商品索引(1-12)
-- @return boolean 索引是否有效
local function validateItemIndex(itemIndex)
    if not itemIndex or itemIndex < 1 or itemIndex > 12 then
        Debug("Invalid item index: " .. tostring(itemIndex))
        return false
    end
    return true
end

--- 验证UI控件是否存在
-- @param ctrl object 控件对象
-- @param ctrlName string 控件名称(用于调试)
-- @return boolean 控件是否存在
local function validateUIControl(ctrl, ctrlName)
    if not ctrl then
        Debug("UI control not found: " .. tostring(ctrlName))
        return false
    end
    return true
end

-- ================================================================
-- 模块导出
-- ================================================================

return {
    IsActivityOpen = isActivityOpen,
    GetRemainHours = getRemainHours,
    ValidateActivity = validateActivity,
    ValidateLottery = validateLottery,
    ValidateBusiness = validateBusiness,
    ValidateItemIndex = validateItemIndex,
    ValidateUIControl = validateUIControl
}