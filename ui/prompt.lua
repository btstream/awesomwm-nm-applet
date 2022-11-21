local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local gears = require("gears")
local dpi = require("beautiful.xresources").apply_dpi
local prompt =
    require(tostring(...):match(".*nm_applet") .. ".ui.widgets.prompt")
local configuration =
    require(tostring(...):match(".*nm_applet") .. ".configuration")

local widget = {}
local default_config = configuration.get()
----------------------------------------------------------------------
--                          prompt widget                           --
----------------------------------------------------------------------

widget.password_prompt = prompt({
    history_path = nil,
    password = true,
    prompt = "",
    hooks = {
        {
            {},
            "Return",
            function(cmd)
                print(cmd)
                widget.popup.visible = false
            end,
        },
        {
            {},
            "Escape",
            function(cmd) widget.popup.visible = false end,
        },
    },
})

----------------------------------------------------------------------
--                           Popup window                           --
----------------------------------------------------------------------
widget.popup = awful.popup({
    widget = {
        layout = wibox.layout.fixed.horizontal,
        {
            {
                markup = string.format(
                    '<span color="%s"> </span>',
                    default_config.active_wifi_color
                ),
                font = "Sans 60",
                valignt = "center",
                align = "center",
                widget = wibox.widget.textbox,
            },
            left = dpi(10),
            right = dpi(10),
            top = dpi(10),
            bottom = dpi(10),
            widget = wibox.container.margin,
        },
        {
            layout = wibox.layout.align.vertical,
            spacing = dpi(5),
            {
                {
                    align = center,
                    valignt = center,
                    text = "当前Wi-Fi接入点已被密码保护请输入密码，以继续连接当前Wi-Fi",
                    wrap = "word_char",
                    ellipsize = "none",
                    widget = wibox.widget.textbox,
                },
                top = dpi(25),
                widget = wibox.container.margin,
            },
            {
                {
                    {
                        text = "密码：",
                        widget = wibox.widget.textbox,
                    },
                    widget.password_prompt,
                    layout = wibox.layout.align.horizontal,
                },
                widget = wibox.container.margin,
            },
        },
    },
    visible = false,
    shape = function(cr, width, height)
        gears.shape.rounded_rect(cr, width, height, dpi(5))
    end,
    placement = function(d)
        awful.placement.align(d, {
            position = "top",
            margins = {
                top = dpi(120),
            },
        })
    end,
    minimum_width = dpi(320),
    maximum_width = dpi(320),
    border_color = beautiful.border_normal,
    border_width = dpi(1),
    ontop = true,
})

local M = {}

function M.toggle()
    widget.popup.visible = not widget.popup.visible
    if widget.popup.visible then widget.password_prompt:run() end
end

return M
