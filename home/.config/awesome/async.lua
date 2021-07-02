local awful = require("awful")
local gears = require("gears")
local naughty = require("naughty")

local D = require("debug_util")

local async = {}

function async.safe_call(action)
    local result, err = xpcall(action, debug.traceback)
    if not result then
        D.notify_error({title="Error", text=err})
    end
end

local function handle_start_command(command, action, silent)
    local result = action()
    if type(result) == "string" then
        local error_string = "Error starting command: " .. command
        if silent then
            D.log(D.error, error_string);
            D.log(D.error, result);
        else
            D.notify_error({title=error_string, text=result})
        end
    end
    return result
end

function async.spawn_and_get_output(command, callback, silent)
    local command_str = D.to_string_recursive(command)
    return handle_start_command(command_str, function()
        return awful.spawn.easy_async(command,
                function(stdout, stderr, _, exit_code)
                    local result = true
                    async.safe_call(
                            function()
                                result = callback(stdout, exit_code, stderr)
                            end)
                    if not result and exit_code ~= 0 then
                        D.notify_error({
                                title="Error running command: " .. command_str,
                                text=stderr})
                    end
                end)
    end, silent)
end

function async.spawn_and_get_lines(command, callbacks, silent)
    local log = {stderr=""}
    local done = nil
    if callbacks.done then
        done =
            function(line)
                async.safe_call(function() callbacks.done(line) end)
            end
    end
    local command_str = D.to_string_recursive(command)
    return handle_start_command(command_str, function()
        return awful.spawn.with_line_callback(command, {
                stdout=function(line)
                    async.safe_call(function() callbacks.line(line) end)
                end,
                stderr=function(line)
                    log.stderr = log.stderr .. line .. "\n"
                end,
                exit=function(reason, code)
                    local result = nil
                    if callbacks.finish then
                        result = callbacks.finish(code, log)
                    end
                    if not result and code ~= 0 then
                        D.notify_error({
                                title="Error running command: " .. command_str,
                                text=log.stderr})
                    end
                end,
                output_done=done})
    end, silent)
end

function async.run_continuously(action)
    local retries = 0
    local timer = gears.timer({
            timeout=1,
            single_shot=true,
            callback=function()
                retries = 0
            end})
    local start
    local function callback()
        if retries < 3 then
            retries = retries + 1
            start()
            return true
        end
        D.log(D.error, "Too many retries, giving up.")
        return false
    end
    start = function()
        action(callback)
        timer:again()
    end
    start()
end

function async.run_command_continuously(command, line_callback, start_callback,
        finish_callback)
    if not line_callback then
        line_callback = function() end
    end
    if not finish_callback then
        finish_callback = function() return false end
    end
    local command_str = D.to_string_recursive(command)
    async.run_continuously(
            function(callback)
                D.log(D.debug, "Running command: " .. command_str)
                local pid = async.spawn_and_get_lines(command, {
                        line=line_callback,
                        finish=function()
                            D.log(D.warning, "Command stopped: " .. command_str)
                            if not finish_callback() then
                                return callback()
                            end
                            return true
                        end})
                if type(pid) == "string" then
                    D.notify_error({
                        title="Failed to start command",
                        text=pid
                    })
                    finish_callback()
                    return
                end
                if pid then
                    if start_callback then
                        start_callback(pid)
                    end
                else
                    if not finish_callback() then
                        callback()
                    end
                end
            end)
end

function async.run_commands(commands)
    for _, command in ipairs(commands) do
        async.spawn_and_get_output(command, function() end)
    end
end

return async
