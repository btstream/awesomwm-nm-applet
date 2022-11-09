local wifi = require("wifi")
local aps = wifi.get_wifi_list(false)
local active_ap = wifi.get_active_ap()

if active_ap then print(active_ap.ssid) end

for _, ap in ipairs(aps) do
    if ap.ssid == "" then
        goto continue
    end
    print(ap.ssid)
    ::continue::
end
