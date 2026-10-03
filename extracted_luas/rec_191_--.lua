-- ================================================================
-- 神侍系统 - 错误码定义（客户端）
-- 与服务端 Activity/Activity1004/GodServant/GodServantConfig.lua 的 Config.Err 保持一致
-- ================================================================

local ErrorCode = {}

ErrorCode.SUCCESS           = 0
ErrorCode.PET_NOT_FOUND     = -201   -- 宠物不存在/编号错
ErrorCode.NO_GODSERVANT     = -202   -- 该宠物无神火库（无法领悟神火）
ErrorCode.NOT_CONTRACT      = -203   -- 未达契约阶段，不可归元
ErrorCode.NO_PRAY           = -204   -- 当前无可归元的祈愿
ErrorCode.NOT_ENOUGH_MONEY  = -205   -- 金币不足
ErrorCode.NOT_ENOUGH_GODEXP = -206   -- 神识不足
ErrorCode.NOT_ENOUGH_ITEM   = -207   -- 归元材料不足
ErrorCode.LEVEL_MAX         = -208   -- 神侍等级已达上限（祈愿）
ErrorCode.SYSTEM_ERR        = -209   -- 系统/数据库错误
ErrorCode.NOT_FULL_AWAKE    = -210   -- 觉悟未尽，需先把可觉悟次数用完再归元

return ErrorCode
