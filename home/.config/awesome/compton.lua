local awful = require("awful")

local async = require("async")
local command = require("command")
local D = require("debug_util")
local Process = require("Process")

local enabled = true
local disable_compton = os.getenv("DISABLE_COMPTON")
local transparency_enabled = true
local opacity = 0.85

local compton_command = command.get_available_command({{command="compton"}})

local process = Process("Compton", compton_command, false)

local compton = {}

local function setup_config_file()
    local content =
        'backend = "glx";\n' ..
        'paint-on-overlay = true;\n' ..
        'vsync = "opengl-swc";\n'
    if transparency_enabled then
        content = content ..
            'inactive-opacity = ' .. tostring(opacity) .. ';\n' ..
            'focus-exclude = "! name~=\'\' || class_g = \'XScreenSaver\'";\n'
    end

    local filename = os.getenv("HOME") .. "/.config/compton.conf"
    local f = io.open(filename, "w")
    f:write(content)
    f:close()
end

local function reset_config()
    if disable_compton then
        return
    end

    setup_config_file()
    if enabled then
        process:restart()
    end
end

local function start()
    if disable_compton then
        return
    end

    if not compton_command then
        D.log(D.warning, "Compton is not available")
        return
    end
    setup_config_file()
    process:start()
end

local function set_enabled(value)
    if disable_compton then
        return
    end

    if value == enabled then
        return
    end

    enabled = value

    if enabled then
        start()
    else
        process:stop()
    end
end

function compton.set_opacity(value)
    if value < 0.0 then
        value = 0.0
    end
    if value > 1.0 then
        value = 1.0
    end
    opacity = value
    reset_config()
end

function compton.increase_opacity(value)
    compton.set_opacity(opacity + value)
end

function compton.decrease_opacity(value)
    compton.set_opacity(opacity - value)
end

function compton.toggle_transparency()
    transparency_enabled = not transparency_enabled
    reset_config()
end

function compton.enable_transparency()
    transparency_enabled = true
    reset_config()
end

function compton.disable_transparency()
    transparency_enabled = false
    reset_config()
end

function compton.enable()
    set_enabled(true)
end

function compton.disable()
    set_enabled(false)
end

function compton.toggle()
    set_enabled(not enabled)
end

if not disable_compton then
    awesome.connect_signal("startup",
        function()
            awful.spawn.with_shell("killall compton")
            if enabled then
                start()
            end
        end)
end

return compton
