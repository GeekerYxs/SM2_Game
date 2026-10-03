-- -*- coding: utf-8 -*-
local dlgbuilder = require "dlg_builder"
local events = require "events"
local idParseTool = require "id_parse_tool" -- Require the id parse tool

local struct = require "uimapbuff_struct"
local prefix_path = "UIGame/UIMapBuff"

local gbkstr={
    fumianzhuangtaibiaoshil = game:UTF8toASCII("负面状态标识"),
    zhengmianzhuangtaibiaoshil = game:UTF8toASCII("正面状态标识"),
    yongjiu = game:UTF8toASCII("永久"),
    cizhandou = game:UTF8toASCII("次战斗"),
    yiguoqi = game:UTF8toASCII("已过期"),
    tian = game:UTF8toASCII("天"),
    xiaoshi =  game:UTF8toASCII("小时"),
    fen = game:UTF8toASCII("分"),
    miao = game:UTF8toASCII("秒"),
    dengji = game:UTF8toASCII("等级"),
    zhandouxiaoguo = game:UTF8toASCII("战斗效果："),
    shengxiaoditu = game:UTF8toASCII("生效地图："),
    shixiaoditu = game:UTF8toASCII("失效地图："),
    beizhuangtai = game:UTF8toASCII("被状态"),
    kezhi = game:UTF8toASCII("克制"),
    shengyushijian = game:UTF8toASCII("剩余时间："),
    beiguanbibiaoshil = game:UTF8toASCII("被关闭标识"),
    beijinzhibiaoshil = game:UTF8toASCII("被禁止标识"),
    xiaxianhoujishijianghuitingzhi = game:UTF8toASCII("下线后计时将会停止"),
    yijingguanbi = game:UTF8toASCII("已经关闭"),
    suozaiquyubunengjihuo = game:UTF8toASCII("所在区域不能激活"),
    yibeikezhi = game:UTF8toASCII("已被克制"),
}

-- 地图buff列表数据结构，暂时未用到的先存储在这里
local mapBuffs = {}  -- 每一项包含 buffId, buffInfo, time, isOpen, isEnable

local _dlg = nil

local function showOneBuff(idx, buff)
    local buffCtl = _dlg['Buff'..idx]
    if buffCtl == nil then return end
    buffCtl._buffData = buff
    buffCtl:SetVisible(1)
    -- 显示图标
    buffCtl.buff:SetImage("UIGame/Icon/"..buff.buffInfo.Icon..".mgff")
    if buff.buffInfo.IsNegative then
        buffCtl.type:SetImage(prefix_path.."/"..gbkstr.fumianzhuangtaibiaoshil..".mgff") 
    else
        buffCtl.type:SetImage(prefix_path.."/"..gbkstr.zhengmianzhuangtaibiaoshil..".mgff")
    end
    -- 是否关闭/不可用
    buffCtl.cover:SetVisible(0)
    if not buff.isOpen then
        buffCtl.cover:SetVisible(1)
        buffCtl.cover:SetImage(prefix_path.."/"..gbkstr.beiguanbibiaoshil..".mgff")
    elseif buff.isEnable~= 1 then
        buffCtl.cover:SetVisible(1)
        buffCtl.cover:SetImage(prefix_path.."/"..gbkstr.beijinzhibiaoshil..".mgff")
    end
end

local function removeBuffShow()
    for i=1,20 do
        local buff = _dlg['Buff'..i]
        if buff then
            buff._buffData = nil
            buff:SetVisible(0)
        end
    end
end

local function refreshView()
    if not _dlg then return end

    -- 清理所有显示buff
    removeBuffShow()
    -- buff按id排序
    local sortedBuffList = {}
    for bid, buff in pairs(mapBuffs) do
        table.insert(sortedBuffList, buff)
    end
    table.sort(sortedBuffList, function(a, b)
        return a.buffId < b.buffId
    end)
    -- 先显示减益buff
    local curIdx = 1
    for _, buff in ipairs(sortedBuffList) do
        if buff.buffInfo and buff.buffInfo.IsNegative then
            showOneBuff(curIdx, buff)
            curIdx = curIdx + 1
        end
    end
    -- 再显示增益buff
    for _, buff in ipairs(sortedBuffList) do
        if buff.buffInfo and not buff.buffInfo.IsNegative then
            showOneBuff(curIdx, buff)
            curIdx = curIdx + 1
        end
    end
end

local function onUIPackage(luadlg,pkgType,buffer)
end

