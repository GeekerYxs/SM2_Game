local model = {}

local MoveAction = require("move_action")
local MoveTransMapAction = require("move_transmap_action")
local ClickNpcDialogAction = require("click_npc_dialog_action")
local MenuDialogAction = require("menu_dialog_action")
local MenuTransMapAction = require("menu_transmap_action")
local CloseDialogAction = require("close_dialog_action")
local CompleteTaskAction = require("complete_task_action")
local MenuFightAction = require("menu_fight_action")
local MenuFightOptionAction = require("menu_fight_option_action")
local MenuAction = require("menu_action")
local MenuDialogOptionAction = require("menu_dialog_option_action")
local ClickNpcTransmapAction = require("click_npc_transmap_action")
local GotoAction = require("goto_action")
local DelayAction = require("delay_action")
local ClickNpcsFightAction = require("click_npcs_fight_action")
local MoveTransAction = require("move_trans_action")
local CheckInstancePosAction = require("check_instancepos_action")
local CheckContentAction = require("check_content_action")
local CheckMenuAction = require("check_menu_action")

local function CreateAction(act)
    local obj = nil
    if act.action == "move" then
        obj = MoveAction:New(act.mapid,act.pos)
    elseif act.action=="move_transmap" then
        obj = MoveTransMapAction:New(act.mapid,act.pos,act.tomapid)
    elseif act.action=="click_npc_dialog" then
        obj = ClickNpcDialogAction:New(act.npc_id)
    elseif act.action=="menu_dialog" then
        obj = MenuDialogAction:New(act.menu)
    elseif act.action=="menu_transmap" then
        obj = MenuTransMapAction:New(act.menu,act.tomapid)
    elseif act.action=="close_dialog" then
        obj = CloseDialogAction:New()
    elseif act.action=="complete_task" then
        obj = CompleteTaskAction:New(act.complete)
    elseif act.action=="menu_fight" then
        obj = MenuFightAction:New(act.menu)
    elseif act.action=="menu_fight?" then
        obj = MenuFightOptionAction:New(act.menu, act.next)
    elseif act.action=="menu" then
        obj = MenuAction:New(act.menu)
    elseif act.action=="menu_dialog?" then
        obj = MenuDialogOptionAction:New(act.menu, act.next)
    elseif act.action=="click_npc_transmap" then
        obj = ClickNpcTransmapAction:New(act.npc_id,act.tomapid)
    elseif act.action=="goto" then
        obj = GotoAction:New(act.next)
    elseif act.action=="check_content" then
        obj = CheckContentAction:New(act.content,act.next)
    elseif act.action=="check_menu" then
        obj = CheckMenuAction:New(act.menu, act.next)
    elseif act.action=="delay" then
        obj = DelayAction:New(act.delay)
    elseif act.action=="check_instancepos" then
        obj = CheckInstancePosAction:New(act.taskid,act.posx,act.posy)
    elseif act.action=="click_npcs_fight" then
        obj = ClickNpcsFightAction:New(act.npcs)
    elseif act.action=="move_trans" then
        obj = MoveTransAction:New(act.pos,act.topos)
    end

    if obj ~= nil then
        obj.Name = act.name or act.action
    else
        Error("can't create action "..act.action)
    end
    return obj
end

model.CreateAction = CreateAction

return model