local awful = require("awful")
local gears = require("gears")
local naughty = require("naughty")

local async = require("async")
local Semaphore = require("Semaphore")
local D = require("debug_util")
local StateMachine = require("StateMachine")

local locker = {}

local callbacks = {}

local locked = false
local disabled = false

local actions = {}
local state_machine = nil
local backend = nil

local function reset_state_machine()
    state_machine = StateMachine({
        name="Locker",
        initial="Start",
        actions=actions,
        states={
            Start={
                enter={"stop_timer", "disable_screen_out"},
            },
            Enabled={
            },
            Disabled={
                enter={"disable", "disable_screen_out"},
                exit="enable",
            },
            Locking={
                exit="stop_timer",
            },
            Locked={
                enter="call_callbacks",
                exit={"disable_screen_out", "refresh_widgets"},
            },
        },
        transitions={
            Start={
                init={
                    {
                        to="Enabled",
                        guard="is_enabled"
                    },
                    {
                        to="Disabled",
                        guard="is_disabled"
                    },
                },
                lock={
                    action="print_not_running",
                },
                enable={},
                disable={},
            },
            Enabled={
                lock={
                    to="Locking",
                    action={"lock", "add_callback", "start_timer"},
                },
                locked={
                    to="Locked",
                },
                disable={
                    to="Disabled",
                },
                unlocked={},
            },
            Disabled={
                lock={
                    to="Locking",
                    action={"start_timer", "add_callback"},
                },
                locked={
                    to="Locked",
                },
                enable={
                    to="Enabled",
                },
                unlocked={},
            },
            Locking={
                lock={
                    action="add_callback"
                },
                timeout={
                    action="lock",
                },
                locked={
                    to="Locked",
                },
            },
            Locked={
                lock={
                    action="call_callback",
                },
                unlocked={
                    {
                        to="Enabled",
                        guard="is_enabled"
                    },
                    {
                        to="Disabled",
                        guard="is_disabled"
                    },
                },
            },
        },
    })
end

local timer = gears.timer({
    timeout=1, autostart=false,
    callback=function() state_machine:process_event("timeout") end})

locker.prevent_idle = Semaphore(
        function()
            state_machine:process_event("disable")
        end,
        function()
            state_machine:process_event("enable")
        end)

function actions.add_callback(args)
    if args.arg then
        D.log(D.debug, "Has callback")
        table.insert(callbacks, args.arg)
    else
        D.log(D.debug, "No callback")
    end
end

function actions.call_callbacks(args)
    local callbacks_local = callbacks
    callbacks = {}

    D.log(D.debug, "Number of callbacks: " .. tostring(#callbacks_local))
    for _, callback in ipairs(callbacks_local) do
        async.safe_call(callback)
    end
end

function actions.call_callback(args)
    async.safe_call(args.arg)
end

function actions.lock()
    if backend then
        backend.lock()
    end
end

function actions.start_timer()
    timer:start()
end

function actions.stop_timer()
    timer:stop()
end

function actions.enable()
    if backend then
        backend.enable()
    end
end

function actions.disable()
    if backend then
        backend.disable()
    end
end

function actions.disable_screen_out()
    if backend then
        backend.disable_screen_out()
    end
end

function actions.refresh_widgets()
    local widgets = require("widgets")
    widgets.text_clock:force_update()
end

function actions.print_not_running()
    D.notify_error({title="Locker", text="Locker is not running."})
end

function actions.is_enabled()
    return not locker.prevent_idle:is_locked()
end

function actions.is_disabled()
    return locker.prevent_idle:is_locked()
end

function locker.lock(callback)
    state_machine:process_event("lock", callback)
end

local initialized = false

function locker.is_initialized()
    return initialized
end

function locker.init(backend_, args)
    backend = backend_
    backend.connect_signal("locked", function()
        state_machine:process_event("locked")
    end)
    backend.connect_signal("unlocked", function()
        state_machine:process_event("unlocked")
    end)
    backend.connect_signal("started", function()
        state_machine:process_event("init")
    end)
    backend.connect_signal("stopped", function()
        reset_state_machine()
    end)
    backend.init(args)
    initialized = true
end

reset_state_machine()

return locker