local function getLeftTimeDesc(buff)
    if buff.buffInfo.ExpireTimeType == 0 then
        return gbkstr.yongjiu
    end
    if buff.buffInfo.ExpireTimeType==3 then
        return tostring(buff.time)..gbkstr.cizhandou
    end
    -- 到期时间戳-buff.time算出剩余时间
    local now = os.time()
    local left_time = buff.time - now - 8*3600 -- 8小时的时差

    if left_time <= 0 then
        return "#63488"..gbkstr.yiguoqi
    end

    local days = math.floor(left_time / 86400)
    local remaining_after_days = left_time % 86400
    local hours = math.floor(remaining_after_days / 3600)
    local remaining_after_hours = remaining_after_days % 3600
    local minutes = math.floor(remaining_after_hours / 60)
    local seconds = remaining_after_hours % 60

    if days > 0 then
        return string.format("#63181 %d#02019"..gbkstr.tian.."#63181 %d#02019"..gbkstr.xiaoshi, days, math.ceil(remaining_after_days / 3600))
    elseif hours > 0 then
        return string.format("#63181 %d#02019"..gbkstr.xiaoshi.."#63181 %d#02019"..gbkstr.fen, hours, math.ceil(remaining_after_hours / 60))
    else
        return string.format("#63181 %d#02019"..gbkstr.fen.."#63181 %d#02019"..gbkstr.miao, minutes, seconds)
    end
end

local function getBuffDesc(buff)
    local buffInfo = buff.buffInfo
    if buffInfo == nil then
        Warn("MapBuff not found: " .. buff.buffId)
        return
    end
    local desc = (buffInfo.IsNegative and "#63488" or "#02019")..buffInfo.Name.."#65535("..gbkstr.dengji..buffInfo.GroupLevel..")"
    if not buff.isOpen then
        desc = desc.."       #63488"..gbkstr.yijingguanbi.."#65535\n"
    elseif buff.isEnable==2 then
        desc = desc.."  #63488"..gbkstr.suozaiquyubunengjihuo.."#65535\n"
    elseif buff.isEnable==3 then
        desc = desc.."      #63488"..gbkstr.yibeikezhi.."#65535\n"
    end
    desc = desc.."\n"..buffInfo.Desc.."\n"
    if #buffInfo.Skills>0 then
        desc = desc.."#65056"..gbkstr.zhandouxiaoguo.."#65535\n"
        for _, skill in ipairs(buffInfo.Skills) do
            desc = desc..skill.SkillInfo.Desc.."\n"
        end
    end
    if buffInfo.ValidMapTag~=0 then
        local tagName = idParseTool.FindMapTagName(buffInfo.ValidMapTag)
        desc = desc.."#65056"..gbkstr.shengxiaoditu.."#65535\n"
        desc = desc..tagName.."\n"
    end
    if buffInfo.InvalidMapTag~=0 then
        local tagName = idParseTool.FindMapTagName(buffInfo.InvalidMapTag)
        desc = desc.."#65056"..gbkstr.shixiaoditu.."#65535\n"
        desc = desc..tagName.."\n"
    end
    if buffInfo.SupressedBuffId~=0 then
        local supressedBuff = idParseTool.FindMapBuff(buffInfo.SupressedBuffId)
        if supressedBuff then
            desc = desc.."#65056"..gbkstr.beizhuangtai.."#63488"..supressedBuff.Name.."#65056"..gbkstr.kezhi.."#65535\n"
        end
    end
    if buff.buffInfo.ExpireTimeType==2 then
        desc = desc..gbkstr.xiaxianhoujishijianghuitingzhi.."\n"
    end
    desc = desc.."#02019"..gbkstr.shengyushijian
    desc = desc..getLeftTimeDesc(buff)
    return desc 
end

local function sendCancelBuff(buffId)
    local pkg = game:PrepareSendBuffer()
    pkg:WriteUInt32(0)
    pkg:WriteUInt32(buffId)
    game:SendPackage(EPackageType.MSLGP_C_TYPE_CANCELMAPBUFF)
end

local function sendSetBuffOpenState(buffId, isOpen)
    local pkg = game:PrepareSendBuffer()
    pkg:WriteUInt32(0)
    pkg:WriteUInt32(buffId)
    pkg:WriteUInt8(isOpen)
    game:SendPackage(EPackageType.MSLGP_C_TYPE_SETMAPBUFFOPENSTATE)
end

