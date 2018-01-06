local luaSocket = require "socket-lanes"

local log = require "PuRest.Logging.FileLogger"
local LogLevelMap = require "PuRest.Logging.LogLevelMap"
local HttpDataPipe = require "PuRest.Http.HttpDataPipe"
local try = require "PuRest.Util.ErrorHandling.try"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

local function convertClientSocketFileDescriptorToHttpDataPipe (fileDescriptor)
    validateParameters(
        {
            fileDescriptor = {fileDescriptor, Types._number_}
		}, "convertFileDescriptorToHttpDataPipe")

	log(string.format("Attempting to convert file descriptor to socket: %d", fileDescriptor), LogLevelMap.DEBUG)

	local socket, err = luaSocket.tcp(fileDescriptor)

	if not socket or err then
		error(string.format("Error when converting file descriptor to client socket: %s", err))
	end

	log(string.format("Converted file descriptor to client socket: %d", fileDescriptor), LogLevelMap.DEBUG)

	return HttpDataPipe({socket = socket})
end

return convertClientSocketFileDescriptorToHttpDataPipe
