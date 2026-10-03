--region *.lua
--Date
--此文件由[BabeLua]插件自动生成

-- 行动队列全局表
QueueForActions = {}

-- 清空行动列表
function ClearActions()

    QueueForActions = {}
end

-- 添加新行动
-- 每个行动由两个函数组成, 状态检查函数
-- 仅当init状态时会自动调用beginAction函数, finish状态删除当前行动
function AddAction(funcCheckState)

    if not funcCheckState then
        local arg1 = tostring( debug.getlocal(1, 1))
        Error( string.format('AddAction(%s) 参数%s=nil', arg1, arg1 ))
        return
    end

    local act = { check = funcCheckState }

    QueueForActions[#QueueForActions + 1] = act

end


-- 行动队列处理
function ProcessActionQueue()

    local act = QueueForActions[1]

    if act then

        local state = act.check()
        if state then
            -- 如果已完成, 则删除当前行动
            table.remove(QueueForActions, 1)
        end
    end
end

--endregion