local function onEventProc(luadlg,eventCode,ctrlId,ctrl)
    for i=1,20 do
        local buffCtl = luadlg["Buff"..i]
        -- 检查 buffCtl 是否有效，以及 buffCtl.buff 是否有效
        if buffCtl and buffCtl.buff and ctrlId==buffCtl.buff.CtrlID then
            if eventCode==UIEventDef.TIN_MOUSEMOVE then
                -- 显示buff信息
                local buff = buffCtl._buffData
                if buff then
                    -- 拼接完整描述，包括时间
                    local completeDesc = getBuffDesc(buff)
                    buffCtl.buff:SetTipInfo(completeDesc)
                end 
            elseif eventCode==UIEventDef.TIN_MOUSECLICK then
                local buff = buffCtl._buffData
                if buff.buffInfo.CanClose then
                    sendSetBuffOpenState(buff.buffId, buffCtl._buffData.isOpen and 0 or 1)
                end
            elseif eventCode==UIEventDef.TIN_MOUSERCLICK then
                local buff = buffCtl._buffData
                if buff.buffInfo.CanCancel then
                    -- 发送取消buff请求
                    sendCancelBuff(buff.buffId)
                end
            end
        end
    end
end

local function onUpdateMapBuff(updateBuffs)
    local changed = false -- 标记是否有变化
    for bid, buff in pairs(updateBuffs) do
        if mapBuffs[bid] == nil then
            -- 新的buff
            mapBuffs[bid] = buff
            local buffInfo = idParseTool.FindMapBuff(bid)
            if buffInfo == nil then
                Warn("MapBuff not found: " .. bid)
            else
              buff.buffInfo = buffInfo
            end
            changed = true
        else
            -- 更新buff
            local buffData = mapBuffs[bid]
            if buffData.time ~= buff.time or buffData.isOpen ~= buff.isOpen or buffData.isEnable ~= buff.isEnable then
                buffData.time = buff.time
                buffData.isOpen = buff.isOpen
                buffData.isEnable = buff.isEnable
                changed = true
            end
             -- 确保 buffInfo 存在
            if not buffData.buffInfo then
                 local buffInfo = idParseTool.FindMapBuff(bid)
                 if buffInfo then
                    buffData.buffInfo = buffInfo
                 else
                    Warn("MapBuff info still not found on update: " .. bid)
                 end
            end
        end
    end
    -- 删除不存在的buff
    local bidsToRemove = {}
    for bid, buff in pairs(mapBuffs) do
        if updateBuffs[bid] == nil then
            table.insert(bidsToRemove, bid)
            changed = true
        end
    end
    for _, bid in ipairs(bidsToRemove) do
        mapBuffs[bid] = nil
    end

    if changed then
        refreshView()
    end
    if _dlg ~=nil then
        _dlg.Raw:ShowDlg(true) -- 显示buff列表
    end
end

local function onShow(luadlg,show)
end

local function onScreenResize(luadlg,w,h)
    if luadlg.Raw then
        if w>800 then
            luadlg.Raw:SetPosition(470,7)
        else
            luadlg.Raw:SetPosition(205,60)
        end
    end
end

local function OnEnterFight()
    if _dlg ~= nil then
        -- 进入战斗隐藏buff列表
        _dlg.Raw:ShowDlg(false)
    end
end

local function OnLeaveFight()
    if _dlg ~= nil then
        -- 退出战斗显示buff列表
        _dlg.Raw:ShowDlg(true)
        -- 退出战斗时可能需要刷新状态
        refreshView() 
    end
end

local function onLogout()
    mapBuffs = {}
    removeBuffShow()
end

local function createDlg(dlgmgr)
    local luadlg = dlgbuilder(dlgmgr,struct,prefix_path,3000)
    _dlg = luadlg
    if game:GetScreenWidth()>800 then
        luadlg.Raw:SetPosition(470,7)
    else
        luadlg.Raw:SetPosition(205,60)
    end
    luadlg.ignoreEsc = true     -- 忽略esc关闭窗口
    events.UpdateMapBuff:Add(onUpdateMapBuff)
    events.EnterFight:Add(OnEnterFight)
    events.LeaveFight:Add(OnLeaveFight)
    events.GameLogout:Add(onLogout)
    luadlg.OnUIPackage = onUIPackage
    luadlg.OnEventProc = onEventProc
    luadlg.OnShow = onShow
    luadlg.OnScreenResize = onScreenResize
    --HandlePackage(EPackageType.MSLGP_G_TYPE_UPDATEPLAYERPROP,luadlg)
    -- 初始时不确定状态，先刷新一次
    refreshView()
    -- 初始显示状态根据游戏逻辑决定，这里假设默认显示
    luadlg.Raw:ShowDlg(true) 
    return luadlg
end

return {OnCreate=createDlg}