-- 手动实现trim函数（Lua 5.1不直接支持string方法扩展）
local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- 解析CSV文件内容
-- @param content: CSV文件内容的字符串
-- @return: 解析后的二维表数据，如果内容为空或nil则返回空表
local function readCSV(content)
    -- 处理nil或空字符串
    if not content or content == "" then
        return {}
    end
    
    local data = {}
    local currentRow = {}
    local currentField = ""
    local inQuotes = false

    for line in content:gmatch("[^\r\n]+") do 
        --Info(line)
        if not line:match("^%s*//") and not line:match("^%s*$") and not line:match("^%s*#") then
            local i = 1
            while i <= #line do
                local char = line:sub(i, i)

                if char == '"' then
                    if inQuotes and i + 1 <= #line and line:sub(i+1, i+1) == '"' then -- 转义的双引号
                        currentField = currentField .. '"'
                        i = i + 1 -- 跳过下一个引号
                    else
                        inQuotes = not inQuotes
                    end
                elseif char == ',' and not inQuotes then
                    table.insert(currentRow, trim(currentField))
                    currentField = ""
                else
                    currentField = currentField .. char
                end

                i = i + 1
            end

            -- 如果仍在引号内，说明字段继续到下一行
            if inQuotes then
                currentField = currentField .. "\n" -- 在引号字段内保留换行符
            else
                table.insert(currentRow, trim(currentField))
                table.insert(data, currentRow)
                currentRow = {}
                currentField = ""
            end
        end
    end

    -- 处理最后一行没有换行符的情况
    if #currentRow > 0 or currentField ~= "" then
        table.insert(currentRow, trim(currentField))
        table.insert(data, currentRow)
    end

    return data
end

local allDatas = {}

local function readSkillLibCSV()
    local filedata = game:ReadFileData("ResLib/SkillLib.csv")
    if filedata == nil then
        Error("读取ResLib/SkillLib.csv文件失败")
        return false
    end
    local data = readCSV(filedata)
    local items = {}
    for _, row in ipairs(data) do
        local item = {
            SkillId = tonumber(row[1]), -- 技能ID
            SkillLevel = tonumber(row[2]), -- 技能等级
            Name = row[15], -- 技能名称
            Icon = row[16], -- 技能图标(SetImage "UIGame/Icon/"..Icon..".mgff")
            Desc = row[17], -- 技能描述
        }
        if items[item.SkillId] == nil then
            items[item.SkillId] = {}
        end
        items[item.SkillId][item.SkillLevel] = item
    end
    allDatas['SkillLib'] = items
    return true
end

local function findSkill(skillId, skillLevel)
    local items = allDatas['SkillLib'] -- 获取技能库数据
    if items == nil then
        return nil -- 数据不存在
    end
    if items[skillId] == nil then
        return nil -- 技能ID不存在
    end
    return items[skillId][skillLevel] -- 返回指定技能ID和等级的信息
end

local function readGodhoodLevelLibCSV()
    local filedata = game:ReadFileData("ResLib\\GodhoodLevelLib.csv")
    if filedata == nil then
        Error("读取ResLib\\GodhoodLevelLib.csv文件失败")
        return false
    end
    local data = readCSV(filedata)
    local items = {} -- 存储神格等级数据
    for _, row in ipairs(data) do
        local item = {
            level = tonumber(row[1]), -- 等级
            name = row[2], -- 名称
        }
        items[item.level] = item
    end
    allDatas['GodhoodLevel'] = items
    return true
end
local function findGodhoodLevel(level)
    local items = allDatas['GodhoodLevel'] -- 获取神格等级数据
    if items == nil then
        return nil -- 数据不存在
    end
    return items[level] -- 返回指定等级的神格信息
end

-- 读取宠物模板库(PetLib.csv)——取「宠物种族ID → 圣痕ID / 神火技能库ID」映射，供神侍界面按种族查
-- (服务端只下发 pet_species)。列序与客户端 C++ IDParseTool 解析一致：
--   row[1]=宠物ID(种族) … row[12]=神侍等级 row[13]=稀有度 row[14]=神火技能库ID
--   row[15]=圣痕ID(对应 TSHolyMarkAuraLib.AuraID，0=无光环)。表头以 // 开头，readCSV 会跳过。
local function readPetLibCSV()
    local filedata = game:ReadFileData("ResLib\\PetLib.csv")
    if filedata == nil then
        Error("读取ResLib\\PetLib.csv文件失败")
        return false
    end
    local data = readCSV(filedata)
    local items = {} -- species(宠物ID) -> { holyMarkId, godFireLibId, godServantRank }
    for _, row in ipairs(data) do
        local species = tonumber(row[1]) -- 宠物ID(种族)
        if species ~= nil then
            items[species] = {
                holyMarkId     = tonumber(row[15]) or 0, -- 圣痕ID(圣痕光环组ID，0=无光环)
                godFireLibId   = tonumber(row[14]) or 0, -- 神火技能库ID(0=无神火)
                godServantRank = tonumber(row[12]) or 0, -- 神侍等级(= 服务端 TPetLib.GodServantRank，种族固定，不随祈愿成长)
            }
        end
    end
    allDatas['PetLib'] = items
    return true
end

