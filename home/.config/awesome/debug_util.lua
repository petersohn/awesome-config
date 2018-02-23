local function __to_string_recursive(object, depth)
    if type(object) == "table" then
       local prefix = ""
       for _=1,depth do
           prefix = prefix .. " "
       end
       local result = "{\n"
       for key, value in pairs(object) do
           result = result .. prefix .. " "
                   .. __to_string_recursive(key, depth + 1) .. " -> "
                   .. __to_string_recursive(value, depth + 1) .. "\n"
       end
       return result .. prefix .. "}"
    elseif type(object) == "string" then
        return "\"" .. object .. "\""
    else
       return tostring(object)
    end
end

local debug_util = {}

function debug_util.to_string_recursive(object)
    return __to_string_recursive(object, 0)
end

function debug_util.get_client_debug_info(c)
    if not c then
        return "<none>"
    end
    local class = c.class or ""
    local name = c.name or ""
    local instance = c.instance or ""
    return c.window .. " - " .. class .. " [" .. instance .. "] - " .. name
end

local log_file = io.open("awesome.log", "a")

function debug_util.log(message)
    log_file:write(os.date("%F %T: ") .. message .. "\n")
    log_file:flush()
end

return debug_util
