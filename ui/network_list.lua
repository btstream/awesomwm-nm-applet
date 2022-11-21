local lgi = require("lgi")
local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local dpi = require("beautiful.xresources").apply_dpi

local NM = require(tostring(...):match(".*nm_applet") .. ".nm").nm
local nm_client = require(tostring(...):match(".*nm_applet") .. ".nm").client

local wifi = require(tostring(...):match(".*nm_applet") .. ".nm.wifi")

local overflow =
    require(tostring(...):match(".*nm_applet") .. ".ui.layouts.overflow")
local icons = require(tostring(...):match(".*nm_applet") .. ".ui.icons")
local prompt = require(tostring(...):match(".*nm_applet") .. ".ui.prompt")

local configuration =
    require(tostring(...):match(".*nm_applet") .. ".configuration")

--- hleper function to generate accesspoint row
---@param ap table
---@return wibox.widget
local function wifilist_ap_widget(ap, active)
    if ap == nil then return nil end

    local defaualt_config = configuration.get()
    local wifi_icon = icons.get_wifi_icon(ap)
    local wifi_color = defaualt_config.nonactive_wifi_color
    if active then wifi_color = defaualt_config.active_wifi_color end
    local wifi_lock = ap.wpa_flags == " " or " "

    -- local ssid_data = ap:get_ssid()

    local ssid = NM.utils_ssid_to_utf8((ap:get_ssid()):get_data())
    if #ssid >= 25 then ssid = ssid:sub(1, 20) .. "..." end

    local r = wibox.widget({
        widget = wibox.container.background,
        shape = function(cr, width, height)
            gears.shape.rounded_rect(cr, width, height, dpi(5))
        end,
        {
            widget = wibox.container.margin,
            left = dpi(10),
            right = dpi(10),
            top = dpi(8),
            bottom = dpi(8),
            {
                layout = wibox.layout.align.horizontal,
                expand = "none",
                {
                    widget = wibox.container.margin,
                    {
                        widget = wibox.widget.textbox,
                        markup = string.format(
                            '<span font="%s" color="%s">%s</span>   <span font="%s">%s</span>',
                            defaualt_config.wifilist_icon_font,
                            wifi_color,
                            wifi_icon,
                            defaualt_config.wifilist_text_font,
                            ssid
                        ),
                        align = "center",
                        valign = "center",
                    },
                },
                nil,
                {
                    widget = wibox.container.margin,
                    {
                        widget = wibox.widget.textbox,
                        align = "center",
                        valign = "center",
                        markup = string.format(
                            '<span font="%s %s">%s</span>',
                            defaualt_config.applet_icon_font,
                            defaualt_config.wifilist_icon_size,
                            wifi_lock
                        ),
                    },
                },
            },
        },
    })
    r:connect_signal("mouse::enter", function(r) r.bg = beautiful.bg_focus end)
    r:connect_signal("mouse::leave", function(r) r.bg = beautiful.bg_normal end)

    r:buttons(
        gears.table.join(awful.button({}, 1, function() prompt.toggle() end))
    )

    -- r.active = ap.active
    local ret = wibox.widget({
        widget = wibox.container.margin,
        left = dpi(3),
        right = dpi(3),
        r,
    })
    ret.active = active
    ret.ssid = ssid
    return ret
end

-- overflow widget for accesspoint list
local wifilist_ap_list = wibox.widget({
    layout = overflow.vertical,
    forced_height = dpi(300),
    scrollbar_widget = {
        widget = wibox.widget.separator,
        shape = function(cr, width, height, _)
            gears.shape.rounded_rect(cr, width, height, dpi(15))
        end,
    },
    scrollbar_width = dpi(2),
    step = 50,
})
----------------------------------------------------------------------
--                       A wifi toggle button                       --
----------------------------------------------------------------------

local wifi_button = wibox.widget({
    widget = wibox.widget.textbox,
})
wifi_button.status = nm_client:wireless_get_enabled()

local function update_wifi_button()
    local defaualt_config = configuration.get()
    if wifi_button.status then
        wifi_button.markup = string.format(
            '<span font="%s" color="%s"> </span>',
            defaualt_config.wifilist_btn_font,
            defaualt_config.active_wifi_color
        )
    else
        wifi_button.markup = string.format(
            '<span font="%s" color="%s"> </span>',
            defaualt_config.wifilist_btn_font,
            beautiful.fg_normal
        )
    end
end
-- wifi_button:connect_signal("wifi::update_button", function() print("wokao") end)

