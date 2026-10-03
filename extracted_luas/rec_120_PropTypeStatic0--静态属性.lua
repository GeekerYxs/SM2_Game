local propstype = {
    PropTypeStatic = 0,      --// 静态属性
    PropTypeAS = 1,          --// 广义攻击时对自己的属性
    PropTypeAD = 2,          --// 广义攻击时对目标的属性
    PropTypeDS = 3,          --// 广义防守时对自己的属性
    PropTypeDD = 4,          --// 广义防守时对目标的属性
}

local propids = {
    PropIDStrengthUI = 128, -- 2 力量增加
    PropIDStrengthDI = 256, -- 4 力量减少
    PropIDSenseUI =  384, -- 6 感悟增加
    PropIDSenseDI =  512, -- 8 感悟减少
    PropIDResistanceUI =  640, -- 10 耐力增加
    PropIDResistanceDI =  768, -- 12 耐力减少
    PropIDAgilityUI = 896, -- 14 灵敏增加
    PropIDAgilityDI = 1024, -- 16 灵敏减少
    PropIDLuckUI = 1152, -- 18 运气增加
    PropIDLuckDI = 1280, -- 20 运气减少

    PropIDMagicAttUI = 2688, -- 42 法术攻击点数增加
    PropIDAccuracyUI = 3200, -- 50 命中点数增加
    PropIDPhysicDeadlyHarmScaleUI = 7360, -- 115 物理爆伤,暴击伤害的放大倍率  =  Max(50%,（200+爆伤-抗暴伤）/100)
    PropIDNormalAttackScaleUI = 7616, -- 119 普攻伤害百分比,按比例提升普攻攻击力
    PropIDSkillHarmScaleUI = 8512, -- 133 施法伤害, 发动攻击技能或魔法时，按比例%提升伤害
    PropIDCureEffectUI = 10176, -- 159 治疗效果增加

    -- 以下是其他段 ----
    BasePropIDPassiveSkill = 500, -- 被动技能
    PropIDPassiveSkillBegin = 32000, --500 被动技能编号开始
    PropIDPassiveSkillEnd = 32063,   --500 被动技能编号结束
    PropIDPhysicsAttRange = 38400, -- 600 物理攻击力范围（专门用在武器上面，该属性只能用于静态属性）
    PropIDMapIDHide = 38464, -- 601 隐藏的地图编号
    PropIDPositionHide = 38528, -- 602 隐藏的地图位置（高字为 Y 坐标，低字为 X 坐标）
    PropIDDiggingTimes = 38592, -- 603 挖掘次数, (-1 = 未发现)
    PropIDMapCode = 38720, -- 605 地图编号
    PropIDMapCoordinate = 38784, -- 606 地图坐标
    PropIDPosition = 38912, -- 608 地图位置（高字为 Y 坐标，低字为 X 坐标）
    PropIDEvent = 38976,                         -- 609 事件（用于脚本）
    PropIDExp = 39040,                           -- 610 经验
    PropIDSp = 39104,                            -- 611 潜能
    PropIDLevel = 39168,                         -- 612 等级
    PropIDID = 39232,                            -- 613 ID
    PropIDGrowingRateKilo = 39296,               -- 614 成长率（千倍值）
    PropIDStrength = 39424,                      -- 616 力量
    PropIDAgility = 39488,                       -- 617 敏捷
    PropIDResistance = 39552,                    -- 618 体质
    PropIDIntelligence = 39616,                  -- 619 智力
    PropIDSpirit = 39680,                        -- 620 灵力
    PropIDAbleSeriesCode = 39744,                -- 621 天赋系代码
    -- 战士系的进攻天赋系：系号=1
    -- 战士系的体质天赋系：系号=2
    -- 战士系的防护天赋系：系号=4
    -- 敏锐系的残忍天赋系：系号=8
    -- 敏锐系的灵巧天赋系：系号=16
    -- 敏锐系的险恶天赋系：系号=32
    -- 魔法系的破坏天赋系：系号=64
    -- 魔法系的智慧天赋系：系号=128
    -- 魔法系的偏移天赋系：系号=256
    -- 辅助系的活力天赋系：系号=512
    -- 辅助系的祈福天赋系：系号=1024
    -- 辅助系的恢复天赋系：系号=2048
    -- 控制系的操纵天赋系：系号=4096
    -- 控制系的精神天赋系：系号=8192
    -- 控制系的增强天赋系：系号=16384

    --  修改时要同步修改CParseProp中的ParseResistName函数
    PropIDRPoisoning = 39808,    -- 622 抗中毒
    PropIDRWeaken = 39872,       -- 623 抗削弱
    PropIDRSlow = 39936,         -- 624 抗缓慢
    PropIDRSleep = 40000,        -- 625 抗睡眠
    PropIDRWrap = 40064,         -- 626 抗缠绕
    PropIDRStable = 40128,       -- 627 抗定身
    PropIDRConfusion = 40192,    -- 628 抗混乱
    PropIDRSealmagic = 40256,    -- 629 抗封魔
    PropIDRSealskill = 40320,    -- 630 抗封技
    PropIDRAberrance = 40384,    -- 631 抗变身
    --抗性表
    PropIDResistances = {PropIDRPoisoning,PropIDRWeaken,PropIDRSlow,PropIDRSleep,PropIDRWrap,PropIDRStable,PropIDRConfusion,PropIDRSealmagic, PropIDRSealskill},

    PropIDRepareTimes = 40640,       -- 635 特修次数
    PropIDEnhanceTimes = 40704,      -- 636 强化次数
    PropIDEnhanceAttEffect = 40768,  -- 637 穿刺强化次数
    PropIDEnhanceDefEffect = 40832,  -- 638 坚固强化次数
    PropIDIntergrowthEnhance = 40896, -- 639 共生强化

    PropIDDate = 41216, -- 644 属性（高字为年，低字高字节为月，低字低字节为日）

    PropIDMoveSpeedMulti = 43968, -- 687 移动速度加成(百分比), 0 表示默认值
    PropIDMoveSpeedChange = 44032, -- 688 移动速度变化值, 0 表示默认值

    -- kylin剥离宠物新增
    PropIDReqLevel = 42624, -- 666 剥离后卡片的等级限制
    PropIDLearnExp = 42688, -- 667 宠物内丹所包含的宠物训练经验

    PropIDSoulshift = 42752, -- 668 宠物卡片的转生属性0表示未转生
    PropIDXiuLianLevel = 42880, -- 670 修炼等级释放宠物时需要根据修炼等级添加宠物被动技能
    PropIDStarLevel = 42944, -- 671 星级
    PropIDAwakenLevel = 43008, -- 672 觉醒等级

    -- 绑定属性
    PropIDEquipBind = 43136, -- 674 装备绑定状态， 0 或无属性=未绑定， 1 = 已绑定

    -- 内含元宝
    PropIDGoldYuanbao = 43200, -- 675 内涵可领取的金元宝数量
    PropIDSilverYuanbao = 43264, -- 676 内含可领取的银元宝数量

    PropIDEquipBlessRank = 44224,    --装备祝福阶段
    PropIDEquipBlessLevel = 44288,   --装备祝福等级
    PropIDEquipBlessAbility = 44352, --装备祝福能力
    PropIDEquipBlessCandidateAbility = 44416, --装备祝福待选能力
    PropIDEquipBlessCandidateAbility2 = 44480, --装备祝福待选能力2，激活需要费用

    PropIDEnhanceLoseTimes = 44544, -- 696 强化失败次数
    --
    PropIDOther = 63936, -- 999 其他属性，数据库中不定义该值
}

-- 返回这两个表,供其他模块使用
return {
    PropType = propstype,
    PropID = propids
}