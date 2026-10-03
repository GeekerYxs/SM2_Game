require "ui_define"
local events = require("events")
local allmodels = require "all_ui_model"
local luadlgs = {}
local packageHandlers = {}
local callScriptHandlers = {}
local _dlgmgr = nil

function FindLuaDlg(dlg)
    return luadlgs[dlg:GetName()]
end

function OnCreateAllUI(dlgmgr)
    Debug("OnCreateAllUI")
    _dlgmgr = dlgmgr
    for _,v in ipairs(allmodels)do
        local luadlg = v.OnCreate(dlgmgr)
        luadlgs[luadlg.Raw:GetName()] = luadlg
    end
end

function OnFreeAllUI(dlgmgr)
    Debug("OnFreeAllUI")
    --TODO::释放所有的UI
    luadlgs = {}
end

function OnDlgShow(dlg,show)
    Debug("OnDlgShow name="..dlg:GetName()..", show="..tostring(show))
    local luadlg = luadlgs[dlg:GetName()]
    if luadlg~=nil and luadlg.OnShow~=nil then
        luadlg.OnShow(luadlg,show)
    end
end

function OnScreenResize(dlg, w, h)
    local luadlg = luadlgs[dlg:GetName()]
    if luadlg~=nil and luadlg.OnScreenResize~=nil then
        luadlg.OnScreenResize(luadlg, w, h)
    end
end

function OnMove(dlg, offx, offy)
    local luadlg = luadlgs[dlg:GetName()]
    if luadlg~=nil and luadlg.OnMove~=nil then
        luadlg.OnMove(luadlg, offx, offy)
    end
end

function OnDlgEventProc(dlg,eventCode,ctrlId,ctrl)
    --Debug("OnDlgEventProc name="..dlg:GetName()..", eventCode="..tostring(eventCode)..",ctrlId="..ctrlId)
    local luadlg = luadlgs[dlg:GetName()]
    if luadlg~=nil then
        if luadlg._onEventProc~=nil then
            luadlg._onEventProc(luadlg,eventCode,ctrlId,ctrl)
        end
        if luadlg.OnEventProc~=nil then
            luadlg.OnEventProc(luadlg,eventCode,ctrlId,ctrl)
        end
    end
end

function OnDlgHandleMessage(dlg,eventCode,param1,param2)
    --Debug("OnDlgHandleMessage name="..dlg:GetName()..", eventCode="..tostring(eventCode)..",param1="..param1..",param2="..param2)
    local luadlg = luadlgs[dlg:GetName()]
    if luadlg~=nil and luadlg.OnHandleMessage~=nil then
        return luadlg.OnHandleMessage(luadlg,eventCode,param1,param2)
    end
    return false
end

function OnDlgEscape(dlg)
    Debug("OnDlgEscape name="..dlg:GetName())
    local luadlg = luadlgs[dlg:GetName()]
    if luadlg~=nil and luadlg.Raw:GetVisible() and not luadlg.ignoreEsc then
        luadlg.Raw:ShowDlg(false)
        return true
    end
    return false
end

function OnUIPackage(pkgType,buffer)
    Debug("OnUIPackage pkgType="..pkgType)
    local handlers = packageHandlers[pkgType]
    if handlers == nil then
        return
    end
    for _,luadlg in pairs(handlers) do
        if luadlg.OnUIPackage~=nil then
            luadlg.OnUIPackage(luadlg,pkgType,buffer)
        end
    end
end

function HandlePackage(pkgType,luadlg)
    local handlers = packageHandlers[pkgType]
    if handlers == nil then
        handlers = {}
        packageHandlers[pkgType] = handlers
        if _dlgmgr then
            _dlgmgr:HandlePackage(pkgType)
        end
    end
    table.insert(handlers,luadlg)
end

function OnCallScript(event,obj)
    Debug("OnCallScript event="..event)
    local handlers = callScriptHandlers[event]
    if handlers then
        for _,luadlg in pairs(handlers) do
            if luadlg.OnCallScript~=nil then
                luadlg.OnCallScript(luadlg,event,obj)
            end
        end
    end
    local GetFunc = loadstring("return OnCallScriptID" .. event)
    if GetFunc then
        local Func = GetFunc()
        if Func then
            Func(event,obj)
        end
    end

end

function HandleCallScript(event,luadlg)
    local handlers = callScriptHandlers[event]
    if handlers == nil then
        handlers = {}
        callScriptHandlers[event] = handlers
    end
    table.insert(handlers,luadlg)
end

function OnUpdateItemBar(dlgmgr)
    for _,dlg in pairs(luadlgs) do
        if dlg.OnUpdateItemBar~=nil then
            dlg.OnUpdateItemBar(dlg)
        end
    end
end

function OnUpdateItemCount(dlgmgr)
    for _,dlg in pairs(luadlgs) do
        if dlg.OnUpdateItemCount~=nil then
            dlg.OnUpdateItemCount(dlg)
        end
    end
end

function OnUpdateMoney(dlgmgr)
    for _,dlg in pairs(luadlgs) do
        if dlg.OnUpdateMoney~=nil then
            dlg.OnUpdateMoney(dlg)
        end
    end
end

function OnUpdateGodhoodExp(dlgmgr)
    for _,dlg in pairs(luadlgs) do
        if dlg.OnUpdateGodhoodExp~=nil then
            dlg.OnUpdateGodhoodExp(dlg)
        end
    end
end

function GetScrollVMaxLen(dlg,listener)
    local luadlg = luadlgs[dlg:GetName()]
    if luadlg~=nil and luadlg.Raw:GetVisible() then
        if luadlg.GetScrollVMaxLen~=nil then
            return luadlg.GetScrollVMaxLen(luadlg,listener)
        end
    end
    return 0
end

function GetScrollVPageLen(dlg,listener)
    local luadlg = luadlgs[dlg:GetName()]
    if luadlg~=nil and luadlg.Raw:GetVisible() then
        if luadlg.GetScrollVPageLen~=nil then
            return luadlg.GetScrollVPageLen(luadlg,listener)
        end
    end
    return 0
end

function SetScrollVStart(dlg,listener,start)
    local luadlg = luadlgs[dlg:GetName()]
    if luadlg~=nil and luadlg.Raw:GetVisible() then
        if luadlg.SetScrollVStart~=nil then
            luadlg.SetScrollVStart(luadlg,listener,start)
        end
    end
end

function GetScrollVCurrent(dlg,listener)
    local luadlg = luadlgs[dlg:GetName()]
    if luadlg~=nil and luadlg.Raw:GetVisible() then
        if luadlg.GetScrollVCurrent~=nil then
            return luadlg.GetScrollVCurrent(luadlg,listener)
        end
    end
    return 0
end

function OnLuaQuantDlgOK(quant)
    for _,dlg in pairs(luadlgs) do
        if dlg.OnLuaQuantDlgOK~=nil then
            dlg.OnLuaQuantDlgOK(quant)
        end
    end
end

function OnLuaQuantDlgCancel()
    for _,dlg in pairs(luadlgs) do
        if dlg.OnLuaQuantDlgCancel~=nil then
            dlg.OnLuaQuantDlgCancel()
        end
    end
end

events.LuaReload:Add(function()
    --释放所有的界面
    local mgr = game:LuaUIMgr()
    mgr:Free()
    packageHandlers = {}
    callScriptHandlers = {}
    --重新创建所有的界面
    OnCreateAllUI(mgr)
end)