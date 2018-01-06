local zlib = require "zlib"

local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

--- Compress a string buffer using gzip.
--
-- @param str The buffer to compress.
-- @param compressionLevel optional Level of compression as a number between 1-9.
-- @param stripGzipHeaders optional Strip the headers (first three bytes) of the compressed data.
-- @return The input buffer compressed (string).
--
local function gzipCompressString (str, compressionLevel, stripGzipHeaders)
    validateParameters(
        {
            str = {str, Types._string_}
        },
        "gzipCompressString")

    if compressionLevel and type(compressionLevel) ~= "number" then
        error(string.format("Parameter 'compressionLevel' to 'gzipCompressString' must be of type 'string': got '%s'.",
            type(compressionLevel)))
    elseif compressionLevel and (compressionLevel < 1 or compressionLevel > 9) then
        error(string.format("Specified compression level passed to 'gzipCompressString' was '%d', needs to be in the range 1-9.",
            compressionLevel))
    end

    local gzipDataBuffer = {}

    local func = function(data)
        table.insert(gzipDataBuffer, data)
    end

    local gzipStream = zlib.deflate(func, nil, nil, 31)
    gzipStream:write(str)
    gzipStream:close()

   return stripGzipHeaders and string.sub(table.concat(gzipDataBuffer), 3) or table.concat(gzipDataBuffer)
end

return gzipCompressString