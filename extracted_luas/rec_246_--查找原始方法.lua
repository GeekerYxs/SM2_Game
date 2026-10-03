local model = {}

function model:new(ctrl)
    local o = {Ctrl=ctrl}
    setmetatable(o,self)
   return o
end

model.__index = function(t, key)
    -- 查找原始方法
    local field = rawget(model, key)

    if field ~= nil then
        return field
    end

    -- 如果是C函数，特殊处理
    local ctrl = t.Ctrl
    if type(ctrl) == 'userdata' then
        local success, ctrlField = pcall(function()
            return ctrl[key]
        end)

        if not success then
            return nil
        end

        if type(ctrlField) == 'function' then
            return function(self, ...)
                return ctrlField(ctrl, ...)
            end
        else
            return ctrlField
        end
    end

    return nil
end

return model