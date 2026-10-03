-- ================================================================
-- 神侍系统 - 数据模型（客户端）
-- 保存当前弹窗针对的宠物序号 + 服务端下发的全量状态（OpenResult/PrayResult/ResetResult 同结构）
-- ================================================================

local idtool = require "id_parse_tool"

local M = {}

local _petIdx = 0
local _state  = nil   -- 服务端下发的全量状态

function M.SetPetIdx(idx) _petIdx = idx or 0 end
function M.GetPetIdx() return _petIdx end

-- 神火技能格模型（顺序格）：每抽到一条神火就占一格（第 N 次跨阶段抽取 → 第 N 格），同阶重复也各占一格。
--   服务端下发整库候选(每条带 need_level/skill_id/level/owned)；这里筛出「已拥有」的，按 (need_level, skill_id)
--   稳定排序（≈抽取顺序：低阶先抽、同阶按 skill_id）顺序填格。slots[i] = 第 i 条已得神火(或 nil=该格未抽到)。
--   注：精确抽取顺序未持久化，同阶多条按 skill_id 排；要严格按获取先后需服务端存获取序。
local function _buildSlotModel(obj)
    local owned = {}
    for _, sk in ipairs(obj.skills or {}) do
        if sk.owned == 1 then owned[#owned + 1] = sk end
    end
    table.sort(owned, function(a, b)
        local na, nb = (a.need_level or 0), (b.need_level or 0)
        if na ~= nb then return na < nb end
        return (a.skill_id or 0) < (b.skill_id or 0)
    end)
    return owned
end

function M.SetState(obj)
    -- 神侍等级不再由服务端下发：按种族(pet_species)现算 = TPetLib.GodServantRank（读 PetLib.csv）。
    -- 补进 obj.gs_level 后，下游一切 st.gs_level 读取（阶/星/名·圣痕档位·归元消耗·可否祈愿）沿用不变。
    if obj ~= nil then
        obj.gs_level = idtool.FindPetGodServantRank(obj.pet_species or 0)
        obj.slots    = _buildSlotModel(obj)   -- 神火技能格：每条已得神火顺序占一格
    end
    _state = obj
end
function M.GetState() return _state end

-- 剩余可领悟(觉悟)次数 = 神侍等级(gs_level) - 已祈愿次数(pray_count)，下限 0；无神火库(libID<=0)则 0。
-- 界面计数(txtLeftAwakeCount) 与 btnAwake 点击反馈共用，保证「显示的次数」与「点击校验」判定一致。
function M.GetLeftAwakeCount()
    local st = _state
    if not st then return 0 end
    if idtool.FindPetGodFireLibID(st.pet_species or 0) <= 0 then return 0 end
    return math.max(0, (st.gs_level or 0) - (st.pray_count or 0))
end

function M.Reset()
    _state = nil
end

return M
