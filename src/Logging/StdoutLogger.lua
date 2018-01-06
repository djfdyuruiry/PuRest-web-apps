local LogLevelMap = require "PuRest.Logging.LogLevelMap"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

--- Log function using stdout to print messages, this function
-- has no server config dependencies.
--
-- @param msg The message to log to stdout.
-- @param level Log level associated with the message.
--
local function log(msg, level)
    validateParameters(
        {
            msg = {msg, Types._string_}
        },
        "StdoutLogger.log")

	if type(level) == Types._number_ then
		for k, v in pairs(LogLevelMap) do
			if level == v then
				level = k
			end
		end
	end

    if level == nil then
        level = "INFO"
    end

	print(string.format("%s: %s", tostring(level), tostring(msg)))
end

return log
