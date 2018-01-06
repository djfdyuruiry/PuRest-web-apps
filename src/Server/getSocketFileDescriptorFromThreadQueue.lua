local DEFAULT_LINDA_KEY = require "PuRest.Util.Threading.defaultLindaKey"

local log = require "PuRest.Logging.FileLogger"
local LogLevelMap = require "PuRest.Logging.LogLevelMap"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

local DEFAULT_TIMEOUT = 30

local function getSocketFileDescriptorFromThreadQueue (threadQueue)
	validateParameters(
		{
			threadQueue = {threadQueue, Types._userdata_}
        }, "getSocketFileDescriptorFromThreadQueue")

    log("Waiting for client socket file descriptor to be passed.", LogLevelMap.INFO)
					
    local _, err, socketFileDescriptor = threadQueue:receive(DEFAULT_TIMEOUT, DEFAULT_LINDA_KEY)
    
    if not socketFileDescriptor or err then
        error(string.format("Error occured while getting client socket file descriptor from thread queue: %s", 
            (err or "unknown error")))
    end

    return socketFileDescriptor
end

return getSocketFileDescriptorFromThreadQueue
