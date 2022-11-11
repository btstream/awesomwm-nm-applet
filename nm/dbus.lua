local dbus = require("dbus_proxy")
local Proxy = dbus.Proxy
local NM = require("lgi").NM

local DeviceTypes = {
    ETHERNET = 1,
    WIFI = 2,
}

local NM_DBUS = dbus.Proxy:new({
    bus = dbus.Bus.SYSTEM,
    name = "org.freedesktop.NetworkManager",
    interface = "org.freedesktop.NetworkManager",
    path = "/org/freedesktop/NetworkManager",
})

local function new_active_connection_proxy(path)
    return Proxy:new({
        bus = dbus.Bus.SYSTEM,
        name = "org.freedesktop.NetworkManager",
        interface = "org.freedesktop.NetworkManager.Connection.Active",
        path = path,
    })
end

local function new_device_proxy(path)
    return Proxy:new({
        bus = dbus.Bus.SYSTEM,
        name = "org.freedesktop.NetworkManager",
        interface = "org.freedesktop.NetworkManager.Device",
        path = path,
    })
end

local function new_wireless_device_proxy(path)
    return Proxy:new({
        bus = dbus.Bus.SYSTEM,
        name = "org.freedesktop.NetworkManager",
        interface = "org.freedesktop.NetworkManager.Device.Wireless",
        path = path,
    })
end

local function new_accesspoint_proxy(path)
    return Proxy:new({
        bus = dbus.Bus.SYSTEM,
        name = "org.freedesktop.NetworkManager",
        interface = "org.freedesktop.NetworkManager.AccessPoint",
        path = path,
    })
end

----------------------------------------------------------------------
--              Process Active Connection Information               --
----------------------------------------------------------------------
local active_access_points = {}
for _, path in ipairs(NM_DBUS.ActiveConnections) do
    local active_connection = new_active_connection_proxy(path)
    for _, j in ipairs(active_connection.Devices) do
        local device = new_device_proxy(j)
        if device.DeviceType == DeviceTypes.WIFI then
            device = new_wireless_device_proxy(j)
            local active_ap = new_accesspoint_proxy(device.ActiveAccessPoint)
            table.insert(active_access_points, active_ap)
        end
    end
end

-- local mainloop = (require("lgi").GLib.MainLoop())
-- mainloop:run()
