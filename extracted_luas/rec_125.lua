local m = {
    UIStore_QueryStoreTipTotalConsume = 101,
    OpenResetEquipPropsDlg = 1000,
    ResetEquipProps = 1001,
    ResetEquipPropsResult = 1002,
    OpenMythicEquipAwakeDlg = 1003,
    AwakeMythicEquipResult = 1004,
    AwakeMythicEquip = 1005,
    OpenEnhanceEquipAwakeDlg = 1006,
    EnhanceEquipAwakeResult = 1007,
    EnhanceEquipAwake = 1008,
    OpenResetEquipAwakeEffectDlg = 1009,
    ResetEquipAwakeEffectResult = 1010,
    ResetEquipAwakeEffect = 1011,
    UpdateCompetitivePVPInfo = 1012,
    PlayCompetitivePVPMagicEffect = 1013,
    EvolvePetChangePetID = 1014,

    -- 鬼市活动事件ID（服务端发往客户端）
    GhostMarket_OpenUI = 1020,              -- 打开鬼市界面
    GhostMarket_LotteryResult = 1021,       -- 抽签结果
    GhostMarket_StockResult = 1022,         -- 上货结果
    GhostMarket_BuyResult = 1023,           -- 购买商品结果
    GhostMarket_RefreshTreasureResult = 1024, -- 刷新秘藏结果
    GhostMarket_ClaimTreasureResult = 1025,   -- 领取秘藏结果

    -- 鬼市活动事件ID（客户端发往服务端）
    GhostMarket_LotteryRequest = 1030,      -- 抽签请求
    GhostMarket_StockRequest = 1031,        -- 上货请求
    GhostMarket_BuyGoodsRequest = 1032,     -- 购买商品请求
    GhostMarket_RefreshTreasureRequest = 1033, -- 刷新秘藏请求
    GhostMarket_ClaimTreasureRequest = 1034,   -- 领取秘藏请求

    -- Consignment S2C
    Consignment_OpenResult       = 1040, -- OpenResult
    Consignment_ListQueryResult  = 1041, -- ListQueryResult
    Consignment_ApplyOpenResult  = 1042, -- ApplyOpenResult
    Consignment_ApplyResult      = 1043, -- ApplyResult
    Consignment_BuyResult        = 1044, -- BuyResult
    Consignment_ClaimResult      = 1045, -- ClaimResult
    Consignment_CancelResult     = 1046, -- CancelResult
    Consignment_SystemClosed     = 1047, -- SystemClosed push (reserved)
    Consignment_NotifyPush       = 1048, -- NotifyPush
    Consignment_ItemPropsResult  = 1049, -- ItemPropsResult (per-order packet)

    -- Consignment C2S
    Consignment_OpenRequest      = 1050, -- OpenRequest
    Consignment_ListQueryRequest = 1051, -- ListQueryRequest
    Consignment_ApplyOpenRequest = 1052, -- ApplyOpenRequest
    Consignment_ApplyRequest     = 1053, -- ApplyRequest
    Consignment_BuyRequest       = 1054, -- BuyRequest
    Consignment_ClaimRequest     = 1055, -- ClaimRequest
    Consignment_CancelRequest    = 1056, -- CancelRequest
    Consignment_ItemPropsRequest = 1057, -- ItemPropsRequest (order_ids csv)
    Consignment_NotifyPageRequest = 1058, -- NotifyPageRequest (C2S {page})
    Consignment_NotifyPageResult  = 1059, -- NotifyPageResult (S2C {total,page,page_size,items})

    -- GodServant (Activity1004) C2S
    GodServant_OpenRequest       = 1060, -- OpenRequest {petIdx}
    GodServant_PrayRequest       = 1062, -- PrayRequest {petIdx}
    GodServant_ResetRequest      = 1064, -- ResetRequest {petIdx}

    -- GodServant (Activity1004) S2C
    GodServant_OpenResult        = 1061, -- OpenResult (full pet state)
    GodServant_PrayResult        = 1063, -- PrayResult (with refreshed state)
    GodServant_ResetResult       = 1065, -- ResetResult (with refreshed state)

    -- 地图突进技能事件ID（通用技能，任意地图可调）
    -- C2S：客户端发往服务端
    PlayerDashRequest             = 1070,   -- 突进请求（{ dir = 0~7，0=上，顺时针方向 }）
    -- S2C：服务端发往客户端
    PlayerDashResult              = 1071,   -- 突进结果（{ ret, errCode, cooldown_ms, x, y }）
}

return m
