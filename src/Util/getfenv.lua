-- based on http://leafo.net/guides/setfenv-in-lua52-and-above.html#setfenv-implementation

if getfenv then
    return getfenv
end

local function getfenv(fn)
    local i = 1
    
    while true do
      local name, val = debug.getupvalue(fn, i)
      
      if name == "_ENV" then
        return val
      elseif not name then
        break
      end

      i = i + 1
    end
end

return getfenv
