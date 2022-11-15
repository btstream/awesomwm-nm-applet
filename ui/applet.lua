local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
-- local mouse = require("awful.mouse")
local inspect = require("inspect")

local wifi = require(tostring(...):match(".*nm_applet") .. ".nm.wifi")

local configuration =
    require(tostring(...):match(".*nm_applet.ui") .. ".configuration")
local icons = require(tostring(...):match(".*nm_applet.ui") .. ".icons")
local network_list =
    require(tostring(...):match(".*nm_applet.ui") .. ".network_list")

local indicator = wibox.widget({
    align = "center",
    valign = "center",
    widget = wibox.widget.textbox,
})

local function update_indicator(_, data)
    print(require("inspect")(data))
    local default_config = configuration.get()
    local ap = data == nil and wifi.get_active_ap() or data
    if data ~= nil and data.Strength ~= nil then
        ap = {
            strength = data.Strength,
        }
    end

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
        indicator,
        left = default_config.left,
        right = default_config.right,
        widget = wibox.container.margin,
    })

    applet:buttons(
        gears.table.join(
            awful.button({}, 1, function() network_list.toggle() end)
        )
    )

    update_indicator()
    wifi:connect_signal("wifi::ap_properties_changed", update_indicator)
    wifi:connect_signal("wifi::activated", update_indicator)
    wifi:connect_signal("wifi::disconnected", update_indicator)
    return applet
end

return setmetatable({}, {
    __call = setup,
})
