local gears = require("gears")
local inspect = require("inspect")
local nm = require(tostring(...):match(".*nm_applet") .. ".nm")
local dbus = require(tostring(...):match(".*nm_applet") .. ".nm.dbus")
-- local nm = require("nm")
local NM = nm.nm
local devs = nm.devices

----------------------------------------------------------------------
--           Util functions, all this function comme from           --
--                     NetworkManager examples                      --
----------------------------------------------------------------------
local function is_empty(t)
    local next = next
    if next(t) then
        return false
    else
        return true
    end
end

local function ssid_to_utf8(ap)
    local ssid = ""
    if type(ap.get_ssid) == "userdata" then
        ssid = ap:get_ssid()
    else
        ssid = ap.Ssid
    end
    if not ssid then return "" end
    return NM.utils_ssid_to_utf8(
        type(ap.get_ssid) == "userdata" and ssid:get_data() or ssid
    )
end

local function flags_to_string(flags)
    local str = ""
    -- if comes from dbus
    if type(flags) == "number" then
        if flags == 1 then
            str = str .. " " .. "PRIVACY"
        else
            str = "NONE"
        end
    else
        for flag, _ in pairs(flags) do
            str = str .. " " .. flag
        end
        if str == "" then str = "NONE" end
    end
    return (str:gsub("^%s", ""))
end

local function flags_to_security(flags, wpa_flags, rsn_flags)
    local str = ""

    -- if comes from dbus
    if type(flags) == "number" then
        if flags == 1 and wpa_flags == 0 and rsn_flags == 0 then
            str = str .. " WEP"
        end
        if wpa_flags ~= 0 then str = str .. " WPA1" end
        if not rsn_flags ~= 0 then str = str .. " WPA2" end
        if wpa_flags == 512 or rsn_flags == 512 then str = str .. " 802.1X" end
    else
        if flags["PRIVACY"] and is_empty(wpa_flags) and is_empty(rsn_flags) then
            str = str .. " WEP"
        end
        if not is_empty(wpa_flags) then str = str .. " WPA1" end
        if not is_empty(rsn_flags) then str = str .. " WPA2" end
        if wpa_flags["KEY_MGMT_802_1X"] or rsn_flags["KEY_MGMT_802_1X"] then
            str = str .. " 802.1X"
        end
    end
    return (str:gsub("^%s", ""))
end

local function parse_ap_info(ap)
    if ap == nil then return ap end

    local strength = type(ap.get_strength) == "userdata" and ap:get_strength()
        or ap.Strength
    local frequency = type(ap.get_frequency) == "userdata"
            and ap:get_frequency()
        or ap.Frequency
    local flags = type(ap.get_flags) == "userdata" and ap:get_flags()
        or ap.Flags
    local wpa_flags = type(ap.get_wpa_flags) == "userdata"
            and ap:get_wpa_flags()
        or ap.WpaFlags
    local rsn_flags = type(ap.get_rsn_flags) == "userdata"
            and ap:get_rsn_flags()
        or ap.RsnFlags
    -- remove extra NONE from the flags tables
    if type(flags) == "table" then flags["NONE"] = nil end
    if type(wpa_flags) == "table" then wpa_flags["NONE"] = nil end
    if type(rsn_flags) == "table" then rsn_flags["NONE"] = nil end
    return {
        ssid = ssid_to_utf8(ap),
        bssid = type(ap.get_bssid) == "userdata" and ap:get_bssid() or ap.Bssid,
        frequency = frequency,
        channel = NM.utils_wifi_freq_to_channel(frequency),
        mode = type(ap.get_mode) == "userdata" and ap:get_mode() or ap.Mode,
        flags = flags_to_string(flags),
        wpa_flags = flags_to_string(wpa_flags),
        security = flags_to_security(flags, wpa_flags, rsn_flags),
        strength = strength,
    }
end

----------------------------------------------------------------------
--            other helper function, does not come from             --
--                     NetworkManager examples                      --
----------------------------------------------------------------------

