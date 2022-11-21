local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local gears = require("gears")
local dpi = require("beautiful.xresources").apply_dpi
local prompt =
    require(tostring(...):match(".*nm_applet") .. ".ui.widgets.prompt")

----------------------------------------------------------------------
--                          prompt widget                           --
----------------------------------------------------------------------
local password_textbox = wibox.widget.textbox()

local password_prompt = prompt({
    history_path = nil,
    password = true,
    textbox = password_textbox,
    prompt = "",
    hooks = {
        {
            {},
            "Return",
            function(cmd) print(cmd) end,
        },
    },
})

----------------------------------------------------------------------
--                           Popup window                           --
----------------------------------------------------------------------
local popup = awful.popup({
    widget = {
        password_prompt,
        -- password_textbox,
        widget = wibox.container.margin,
    },
    visible = false,
    shape = function(cr, width, height)
        gears.shape.rounded_rect(cr, width, height, dpi(5))
    end,
    placement = awful.placement.centered,
    minimum_width = dpi(260),
    maximum_width = dpi(260),
    border_color = beautiful.border_normal,
    border_width = dpi(1),
    ontop = true,
})

local M = {}

function M.toggle()
    popup.visible = not popup.visible
    if popup.visible then password_prompt:run() end
end

return M
