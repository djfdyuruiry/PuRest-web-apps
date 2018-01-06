local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

--- Load the most recent version of the given
--  module, flushing any existing version before
--  calling require.
--
-- @param moduleName Name of the Lua module to load.
-- @return The return values of calling require with the 'moduleName' string.
--
local function forceRequire (moduleName)
	validateParameters(
		{
			moduleName = {moduleName, Types._string_}
		}, "forceRequire")

	if package.loaded[moduleName] then
		package.loaded[moduleName] = nil
	end

	return require(moduleName)
end

return forceRequire
