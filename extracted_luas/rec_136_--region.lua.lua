--region *.lua
--Date
--此文件由[BabeLua]插件自动生成

-- 每日-泡温泉(单人-用券加时加倍)【注意：因为有地图加速功能（时装、交通工具），所以要注意，可能会出现有加速的玩家提前完成的情况】【目前先做界面提醒处理】

-- 

-- task_state: 0 = 未接受, 1 = 向目标进发点NPC传送, 2 = 任务进行中处理NPC选项 , 3 = 行进中穿过传送点, 4 = 找NPC提交任务 (提交后删除就没有任务了)
-- 行动数据定义
local act1_data = {

    presteps = {

    },

    steps = {

        --龙之都外城
        {name="移动到温泉服务生甲",action="move", mapid = 20, pos = {x = 3528, y = 1076}},
        {name="点击温泉服务生甲",action="click_npc_dialog", npc_id=39}, 
        {name="点击我要泡温泉",action="menu_dialog", menu="我要泡温泉"}, 
        {name="点击确定",action="menu_transmap", menu="确定", tomapid=305},



		--使用15张温泉消费券，加倍奖励
        {name="等个2秒", action="delay" , delay = 2.0},
        {action="move", mapid = 305, pos = {x = 1580, y = 295}},
        {action="click_npc_dialog", npc_id=41}, 
        {action="menu_dialog", menu="使用温泉消费券加倍奖励"}, 
        {action="menu", menu="使用15张温泉消费券"}, 



		--使用3张温泉消费券，增加15分钟时间
        {name="等个2秒", action="delay" , delay = 2.0},
        {action="move", mapid = 305, pos = {x = 1580, y = 295}},
        {action="click_npc_dialog", npc_id=41}, 
        {action="menu_dialog", menu="使用温泉消费券增加奖励时间"}, 
        {action="menu_dialog", menu="使用1张温泉消费券"}, 
        {action="menu_dialog", menu="使用1张温泉消费券"}, 
        {action="menu_dialog", menu="使用1张温泉消费券"}, 
        {action="menu", menu="离开"}, 



		--冰池热池循环跑要超过15分钟

		--从中间温池-去右边冰池
        {name="等个2秒", action="delay" , delay = 2.0},
        {action="move", mapid = 305, pos = {x = 2085, y = 765}},
        {action="click_npc_transmap", npc_id=53, tomapid=305}, 

		--在冰池晃2分多钟
        {action="move", mapid = 305, pos = {x = 3000, y = 1850}},
        {action="move", mapid = 305, pos = {x = 2580, y = 715}},
        {action="move", mapid = 305, pos = {x = 2730, y = 1910}},
        {action="move", mapid = 305, pos = {x = 3000, y = 685}},
        {action="move", mapid = 305, pos = {x = 3255, y = 1845}},
        {action="move", mapid = 305, pos = {x = 2760, y = 580}},

        {action="move", mapid = 305, pos = {x = 3000, y = 1850}},
        {action="move", mapid = 305, pos = {x = 2580, y = 715}},
        {action="move", mapid = 305, pos = {x = 2730, y = 1910}},
        {action="move", mapid = 305, pos = {x = 3000, y = 685}},
        {action="move", mapid = 305, pos = {x = 3255, y = 1845}},
        {action="move", mapid = 305, pos = {x = 2760, y = 580}},

		--从右边冰池-去中间温池
        {action="move", mapid = 305, pos = {x = 2475, y = 1085}},
        {action="click_npc_transmap", npc_id=58, tomapid=305}, 

		--从中间温池-去左边热池
        {name="等个2秒", action="delay" , delay = 2.0},
        {action="move", mapid = 305, pos = {x = 1535, y = 940}},
        {action="click_npc_transmap", npc_id=48, tomapid=305}, 

		--在热池晃2分多钟
        {action="move", mapid = 305, pos = {x = 890, y = 2085}},
        {action="move", mapid = 305, pos = {x = 890, y = 395}},
        {action="move", mapid = 305, pos = {x = 1050, y = 1950}},
        {action="move", mapid = 305, pos = {x = 650, y = 420}},
        {action="move", mapid = 305, pos = {x = 745, y = 1885}},
        {action="move", mapid = 305, pos = {x = 1065, y = 470}},

        {action="move", mapid = 305, pos = {x = 890, y = 2085}},
        {action="move", mapid = 305, pos = {x = 890, y = 395}},
        {action="move", mapid = 305, pos = {x = 1050, y = 1950}},
        {action="move", mapid = 305, pos = {x = 650, y = 420}},
        {action="move", mapid = 305, pos = {x = 745, y = 1885}},

		--从左边热池-去中间温池
        {action="move", mapid = 305, pos = {x = 1085, y = 1320}},
        {action="click_npc_transmap", npc_id=44, tomapid=305}, 

		--从中间温池-去右边冰池
        {name="等个2秒", action="delay" , delay = 2.0},
        {action="move", mapid = 305, pos = {x = 2085, y = 765}},
        {action="click_npc_transmap", npc_id=53, tomapid=305}, 

		--在冰池晃2分多钟
        {action="move", mapid = 305, pos = {x = 3000, y = 1850}},
        {action="move", mapid = 305, pos = {x = 2580, y = 715}},
        {action="move", mapid = 305, pos = {x = 2730, y = 1910}},
        {action="move", mapid = 305, pos = {x = 3000, y = 685}},
        {action="move", mapid = 305, pos = {x = 3255, y = 1845}},
        {action="move", mapid = 305, pos = {x = 2760, y = 580}},

        {action="move", mapid = 305, pos = {x = 3000, y = 1850}},
        {action="move", mapid = 305, pos = {x = 2580, y = 715}},
        {action="move", mapid = 305, pos = {x = 2730, y = 1910}},
        {action="move", mapid = 305, pos = {x = 3000, y = 685}},
        {action="move", mapid = 305, pos = {x = 3255, y = 1845}},
        {action="move", mapid = 305, pos = {x = 2760, y = 580}},

		--从右边冰池-去中间温池
        {action="move", mapid = 305, pos = {x = 2475, y = 1085}},
        {action="click_npc_transmap", npc_id=58, tomapid=305}, 

		--从中间温池-去左边热池
        {name="等个2秒", action="delay" , delay = 2.0},
        {action="move", mapid = 305, pos = {x = 1535, y = 940}},
        {action="click_npc_transmap", npc_id=48, tomapid=305}, 

		--在热池晃2分多钟
        {action="move", mapid = 305, pos = {x = 890, y = 2085}},
        {action="move", mapid = 305, pos = {x = 890, y = 395}},
        {action="move", mapid = 305, pos = {x = 1050, y = 1950}},
        {action="move", mapid = 305, pos = {x = 650, y = 420}},
        {action="move", mapid = 305, pos = {x = 745, y = 1885}},
        {action="move", mapid = 305, pos = {x = 1065, y = 470}},

        {action="move", mapid = 305, pos = {x = 890, y = 2085}},
        {action="move", mapid = 305, pos = {x = 890, y = 395}},
        {action="move", mapid = 305, pos = {x = 1050, y = 1950}},
        {action="move", mapid = 305, pos = {x = 650, y = 420}},
        {action="move", mapid = 305, pos = {x = 745, y = 1885}},

		--从左边热池-去中间温池	
        {action="move", mapid = 305, pos = {x = 1085, y = 1320}},
        {action="click_npc_transmap", npc_id=44, tomapid=305}, 

		--从中间温池-去右边冰池
        {name="等个2秒", action="delay" , delay = 2.0},
        {action="move", mapid = 305, pos = {x = 2085, y = 765}},
        {action="click_npc_transmap", npc_id=53, tomapid=305}, 

		--在冰池晃2分多钟
        {action="move", mapid = 305, pos = {x = 3000, y = 1850}},
        {action="move", mapid = 305, pos = {x = 2580, y = 715}},
        {action="move", mapid = 305, pos = {x = 2730, y = 1910}},
        {action="move", mapid = 305, pos = {x = 3000, y = 685}},
        {action="move", mapid = 305, pos = {x = 3255, y = 1845}},
        {action="move", mapid = 305, pos = {x = 2760, y = 580}},

        {action="move", mapid = 305, pos = {x = 3000, y = 1850}},
        {action="move", mapid = 305, pos = {x = 2580, y = 715}},
        {action="move", mapid = 305, pos = {x = 2730, y = 1910}},
        {action="move", mapid = 305, pos = {x = 3000, y = 685}},
        {action="move", mapid = 305, pos = {x = 3255, y = 1845}},
        {action="move", mapid = 305, pos = {x = 2760, y = 580}},

		--从右边冰池-去中间温池
        {action="move", mapid = 305, pos = {x = 2475, y = 1085}},
        {action="click_npc_transmap", npc_id=58, tomapid=305}, 

		--从中间温池-去左边热池
        {name="等个2秒", action="delay" , delay = 2.0},
        {action="move", mapid = 305, pos = {x = 1535, y = 940}},
        {action="click_npc_transmap", npc_id=48, tomapid=305}, 

		--在热池晃2分多钟
        {action="move", mapid = 305, pos = {x = 890, y = 2085}},
        {action="move", mapid = 305, pos = {x = 890, y = 395}},
        {action="move", mapid = 305, pos = {x = 1050, y = 1950}},
        {action="move", mapid = 305, pos = {x = 650, y = 420}},
        {action="move", mapid = 305, pos = {x = 745, y = 1885}},
        {action="move", mapid = 305, pos = {x = 1065, y = 470}},

        {action="move", mapid = 305, pos = {x = 890, y = 2085}},
        {action="move", mapid = 305, pos = {x = 890, y = 395}},
        {action="move", mapid = 305, pos = {x = 1050, y = 1950}},
        {action="move", mapid = 305, pos = {x = 650, y = 420}},
        {action="move", mapid = 305, pos = {x = 745, y = 1885}},

		--从左边热池-去中间温池	
        {action="move", mapid = 305, pos = {x = 1085, y = 1320}},
        {action="click_npc_transmap", npc_id=44, tomapid=305}, 

		--从中间温池-去右边冰池
        {name="等个2秒", action="delay" , delay = 2.0},
        {action="move", mapid = 305, pos = {x = 2085, y = 765}},
        {action="click_npc_transmap", npc_id=53, tomapid=305}, 

		--在冰池晃2分多钟
        {action="move", mapid = 305, pos = {x = 3000, y = 1850}},
        {action="move", mapid = 305, pos = {x = 2580, y = 715}},
        {action="move", mapid = 305, pos = {x = 2730, y = 1910}},
        {action="move", mapid = 305, pos = {x = 3000, y = 685}},
        {action="move", mapid = 305, pos = {x = 3255, y = 1845}},
        {action="move", mapid = 305, pos = {x = 2760, y = 580}},

        {action="move", mapid = 305, pos = {x = 3000, y = 1850}},
        {action="move", mapid = 305, pos = {x = 2580, y = 715}},
        {action="move", mapid = 305, pos = {x = 2730, y = 1910}},
        {action="move", mapid = 305, pos = {x = 3000, y = 685}},
        {action="move", mapid = 305, pos = {x = 3255, y = 1845}},
        {action="move", mapid = 305, pos = {x = 2760, y = 580}},

		--从右边冰池-去中间温池
        {action="move", mapid = 305, pos = {x = 2475, y = 1085}},
        {action="click_npc_transmap", npc_id=58, tomapid=305}, 



		--冰池热池循环跑要超过15分钟-2

		--从中间温池-去左边热池
        {name="等个2秒", action="delay" , delay = 2.0},
        {action="move", mapid = 305, pos = {x = 1535, y = 940}},
        {action="click_npc_transmap", npc_id=48, tomapid=305}, 

		--在热池晃2分多钟
        {action="move", mapid = 305, pos = {x = 890, y = 2085}},
        {action="move", mapid = 305, pos = {x = 890, y = 395}},
        {action="move", mapid = 305, pos = {x = 1050, y = 1950}},
        {action="move", mapid = 305, pos = {x = 650, y = 420}},
        {action="move", mapid = 305, pos = {x = 745, y = 1885}},
        {action="move", mapid = 305, pos = {x = 1065, y = 470}},

        {action="move", mapid = 305, pos = {x = 890, y = 2085}},
        {action="move", mapid = 305, pos = {x = 890, y = 395}},
        {action="move", mapid = 305, pos = {x = 1050, y = 1950}},
        {action="move", mapid = 305, pos = {x = 650, y = 420}},
        {action="move", mapid = 305, pos = {x = 745, y = 1885}},

		--从左边热池-去中间温池
        {action="move", mapid = 305, pos = {x = 1085, y = 1320}},
        {action="click_npc_transmap", npc_id=44, tomapid=305}, 

		--从中间温池-去右边冰池
        {name="等个2秒", action="delay" , delay = 2.0},
        {action="move", mapid = 305, pos = {x = 2085, y = 765}},
        {action="click_npc_transmap", npc_id=53, tomapid=305}, 

		--在冰池晃2分多钟
        {action="move", mapid = 305, pos = {x = 3000, y = 1850}},
        {action="move", mapid = 305, pos = {x = 2580, y = 715}},
        {action="move", mapid = 305, pos = {x = 2730, y = 1910}},
        {action="move", mapid = 305, pos = {x = 3000, y = 685}},
        {action="move", mapid = 305, pos = {x = 3255, y = 1845}},
        {action="move", mapid = 305, pos = {x = 2760, y = 580}},

        {action="move", mapid = 305, pos = {x = 3000, y = 1850}},
        {action="move", mapid = 305, pos = {x = 2580, y = 715}},
        {action="move", mapid = 305, pos = {x = 2730, y = 1910}},
        {action="move", mapid = 305, pos = {x = 3000, y = 685}},
        {action="move", mapid = 305, pos = {x = 3255, y = 1845}},
        {action="move", mapid = 305, pos = {x = 2760, y = 580}},

		--从右边冰池-去中间温池
        {action="move", mapid = 305, pos = {x = 2475, y = 1085}},
        {action="click_npc_transmap", npc_id=58, tomapid=305}, 

		--从中间温池-去左边热池
        {name="等个2秒", action="delay" , delay = 2.0},
        {action="move", mapid = 305, pos = {x = 1535, y = 940}},
        {action="click_npc_transmap", npc_id=48, tomapid=305}, 

		--在热池晃2分多钟
        {action="move", mapid = 305, pos = {x = 890, y = 2085}},
        {action="move", mapid = 305, pos = {x = 890, y = 395}},
        {action="move", mapid = 305, pos = {x = 1050, y = 1950}},
        {action="move", mapid = 305, pos = {x = 650, y = 420}},
        {action="move", mapid = 305, pos = {x = 745, y = 1885}},
        {action="move", mapid = 305, pos = {x = 1065, y = 470}},

        {action="move", mapid = 305, pos = {x = 890, y = 2085}},
        {action="move", mapid = 305, pos = {x = 890, y = 395}},
        {action="move", mapid = 305, pos = {x = 1050, y = 1950}},
        {action="move", mapid = 305, pos = {x = 650, y = 420}},
        {action="move", mapid = 305, pos = {x = 745, y = 1885}},

		--从左边热池-去中间温池	
        {action="move", mapid = 305, pos = {x = 1085, y = 1320}},
        {action="click_npc_transmap", npc_id=44, tomapid=305}, 

		--从中间温池-去右边冰池
        {name="等个2秒", action="delay" , delay = 2.0},
        {action="move", mapid = 305, pos = {x = 2085, y = 765}},
        {action="click_npc_transmap", npc_id=53, tomapid=305}, 

		--在冰池晃2分多钟
        {action="move", mapid = 305, pos = {x = 3000, y = 1850}},
        {action="move", mapid = 305, pos = {x = 2580, y = 715}},
        {action="move", mapid = 305, pos = {x = 2730, y = 1910}},
        {action="move", mapid = 305, pos = {x = 3000, y = 685}},
        {action="move", mapid = 305, pos = {x = 3255, y = 1845}},
        {action="move", mapid = 305, pos = {x = 2760, y = 580}},

        {action="move", mapid = 305, pos = {x = 3000, y = 1850}},
        {action="move", mapid = 305, pos = {x = 2580, y = 715}},
        {action="move", mapid = 305, pos = {x = 2730, y = 1910}},
        {action="move", mapid = 305, pos = {x = 3000, y = 685}},
        {action="move", mapid = 305, pos = {x = 3255, y = 1845}},
        {action="move", mapid = 305, pos = {x = 2760, y = 580}},

		--从右边冰池-去中间温池
        {action="move", mapid = 305, pos = {x = 2475, y = 1085}},
        {action="click_npc_transmap", npc_id=58, tomapid=305}, 

		--从中间温池-去左边热池
        {name="等个2秒", action="delay" , delay = 2.0},
        {action="move", mapid = 305, pos = {x = 1535, y = 940}},
        {action="click_npc_transmap", npc_id=48, tomapid=305}, 

		--在热池晃2分多钟
        {action="move", mapid = 305, pos = {x = 890, y = 2085}},
        {action="move", mapid = 305, pos = {x = 890, y = 395}},
        {action="move", mapid = 305, pos = {x = 1050, y = 1950}},
        {action="move", mapid = 305, pos = {x = 650, y = 420}},
        {action="move", mapid = 305, pos = {x = 745, y = 1885}},
        {action="move", mapid = 305, pos = {x = 1065, y = 470}},

        {action="move", mapid = 305, pos = {x = 890, y = 2085}},
        {action="move", mapid = 305, pos = {x = 890, y = 395}},
        {action="move", mapid = 305, pos = {x = 1050, y = 1950}},
        {action="move", mapid = 305, pos = {x = 650, y = 420}},
        {action="move", mapid = 305, pos = {x = 745, y = 1885}},

		--从左边热池-去中间温池	
        {action="move", mapid = 305, pos = {x = 1085, y = 1320}},
        {action="click_npc_transmap", npc_id=44, tomapid=305}, 

		--从中间温池-去右边冰池
        {name="等个2秒", action="delay" , delay = 2.0},
        {action="move", mapid = 305, pos = {x = 2085, y = 765}},
        {action="click_npc_transmap", npc_id=53, tomapid=305}, 

		--在冰池晃2分多钟
        {action="move", mapid = 305, pos = {x = 3000, y = 1850}},
        {action="move", mapid = 305, pos = {x = 2580, y = 715}},
        {action="move", mapid = 305, pos = {x = 2730, y = 1910}},
        {action="move", mapid = 305, pos = {x = 3000, y = 685}},
        {action="move", mapid = 305, pos = {x = 3255, y = 1845}},
        {action="move", mapid = 305, pos = {x = 2760, y = 580}},

        {action="move", mapid = 305, pos = {x = 3000, y = 1850}},
        {action="move", mapid = 305, pos = {x = 2580, y = 715}},
        {action="move", mapid = 305, pos = {x = 2730, y = 1910}},
        {action="move", mapid = 305, pos = {x = 3000, y = 685}},
        {action="move", mapid = 305, pos = {x = 3255, y = 1845}},
        {action="move", mapid = 305, pos = {x = 2760, y = 580}},

		--从右边冰池-去中间温池
        {action="move", mapid = 305, pos = {x = 2475, y = 1085}},
        {action="click_npc_transmap", npc_id=58, tomapid=305}, 

		--从中间温池-去左边热池
        {name="等个2秒", action="delay" , delay = 2.0},
        {action="move", mapid = 305, pos = {x = 1535, y = 940}},
        {action="click_npc_transmap", npc_id=48, tomapid=305}, 

		--在热池晃2分多钟
        {action="move", mapid = 305, pos = {x = 890, y = 2085}},
        {action="move", mapid = 305, pos = {x = 890, y = 395}},
        {action="move", mapid = 305, pos = {x = 1050, y = 1950}},
        {action="move", mapid = 305, pos = {x = 650, y = 420}},
        {action="move", mapid = 305, pos = {x = 745, y = 1885}},
        {action="move", mapid = 305, pos = {x = 1065, y = 470}},

        {action="move", mapid = 305, pos = {x = 890, y = 2085}},
        {action="move", mapid = 305, pos = {x = 890, y = 395}},
        {action="move", mapid = 305, pos = {x = 1050, y = 1950}},
        {action="move", mapid = 305, pos = {x = 650, y = 420}},
        {action="move", mapid = 305, pos = {x = 745, y = 1885}},

		--从左边热池-去中间温池
        {action="move", mapid = 305, pos = {x = 1085, y = 1320}},
        {action="click_npc_transmap", npc_id=44, tomapid=305}, 



		--领取满15分钟泡温泉经验奖励
        {name="等个2秒", action="delay" , delay = 2.0},
        {action="move", mapid = 305, pos = {x = 1580, y = 295}},
        {action="click_npc_dialog", npc_id=41}, 
        {action="menu", menu="领取满15分钟泡温泉经验奖励"}, 



		--领取满30分钟泡温泉经验奖励
        {name="等个2秒", action="delay" , delay = 2.0},
        {action="move", mapid = 305, pos = {x = 1580, y = 295}},
        {action="click_npc_dialog", npc_id=41}, 
        {action="menu", menu="领取满30分钟泡温泉经验奖励"}, 



		--离开温泉
        {name="等个2秒", action="delay" , delay = 2.0},
        {action="move", mapid = 305, pos = {x = 1580, y = 295}},
        {action="click_npc_dialog", npc_id=41}, 
        {action="menu", menu="泡好了，我想出去"}, 

    },

    endsteps = {

    },
}

return act1_data 
--endregion
