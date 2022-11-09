local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local dpi = require("beautiful.xresources").apply_dpi
local naughty = require("naughty")

local devices = require(tostring(...):match(".*nm_applet") .. ".nm").devices
local wifi = require(tostring(...):match(".*nm_applet") .. ".wifi")
local icons = require(tostring(...):match(".*nm_applet") .. ".ui.icons")
local configuration =
    require(tostring(...):match(".*nm_applet") .. ".ui.configuration")

--- generate row from an ap
---@param ap
local function row(ap)
    if ap == nil then return nil end

    local defaualt_configs = configuration.get()
    local wifi_icon = icons.get_wifi_icon(ap)
    local wifi_color = defaualt_configs.nonactive_wifi_color
    if ap.active then wifi_color = defaualt_configs.active_wifi_color end
    local wifi_lock = ap.wpa_flags == "" or ""

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
                        '<span font="%s" color="%s">%s</span>   %s',
                        defaualt_configs.font_icon,
                        wifi_color,
                        wifi_icon,
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
                        '<span font="%s">%s</span>',
                        defaualt_configs.font_icon,
                        wifi_lock
                    ),
                },
            },
        },
    })

    return r
end

local list = wibox.widget({
    widget = wibox.layout.fixed.vertical,
})

local popup_menu = awful.popup({
    widget = list,
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
    -- naughty.notify({ text = "jkjkjkjkj" })
    local active = wifi.get_active_ap()
    for _, dev in ipairs(devices) do
        if
            dev:get_device_type() == "WIFI"
            and dev:get_state() == "ACTIVATED"
        then
            local aps = dev:get_access_points()
            if -- if only get active ap
                aps ~= nil
                and #aps == 1
                and wifi.parse_ap_info(aps[1]).ssid == active.ssid
            then
                gears.timer({
                    single_shot = true,
                    timeout = 5,
                    callback = process_wifi_list,
                })
                return
            else
                for _, ap in ipairs(aps) do
                    local info = wifi.parse_ap_info(ap)
                    if info.ssid ~= active.ssid then list:add(row(info)) end
                end
            end
        end
    end
end

local function toggle()
    popup_menu.visible = not popup_menu.visible
    if popup_menu.visible then
        list:reset()
        -- for active ap
        local ap = wifi.get_active_ap()
        if ap then list:add(row(ap)) end

        wifi.scan()
        process_wifi_list()
    end
end

return {
    toggle = toggle,
}
