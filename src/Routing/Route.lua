local lualinq = require "lualinq"
local from = lualinq.from

local Regex = require "rex_pcre"

local log = require "PuRest.Logging.FileLogger"
local LogLevelMap = require "PuRest.Logging.LogLevelMap"
local StringUtils = require "PuRest.Util.Data.StringUtils"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

--- Describes and handles a HTTP endpoint by specifing a URL pattern to be matched
-- to identify route and an handler function which can be run with current HTTP request state parameters.
--
-- Abstract pattern matching for routes using syntax: /api/{captureName} (Captures in curly braces with name in middle)
--
-- @param name Human readable name for the route.
-- @param httpMethods A string or table of strings representing supported HTTP methods.
-- @param routePattern A regex or simple URL pattern (described above) to identify route and extract URL parameters.
-- @param action Function that is called with request parameters when this HTTP endpoint is requested.
--               Called with this syntax by route: action(urlParams, queryStringArgs, httpState, siteConfig).
--               For parameter documentation see the call method.
-- @param patternIsRegex optional Is the pattern in routePattern already a regex string?
-- @param regexModifiers optional Regex modifiers to apply to regex object built from routePattern.
--
local function Route (name, httpMethods, routePattern, action, patternIsRegex, regexModifiers)
	-- If only one HTTP method was passed build an array for it.
	if type(httpMethods) == Types._string_ then
		httpMethods = {httpMethods}
	end

	validateParameters(
		{
			name = {name, Types._string_},
			httpMethods = {httpMethods, Types._table_},
			routePattern = {routePattern, Types._string_},
			action = {action, Types._function_}
		}
		, "Route")

	local routeHttpMethods
	local routeRegex
	local isRegex = patternIsRegex
	local regexModifiers = regexModifiers

	-- Detect a URL part, either a named parameter or static part.
	local function detectUrlPart (routePattern, urlPart, includeOptionalTrailingSlash)
		validateParameters(
			{
				routePattern = {routePattern, Types._string_},
				urlPart = {urlPart, Types._string_},
				includeOptionalTrailingSlash = {includeOptionalTrailingSlash, Types._boolean_}
			}
			, "Route.detectUrlPart")

        local urlParamName = urlPart:match("{(.+)}")
		local urlPartName = urlPart:match("(.+)")
		local trailingSlash = includeOptionalTrailingSlash and "[/]*" or ""

		if urlParamName then
			return string.format([[%s/(?<%s>[^\/^?]+)%s]], routePattern, urlParamName, trailingSlash)
		end

        if urlPartName then
			return string.format("%s/%s%s", routePattern, urlPartName, trailingSlash)
        end

        if not urlParamName and not urlPartName then
            error(string.format("URL part '%s' is not recognised as either a static URL part or a named URL parameter.",
					urlPart))
        end
    end

	--- Compile the URL pattern passed to this instance into a regex object.
	--
	-- @param urlPattern A simple URL pattern, e.g. "/api/{captureName}"
    -- @return Regex object for given URL pattern.
    --
	local function compileRegex (urlPattern)
		validateParameters(
			{
				urlPattern = {urlPattern, Types._string_}
			}
			, "Route.compileRegex")

		local routePattern = ""

        if urlPattern ~= "/" then
        	-- Convert simple URL pattern to regex pattern.
	        local routeParts = StringUtils.explode(urlPattern, "/")

	        for idx, urlPart in ipairs(routeParts) do
	            routePattern = detectUrlPart(routePattern , urlPart, (idx == #routeParts))
	        end
		else
			-- One to one mapping between URL and regex pattern.
			routePattern = "[/]*"
		end

		-- Include query string regex capture.
		local regex = string.format([[^%s(?(?=\?)[?]*(?<queryString>[^\/]*)$|$)]], routePattern)

		log(string.format("Built regex pattern for URL pattern '%s': '%s'", urlPattern, routePattern), LogLevelMap.INFO)

		return regex
	end

    --- Is the given HTTP method supported by this route?
    --
    -- @param httpMethod A string or table of strings representing supported HTTP methods.
    -- @return True if method is supported or false if route is not supported or httpMethod was
    --         neither a string or table.
    --
	local function supportsHttpMethod (httpMethod)
		if from(routeHttpMethods):contains("*") then
			return true
		end

		local httpMethodType = type(httpMethod)

		if httpMethodType == Types._table_ then
			return from(httpMethod):where(function (m) return supportsHttpMethod(m) end):any()
		elseif httpMethodType == Types._string_ then
			return from(routeHttpMethods):contains(httpMethod)
		end

		return false
	end

	--- Does this route match the specified route and support the given HTTP method.
    --
    -- @param location The location from a HTTP header.
    -- @param httpMethod A string representing HTTP method used.
    -- @return Nil/false if this route was not a match, otherwise true and a table of named regex captures.
    --
	local function matchesRoute (location, httpMethod)
		validateParameters(
			{
                location = { location, Types._string_}
			}
			, "Route.matchesRoute")

		if not supportsHttpMethod(httpMethod) then
			return nil
		end

		local match = { routeRegex:exec(location) }

		return #match > 0, match[3] or {}
	end

    --- Call this route's associated handler with request parameters.
    --
    -- @param _ ignored (Table reference from metatable call.)
    -- @param urlParams The URL argments gathered from a route match.
    -- @param queryStringArgs Query string arguments for a route (can be nil).
    -- @param httpState Current HttpState object for client request.
    -- @param siteConfig Config for site handling the request.
    -- @return Return values from calling the action function for this route.
    --
	local function call (_, urlParams, queryStringArgs, httpState, siteConfig)
		validateParameters(
			{
                urlParams = { urlParams, Types._table_},
				httpState = {httpState, Types._table_},
				siteConfig = {siteConfig, Types._table_},
			}
			, "Route.call")

		return action(urlParams, queryStringArgs, httpState, siteConfig)
	end

	--- Are the two routes equal?
    --
    -- @param route0 Left operand route object.
    -- @param route1 Right operand route object.
    -- @return True if routePattern and HTTP method support are the same, false otherwise.
    --
	local function equals (route0, route1)
		validateParameters(
			{
				route0 = {route0, Types._table_},
				route1 = {route1, Types._table_}
			}
			, "Route.equals")

		return route0.routePattern == route1.routePattern and
			route0.supportsHttpMethod(route1.httpMethods)
	end

    --- Compile regex for routePattern if not already regex.
	local function construct ()
		routeHttpMethods = httpMethods
		routeRegex = isRegex and Regex.new(routePattern, regexModifiers) or Regex.new(compileRegex(routePattern))

		return setmetatable(
			{
				name = name,
				httpMethods = httpMethods,
				routePattern = routePattern,
				action = action,
				matchesRoute = matchesRoute
			},
			{
				__call = call,
				__eq = equals
			})
	end

	return construct()
end

return Route
