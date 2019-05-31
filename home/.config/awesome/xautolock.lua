local awful = require("awful")
local gears = require("gears")

local async = require("async")


local enable_commands = {"xautolock -enable"}
local disable_commands = {"xautolock -disable"}
local disable_screensaver_commands = {"xset -dpms", "xset s off"}
local lock_commands = {"xautolock -locknow"}

local object = gears.object{}
local xautolock = {}
local args = {}

function xautolock.enable()
    async.run_commands(enable_commands)
end

function xautolock.disable()
    async.run_commands(disable_commands)
end

function xautolock.lock()
    async.run_commands(lock_commands)
end

function xautolock.disable_screen_out()
    async.run_commands(disable_screensaver_commands)
end

function xautolock._on_locked()
    object:emit_signal("locked")
end

function xautolock._on_unlocked()
    object:emit_signal("unlocked")
end

function xautolock.connect_signal(...)
    return object:connect_signal(...)
end

function xautolock.disconnect_signal(...)
    return object:disconnect_signal(...)
end

local function initialize()
    async.spawn_and_get_output("pidof xautolock",
            function(pid_)
                local pid = tonumber(pid_)
                if pid then
                    gears.timer.start_new(0.5,
                            function()
                                initialize()
                                return false
                            end)
                else
                    async.run_command_continuously("xautolock"
                            .. " -locker ~/.config/awesome/lock-session"
                            .. " -time " .. tostring(args.lock_time)
                            .. " -killer 'xset dpms force off'"
                            .. " -killtime " .. tostring(args.blank_time)
                            .. " -notifier 'xset s activate'"
                            .. " -notify " .. tostring(args.notify_time),
                            function() end,
                            function()
                                object:emit_signal("started")
                            end,
                            function()
                                object:emit_signal("stopped")
                            end)
                end
                return true
            end)
    return true
end

function xautolock.init(args_)
    args = args_
    awful.spawn.with_shell("xset dpms 0 0 0")
    async.spawn_and_get_output("xautolock -exit", initialize)
    awesome.connect_signal("exit",
        function()
            awful.spawn.with_shell("xautolock -exit")
        end)
end


return xautolock
