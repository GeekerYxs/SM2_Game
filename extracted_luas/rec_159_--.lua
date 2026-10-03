-- ================================================================
-- 寄售-错误码定义
-- ================================================================

local Strings = require "ui.dlgs.consignment.consignment_strings"

local ErrorCode = {
    -- 业务拒绝（1000-1035）
    E_SYSTEM_STARTING            = 1000,
    E_SYSTEM_CLOSED              = 1001,
    E_IN_DAILY_CLOSE             = 1002,
    E_PLAYER_BLACKLIST           = 1003,
    E_LEVEL_TOO_LOW              = 1004,
    E_DAILY_APPLY_LIMIT          = 1005,
    E_DAILY_CANCEL_LIMIT         = 1006,
    E_CONCURRENT_LIMIT           = 1007,
    E_ITEM_NOT_TRADABLE          = 1008,
    E_ITEM_FROM_CAR              = 1009,
    E_COUNT_EXCEED_STACK         = 1010,
    E_COIN_NOT_ENOUGH            = 1011,
    E_YUANBAO_NOT_ENOUGH         = 1012,
    E_SECRET_MISMATCH            = 1013,
    E_SECRET_FORMAT              = 1014,
    E_BUY_SELF                   = 1015,
    E_DAILY_BUY_FAIL_LIMIT       = 1016,
    E_DAILY_BUY_COUNT_LIMIT      = 1017,
    E_DAILY_PAY_LIMIT            = 1018,
    E_ORDER_NOT_FOUND            = 1019,
    E_ORDER_FROZEN               = 1020,
    E_ORDER_STATE_MISMATCH       = 1021,
    E_CLAIM_ALREADY_DONE         = 1022,
    E_BACKPACK_FULL              = 1023,
    E_DAILY_CLAIM_ITEM_FAIL      = 1024,
    E_DAILY_CLAIM_YUANBAO_FAIL   = 1025,
    E_PLAYER_BUSY                = 1026,
    E_SLOT_NOT_FOUND             = 1027,
    E_COUNT_EXCEED_SLOT          = 1028,
    E_PRICE_OUT_OF_RANGE         = 1029,
    E_CLAIM_TYPE_INVALID         = 1030,
    E_PAGE_MODE_INVALID          = 1031,
    E_PAGE_INVALID               = 1032,
    E_SORT_INVALID               = 1033,
    E_ITEM_ID_INVALID            = 1034,
    E_IDENTITY_INVALID           = 1035,
    E_FAIL_TOO_MANY              = 1036,    -- 失败次数过多（每小时内存限流）：由服务端屏显(ReceiveSysNotiry)通知玩家，客户端不再弹窗（见 consignment_error_handler.SERVER_NOTIFIED）
    E_REQUEST_TOO_FREQUENT       = 1038,    -- 浏览请求过快（搜索/翻页/刷新 共用冷却；服务端兜底节流回包用，客户端本地预拦截也复用此文案）
    E_RECHARGE_NOT_ENOUGH        = 1039,    -- 试营业·账号累计充值未达门槛：由服务端屏显(ReceiveSysNotiry)通知玩家（含所需金额），客户端不再弹窗（见 consignment_error_handler.SERVER_NOTIFIED）
    E_ITEM_BOUND                 = 1040,    -- 物品已绑定，不可寄售
    E_ITEM_SOUL_BOUND            = 1041,    -- 物品已灵魂绑定（共生强化），不可寄售
    E_ITEM_HAS_FRAGMENT          = 1042,    -- 物品镶有圣器/神体碎片，不可寄售

    -- 致命错误（1900+）
    E_COARSE_AUDIT_FAIL          = 1900,
    E_DB_WRITE_FAIL              = 1901,
    E_STEP_FAIL_ORDER_FROZEN     = 1902,
    E_BACKPACK_API_FAIL          = 1903,
}

-- 错误码文案集中在 consignment_strings.lua（S.ERR / S.ERR_UNKNOWN_PREFIX）
local CODE_TEXT      = Strings.ERR
local UNKNOWN_PREFIX = Strings.ERR_UNKNOWN_PREFIX

-- 根据错误码获取可读文案；extras 用于填充 string.format 占位符。
function ErrorCode.GetText(code, extras)
    local txt = CODE_TEXT[code]
    if not txt then
        return UNKNOWN_PREFIX .. tostring(code)
    end
    if extras then
        if code == ErrorCode.E_LEVEL_TOO_LOW and extras.required_level then
            return string.format(txt, extras.required_level)
        elseif code == ErrorCode.E_CONCURRENT_LIMIT and extras.limit then
            return string.format(txt, extras.limit)
        end
    end
    return txt
end

return ErrorCode
