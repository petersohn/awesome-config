local awful = require("awful")
local async = require("async")
local D = require("debug_util")

local command = {}

function command.start_if_not_running(command, args, path)
    if command == nil then
        return
    end
    D.log(D.info, 'Starting ' .. command)
    async.spawn_and_get_output("pidof -x " .. command,
            function(stdout, result_code)
                if result_code ~= 0 then
                    local full_command = command
                    if args then
                        full_command = full_command .. " " .. args
                    end
                    if path then
                        full_command = path .. "/" .. full_command
                    end
                    D.log(D.debug, 'Running: ' .. full_command)
                    awful.spawn.with_shell(full_command)
                    return true
                else
                    D.log(D.debug, 'Already running')
                end
            end)
end

function command.get_available_command(commands)
    for _, command in ipairs(commands) do
        local args = ""
        if command.args then
            args = command.args
        end
        local test
        local command_base = command.command .. " "
        if command.test then
            test = command.test
        else
            local test_args = "--help"
            if command.test_args then
                test_args = command.test_args
            end
            test = command_base .. test_args
        end
        res = os.execute(test)
        -- Different Lua versions return different results
        if res == true or res == 0 then
            return command_base .. args
        else
        end
    end
    return nil
end

return command
