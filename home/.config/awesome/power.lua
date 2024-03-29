local gears = require("gears")
local awful = require("awful")
local naughty = require("naughty")
local shutdown = require('shutdown')
local command = require('command')
local dbus_ = require("dbus_")
local D = require("debug_util")

local commands = {}

local function call_power_command(name)
    local command = commands[name]
    if command then
        D.log(D.info, "Calling command: " .. command)
        awful.spawn.with_shell(command)
    else
        local message = "No command found for " .. name
        D.notify_error({text=message})
    end
end

local function lock_and_call_power_command(command)
    local locker = require('locker')
    locker.lock(function() call_power_command(command) end)
end

local power = {}

function power.suspend()
    lock_and_call_power_command("suspend")
end

function power.reboot()
    shutdown.clean_shutdown('Reboot', 30,
        function() call_power_command("reboot") end)
end

function power.hibernate()
    lock_and_call_power_command("hibernate")
end

function power.poweroff()
    shutdown.clean_shutdown('Power off', 30,
        function() call_power_command("poweroff") end)
end

function power.quit()
    shutdown.clean_shutdown('Quit awesome', 30, awesome.quit)
end

local power_menu_notification = nil

function power.power_menu()
    if power_menu_notification then
        return
    end

    local function call(f)
        return function()
            naughty.destroy(power_menu_notification,
                naughty.notificationClosedReason.dismissedByCommand)
            f()
        end
    end

    power_menu_notification = naughty.notify({
        title='Power',
        text='Choose action to take.',
        timeout=30,
        actions={
            ['power off']=call(power.poweroff),
            suspend=call(power.suspend),
            hibernate=call(power.hibernate),
            reboot=call(power.reboot),
            logout=call(power.quit),
            cancel=call(function() end),
        },
        destroy = function()
            power_menu_notification = nil
        end,
    })
end

awesome.connect_signal("startup",
    function()
        local systemctl_command = command.get_available_command({
            {command="systemctl"},
            {command="loginctl"},
        })
        if systemctl_command then
            commands = {
                suspend=systemctl_command .. " suspend",
                reboot=systemctl_command .. " reboot",
                hibernate=systemctl_command .. " hibernate",
                poweroff=systemctl_command .. " poweroff",
            }
            if not variables.is_minimal then
                local power_key_inhibitor = dbus_.inhibit(
                    "handle-suspend-key:handle-lid-switch:handle-power-key",
                    "Handle power keys by awesome", "block")
            end

        else
            commands = {
                suspend="sudo pm-suspend",
                poweroff="sudo poweroff",
                reboot="sudo reboot",
            }
        end
    end)

return power
