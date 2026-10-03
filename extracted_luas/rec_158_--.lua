-- ================================================================
-- 寄售系统配置常量
-- 与服务端 Activity/Activity1003/Consignment/ConsignmentConfig.lua 保持一致
-- 客户端 UI 文案/计算一律读这里，绝不硬编码数字
-- ================================================================

local Config = {}

-- ----------------------------------------------------------------
-- 关键配置默认值
-- ----------------------------------------------------------------
Config.COIN_PER_YUANBAO     = 1000        -- 申请寄售手续费金币 = 总价(元宝) × 此值
Config.FEE_RATE_PERCENT     = 5           -- 卖家收款扣的元宝手续费率（%），实付 = 总价 × 95%
Config.FEE_MIN_YUANBAO      = 1           -- 卖家取款手续费下限（元宝）：按比率算出的手续费不足此值时，按此值收取（保证小额单也至少收 1 元宝）。
Config.APPLY_LEVEL_REQUIRED = 70          -- 申请寄售所需角色等级下限
Config.DAILY_APPLY_LIMIT    = 15          -- 每日申请上限（按角色，超出报 1005 E_DAILY_APPLY_LIMIT）
Config.DAILY_CANCEL_LIMIT   = 4           -- 每日撤销上限（按角色，超出报 1006 E_DAILY_CANCEL_LIMIT）
Config.CONCURRENT_LISTING_LIMIT = 10      -- 同时在售订单上限（按角色，在售+公示+审核都算占位，超出报 1007 E_CONCURRENT_LIMIT）
Config.DAILY_BUY_LIMIT      = 20          -- 每日购买订单数上限（按账号，超出报 1017 E_DAILY_BUY_COUNT_LIMIT）
Config.DAILY_PAY_LIMIT      = 10000       -- 每日累计支付元宝上限（按账号，超出报 1018 E_DAILY_PAY_LIMIT）
Config.PUBLIC_HOURS         = 3           -- 公示时长（小时）：申请通过后挂在「即将上架」的时长
Config.AUDIT_BUFFER_HOURS   = 1           -- 交易审核缓冲期（小时）：售出后进入审核的时长
Config.MAX_LISTING_DAYS     = 30          -- 订单最长上架天数，到期自动过期可退货
Config.PAGE_SIZE            = 8           -- 列表每页固定 8 条，不可修改
Config.NOTIFY_PAGE_SIZE     = 6           -- 通知历史每页条数；须 = 主界面 struct 的 History 槽位数 = 服务端 notification_page_size
Config.MIN_TOTAL_PRICE      = 10          -- 单笔订单元宝总价下限（含）：申请时校验，总价必须高于 10 元宝
Config.MAX_TOTAL_PRICE      = 10000       -- 单笔订单元宝总价上限（申请时校验）
Config.MAX_FEE              = 10000000    -- 单笔订单手续费金币上限（申请时校验）
Config.MAX_SEARCH_ITEM_IDS  = 50         -- 搜索框模糊匹配（"包含"规则）回退时最多下发的 itemid 数（防止超包 / SQL IN 过长，服务端会再次截断）；超过时只取 ItemLib 前面匹配的这么多个
Config.MIN_SEARCH_FUZZY_BYTES = 4        -- 模糊匹配回退所需的最小输入字节数：GBK 下 4 字节 = 2 个中文（或 4 个英文字符）。精确命中物品全名不受此限；仅在回退模糊匹配前拦截过短输入，不足时本地直接拒绝并提示"请至少输入两个字"
Config.BROWSE_COOLDOWN_SEC  = 1.3         -- 浏览操作冷却（秒）：搜索 / 翻页 / 刷新 三者共用一个冷却，两次操作间隔短于此值时本地直接拒绝并提示"请求间隔过短"（服务端有同名兜底 browse_cooldown_sec=1）。设为 0 关闭。
                                          -- 故意比服务端的 1 秒大一点（留 0.3s 余量）：本地用 os.clock()/帧节拍计时，与服务端各自的时钟有抖动；若两边都卡 1 秒，申请寄售后自动刷新(list+notify 各排一发)按 1 秒派发时，客户端以为满 1 秒、服务端却仍判 <1 秒被回 1038“请求过快”。设大于服务端值即可避免，勿改回 1。


-- ----------------------------------------------------------------
-- PageMode 列表页签
-- ----------------------------------------------------------------
Config.PageMode = {
    OnSaleDisplay = 1,  -- 在售品陈列：所有可购买的开售订单
    ComingSoon    = 2,  -- 即将上架：处于公示期、尚未开售
    MyOrders      = 3,  -- 我的订单：本角色作为卖家/买家的订单
}

