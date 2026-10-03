local UICtrl = require("ui_ctrl")

local function getResPath(luadlg,name,ext)
    ext = ext or ""
    return luadlg.ResPrefix.."/"..name..ext
end

local function buildImgCtrl(luadlg,uidata,ctrlname,isactive,parentCtrl)
    local ctrl = nil
    local ctrlId = -1
    if isactive then
        ctrlId = luadlg.CurCtrlId
        luadlg.CurCtrlId  = luadlg.CurCtrlId+1
    end
    if(parentCtrl~=nil) then
        ctrl = luadlg.Raw:CreateImageCtrlInParent(ctrlname,uidata.Left,uidata.Top,uidata.Width,uidata.Height,ctrlId,parentCtrl)
    else
        ctrl = luadlg.Raw:CreateImageCtrl(ctrlname,uidata.Left,uidata.Top,uidata.Width,uidata.Height,ctrlId)
    end
    if isactive then
        ctrl:SetEnable(1)
        ctrl:SetMouseMoveEvent(1)
    else
        ctrl:SetEnable(0)
        ctrl:SetMouseMoveEvent(0)
    end
    if uidata.ImgPath then
        ctrl:SetImage(getResPath(luadlg,uidata.ImgPath,".mgff"))
    end
    return ctrl
end

local function buildMovCtrl(luadlg,uidata,ctrlname,parentCtrl)
    local ctrl = nil
    if parentCtrl~=nil then
        ctrl = luadlg.Raw:CreateMovCtrlInParent(ctrlname,uidata.Left,uidata.Top,uidata.Width,uidata.Height,luadlg.CurCtrlId,parentCtrl)
    else
        ctrl = luadlg.Raw:CreateMovCtrl(ctrlname,uidata.Left,uidata.Top,uidata.Width,uidata.Height,luadlg.CurCtrlId)
    end
    luadlg.CurCtrlId  = luadlg.CurCtrlId+1
    if uidata.ImgPath then
        ctrl:SetImage(getResPath(luadlg,uidata.ImgPath,".mgff"))
    end
    ctrl:SetSpeed(33)
    return ctrl
end

local function buildBarCtrl(luadlg,uidata,ctrlname,parentCtrl)
    local ctrl = nil
    if parentCtrl~=nil then
        ctrl = luadlg.Raw:CreateProgressBarCtrlInParent(ctrlname,uidata.Left,uidata.Top,uidata.Width,uidata.Height,luadlg.CurCtrlId,parentCtrl)
    else
        ctrl = luadlg.Raw:CreateProgressBarCtrl(ctrlname,uidata.Left,uidata.Top,uidata.Width,uidata.Height,luadlg.CurCtrlId)
    end
    luadlg.CurCtrlId  = luadlg.CurCtrlId+1
    if uidata.ImgPath then
        ctrl:SetProcessBarImage(getResPath(luadlg,uidata.ImgPath,".mgff"))
    end
    return ctrl
end

local function buildBtnCtrl(luadlg,uidata,ctrlname,parentCtrl)
    local ctrl = nil
    if parentCtrl~=nil then
        ctrl = luadlg.Raw:CreateBtnCtrlInParent(ctrlname,uidata.Left,uidata.Top,uidata.Width,uidata.Height,luadlg.CurCtrlId,parentCtrl)
    else
        ctrl = luadlg.Raw:CreateBtnCtrl(ctrlname,uidata.Left,uidata.Top,uidata.Width,uidata.Height,luadlg.CurCtrlId)
    end
    luadlg.CurCtrlId  = luadlg.CurCtrlId+1
    if uidata.ImgPath then
        ctrl:SetImage(getResPath(luadlg,uidata.ImgPath," 正常.mgff"),
            getResPath(luadlg,uidata.ImgPath," 高亮.mgff"),
            getResPath(luadlg,uidata.ImgPath," 点击.mgff"),
            getResPath(luadlg,uidata.ImgPath," 灰色.mgff"))
    end
    return ctrl
end

