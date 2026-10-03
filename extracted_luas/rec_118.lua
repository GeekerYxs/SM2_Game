local events = require("events")
local states = {isLogin = false,isCheatConfigLoaded=false, isInFight = false}

local function OnGameLogin()
    states.isLogin = true
end
events.GameLogin:Add(OnGameLogin)

local function OnGameLogout()
    states.isLogin = false
end
events.GameLogout:Add(OnGameLogout)

local function OnCheatConfigLoaded()
    states.isCheatConfigLoaded = true
end
events.CheatConfigLoaded:Add(OnCheatConfigLoaded)

local function OnReload()
    states.isLogin = true
    states.isCheatConfigLoaded  = true
end
events.LuaReload:Add(OnReload)

local function enterFight()
    states.isInFight = true
end
events.EnterFight:Add(enterFight)

local function leaveFight()
    states.isInFight = false
end
events.LeaveFight:Add(leaveFight)

return states