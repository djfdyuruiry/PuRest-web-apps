local Serialization = require "PuRest.Util.Data.Serialization"
local ServerConfig = require "PuRest.Config.resolveConfig"

--- Generate a copy of the default site config; use this to
-- prevent using the same table referenced to by server code.
--
-- @param useRelativePath Configure new config to use relative paths.
-- @return A new site config table.
--
local function generateSiteConfig (useRelativePath)
	local siteCfg = ServerConfig.siteDefaults
	local cfgCopy = Serialization.parseJson(Serialization.serializeToJson(siteCfg))

	if useRelativePath then
		cfgCopy.fullPath = nil
	end

	return cfgCopy
end

return generateSiteConfig
