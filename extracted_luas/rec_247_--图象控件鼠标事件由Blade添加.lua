UIEventDef = {
    -- 图象控件鼠标事件（由Blade添加）
    TIN_MOUSEOVER = 0x01,
    TIN_MOUSELEAVE = 0x02,
    TIN_MOUSECLICK = 0x03, -- 鼠标点击发生，仅指左键点击
    TIN_MOUSEMOVE = 0x04,
    TIN_MOUSERCLICK = 0x05, -- 鼠标右键点击

    -- 按钮控件事件（由Blade添加）
    TBN_CLICKED = 0x11, -- 按钮发生了一次点击操作（按下，再放开）
    TBN_DBLCLK = 0x12, -- 按钮被鼠标双击，按钮再失效状态下也会发出此事件

    -- Tab控件事件（由袁辉（YH）添加）
    TNM_CLICK = 0x21, -- 

    -- 控件热键事件
    TN_HOTKEY = 0x25, -- 控件默认实现中发送的事件

    -- EDIT控件事件
    -- by Blade
    TEN_CHANGE = 0x31, -- 文本内容发生改变时触发
    TEN_RETURN = 0x32, -- 编辑框内按下回车时发送
    -- 编辑控件得到和失去焦点的事件 qml
    TEN_GETFOCUS = 0x33, -- 得到焦点
    TEN_LOSTFOCUS = 0x34, -- 失去焦点

    -- 矩形型槽控件（由袁辉（YH）添加）
    TRSC_LDOWN = 0x41,
    TRSC_LUP = 0x42,
    TRSC_RDOWN = 0x43,
    TRSC_RUP = 0x44,
    TRSC_MOVE = 0x45,
    TRSC_LEAVE = 0x46,
    TRSC_ENTER = 0x47,

    -- 翻页控件（由袁辉（YH）添加）
    TPGN_HOTITEMCHANGE = 0x51,    

    -- 图像列表消息类型（由袁辉（YH）添加）
    TIMGLIST_CLICK = 0x61,
    TIMGLIST_RCLICK = 0x62,
    TIMGLIST_MOVE = 0x63,
    TIMGLIST_LEAVE = 0x64,
    TIMGLIST_ENTER = 0x65,

    -- 垂直滚动条（由袁辉（YH）添加）
    -- 应用于TWndVScrollBar类（由Blade添加）
    TVSB_TOP = 0x71,
    TVSB_LINEUP = 0x72,
    TVSB_LINEDOWN = 0x73,
    TVSB_PAGEUP = 0x74,
    TVSB_PAGEDOWN = 0x75,
    TVSB_DRAGUP = 0x76,
    TVSB_DRAGDOWN = 0x77,
    TVSB_BOTTOM = 0x78,

    -- 一般滚动条事件，应用于TWndScrollCtrl控件（由Blade添加）
    -- 对应于windows的 SB_??? 消息定义.TSB_DRAGGING = SB_THUMBTRACK;
    -- 应该使用累加方式处理这些消息,并在成功处理后更新滚动条信息
    -- 参考wsCtrlScroll.h文件头说明
    TSB_LINEUP = 0x90,
    TSB_LINEDOWN = 0x91,
    TSB_PAGEUP = 0x92,
    TSB_PAGEDOWN = 0x93,
    TSB_DRAGGING = 0x95,
    TSB_TOP = 0x96,
    TSB_BOTTOM = 0x97,

    -- 弹出式菜单
    TPM_CLICK = 0x101,

    -- 列表控件
    TLN_LDOWN = 0x121, -- 鼠标左键按下
    TLN_LUP = 0x122, -- 左键抬起
    TLN_RDOWN = 0x123, -- 右键下
    TLN_RUP = 0x124, -- 右键上
    TLN_MOVE = 0x125, -- 鼠标在控件上移动
    TLN_LEAVE = 0x126, -- 鼠标离开控件
    TLN_ENTER = 0x127, -- 鼠标进入控件

    -- 遮罩控件事件
    TCN_SELECT = 0x130, -- 表格选中事件
    TCN_MOVE = 0x131, -- 移动到不同的表格上的事件
    TCN_DCLICK = 0x132, -- 双击时产生的事件
    TCN_LSELECT = 0x134,
    TCN_RSELECT = 0x135,
    TCN_LEAVE = 0x136, -- 鼠标离开事件

    -- messagebox 事件
    -- 详细信息请参考wsMessageBoxDlg.h中的说明
    TDN_TIMEOVER = 0x140, -- 定时结束消息
    TDN_CANCELTIMER = 0x141, -- 定时被取消/覆盖

    -- 滚轮事件
    MWN_FORWARD = 0x150, -- 滚轮前滚事件
    MWN_BACKWARD = 0x151, -- 滚轮后滚事件

    TTN_MOUSEMOVE = 0x160, -- text鼠标移动事件
    TTN_MOUSECLICK = 0x161,   -- text鼠标点击事件

    TPIN_END = 0x1000   --动画结束
}

