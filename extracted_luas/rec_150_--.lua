-- ================================================================
-- 寄售-子对话框开启器
-- ================================================================

local M = {}

local DIALOG_NAMES = {
    Apply         = "ConsignmentApply",
    Buy           = "ConsignmentBuy",
    BuyToken      = "ConsignmentBuyWithToken",
    Undo          = "ConsignmentUndo",
    PickUp        = "ConsignmentPickUp",
    PickUpReturn  = "ConsignmentPickUpReturn",
    Withdrawal    = "ConsignmentWithdrawal",
    ClaimRefund   = "ConsignmentClaimRefund",
    NotifyDetail  = "ConsignmentNotifyDetail",
}
M.DIALOG_NAMES = DIALOG_NAMES

local function getLuaUIMgr()
    local mgr = game:LuaUIMgr()
    if not mgr then
        Debug("Consignment: LuaUIMgr not found")
        return nil
    end
    return mgr
end

local function getLuaDlg(name)
    local mgr = getLuaUIMgr()
    if not mgr then return nil end
    local dlg = mgr:FindDlg(name)
    if not dlg then
        Debug("Consignment: dialog not found: " .. name)
        return nil
    end
    return FindLuaDlg(dlg), dlg
end

-- ----------------------------------------------------------------
-- 申请对话框：开启器（不携带具体订单数据）
-- ----------------------------------------------------------------
function M.OpenApplyDlg()
    local luadlg, dlg = getLuaDlg(DIALOG_NAMES.Apply)
    if not luadlg then return end
    if luadlg.OnOpenWithApplyData then
        luadlg.OnOpenWithApplyData(luadlg)
    end
    dlg:ShowDlg(true)
end

-- ----------------------------------------------------------------
-- 通用-携带订单数据的开启器
-- ----------------------------------------------------------------
local function openWithOrder(name, order)
    local luadlg, dlg = getLuaDlg(name)
    if not luadlg or not order then return end
    if luadlg.SetOrder then
        luadlg.SetOrder(luadlg, order)
    end
    dlg:ShowDlg(true)
end

function M.OpenBuyDlg(order)
    if order and order.secret_protected then
        openWithOrder(DIALOG_NAMES.BuyToken, order)
    else
        openWithOrder(DIALOG_NAMES.Buy, order)
    end
end

function M.OpenUndoDlg(order)         openWithOrder(DIALOG_NAMES.Undo,         order) end
function M.OpenPickUpDlg(order)       openWithOrder(DIALOG_NAMES.PickUp,       order) end
function M.OpenPickUpReturnDlg(order) openWithOrder(DIALOG_NAMES.PickUpReturn, order) end
function M.OpenWithdrawalDlg(order)   openWithOrder(DIALOG_NAMES.Withdrawal,   order) end
function M.OpenClaimRefundDlg(order)  openWithOrder(DIALOG_NAMES.ClaimRefund,  order) end

-- ----------------------------------------------------------------
-- 通知详情对话框：携带当前页通知数组 + 选中下标（详情内 btnPre/btnNext 翻条）
-- ----------------------------------------------------------------
function M.OpenNotifyDetailDlg(items, index)
    local luadlg, dlg = getLuaDlg(DIALOG_NAMES.NotifyDetail)
    if not luadlg or not items then return end
    if luadlg.SetData then
        luadlg.SetData(luadlg, items, index)
    end
    dlg:ShowDlg(true)
end

function M.CloseAllSubDialogs()
    local mgr = getLuaUIMgr()
    if not mgr then return end
    for _, name in pairs(DIALOG_NAMES) do
        local dlg = mgr:FindDlg(name)
        if dlg then dlg:ShowDlg(false) end
    end
end

return M
