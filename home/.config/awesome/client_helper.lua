local client_helper = {}

function client_helper.has_client_with(func)
    for s in screen do
        for _, t in ipairs(s.selected_tags) do
            for _, c in ipairs(t:clients()) do
                if c.valid and func(c) then
                    return true
                end
            end
        end
    end
    return false
end

return client_helper
