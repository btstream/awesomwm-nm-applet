local M = {}
M.__index = M

function M:add(element, overwrite)
    local key = self.hash_func(element)
    if overwrite then self:remove(element) end
    if not self._private.key[key] then
        table.insert(self._private.data, element)
        self._private.key[key] = true
    end
end

function M:remove(element)
    local key = self.hash_func(element)
    if self._private.key[key] then
        for index, value in ipairs(self._private.data) do
            if self.hash_func(element) == self.hash_func(value) then
                table.remove(self._private.data, index)
            end
        end
        self._private.key[key] = nil
    end
end

function M:elements() return self._private.data end

function M:has(element) return self._private.key[self.hash_func(element)] end

function M:reset()
    self._private.key = {}
    self._private.data = {}
end

local function new(hash_func)
    local d = {
        hash_func = hash_func == nil and tostring or hash_func,
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
