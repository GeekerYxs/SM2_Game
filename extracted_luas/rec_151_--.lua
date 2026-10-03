-- ================================================================
-- 寄售-统一错误显示
-- ================================================================

local ErrorCode = require "ui.dlgs.consignment.ConsignmentErrorCode"

local M = {}

-- 由服务端直接屏显(ReceiveSysNotiry)通知玩家的错误码：客户端不再重复弹窗，避免双重提示。
-- 这类码服务端的屏显文案更友好（如含所需充值金额），客户端静默即可。
local SERVER_NOTIFIED = {
    [ErrorCode.E_FAIL_TOO_MANY]       = true,   -- 1036 失败次数过多（每小时限流）
    [ErrorCode.E_RECHARGE_NOT_ENOUGH] = true,   -- 1039 试营业累计充值门槛
}

--- 根据错误码弹出系统提示消息。
-- @param code number 错误码
-- @param extras table|nil 占位符替换值（例如 { required_level=70 }）
function M.ShowError(code, extras)
    if not code or code == 0 then return end
    if SERVER_NOTIFIED[code] then return end   -- 服务端已屏显通知，客户端静默
    local txt = ErrorCode.GetText(code, extras)
    if txt and #txt > 0 then
        game:ShowMessage("#d60000#" .. txt)
    end
end

--- 弹出一条普通警告（不带错误码）。
function M.ShowWarning(text)
    if text and #text > 0 then
        game:ShowMessage("#ffff00#" .. text)
    end
end

--- 弹出一条成功提示消息。
function M.ShowSuccess(text)
    if text and #text > 0 then
        game:ShowMessage("#ffffff#" .. text)
    end
end

return M
