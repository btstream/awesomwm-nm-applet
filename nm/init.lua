local gears = require("gears")

local nm = require("lgi").NM
local client = nm.Client.new()
local devices = client:get_devices()

-- local dbus = require(tostring(...):match(".*nm_applet") .. ".nm.dbus")

local M = gears.object()
gears.table.crush(M, {
    nm = nm,
    client = client,
    devices = devices,
    _private = {
        primary_connection = client:get_primary_connection(),
        state = "UNKNOWN",
    },
})

-- update connection state
client.on_notify["state"] = function()
    local state = client:get_state()
    M._private.state = state
    if state == "CONNECTED_SITE" or state == "CONNECTED_GLOBAL" then
        M._private.primary_connection = client:get_primary_connection()
    else
        M._private.primary_connection = nil
    end
    M:emit_signal("nm::state_changed", state)
end

function M:get_state() return M._private.state end

function M:get_primary_connection() return M._private.primary_connection end

return setmetatable({}, {
    __index = function(_, key)
        if key == "_private" then
            return nil
        else
            return M[key]
        end
    end,
})