local function buildLabelCtrl(luadlg,uidata,ctrlname,isactive,parentCtrl)
    local ctrl = nil
    local ctrlId = -1
    if isactive then
        ctrlId = luadlg.CurCtrlId
        luadlg.CurCtrlId  = luadlg.CurCtrlId+1
    end
    if parentCtrl~=nil then
        ctrl = luadlg.Raw:CreateLabelCtrlInParent(ctrlname,uidata.Left,uidata.Top,uidata.Width,uidata.Height,ctrlId,parentCtrl)
    else
        ctrl = luadlg.Raw:CreateLabelCtrl(ctrlname,uidata.Left,uidata.Top,uidata.Width,uidata.Height,ctrlId)
    end
    if uidata.FontSize~=nil then
        ctrl:SetFontSize(uidata.FontSize)
    end
    if uidata.Color~=nil and uidata.Color~="" then
        if string.find(uidata.Color, "rgba") == 1 then
            local pattern = "([0-9]+%.?[0-9]*)"
            local subcolors = {}
            for c in string.gmatch(uidata.Color, pattern) do
                subcolors[#subcolors+1] = c
            end
            Debug("buildLabelCtrl color subcolors=".. TableToString(subcolors))
            if #subcolors >= 3 then
                local r = tonumber(subcolors[1])
                local g = tonumber(subcolors[2])
                local b = tonumber(subcolors[3])
                ctrl:SetColor(game:Color24To16(r, g, b))
            end
        else
            local r = tonumber(string.sub(uidata.Color,1,2),16)
            local g = tonumber(string.sub(uidata.Color, 3, 4), 16)
            local b = tonumber(string.sub(uidata.Color, 5, 6), 16)
            if r and b and g then
                ctrl:SetColor(game:Color24To16(r, g, b))
            end
        end
    else
        ctrl:SetColor(0)
    end
    ctrl:SetAlign(0)
    if uidata.Align~=nil then
        if uidata.Align=='center' then
            ctrl:SetAlign(2)
        elseif uidata.Align=='right' then
            ctrl:SetAlign(1)
        end
    end
    ctrl:SetVAlign(0)
    if uidata.VAlign~=nil then
        if uidata.VAlign=='flex-end' then
            ctrl:SetVAlign(1)
        elseif uidata.VAlign=='flex-start' then
            ctrl:SetVAlign(0)
        elseif uidata.VAlign=='center' then
            ctrl:SetVAlign(2)
        end
    end
    ctrl:SetWrap(true)
    ctrl:SetLineSpace(5)
    if isactive then
        ctrl:SetMouseMoveEvent(1)
    else
        ctrl:SetMouseMoveEvent(0)
        ctrl:SetEnable(0)
    end
    if uidata.Text~=nil then
        ctrl:AddString(uidata.Text)
    end
    -- 文本描边：由建对话框时传入的 OutlineText 开关统一控制（默认关，黑色描边=引擎默认色0）
    if luadlg.OutlineText then
        ctrl:EnableOutlineEffect(1)
    else
        ctrl:EnableOutlineEffect(0)
    end
    return ctrl
end

local function buildRichLabelCtrl(luadlg,uidata,ctrlname,isactive,parentCtrl)
    local ctrl = nil
    if parentCtrl~=nil then
        ctrl = luadlg.Raw:CreateRichEditInParent(ctrlname,uidata.Left,uidata.Top,uidata.Width,uidata.Height,luadlg.CurCtrlId,parentCtrl)
    else
        ctrl = luadlg.Raw:CreateRichEdit(ctrlname,uidata.Left,uidata.Top,uidata.Width,uidata.Height,luadlg.CurCtrlId)
    end
    luadlg.CurCtrlId = luadlg.CurCtrlId+1
    if uidata.FontSize~=nil then
        ctrl:SetTextSize(uidata.FontSize)
    end
    ctrl:SetLineSpace(5)
    return ctrl
end

local function buildCBCtrl(luadlg,uidata,ctrlname,parentCtrl)
    local ctrl = nil
    if parentCtrl~=nil then
        ctrl = luadlg.Raw:CreateCBCtrlInParent(ctrlname,uidata.Left,uidata.Top,uidata.Width,uidata.Height,luadlg.CurCtrlId,parentCtrl)
    else
        ctrl = luadlg.Raw:CreateCBCtrl(ctrlname,uidata.Left,uidata.Top,uidata.Width,uidata.Height,luadlg.CurCtrlId)
    end
    luadlg.CurCtrlId = luadlg.CurCtrlId+1
    ctrl:Init(2)
    ctrl:SetImage(0, "UIGame\\UICommonRes\\uncheck.mgff", "UIGame\\UICommonRes\\uncheck_active.mgff")
    ctrl:SetImage(1, "UIGame\\UICommonRes\\checked.mgff", "UIGame\\UICommonRes\\checked_active.mgff")
    ctrl:SetCurStatus(0)
    return ctrl
end

local function buildEditCtrl(luadlg,uidata,ctrlname,parentCtrl)
    local ctrl = nil
    if parentCtrl~=nil then
        ctrl = luadlg.Raw:CreateEditCtrlInParent(ctrlname,uidata.Left,uidata.Top,uidata.Width,uidata.Height,luadlg.CurCtrlId,parentCtrl)
    else
        ctrl = luadlg.Raw:CreateEditCtrl(ctrlname,uidata.Left,uidata.Top,uidata.Width,uidata.Height,luadlg.CurCtrlId)
    end
    luadlg.CurCtrlId = luadlg.CurCtrlId+1
    return ctrl
end

local function buildTabGroupCtrl(luadlg,uidata,ctrlname,parentCtrl)
    local ctrl = nil
    --查看有多少成员项
    local itemCount = 0
    local leftx,lefty,rightx,righty = 0,0,0,0
    local itemWidth,itemHeight = 0,0
    for _,child in pairs(uidata.Children) do
        if child.CtrlType=='tab' then
            itemCount = itemCount + 1
            itemWidth = child.Width
            itemHeight = child.Height
            if leftx==0 or leftx>child.Left then
                leftx = child.Left
            end
            if lefty==0 or lefty>child.Top then
                lefty = child.Top
            end
            if rightx==0 or rightx<child.Left+child.Width then
                rightx = child.Left+child.Width
            end
            if righty==0 or righty<child.Top+child.Height then
                righty = child.Top+child.Height
            end
        end
    end
    local width = rightx-leftx
    local height = righty-lefty
    if parentCtrl~=nil then
        ctrl = luadlg.Raw:CreateTabCtrlInParent(ctrlname,leftx,lefty,width,height,luadlg.CurCtrlId,parentCtrl)
    else
        ctrl = luadlg.Raw:CreateTabCtrl(ctrlname,leftx,lefty,width,height,luadlg.CurCtrlId)
    end
    luadlg.CurCtrlId = luadlg.CurCtrlId+1
    ctrl:Init(itemCount)
    ctrl:SetPageAlign(1)
    ctrl:SetPageInterval(2)
    ctrl:SetEachPagePos(0,0,itemWidth,itemHeight)
    local idx = 0
    for _,child in pairs(uidata.Children) do
        if child.CtrlType=='tab' then
            ctrl:SetTabPageImage(idx,getResPath(luadlg,child.ImgPath," 灰色.mgff"),
                getResPath(luadlg,child.ImgPath," 高亮.mgff"),
                getResPath(luadlg,child.ImgPath," 点击.mgff"),
                getResPath(luadlg,child.ImgPath," 灰色.mgff"))
            idx = idx+1
        end
    end
    ctrl:ActiveTabPage(0)
    return ctrl
end

local buildCtrl = nil
local function buildVScrollCtrl(luadlg,uidata,ctrlname,parentCtrl)
    local ctrl = nil
    local x,y = uidata.DataLeft,uidata.DataTop
    local width,height = uidata.DataWidth,uidata.DataHeight
    if parentCtrl~=nil then
        ctrl = luadlg.Raw:CreateScrollBarVInParent(ctrlname,x,y,width,height,luadlg.CurCtrlId,parentCtrl)
    else
        ctrl = luadlg.Raw:CreateScrollBarV(ctrlname,x,y,width,height,luadlg.CurCtrlId)
    end
    luadlg.CurCtrlId = luadlg.CurCtrlId+1
    return ctrl
end

-- 实例化 prefab 时给每个实例的子树拷贝一份再用：
-- buildObjCtrl 的 else 分支会把嵌套 obj 的子节点按位置偏移就地改写(mutate child.Left 等)，
-- 而 Product1..8 这 8 张卡片共享同一个 ProductItem prefab，同一份 table 会被多次减去偏移、
-- 从第 2 张卡片起累计出错，表现为 ReceivePayment / ReceivedPayment 的子节点偏到卡片左上角。
-- 实例化前先深拷贝，让每个实例只 mutate 自己的副本。
local function deepCopyUIData(node)
    local copy = {}
    for k, v in pairs(node) do
        if k == 'Children' and type(v) == 'table' then
            local children = {}
            for i = 1, #v do
                children[i] = deepCopyUIData(v[i])
            end
            copy[k] = children
        else
            copy[k] = v
        end
    end
    return copy
end

local function buildObjCtrl(luadlg,uidata,ctrlname,parentCtrl,originX,originY)
    originX = originX or 0
    originY = originY or 0
    if uidata.Prefab then
        local prefab = luadlg.Prefabs[uidata.Prefab]
        if prefab==nil then
            Warn('prefab not found:'..uidata.Prefab)
            return nil
        end
        local ctrl = nil
        if parentCtrl~=nil then
            ctrl = luadlg.Raw:CreateLuaCtrlInParent(ctrlname,uidata.DataLeft,uidata.DataTop,1,1,-1,parentCtrl)
        else
            ctrl = luadlg.Raw:CreateLuaCtrl(ctrlname,uidata.DataLeft,uidata.DataTop,1,1,-1)
        end
        local obj = UICtrl:new(ctrl)
        for _,child in ipairs(prefab.UIData.Children) do
            buildCtrl(luadlg,obj,deepCopyUIData(child),ctrl:BaseCtrl())
        end
        return obj
    else
        local ctrl = nil
        if parentCtrl~=nil then
            ctrl = luadlg.Raw:CreateLuaCtrlInParent(ctrlname,uidata.DataLeft,uidata.DataTop,1,1,-1,parentCtrl)
        else
            ctrl = luadlg.Raw:CreateLuaCtrl(ctrlname,uidata.DataLeft,uidata.DataTop,1,1,-1)
        end
        local obj = UICtrl:new(ctrl)
        local absLeft = originX + uidata.DataLeft
        local absTop  = originY + uidata.DataTop
        for _,child in ipairs(uidata.Children) do
            -- 需要做位置偏移
            child.DataLeft = child.DataLeft-absLeft
            child.DataTop = child.DataTop-absTop
            child.Left = child.Left-absLeft
            child.Top = child.Top-absTop
            buildCtrl(luadlg,obj,child,ctrl:BaseCtrl(),absLeft,absTop)
        end
        return obj

    end
end

local function readPrefabs(luadlg,uidata)
    for _,child in ipairs(uidata.Children) do
        buildCtrl(luadlg,nil,child)
    end
end

local function resetPrefabItemPos(uidata,left,right)
    for _,child in ipairs(uidata.Children) do
        if child.Left~=nil then
            child.Left = child.Left - left
        end
        if child.Top~=nil then
            child.Top = child.Top - right
        end
        -- 嵌套 obj 子节点用 DataLeft/DataTop 定位，也需要一起转成 prefab 内相对坐标，
        -- 否则实例化时 buildObjCtrl 的 else 分支会按绝对偏移去改写共享子节点位置，
        -- 多次实例化（同一 prefab 多次使用）就会累计破坏，第 2 张及以后的卡片飞出屏幕。
        if child.DataLeft~=nil then
            child.DataLeft = child.DataLeft - left
        end
        if child.DataTop~=nil then
            child.DataTop = child.DataTop - right
        end
        if child.Children~=nil then
            resetPrefabItemPos(child,left,right)
        end
    end
end

local function readPrefab(luadlg,uidata,ctrlname)
    if luadlg.Prefabs == nil then
        luadlg.Prefabs = {}
    end
    --仅仅记录，不用解析
    --位置修改为相对位置
    resetPrefabItemPos(uidata,uidata.DataLeft,uidata.DataTop)
    local prefab = {UIData=uidata,Name=ctrlname}
    luadlg.Prefabs[ctrlname] = prefab
end

buildCtrl = function(luadlg,parent,uidata,parentCtrl,originX,originY)
    local ctrl = nil
    local ctrlname = "noname"
    local savename = false;
    if uidata.CtrlName~=nil and uidata.CtrlName.length~=0  and uidata.CtrlName~='_' then
        ctrlname = uidata.CtrlName
        savename = true
    end
    if uidata.CtrlType=='img' then
        ctrl = buildImgCtrl(luadlg,uidata,ctrlname,false,parentCtrl)
    elseif uidata.CtrlType=='aimg' then
        ctrl = buildImgCtrl(luadlg,uidata,ctrlname,true,parentCtrl)
    elseif uidata.CtrlType=='btn' then
        ctrl = buildBtnCtrl(luadlg,uidata,ctrlname,parentCtrl)
    elseif uidata.CtrlType=='txt' then
        ctrl = buildLabelCtrl(luadlg,uidata,ctrlname,false,parentCtrl)
    elseif uidata.CtrlType=='atxt' then
        ctrl = buildLabelCtrl(luadlg,uidata,ctrlname,true,parentCtrl)
    elseif uidata.CtrlType=='richtxt' then
        ctrl = buildRichLabelCtrl(luadlg,uidata,ctrlname,parentCtrl)
    elseif uidata.CtrlType=='cb' then
        ctrl = buildCBCtrl(luadlg,uidata,ctrlname,parentCtrl)
    elseif uidata.CtrlType=='edit' then
        ctrl = buildEditCtrl(luadlg,uidata,ctrlname,parentCtrl)
    elseif uidata.CtrlType=='mov' then
        ctrl = buildMovCtrl(luadlg,uidata,ctrlname,parentCtrl)
    elseif uidata.CtrlType=='bar' then
        ctrl = buildBarCtrl(luadlg,uidata,ctrlname,parentCtrl)
    elseif uidata.CtrlType=='obj' then
        ctrl = buildObjCtrl(luadlg,uidata,ctrlname,parentCtrl,originX,originY)
    elseif uidata.CtrlType=='tabgroup' then
        ctrl = buildTabGroupCtrl(luadlg,uidata,ctrlname,parentCtrl)
    elseif uidata.CtrlType=='vscroll' then
        ctrl = buildVScrollCtrl(luadlg,uidata,ctrlname,parentCtrl)
    elseif uidata.CtrlType=='prefabs' then
        --prefabs定义保存到dlg顶层
        readPrefabs(luadlg,uidata)
    elseif uidata.CtrlType=='prefab' then
        --prefab定义保存到dlg的Prefabs
        readPrefab(luadlg,uidata,ctrlname)
    end
    if ctrl~=nil and savename then
        parent[ctrlname] = ctrl
    end
end

local function buildDlg(dlgmgr,uidata,resprefix,curCtrlId,outlineText)
    -- outlineText: 是否给本对话框内所有文本(txt/atxt 标签)加描边，透传给 buildLabelCtrl
    local luadlg = {ResPrefix=resprefix,CurCtrlId=curCtrlId,OutlineText=outlineText}
    local dlgw = uidata.bg and uidata.bg.Width or uidata.DataWidth
    local dlgh = uidata.bg and uidata.bg.Height or uidata.DataHeight
    local dlgx = uidata.DataLeft ~= 0 and uidata.DataLeft or (1024-dlgw)/2
    local dlgy = uidata.DataTop ~= 0 and uidata.DataTop or (768-dlgh)/2
    --dlg主体
    local dlg = dlgmgr:CreateDlg(uidata.CtrlName,dlgx, dlgy, dlgw, dlgh);
    dlg:SetupCustomTipWnd(game:GetFormatTipDlg())
    if uidata.bg then
        dlg:SetBKImage(resprefix..'/'..uidata.bg.ImgPath..".mgff",0,0)
    end
    if uidata.head then
        dlg:SetCaptionRect(uidata.head.Left, uidata.head.Top, uidata.head.Width, uidata.head.Height, 0)
    end
    if uidata.title then
        local caption = dlg:CreateLabelCtrl("caption",uidata.title.Left,uidata.title.Top,uidata.title.Width,uidata.title.Height,-1)
        caption:SetFontSize(uidata.title.FontSize)
        caption:SetAlign(2)
        caption:AddString(uidata.title.Text)
        luadlg.Caption = caption
    end
    if uidata.close then
        local closeBtn = dlg:CreateBtnCtrl("close",uidata.close.Left,uidata.close.Top,uidata.close.Width,uidata.close.Height,luadlg.CurCtrlId)
        luadlg.CurCtrlId = luadlg.CurCtrlId+1
        closeBtn:SetImage("UIGame\\UICommonRes\\closeNormal.mgff",
            "UIGame\\UICommonRes\\closeActive.mgff",
            "UIGame\\UICommonRes\\closePressed.mgff",
            "")
        luadlg.Close = closeBtn
        luadlg._onEventProc = function(luadlg,eventCode,ctrlId,ctrl)
            if ctrlId==closeBtn.CtrlID and eventCode==UIEventDef.TBN_CLICKED then
                dlg:ShowDlg(false)
            end
        end
    end
    luadlg.Raw = dlg

    --其它控件
    for _,child in ipairs(uidata.Ctrls) do
        buildCtrl(luadlg,luadlg,child)
    end
    return luadlg
end

return buildDlg