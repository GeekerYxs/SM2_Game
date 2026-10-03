local dlgbuilder = require "dlg_builder"

local struct = require "uiinputtext_struct"
local prefix_path = "UIGame/UIInputText"

local _dlg = nil

local function refreshUI()
    if _dlg==nil then
        return
    end
    Debug("refreshUI input="..tostring(_dlg.Input))
    _dlg.Input:Clear()
end

local function setInfo(title)
    if _dlg==nil then
        return
    end
    if title then
        _dlg.LabelInput:ClearString()
        _dlg.LabelInput:AddString(title)
    end
end

-- 隐藏输入框对话框
local function hideInputDialog()
    if _dlg then
        _dlg.Raw:ShowDlg(false)
    end
end

-- 确认按钮处理
local function onConfirm()
    local inputText = _dlg.Input:GetInputText()
    game:SendInputDlgResult(inputText)
    hideInputDialog()
end

-- 取消按钮处理
local function onCancel()
    hideInputDialog()
end

-- 事件处理函数
local function onEventProc(luadlg, eventCode, ctrlId, ctrl)
    if eventCode == UIEventDef.TBN_CLICKED then
        if ctrlId == _dlg.BtnConfirm.CtrlID then
            onConfirm()
        elseif ctrlId == _dlg.BtnCancel.CtrlID then
            onCancel()
        end
    elseif eventCode == UIEventDef.TEN_RETURN then
        -- 在输入框中按回车键，相当于确认
        if ctrlId == _dlg.Input.CtrlID then
            onConfirm()
        end
    elseif eventCode == UIEventDef.TEN_LOSTFOCUS then
        -- 输入框失去焦点时的处理（如果需要的话）
    elseif eventCode == UIEventDef.TEN_CHANGE then
        -- 输入内容改变时的处理（如果需要的话）
    end
end

-- 显示状态改变处理
local function onShow(luadlg, show)
    if _dlg==nil then
        return
    end
    if show then
        refreshUI()
        -- 对话框显示时的处理
        if _dlg.Input then
            -- 确保输入框获得焦点
            _dlg.Raw:RequestFocus(_dlg.Input:BaseCtrl())
        end
    end
end

-- 创建对话框
local function createDlg(dlgmgr)
    local luadlg = dlgbuilder(dlgmgr, struct, prefix_path, 3000)
    _dlg = luadlg
    
    -- 设置事件处理函数
    luadlg.OnEventProc = onEventProc
    luadlg.OnShow = onShow
    
    -- 初始状态隐藏对话框
    luadlg.Raw:ShowDlg(false)
    _dlg.Input:SetTextColor(0)
    
    return luadlg
end

-- 处理打开输入dlg的全局方法
function OnOpenInputDlg(inputType, title)
    if _dlg==nil then
        return
    end
    _dlg.Raw:ShowDlg(true)
    --setInfo(title)
end

-- 导出接口
return {
    OnCreate = createDlg,
}