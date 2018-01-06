local luaFileSystem = require "lfs"

local function getNextDirectoryEntry(basePath, dirReader, dirMetatable)
    local entry = dirReader(dirMetatable)

    if not entry then
        return false
    end

    local attributes = luaFileSystem.attributes(string.format("%s/%s", basePath, entry))

    return
    {
        name = entry,
        type = attributes.mode
    }
end

return getNextDirectoryEntry
