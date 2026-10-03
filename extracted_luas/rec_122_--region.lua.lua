--region *.lua
--Date
--此文件由[BabeLua]插件自动生成
-- 数学实用函数

function getAngleByPos(x1, y1, x2, y2)

    local x,y = x2 - x1, y2 - y1
    local r = math.atan2(y, x) * 180 / math.pi
    if r < 0 then
        r = 360 + r
    end
    return r
end
function getAngleByPoint(p1, p2)
    return getAngleByPos(p1.x, p1.y, p2.x, p2.y)
end


-- 计算从(x1,y1)到(x2,y2)向量的方向(x轴逆时针计算)
function getDirByPos(x1, y1, x2, y2)
    local ang = getAngleByPos(x1, y1, x2, y2)

    local Ang1In16 = 22.5
    local ret = "up"
    
    if ang > 360 - Ang1In16 * 1 then
        ret = "right"
    elseif ang > 360 - Ang1In16 * 3 then
        ret = "rightup"
    elseif ang > 360 - Ang1In16 * 5 then
        ret = "up"
    elseif ang > 360 - Ang1In16 * 7 then
        ret = "leftup"
    elseif ang > 360 - Ang1In16 * 9 then
        ret = "left"
    elseif ang > 360 - Ang1In16 * 11 then
        ret = "leftdown"
    elseif ang > 360 - Ang1In16 * 13 then
        ret = "down"
    elseif ang > 360 - Ang1In16 * 15 then
        ret = "rightdown"
    else
        ret = "right"
    end

    return ret
end

-- 计算从p1到p2向量的方向(x轴逆时针计算)
function getDirByPoint(p1, p2)
    return getDirByPos(p1.x, p1.y, p2.x, p2.y)
end


-- 获取指定数num在二进制位bit上的值
-- bit: 0 ~ 63
-- 若num为负数,指定位有值时返回-1, 正数则返回1
function getBitValue(num, bit)
    -- k = num >> bit
    local p = math.pow(2, bit)
    local k = math.floor(num / p)
    -- res = k % 2
    local val = math.fmod(k, 2)

    return val
end


-- 按位与
function BitAnd(a, b)
    local p, c = 1, 0
    while a > 0 and b > 0 do
        local ra, rb = a % 2, b % 2
        if ra + rb > 1 then c = c + p end
        a, b, p = (a - ra) / 2, (b - rb) / 2, p * 2
    end
    return c
end

-- 按位或
function BitOr(a, b)
    local p, c = 1, 0
    while a + b > 0 do
        local ra, rb = a % 2, b % 2
        if ra + rb > 0 then c = c + p end
        a, b, p = (a - ra) / 2, (b - rb) / 2, p * 2
    end
    return c
end

-- 按位非
function BitNot(a)
    local p, c = 1, 0
    local count = 32

    for i = 1, count do
        local r = a % 2
        if r == 0 then c = c + p end
        a, p = (a - r) / 2, p * 2
    end

    return c
end

-- 按位非, 值作为有符号数处理
function BitNotAsInt(a)
    local p, c = 1, 0
    local count = 32
    if a < 0 then
        for i = 1, count do
            local r = a % 2
            if r == 0 then c = c + p end
            a, p = (a - r) / 2, p * 2
        end
    else
        for i = 1, count do
            local r = a % 2
            if r == 1 then c = c + p end
            a, p = (a - r) / 2, p * 2
        end
        c = -(c + 1)
    end
    return c

end

-- 按位异或
function BitXor(a, b)
    local p, c = 1, 0
    while a + b > 0 do
        local ra, rb = a % 2, b % 2
        if ra ~= rb then c = c + p end
        a, b, p = (a - ra) / 2, (b - rb) / 2, p * 2
    end
    return c

end

----------------------------------------------------------------------------------------------------------
--  函数：GetRandNum(maxnum[,b])
--  描述：取随机数
--  返回值：从b或1（b省略时）到maxnum之间的数
--  参数：maxnum 一个数
-- 			b      与maxnum组成范围
--function GetRandNum(maxnum, b)
--    RAND_NEXT_NUM = math.fmod(RAND_NEXT_NUM * 214013 + 2531011, 32768)
--    local minnum = b or 1
--    if maxnum < minnum then
--        minnum = maxnum
--        maxnum = b or 1
--    end
--    return math.fmod(RAND_NEXT_NUM,(maxnum - minnum + 1)) + minnum
--end 

RAND_NEXT_NUM = os.time()   -- 随机种子初始化

function GetRandNum(maxnum, b)

    RAND_NEXT_NUM = math.fmod(RAND_NEXT_NUM * 214013 + 2531011, 4294967296)
    local m = math.floor(RAND_NEXT_NUM / 65536)
    local minnum = b or 1
    if maxnum < minnum then
        minnum = maxnum
        maxnum = b or 1
    end
    return math.fmod(m,(maxnum - minnum + 1)) + minnum

end
----------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------
--  函数：GetRandNumByWeightCoef(tbl)
--  描述：从表tbl中按权重系数(cof)的值随机获取一个编号
--  返回值：表中一个索引编号, 表中索引必须连续

function GetRandNumByWeightCoef(tbl)
    local Coef = 0
    local num = 0
    for c, v in pairs(tbl) do
        if type(v) == "table" then
            Coef = Coef + v.cof
            num = num + 1
        end
    end

    if Coef == 0 and num > 0 then
        local callfunc = callstack(2)
        Error("GetRandNumByWeightCoef() cof 必须大于0, callstack:\n" .. callfunc)
        return nil
    end

    local Idx
    local RandNum = GetRandNum(Coef)

    for c, v in pairs(tbl) do
        if type(v) == "table" then
            if RandNum <= v.cof then
                Idx = c
                break
            end
            RandNum = RandNum - v.cof
        end
    end

    return Idx
end
----------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------
--  函数：RandSelectInArrayList(tbl)
-- 不重复的随机获取列表数组中的一项列表
function RandSelectInArrayList(arrayList, reinit)
    local arraySize = #(arrayList)
    local RandNum = GetRandNum(arraySize)

    if( type(arrayList[RandNum]) == "table") then
        if reinit then
            for c, v in pairs(arrayList) do
                if type(v) == "table" then
                    v.inuse = nil
                end
            end
        end

        for i = 1, arraySize do
            if arrayList[RandNum].inuse then
                RandNum = math.fmod(RandNum, arraySize) + 1
            else
                break
            end
        end
        -- 全部用完则重置
        if arrayList[RandNum].inuse then
            for i = 1, arraySize do
                arrayList[i].inuse = nil
            end
            RandNum = GetRandNum(arraySize)
        end
        arrayList[RandNum].inuse = true
    end
    return arrayList[RandNum], RandNum
end

----------------------------------------------------------------------------------------------------------
-- 随机排序表
-- bysort:使用table.sort方式排序,比较大小时随机
function Shuffle(arrayList, bysort)
    if bysort then
        table.sort(t,function (a,b)
            return math.random(1,10) < 5
          end)
    else
        local len = #arrayList
        for i = 1, len do
            -- 生成一个 1 到 len 之间的随机索引
            local randIndex = math.random(1, len)
            -- 交换当前元素和随机索引处的元素
            arrayList[i], arrayList[randIndex] = arrayList[randIndex], arrayList[i]
        end
    end
end



--endregion
