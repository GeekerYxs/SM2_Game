-- 一些时间计算相关

-- [Comment]
-- 时间单位:秒(utc)
function dtNowTime()
    return os.time()
end

-- [Comment]
-- 时间单位:秒
function dtLocalNowTime()
    local utc = os.time()
    -- 把utc date表作为本地日期计算时间戳, 并计算差值, 加到utc时间上
    local localdiff = dtDiffLocalAndUTC()
    return utc + localdiff
end

function dtDiffLocalAndUTC()
    -- 把utc date表作为本地日期计算时间戳, 并计算差值
    local diff = os.difftime( os.time(), os.time( os.date('!*t') ) )
    return diff
end

-- [Comment]
-- utc days
function dtNowDays()
    local s = os.time()

    return math.floor( s / 3600 / 24 )
end

-- [Comment]
-- local days
function dtLocalNowDays()
    local s = dtLocalNowTime()

    return math.floor( s / 3600 / 24 )
end

-- [Comment]
-- 返回日期table:{year:xxxx, month(1-12), day(1-31), hour(0-23), min(0-59), sec(0-61), wday(1-7,星期日=1), yday(本年天数编号}
function dtNowDate()
    return os.date("*t")
end

-- [Comment]
-- Format:
-- 1. "!" 开头= UTC时间,按格林尼治时间进行格式化。
-- 2. "*t" = 返回表 {year:xxxx, month(1-12), day(1-31), hour(0-23), min(0-59), sec(0-61), wday(1-7,星期日=1), yday(本年天数编号}
-- 3. nil = 默认使用"%c", 格式如: 月/日/年 时(24):分:秒
-- 4. 字符串格式:
-- 格式符	含义	具体示例
-- %a	一星期中天数的简写	(Fri)
-- %A	一星期中天数的全称	(Wednesday)
-- %b	月份的简写	(Sep)
-- %B	月份的全称	(May)
-- %c	日期和时间	(09/16/98 23:48:10)
-- %d	一个月中的第几天	(28)[1 - 31]
-- %H	24小时制中的小时数	(18)[00 - 23]
-- %I	12小时制中的小时数	(10)[01 - 12]
-- %j	一年中的第几天	(209)[01 - 366]
-- %M	分钟数	(48)[00 - 59]
-- %m	月份数	(09)[01 - 12]
-- %P	上午或下午	(pm)[am - pm]
-- %S	一分钟之内秒数	(10)[00 - 59]
-- %w	一星期中的第几天	(3)[0 - 6 = 星期天 - 星期六]
-- %W	一年中的第几个星期	(2)0 - 52
-- %x	日期	(09/16/98)
-- %X	时间	(23:48:10)
-- %y	两位数的年份	(16)[00 - 99]
-- %Y	完整的年份	(2016)
-- %%	字符串'%'	(%)
-- 示例: local timestr = dtNowDateString("%Y%m%d%H%M%S")
function dtNowDateString(Format)
    if not Format then
        Format = "%c"
    end
    local dt = os.date(Format)
    if type(dt) =="table" then
        return TableToString(dt)
    end

    return dt
end

-- [Comment]
-- 获取当天0点时间戳
function dtNowDateOClockTime(h, m, s)
    local nowdate = os.date("*t")
    nowdate.hour = h or 0
    nowdate.min = m or 0
    nowdate.sec = s or 0
    local nowtime = os.time(nowdate)
    return nowtime
end

-- [Comment]
-- 获取当天0点时间戳字符串
function dtNowDateOClockTimeString(h, m, s)
    local nowtime = tostring(dtNowDateOClockTime(h, m, s))
    return nowtime
end

-- [Comment]
-- 获取本周开始当天0点时间戳
-- weekDay 默认为1(表示星期天0点), 取值(1~7),表示周日~周六不同周天的0点
function dtNowWeekOClockTime(weekDay, h, m, s)

    weekDay = weekDay or 1

    local nowdate = os.date("*t")
    nowdate.hour = h or 0
    nowdate.min = m or 0
    nowdate.sec = s or 0

    local difftime = (tonumber(nowdate.wday) - weekDay) * 24 * 3600
    if difftime < 0 then
        -- 如果是定义的本周前, 则将时刻往前移动一周
        difftime = difftime + 7 * 24 * 3600
    end

    local nowtime = os.time(nowdate) - difftime
    return nowtime
end

-- [Comment]
-- 获取本周开始当天0点时间戳字符串
function dtNowWeekOClockTimeString(weekDay, h, m, s)
    local nowtime = tostring(dtNowWeekOClockTime(weekDay, h, m, s))
    return nowtime
end

-- [Comment]
-- 获取当前所在分钟对应的时间戳{year,month, day, hour, min, 0, 0}
function dtCurrentMinuteTime()
    local dt = os.date('*t')
    dt.sec = 0

    return os.time(dt)
end

-- [Comment]
-- 返回dttime下一分钟整对应的时间戳
function dtNextMinuteTime(dttime)
    dttime = dttime or os.time()

    local nextmin = ( math.floor(dttime / 60) + 1 ) * 60

    return nextmin
end


-- [Comment]
-- 获取当前所在小时整对应的时间戳{year,month, day, hour, 0, 0, 0}
function dtCurrentHourTime()
    local dt = os.date('*t')
    dt.min = 0
    dt.sec = 0

    return os.time(dt)
end

-- [Comment]
-- 返回date1下一个小时整对应的时间戳
function dtNextHourTime(date1)
    local d1 = { year = date1.year, month = date1.month, day = date1.day, hour = date1.hour, min = date1.min, sec = date1.sec, wday = date1.wday, yday = date1.yday, isdst = date1.isdst }
    d1.min = 0
    d1.sec = 0
    d1.hour = d1.hour + 1
    if d1.hour >= 24 then
        d1.hour = d1.hour - 24
        d1.day = d1.day + 1
        if d1.day > 28 then
            local dayMax = os.date("*t", os.time( { year = d1.year, month = d1.month + 1, day = 0 })).day
            if d1.day >= dayMax then
                d1.day = d1.day - dayMax
                d1.month = d1.month + 1
                if d1.month > 12 then
                    d1.month = d1.month - 12
                    d1.year = d1.year + 1
                end
            end
        end
    end

    return os.time(d1)
end

-- [Comment]
-- 解析日期字符串返回日期table:{year:xxxx, month(1-12), day(1-31), hour(0-23), min(0-59), sec(0-61), wday(1-7,星期日=1), yday(本年天数编号}
-- 日期格式:只支持24小时格式, "2019/06/27 19:48:57" 或 "2019-06-27 19:48:57"
function dtParseDateString(strDate)

    local time = dtString2Time(strDate)
    -- 时间戳转为日期表
    return os.date('*t', time)
end

-- [Comment]
-- 解析日期字符串返回时间戳
-- 日期格式:只支持 "2019/06/27 19:48:57" 或 "2019-06-27 19:48:57"
function dtString2Time(strDate)

    -- 日期时间, 时间可以省略, 日期至少优先保证月,日两部分
    local _pos, _, y, m, d, _hour, _min, _sec, _hs = string.find(strDate, "(%d*)[/-]?(%d+)[/-](%d+)%s*(%d*):?(%d*):?(%d*)%s*(%a*)")

    -- 若无效说明不含日期部分, 尝试分析时间, 时间优先顺序为时分秒
    if not _pos then
        y = 1970
        m = 1
        d = 1
        _pos, _, _hour, _min, _sec, _hs = string.find(strDate, "%s*(%d*):?(%d*):?(%d*)%s*(%a*)")
    end

    if not _pos then
        -- 返回-1避免被解释为1970.1.1
        return -1
    end

    local date = {year=y, month = m, day = d, hour = _hour, min = _min, sec = _sec}
    if date.year == "" then
        date.year = 1970
    end
    if date.hour == "" then
        date.hour = 0
    end
    if date.min == "" then
        date.min = 0
    end
    if date.sec == "" then
        date.sec = 0
    end

    if _hs and string.upper(_hs) == "PM" and date.hour < 12 then
        -- 下午时间调整为24小时制
        date.hour = date.hour + 12
    end

    local time = os.time(date)

    return time
end

-- [Comment]
-- 根据一年中天数编号与该天是星期几计算所在一年中周数编号(从第1周开始)
function dtWeekOfYear(yday, wday)

    -- 从0开始的周编号
    local week = math.floor( (yday - 1) / 7 )
    -- 该年1号所在的星期几为开始, 超过的天数, 即第week周过diff天
    local diffday = yday - 1 - week * 7

    --Info("yday=" .. yday .. ",wday=" .. wday .. ", diffday = " .. diffday .. ", week = " .. week)

    -- 得到今年第一天星期几
    local firstweekday = wday - 1 - diffday;
    if firstweekday >= 7 then
        firstweekday = firstweekday - 7
    end
    if firstweekday < 0 then
        firstweekday = firstweekday + 7
    end
    --Info("firstweekday = " .. firstweekday .. ", wday - 1 = " .. (wday - 1 ))

    if wday - 1 < firstweekday then
        return week + 2
    else
        return week + 1
    end


end


-- [Comment]
-- 获取本周编号
function dtNowWeekOfYear()

    local date = dtNowDate()

    return dtWeekOfYear(date.yday, date.wday)
end

-- [Comment]
-- 通过给定时间戳计算当月天数
function dtGetDayAmountOfMonth(dttime)
    dttime = dttime or os.time()

    -- 获取年份(4位年),月份(1-12)
    local year = os.date("%Y", dttime)
    local month = os.date("%m", dttime) + 1

    -- 获取当月天数, 通过计算下个月第0天
    local dayAmount = tonumber( os.date("%d", os.time({year=year, month=month, day=0})) )

    return dayAmount
end

-- [Comment]
-- 获取时间戳给定时间当月开始时间
-- mday 指定当月的第几天,从1开始
-- 返回日期table:{year:xxxx, month(1-12), day(1-31), hour(0-23), min(0-59), sec(0-61), wday(1-7,星期日=1), yday(本年天数编号}
function dtGetMonthStartDate(dttime, mday)
    dttime = dttime or os.time()
    mday = mday or 1
    local d1 = os.date("*t", dttime)
    d1.day = mday
    d1.hour = 0
    d1.min = 0
    d1.sec = 0

    return d1
end

-- [Comment]
-- 获取时间戳给定时间当月结束时间
-- 返回日期table:{year:xxxx, month(1-12), day(1-31), hour(0-23), min(0-59), sec(0-61), wday(1-7,星期日=1), yday(本年天数编号}
function dtGetMonthEndDate(dttime)
    dttime = dttime or os.time()

    local monthdays = dtGetDayAmountOfMonth(dttime)

    local d1 = os.date("*t", dttime)
    d1.day = monthdays
    d1.hour = 23
    d1.min = 59
    d1.sec = 59

    return d1
end


-- [Comment]
-- 日期相加, 返回用于可读性的date表
function dtDateAdd(date1, date2)
    local d1 = { year = date1.year, month = date1.month, day = date1.day, hour = date1.hour, min = date1.min, sec = date1.sec, wday = date1.wday, yday = date1.yday, isdst = date1.isdst }
    local d2 = { year = date2.year, month = date2.month, day = date2.day, hour = date2.hour, min = date2.min, sec = date2.sec, wday = date2.wday, yday = date2.yday, isdst = date2.isdst }
    local carry, res = false, { }

    if not d1['yday'] then
        local t1 = os.time(d1)
        if not t1 then
            -- 时间小于1970等无效情况, 视为差值
        else
            d1 = os.date("*t", t1)
        end
    end
    if not d2['yday'] then
        local t2 = os.time(d2)
        if not t2 then
            -- 时间小于1970等无效情况, 视为差值
        else
            d2 = os.date("*t", t2)
        end
    end

    local dayMax = os.date("*t", os.time( { year = d1.year, month = d1.month + 1, day = 0 })).day
    local colMax = { 60, 60, 24, dayMax, 12, 99999999, 366 }

    d2.hour = d2.hour -(d2.isdst and 1 or 0) +(d1.isdst and 1 or 0)

    for i, v in ipairs( { 'sec', 'min', 'hour', 'day', 'month', 'year', 'yday' }) do
        if not d1[v] then
            res[v] = d2[v] +(carry and 1 or 0)
        elseif not d2[v] then
            res[v] = d1[v] +(carry and 1 or 0)
        else
            res[v] = d2[v] + d1[v] +(carry and 1 or 0)
        end

        carry = res[v] >= colMax[i]
        if carry then
            res[v] = res[v] - colMax[i]
        end
    end

    return res
end

-- [Comment]
-- 计算两个date表的差值, 返回date表
-- 由于闰年以及每月天数不同,返回的值仅作为可读性需求提供
function dtDateDiff(date2, date1)

    local d1 = { year = date1.year, month = date1.month, day = date1.day, hour = date1.hour, min = date1.min, sec = date1.sec, wday = date1.wday, yday = date1.yday, isdst = date1.isdst }
    local d2 = { year = date2.year, month = date2.month, day = date2.day, hour = date2.hour, min = date2.min, sec = date2.sec, wday = date2.wday, yday = date2.yday, isdst = date2.isdst }
    local carry, diff = false, { }

    if not d1['yday'] then
        local t1 = os.time(d1)
        if not t1 then
            -- 时间小于1970等无效情况, 视为差值
        else
            d1 = os.date("*t", t1)
        end
    end
    if not d2['yday'] then
        local t2 = os.time(d2)
        if not t2 then
            -- 时间小于1970等无效情况, 视为差值
        else
            d2 = os.date("*t", t2)
        end
    end

    local dayMax = os.date("*t", os.time( { year = d1.year, month = d1.month + 1, day = 0 })).day
    local colMax = { 60, 60, 24, dayMax, 12, 0, 366 }

    d2.hour = d2.hour -(d2.isdst and 1 or 0) +(d1.isdst and 1 or 0)

    for i, v in ipairs( { 'sec', 'min', 'hour', 'day', 'month', 'year', 'yday' }) do
        diff[v] = d2[v] - d1[v] +(carry and -1 or 0)
        carry = diff[v] < 0
        if carry then
            diff[v] = diff[v] + colMax[i]
        end
    end

    return diff
end

-- [Comment]
-- 从datediff表转换为秒
function dtDateDiffToSecond(datediff)
    local sec = 0
    if datediff.year and datediff.year ~= 0 then
        if datediff.year % 400 == 0 or datediff.year % 4 == 0 and datediff.year % 100 ~= 0 then
            sec = sec + datediff.year * 366 * 24 * 3600
        else
            sec = sec + datediff.year * 365 * 24 * 3600
        end
    end

    if datediff.yday and datediff.yday ~= 0 then
        sec = sec + datediff.yday * 24 * 3600
    end

    if datediff.hour and datediff.hour ~= 0 then
        sec = sec + datediff.hour * 3600
    end

    if datediff.min and datediff.min ~= 0 then
        sec = sec + datediff.min * 60
    end

    if datediff.sec and datediff.sec ~= 0 then
        sec = sec + datediff.sec
    end

end



---------------------------------------------------------------------------------------------------------------------------
---农历计算
--天干名称
local tianGan = {"甲","乙","丙","丁","戊","己","庚","辛","壬","癸"}
--地支名称
local diZhi = {"子","丑","寅","卯","辰","巳","午", "未","申","酉","戌","亥"}
--属相名称
local shengXiao = {"鼠","牛","虎","兔","龙","蛇", "马","羊","猴","鸡","狗","猪"}
--农历日期名
local lunarDayShuXu = {"初一","初二","初三","初四","初五","初六","初七","初八","初九","初十",
						"十一","十二","十三","十四","十五","十六","十七","十八","十九","二十",
						"廿一","廿二","廿三","廿四","廿五","廿六","廿七","廿八","廿九","三十"}
--农历月份名
local lunarMonthShuXu = {"正","二","三","四","五","六", "七","八","九","十","冬","腊"}

local daysToMonth365= {0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334}
local daysToMonth366= {0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335}

--[[dateLunarInfo说明：
自1901年起，至2100年每年的农历信息，与万年历核对完成
每年第1个数字为闰月月份
每年第2、3个数字为当年春节所在的阳历月份和日期
每年第4个数字为当年中对应月分的大小进，左边起为1月，往后依次为2月，3月，4月，。。。]]
local BEGIN_YEAR = 1901
local NUMBER_YEAR = 199
local MAX_YEAR = 3000
local dateLunarInfo = {
    { 0, 2, 19, 19168 }, { 0, 2, 8, 42352 }, { 5, 1, 29, 21096 }, { 0, 2, 16, 53856 }, { 0, 2, 4, 55632 }, { 4, 1, 25, 27304 },
    { 0, 2, 13, 22176 }, { 0, 2, 2, 39632 }, { 2, 1, 22, 19176 }, { 0, 2, 10, 19168 }, { 6, 1, 30, 42200 }, { 0, 2, 18, 42192 },
    { 0, 2, 6, 53840 }, { 5, 1, 26, 54568 }, { 0, 2, 14, 46400 }, { 0, 2, 3, 54944 }, { 2, 1, 23, 38608 }, { 0, 2, 11, 38320 },
    { 7, 2, 1, 18872 }, { 0, 2, 20, 18800 }, { 0, 2, 8, 42160 }, { 5, 1, 28, 45656 }, { 0, 2, 16, 27216 }, { 0, 2, 5, 27968 },
    { 4, 1, 24, 44456 }, { 0, 2, 13, 11104 }, { 0, 2, 2, 38256 }, { 2, 1, 23, 18808 }, { 0, 2, 10, 18800 }, { 6, 1, 30, 25776 },
    { 0, 2, 17, 54432 }, { 0, 2, 6, 59984 }, { 5, 1, 26, 27976 }, { 0, 2, 14, 23248 }, { 0, 2, 4, 11104 }, { 3, 1, 24, 37744 },
    { 0, 2, 11, 37600 }, { 7, 1, 31, 51560 }, { 0, 2, 19, 51536 }, { 0, 2, 8, 54432 }, { 6, 1, 27, 55888 }, { 0, 2, 15, 46416 },
    { 0, 2, 5,  22176 }, { 4, 1, 25, 43736 }, { 0, 2, 13, 9680 }, { 0, 2, 2, 37584 }, { 2, 1, 22, 51544 }, { 0, 2, 10, 43344 },
    { 7, 1, 29, 46248 }, { 0, 2, 17, 27808 }, { 0, 2, 6, 46416 }, { 5, 1, 27, 21928 }, { 0, 2, 14, 19872 }, { 0, 2, 3, 42416 },
    { 3, 1, 24, 21176 }, { 0, 2, 12, 21168 }, { 8, 1, 31, 43344 }, { 0, 2, 18, 59728 }, { 0, 2, 8, 27296 }, { 6, 1, 28, 44368 },
    { 0, 2, 15, 43856 }, { 0, 2, 5, 19296 }, { 4, 1, 25, 42352 }, { 0, 2, 13, 42352 }, { 0, 2, 2, 21088 }, { 3, 1, 21, 59696 },
    { 0, 2, 9,  55632 }, { 7, 1, 30, 23208 }, { 0, 2, 17, 22176 }, { 0, 2, 6, 38608 }, { 5, 1, 27, 19176 }, { 0, 2, 15, 19152 },
    { 0, 2, 3,  42192 }, { 4, 1, 23, 53864 }, { 0, 2, 11, 53840 }, { 8, 1, 31, 54568 }, { 0, 2, 18, 46400 }, { 0, 2, 7, 46752 },
    { 6, 1, 28, 38608 }, { 0, 2, 16, 38320 }, { 0, 2, 5, 18864 }, { 4, 1, 25, 42168 }, { 0, 2, 13, 42160 }, { 10, 2, 2, 45656 },
    { 0, 2, 20, 27216 }, { 0, 2, 9, 27968 }, { 6, 1, 29, 44448 }, { 0, 2, 17, 43872 }, { 0, 2, 6, 38256 }, { 5, 1, 27, 18808 },
    { 0, 2, 15, 18800 }, { 0, 2, 4, 25776 }, { 3, 1, 23, 27216 }, { 0, 2, 10, 59984 }, { 8, 1, 31, 27432 }, { 0, 2, 19, 23232 },
    { 0, 2, 7, 43872 }, { 5, 1, 28, 37736 }, { 0, 2, 16, 37600 }, { 0, 2, 5, 51552 }, { 4, 1, 24, 54440 }, { 0, 2, 12, 54432 },
    { 0, 2, 1, 55888 }, { 2, 1, 22, 23208 }, { 0, 2, 9, 22176 }, { 7, 1, 29, 43736 }, { 0, 2, 18, 9680 }, { 0, 2, 7, 37584 },
    { 5, 1, 26, 51544 }, { 0, 2, 14, 43344 }, { 0, 2, 3, 46240 }, { 4, 1, 23, 46416 }, { 0, 2, 10, 44368 }, { 9, 1, 31, 21928 },
    { 0, 2, 19, 19360 }, { 0, 2, 8, 42416 }, { 6, 1, 28, 21176 }, { 0, 2, 16, 21168 }, { 0, 2, 5, 43312 }, { 4, 1, 25, 29864 },
    { 0, 2, 12, 27296 }, { 0, 2, 1, 44368 }, { 2, 1, 22, 19880 }, { 0, 2, 10, 19296 }, { 6, 1, 29, 42352 }, { 0, 2, 17, 42208 },
    { 0, 2, 6,  53856 }, { 5, 1, 26, 59696 }, { 0, 2, 13, 54576 }, { 0, 2, 3, 23200 }, { 3, 1, 23, 27472 }, { 0, 2, 11, 38608 },
    { 11, 1, 31, 19176 }, { 0, 2, 19, 19152 }, { 0, 2, 8, 42192 }, { 6, 1, 28, 53848 }, { 0, 2, 15, 53840 }, { 0, 2, 4, 54560 },
    { 5,  1, 24, 55968 }, { 0, 2, 12, 46496 }, { 0, 2, 1, 22224 }, { 2, 1, 22, 19160 }, { 0, 2, 10, 18864 }, { 7, 1, 30, 42168 },
    { 0, 2, 17, 42160 }, { 0, 2, 6, 43600 }, { 5, 1, 26, 46376 }, { 0, 2, 14, 27936 }, { 0, 2, 2, 44448 }, { 3, 1, 23, 21936 },
    { 0, 2, 11, 37744 }, { 8, 2, 1, 18808 }, { 0, 2, 19, 18800 }, { 0, 2, 8, 25776 }, { 6, 1, 28, 27216 }, { 0, 2, 15, 59984 },
    { 0, 2, 4,  27424 }, { 4, 1, 24, 43872 }, { 0, 2, 12, 43744 }, { 0, 2, 2, 37600 }, { 3, 1, 21, 51568 }, { 0, 2, 9, 51552 },
    { 7, 1, 29, 54440 }, { 0, 2, 17, 54432 }, { 0, 2, 5, 55888 }, { 5, 1, 26, 23208 }, { 0, 2, 14, 22176 }, { 0, 2, 3, 42704 },
    { 4, 1, 23, 21224 }, { 0, 2, 11, 21200 }, { 8, 1, 31, 43352 }, { 0, 2, 19, 43344 }, { 0, 2, 7, 46240 }, { 6, 1, 27, 46416 },
    { 0, 2, 15, 44368 }, { 0, 2, 5, 21920 }, { 4, 1, 24, 42448 }, { 0, 2, 12, 42416 }, { 0, 2, 2, 21168 }, { 3, 1, 22, 43320 },
    { 0, 2, 9, 26928 }, { 7, 1, 29, 29336 }, { 0, 2, 17, 27296 }, { 0, 2, 6, 44368 }, { 5, 1, 26, 19880 }, { 0, 2, 14, 19296 },
    { 0, 2, 3, 42352 }, { 4, 1, 24, 21104 }, { 0, 2, 10, 53856 }, { 8, 1, 30, 59696 }, { 0, 2, 18, 54560 }, { 0, 2, 7, 55968 },
    { 6, 1, 27, 27472 }, { 0, 2, 15, 22224 }, { 0, 2, 5, 19168 }, { 4, 1, 25, 42216 }, { 0, 2, 12, 42192 }, { 0, 2, 1, 53584 },
    { 2, 1, 21, 55592 }, { 0, 2, 9, 54560 }
}

--公历闰年
function IsLeapYear(year)
    if year % 4 ~= 0 then
        return 0
    end
    if year % 100 ~= 0 then
        return 1
    end
    if year % 400 == 0 then
        return 1
    end
    return 0
end

local function getYearInfo(lunarYear, index)
    if lunarYear < BEGIN_YEAR or lunarYear > BEGIN_YEAR + NUMBER_YEAR - 1 then
        return
    end
    return dateLunarInfo[lunarYear - BEGIN_YEAR + 1][index]
end


--计算指定公历日期是这一年中的第几天
local function daysCntInSolar(solarYear, solarMonth, solarDay)
    local daysToMonth = daysToMonth365
    if solarYear % 4 == 0 then
        if solarYear % 100 ~= 0 then
            daysToMonth = daysToMonth366
        end
        if solarYear % 400 == 0 then
            daysToMonth = daysToMonth366
        end
    end
    return daysToMonth[solarMonth] + solarDay
end


--阳历转阴历
-- 返回: lunarDate
-- local lunarDate = {
--     solarYear = 2013,
--     solarMonth = 2,
--     solarDay = 9,
--     solarDate = "20130209",
--     leap = 0,
--     daysToBase = 4782,          -- 相对于2000年1月7日的天数
--     year = 2012,                -- 农历年
--     month = 12,                 -- 农历月
--     day = 29,                   -- 农历日
--     year_ganZhi = "壬辰",
--     year_shengXiao = "龙",
--     month_shuXu = "腊",
--     day_shuXu = "廿九",
--     day_ganZhi = "丙午",
--     lunarDate_1 = "壬辰年腊月廿九日",
--     lunarDate_2 = "龙年腊月廿九日",
--     lunarDate_3 = "壬辰年腊月丙午日",
--     lunarDate_4 = "壬辰(龙)年腊月廿九日",
-- }
function Date2Lunar(solarYear, solarMonth, solarDay)
    local lunarDate = {}
    lunarDate.solarYear = solarYear
    lunarDate.solarMonth = solarMonth
    lunarDate.solarDay = solarDay
    lunarDate.solarDate = ''
    lunarDate.year = solarYear
    lunarDate.month = 0
    lunarDate.day = 0
    lunarDate.leap = false
    lunarDate.year_shengXiao = ''
    lunarDate.year_ganZhi = ''
    lunarDate.month_shuXu = ''
    lunarDate.day_shuXu = ''
    lunarDate.day_ganZhi = ''
    lunarDate.lunarDate_1 = ''
    lunarDate.lunarDate_2 = ''
    lunarDate.lunarDate_3 = ''
    lunarDate.lunarDate_4 = ''

    --确定当前日期相对于2000年1月7日的天数，此日期是一个甲子记日的起点
    local tBase = os.time({ year = 2000, month = 1, day = 7 })
    local tThisDay = os.time({ year = math.min(solarYear, MAX_YEAR), month = solarMonth, day = solarDay })
    lunarDate.daysToBase = math.floor((tThisDay - tBase) / 86400)

    lunarDate.solarDate = os.date("%Y%m%d", tThisDay)

    if lunarDate.solarYear <= BEGIN_YEAR or lunarDate.solarYear > BEGIN_YEAR + NUMBER_YEAR - 1 then
        return lunarDate
    end

    --春节的公历日期
    local solarMontSpring = getYearInfo(lunarDate.year, 2)
    local solarDaySpring = getYearInfo(lunarDate.year, 3)

    --计算这天是公历年的第几天
    local daysCntInSolarThisDate = daysCntInSolar(solarYear, solarMonth, solarDay)
    --计算春节是公历年的第几天
    local daysCntInSolarSprint = daysCntInSolar(solarYear, solarMontSpring, solarDaySpring)
    --计算这天是农历年的第几天
    local daysCntInLunarThisDate = daysCntInSolarThisDate - daysCntInSolarSprint + 1

    if daysCntInLunarThisDate <= 0 then
        --如果 daysCntInLunarThisDate 为负，说明指定的日期在农历中位于上一年的年度内
        lunarDate.year = lunarDate.year - 1
        if lunarDate.year <= BEGIN_YEAR then
            return lunarDate
        end

        --重新确定农历春节所在的公历日期
        solarMontSpring = getYearInfo(lunarDate.year, 2)
        solarDaySpring = getYearInfo(lunarDate.year, 3)

        --重新计算上一年春节是第几天
        daysCntInSolarSprint = daysCntInSolar(solarYear - 1, solarMontSpring, solarDaySpring)
        --计算上一年共几天
        local daysCntInSolarTotal = daysCntInSolar(solarYear - 1, 12, 31)
        --上一年农历年的第几天
        daysCntInLunarThisDate = daysCntInSolarThisDate + daysCntInSolarTotal - daysCntInSolarSprint + 1
    end

    --开始计算月份
    local lunarMonth = 1
    local lunarDaysCntInMonth = 0
    --dec 32768 =bin 1000000000000000，一个掩码
    local bitMask = 32768
    --大小月份的flg数据
    local lunarMonth30Flg = getYearInfo(lunarDate.year, 4)
    --从正月开始，每个月进行以下计算
    while lunarMonth <= 13 do
        --计算这个月总共有多少天
        if BitAnd(lunarMonth30Flg, bitMask) ~= 0 then
            lunarDaysCntInMonth = 30
        else
            lunarDaysCntInMonth = 29
        end

        --检查thisDate距离这个月初一的天数是否小于这个月的总天数
        if daysCntInLunarThisDate <= lunarDaysCntInMonth then
            lunarDate.month = lunarMonth
            lunarDate.day = daysCntInLunarThisDate
            break
        else
            --如果剩余天数还大于这个月的天数，则继续往下个月算
            daysCntInLunarThisDate = daysCntInLunarThisDate - lunarDaysCntInMonth
            lunarMonth = lunarMonth + 1
            --掩码除2，相当于bit位向右移动一位
            bitMask = bitMask / 2
        end
    end

    --闰月所在的月份
    local leapMontInLunar = getYearInfo(lunarDate.year, 1)
    --确定闰月信息
    if leapMontInLunar > 0 and leapMontInLunar < lunarDate.month then
        --如果存在闰月，且闰在前面判断的月份前面，则农历月份需要减 1 处理
        lunarDate.month = lunarDate.month - 1

        if leapMontInLunar == lunarDate.month then
            --如果恰好闰在这个月，则把闰月标记位置
            lunarDate.leap = true
        end
    end

    --确定年份的生肖
    lunarDate.year_shengXiao = shengXiao[(((lunarDate.year - 4) % 60) % 12) + 1]
    --确定年份的干支
    lunarDate.year_ganZhi = tianGan[(((lunarDate.year - 4) % 60) % 10) + 1] .. diZhi[(((lunarDate.year - 4) % 60) % 12) + 1]
    --确定月份的数序
    lunarDate.month_shuXu = (lunarDate.leap and '闰' or '') .. lunarMonthShuXu[lunarDate.month]
    --确定月份的干支，暂不支持计算
    --lunarDate.month_ganZhi = ''
    --确定日期的数序
    lunarDate.day_shuXu = lunarDayShuXu[lunarDate.day]
    --确定日期的干支
    lunarDate.day_ganZhi = tianGan[(((lunarDate.daysToBase) % 60) % 10) + 1] .. diZhi[(((lunarDate.daysToBase) % 60) % 12) + 1]

    --提供国标第一类计年表示格式
    lunarDate.lunarDate_1 = lunarDate.year_ganZhi .. '年' .. lunarDate.month_shuXu .. '月' .. lunarDate.day_shuXu .. '日'
    --提供国标第二类计年表示格式
    lunarDate.lunarDate_2 = lunarDate.year_shengXiao .. '年' .. lunarDate.month_shuXu .. '月' .. lunarDate.day_shuXu .. '日'
    --提供国标第三类计年表示格式
    lunarDate.lunarDate_3 = lunarDate.year_ganZhi .. '年' .. lunarDate.month_shuXu .. '月' .. lunarDate.day_ganZhi .. '日'
    --提供非国标的第四类计年表示格式
    lunarDate.lunarDate_4 = lunarDate.year_ganZhi .. '(' .. lunarDate.year_shengXiao .. ')年' .. lunarDate.month_shuXu .. '月' .. lunarDate.day_shuXu .. '日'

    return lunarDate
end