local function for_each_wifi_dev(callback)
    for _, dev in ipairs(devs) do
        if dev:get_device_type() == "WIFI" then
            if callback(dev) then break end
        end
    end
end

local dev_status = {}
local function get_scan_status(dev) return dev_status[dev:get_udi()] end

----------------------------------------------------------------------
--                           wifi modules                           --
----------------------------------------------------------------------

local M = gears.object()

dbus:connect_signal(
    "wifi::ap_properties_changed",
    function(_, properties) M:emit_signal("wifi::ap_properties_changed", properties) end
)

dbus:connect_signal(
    "wifi::activated",
    function() M:emit_signal("wifi::activated") end
)

dbus:connect_signal(
    "wifi::disconnected",
    function() M:emit_signal("wifi::disconnected") end
)

function M:get_active_ap()
    local ret = parse_ap_info(dbus.active_access_point)
    if ret == nil then return nil end
    ret.active = true
    return ret
end

--- get all access point informations
function M:scan()
    local active = M:get_active_ap()
    for_each_wifi_dev(function(dev)
        -- gears.debug.print_warning(dev:get_state())
        if dev:get_state() == "UNAVAILABLE" then return end
        local last_scan = dev:get_last_scan()
        local timeout = NM.utils_get_timestamp_msec() - last_scan

        local aps = dev:get_access_points()

        -- check if only_active
        local only_active = active ~= nil
            and (
                aps ~= nil
                and #aps == 1
                and parse_ap_info(aps[1]) == active.ssid
            )

        -- gears.debug.print_warning(
        --     string.format(
        --         "scan condition %s, %s, %s",
        --         last_scan < 0,
        --         only_active,
        --         timeout >= 15000
        --     )
        -- )

        if last_scan < 0 or only_active or timeout >= 15000 then
            dev_status[dev:get_udi()] = "SCANNING"
            dev:request_scan_async(nil, function(d, result)
                local ok, err = d:request_scan_finish(result)
                if ok then
                    aps = dev:get_access_points()

                    -- check if only_active
                    only_active = active ~= nil
                        and (
                            aps ~= nil
                            and #aps == 1
                            and parse_ap_info(aps[1]) == active.ssid
                        )

                    -- to do re_scan
                    if
                        (aps == nil or #aps == 0) -- if does not have aps
                        or ( -- only active aps
                            active ~= nil
                            and #aps == 1
                            and parse_ap_info(aps[1]).ssid == active.ssid
                        )
                    then
                        gears.debug.print_warning(
                            "nm-applet: wifi scan does not get any result, scheduled to rescan"
                        )
                        gears.timer({
                            timeout = 3,
                            single_shot = true,
                            callback = function() M:scan() end,
                            autostart = true,
                        })
                        return
                    end

                    dev_status[dev:get_udi()] = "DONE"
                    self:emit_signal("wifi::scan_done")
                else
                    dev_status[dev:get_udi()] = "ERROR"
                    gears.debug.print_error(
                        string.format("nm-applet: get scanning errors, %s", err)
                    )
                end
            end)
        else
            gears.debug.print_warning("already scanned, do not scan right now")
            self:emit_signal("wifi::scan_done")
        end
    end)
end

function M:get_wifilist()
    local wifilist = {}
    local scan_done = false

    local active = M:get_active_ap()
    for_each_wifi_dev(function(dev)
        local aps = dev:get_access_points()
        if
            (aps == nil or #aps == 0) -- if does not have aps
            or (
                active ~= nil
                and #aps == 1
                and parse_ap_info(aps[1]).ssid == active.ssid
            ) -- or only active
        then
            scan_done = false
            return
        else
            for _, ap in ipairs(aps) do
                local info = parse_ap_info(ap)

                -- ignore active ssid
                -- if active ~= nil then
                --     goto continue
                -- end

                if info.ssid == "" then
                    goto continue
                end

                table.insert(wifilist, info)

                ::continue::
            end
            scan_done = get_scan_status(dev) == "DONE"
        end
    end)

    table.sort(wifilist, function(a, b) return a.strength > b.strength end)
    return wifilist, scan_done
end

return M
