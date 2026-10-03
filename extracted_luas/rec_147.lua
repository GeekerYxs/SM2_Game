local models = {}
local function addmodel(m)
    table.insert(models,m)
end

addmodel(require "ui_bless_equip_dlg")
addmodel(require "ui_reset_bless_equip_ability_dlg")
addmodel(require "ui_trans_bless_equip_ability_dlg")
addmodel(require "ui_property_list_dlg")
addmodel(require "ui_input_text_dlg")
addmodel(require "ui_reset_equip_props_dlg")
addmodel(require "ui_mythic_equip_awake_dlg")
addmodel(require "ui_enhance_equip_awake_dlg")
addmodel(require "ui_reset_equip_awake_effect_dlg")
addmodel(require "ui_mapbuff_list_dlg")
addmodel(require "ui_artifact")
addmodel(require "ui_competitivepvpinfobar_dlg")

addmodel(require "ui_competitivepvpmatchpanel_dlg")
addmodel(require "ui_competitivepvpfightteam_dlg")
addmodel(require "ui_competitivepvpfightjournal_dlg")

-- 鬼市
addmodel(require "ghost_market.ui_ghost_market_dlg")
addmodel(require "ghost_market.ui_ghost_market_buy_dlg")
addmodel(require "ghost_market.ui_ghost_market_change_fortune_dlg")
addmodel(require "ghost_market.ui_ghost_market_open_business_dlg")
addmodel(require "ghost_market.ui_ghost_market_change_treasure_dlg")
addmodel(require "ghost_market.ui_ghost_market_fortune_info_dlg")
addmodel(require "ghost_market.ui_ghost_market_info_dlg")

-- Consignment dialogs
addmodel(require "consignment.ui_consignment_dlg")
addmodel(require "consignment.ui_consignment_apply_dlg")
addmodel(require "consignment.ui_consignment_buy_dlg")
addmodel(require "consignment.ui_consignment_buywithtoken_dlg")
addmodel(require "consignment.ui_consignment_undo_dlg")
addmodel(require "consignment.ui_consignment_pickup_dlg")
addmodel(require "consignment.ui_consignment_pickupreturn_dlg")
addmodel(require "consignment.ui_consignment_withdrawal_dlg")
addmodel(require "consignment.ui_consignment_claimrefund_dlg")
addmodel(require "consignment.ui_consignment_notifydetail_dlg")

-- 神侍（Activity1004）
addmodel(require "godservant.ui_godservant_dlg")
addmodel(require "godservant.ui_godservant_confirm_dlg")

-- 地图突进按钮（PlayerDash 1070/1071，常驻地图场景）
-- 暂时关闭, 先提交代码
--addmodel(require "ui_dash_button_dlg")

return models
