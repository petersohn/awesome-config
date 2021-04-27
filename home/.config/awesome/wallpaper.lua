local beautiful = require("beautiful")
local gears = require("gears")

local async = require("async")
local variables = require("variables")
local D = require("debug_util")
local multimonitor = require("multimonitor")


local wallpapers_dir = variables.config_dir .. "/wallpapers"
local wallpaper_file = variables.config_dir .. "/wallpaper"

local has_wallpapers_dir = gears.filesystem.dir_readable(wallpapers_dir)

local wallpaper = {}

function wallpaper.init()
    D.log(D.info, "Init wallpapers")
    if has_wallpapers_dir then
        beautiful.wallpaper = nil
        wallpaper.choose_wallpaper()
    elseif gears.filesystem.file_readable(wallpaper_file) then
        beautiful.wallpaper = wallpaper_file
    end

end

function wallpaper.choose_wallpaper()
    if not has_wallpapers_dir then
        return
    end

    D.log(D.debug, "Choosing wallpapers")
    local wallpapers = {}
    async.spawn_and_get_lines({"find", wallpapers_dir,
        "-name", ".*", "-prune", "-o", "-type", "f", "-print"}, {
        line=function(line)
            table.insert(wallpapers, line)
        end,
        done=function()
            for s in screen do
                wallpaper.set_wallpaper(s, wallpapers[math.random(#wallpapers)])
            end
        end})
end

function wallpaper.set_wallpaper(s, filename)
    if beautiful.wallpaper then
        filename = beautiful.wallpaper
    end
    if not filename then
        return
    end

    D.log(D.debug, "Set wallpaper for screen "
            .. multimonitor.get_screen_name(s) .. ": "
            .. filename)
    gears.wallpaper.maximized(filename, s, false)
end

if has_wallpapers_dir then
    gears.timer.start_new(300,
        function()
            wallpaper.choose_wallpaper()
            return true
        end)
end

return wallpaper
