-- ================================================================
-- 寄售-通知详情对话框（UIConsignmentNotifyDetail）
-- ----------------------------------------------------------------
-- 通知列表项 btnClick 打开；按 detail_group 渲染卡片（卖家·未交易/卖家·已交易/买家）。
-- btnPre/btnNext 翻条功能已废弃：createDlg 里直接隐藏，不再响应点击。
-- 文案/渲染见 consignment_notify_render.lua + consignment_strings.lua S.NOTIFY。
-- ================================================================

local dlgbuilder = require "dlg_builder"

local struct      = require "uiconsignmentnotifydetail_struct"
local prefix_path = "UIGame/UIConsignmentSub"

local NotifyRender = require "ui.dlgs.consignment.consignment_notify_render"

local _dlg   = nil
local _items = nil   -- 当前页通知数组（引用主界面 Data 的当前页）
local _index = 1     -- 选中下标

local function setLabel(ctrl, text)
    if not ctrl then return end
    ctrl:ClearString()
    if text ~= nil and text ~= "" then ctrl:AddString(tostring(text)) end
end

-- 渲染当前选中通知的卡片
local function render(luadlg)
    if not luadlg or not _items then return end
    local n    = _items[_index]
    local card = n and NotifyRender.Detail(n)
    if not card then return end
    setLabel(luadlg.txtTitle, card.title)
    setLabel(luadlg.txtLine1, card.line1)
    setLabel(luadlg.txtLine2, card.line2)
    setLabel(luadlg.txtLine3, card.line3)
    setLabel(luadlg.txtLine4, card.line4)
    setLabel(luadlg.txtLine5, card.line5)
    setLabel(luadlg.txtLine6, card.line6)
    setLabel(luadlg.txtLine7, card.line7)
end

-- 携带当前页通知数组 + 选中下标打开
local function setData(luadlg, items, index)
    _items = items or {}
    _index = tonumber(index) or 1
    if _index < 1 then _index = 1 end
    if _index > #_items then _index = #_items end
    render(luadlg)
end

local function onEventProc(luadlg, eventCode, ctrlId, ctrl)
    if eventCode ~= UIEventDef.TBN_CLICKED then return end
    if luadlg.btnClose and ctrlId == luadlg.btnClose.CtrlID then
        luadlg.Raw:ShowDlg(false); return
    end
end

local function createDlg(dlgmgr)
    local luadlg = dlgbuilder(dlgmgr, struct, prefix_path, 4800)
    _dlg = luadlg
    luadlg.OnEventProc = onEventProc
    luadlg.SetData     = setData
    -- 翻条按钮已废弃：隐藏 btnPre/btnNext（UI 资源仍在 struct 里，仅不显示/不响应）
    if luadlg.btnPre  then luadlg.btnPre:SetVisible(0)  end
    if luadlg.btnNext then luadlg.btnNext:SetVisible(0) end
    return luadlg
end

return { OnCreate = createDlg }
