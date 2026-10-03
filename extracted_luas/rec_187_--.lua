-- ================================================================
-- 神侍系统 - 错误处理模块（客户端）
-- 统一：错误码 -> 文案，以及成功/警告提示
-- ================================================================

local ErrorCode = require "ui.dlgs.godservant.GodServantErrorCode"

-- 源码 UTF-8，经 L() 转客户端显示编码(GBK) 后再屏显（与 consignment 一致）
local L = function(s) return game:UTF8toASCII(s) end

local errorMessages = {
    [ErrorCode.PET_NOT_FOUND]     = L("找不到该宠物，请重新打开"),
    [ErrorCode.NO_GODSERVANT]     = L("该宠物无法领悟神火之力"),
    [ErrorCode.NOT_CONTRACT]      = L("神侍需达到契约阶段才可归元"),
    [ErrorCode.NO_PRAY]           = L("当前没有可归元的祈愿"),
    [ErrorCode.NOT_ENOUGH_MONEY]  = L("金币不足，无法归元"),
    [ErrorCode.NOT_ENOUGH_GODEXP] = L("神识不足，无法归元"),
    [ErrorCode.NOT_ENOUGH_ITEM]   = L("归元材料不足"),
    [ErrorCode.LEVEL_MAX]         = L("神侍等级已达上限"),
    [ErrorCode.SYSTEM_ERR]        = L("操作失败，请稍后再试"),
    [ErrorCode.NOT_FULL_AWAKE]    = L("还有神火尚未使用，不能归元"),
}

local function getErrorMessage(errorCode)
    if errorCode == nil or errorCode == ErrorCode.SUCCESS or errorCode == 0 then
        return nil
    end
    return errorMessages[errorCode] or L("操作失败(错误码:" .. tostring(errorCode) .. ")")
end

local function showError(errorCode, customMessage)
    -- customMessage 只接受字符串；传进来的若非字符串（如整包 obj 表）则忽略，回退到错误码映射
    local message = (type(customMessage) == "string") and customMessage or getErrorMessage(errorCode)
    if message then
        game:ShowMessage("#d60000#" .. message)
    end
end

local function showSuccess(message)
    if message then game:ShowMessage("#ffffff#" .. message) end
end

local function showWarning(message)
    if message then game:ShowMessage("#ffff00#" .. message) end
end

return {
    GetErrorMessage = getErrorMessage,
    ShowError       = showError,
    ShowSuccess     = showSuccess,
    ShowWarning     = showWarning,
}
