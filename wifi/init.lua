local gears = require("gears")
local nm = require(tostring(...):match(".*nm_applet") .. ".nm")
-- local nm = require("nm")
local NM = nm.nm
local devs = nm.devices

local naughty = require("naughty")

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

local dev_status = {}

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
            -- naughty.notify({
            --     text = string.format(
            --         "%s-%s-%s",
            --         last_scan,
            --         timeout,
            --         only_active
            --     ),
            -- })
            -- dev.scan_status = "SCANNING"
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

                    -- naughty.notify({ text = string.format("%s", #aps) })
                    -- to do re_scan
                    if aps == nil or #aps == 0 or only_active then
                        gears.timer({
                            timeout = 15,
                            single_shot = true,
                            callback = M.scan_wifi_list,
                        })
                        return
                    end

                    dev_status[dev:get_udi()] = "DONE"
                else
                    dev_status[dev:get_udi()] = "ERROR"
                    d.scan_error_info = string.format("%s", err)
                end
            end)
        end
    end)
end

function M.get_device_status(dev) return dev_status[dev:get_udi()] end

M.parse_ap_info = parse_ap_info
return M
