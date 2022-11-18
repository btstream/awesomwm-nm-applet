local gears = require("gears")
local signal_handler_disconnect =
    require("lgi").GObject.signal_handler_disconnect
local inspect = require("inspect")
local nm = require(tostring(...):match(".*nm_applet") .. ".nm")
local NM = nm.nm
-- local nm_client = nm.client
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

local function parse_ap_info(ap)
    if ap == nil then return ap end

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

----------------------------------------------------------------------
--            other helper function, does not come from             --
--                     NetworkManager examples                      --
----------------------------------------------------------------------

local function for_each_avaiable_wifi_dev(callback)
    for _, dev in ipairs(devs) do
        local state = dev:get_state()
        if
            dev:get_device_type() == "WIFI"
            and state ~= "UNKNOWN"
            and state ~= "UNMANAGED"
            and state ~= "UNAVAILABLE"
        then
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

M._private = {
    active_access_point = nil,
}

-- wifi accesspoint event for strength
local function register_accesspoint_event(ap)
    return ap.on_notify:connect(
        function() M:emit_signal("wifi::signal_strength_changed") end,
        "strength",
        false
    )
end

-- init
local function update_active_infomation()
    -- disconnect strength change signal
    local active_access_points = {}

    for_each_avaiable_wifi_dev(function(dev)
        local active_access_point = dev:get_active_access_point()
        if active_access_point ~= nil then
            table.insert(active_access_points, active_access_point)
        end
    end)

    if #active_access_points >= 1 then
        local new_active_ap = active_access_points[1]

        if -- if there is no active access point exists or connected to a active access point
            M._private.active_access_point == nil
            or M._private.active_access_point.ap ~= new_active_ap
        then
            if M._private.active_access_point ~= nil then
                signal_handler_disconnect(
                    M._private.active_access_point.ap,
                    M._private.active_access_point.handler
                )
            end
            local handler = register_accesspoint_event(new_active_ap)
            M._private.active_access_point = {
                ap = new_active_ap,
                handler = handler,
            }
        end
    else -- disconnect from current access point
        if M._private.active_access_point ~= nil then
            signal_handler_disconnect(
                M._private.active_access_point.ap,
                M._private.active_access_point.handler
            )
        end
        M._private.active_access_point = nil
    end
end

update_active_infomation()
-- nm:connect_signal("nm::state_changed", update_active_infomation)
for_each_avaiable_wifi_dev(function(dev)
    return dev.on_notify:connect(function()
        local state = dev:get_state()
        update_active_infomation()
        M:emit_signal("wifi::state_changed", state)
    end, "state")
end)

function M:get_active_ap()
    if M._private.active_access_point == nil then return nil end
    local ret = parse_ap_info(M._private.active_access_point.ap)
    ret.active = true
    return ret
end

--- get all access point informations
function M:scan()
    local active = M:get_active_ap()
    for_each_avaiable_wifi_dev(function(dev)
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
    for_each_avaiable_wifi_dev(function(dev)
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

return setmetatable({}, {
    __index = function(_, key)
        if key == "_private" then
            return nil
        else
            return M[key]
        end
    end,
})