local function check_wifi_button()
    if wifi_button.status == nm_client:wireless_get_enabled() then
        update_wifi_button()
        wifi:scan()
    else
        gears.timer({
            single_shot = true,
            timeout = 0.5,
            callback = check_wifi_button,
            autostart = true,
        })
    end
end

wifi_button:buttons(gears.table.join(awful.button({}, 1, function()
    wifi_button.status = not wifi_button.status
    nm_client:dbus_set_property(
        "/org/freedesktop/NetworkManager",
        "org.freedesktop.NetworkManager",
        "WirelessEnabled",
        lgi.GLib.Variant("b", wifi_button.status),
        15000,
        nil,
        check_wifi_button
    )
    if not wifi_button.status then wifilist_ap_list:reset() end
end)))

----------------------------------------------------------------------
--                            Popup menu                            --
----------------------------------------------------------------------
local popup_container = awful.popup({
    widget = {
        {
            {
                widget = wibox.container.margin,
                top = dpi(10),
                bottom = dpi(5),
                right = dpi(13),
                left = dpi(12),
                {
                    layout = wibox.layout.align.horizontal,
                    expand = "none",
                    wibox.widget.textbox("Wi-Fi"),
                    nil,
                    wifi_button,
                },
                -- wifi_button,
            },
            spacing_widget = {
                widget = wibox.container.margin,
                left = dpi(10),
                right = dpi(10),
                {
                    widget = wibox.widget.separator,
                    color = beautiful.border_normal,
                    thickness = dpi(1),
                },
            },
            wifilist_ap_list,
            layout = wibox.layout.fixed.vertical,
            spacing = dpi(5),
        },
        widget = wibox.container.margin,
        -- top = beautiful.systray_icon_spacing * 2,
        -- bottom = beautiful.systray_icon_spacing * 2,
    },
    ontop = true,
    visible = false,
    shape = function(cr, width, height)
        gears.shape.rounded_rect(cr, width, height, dpi(5))
    end,
    minimum_width = dpi(240),
    maximum_width = dpi(240),
    border_color = beautiful.border_normal,
    border_width = dpi(1),
    type = "menu",
})

----------------------------------------------------------------------
--          helper function to append data to access point          --
--                               list                               --
----------------------------------------------------------------------
local function process_wifi_list()
    local active = wifi:get_active_ap()
    local wifilist, scan_done = wifi:get_wifilist()

    if
        (
            #wifilist == 0
            or (
                #wifilist == 1
                and active ~= nil
                and wifi.parse_ap_info(wifilist[1]).ssid
                    == wifi.parse_ap_info(active.ssid)
            )
        ) and not scan_done
    then
        -- gears.debug.print_warning("schedule to reget wifilist")
        gears.timer({
            callback = process_wifi_list,
            single_shot = true,
            timeout = 3,
            autostart = true,
        })
    else
        -- gears.debug.print_warning(#wifilist)
        for _, ap in ipairs(wifilist) do
            if
                not (
                    active
                    and wifi.parse_ap_info(active).ssid
                        == wifi.parse_ap_info(ap).ssid
                )
            then
                wifilist_ap_list:add(wifilist_ap_widget(ap))
            end
        end
    end
end

wifi:connect_signal("wifi::scan_done", process_wifi_list)
wifi:connect_signal("wifi::state_changed", function()
    if not popup_container.visible then return end
    local active_ap = wifi:get_active_ap()
    if active_ap == nil then return end

    local first_ap_in_list = wifilist_ap_list.all_children[1]
    if
        (first_ap_in_list and not first_ap_in_list.active)
        or first_ap_in_list == nil
    then
        -- wifilist_ap_list:insert(1, wifilist_ap_widget(active_ap))
        wifilist_ap_list:reset()
        wifilist_ap_list:add(wifilist_ap_widget(active_ap, true))
        wifi:scan()
    end
end)

----------------------------------------------------------------------
--                        toggle popup menu                         --
----------------------------------------------------------------------
local function toggle()
    popup_container.visible = not popup_container.visible

    if popup_container.visible then
        update_wifi_button()
        popup_container:move_next_to(mouse.current_widget_geometry)
        local active = wifi:get_active_ap()
        wifilist_ap_list:reset()
        if active then
            wifilist_ap_list:add(wifilist_ap_widget(active, true))
        end
        wifi:scan()
    end

    return popup_container.visible
end

return {
    toggle = toggle,
}
