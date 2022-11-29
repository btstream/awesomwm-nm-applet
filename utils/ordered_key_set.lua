local M = {}
M.__index = M

function M:add(element, overwrite)
    -- print(require("inspect")(element))
    local key = self.key_func(element)
    if overwrite then self:remove(element) end
    if not self._private.key[key] then
        table.insert(self._private.data, element)
        self._private.key[key] = #self._private.data
    end
end

function M:remove(element)
    local key = self.key_func(element)
    local removed = false
    if self._private.key[key] then
        table.remove(self._private.data, key)
        self._private.key[key] = nil
        removed = true
    end

    if removed then
        for i, e in ipairs(self._private.data) do
            self._private.key[self.key_func(e)] = i
        end
    end
end

function M:remove_with_key(key)
    local index = self._private.key[key]
    local removed = false
    if index then
        table.remove(self._private.data, index)
        removed = true
    end

    if removed then
        for i, element in ipairs(self._private.data) do
            self._private.key[self.key_func(element)] = i
        end
    end
end

function M:elements()
    local ret = {}
    for _, v in ipairs(self._private.data) do
        table.insert(ret, v)
    end
    return ret
end

function M:has(element) return self._private.key[self.key_func(element)] end

function M:get(key) return self._private.data[self._private.key[key]] end

function M:reset()
    self._private.key = {}
    self._private.data = {}
end

local function new(key_func)
    local d = {
        key_func = key_func == nil and tostring or key_func,
        _private = {
            data = {},
            key = {},
        },
    }

    setmetatable(d, M)
    return d
end

return {
    new = new,
}
