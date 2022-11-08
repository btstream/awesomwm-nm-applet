-- local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local wibox = require("wibox")
local dpi = require("beautiful.xresources").apply_dpi

local wifi = require(tostring(...):match(".*nm_applet") .. ".wifi")

local default_config = {
    left = beautiful.systray_icon_spacing or dpi(5),
    right = beautiful.systray_icon_spacing or dpi(5),
    icon_font = beautiful.nm_applet_icon_font or "Material Design Icons 12",

    --stylua: ignore
    icons            = {
        strength1    = "󰤯",
        strength2    = "󰤟",
        strength3    = "󰤢",
        strength4    = "󰤥",
        strength5    = "󰤨",
        disconnected = "󰤮",
    },
}

local indicator = wibox.widget({
    align = "center",
    valign = "center",
    widget = wibox.widget.textbox,
})

local function update_indicator()
    local ap = wifi.get_active_ap()
    local icon = default_config.icons.disconnected

    if ap == nil then
        icon = default_config.icon.disconnected
    else
        local strength = ap.strength
        if strength < 20 then
            icon = default_config.icons.strength1
        elseif strength >= 20 and strength < 40 then
            icon = default_config.icons.strength2
        elseif strength >= 40 and strength < 60 then
            icon = default_config.icons.strength3
        elseif strength >= 60 and strength < 80 then
            icon = default_config.icons.strength4
        elseif strength >= 80 then
            icon = default_config.icons.strength5
        end
    end

    indicator:set_markup_silently(
        string.format(
            '<span font="%s">%s</span>',
            default_config.icon_font,
            icon
        )
    )
end

--- setup
---@param[opt] config table
---@return wibox.widget
local function setup(config)
    assert(type(config) == "table" or "nil")
    if config then gears.table.crush(default_config, config) end
    local applet = wibox.widget({
        indicator,
        left = default_config.left,
        right = default_config.right,
        widget = wibox.container.margin,
    })

    gears.timer({
        timeout = 5,
        call_now = true,
        autostart = true,
        callback = update_indicator,
    })

    return applet
end

return setmetatable({}, {
    __call = setup,
})
