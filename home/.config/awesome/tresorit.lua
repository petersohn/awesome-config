local awful = require("awful")
local gears = require("gears")
local naughty = require("naughty")
local wibox = require("wibox")

local async = require("async")
local command = require("command")
local D = require("debug_util")
local variables = require("variables_base")

local tresorit = {}

local tresorit_command = command.get_available_command({
    {command="tresorit-cli", test="tresorit-cli status"}
})

local function on_command_finished(command, result, callback)
    local error_code = nil
    local description = nil
    local error_string = nil
    for _, line in ipairs(result.lines) do
        if line[1] == "Error code:" then
            error_code = line[2]
        elseif line[1] == "Description:" then
            description = line[2]
        end
    end
    result.has_error = false
    if error_code then
        result.has_error = true
        error_string = error_code .. ": " .. description
        D.log(D.debug, "Tresorit: error running command: " .. command)
        D.log(D.debug, error_string)
    end
    if callback then
        callback(result.lines, error_string)
    end
end

local function call_tresorit_cli(command, callback, error_handler)
    local result = {lines={}, has_error=nil, result_code=nil, stderr=nil}
    local on_done = function()
        if result.has_error ~= nil and result.result_code ~= nil then
            if not result.has_error and result.result_code ~= 0 then
                error_handler(result.stderr)
            end
        end
    end

    D.log(D.debug, "Call tresorit-cli " .. command)
    local spawn_result = async.spawn_and_get_lines(
            tresorit_command .. " --porcelain " .. command, {
        line=function(line)
            table.insert(result.lines, gears.string.split(line, "\t"))
        end,
        finish=function(code, log)
            result.result_code = code
            result.stderr = log.stderr
            on_done()
            return true
        end,
        done=function()
            local res, err = xpcall(
                function() on_command_finished(command, result, callback) end,
                debug.traceback)
            if not res then
                local handled = nil
                if error_handler then
                    handled = error_handler(err)
                end
                if not handled then
                    D.notify_error({title="Error", text=err})
                end
            else
                on_done()
            end
        end})
    if type(spawn_result) == "string" and error_handler then
        error_handler(spawn_result)
    end
end

local menu_widget = awful.widget.launcher{
    image=variables.config_dir .. "/tresorit.png",
    menu=awful.menu{items={
        {"Start", function() call_tresorit_cli("start") end},
        {"Stop", function() call_tresorit_cli("stop") end},
        {"Logout", function() call_tresorit_cli("logout") end},
        {"Open GUI", function() awful.spawn("tresorit") end},
    }}
}

local stopped_widget = wibox.widget{
    image=variables.config_dir .. "/cancel.svg",
    resize=true,
    widget=wibox.widget.imagebox,
}

local logout_widget = wibox.widget{
    image=variables.config_dir .. "/question.svg",
    resize=true,
    widget=wibox.widget.imagebox,
}

local restricted_widget = wibox.widget{
    image=variables.config_dir .. "/exclamation-yellow.svg",
    resize=true,
    widget=wibox.widget.imagebox,
}

local error_widget = wibox.widget{
    image=variables.config_dir .. "/exclamation-red.svg",
    resize=true,
    widget=wibox.widget.imagebox,
}

local sync_widget = wibox.widget{
    image=variables.config_dir .. "/sync.svg",
    resize=true,
    widget=wibox.widget.imagebox,
    visible=false,
}
local sync_indexing_widget = wibox.widget{
    image=variables.config_dir .. "/sync-indexing.svg",
    resize=true,
    widget=wibox.widget.imagebox,
    visible=false,
}
local sync_error_widget = wibox.widget{
    image=variables.config_dir .. "/sync-error.svg",
    resize=true,
    widget=wibox.widget.imagebox,
    visible=false,
}


tresorit.widget = wibox.widget{
    menu_widget,
    logout_widget,
    stopped_widget,
    restricted_widget,
    sync_widget,
    sync_indexing_widget,
    sync_error_widget,
    error_widget,
    layout=wibox.layout.stack,
    visible=tresorit_command ~= nil
}

local tooltip = awful.tooltip{
    objects={tresorit.widget},
    text="-"
}

local tooltip_text = "-"

local timer

local function set_tooltip_text(s)
    tooltip_text = s
end

local function append_tooltip_text(s)
    tooltip_text = tooltip_text .. s
end

local backoff_timeout = 10


