local gears = require("gears")
local D = require("debug_util")
local client_helper = require("client_helper")

local object = gears.object{has_zoom=false}

local function check_zoom()
    local has_zoom = client_helper.has_client_with(
        function(c) return c.class == 'zoom' end)
    if object.has_zoom ~= has_zoom then
        D.log(D.debug, 'Zoom status changed: ' .. tostring(has_zoom))
        object.has_zoom = has_zoom
        object:emit_signal('status_changed', has_zoom)
    end
end

client.connect_signal("manage", check_zoom)
client.connect_signal("unmanage", check_zoom)

return object
