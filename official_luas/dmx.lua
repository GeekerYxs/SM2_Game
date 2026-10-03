package.path = package.path .. ";./luas/?.lua;./luas/task/?.lua;./luas/action/?.lua;./luas/fight/?.lua;./luas/script/?.lua;./luas/ui/?.lua;./luas/ui/struct/?.lua;./luas/ui/dlgs/?.lua"

require("TimeFunction")
require("FunctionEx")
require("MathFunction")

require("game_define")

require("log")
require("cheat_script_config")
require("events")
require("game_state")

require("auto_drop")
require("auto_fill")
require("auto_sell")
require("auto_gather")
require("team_tool")

require("auto_task")

require("auto_fight")

require("TriggerItem")
require("SpecialRecordPet")

require("uimgr")

require("script1")
require("script101")

local tool = require("id_parse_tool")

function GameStart()
    Info("lua start!!!")
    tool.LoadAll()
end
