local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local dpi = require("beautiful.xresources").apply_dpi

local overflow =
    require(tostring(...):match(".*nm_applet") .. ".ui.layouts.overflow")

local wifi = require(tostring(...):match(".*nm_applet") .. ".nm.wifi")
local icons = require(tostring(...):match(".*nm_applet") .. ".ui.icons")
local configuration =
    require(tostring(...):match(".*nm_applet") .. ".ui.configuration")

local function wifilist_ap_widget(ap)
    if ap == nil then return nil end

    local defaualt_config = configuration.get()
    local wifi_icon = icons.get_wifi_icon(ap)
    local wifi_color = defaualt_config.nonactive_wifi_color
    if ap.active then wifi_color = defaualt_config.active_wifi_color end
    local wifi_lock = ap.wpa_flags == " " or ""

    local r = wibox.widget({
        widget = wibox.container.background,
        {
            widget = wibox.layout.align.horizontal,
            expand = "none",
            {
                widget = wibox.container.margin,
                top = dpi(5),
                bottom = dpi(5),
                left = beautiful.systray_icon_spacing * 3,
                right = beautiful.systray_icon_spacing * 3,
                {
                    widget = wibox.widget.textbox,
                    markup = string.format(
                        '<span font="%s" color="%s">%s</span>   <span font="%s">%s</span>',
                        defaualt_config.wifilist_icon_font,
                        wifi_color,
                        wifi_icon,
                        defaualt_config.wifilist_text_font,
                        ap.ssid
                    ),
                    align = "center",
                    valign = "center",
                },
            },
            nil,
            {
                widget = wibox.container.margin,
                top = dpi(5),
                bottom = dpi(5),
                left = beautiful.systray_icon_spacing * 3,
                right = beautiful.systray_icon_spacing * 3,
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
    })
    r:connect_signal("mouse::enter", function(r) r.bg = beautiful.bg_focus end)
    r:connect_signal("mouse::leave", function(r) r.bg = beautiful.bg_normal end)
    r.active = ap.active
    return r
end

local wifilist_active_ap = wibox.widget({
    widget = wibox.layout.fixed.vertical,
})

local wifilist_ap_list = wibox.widget({
    layout = overflow.vertical,
    forced_height = dpi(300),
    spacing = dpi(6),
    scrollbar_widget = {
        widget = wibox.widget.separator,
        shape = function(cr, width, height, _)
            gears.shape.rounded_rect(cr, width, height, dpi(15))
        end,
    },
    scrollbar_width = dpi(4),
    step = 50,
})

local popup_container = awful.popup({
    widget = {
        {
            {
                wifilist_active_ap,
                right = dpi(4),
                widget = wibox.container.margin,
            },
            wifilist_ap_list,
            layout = wibox.layout.fixed.vertical,
            spacing = dpi(6),
        },
        widget = wibox.container.margin,
        top = beautiful.systray_icon_spacing * 2,
        bottom = beautiful.systray_icon_spacing * 2,
    },
    ontop = true,
    visible = false,
    shape = function(cr, width, height)
        gears.shape.rounded_rect(cr, width, height, dpi(5))
    end,
    minimum_width = dpi(240),
    maximum_width = dpi(240),
    placement = function(w)
        awful.placement.top_right(w, {
            margins = {
                top = dpi(32) + beautiful.useless_gap * 2,
                right = beautiful.useless_gap * 2,
            },
        })
    end,
})

local function process_wifi_list()
    local active = wifi:get_active_ap()
    local wifilist, scan_done = wifi:get_wifilist()

    if
        (
            #wifilist == 0
            or (
                #wifilist == 1
                and active ~= nil
                and wifilist[1].ssid == active.ssid
            )
        ) and not scan_done
    then
        gears.debug.print_warning("schedule to reget wifilist")
        gears.timer({
            callback = process_wifi_list,
            single_shot = true,
            timeout = 3,
            autostart = true,
        })
    else
        gears.debug.print_warning(#wifilist)
        for _, ap in ipairs(wifilist) do
            if not (active and active.ssid == ap.ssid) then
                wifilist_ap_list:add(wifilist_ap_widget(ap))
            end
        end
    end
end

wifi:connect_signal("wifiscan::done", process_wifi_list)

local function toggle()
    popup_container.visible = not popup_container.visible

    if popup_container.visible then
        wifilist_ap_list:reset()
        local active = wifi:get_active_ap()
        if active then
            wifilist_active_ap:reset()
            wifilist_active_ap:add(wifilist_ap_widget(active))
        end
        wifilist_ap_list:reset()
        wifi:scan()
    end
end

return {
    toggle = toggle,
}
