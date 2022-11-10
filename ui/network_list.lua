local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local dpi = require("beautiful.xresources").apply_dpi

local wifi = require(tostring(...):match(".*nm_applet") .. ".wifi")
local icons = require(tostring(...):match(".*nm_applet") .. ".ui.icons")
local configuration =
    require(tostring(...):match(".*nm_applet") .. ".ui.configuration")

local function row(ap)
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

local list = wibox.widget({
    widget = wibox.layout.fixed.vertical,
})

list.rows = {}
list.render_start = 1
list.scroll_down = function()
    if list.render_start + 10 >= #list.rows then return end
    list.render_start = list.render_start + 1
    list.render_list()
end
list.scroll_up = function()
    if list.render_start - 1 < 1 then return end
    list.render_start = list.render_start - 1
    list.render_list()
end

list.btn_up = wibox.widget({
    widget = wibox.container.background,
    {
        widget = wibox.layout.align.horizontal,
        expand = "none",
        nil,
        {
            align = "center",
            valign = "center",
            markup = string.format(
                '<span font="%s">%s</span>',
                configuration.get().wifilist_btn_font,
                ""
            ),
            widget = wibox.widget.textbox,
        },
        nil,
    },
})
list.btn_up:buttons(gears.table.join(awful.button({}, 1, list.scroll_up)))

list.btn_down = wibox.widget({
    widget = wibox.container.background,
    {
        widget = wibox.layout.align.horizontal,
        expand = "none",
        nil,
        {
            align = "center",
            valign = "center",
            markup = string.format(
                '<span font="%s">%s</span>',
                configuration.get().wifilist_btn_font,
                ""
            ),
            widget = wibox.widget.textbox,
        },
        nil,
    },
})
list.btn_down:buttons(gears.table.join(awful.button({}, 1, list.scroll_down)))

function list.render_list()
    local render_end = list.render_start + 10
    if render_end > #list.rows then
        render_end = #list.rows
        list.render_start = list.render_start - 1
    end
    -- render_end = render_end > #list.rows and #list.rows or render_end

    local first_row = list.all_children[1]
    list:reset()

    if first_row.active then list:add(first_row) end
    if list.render_start > 1 then list:add(list.btn_up) end

    for i = list.render_start, render_end, 1 do
        list:add(list.rows[i])
    end

    if render_end < #list.rows then list:add(list.btn_down) end
end

list:buttons(
    gears.table.join(
        awful.button({}, 4, list.scroll_up),
        awful.button({}, 5, list.scroll_down)
    )
)

local popup_menu = awful.popup({
    widget = {
        list,
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
    local wifilist, scan_done = wifi.get_wifilist()

    if #wifilist == 0 and not scan_done then
        gears.debug.print_warning("schedule to reget wifilist")
        gears.timer({
            single_shot = true,
            timeout = 5,
            callback = process_wifi_list,
            autostart = true,
        })
    else
        list.rows = {}
        for _, ap in ipairs(wifilist) do
            table.insert(list.rows, row(ap))
        end
        list.render_list()
    end
end

local function toggle()
    popup_menu.visible = not popup_menu.visible
    if popup_menu.visible then
        list.render_start = 1
        list:reset()
        local ap = wifi.get_active_ap()
        if ap then list:add(row(ap)) end

        wifi.scan()
        process_wifi_list()
    end
end

return {
    toggle = toggle,
}
