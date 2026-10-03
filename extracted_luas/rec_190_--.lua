-- ================================================================
-- 神侍系统配置常量（客户端）
-- 与服务端 Activity/Activity1004/GodServant/GodServantConfig.lua 对齐
-- ================================================================

local Config = {}

Config.MAX_SKILL_SLOTS    = 8   -- 神火技能格（struct Skill1..Skill8）
Config.MAX_MATERIAL_SLOTS = 3   -- 归元材料格（struct Material1..Material3）

-- 归元门槛：神侍等级(=种族 GodServantRank)达到此值（=契约，阶段2 / gsLevel 3）及以上才可归元。
-- 门槛只看等级、不看消耗系数（系数仅用于算花费）。⚠必须与服务端
--   Activity1004/GodServant/GodServantConfig.lua 的 MIN_RESET_GS_LEVEL 一致。
Config.MIN_RESET_GS_LEVEL = 3

-- 归元基础消耗:读 ResLib\GodServantResetCostLib.csv
--   → idtool.GetGodServantResetBase() 返回 { money=, godexp=, materials={ {itemId, baseCount}, ... } }
-- 该 csv 是服务端 DB 表 TSGodServantResetCostLib 的镜像（唯一权威在 DB，改值两边都要改）；
-- 服务端 Lua 走 game:GetGodServantResetCost() 权威扣减，本地只做「显示 + 买得起判定」。
-- 展示用消耗 = 基础量 × 归元消耗系数(当前神侍等级，GodServantLevelLib.csv 第6列)。

-- 颜色（label / atxt 用 #NNNNN 十进制 RGB565；与 ui_reset_equip_props_dlg 同源）
Config.Color = {
    Enough    = "#26592",   -- 足够（绿）
    Lack      = "#53248",   -- 不足（红）
    White     = "#65535",   -- 白
    Highlight  = "#26601",  -- 强调（下次领悟说明里「升级 / 解锁新技能」用）
}

return Config
