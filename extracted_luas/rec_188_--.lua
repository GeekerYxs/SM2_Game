-- ================================================================
-- 神侍系统 - 网络层（3 个 C2S 协议）
-- 事件 ID 见 script_event.lua（GodServant_*）。任意地图可发，服务端 Activity1004 处理。
-- ================================================================

local ScriptEvent = require "script_event"

local M = {}

--- 打开神侍界面（拉取该宠物全量状态）
function M.SendOpenRequest(petIdx)
    Debug("GodServant.SendOpenRequest petIdx=" .. tostring(petIdx))
    game:SendCallScriptPacket(ScriptEvent.GodServant_OpenRequest, { petIdx = petIdx or 0 })
end

--- 祈愿/领悟神火（免费）
function M.SendPrayRequest(petIdx)
    Debug("GodServant.SendPrayRequest petIdx=" .. tostring(petIdx))
    game:SendCallScriptPacket(ScriptEvent.GodServant_PrayRequest, { petIdx = petIdx or 0 })
end

--- 归元（消耗金币+神识+材料）
function M.SendResetRequest(petIdx)
    Debug("GodServant.SendResetRequest petIdx=" .. tostring(petIdx))
    game:SendCallScriptPacket(ScriptEvent.GodServant_ResetRequest, { petIdx = petIdx or 0 })
end

return M
