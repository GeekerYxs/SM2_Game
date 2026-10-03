--region *.lua
--Date
--此文件由[BabeLua]插件自动生成

--自动处理任务
local gamestate = require("game_state")
local events = require("events")
local TaskExecutor = require("task_executor")

local taskExecutor = nil

local curTaskIdx = 0
local curTaskID = 0

local gotoNextTask = nil

local state = 0

local autoStartTime = 0

local function completeTask()
    Debug("completeTask("..tostring(curTaskIdx)..")")
    taskExecutor = nil
    game:SetAutoTaskItemStatusImage(curTaskID,0)
    curTaskID = 0
    curTaskIdx = curTaskIdx+1
    gotoNextTask()
end

gotoNextTask  = function()
    local cheat = game:GetCheatScript()
    while true do
        local taskCfg = cheat:GetTaskByIdx(curTaskIdx)
        if taskCfg==nil then
            break
        end
        if taskCfg.Checked~=0 then
            local task = require("task"..tostring(taskCfg.ID))
            if taskExecutor ~= nil then
                taskExecutor:Cancel()
                taskExecutor = nil
            end
            curTaskID = taskCfg.ID
            game:SetAutoTaskItemStatusImage(curTaskID,1)
            taskExecutor = TaskExecutor:New(task, completeTask)
            taskExecutor:Start()
            return
        else
            curTaskIdx = curTaskIdx+1
        end
    end
    state = -1   --结束自动任务
end

local function startAutoTask()
    Debug("startAutoTask")
    game:CheckInstanceLoaded()
    autoStartTime = os.clock()
    state = 1
    game:SetAutoTaskButtonVisibleStatus(1)
    curTaskIdx = 0
    gotoNextTask()
end

local function pauseAutoTask()
    Debug("pauseAutoTask")
    state = 2
    game:SetAutoTaskButtonVisibleStatus(2)
    if curTaskID~=0 then
        game:SetAutoTaskItemStatusImage(curTaskID,2)
    end
    if taskExecutor~=nil then
        taskExecutor:Pause()
    end
end

local function continueAutoTask()
    Debug("continueAutoTask")
    state = 1
    game:SetAutoTaskButtonVisibleStatus(1)
    if curTaskID~=0 then
        game:SetAutoTaskItemStatusImage(curTaskID,1)
    end
    if taskExecutor~=nil then
        taskExecutor:Continue()
    end
end

local function gameUpdate()
    if(not gamestate.isLogin)then
        return
    end
    if(not gamestate.isCheatConfigLoaded)then
        return
    end
    if os.clock()-autoStartTime<1 then
        return
    end
    if state==1 then
        if (taskExecutor ~= nil) then
            taskExecutor:Update()
        end
    end
end

local function ResetAutoTask()
    Debug("ResetAutoTask")
    state = 0
    if curTaskID~=0 then
        game:SetAutoTaskItemStatusImage(curTaskID,0)
        curTaskID = 0
    end
    if taskExecutor~=nil then
        taskExecutor:Cancel()
        taskExecutor = nil
    end
    curTaskIdx = 0
    game:SetAutoTaskButtonVisibleStatus(0)
end

local function onButtonClick(wndname, btnId)
    if btnId==306 then
        if state==0 then
            startAutoTask()
        elseif state==1 then
            pauseAutoTask()
        elseif state==2 then
            continueAutoTask()
        end
    elseif btnId==307 then
        ResetAutoTask()
    end
end

events.GameUpdate:Add(gameUpdate)
events.ButtonClicked:Add(onButtonClick)

--endregion