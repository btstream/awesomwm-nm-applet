local configurations =
    require(tostring(...):match(".*nm_applet.ui") .. ".configuration")

local M = {}

function M.get_wifi_icon(ap)
    local default_config = configurations.get()
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
    return icon
end

return M