EOperationCmd = {
    None = 0,
    Item_Pickup = 1, -- 拾取物品
    Item_Eat = 2, -- 吃物品

    -- 使用物品
    UseItem_Throw = 3, -- 投掷品
    UseItem_Assisant = 4, -- 使用辅助品
    UseItem_Special = 5, -- 使用特殊品
    UseItem_Temporal = 6, -- 使用时效品
    UseItem_RangeTrick = 7, -- 使用区域整人道具
    UseItem_SingleTrick = 8, -- 使用个体整人道具
    UseItem_TransmitRick = 9, -- 传送整人道具
    UseItem_StealTrick = 10, -- 偷窃整人道具
    UseItem_FightTrick = 11, -- 战斗整人道具
    UseItem_UnTrick = 12, -- 使用反整人道具
    UseItem_PetCard = 13, -- 宠物卡片
    UseItem_AbleStone = 14, -- 技能石
    UseItem_Catch = 15, -- 捕捉道具
    UseItem_Recipe = 16, -- 配方
    UseItem_Other = 17, -- 杂物品
    UseItem_Task = 18, -- 任务物品
    UseItem_Prize = 19, -- 奖励品
    UseItem_Consume = 20, -- 消耗品
    UseItem_TaskSpring = 21, -- 任务触发道具

    -- 特殊类型
    --UseItem_ResetPetCard = 22, -- 洗宠道具
    --UseItem_EnhancePoint = 23, -- 强化药剂
    UseItem_DynamicSelect = 24, -- 动态选择

    -- 其他
    Equip_Pickup = 25, -- 拾取装备
    NPCSale_Pickup = 26, -- 拾取
    NPCPurchase_PickupFromShop = 27, -- 跟NPC购买物品--从商店中拿起物品
    NPCPurchase_PickupFromTrade = 28, -- 跟NPC购买物品--从交易栏中拿起物品
    Trade_PickupFromItemBar = 29, -- 与玩家交易--从玩家的物品栏中拿起物品
    Trade_PickupFromPetBar = 30, -- 与玩家交易--从玩家的宠物栏中拿起物品
    Trade_PickupFromSelfTradeItemBar = 31, -- 与玩家交易--从交易物品栏中拿起物品
    Trade_PickupFromTradePetBar = 32, -- 与玩家交易--从交易宠物品栏中拿起物品
    ShortcutInMap_Pickup = 33,
    ShortcutInFight_Pickup = 34,
    Skill_Pickup = 35,
    Magic_Pickup = 36,
    BankPutIn = 37, -- 存入银行操作
    BankTakeOut = 38, -- 从银行取出操作
    StallPutOn = 39, -- 摆摊货物上架
    VehiclePunIn = 40, -- 放进交通工具物品栏
    VehicleTakeOut = 41, -- 从交通工具物品栏取出
    MailItemTakeOut = 42, -- 从发送邮件窗口移除物品
    PetEquip_Pickup = 43, -- 拾取宠物装备
    PetAble_Pickup = 44, -- 拾取宠物技能
    CheatingScript_PickupPlayerSkill = 45, -- 辅助工具.战斗页面拾取技能/法术图标
    CheatingScript_PickupPetSkill = 46,
    PortableBank_Pickup = 47 -- 拾取随身仓库物品
}

