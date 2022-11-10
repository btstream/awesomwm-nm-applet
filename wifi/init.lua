local gears = require("gears")
local nm = require(tostring(...):match(".*nm_applet") .. ".nm")
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
    local ssid = ap:get_ssid()
    if not ssid then return "" end
    return NM.utils_ssid_to_utf8(ssid:get_data())
end

local function flags_to_string(flags)
    local str = ""
    for flag, _ in pairs(flags) do
        str = str .. " " .. flag
    end
    if str == "" then str = "NONE" end
    return (str:gsub("^%s", ""))
end

local function flags_to_security(flags, wpa_flags, rsn_flags)
    local str = ""
    if flags["PRIVACY"] and is_empty(wpa_flags) and is_empty(rsn_flags) then
        str = str .. " WEP"
    end
    if not is_empty(wpa_flags) then str = str .. " WPA1" end
    if not is_empty(rsn_flags) then str = str .. " WPA2" end
    if wpa_flags["KEY_MGMT_802_1X"] or rsn_flags["KEY_MGMT_802_1X"] then
        str = str .. " 802.1X"
    end
    return (str:gsub("^%s", ""))
end

----------------------------------------------------------------------
--                            Parse Info                            --
----------------------------------------------------------------------
--- parse ap info
--- @return table
local function parse_ap_info(ap)
    local strength = ap:get_strength()
    local frequency = ap:get_frequency()
    local flags = ap:get_flags()
    local wpa_flags = ap:get_wpa_flags()
    local rsn_flags = ap:get_rsn_flags()
    -- remove extra NONE from the flags tables
    flags["NONE"] = nil
    wpa_flags["NONE"] = nil
    rsn_flags["NONE"] = nil
    return {
        ssid = ssid_to_utf8(ap),
        bssid = ap:get_bssid(),
        frequency = frequency,
        channel = NM.utils_wifi_freq_to_channel(frequency),
        mode = ap:get_mode(),
        flags = flags_to_string(flags),
        wpa_flags = flags_to_string(wpa_flags),
        security = flags_to_security(flags, wpa_flags, rsn_flags),
        strength = strength,
    }
end

--- an help function to run
---@param callback function parameter is device, if return value is true then break the loop
local function for_each_wifi_dev(callback)
    for _, dev in ipairs(devs) do
        if dev:get_device_type() == "WIFI" then
            if callback(dev) then break end
        end
    end
end

local dev_status = {}
local function get_scan_status(dev) return dev_status[dev:get_udi()] end

local M = {}

function M.get_active_ap()
    local ap = nil
    for_each_wifi_dev(function(dev)
        ap = dev:get_active_access_point()
        return ap ~= nil
    end)
    if ap then
        local r = parse_ap_info(ap)
        r.active = true
        return r
    end
end

--- get all access point informations
function M.scan()
    local active = M.get_active_ap()
    for_each_wifi_dev(function(dev)
        if dev:get_state() ~= "ACTIVATED" then return end
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

        if last_scan < 0 or timeout >= 15000 or only_active then
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
                    if aps == nil or #aps == 0 or only_active then
                        gears.debug.print_warning(
                            "nm-applet: wifi scan does not get any result, scheduled to rescan"
                        )
                        gears.timer({
                            timeout = 15,
                            single_shot = true,
                            callback = M.scan_wifi_list,
                            autostart = true,
                        })
                        return
                    end

                    dev_status[dev:get_udi()] = "DONE"
                else
                    dev_status[dev:get_udi()] = "ERROR"
                    gears.debug.print_error(
                        string.format("nm-applet: get scanning errors, %s", err)
                    )
                end
            end)
        end
    end)
end

function M.get_wifilist()
    local wifilist = {}
    local scan_done = false

    local active = M.get_active_ap()
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
                if active ~= nil and active.ssid == info.ssid then
                    goto continue
                end

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
