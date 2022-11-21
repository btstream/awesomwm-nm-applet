local beautiful = require("beautiful")
local gears = require("gears")
-- local dpi = require("beautiful.xresources").apply_dpi

local default_config = {
    applet_icon_font = beautiful.nm_applet_icon_font
        or "Material Design Icons 12",
    wifilist_icon_font = beautiful.nm_wifilist_icon_font
        or "Material Design Icons 11",
    wifilist_text_font = beautiful.nm_wifilist_text_font or beautiful.font,
    wifilist_btn_font = beautiful.nm_wifilist_btn_font
        or "Material Design Icons 12",

    margin_left = beautiful.nm_applet_margin_left
        or beautiful.systray_icon_spacing / 2,

    margin_right = beautiful.nm_applet_margin_right
        or beautiful.systray_icon_spacing / 2,

    active_wifi_color = beautiful.active_wifi_color or beautiful.fg_normal,
    nonactive_wifi_color = beautiful.fg_normal,

    --stylua: ignore
    icons            = {
        strength1    = "󰤯",
        strength2    = "󰤟",
        strength3    = "󰤢",
        strength4    = "󰤥",
        strength5    = "󰤨",
        disconnected = "󰤫",
        disabled     = "󰤮",
    },
}

--- get_config
---@param[opt] conf table or nil
local function get(config)
    assert(type(config) == "table" or "nil")
    if config then gears.table.crush(default_config, config) end

    return default_config
end

return {
    get = get,
}
