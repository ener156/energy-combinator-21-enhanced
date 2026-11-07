local data_utility = {}

function data_utility.times(n,v)
    local r = {} for i = 1,n do r[i] = v end return r
end

function data_utility.deepmerge(t,o)
    for k,v in pairs(o) do
        if type(v) == 'table' and type(t[k]) == 'table' then
            v = data_utility.deepmerge(t[k], v)
        end
        t[k] = v
    end
    return t
end

function data_utility.set(t,k,v) t[k] = v return t end

function data_utility.rm_prop(key, entity)
    return data_utility.set(entity,key,nil)
end

function data_utility.rm_icon(entity)
    return data_utility.rm_prop('icon', data_utility.rm_prop('icon_size', entity))
end

function data_utility.iter_layers(entity, f)
    for _, sprite in pairs(entity.sprites or {}) do
        if sprite.layers then
            data_utility.iter_layers({sprites=sprite.layers}, f)
        else
            f(sprite)
            if sprite.hr_version then
                f(sprite.hr_version)
            end
        end
    end
    return entity
end

function data_utility.tint_hint(entity, tint)
    return data_utility.iter_layers(entity, function (sprite)
        sprite.tint = tint
    end)
end

function data_utility.rescale(entity, scale)
    for _,offset in pairs(entity.activity_led_light_offsets or {}) do
        for k,v in pairs(offset) do
            offset[k] = v * scale
        end
    end
    for _,connection in pairs(entity.circuit_wire_connection_points or {}) do
        for _,point in pairs(connection) do
            for _,vector in pairs(point) do
                for k,v in pairs(vector) do
                    vector[k] = v * scale
                end
            end
        end
    end
    data_utility.iter_layers({sprites={{layers=entity.activity_led_sprites}}}, function (sprite)
        sprite.scale = (sprite.scale or 1) * scale
        for k,v in pairs(sprite.shift or {}) do
            sprite.shift[k] = v * scale
        end
    end)
    return data_utility.iter_layers(entity, function (sprite)
        sprite.scale = (sprite.scale or 1) * scale
    end)
end

return data_utility