-- 鼠标事件
MOUSEEVENT = {
    MS_NOEVENT    = 0x00000000,

    MS_LDOWN      = 0xFF0100FF,
    MS_LUP        = 0xFF0200FF,
    MS_LCLICK     = 0xFF0300FF,
    MS_LDCLICK    = 0xFF0400FF,
    MS_LDRAG      = 0xFF0500FF,

    MS_RDOWN      = 0xFF1100FE,
    MS_RUP        = 0xFF1200FE,
    MS_RCLICK     = 0xFF1300FE,
    MS_RDCLICK    = 0xFF1400FE,
    MS_RDRAG      = 0xFF1500FE,

    MS_MDOWN      = 0xFF2100FD,
    MS_MUP        = 0xFF2200FD,
    MS_MCLICK     = 0xFF2300FD,
    MS_MDCLICK    = 0xFF2400FD,
    MS_MDRAG      = 0xFF2500FD,

    MS_WFORWARD   = 0xFF3100FC,
    MS_WBACKWARD  = 0xFF3200FC,

    MS_MOVE       = 0xFF400000,

    -- 非一般用途,仅用于代码实现
    MS_DOWN              = 1, -- 事件号
    MS_UP                = 2,
    MS_CLICK             = 3,
    MS_DCLICK            = 4,
    MS_DRAG              = 5,
    MS_BTNCODEMSK        = 0x000000FF, -- 按钮值掩码
    MS_MSKBIT            = 0xFF000000, -- 事件掩码
    MS_BTNMSK            = 0x00F00000, -- 按钮编号掩码
    MS_EVNTMSK           = 0x000F0000, -- 事件掩码
    MS_MSKSTARTBIT       = 24,         -- 位偏移
    MS_BTNMSKSTARTBIT    = 20,
    MS_EVNTMSKSTARTBIT   = 16,
}

-- 键盘事件,按键值取低位字节
-- 按键值定义在<dinput.h>中(DIK_???)定义
KEYBOARDEVENT = {
    KEY_NOEVENT = 0x00000000, -- 无键盘事件
    KEY_DOWN    = 0xFF510000, -- 发生键盘按下事件
    KEY_UP      = 0xFF520000, -- 发生键盘抬起事件
    KEY_PRESS   = 0xFF530000, -- (重复)发生键盘按键事件,注意使用此消息不能同时产生多个按键的消息
}

-- C++ 通过 Lua 桥传入的 uint32 会被当作有符号 int32（高位置 1 的值变成负数）
-- 在这里把 MOUSEEVENT / KEYBOARDEVENT 内 >=0x80000000 的常量统一转换,
-- 以便后续直接用 == 与 eventCode 比较。
local function _toSignedInt32Table(t)
    -- 注意:不能用 0x100000000 字面量,Windows Lua 5.1 走 strtoul 解析 hex,
    -- 33 位以上会被截断为 0xFFFFFFFF,导致结果偏 1。改用十进制 4294967296。
    for k, v in pairs(t) do
        if type(v) == "number" and v >= 0x80000000 then
            t[k] = v - 4294967296
        end
    end
end
_toSignedInt32Table(MOUSEEVENT)
_toSignedInt32Table(KEYBOARDEVENT)

