local awful = require("awful")
local ProcessWidget = require("ProcessWidget")
local variables = require("variables")
local naughty = require("naughty")
local rex = require("rex_pcre")
local D = require("debug_util")

stream_player = {}

function stream_player.create_player_widget(name, url)
    local player =
        ProcessWidget(name, {"mplayer", "-quiet", url},
            variables.config_dir .. "/player_stopped.svg",
            variables.config_dir .. "/player_running.svg")

    player.tooltip = awful.tooltip{objects={player}}
    player.tooltip.text = ""

    player.process:connect_signal("line",
        function(process, line)
            stream_title = rex.match(line, "^ICY Info:.*StreamTitle='([^']*)'")
            if stream_title then
                D.log(D.debug, name .. ": ", line .. " => " .. stream_title)
                player.tooltip.text = stream_title
            end
        end)

    player.process:connect_signal("stopped",
        function()
            player.tooltip.text = ""
        end)

    return player
end

return stream_player
