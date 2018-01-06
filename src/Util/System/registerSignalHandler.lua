local signalLoaded, signalOrErr = pcall(require, "posix.signal")
local signal = signalLoaded and signalOrErr or nil

local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

local function registerSignalHandler (signalType, handler)
	validateParameters(
		{
			signalType = {signalType, Types._string_},
			handler = {handler, Types._function_}
		}, "registerSignalHandler")
	
	if not signal then
		io.stderr:write(
			string.format(
				"Unable to register signal handler for %s, check luaposix is installed and supports current OS", 
				signalType))

		io.stderr:write(string.format("Error: %s", signalOrErr))
		return
	end

    signal.signal(signal[signalType], handler)
end

return registerSignalHandler