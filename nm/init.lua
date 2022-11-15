local nm = require("lgi").NM
local client = nm.Client.new()
local devices = client:get_devices()

local dbus = require(tostring(...):match(".*nm_applet") .. ".nm.dbus")

return {
    nm = nm,
    client = client,
    devices = devices,
}
