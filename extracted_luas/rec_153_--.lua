-- ================================================================
-- 寄售-玩家通知（结构化）渲染
-- ----------------------------------------------------------------
-- 通知不再下发渲染文本：服务端只发 { event_code, detail_group, order_id,
-- item_id, item_count, total_price, yuanbao, counterparty_name, secret_set,
-- create_time }，客户端按本模块 + S.NOTIFY 模板本地渲染。
--   M.Title(n)  -> 列表项 2 行标题字符串
--   M.Detail(n) -> 详情卡片 { title, line1..line7 }（对应 txtTitle / txtLine1..7）
-- 列表渲染(consignment_ui_updater) 与详情对话框(ui_consignment_notifydetail_dlg) 共用。
-- ================================================================

local idParseTool = require "id_parse_tool"
local Config      = require "ui.dlgs.consignment.ConsignmentConfig"
local Strings     = require "ui.dlgs.consignment.consignment_strings"

local NT = Strings.NOTIFY
local EC = Config.EventCode
local DG = Config.DetailGroup

local M = {}

-- 冻结/解冻：note1 按 detail_group 取（其余 event_code 用 BY_CODE.note1）
local FREEZE_CODES = {
    [EC.FROZEN_SELLER]   = true,
    [EC.UNFROZEN_SELLER] = true,
    [EC.FROZEN_BUYER]    = true,
    [EC.UNFROZEN_BUYER]  = true,
}

local function itemName(itemId)
    if not itemId then return NT.EMPTY end
    local info = idParseTool.FindItem(itemId)
    local name = info and info.Name
    if not name or name == "" then return NT.EMPTY end
    return name
end

-- string.format 兜底：模板缺失/参数异常不抛错（防一条坏通知整屏报错）
local function fmt(tmpl, ...)
    if type(tmpl) ~= "string" then return "" end
    local ok, s = pcall(string.format, tmpl, ...)
    return ok and s or tmpl
end

local function note1Of(n, t)
    if FREEZE_CODES[n.event_code] then
        return NT.FROZEN_NOTE1[tonumber(n.detail_group) or 1] or ""
    end
    return fmt(t.note1 or "", n.yuanbao or 0)
end

-- 列表项标题：2 行字符串（含 \n），写入 txtHistory
function M.Title(n)
    if not n then return "" end
    local t = NT.BY_CODE[n.event_code]
    if not t then return "" end
    local phrase = fmt(t.phrase, n.yuanbao or 0)
    local line1  = fmt(NT.TITLE_FMT, t.tag, n.order_id or 0, phrase)
    local line2  = fmt(NT.ITEM_FMT, itemName(n.item_id), n.item_count or 0)
    return line1 .. "\n" .. line2
end

-- 详情卡片：返回 { title, line1..line7 }；按 detail_group 选第 5 行（口令/买家/卖家）
function M.Detail(n)
    if not n then return nil end
    local t = NT.BY_CODE[n.event_code]
    if not t then return nil end
    local group = tonumber(n.detail_group) or DG.SellerUntraded
    local cnt   = tonumber(n.item_count)  or 0
    local total = tonumber(n.total_price) or 0
    local unit  = (cnt > 0) and math.floor(total / cnt) or 0
    local iname = itemName(n.item_id)

    local card = {
        title = fmt(NT.DETAIL_TITLE, t.tag, note1Of(n, t)),
        line1 = fmt(NT.LINE_ORDER, n.order_id or 0),
        line2 = (group == DG.Buyer)
                  and fmt(NT.LINE_BUY,  iname, cnt)
                  or  fmt(NT.LINE_SELL, iname, cnt),
        line3 = fmt(NT.LINE_UNIT,  unit),
        line4 = fmt(NT.LINE_TOTAL, total),
        line6 = fmt(NT.LINE_TIME,  tostring(n.create_time or "")),
        line7 = t.note2 or "",
    }
    if group == DG.SellerUntraded then
        local sv = (tonumber(n.secret_set) == 1) and NT.SECRET_YES or NT.SECRET_NO
        card.line5 = fmt(NT.LINE_SECRET, sv)
    elseif group == DG.SellerTraded then
        card.line5 = fmt(NT.LINE_BUYER, n.counterparty_name or NT.EMPTY)
    else
        card.line5 = fmt(NT.LINE_SELLER, n.counterparty_name or NT.EMPTY)
    end
    return card
end

-- 强关界面 reason → 文案（Config.CloseReason）
function M.CloseReasonText(reason)
    return NT.CLOSE_REASON[tonumber(reason) or 0]
end

return M
