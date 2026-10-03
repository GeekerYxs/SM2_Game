-- ================================================================
-- 寄售-客户端校验器
-- ================================================================

local Config = require "ui.dlgs.consignment.ConsignmentConfig"
local idParseTool = require "id_parse_tool"

local M = {}

-- ----------------------------------------------------------------
-- 申请：该背包槽位的物品是否可寄售？
-- 必须可交易（Useable 位）且不来自车厢。
-- ----------------------------------------------------------------
local USEABLE_STALL_BIT = 0x4  -- “可摆摊位”位

function M.CanConsign(slot)
    if slot == nil or slot < 0 then
        return false, "no_slot"
    end
    local items = game:GetItemBar()
    if not items or not items[slot] then
        return false, "no_slot"
    end
    local item = items[slot]
    local info = game:GetItemInfo(item.ItemID)
    if not info then
        return false, "no_info"
    end
    -- Useable 是位掩码：包含 可使用 / 可丢弃 / 可摆摊 等位
    if info.Useable and game:MaskValue(info.Useable, USEABLE_STALL_BIT) == 0 then
        return false, "not_tradable"
    end
    return true
end

-- ----------------------------------------------------------------
-- 申请：口令格式校验（允许空，或恰好 6 位数字）
-- ----------------------------------------------------------------
function M.IsSecretValid(secret)
    if secret == nil or secret == "" then return true end
    if type(secret) ~= "string" then return false end
    return string.match(secret, "^%d%d%d%d%d%d$") ~= nil
end

-- ----------------------------------------------------------------
-- 申请：数量 / 价格范围校验
-- ----------------------------------------------------------------
function M.IsCountValid(count, maxCount)
    if type(count) ~= "number" then return false end
    if count < 1 then return false end
    if maxCount and count > maxCount then return false end
    return true
end

function M.IsTotalPriceValid(totalPrice)
    if type(totalPrice) ~= "number" then return false end
    -- 总价下限：必须高于 10 元宝（MIN_TOTAL_PRICE = 11，含）
    if totalPrice < Config.MIN_TOTAL_PRICE then return false end
    if totalPrice > Config.MAX_TOTAL_PRICE then return false end
    return true
end

-- ----------------------------------------------------------------
-- 搜索框 -> item_id：按物品名称查 ItemLib 静态库。
-- 返回：itemId | nil
-- ----------------------------------------------------------------
function M.ResolveItemIdByName(name)
    if not name or name == "" then return nil end
    return idParseTool.FindItemIdByName(name)
end

-- ----------------------------------------------------------------
-- 搜索框 -> 模糊匹配最小输入长度校验：GBK 运行时下输入文本按字节计，
-- 需至少 Config.MIN_SEARCH_FUZZY_BYTES（4）字节 = 2 个中文（或 4 个英文字符）。
-- 精确匹配命中物品全名时不受此限；仅在回退模糊匹配前用于拦截过短输入。
-- ----------------------------------------------------------------
function M.IsSearchTextLongEnoughForFuzzy(text)
    if type(text) ~= "string" then return false end
    return #text >= Config.MIN_SEARCH_FUZZY_BYTES
end

-- ----------------------------------------------------------------
-- 搜索框 -> itemId 列表：精确匹配不到时按"只要包含即可"模糊匹配 ItemLib。
-- 返回：itemId 数组（可能为空表）；数量受 Config.MAX_SEARCH_ITEM_IDS 上限约束
-- （超过时只取 ItemLib 前面匹配的这么多个，服务端会再次截断）。
-- ----------------------------------------------------------------
function M.ResolveItemIdsByNameFuzzy(name)
    if not name or name == "" then return {} end
    return idParseTool.FindItemIdsByNameFuzzy(name, Config.MAX_SEARCH_ITEM_IDS)
end

-- ----------------------------------------------------------------
-- 页面模式 / 排序 / 身份的合法性校验（纵深防御，服务端仍会再次校验）
-- ----------------------------------------------------------------
local function inSet(v, set)
    for _, x in ipairs(set) do if v == x then return true end end
    return false
end

function M.IsPageModeValid(pm)
    return inSet(pm, { Config.PageMode.OnSaleDisplay,
                       Config.PageMode.ComingSoon,
                       Config.PageMode.MyOrders })
end

function M.IsSortValid(sort)
    return inSet(sort, { Config.Sort.TimeDesc,
                         Config.Sort.PriceAsc,
                         Config.Sort.PriceDesc,
                         Config.Sort.CountAsc,
                         Config.Sort.CountDesc,
                         Config.Sort.Mine,
                         Config.Sort.Category })
end

function M.IsIdentityValid(identity)
    return inSet(identity, { Config.Identity.All,
                             Config.Identity.Seller,
                             Config.Identity.Buyer })
end

return M
