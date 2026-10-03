--region *.lua
--Date
--此文件由[BabeLua]插件自动生成

-- 每日-龙之都大练兵(单人-60级以上)

-- 

-- task_state: 0 = 未接受, 1 = 向目标进发点NPC传送, 2 = 任务进行中处理NPC选项 , 3 = 行进中穿过传送点, 4 = 找NPC提交任务 (提交后删除就没有任务了)
-- 行动数据定义
local act1_data = {

    presteps = {

        --传送到集训营
        {name="移动到集训营军官", action="move", mapid = 20, pos = {x = 2358, y = 1377}},
        {name="点击集训营军官", action="click_npc_dialog", npc_id=693 }, 
        {name="选择传送选项", action="menu_transmap", menu="进入禁卫军魔鬼集训营（60级以上）", tomapid=30},

    },

    steps = {

        --找集训官
        {name="移动到集训官",action="move", mapid = 30, pos = {x = 3544, y = 1988}},
        {name="点击集训官",action="click_npc_dialog", npc_id=730}, 
        {name="选择龙之都大练兵",action="menu_dialog", menu="龙之都大练兵"}, 



		--【接受任务】【menu_dialog? 表示可能会没有这个选项】【有？有check，后面都要加next=】【检测下一步是否有对话框，有的话往下走，没有的话走next的内容】
        {name="点击接受任务",action="menu_dialog?", menu="接受培训", next="从集训官那进入训练营"}, 
		--【从内容检测是否可以完成任务，超过今日挑战上限，就会结束此任务循环，回去龙之都外城】【有？有check，后面都要加next=】【检测是否有content的内容，有的话往下走，没有的话走next的内容】
        {name="从内容检测是否可以完成任务",action="check_content", content="明天在来吧", next="从集训官那进入训练营"}, 



        --结束任务
        {name="关闭对话框，准备结束任务",action="close_dialog"}, 
        {name="结束任务", action="complete_task",complete=false},



		--进入训练营
        {name="从集训官那进入训练营",action="move", mapid = 30, pos = {x = 3544, y = 1988}},
        {name="点击集训官2", action="click_npc_dialog", npc_id=730}, 
        {name="选择进入训练营", action="menu_dialog", menu="进入训练营"}, 
        {name="选择进入", action="menu_transmap", menu="进入", tomapid=30},



		--B1
        {name="移动到B1", action="move", mapid = 30, pos = {x = 900, y = 1275}},
        {name="B1战斗", action="click_npcs_fight", npcs={1360,1361,1382}}, 

		--B2
        {name="移动到B2", action="move", mapid = 30, pos = {x = 2200, y = 685}},
        {name="B2战斗", action="click_npcs_fight", npcs={1364,1365,1383}}, 

		--C1
        {name="移动到C1", action="move", mapid = 30, pos = {x = 890, y = 1970}},
        {name="C1战斗", action="click_npcs_fight", npcs={1357,1358,1359}}, 

		--C2
        {name="移动到C2", action="move", mapid = 30, pos = {x = 3540, y = 695}},
        {name="C2战斗", action="click_npcs_fight", npcs={1366,1367,1368}}, 

		--A1
        {name="移动到A1", action="move", mapid = 30, pos = {x = 810, y = 500}},
        {name="A1战斗", action="click_npcs_fight", npcs={1378,1379,1380}}, 



		--离开训练营
        {name="离开训练营", action="move_trans", pos = {x = 3140, y = 1865}, topos = {x = 3480, y = 2060}},
        {name="等个2秒", action="delay" , delay = 2.0},



        --找集训官2
        {name="移动到集训官2",action="move", mapid = 30, pos = {x = 3544, y = 1988}},
        {name="点击集训官2",action="click_npc_dialog", npc_id=730}, 
        {name="选择龙之都大练兵2",action="menu_dialog", menu="龙之都大练兵"}, 
        {name="选择完成培训",action="menu_dialog", menu="完成培训"}, 



        --继续任务
        {name="关闭对话框，准备结束任务2", action="close_dialog"}, 
        {name="继续任务", action="complete_task",complete=true},

    },

    endsteps = {

		--传送到龙之都交叉口
        {name="移动到龙之都交叉口", action="move_transmap", mapid = 30, pos = {x = 4030, y = 2325},tomapid=25},

		--传送到龙之都外城
        {name="移动到龙之都外城", action="move_transmap", mapid = 25, pos = {x = 3115, y = 1635},tomapid=20},

    },
}

return act1_data 
--endregion
