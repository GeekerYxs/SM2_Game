-- 不允许打包空白文件
local events = require("events")
local ScriptEvent = require "script_event"

-- 查询商城消费提示
function OnCallScriptID101(EventID, data)
    --Info( "eventid = ".. EventID .. ",data=" .. TableToString(data))

    local storedlg = game:GetUIStoreDlg()
    if not storedlg then
        return
    end

    -- local tipdata =
    -- {
    --     start = '2024-1-1 10:00:00',
    --     finish =  '2024-12-1 10:00:00',

    --     cost1 = totalConsume,
    --     cost2 = specItemConsume,
    --     cost3 = itemListConsume,
    --
    --     serverid = 101,  -- 服务器ID，用于区分不同服务器的提示内容
    -- }
    local i = string.find(data.start, '%s')
    local startstr = string.sub(data.start, 1, i)
    i = string.find(data.finish, '%s')
    local finishstr = string.sub(data.finish, 1, i)

    local serverid = data.serverid or 101

    -- 商城tip描述, 累计消费代码:cost1=商城累计消费, cost2=购买妖精之尘统计, cost3=购买神装材料统计
    local tipstr = "#ffc000#大冒险商城十月活动介绍"
    if serverid == 101 then
        -- 101: 【逍遥村敬老院】
        tipstr = tipstr .. "\n" .. ""
		tipstr = tipstr .. "\n" .. "#47D45A#重点关注："
		tipstr = tipstr .. "\n" .. "#C2F1C8#------------------------------"
		tipstr = tipstr .. "\n" .. ""

		tipstr = tipstr .. "\n" .. "#FF7C80#1、恒久周常礼包，战备福利上线！"
		tipstr = tipstr .. "\n" .. "#C8F8A5#购买限量周常礼包，找福利大师进行印章通兑，开启盲盒助力战力狂飙！"
		tipstr = tipstr .. "\n" .. ""

		tipstr = tipstr .. "\n" .. "#FF7C80#2、百炼嘉奖"
		tipstr = tipstr .. "\n" .. "#C8F8A5#完成任意一项百炼目标，即可获赠："
		tipstr = tipstr .. "\n" .. "#00FF99# [超能币δ]x100"
		tipstr = tipstr .. "\n" .. "#00FF99# [(御)超高级疯火轮]x25"
		tipstr = tipstr .. "\n" .. ""

		tipstr = tipstr .. "\n" .. "#FF7C80#3、充值消费赠礼"
		tipstr = tipstr .. "\n" .. "#C8F8A5#累充每500元或消费400元宝："
		tipstr = tipstr .. "\n" .. "#C8F8A5# 可自选一次奖品，包含："
		tipstr = tipstr .. "\n" .. "#00FF99# [真灵印记]、[神牌碎片·觉能]"
		tipstr = tipstr .. "\n" .. "#00FF99# [神牌碎片]、[超能币δ]"
		tipstr = tipstr .. "\n" .. "#00FF99# [pp鸡纪念玩偶]、[神祈泡泡]"
		tipstr = tipstr .. "\n" .. "#00FF99# [仿造企鹅皮]、[企鹅绒毛]"
		tipstr = tipstr .. "\n" .. "#00FF99# [冥饰强化秘匣]、[圣树甘露]"
		tipstr = tipstr .. "\n" .. ""

        tipstr = tipstr .. "\n" .. "#FF7C80#4、经典补货（高折扣，推荐购买）"
        tipstr = tipstr .. "\n" .. "#FFFF00# [修炼工匠箱][神铸工匠箱]"
		tipstr = tipstr .. "\n" .. ""

		tipstr = tipstr .. "\n" .. "#46B1E1#各城镇的福利大师可查看活动详情"

        --   tipstr = tipstr .. "\n" .. "#46b1e1#当前累积消费额：" .. tostring(data.cost2)
        --   tipstr = tipstr .. "\n" .. "#00b0f0#当前累积消费额：" .. tostring(data.cost3)
    elseif serverid == 102 then
        -- 102: 【乌龙村幼儿园】
        tipstr = tipstr .. "\n" .. ""
		tipstr = tipstr .. "\n" .. "#47D45A#重点关注："
		tipstr = tipstr .. "\n" .. "#C2F1C8#------------------------------"
		tipstr = tipstr .. "\n" .. ""

		tipstr = tipstr .. "\n" .. "#FF7C80#1、恒久周常礼包，战备福利上线！"
		tipstr = tipstr .. "\n" .. "#C8F8A5#购买限量周常礼包，找福利大师进行印章通兑，开启盲盒助力战力狂飙！"
		tipstr = tipstr .. "\n" .. ""

		tipstr = tipstr .. "\n" .. "#FF7C80#2、百炼嘉奖"
		tipstr = tipstr .. "\n" .. "#C8F8A5#完成任意一项百炼目标，即可获赠："
		tipstr = tipstr .. "\n" .. "#00FF99# [超能币δ]x100"
		tipstr = tipstr .. "\n" .. "#00FF99# [(御)超高级疯火轮]x25"
		tipstr = tipstr .. "\n" .. ""

		tipstr = tipstr .. "\n" .. "#FF7C80#3、充值消费赠礼"
		tipstr = tipstr .. "\n" .. "#C8F8A5#累充每500元或消费400元宝："
		tipstr = tipstr .. "\n" .. "#C8F8A5# 可自选一次奖品，包含："
		tipstr = tipstr .. "\n" .. "#00FF99# [真灵印记]、[神牌碎片·觉能]"
		tipstr = tipstr .. "\n" .. "#00FF99# [神牌碎片]、[超能币δ]"
		tipstr = tipstr .. "\n" .. "#00FF99# [pp鸡纪念玩偶]、[神祈泡泡]"
		tipstr = tipstr .. "\n" .. "#00FF99# [仿造企鹅皮]、[企鹅绒毛]"
		tipstr = tipstr .. "\n" .. "#00FF99# [冥饰强化秘匣]、[圣树甘露]"
		tipstr = tipstr .. "\n" .. ""

        tipstr = tipstr .. "\n" .. "#FF7C80#4、经典补货（高折扣，推荐购买）"
        tipstr = tipstr .. "\n" .. "#FFFF00# [修炼工匠箱][神铸工匠箱]"
		tipstr = tipstr .. "\n" .. ""

		tipstr = tipstr .. "\n" .. "#46B1E1#各城镇的福利大师可查看活动详情"

        --   tipstr = tipstr .. "\n" .. "#46b1e1#当前累积消费额：" .. tostring(data.cost2)
        --   tipstr = tipstr .. "\n" .. "#00b0f0#当前累积消费额：" .. tostring(data.cost3)
    else
        -- 若服务器编号未列出，则不显示任何提示信息
        tipstr = tipstr .. "\n" .. ""
		tipstr = tipstr .. "\n" .. "#47D45A#重点关注："
		tipstr = tipstr .. "\n" .. "#C2F1C8#------------------------------"
		tipstr = tipstr .. "\n" .. ""

		tipstr = tipstr .. "\n" .. "#FF7C80#1、恒久周常礼包，战备福利上线！"
		tipstr = tipstr .. "\n" .. "#C8F8A5#购买限量周常礼包，找福利大师进行印章通兑，开启盲盒助力战力狂飙！"
		tipstr = tipstr .. "\n" .. ""

		tipstr = tipstr .. "\n" .. "#FF7C80#2、百炼嘉奖"
		tipstr = tipstr .. "\n" .. "#C8F8A5#完成任意一项百炼目标，即可获赠："
		tipstr = tipstr .. "\n" .. "#00FF99# [超能币δ]x100"
		tipstr = tipstr .. "\n" .. "#00FF99# [(御)超高级疯火轮]x25"
		tipstr = tipstr .. "\n" .. ""

		tipstr = tipstr .. "\n" .. "#FF7C80#3、充值消费赠礼"
		tipstr = tipstr .. "\n" .. "#C8F8A5#累充每500元或消费400元宝："
		tipstr = tipstr .. "\n" .. "#C8F8A5# 可自选一次奖品，包含："
		tipstr = tipstr .. "\n" .. "#00FF99# [真灵印记]、[神牌碎片·觉能]"
		tipstr = tipstr .. "\n" .. "#00FF99# [神牌碎片]、[超能币δ]"
		tipstr = tipstr .. "\n" .. "#00FF99# [pp鸡纪念玩偶]、[神祈泡泡]"
		tipstr = tipstr .. "\n" .. "#00FF99# [仿造企鹅皮]、[企鹅绒毛]"
		tipstr = tipstr .. "\n" .. "#00FF99# [冥饰强化秘匣]、[圣树甘露]"
		tipstr = tipstr .. "\n" .. ""

        tipstr = tipstr .. "\n" .. "#FF7C80#4、经典补货（高折扣，推荐购买）"
        tipstr = tipstr .. "\n" .. "#FFFF00# [修炼工匠箱][神铸工匠箱]"
		tipstr = tipstr .. "\n" .. ""

		tipstr = tipstr .. "\n" .. "#46B1E1#各城镇的福利大师可查看活动详情"

        --   tipstr = tipstr .. "\n" .. "#46b1e1#当前累积消费额：" .. tostring(data.cost2)
        --   tipstr = tipstr .. "\n" .. "#00b0f0#当前累积消费额：" .. tostring(data.cost3)
    end

    -- 调用接口设置提示信息
    storedlg:SetOnSellTip(tipstr)
end

-- 检测商城打开
local function OnShowUIStore(wndname, bShow)
    if wndname == "Store" and bShow == true then
        local storedlg = game:GetUIStoreDlg()
        if not storedlg then
            return
        end
        storedlg:SetOnSellTip("查询中")
        game:SendCallScriptPacket(ScriptEvent.UIStore_QueryStoreTipTotalConsume, {})
    end
end

events.OnShowUIWindow:Add(OnShowUIStore)