-- ----------------------------------------------------------------
-- Sort 排序方式
-- ----------------------------------------------------------------
Config.Sort = {
    TimeDesc  = 1, -- 上架时间降序（最新→最旧）(select0) —— 浏览页默认
    PriceAsc  = 2, -- 单价升序 (select1)；单价 = total_price / item_count
    PriceDesc = 3, -- 单价降序 (select2)
    CountAsc  = 4, -- 数量升序 (select3)
    CountDesc = 5, -- 数量降序 (select4)
    Mine      = 6, -- 「我的订单」(select5)：本页签内只看自己挂的货，按上架时间降序（仅在售/即将上架可选）
    Category  = 7, -- 「分类排序」(select6)：仅我的交易，待处理按紧急程度分组+组内时间降序，操作完毕单时间降序兜底（我的交易默认）
}

-- ----------------------------------------------------------------
-- Identity 「我的订单」身份筛选
-- ----------------------------------------------------------------
Config.Identity = {
    All    = 0, -- 全部（默认）
    Seller = 1, -- 我的寄售（作为卖家）
    Buyer  = 2, -- 我的购买（作为买家）
}

-- ----------------------------------------------------------------
-- ClaimType 领取类型（ClaimRequest.type）
-- ----------------------------------------------------------------
Config.ClaimType = {
    Yuanbao       = 1, -- 卖家收款：trade_phase=4 且 end_type=0 且 yuanbao_claimed=0
    Item          = 2, -- 买家收货：trade_phase=4 且 end_type=0 且 item_claimed=0
    RefundItem    = 3, -- 卖家退货：撤销或过期且 item_claimed=0
    RefundYuanbao = 4, -- 买家退款：trade_phase∈{3,4} 且 end_type∈{1,2} 且 yuanbao_claimed=0（审核期或成交后双方未领取被撤销）
}

-- ----------------------------------------------------------------
-- 订单状态三元组（order_run / trade_phase / end_type）
-- 注：「过期」「售罄」不在 end_type 里 —— 过期看 expired=1，售罄看 trade_phase=4
-- ----------------------------------------------------------------
Config.OrderRun = {
    Open   = 1, -- 正常运行
    Frozen = 2, -- 已冻结（仅管理员可处理）
}

Config.TradePhase = {
    Public       = 1, -- 公示中（默认 3 小时）
    OnSale       = 2, -- 开售中（可被购买）
    Audit        = 3, -- 交易审核（缓冲期，默认 1 小时）
    TradeSuccess = 4, -- 交易成功（等双方领取）
}

Config.EndType = {
    None         = 0, -- 未结束
    PlayerCancel = 1, -- 卖家主动撤销
    AdminCancel  = 2, -- 管理员强制撤销
}

-- ----------------------------------------------------------------
-- EventCode 通知行为码（18 个，与服务端 ConsignmentConfig.EventCode 对齐）
--     通知不再下发渲染文本：客户端按 event_code 查 S.NOTIFY 模板渲染标题/详情。
-- ----------------------------------------------------------------
Config.EventCode = {
    APPLY              = 1,  -- 申请寄售，进入公示
    ON_SALE            = 2,  -- 公示转开售 / 管理员开售，已上架
    EXPIRED            = 3,  -- 超时下架，待退货
    CANCEL_SELF        = 4,  -- 主动撤销，待退货
    CANCEL_ADMIN       = 5,  -- 管理员撤销，待退货（组运行时定）
    SOLD               = 10, -- 被拍下，待审核
    PENDING_WITHDRAW   = 11, -- 审核通过，待取款（yuanbao=货款总价）
    WITHDRAWN          = 12, -- 领取货款，已取款（yuanbao=到账净额）
    RETURNED           = 14, -- 领取退货，已退货
    BOUGHT             = 20, -- 交易支付，待审核（yuanbao=支付总价）
    PENDING_PICKUP     = 21, -- 审核通过，待取货
    PICKED_UP          = 22, -- 领取货品，已取货
    CANCEL_ADMIN_BUYER = 23, -- 管理员撤销·买家侧，待退款（yuanbao=退款全额）
    REFUNDED           = 24, -- 领取退款，已退款（yuanbao=退款全额）
    FROZEN_SELLER      = 30, -- 卖家·冻结（组运行时定）
    UNFROZEN_SELLER    = 31, -- 卖家·解冻（组运行时定）
    FROZEN_BUYER       = 32, -- 买家·冻结
    UNFROZEN_BUYER     = 33, -- 买家·解冻
}

-- ----------------------------------------------------------------
-- DetailGroup 详情卡片模板组（决定卡片布局：卖家·未交易 / 卖家·已交易 / 买家）
-- ----------------------------------------------------------------
Config.DetailGroup = {
    SellerUntraded = 1, -- 卖家·未交易：出售行 + 口令设置行
    SellerTraded   = 2, -- 卖家·已交易：出售行 + 买家行
    Buyer          = 3, -- 买家：购买行 + 卖家行
}

-- ----------------------------------------------------------------
-- CloseReason 强制关闭界面控制推送（Consignment_SystemClosed.reason）
-- ----------------------------------------------------------------
Config.CloseReason = {
    SystemClosed = 1, -- 系统熔断
    DailyClosed  = 2, -- 每日打烊
    Blacklisted  = 3, -- 账号被拉黑
}

return Config
