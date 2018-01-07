local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

--- Validate the given route map; return value is true if object validates OK, otherwise false
-- and a string containing an error.
--
-- @param routeMap The route map object to validate.
-- @return True if validation was OK, otherwise false and an error message.
--
local function validateRouteMap (routeMap)
	return pcall(validateParameters,
		{
			routeMap = {routeMap, Types._table_},
			routes = {routeMap.routes, Types._table_},
			addRoute = {routeMap.addRoute, Types._function_},
			removeRoute = {routeMap.removeRoute, Types._function_},
			routeExists = {routeMap.routeExists, Types._function_},
			getMatchingRoute = {routeMap.getMatchingRoute, Types._function_},
			handleRoute = {routeMap.handleRoute, Types._function_}
		})
end

return validateRouteMap