-- DirectInput 按键码（DIK_???，来自 <dinput.h>）
DIK = {
    ESCAPE       = 0x01,
    KEY_1        = 0x02,
    KEY_2        = 0x03,
    KEY_3        = 0x04,
    KEY_4        = 0x05,
    KEY_5        = 0x06,
    KEY_6        = 0x07,
    KEY_7        = 0x08,
    KEY_8        = 0x09,
    KEY_9        = 0x0A,
    KEY_0        = 0x0B,
    MINUS        = 0x0C, -- 主键盘的 -
    EQUALS       = 0x0D,
    BACK         = 0x0E, -- backspace
    TAB          = 0x0F,
    Q            = 0x10,
    W            = 0x11,
    E            = 0x12,
    R            = 0x13,
    T            = 0x14,
    Y            = 0x15,
    U            = 0x16,
    I            = 0x17,
    O            = 0x18,
    P            = 0x19,
    LBRACKET     = 0x1A,
    RBRACKET     = 0x1B,
    RETURN       = 0x1C, -- 主键盘的 Enter
    LCONTROL     = 0x1D,
    A            = 0x1E,
    S            = 0x1F,
    D            = 0x20,
    F            = 0x21,
    G            = 0x22,
    H            = 0x23,
    J            = 0x24,
    K            = 0x25,
    L            = 0x26,
    SEMICOLON    = 0x27,
    APOSTROPHE   = 0x28,
    GRAVE        = 0x29, -- 反引号 `
    LSHIFT       = 0x2A,
    BACKSLASH    = 0x2B,
    Z            = 0x2C,
    X            = 0x2D,
    C            = 0x2E,
    V            = 0x2F,
    B            = 0x30,
    N            = 0x31,
    M            = 0x32,
    COMMA        = 0x33,
    PERIOD       = 0x34, -- 主键盘的 .
    SLASH        = 0x35, -- 主键盘的 /
    RSHIFT       = 0x36,
    MULTIPLY     = 0x37, -- 小键盘的 *
    LMENU        = 0x38, -- 左 Alt
    SPACE        = 0x39,
    CAPITAL      = 0x3A,
    F1           = 0x3B,
    F2           = 0x3C,
    F3           = 0x3D,
    F4           = 0x3E,
    F5           = 0x3F,
    F6           = 0x40,
    F7           = 0x41,
    F8           = 0x42,
    F9           = 0x43,
    F10          = 0x44,
    NUMLOCK      = 0x45,
    SCROLL       = 0x46, -- Scroll Lock
    NUMPAD7      = 0x47,
    NUMPAD8      = 0x48,
    NUMPAD9      = 0x49,
    SUBTRACT     = 0x4A, -- 小键盘的 -
    NUMPAD4      = 0x4B,
    NUMPAD5      = 0x4C,
    NUMPAD6      = 0x4D,
    ADD          = 0x4E, -- 小键盘的 +
    NUMPAD1      = 0x4F,
    NUMPAD2      = 0x50,
    NUMPAD3      = 0x51,
    NUMPAD0      = 0x52,
    DECIMAL      = 0x53, -- 小键盘的 .
    OEM_102      = 0x56, -- 102 键键盘上的 <> 或 \|
    F11          = 0x57,
    F12          = 0x58,
    F13          = 0x64, -- (NEC PC98)
    F14          = 0x65, -- (NEC PC98)
    F15          = 0x66, -- (NEC PC98)
    KANA         = 0x70, -- 日文键盘
    ABNT_C1      = 0x73, -- 巴西键盘上的 /?
    CONVERT      = 0x79, -- 日文键盘
    NOCONVERT    = 0x7B, -- 日文键盘
    YEN          = 0x7D, -- 日文键盘
    ABNT_C2      = 0x7E, -- 巴西键盘上的小键盘 .
    NUMPADEQUALS = 0x8D, -- 小键盘的 = (NEC PC98)
    PREVTRACK    = 0x90, -- 上一曲（日文键盘上为 DIK_CIRCUMFLEX）
    AT           = 0x91, -- (NEC PC98)
    COLON        = 0x92, -- (NEC PC98)
    UNDERLINE    = 0x93, -- (NEC PC98)
    KANJI        = 0x94, -- 日文键盘
    STOP         = 0x95, -- (NEC PC98)
    AX           = 0x96, -- (Japan AX)
    UNLABELED    = 0x97, -- (J3100)
    NEXTTRACK    = 0x99, -- 下一曲
    NUMPADENTER  = 0x9C, -- 小键盘的 Enter
    RCONTROL     = 0x9D,
    MUTE         = 0xA0, -- 静音
    CALCULATOR   = 0xA1, -- 计算器
    PLAYPAUSE    = 0xA2, -- 播放/暂停
    MEDIASTOP    = 0xA4, -- 媒体停止
    VOLUMEDOWN   = 0xAE, -- 音量 -
    VOLUMEUP     = 0xB0, -- 音量 +
    WEBHOME      = 0xB2, -- 网页主页
    NUMPADCOMMA  = 0xB3, -- 小键盘的 , (NEC PC98)
    DIVIDE       = 0xB5, -- 小键盘的 /
    SYSRQ        = 0xB7,
    RMENU        = 0xB8, -- 右 Alt
    PAUSE        = 0xC5, -- Pause
    HOME         = 0xC7, -- 方向键区的 Home
    UP           = 0xC8, -- 方向键区的 ↑
    PRIOR        = 0xC9, -- 方向键区的 PgUp
    LEFT         = 0xCB, -- 方向键区的 ←
    RIGHT        = 0xCD, -- 方向键区的 →
    END          = 0xCF, -- 方向键区的 End
    DOWN         = 0xD0, -- 方向键区的 ↓
    NEXT         = 0xD1, -- 方向键区的 PgDn
    INSERT       = 0xD2, -- 方向键区的 Insert
    DELETE       = 0xD3, -- 方向键区的 Delete
    LWIN         = 0xDB, -- 左 Windows 键
    RWIN         = 0xDC, -- 右 Windows 键
    APPS         = 0xDD, -- 应用菜单键
    POWER        = 0xDE, -- 系统电源
    SLEEP        = 0xDF, -- 系统睡眠
    WAKE         = 0xE3, -- 系统唤醒
    WEBSEARCH    = 0xE5, -- 网页搜索
    WEBFAVORITES = 0xE6, -- 网页收藏
    WEBREFRESH   = 0xE7, -- 网页刷新
    WEBSTOP      = 0xE8, -- 网页停止
    WEBFORWARD   = 0xE9, -- 网页前进
    WEBBACK      = 0xEA, -- 网页后退
    MYCOMPUTER   = 0xEB, -- 我的电脑
    MAIL         = 0xEC, -- 邮件
    MEDIASELECT  = 0xED, -- 媒体选择
}