
-------------------------------------------------------------------------
-- 获取调用堆栈字符串
-- stackLevel: 最大递归次数: 即返回信息最大包含调用层次数
function callstack(stackLevel)

    local str = ""
    -- 0表示debug.getinfo本身, 1 表示调用者(即callstack), 2 表示调用callstack的函数
    local startLevel = 2
    for level = startLevel, stackLevel + 2 do
        local info = debug.getinfo(level, "nSl")
        if not info then
            break
        end
        if level > startLevel then
            str = str .. "\n"
        end
        str = str .. string.format("(%d)%-20s():%s(%-4d)\n", level - startLevel, info.name or "", info.source or "", info.currentline)

        -- 打印该层的参数与局部变量
        local index = 1  -- 1表示第一个参数或局部变量,依次类推
        while true do
            local name, value = debug.getlocal(level, index)
            if not name then
                break
            end

            local valueType = type(value)
            local valueStr
            if valueType == "string" then
                valueStr = value
            elseif valueType == "number" then
                valueStr = string.format("%.2f", value)
            elseif valueType == "table" then
                valueStr = TableToString(value)
            end
            if valueStr then
                str = str .. string.format("%s=%s\n", name, valueStr)
            end
            index = index + 1
        end

    end
    return str
end
-------------------------------------------------------------------------
function TableToString(t)

    local str = ""

    local tp = type(t)

    if tp == "table" then
        str = str .. "{"
        for k, v in pairs(t) do
            if tonumber(k) then
                str = str .. "[" .. k .. "]="
            else
                str = str .. k .. "="
            end
            str = str .. TableToString(v) .. ","
        end
        str = str .. "}"
    elseif tp == "nil" then
        str = str .. 'nil'
    elseif tp == "boolean" then
        if t then
            str = str .. 'true'
        else
            str = str .. 'false'
        end
    elseif tp == "string" then
        str = str .. '"' .. t .. '"'
    else
        str = str .. tostring(t)
    end

    return str
end
-- 定义个缩写
tts = TableToString

-- 重载print函数
print = function(...)
    local args = {...}
    for c, v in pairs(args) do
        if type(v) == 'table' then
            local tblstr = TableToString(v)
            args[c] = tblstr
        end
    end
    local str = ""
    for c, v in pairs(args) do
        if string.len(str) > 0 then
            str = str .. (print_sepchar or "")
        end
        if type(v) == "string" then
            str = str .. v
        else
            str = str .. TableToString(v)
        end
    end

    -- 恢复默认的print_sepchar值, 防止影响其他地方的打印
    print_sepchar = '\t'
    if string.len(str) > 0 then
        Info(str)
    end
end
print_sepchar = '\t'

----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
-- 按空格个数对齐文本, 文本不足时补足空格
-- prespacenum:右对齐, 按指定空格数量填充不足数量
-- spacenum:   左对齐, 按指定空格数量填充不足的空格, 若存在prespacenum, 则此值为包含prespacenum的总数量
function AlignTextWithSpace(str, spacenum, prespacenum)
    spacenum = spacenum or 0

    local strnum = string.len(str)

    local ColorCodeNum = 0
    for code in string.gmatch(str, "(#%x+#)") do
        ColorCodeNum = ColorCodeNum + 1
    end

    strnum = strnum - ColorCodeNum * 8

    if prespacenum and strnum < prespacenum then
        str = string.rep(" ", prespacenum - strnum ) .. str
        strnum = prespacenum
    end

    if strnum >= spacenum then
        return str
    end

    local diff = spacenum - strnum

    str = str .. string.rep(" ", diff)

    return str
end

-- 返回品质代码对应的6位十六进制颜色字符串
function GetItemColorString(QualityColor)

    local str = 'FFFFFF'
    --灰,白,绿,蓝,黄,暗金,紫,红
    if QualityColor == 0 then
        str = '838183'
    elseif QualityColor == 1 then
        str = 'FFFFFF'
    elseif QualityColor == 2 then
        str = '10D210'
    elseif QualityColor == 3 then
        str = '0071DE'
    elseif QualityColor == 4 then
        str = 'FFFF00'
    elseif QualityColor == 5 then
        str = 'FFE294'
    elseif QualityColor == 6 then
        str = 'B430B4'
    elseif QualityColor == 7 then
        str = 'E61800'
    end

    return str
end

-- 获取时间长度描述字符串, 最大单位天,精确到秒
-- DayName, HourName, MinuteName, SecName: 天, 小时,分秒的分割名称, 若不填则没有想关输出, 不显示名称应传入空白字符串
function GetTimeLengthFormatString(TimeLeftSec, DayName, HourName, MinuteName, SecName)

    --DayName = DayName or '天'
    --HourName = HourName or '小时'
    --MinuteName = MinuteName or '分'
    --SecName = SecName or '秒'

    local second = math.fmod(TimeLeftSec, 60)
    TimeLeftSec = math.floor(TimeLeftSec / 60)
    local minute = math.fmod(TimeLeftSec, 60)
    TimeLeftSec = math.floor(TimeLeftSec / 60)
    local hour = math.fmod(TimeLeftSec, 24)
    TimeLeftSec = math.floor(TimeLeftSec / 24)
    local day = TimeLeftSec

    local TimeLengthStr = ''
    if DayName and day > 0 then
        TimeLengthStr = TimeLengthStr .. day .. DayName
    end
    if HourName and hour > 0 then
        TimeLengthStr = TimeLengthStr .. hour .. HourName
    end
    if MinuteName and minute > 0 then
        TimeLengthStr = TimeLengthStr .. minute .. MinuteName
    end
    if SecName and second >= 0 then
        TimeLengthStr = TimeLengthStr .. second .. SecName
    end

    return TimeLengthStr
end

-- 获取时间剩余描述字符串
-- remainTimeSec: 剩余时间秒数
-- 返回最大的时间单位, 按天,小时,分钟,秒的优先顺序处理
function GetTimeRemainFormatString(remainTimeSec)
    local timestr = ""
    if remainTimeSec > 3600*24 then
        local t = math.floor(remainTimeSec / (3600*24))
        timestr = string.format("%d天", t)
    elseif remainTimeSec > 3600 then
        local t = math.floor(remainTimeSec / 3600)
        timestr = string.format("%d小时", t)
        print("t=", t, "str=", timestr)
    elseif remainTimeSec > 60 then
        local t = math.floor(remainTimeSec / 60)
        timestr = string.format("%d分钟", t)
    else
        local t = math.floor(remainTimeSec)
        timestr = string.format("%d秒", t)
    end
    return timestr
end

-- 格式化金钱字符串
-- money: 金钱数字
-- minlen: 金钱字符串格式化最小长度, 默认4位
-- delimiter: 分割符号,默认为逗号','
-- place: 进位位数, 默认万进位(4), 若要使用千进位则传入3
function GetMoneyFormatString(money, minlen, place, delimiter)

    minlen = minlen or 4
    place = place or 4
    delimiter = delimiter or ','

    local strmoney = tostring(money)
    local temp = { }
    local mlen = string.len(strmoney)
    if place > 0 and mlen > minlen then
        while mlen > place do
            local str = string.sub(strmoney, mlen - place + 1, mlen)
            temp[#temp + 1] = str
            strmoney = string.sub(strmoney, 1, mlen - place)
            mlen = string.len(strmoney)
        end
    end
    temp[#temp + 1] = strmoney
    local str = ""
    for i = #temp, 1, -1 do
        if i ~= 1 then
            str = str .. temp[i] .. ","
        else
            str = str .. temp[i]
        end
    end
    return str
end