-- 按宠物种族ID取圣痕(光环组)ID；无数据/无光环返回 0
-- @param species: 宠物种族ID(服务端下发的 pet_species)
local function findPetHolyMarkID(species)
    local items = allDatas['PetLib']
    if items == nil or species == nil or items[species] == nil then
        return 0
    end
    return items[species].holyMarkId or 0
end

-- 按宠物种族ID取神火技能库ID；无数据/无神火返回 0（神侍界面判「可否祈愿/有无神火库」用）
local function findPetGodFireLibID(species)
    local items = allDatas['PetLib']
    if items == nil or species == nil or items[species] == nil then
        return 0
    end
    return items[species].godFireLibId or 0
end

-- 按宠物种族ID取神侍等级(= TPetLib.GodServantRank，种族固定，不随祈愿成长)；无数据返回 0
-- 服务端不再下发神侍等级，界面一切按等级查 CSV 的键都由此现算。
local function findPetGodServantRank(species)
    local items = allDatas['PetLib']
    if items == nil or species == nil or items[species] == nil then
        return 0
    end
    return items[species].godServantRank or 0
end

-- 读取神侍等级库(GodServantLevelLib.csv)——神侍等级 → 阶/星/名/归元消耗系数/展示颜色
-- 列: row[1]=神侍等级 row[2]=阶段 row[3]=星 row[4]=名称 row[5]=icon名(头像框) row[6]=归元消耗系数
--     row[7]=展示颜色(名称显示色，十进制 RGB565，label 用 #NNNNN；0=不着色沿用控件底色)
-- 表头(神侍等级,阶段,...)无 // 前缀，会被当作数据行，gsLevel 解析为 nil 时跳过。
-- ⚠ 与 GodhoodLevel(神格)不是一回事：这是神侍(GodServant)等级。
local function readGodServantLevelLibCSV()
    local filedata = game:ReadFileData("ResLib\\GodServantLevelLib.csv")
    if filedata == nil then
        Error("读取ResLib\\GodServantLevelLib.csv文件失败")
        return false
    end
    local data = readCSV(filedata)
    local items = {} -- gsLevel -> {phase, star, name, iconFrame, coefficient}
    for _, row in ipairs(data) do
        local gsLevel = tonumber(row[1]) -- 神侍等级
        if gsLevel ~= nil then
            items[gsLevel] = {
                phase       = tonumber(row[2]) or 0, -- 阶段
                star        = tonumber(row[3]) or 0, -- 星
                name        = row[4],                -- 名称(GBK字节,直接显示)
                iconFrame   = row[5],                -- icon名(头像框)
                coefficient = tonumber(row[6]) or 0, -- 归元消耗系数(=服务端 MaterialCoefficient)
                nameColor   = tonumber(row[7]) or 0, -- 展示颜色(十进制RGB565,#NNNNN;0=不着色)
            }
        end
    end
    allDatas['GodServantLevel'] = items
    return true
end

-- 按神侍等级取配置行(阶/星/名/系数)；无则 nil
local function findGodServantLevel(gsLevel)
    local items = allDatas['GodServantLevel']
    if items == nil or gsLevel == nil then
        return nil
    end
    return items[gsLevel]
end

-- 按品阶(段位)取该段位「第一个神侍」的名称（=该 phase 内最小 gsLevel、即 star 0 那行的 Name）；无则 nil。
-- 神火技能格解锁：第 i 格需神侍品阶达到 i，故用此取"需要神侍位阶达到 xxxx"里的 xxxx。
-- name 是 GBK 字节(直接显示，勿再过 L)。
local function findGodServantNameByPhase(phase)
    local items = allDatas['GodServantLevel']
    if items == nil or phase == nil then
        return nil
    end
    local bestLevel, bestName = nil, nil
    for gsLevel, info in pairs(items) do
        if info.phase == phase and (bestLevel == nil or gsLevel < bestLevel) then
            bestLevel, bestName = gsLevel, info.name
        end
    end
    return bestName
end

-- 读取神侍归元基础消耗(GodServantResetCostLib.csv)——单行全局配置
-- 列: row[1]=基础金币 row[2]=基础神识 row[3..8]=材料1~3 的(物品ID,基础数量)
-- 服务器对应表 TSGodServantResetCostLib（唯一权威，本 csv 是它的镜像，改值两边都要改）：
--   服务端 Lua 走 game:GetGodServantResetCost() 扣减，C++ 剥离/提取按 75% 退材料，本表只供
--   界面「显示 + 本地买得起判定」。归元实际消耗 = 各基础量 × 归元消耗系数(当前神侍等级)。
-- 只取第一条数据行；文件缺失/无数据行时退化为全 0（界面显示 0 消耗，不阻塞点归元，由服务端拒）。
local function readGodServantResetCostCSV()
    local base = { money = 0, godexp = 0, materials = {} }
    allDatas['GodServantResetCost'] = base
    local filedata = game:ReadFileData("ResLib\\GodServantResetCostLib.csv")
    if filedata == nil then
        Error("读取ResLib\\GodServantResetCostLib.csv文件失败")
        return false
    end
    local data = readCSV(filedata)
    for _, row in ipairs(data) do
        local money = tonumber(row[1]) -- 基础金币；表头行解析为 nil 时跳过
        if money ~= nil then
            base.money  = money
            base.godexp = tonumber(row[2]) or 0
            -- 材料格：itemId/数量任一 ≤0 视为该格不用；结果是密集数组（与服务端下发形状一致，
            -- 界面按 1..N 顺序占格，中间空格不会留空洞）
            for i = 1, 3 do
                local itemId    = tonumber(row[1 + i * 2]) or 0
                local baseCount = tonumber(row[2 + i * 2]) or 0
                if itemId > 0 and baseCount > 0 then
                    table.insert(base.materials, { itemId, baseCount })
                end
            end
            break
        end
    end
    return true
end

-- 取神侍归元基础消耗 { money=, godexp=, materials={ {itemId, baseCount}, ... } }；恒不为 nil
local function getGodServantResetBase()
    return allDatas['GodServantResetCost'] or { money = 0, godexp = 0, materials = {} }
end

-- 读取圣痕光环库(HolyMarkAuraLib.csv)
-- 列(2026 更新，6 列): 圣痕ID(光环组) | 圣痕等级(字符串,仅界面显示,不参与逻辑) | 圣痕图标 |
--                     对应神侍等级(=达到该神侍等级激活本行,逻辑用) | 技能ID | 技能等级
-- 服务器对应表 TSHolyMarkAuraLib，主键(AuraID, GSLevel=对应神侍等级)；服务端只用
-- (AuraID,GSLevel,SkillID,SkillLevel) 做技能派生，「圣痕等级串/圣痕图标」是客户端展示专用
-- (服务端不下发，由本表按 auraId + 当前神侍等级本地查)。
local function readHolyMarkAuraLibCSV()
    local filedata = game:ReadFileData("ResLib\\HolyMarkAuraLib.csv")
    if filedata == nil then
        Error("读取ResLib\\HolyMarkAuraLib.csv文件失败")
        return false
    end
    local data = readCSV(filedata)
    local items = {} -- auraId -> { {gsLevel=, skillId=, skillLevel=, holyMarkLevel=, icon=}, ... }
    for _, row in ipairs(data) do
        local auraId = tonumber(row[1]) -- 圣痕ID(光环组ID)
        local gsLevel = tonumber(row[4]) -- 对应神侍等级(生效所需神侍等级,逻辑用)
        -- 该csv表头(圣痕ID,...)无//前缀，会被当作数据行，auraId/gsLevel 解析为 nil 时跳过
        if auraId ~= nil and gsLevel ~= nil then
            if items[auraId] == nil then
                items[auraId] = {}
            end
            table.insert(items[auraId], {
                gsLevel = gsLevel, -- 对应神侍等级(生效所需,逻辑用)
                holyMarkLevel = row[2], -- 圣痕等级(字符串,仅界面显示)
                icon = row[3], -- 圣痕图标
                skillId = tonumber(row[5]), -- 光环技能ID
                skillLevel = tonumber(row[6]), -- 光环技能等级
            })
        end
    end
    allDatas['HolyMarkAura'] = items
    return true
end

-- 根据圣痕(光环组)ID与当前神侍等级，取 gsLevel<=当前 的最高行(即当前生效的光环)
-- @param auraId: 圣痕ID(光环组ID)
-- @param servantLevel: 当前神侍等级
-- @return: {gsLevel, skillId, skillLevel, holyMarkLevel(字符串,仅显示), icon}；无生效行则返回nil
local function findHolyMarkAura(auraId, servantLevel)
    local items = allDatas['HolyMarkAura'] -- 获取圣痕光环数据
    if items == nil or auraId == nil or servantLevel == nil then
        return nil
    end
    local rows = items[auraId]
    if rows == nil then
        return nil -- 该光环组不存在
    end
    local best = nil
    for _, r in ipairs(rows) do
        if r.gsLevel <= servantLevel and (best == nil or r.gsLevel > best.gsLevel) then
            best = r
        end
    end
    return best -- 返回当前神侍等级下生效的光环技能信息
end

-- 取该光环组的「最低门槛行」(gsLevel 最小的一行)。
-- 并非所有神侍等级都有光环：光环组可以从某个 gsLevel 起才配行，低于它就没有任何生效行。
-- @param auraId: 圣痕ID(光环组ID)
-- @return: {gsLevel, skillId, skillLevel, holyMarkLevel(字符串,仅显示), icon}；该组不存在则返回nil
local function findFirstHolyMarkAura(auraId)
    local items = allDatas['HolyMarkAura']
    if items == nil or auraId == nil then
        return nil
    end
    local rows = items[auraId]
    if rows == nil then
        return nil -- 该光环组不存在
    end
    local best = nil
    for _, r in ipairs(rows) do
        if best == nil or r.gsLevel < best.gsLevel then
            best = r
        end
    end
    return best
end

-- 界面展示用取行：优先当前生效行；当前神侍等级未达该组最低门槛(无生效行)时，回退到最低门槛行，
-- 让界面仍能按「最低门槛那一项」展示图标/技能名/tip，只是额外打上「未解锁」标记。
-- @param auraId: 圣痕ID(光环组ID)
-- @param servantLevel: 当前神侍等级
-- @return: row, locked —— row 为展示行(该组不存在时 nil)；locked=true 表示未达最低门槛(尚未解锁)
local function findHolyMarkAuraForDisplay(auraId, servantLevel)
    local cur = findHolyMarkAura(auraId, servantLevel)
    if cur ~= nil then
        return cur, false -- 已解锁：展示当前生效行
    end
    local first = findFirstHolyMarkAura(auraId)
    if first ~= nil then
        return first, true -- 未达门槛：展示最低门槛行 + 锁
    end
    return nil, false -- 该种族无光环组
end

-- 取「下一次真正升级」的光环行：gsLevel>当前 且 技能等级>当前生效技能等级 的最低 gsLevel 行。
-- 仅 gsLevel 更高但技能等级不变的行(同一光环等级跨多个神侍等级)不算升级，需跳过，
-- 否则「进阶至X将自动升级」会指向一个进阶后光环并不变化的神侍等级。
-- 用于「进阶至X将自动升级」提示：X = 该行对应神侍等级(gsLevel)在 GodServantLevelLib 里的名称。
-- @param auraId: 圣痕ID(光环组ID)
-- @param servantLevel: 当前神侍等级
-- @return: {gsLevel, skillId, skillLevel, holyMarkLevel(字符串,仅显示), icon}；无更高升级行(已达最高)则返回nil
local function findNextHolyMarkAura(auraId, servantLevel)
    local items = allDatas['HolyMarkAura']
    if items == nil or auraId == nil or servantLevel == nil then
        return nil
    end
    local rows = items[auraId]
    if rows == nil then
        return nil -- 该光环组不存在
    end
    -- 当前生效光环的技能等级(无生效行则视为0)——用于判定后续行是否真的把技能升了级
    local cur = findHolyMarkAura(auraId, servantLevel)
    local curSkillLevel = (cur and cur.skillLevel) or 0
    local best = nil
    for _, r in ipairs(rows) do
        if r.gsLevel > servantLevel and (r.skillLevel or 0) > curSkillLevel
            and (best == nil or r.gsLevel < best.gsLevel) then
            best = r
        end
    end
    return best -- 返回下一次真正升级(神侍等级更高且技能等级更高)的光环行；无则nil
end

local function readResetEquipPropsCSV()
    local filedata = game:ReadFileData("ResLib\\ResetEquipProps.csv")
    if filedata == nil then
        Error("读取ResLib\\ResetEquipProps.csv文件失败")
        return false
    end
    local data = readCSV(filedata)
    local items = {} -- 存储装备重置属性数据
    for _, row in ipairs(data) do
        local item = {
            equipId = tonumber(row[1]), -- 装备ID
            material1Id = tonumber(row[2]), -- 材料1 ID
            material1Count = tonumber(row[3]), -- 材料1 数量
            material2Id = tonumber(row[4]), -- 材料2 ID
            material2Count = tonumber(row[5]), -- 材料2 数量
            material3Id = tonumber(row[6]), -- 材料3 ID
            material3Count = tonumber(row[7]), -- 材料3 数量
            needMoney = tonumber(row[8]), -- 需要金钱
            needGodExp = tonumber(row[9]), -- 需要神格经验
            needLevel = tonumber(row[10]), -- 需要等级
            needGodLevel = tonumber(row[11]), -- 需要神格等级
        }
        items[item.equipId] = item
    end
    allDatas['ResetEquipProps'] = items
    return true
end
local function findEquipResetProp(equipId)
    local items = allDatas['ResetEquipProps'] -- 获取装备重置属性数据
    if items == nil then
        return nil -- 数据不存在
    end
    return items[equipId] -- 返回指定装备ID的重置属性
end

local function readEquipPropDescCSV()
    local filedata = game:ReadFileData("ResLib\\EquipPropDesc.csv")
    if filedata == nil then
        Error("读取ResLib\\EquipPropDesc.csv文件失败")
        return false
    end
    local data = readCSV(filedata)
    local items = {} -- 存储装备属性描述数据
    for _, row in ipairs(data) do
        local item = {
            propId = tonumber(row[1])/64, -- 属性ID
            desc = row[3], -- 描述
        }
        items[item.propId] = item
    end
    allDatas['EquipPropDesc'] = items
    return true
end
local function findEquipPropDesc(propId)
    local baseId = math.floor(propId/64) -- 计算基础属性ID
    local items = allDatas['EquipPropDesc'] -- 获取装备属性描述数据
    if items == nil then
        return nil -- 数据不存在
    end
    return items[baseId] -- 返回指定基础属性ID的描述
end

local function readEQPropSortCSV()
    local filedata = game:ReadFileData("ResLib\\EQPropSort.csv")
    if filedata == nil then
        Error("读取ResLib\\EQPropSort.csv文件失败")
        return false
    end
    local data = readCSV(filedata)
    local items = {} -- 存储装备属性排序数据
    for _, row in ipairs(data) do
        local item = {
            propId = tonumber(row[1])/64, -- 属性ID
            order = tonumber(row[3]), -- 排序顺序
            colorvalue = string.format("#%05d", tonumber(row[4]) or 0), -- 颜色值
        }
        items[item.propId] = item
    end
    allDatas['EQPropSort'] = items
    return true
end
local function findEQPropSort(propId)
    local baseId = math.floor(propId/64) -- 计算基础属性ID
    local items = allDatas['EQPropSort'] -- 获取装备属性排序数据
    if items == nil then
        return nil -- 数据不存在
    end
    return items[baseId] -- 返回指定基础属性ID的排序信息
end

local function readAwakeMythicEquipCSV()
    local filedata = game:ReadFileData("ResLib\\AwakeMythicEquip.csv")
    if filedata == nil then
        Error("读取ResLib\\AwakeMythicEquip.csv文件失败")
        return false
    end
    local data = readCSV(filedata)
    local items = {} -- 存储神话装备觉醒数据
    for _, row in ipairs(data) do
        local item = {
            mainEquipId = tonumber(row[1]),    -- 核心装备ID
            assistEquipId = tonumber(row[2]),   -- 辅助装备ID
            needLevel = tonumber(row[3]), -- 需要等级
            needGodLevel = tonumber(row[4]), -- 需要神格等级
            needGodExp = tonumber(row[5]),      -- 需要神格经验
            needMoney = tonumber(row[6]), -- 需要金钱
            productId = tonumber(row[7]), -- 产品ID
            -- 辅助装备属性数组，每组包含ID和数值
            assistProps = {},
            -- 材料数组，每组包含ID和数量
            materials = {}
        }

        -- 读取10组辅助装备属性（索引位置相应调整）
        for i = 1, 10 do
            local propId = tonumber(row[i * 2 + 6])
            local propValue = tonumber(row[i * 2 + 7])
            if propId and propId > 0 then
                table.insert(item.assistProps, {id = propId, value = propValue})
            end
        end

        -- 读取5组材料（索引位置相应调整）
        for i = 1, 5 do
            local materialId = tonumber(row[i * 2 + 26])
            local materialCount = tonumber(row[i * 2 + 27])
            if materialId and materialId > 0 then
                table.insert(item.materials, {id = materialId, count = materialCount})
            end
        end

        --Debug("main equip "..tostring(item.mainEquipId).." assist equip "..tostring(item.assistEquipId))
        if items[item.mainEquipId] == nil then
            items[item.mainEquipId] = {}
        end
        items[item.mainEquipId][item.assistEquipId] = item
    end
    allDatas['AwakeMythicEquip'] = items
    return true
end

local function findAwakeMythicEquip(mainEquipId)
    local items = allDatas['AwakeMythicEquip'] -- 获取神话装备觉醒数据
    if items == nil then
        return nil -- 数据不存在
    end
    return items[mainEquipId] -- 返回指定主装备ID的神话装备觉醒信息
end

local function readEnhanceEquipAwakeLibCSV()
    local filedata = game:ReadFileData("ResLib/EnhanceEquipAwakeLib.csv")
    if filedata == nil then
        Error("读取ResLib/EnhanceEquipAwakeLib.csv文件失败")
        return false
    end
    local data = readCSV(filedata)
    local items = {}
    for _, row in ipairs(data) do
        local item = {
            mainEquipId = tonumber(row[1]), -- 主装备ID
            needLevel = tonumber(row[2]), -- 需要等级
            needGodLevel = tonumber(row[3]), -- 需要神格等级
            needGodExp = tonumber(row[4]), -- 需要神格经验
            needMoney = tonumber(row[5]), -- 需要金钱
            productId = tonumber(row[6]), -- 产品ID
            equipProps = {}, -- 装备属性数组
            materials = {} -- 材料数组
        }

        -- 读取10组装备属性
        for i = 1, 10 do
            local propId = tonumber(row[i * 2 + 5])
            local propValue = tonumber(row[i * 2 + 6])
            if propId and propId > 0 then
                table.insert(item.equipProps, {id = propId, value = propValue})
            end
        end

        -- 读取5组材料
        for i = 1, 5 do
            local materialId = tonumber(row[i * 2 + 25])
            local materialCount = tonumber(row[i * 2 + 26])
            if materialId and materialId > 0 then
                table.insert(item.materials, {id = materialId, count = materialCount})
            end
        end

        items[item.mainEquipId] = item
    end
    allDatas['EnhanceEquipAwakeLib'] = items
    return true
end

local function readResetEquipAwakeEffectCSV()
    local filedata = game:ReadFileData("ResLib/ResetEquipAwakeEffect.csv")
    if filedata == nil then
        Error("读取ResLib/ResetEquipAwakeEffect.csv文件失败")
        return false
    end
    local data = readCSV(filedata)
    local items = {} -- 存储装备觉醒效果重置数据
    for _, row in ipairs(data) do
        local item = {
            mainEquipId = tonumber(row[1]), -- 主装备ID
            needLevel = tonumber(row[2]), -- 需要等级
            needGodLevel = tonumber(row[3]), -- 需要神格等级
            needGodExp = tonumber(row[4]), -- 需要神格经验
            needMoney = tonumber(row[5]), -- 需要金钱
            materials = {} -- 材料数组
        }

        -- 读取5组材料
        for i = 1, 5 do
            local materialId = tonumber(row[i * 2 + 4])
            local materialCount = tonumber(row[i * 2 + 5])
            if materialId and materialId > 0 then
                table.insert(item.materials, {id = materialId, count = materialCount})
            end
        end

        items[item.mainEquipId] = item
    end
    allDatas['ResetEquipAwakeEffect'] = items
    return true
end

local function findResetEquipAwakeEffect(mainEquipId)
    local items = allDatas['ResetEquipAwakeEffect'] -- 获取装备觉醒效果重置数据
    if items == nil then
        return nil -- 数据不存在
    end
    return items[mainEquipId] -- 返回指定主装备ID的重置信息
end

local function readEquipAwakeEffectPoolCSV()
    local filedata = game:ReadFileData("ResLib/EquipAwakeEffectPool.csv")
    if filedata == nil then
        Error("读取ResLib/EquipAwakeEffectPool.csv文件失败")
        return false
    end
    local data = readCSV(filedata)
    local items = {} -- 存储装备觉醒效果池数据
    for _, row in ipairs(data) do
        local poolId = tonumber(row[1]) -- 效果池ID
        local item = {
            skillId = tonumber(row[2]), -- 技能ID
            skillLevel = tonumber(row[3]), -- 技能等级
            weight = tonumber(row[4]) -- 权重
        }
        if poolId~=nil then
            if items[poolId] == nil then
                items[poolId] = {}
            end
            table.insert(items[poolId], item)
        end
    end
    allDatas['EquipAwakeEffectPool'] = items
    return true
end

-- 根据效果池ID查找装备觉醒效果池数据
-- @param poolId: 效果池ID
-- @return: 对应效果池ID的数据表，如果不存在则返回nil
local function findEquipAwakeEffectPool(poolId)
    local items = allDatas['EquipAwakeEffectPool'] -- 获取装备觉醒效果池数据
    if items == nil then
        return nil -- 数据不存在
    end
    return items[poolId] -- 返回指定效果池ID的数据
end

local function readMapTagLibCSV()
    local filedata = game:ReadFileData("ResLib/MapTagLib.csv")
    if filedata == nil then
        Error("读取ResLib/MapTagLib.csv文件失败")
        return false
    end
    local data = readCSV(filedata)
    local mapTagInfos = {} -- 地图ID 到 标签ID列表 的映射
    local tagNames = {}    -- 标签ID 到 标签名称 的映射
    for _, row in ipairs(data) do
        local tagId = tonumber(row[1])
        local mapId = tonumber(row[2])
        local tagName = row[3]
        if mapTagInfos[mapId] == nil then
            mapTagInfos[mapId] = {}
        end
        table.insert(mapTagInfos[mapId],tagId)
        if tagNames[tagId] == nil then
            tagNames[tagId] = tagName
        end
    end
    allDatas['MapTagInfos'] = mapTagInfos
    allDatas['MapTagNames'] = tagNames
    return true -- 为保持一致性，添加返回 true
end

-- 读取地图Buff绑定技能库CSV文件，并将数据添加到 allDatas['MapBuffLib'] 中对应Buff的Skills字段
local function readMapBuffBindSkillLibCSV()
    local filedata = game:ReadFileData("ResLib/MapBuffBindSkillLib.csv")
    if filedata == nil then
        Error("读取ResLib/MapBuffBindSkillLib.csv文件失败")
        return false
    end
    local buffMap = allDatas['MapBuffLib']
    local data = readCSV(filedata)
    for _, row in ipairs(data) do
        local buffId = tonumber(row[1])
        local skillId = tonumber(row[2])
        local skillLevel = tonumber(row[3])
        if buffId and buffId > 0 then
            if buffMap[buffId] == nil then
                Error("buffId " .. tostring(buffId) .. " not found in MapBuffLib")
            else
                local skillInfo = findSkill(skillId, skillLevel)
                if skillInfo == nil then
                    Error("skillId " .. tostring(skillId) .. " skillLevel " .. tostring(skillLevel) .. " not found")
                else
                    table.insert(buffMap[buffId].Skills,
                        { SkillId = skillId, SkillLevel = skillLevel, SkillInfo = skillInfo })
                end
            end
        end
    end
    return true
end

-- 读取地图Buff属性库CSV文件，并将数据添加到 allDatas['MapBuffLib'] 中对应Buff的Props字段
local function readMapBuffPropLibCSV()
    local filedata = game:ReadFileData("ResLib/MapBuffPropLib.csv")
    if filedata == nil then
        Error("读取ResLib/MapBuffPropLib.csv文件失败")
        return false
    end
    local buffMap = allDatas['MapBuffLib']
    local data = readCSV(filedata)
    for _, row in ipairs(data) do
        local buffId = tonumber(row[1])
        local propId = tonumber(row[2])
        local param1 = tonumber(row[3])
        local param2 = tonumber(row[4])
        local param3 = tonumber(row[5])
        local param4 = tonumber(row[6])
        local param5 = tonumber(row[7])
        if buffId and buffId > 0 then
            if buffMap[buffId] == nil then
                Error("buffId "..tostring(buffId).." not found in MapBuffLib")
            else
                table.insert(buffMap[buffId].Props, {PropId = propId, Param1 = param1, Param2 = param2, Param3 = param3, Param4 = param4, Param5 = param5})
            end
        end
    end
    return true
end

local function readMapBuffLibCSV()
    local filedata = game:ReadFileData("ResLib/MapBuffLib.csv")
    if filedata == nil then
        Error("读取ResLib/MapBuffLib.csv文件失败")
        return false
    end
    local data = readCSV(filedata)
    local items = {}
    for _, row in ipairs(data) do
        local item = {
            BuffId = tonumber(row[1]),
            DefaultTime = tonumber(row[2]),
            ExpireTimeType = tonumber(row[3]),
            MaxTime = tonumber(row[4]),
            GroupId = tonumber(row[5]),
            GroupLevel = tonumber(row[6]),
            InvalidMapTag = tonumber(row[7]),
            ValidMapTag = tonumber(row[8]),
            GainMapTag = tonumber(row[9]),
            SurvivalMapTag = tonumber(row[10]),
            Name = row[11],
            CanCancel = tonumber(row[12]) == 1,
            CanClose = tonumber(row[13]) == 1, -- 是否可关闭
            SupressedBuffId = tonumber(row[14]), -- 抑制的Buff ID
            IsNegative = tonumber(row[15]) == 1, -- 是否为负面效果
            Icon = row[16], -- 图标
            Desc = row[17], -- 描述
            Skills = {}, -- 将由 MapBuffBindSkillLib.csv 填充
            Props = {}   -- 将由 MapBuffPropLib.csv 填充
        }
        items[item.BuffId] = item
    end
    allDatas['MapBuffLib'] = items
    Debug("readMapBuffBindSkillLibCSV")
    readMapBuffBindSkillLibCSV()
    Debug("readMapBuffPropLibCSV")
    readMapBuffPropLibCSV()
    return true
end

-- 根据地图ID查找地图标签ID列表
-- @param mapId: 地图ID
-- @return: 包含该地图所有标签ID的表，如果不存在则返回nil
local function findMapTags(mapId)
    local mapTagInfos = allDatas['MapTagInfos'] -- 已修正键名
    if mapTagInfos == nil then
        return nil
    end
    return mapTagInfos[mapId]
end

-- 根据标签ID查找地图标签名称
-- @param tagId: 标签ID
-- @return: 标签名称字符串，如果不存在则返回nil
local function findMapTagName(tagId)
    local tagNames = allDatas['MapTagNames'] -- 已修正键名
    if tagNames == nil then
        return nil
    end
    return tagNames[tagId]
end

local function readArtifactLibCSV()
    local filedata = game:ReadFileData("ResLib/ArtifactLib.csv")
    if filedata == nil then
        Error("读取ResLib/ArtifactLib.csv文件失败")
        return false
    end
    local data = readCSV(filedata)
    local items = {}
    for _, row in ipairs(data) do
        local item = {
            ArtifactId = tonumber(row[1]),      -- 奇物ID
            Name = row[2],                      -- 奇物名称
            Icon = row[3],                      -- 奇物图标
            ShowModel = row[4],                 -- 奇物展示模型
            Type = tonumber(row[5]),            -- 奇物类型
            TargetType = tonumber(row[6]),      -- 目标类型
            TargetTypeId = tonumber(row[7]),    -- 目标类型ID
            Quality = tonumber(row[8]),         -- 品质
            SkillId = tonumber(row[9]),         -- 技能ID
            SkillLevel = tonumber(row[10]),     -- 技能等级
            Desc = row[11],                     -- 奇物描述
            Hint = row[12]                      -- 奇物提示
        }
        items[item.ArtifactId] = item
    end
    allDatas['ArtifactLib'] = items
    return true
end

local function findArtifact(artifactId)
    local items = allDatas['ArtifactLib']
    if items == nil then
        return nil
    end
    return items[artifactId]
end

-- 读取ItemLib.csv，建立 itemId -> 物品信息、物品名称 -> itemId 两张索引。
-- 用于在客户端按物品名搜索 itemId（例如寄售搜索框）。
local function readItemLibCSV()
    local filedata = game:ReadFileData("ResLib/ItemLib.csv")
    if filedata == nil then
        Error("读取ResLib/ItemLib.csv文件失败")
        return false
    end
    local data = readCSV(filedata)
    local items = {}     -- itemId -> 物品静态信息
    local nameToId = {}  -- 名称 -> itemId（同名只保留首次出现的ID）
    for _, row in ipairs(data) do
        local itemId = tonumber(row[1])
        if itemId then
            local item = {
                ItemId = itemId,    -- 道具ID
                Name = row[18],     -- 名称
                Icon = row[16],     -- Icon名称
            }
            items[itemId] = item
            if item.Name and item.Name ~= "" and nameToId[item.Name] == nil then
                nameToId[item.Name] = itemId
            end
        end
    end
    allDatas['ItemLib'] = items
    allDatas['ItemLibNameToId'] = nameToId
    return true
end

-- 根据itemId查找物品静态信息
local function findItem(itemId)
    local items = allDatas['ItemLib']
    if items == nil then return nil end
    return items[itemId]
end

-- 根据物品名称查找itemId（同名物品返回首次出现的ID）
local function findItemIdByName(name)
    local nameToId = allDatas['ItemLibNameToId']
    if nameToId == nil then return nil end
    return nameToId[name]
end

-- 根据物品名称模糊查找itemId（"只要包含即可"规则）：
-- 扫描 ItemLib，返回所有名称包含 substr 的 itemId 数组（按 itemId 升序，
-- 最多 maxCount 个）。供寄售搜索框在精确匹配不到时回退使用。
-- 用 string.find(name, substr, 1, true) 走纯文本匹配，避免 substr 含
-- Lua 模式特殊字符时被当成模式解析。
local function findItemIdsByNameFuzzy(substr, maxCount)
    local result = {}
    if not substr or substr == "" then return result end
    local items = allDatas['ItemLib']
    if items == nil then return result end
    maxCount = maxCount or 200
    for itemId, item in pairs(items) do
        local name = item.Name
        if name and name ~= "" and string.find(name, substr, 1, true) ~= nil then
            table.insert(result, itemId)
        end
    end
    -- pairs 顺序不确定，排序后再截断，保证结果稳定且优先保留较小 itemId
    table.sort(result)
    if #result > maxCount then
        local trimmed = {}
        for i = 1, maxCount do trimmed[i] = result[i] end
        return trimmed
    end
    return result
end

local function loadAll()
    Debug("readSkillLibCSV")
    readSkillLibCSV()
    Debug("readGodhoodLevelLibCSV")
    readGodhoodLevelLibCSV()
    Debug("readGodServantLevelLibCSV")
    readGodServantLevelLibCSV()
    Debug("readGodServantResetCostCSV")
    readGodServantResetCostCSV()
    Debug("readHolyMarkAuraLibCSV")
    readHolyMarkAuraLibCSV()
    Debug("readPetLibCSV")
    readPetLibCSV()
    Debug("readResetEquipPropsCSV")
    readResetEquipPropsCSV()
    Debug("readEquipPropDescCSV")
    readEquipPropDescCSV()
    Debug("readEQPropSortCSV")
    readEQPropSortCSV()
    Debug("readAwakeMythicEquipCSV")
    readAwakeMythicEquipCSV()
    Debug("readEnhanceEquipAwakeLibCSV")
    readEnhanceEquipAwakeLibCSV()
    Debug("readResetEquipAwakeEffectCSV")
    readResetEquipAwakeEffectCSV()
    Debug("readEquipAwakeEffectPoolCSV")
    readEquipAwakeEffectPoolCSV()
    Debug("readMapTagLibCSV") 
    readMapTagLibCSV() 
    Debug("readArtifactLibCSV")
    readArtifactLibCSV()
    Debug("readMapBuffLibCSV")
    readMapBuffLibCSV()
    Debug("readItemLibCSV")
    readItemLibCSV()
end

-- 根据Buff ID查找地图Buff信息
-- @param buffId: Buff ID
-- @return: 包含该Buff信息的表，如果不存在则返回nil
local function findMapBuff(buffId)
    local items = allDatas['MapBuffLib']
    if items == nil then
        return nil
    end
    return items[buffId]
end

-- 模块导出表
local m = {
    LoadAll = loadAll, -- 加载所有CSV数据
    Datas = allDatas, -- 存储所有已加载数据的表
    FindGodhoodLevel = findGodhoodLevel, -- 查找神格等级信息
    FindHolyMarkAura = findHolyMarkAura, -- 查找圣痕光环当前生效的技能(按神侍等级)
    FindHolyMarkAuraForDisplay = findHolyMarkAuraForDisplay, -- 展示用取行(未达最低门槛回退最低行)，返回 row, locked
    FindNextHolyMarkAura = findNextHolyMarkAura, -- 查找下一次升级的圣痕光环行(gsLevel>当前的最低行)
    FindPetHolyMarkID = findPetHolyMarkID, -- 按宠物种族ID查圣痕(光环组)ID(读 PetLib.csv)
    FindPetGodFireLibID = findPetGodFireLibID, -- 按宠物种族ID查神火技能库ID(读 PetLib.csv)
    FindPetGodServantRank = findPetGodServantRank, -- 按宠物种族ID查神侍等级(=TPetLib.GodServantRank，读 PetLib.csv)
    FindGodServantLevel = findGodServantLevel, -- 按神侍等级查阶/星/名/归元消耗系数(读 GodServantLevelLib.csv)
    FindGodServantNameByPhase = findGodServantNameByPhase, -- 按品阶查该段位第一个神侍名(神火格解锁提示用)
    GetGodServantResetBase = getGodServantResetBase, -- 取神侍归元基础消耗(读 GodServantResetCostLib.csv)
    FindEquipResetProp = findEquipResetProp, -- 查找装备重置属性信息
    FindEquipPropDesc = findEquipPropDesc, -- 查找装备属性描述
    FindEQPropSort = findEQPropSort, -- 查找装备属性排序信息
    FindAwakeMythicEquip = findAwakeMythicEquip, -- 查找神话装备觉醒信息
    FindResetEquipAwakeEffect = findResetEquipAwakeEffect, -- 查找装备觉醒效果重置信息
    FindEquipAwakeEffectPool = findEquipAwakeEffectPool, -- 查找装备觉醒效果池信息
    FindMapTags = findMapTags, -- 查找地图标签ID列表
    FindMapTagName = findMapTagName, -- 查找地图标签名称
    FindMapBuff = findMapBuff, -- 查找地图Buff信息
    FindArtifact = findArtifact, -- 查找奇物信息
    FindItem = findItem, -- 根据itemId查找物品静态信息
    FindItemIdByName = findItemIdByName, -- 根据物品名称查找itemId
    FindItemIdsByNameFuzzy = findItemIdsByNameFuzzy, -- 模糊查找itemId列表（"包含"规则）
    FindSkill = findSkill, -- 根据(skillId,skillLevel)查找技能信息(Name/Icon/Desc)，神侍界面用
}

return m
