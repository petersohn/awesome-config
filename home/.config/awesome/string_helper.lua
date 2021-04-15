local string_helper = {}

function string_helper.trim(s)
    return s:match("^%s*(.-)%s*$")
end

return string_helper
