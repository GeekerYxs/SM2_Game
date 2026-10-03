-- ================================================================
-- 神侍-归元二次确认弹窗（GodServantConfirm）
--
-- 归元有消耗（金币+神识+材料）且不可逆，主界面点「归元」不再直接发请求，
-- 而是先弹本确认框；用户点「确定」才真正发出 GodServant_ResetRequest。
--   btnOK     → 对当前选中宠物 Data.GetPetIdx() 发送归元请求，并关闭本框
--   btnCancel → 仅关闭本框，不做任何操作
-- 由主界面（ui_godservant_dlg）通过 FindDlg("GodServantConfirm"):ShowDlg(true) 唤起。
-- 复用与主界面同一份 godservant_data（require 串必须完全一致以命中同一模块缓存），
-- 从而 GetPetIdx() 取到的是主界面刚选中的那只宠物。
-- ================================================================

local dlgbuilder = require "dlg_builder"

local struct     = require "uigodservantconfirm_struct"

-- 源码写 UTF-8，L() = game:UTF8toASCII 转客户端编码(GBK) 后再交给引擎（资源路径也要过）
local L = function(s) return game:UTF8toASCII(s) end
local prefix_path = L("UIGame/神侍界面/确认窗口")

-- 与主界面 ui_godservant_dlg 使用完全相同的 require 串，命中同一模块缓存、共享选中宠物状态
local network = require "ui.dlgs.godservant.godservant_network"
local Data    = require "ui.dlgs.godservant.godservant_data"

-- ----------------------------------------------------------------
-- 事件处理
-- ----------------------------------------------------------------
local function onEventProc(luadlg, eventCode, ctrlId, ctrl)
    if not luadlg then return end
    if eventCode == UIEventDef.TBN_CLICKED then
        -- 确定：真正发出归元请求，再关闭本框
        if luadlg.btnOK and ctrlId == luadlg.btnOK.CtrlID then
            network.SendResetRequest(Data.GetPetIdx())
            luadlg.Raw:ShowDlg(false)
            return
        end
        -- 取消：仅关闭本框
        if luadlg.btnCancel and ctrlId == luadlg.btnCancel.CtrlID then
            luadlg.Raw:ShowDlg(false)
            return
        end
    end
end

-- ----------------------------------------------------------------
-- 创建
-- ----------------------------------------------------------------
local function createDlg(dlgmgr)
    -- 第 5 个参数 true：文本统一描边（与主界面一致）
    local luadlg = dlgbuilder(dlgmgr, struct, prefix_path, 3000, true)
    luadlg.OnEventProc = onEventProc
    return luadlg
end

return { OnCreate = createDlg }
