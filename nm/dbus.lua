local dbus = require("dbus_proxy")

local nm_dbus_proxy = dbus.Proxy:new({
    bus = dbus.Bus.SYSTEM,
    name = "org.freedesktop.NetworkManager",
    interface = "org.freedesktop.NetworkManager",
    path = "/org/freedesktop/NetworkManager",
})
