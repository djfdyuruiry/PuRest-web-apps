local DefaultConfig = require "PuRest.Config.DefaultConfig"
local loadCustomConfig = require "PuRest.Config.loadCustomConfig"

--- Load the server config from a custom file pointed to
-- by the environment variable 'PUREST_CFG' or use the default
-- config.
--
-- @return Server config table.
--
local function resolveConfig ()
	local customConfigFile = os.getenv("PUREST_CFG")

	if not customConfigFile then
		return DefaultConfig
	end

	return loadCustomConfig(customConfigFile)
end

-- Resolve the config for use globally via require.
return resolveConfig()
