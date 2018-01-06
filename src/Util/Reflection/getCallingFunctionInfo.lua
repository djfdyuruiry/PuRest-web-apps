--- Call this to get the debug info for the function that called
-- the current chunk.
--
-- @return A string describing the function and a table containing debug info(zero or more fields depending on function).
--
local function getCallingFunctionInfo ()
    local info = debug.getinfo(3, "Sln") or {}

    return string.format("%s in [%s]:%d", info.name or "?", info.short_src or "?", info.currentline or "?"), info
end

return getCallingFunctionInfo