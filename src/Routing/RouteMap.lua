local luaLinq = require "lualinq"
local from = luaLinq.from

local log = require "PuRest.Logging.FileLogger"
local LogLevelMap = require "PuRest.Logging.LogLevelMap"
local Route = require "PuRest.Routing.Route"
local serveDirectory = require "PuRest.Http.serveDirectory"
local serveFile = require "PuRest.Http.serveFile"
local Timer = require "PuRest.Util.Time.Timer"
local Types = require "PuRest.Util.ErrorHandling.Types"
local Url = require "PuRest.Http.Url"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

--- Static directory handling route.
local SERVE_DIRECTORY_ROUTE = Route("listDirectoryContents", "GET", [[.*]], serveDirectory, true)

--- Static file handling route.
local SERVE_FILE_ROUTE = Route("serveFile", {"GET", "POST"}, [[.*\/(?<fileName>.+[.][^?]+)(?(?=\?)\?(?<queryString>.*)$|$)]], serveFile, true)

--- Handles URL route mapping by filtering on regex patterns and HTTP methods.
-- Routes are declared by addRoute with a Route object to describe the route.
--
-- @param fileServingEnabled Allow files to be served when matching URI routes.
-- @param directoryServingEnabled Allow directory listings to be served when no
---                               matching URI routes found for a trailing '/'.
--
local function RouteMap (fileServingEnabled, directoryServingEnabled)
	validateParameters(
	{
		fileServingEnabled = {fileServingEnabled, Types._boolean_},
		directoryServingEnabled = {directoryServingEnabled, Types._boolean_}
	}, "RouteMap")

	local routes = {}

    --- Does a given route exist in this route map?
    --
    -- @param route Route object to find in RouteMap instance.
    -- @return True if the route is in this map, false otherwise.
    --
	local function routeExists (route)
		validateParameters(
			{
				route = {route, Types._table_}
			}, "RouteMap.routeExists")

		if from(routes):contains(function(r) return r == route; end) then
			return true
		end

		return false
	end

    --- Add a route to the route map.
    --
    -- @param route Route object to add to the map.
    -- @return The route object added to the route map, or false if
    --         route already exists in map.
    --
	local function addRoute (route)
		validateParameters(
			{
				route = {route, Types._table_}
			}, "RouteMap.addRoute")

		if routeExists(route) then
			return false
		end

		table.insert(routes, route)

		return from(routes):contains(function(r) return r == route; end)
	end

    --- Remove a given route from the map.
    --
    -- @param route Route to remove from the map.
    -- @return True if route object was removed from the route map, otherwise false.
    --
	local function removeRoute (route)
		validateParameters(
			{
				route = {route, Types._table_}
			}, "RouteMap.removeRoute")

		if not routeExists(route) then
			return false
		end

		local countBefore = table.getn(routes)

		routes = from(routes):except({route}):toArray()

		local countAfter = table.getn(routes)

		return countAfter == (countBefore - 1)
	end

    --- Get and build request parameters for the matching route for the
    -- location and http method speicfied.
    --
    -- @param location The location from a HTTP header.
    -- @param httpMethod A string representing HTTP method used.
    -- @return False if no route in map was a match, a table {args, queryStringArgs, route}.
    --
	local function getMatchingRoute (location, httpMethod)
		validateParameters(
			{
                location = { location, Types._string_}
			}, "RouteMap.getMatchingRoute")

		for _,r in pairs(routes) do
			local isMatch, captures = r.matchesRoute(location, httpMethod)

			if isMatch then
				local queryStringArgs = captures["queryString"] and Url.parseQueryString(captures["queryString"]) or nil

				return
				{
					args = captures,
					queryStringArgs = queryStringArgs,
					route = r
				}
			end
		end

		return false
	end

    --- Get the matching route for the HTTP state presented and
    -- execute the handler if a match was found. If no route is
    -- found and the given site config allows directory serving an
    -- attempt will be made to build a HTML page for browsing the current
    -- current directory.
    --
    -- @param httpState Current HttpState object for the originating request.
    -- @param siteConfig Config for site handling client request.
    -- @returns False on no match, otherwise the status of handler execution, the handler
    --          return value or an error string and the matching route object.
    --
	local function handleRoute (httpState, siteConfig)
		validateParameters(
			{
				httpState = {httpState, Types._table_},
				siteConfig = {siteConfig, Types._table_}
			}, "RouteMap.handleRoute")

		local timer = Timer()
		local match = getMatchingRoute(httpState.request.location, httpState.request.method)

		if match == false then
			if directoryServingEnabled then
				-- No match found, i.e. not a route/file, so try to serve directory listings.
				match =
                {
                    args = {},
                    queryStringArgs = {},
                    route = SERVE_DIRECTORY_ROUTE
                }
			else
				return false
			end
		end

		local status, returnValOrErr = pcall(match.route, match.args, match.queryStringArgs, httpState, siteConfig)

		log(string.format("Handling route took %s ms.", timer.endTimeNow()), LogLevelMap.DEBUG)

		return status, returnValOrErr, match
	end

    --- Add file handling route if fileServingEnabled flag passed to constructor is true.
	local function construct ()
		if fileServingEnabled then
			-- Load default file handling route if file serving is enabled.
			table.insert(routes, SERVE_FILE_ROUTE)
		end

		return
		{
			routes = routes,
			addRoute = addRoute,
			removeRoute = removeRoute,
			routeExists = routeExists,
			getMatchingRoute = getMatchingRoute,
			handleRoute = handleRoute
		}
	end

	return construct()
end

return RouteMap
