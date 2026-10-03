local dlgbuilder = require "dlg_builder"

local struct = require "uighostmarketinfo_struct"
local prefix_path = "UIGame/UIGhostMarket"

local _dlg = nil

-- 刷新界面
local function refreshView()
    if not _dlg then return end
    
    -- 构建系统规则说明信息
    _dlg.Rule:ClearText()
    _dlg.Rule:AddString("#80350E#本店规矩不少，掌柜怕各位客官一时看花了眼，特将要点逐条记下。入市之前，劳烦过目一遍，买得明白，拿得痛快。\n", false)
    _dlg.Rule:AddString("#80350E#-------------------------------------------------\n", false)
    _dlg.Rule:AddString("#80350E#会客之道（开张时间说明）\n\n", false)
    _dlg.Rule:AddString("#996600#市季是啥？\n", false)
    _dlg.Rule:AddString("#996600#·市季为一段售卖时期，此间便宜坊会按时开张迎客\n", false)
    _dlg.Rule:AddString("#996600#·本市季行市日期：#13501B#2025/11/22 ～ 2025/12/04\n", false)
    _dlg.Rule:AddString("#996600#·每逢市季初开，本店皆会重新整备货品池并调整售价\n\n", false)
	_dlg.Rule:AddString("#996600#按期售卖\n", false)
    _dlg.Rule:AddString("#996600#·市季开张后，会再按“期”来分段售卖\n", false)	
    _dlg.Rule:AddString("#996600#·每一期都需重新抽签与起货，各期互不影响\n", false)	
    _dlg.Rule:AddString("#996600#·每期开张时，免费改签次数、货架状态都会重置\n", false)	
    _dlg.Rule:AddString("#996600#·每期持续 2 天，每周三期的开市时如下\n", false)	
    _dlg.Rule:AddString("#13501B#　- 周一 8:00 ～ 周二 23:59\n", false)		
    _dlg.Rule:AddString("#13501B#　- 周三 8:00 ～ 周四 23:59\n", false)		
    _dlg.Rule:AddString("#13501B#　- 周五 8:00 ～ 周日 23:59\n\n", false)		
	_dlg.Rule:AddString("#80350E#-------------------------------------------------\n", false)
    _dlg.Rule:AddString("#80350E#定运起货（抽签、改签、起货）\n\n", false)
    _dlg.Rule:AddString("#996600#抽签及改签\n", false)
    _dlg.Rule:AddString("#996600#·本掌柜行事随缘，客观签运好坏，所见货品各异\n", false)
    _dlg.Rule:AddString("#996600#·商品种类、数量、售价等，全随签运而变\n", false)
	_dlg.Rule:AddString("#996600#·起货上架前，客观务必先抽一签，获得本期运势\n", false)
    _dlg.Rule:AddString("#996600#·若签运不够合心意，可用改签再试手气\n\n", false)	
    _dlg.Rule:AddString("#996600#上架起货\n", false)
    _dlg.Rule:AddString("#996600#·一旦“定运起货”，本期签运与上架货品便一并锁定\n", false)
    _dlg.Rule:AddString("#996600#·每期仅能起货一次，买定离手，不可在改\n", false)
	_dlg.Rule:AddString("#996600#·上架之物皆为一次性陈列，卖完即止\n\n", false)
    _dlg.Rule:AddString("#996600#定期重置\n", false)	
    _dlg.Rule:AddString("#996600#·每逢新一期开市，货架与签运皆会回到初始状态\n", false)
    _dlg.Rule:AddString("#996600#·客官需重新走一遍 抽签->定运起获 的流程\n\n", false)
	_dlg.Rule:AddString("#80350E#-------------------------------------------------\n", false)
    _dlg.Rule:AddString("#80350E#秘藏奖励（消费奖励）\n\n", false)
    _dlg.Rule:AddString("#996600#奖励品由来\n", false)
    _dlg.Rule:AddString("#996600#·店内消费可积累奖励领取进度，满值即可免费领取\n", false)
    _dlg.Rule:AddString("#996600#·奖励品为随机抽取，若不合心意，可花费贵客点更换\n", false)
    _dlg.Rule:AddString("#996600#·不同奖品所需领取进度值各不相同\n\n", false)
    _dlg.Rule:AddString("#996600#进度及领取\n", false)
    _dlg.Rule:AddString("#996600#·每消费1元宝，增加1点进度值\n", false)
    _dlg.Rule:AddString("#996600#·若得“捷成签运”相助，进度增长效率更高\n", false)
    _dlg.Rule:AddString("#996600#·秘藏奖品及其进度值均为长期累积，可跨期保留\n", false)	
    _dlg.Rule:AddString("#996600#·领取奖品后，进度会被清空，并立刻生成下一份奖品\n\n", false)		
    _dlg.Rule:AddString("#996600#更换奖励品\n", false)
    _dlg.Rule:AddString("#996600#·更换会随机更改奖励内容，但不会重置进度\n", false)
    _dlg.Rule:AddString("#996600#·更换次数按期统计，更换次数越多，代价越高\n\n", false)	
	_dlg.Rule:AddString("#80350E#-------------------------------------------------\n", false)	
    _dlg.Rule:AddString("#80350E#贵客等级（成长权益）\n\n", false)
    _dlg.Rule:AddString("#996600#贵客等级的作用\n", false)
    _dlg.Rule:AddString("#996600#·部分稀缺货品需达到指定等级方能购买\n", false)
    _dlg.Rule:AddString("#996600#·每期会自动回复对应档位的贵客点\n", false)
    _dlg.Rule:AddString("#996600#·贵客点存储上限与免费改运次数随等级提升而提高\n\n", false)
    _dlg.Rule:AddString("#996600#等级权益一览\n", false)
    _dlg.Rule:AddString("#996600#·贵客等级提升：  新客->熟客->尊客->上宾->合伙人\n", false)
    _dlg.Rule:AddString("#996600#·每期恢复贵客点：6->8->10->12->15 \n", false)
    _dlg.Rule:AddString("#996600#·贵客点存储上限：12->15->18->21->25 \n", false)	
    _dlg.Rule:AddString("#996600#·每期免费改运数：3->4->6->8->10 \n\n", false)		
    _dlg.Rule:AddString("#996600#贵客等级提升\n", false)
    _dlg.Rule:AddString("#996600#·多次领取秘藏后，可逐步提升贵客等级\n", false)
    _dlg.Rule:AddString("#996600#·越高的贵客等级，越能享更多福利 \n\n", false)
	_dlg.Rule:AddString("#80350E#-------------------------------------------------\n", false)		
    _dlg.Rule:AddString("#80350E#货品与秘藏奖励（本市季内容）\n\n", false)
    _dlg.Rule:AddString("#996600#按季规划\n", false)
    _dlg.Rule:AddString("#996600#·每一市季都会重新规划当季货品种类，并制定新的售价\n", false)
    _dlg.Rule:AddString("#996600#·当季的秘藏奖励内容也会随市季一并更新\n\n", false)
    _dlg.Rule:AddString("#996600#本季货品及奖励\n", false)	
    _dlg.Rule:AddString("#996600#·本季货品涵盖大部分常用资源，种类繁多，恕不列举\n", false)	
    _dlg.Rule:AddString("#996600#·本季秘藏奖励涵盖多类精选资源，其中压轴好物包括：\n", false)	
    _dlg.Rule:AddString("#996600#	(御)灵魂共鸣石、(御)真灵印记、神牌洗炼石1阶\n", false)		
	_dlg.Rule:AddString("#996600#	特殊4阶武器试管、巨龙的遗骨、龙焰结晶 \n", false)	
	_dlg.Rule:AddString("#996600#	生肖甜甜圈、(御)洗髓丹、(御)高级恶魔果实\n\n", false)		
	_dlg.Rule:AddString("#80350E#-------------------------------------------------\n", false)		
    _dlg.Rule:AddString("#50164A#规矩都摆在这里，客官只需按规而行", false)
    _dlg.Rule:AddString("#04bb23#\n", false)
end

-- 事件处理
local function onEventProc(luadlg, eventCode, ctrlId, ctrl)
    if eventCode == UIEventDef.TBN_CLICKED then
        if ctrlId == luadlg.Close.CtrlID then
            -- 关闭按钮
            luadlg.Raw:ShowDlg(false)
        end
    end
end

-- 显示状态改变
local function onShow(luadlg, show)
    if show then
        refreshView()
    end
end

-- 创建对话框
local function createDlg(dlgmgr)
    local luadlg = dlgbuilder(dlgmgr, struct, prefix_path, 3000)
    _dlg = luadlg
    _dlg.Rule:SetAutoMove(0)
    
    luadlg.OnEventProc = onEventProc
    luadlg.OnShow = onShow

    luadlg.InfoBar:SetListener(luadlg.Rule:ToScrollVListener())
    luadlg.InfoBar:SetImage(
        prefix_path.."/vscroll_bar.mgff",
        prefix_path.."/vscroll_down.mgff",
        prefix_path.."/vscroll_down.mgff",
        prefix_path.."/vscroll_up.mgff",
        prefix_path.."/vscroll_up.mgff"
    )
    
    refreshView()
    
    return luadlg
end

return {OnCreate = createDlg}

