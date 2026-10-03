local dlgbuilder = require "dlg_builder"

local struct = require "uighostmarketfortuneinfo_struct"
local prefix_path = "UIGame/UIGhostMarket"

local _dlg = nil

-- 刷新界面
local function refreshView()
    if not _dlg then return end
    
    -- 构建运势说明信息
    local infoText = [[#80350E#一签在手，本期的货色、到手价、库存、门槛、秘藏增
速……都得听它指点。
-----------------------------------------------
签运组合#996600#
·每个签运由 1～2 项运势构成，且可同时生效
·依组合珍稀程度，分为 平运、顺运、鸿运 三档
·抽签或改签时，皆会随机生成新的签运组合
·该签运仅在本期内生效，新一期到来需重新抽取
#80350E#-----------------------------------------------
运势效果#996600#
·惠至：货品的销售价格更低
·见臻：稀货品会更常出现
·盈仓：上架货品的库存更充足
·捷成：秘藏领取进度增长更快
·添物：上架货品的种类增加
·尊免：稀有货品所需贵客点减少
#80350E#-----------------------------------------------
抽签改签小规#996600#
·每期开市时，会依贵客等级恢复若干次免费改签
·免费次数用尽后，可付代价继续改签，单期最多10次
·一旦定运起货，运势即刻锁定，不可再改
]]
    
    _dlg.Info:ClearText()
    _dlg.Info:AddString(infoText,false)
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
    _dlg.Info:SetAutoMove(0)
    
    luadlg.OnEventProc = onEventProc
    luadlg.OnShow = onShow
    
    luadlg.InfoBar:SetListener(luadlg.Info:ToScrollVListener())
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

