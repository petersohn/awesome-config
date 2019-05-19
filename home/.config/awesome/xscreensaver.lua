local awful = require("awful")
local gears = require("gears")

local async = require("async")
local debug_util = require("debug_util")
local dbus_ = require("dbus_")

local xscreensaver = {}
local watch_pid = nil
local enabled = true
local object = gears.object{}

local inhibitor = nil
local prevent_idle_timer = gears.timer({
    timeout=10,
    callback=function()
      awful.spawn("xscreensaver-command -deactivate")
    end})

function xscreensaver.enable()
    enabled = true
end

function xscreensaver.disable()
    enabled = false
end

function xscreensaver.lock()
    awful.spawn.with_shell("xscreensaver-command -lock")
end

function xscreensaver.disable_screen_out()
end

function xscreensaver.connect_signal(...)
    return object:connect_signal(...)
end

function xscreensaver.disconnect_signal(...)
    return object:disconnect_signal(...)
end

local function update_prevent_idle()
    if not enabled and not locked then
        prevent_idle_timer:start()
        if not inhibitor then
            inhibitor = dbus_.inhibit(
                    "idle", "Disbale screen power management", "block")
        end
    else
        prevent_idle_timer:stop()
        if inhibitor then
            dbus_.stop_inhibit(inhibitor)
            inhibitor = nil
        end
    end
end

local function watch()
    async.run_command_continuously("xscreensaver-command -watch",
            function(line)
                debug_util.log("Got xscreensaver action: " .. line)
                if string.match(line, "^LOCK") then
                    update_prevent_idle()
                    object:emit_signal("locked")
                elseif string.match(line, "^UNBLANK") then
                    update_prevent_idle()
                    object:emit_signal("unlocked")
                end
            end,
            function(pid)
                watch_pid = pid
            end,
            function(pid)
                watch_pid = nil
            end)
end

function xscreensaver.init()
    async.spawn_and_get_output("killall xscreensaver",
        function()
            async.run_command_continuously("xscreensaver -no-splash",
                function() end,
                function()
                    object:emit_signal("started")
                end,
                function()
                    object:emit_signal("stopped")
                end)
            watch()
            return true
        end)

    awesome.connect_signal("exit",
        function()
            if watch_pid then
                awful.spawn.with_shell("kill " .. watch_pid)
            end
        end)
end

return xscreensaver
