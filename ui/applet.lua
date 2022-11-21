local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local wibox = require("wibox")

local wifi = require(tostring(...):match(".*nm_applet") .. ".nm.wifi")

local configuration =
    require(tostring(...):match(".*nm_applet") .. ".configuration")
local icons = require(tostring(...):match(".*nm_applet.ui") .. ".icons")
local network_list =
    require(tostring(...):match(".*nm_applet.ui") .. ".network_list")

local indicator = wibox.widget({
    align = "center",
    valign = "center",
    widget = wibox.widget.textbox,
})

local function update_indicator()
    local default_config = configuration.get()
    local ap = wifi:get_active_ap()

    indicator:set_markup_silently(
        string.format(
            '<span font="%s">%s</span>',
            default_config.applet_icon_font,
            icons.get_wifi_icon(ap)
        )
    )
end

--- setup
---@param[opt] config table
---@return wibox.widget
local function setup(config)
    local default_config = configuration.get(config)

    local applet = wibox.widget({
        {
            indicator,
            left = default_config.margin_left,
            right = default_config.margin_right,
            widget = wibox.container.margin,
        },
        bg = beautiful.bg_normal,
        widget = wibox.container.background,
    })

    network_list:connect_signal(
        "wifi::wifilist_clicked",
        function() applet.bg = beautiful.bg_normal end
    )

    applet:buttons(gears.table.join(awful.button({}, 1, function()
        if network_list.toggle() then
            applet.bg = beautiful.bg_focus
        else
            applet.bg = beautiful.bg_normal
        end
    end)))

    update_indicator()
    wifi:connect_signal("wifi::signal_strength_changed", update_indicator)
    wifi:connect_signal("wifi::state_changed", update_indicator)
    return applet
end

return setmetatable({}, {
    __call = setup,
})
