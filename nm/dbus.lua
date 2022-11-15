local gears = require("gears")
local inspect = require("inspect")
local dbus = require("dbus_proxy")
local Proxy = dbus.Proxy
local NM = require("lgi").NM

local DeviceTypes = {
    ETHERNET = 1,
    WIFI = 2,
}

local DeviceState = {
    UNKNOWN = 0, -- the device's state is unknown
    UNMANAGED = 10, -- the device is recognized, but not managed by NetworkManager
    UNAVAILABLE = 20, --the device is managed by NetworkManager,
    --but is not available for use. Reasons may include the wireless switched off,
    --missing firmware, no ethernet carrier, missing supplicant or modem manager, etc.
    DISCONNECTED = 30, -- the device can be activated,
    --but is currently idle and not connected to a network.
    PREPARE = 40, -- the device is preparing the connection to the network.
    -- This may include operations like changing the MAC address,
    -- setting physical link properties, and anything else required
    -- to connect to the requested network.
    CONFIG = 50, -- the device is connecting to the requested network.
    -- This may include operations like associating with the Wi-Fi AP,
    -- dialing the modem, connecting to the remote Bluetooth device, etc.
    NEED_AUTH = 60, -- the device requires more information to continue
    -- connecting to the requested network. This includes secrets like WiFi passphrases,
    -- login passwords, PIN codes, etc.
    IP_CONFIG = 70, -- the device is requesting IPv4 and/or IPv6 addresses
    -- and routing information from the network.
    IP_CHECK = 80, -- the device is checking whether further action
    -- is required for the requested network connection.
    -- This may include checking whether only local network access is available,
    -- whether a captive portal is blocking access to the Internet, etc.
    SECONDARIES = 90, -- the device is waiting for a secondary connection
    -- (like a VPN) which must activated before the device can be activated
    ACTIVATED = 100, -- the device has a network connection, either local or global.
    DEACTIVATING = 110, -- a disconnection from the current network connection
    -- was requested, and the device is cleaning up resources used for that connection.
    -- The network connection may still be valid.
    FAILED = 120, -- the device failed to connect to
    -- the requested network and is cleaning up the connection request
}

local function device_state_to_string(state)
    local device_state_to_string = {
        [0] = "Unknown",
        [10] = "Unmanaged",
        [20] = "Unavailable",
        [30] = "Disconnected",
        [40] = "Prepare",
        [50] = "Config",
        [60] = "Need Auth",
        [70] = "IP Config",
        [80] = "IP Check",
        [90] = "Secondaries",
        [100] = "Activated",
        [110] = "Deactivated",
        [120] = "Failed",
    }

    return device_state_to_string[state]
end

local nm_dbus_proxy = Proxy:new({
    bus = dbus.Bus.SYSTEM,
    name = "org.freedesktop.NetworkManager",
    interface = "org.freedesktop.NetworkManager",
    path = "/org/freedesktop/NetworkManager",
})

local nm_dbus_properties_proxy = Proxy:new({
    bus = dbus.Bus.SYSTEM,
    name = "org.freedesktop.NetworkManager",
    interface = "org.freedesktop.DBus.Properties",
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
local M = gears.object()

M.active_access_point = nil
M.active_wifi_device = nil

local function register_wifi_properties_signal(ap)
    print("Register signal of properties changed on active access point")
    local ap_properties_proxy = Proxy:new({
        bus = dbus.Bus.SYSTEM,
        name = "org.freedesktop.NetworkManager",
        interface = "org.freedesktop.DBus.Properties",
        path = ap.object_path,
    })
    ap_properties_proxy:connect_signal(
        function(_, _, properties)
            M:emit_signal("wifi::ap_properties_changed", properties)
        end,
        "PropertiesChanged"
    )
end

local function on_wifi_state_change(device, state, _, _)
    print(device_state_to_string(state))
    if state == DeviceState.DISCONNECTED then
        print("Device disconnected")
        M.active_access_point = nil
        M:emit_signal("wifi::disconnected", M.active_access_point)
        return
    end
    if state == DeviceState.ACTIVATED then
        print("device activated")
        local wifi_device = new_wireless_device_proxy(device.object_path)
        M.active_access_point =
            new_accesspoint_proxy(wifi_device.ActiveAccessPoint)
        register_wifi_properties_signal(M.active_access_point)
        M:emit_signal("wifi:activated", M.active_access_point)
    end
end

for _, p in ipairs(nm_dbus_proxy:GetDevices()) do
    local device = new_device_proxy(p)
    if device.DeviceType == DeviceTypes.WIFI then
        M.active_wifi_device = device
        M.active_wifi_device:connect_signal(
            on_wifi_state_change,
            "StateChanged"
        )
        local wifi_device = new_wireless_device_proxy(p)
        local active_ap = new_accesspoint_proxy(wifi_device.ActiveAccessPoint)
        M.active_access_point = active_ap
        register_wifi_properties_signal(active_ap)
    end
end

nm_dbus_properties_proxy:connect_signal(
    function(_, _, properties)
        print("NetworkManager PropertiesChanged", inspect(properties))
    end,
    "PropertiesChanged"
)

return M
