-- based on http://leafo.net/guides/setfenv-in-lua52-and-above.html#setfenv-implementation

if setfenv then
    -- use lua 5.1 implementation
    return setfenv
end

local function setfenv(fn, env)
    local i = 1

    while true do
        local name = debug.getupvalue(fn, i)

        if name == "_ENV" then
            debug.upvaluejoin(fn, i, (function()
                return env
            end), 1)

            break
        elseif not name then
            break
        end

        i = i + 1
    end

    return fn
end

-- use shim function
return setfenv