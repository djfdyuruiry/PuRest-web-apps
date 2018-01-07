local ConfigValidator = require "PuRest.Config.ConfigValidator"
local DefaultConfig = require "PuRest.Config.DefaultConfig"
local defaultLogFunction = require "PuRest.Logging.StdoutLogger"
local LogLevelMap = require "PuRest.Logging.LogLevelMap"
local try = require "PuRest.Util.ErrorHandling.try"

--- Attempt to load in and validate server config from a given file.
--
-- @param customConfigFile The file path to use.
-- @param log OPTIONAL Function to use for logging.
-- @return Custom server config or the default server config if an error
--          occurred when loading the custom config.
--
local function loadCustomConfig (customConfigFile, log)
	log = log or defaultLogFunction

	local customConfig

	-- Attempt to load custom config.
	try( function()
		local config = dofile(customConfigFile)
		customConfig = config
	end)
	.catch( function (ex)
		log(string.format("Could not load custom server config file '%s': %s", customConfigFile, ex), LogLevelMap.ERROR)
	end)

	-- Validate the loaded custom config.
	try( function ()
		if customConfig then
			ConfigValidator.validateConfig(customConfig)
		end
	end)
	.catch( function (ex)
		customConfig = nil
		log(string.format("Could not validate custom server config file '%s': %s", customConfigFile, ex), LogLevelMap.ERROR)
	end)

	if customConfigFile and not customConfig then
		log("Loading custom server config failed, using default server config", LogLevelMap.WARN)
		return DefaultConfig
	end

	customConfig.isCustomConfig = true

	return customConfig
end

return loadCustomConfig