local function commit(err)
    if err then
        tooltip.text = err
        error_widget.visible = true
        D.notify_error{title='Tresorit error', text=err}
        D.log(D.debug, "Retrying tresorit in "
            .. tostring(backoff_timeout) .. " seconds.")
        gears.timer.start_new(backoff_timeout, function()
            timer:start()
        end)
        backoff_timeout = backoff_timeout * 2
        if backoff_timeout > 600 then
            backoff_timeout = 600
        end
        return true
    end
    backoff_timeout = 10
    timer:start()
    tooltip.text = tooltip_text
end

local function on_files(result, error_string)
    if error_string then
        append_tooltip_text("\n" .. error_string)
        sync_error_widget.visible = true
        commit()
        return
    end
    status_text = ""
    for _, line in ipairs(result) do
        tresor = line[1]
        file = line[2]
        status = line[3]
        progress = line[4]
        if status then
            status_text = status_text .. "\n" .. tresor .. "/" .. file .. ": "
                .. status
        end
        if progress and progress ~= "-" then
            status_text = status_text .. " " .. progress .. "%"
        end
    end
    append_tooltip_text(status_text)
    commit()
end

local function on_transfers(result, error_string)
    if error_string then
        append_tooltip_text("\n" .. error_string)
        sync_error_widget.visible = true
        commit()
        return
    end
    local has_sync = false
    local is_indexing = false
    local has_tresor_error = false
    local has_file_error = false
    local status_text = ""
    for _, line in ipairs(result) do
        tresor = line[1]
        status = line[2]
        remaining = line[3]
        errors = tonumber(line[4])
        if status == "syncing" then
            has_sync = true
            status_text = status_text .. "\n" .. tresor
                .. ": Files remaining: " .. remaining
        elseif status == "indexing" then
            status_text = status_text .. "\n" .. tresor .. ": Indexing"
            is_indexing = true
        elseif status ~= "idle" then
            status_text = status_text .. "\n" .. tresor .. ": " .. status
            has_tresor_error = true
        end
        if errors ~= 0 then
            has_file_error = true
        end
    end

    sync_widget.visible = has_sync
    sync_indexing_widget.visible = is_indexing
    sync_error_widget.visible = not has_sync and
        (has_tresor_error or has_file_error)
    append_tooltip_text(status_text)
    if has_sync or has_file_error then
        call_tresorit_cli("transfers --files", on_files, commit)
    else
        commit()
    end
end

local function on_status(result, error_string)
    local running = false
    local logged_in = false
    local error_code = nil
    local description = nil
    local restriction_state = nil
    if error_string then
        set_tooltip_text(error_string)
    else
        set_tooltip_text("")
        for _, line in ipairs(result) do
            if line[1] == "Tresorit daemon:" then
                running = line[2] == "running"
            elseif line[1] == "Logged in as:" then
                logged_in = line[2] ~= "-"
                set_tooltip_text(line[2])
            elseif line[1] == "Restriction state:" then
                if line[2] ~= "-" and line[2] ~= "Normal" then
                    restriction_state = line[2]
                end
            end
        end
    end
    D.log(D.debug, "Tresorit: running=" .. tostring(running)
        .. " logged_in=" .. tostring(logged_in)
        .. " error=" .. tostring(error_string))
    stopped_widget.visible = not error_string and not running
    logout_widget.visible = running and not logged_in
    error_widget.visible = error_string ~= nil
    restricted_widget.visible = restriction_state ~= nil

    if logged_in and not restriction_state then
        call_tresorit_cli("transfers", on_transfers, commit)
    else
        if restriction_state then
            append_tooltip_text('\n' .. restriction_state)
        end
        sync_widget.visible = false
        sync_indexing_widget.visible = false
        sync_error_widget.visible = false
        commit()
    end
end

local last_call

if tresorit_command ~= nil then
    D.log(D.debug, "Has tresorit-cli")
    timer = gears.timer{
        timeout=2,
        single_shot=true,
        call_now=true,
        autostart=true,
        callback=function()
            last_call = os.time()
            call_tresorit_cli("status", on_status, commit)
        end}

    call_tresorit_cli("start")

    gears.timer.start_new(60, function()
        local now = os.time()
        if now - last_call > 60 then
            message = "Tresorit-cli not called since "
                .. os.date("%c", last_call)
            commit(message)
        end
        return true
    end)
else
    D.log(D.debug, "No tresorit-cli")
end

return tresorit
