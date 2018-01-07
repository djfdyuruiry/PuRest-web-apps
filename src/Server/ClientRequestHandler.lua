local luaLinq = require "lualinq"
local from = luaLinq.from

forceRequire = require "PuRest.Util.Module.forceRequire"

local ContentTypes = require "PuRest.Http.ContentTypes"
local Dns = require "PuRest.Util.Networking.Dns"
local extractAuthenticationData = require "PuRest.Security.extractAuthenticationData"
local HttpState = require "PuRest.State.HttpState"
local log = require "PuRest.Logging.FileLogger"
local LogLevelMap = require "PuRest.Logging.LogLevelMap"
local SessionData = require "PuRest.State.SessionData"
local RouteMap = require "PuRest.Routing.RouteMap"
local SecurityProvider = require "PuRest.Security.SecurityProvider"
local ServerConfig = require "PuRest.Config.resolveConfig"
local StringUtils = require "PuRest.Util.Data.StringUtils"
local Timer = require "PuRest.Util.Time.Timer"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

local HTML_TEMPLATE = require "PuRest.Html.SystemTemplate"
local _403_HTML = string.format(HTML_TEMPLATE, "403 Forbidden",
	                "<h1>%s</h1>")
local _404_HTML = string.format(HTML_TEMPLATE, "404 Not Found", "<h1>404 Not Found</h1>")
local _500_HTML = string.format(HTML_TEMPLATE, "500 Server Error",
					"<h1>An error on the server has interrupted your request!</h1><h3>Error Details: </h3><pre>%s</pre>")

--- Handler for client requests coming from a specific site, abstracts
-- away route handling, error handling, sending HTTP response, authentication
-- host filtering.
--
-- @param routeMap RouteMap object to use as for handling requests.
-- @param siteConfig Site config for site handling requests.
-- @param urlNamespace The namespace of the site serving requests.
--
local function ClientRequestHandler (routeMap, siteConfig, urlNamespace)
	validateParameters(
		{
			urlNamespace = {urlNamespace, Types._string_}
		})

	local siteConfig = siteConfig or ServerConfig.siteDefaults
	local routeMap = routeMap or RouteMap()
	local formattedNamespaceName = string.format("Namespace '%s' | ", urlNamespace)
	local logProxy = log

	--- Proxy for regular log calls to prepend URL namespace to all messages.
	--
	-- @param msg Log message to pass to original log function.
    --
	local function log (msg, ...)
		validateParameters(
			{
				msg = {msg, Types._string_}
			})

		logProxy(string.format("%s%s", formattedNamespaceName, msg), ...)
	end

	--- Respond to request using the given httpState to determine headers and content.
	--
	-- @param httpState The state of the HTTP connection with the client.
	-- @param dataPipe HTTP data pipe, on which the response to the client request should be made.
    --
	local function respondToRequest (httpState, dataPipe)
		validateParameters(
			{
				httpState = {httpState, Types._table_},
				dataPipe = {dataPipe, Types._table_}
			})

		-- Prepare error page in case HTTP state has been corrupted by the route handler.
		local corruptDataHtml = string.format(_500_HTML,
									"The HTTP state for the is request was corrupted by the route handler.")
		local headers, content = httpState.response.getFormattedHeadersAndContent("http", 500, corruptDataHtml, "text/html")

		dataPipe.write(headers)
		dataPipe.write(content)
	end

	--- Determine if route was not handled properly and if so, determine why.
	-- Error/status pages are generated and injected into response if neccessary.
    --
	-- @param routeHandled Boolean indicating if the route was handled OK.
	-- @param returnValOrErr Potential error returned by route handler.
	-- @param httpState Current state of HTTP connection with client.
    --
	local function determineIfRouteHandled (routeHandled, returnValOrErr, routeMatch, httpState)
		validateParameters(
			{
				routeHandled = {routeHandled, Types._boolean_},
				httpState = {httpState, Types._table_}
			})

		if not routeHandled then
			local error = (returnValOrErr or "Unknown error")
			local errorCode = (type(returnValOrErr) == Types._table_) and returnValOrErr.httpErrCode or nil

			if errorCode then
				httpState.response.responseFormat = "text/html"
				httpState.response.status = errorCode
			end

			if errorCode and errorCode == 404 then
				httpState.response.content = _404_HTML

				log(string.format("No matching handler for location '%s' was found.", httpState.request.location),
					LogLevelMap.WARN)
			elseif errorCode and errorCode == 403 then
				httpState.response.content = string.format(_403_HTML , returnValOrErr.msg)
			elseif not errorCode or  errorCode == 500 then
				httpState.response.status = 500
				httpState.response.responseFormat = "text/html"
				httpState.response.content = string.format(_500_HTML, tostring(error))

				log(string.format("Error when handling route '%s': %s", httpState.request.location, error),
					LogLevelMap.ERROR)
			end
		elseif routeMatch then
			log(string.format("Route '%s' (%s) has been handled successfully.",  routeMatch.route.name,
					routeMatch.route.routePattern), LogLevelMap.INFO)
		end
	end

	--- Automatically return JSON if the content was not set during
	--  handler and a value was returned by the handler. Return value
	--  is true if response content was modified, otherwise false.
	--
	-- @param routeHandled Boolean indicating if the route was handled OK.
	-- @param returnValOrErr Return value from pcall on route action.
	-- @param httpState Current state of HTTP connection with client.
    -- @return Bool indicating if route was handled and the return value of the route or err details.
    --
	local function tryUpdateRepsonseWithReturnValue (routeHandled, returnValOrErr, httpState)
		validateParameters(
			{
				routeHandled = {routeHandled, Types._boolean_},
				httpState = {httpState, Types._table_}
			})

		if not routeHandled then
			return routeHandled, returnValOrErr
		end

		local timer = Timer()
		local returnValue = returnValOrErr
		local config = siteConfig.routes
		local commonErrMessage = "route handler return value and adding it to response body"

		-- Content is empty or ServerConfig allows us to append to existing content.
		local contentCheckOK = config.appendReturnValueToContent or (#(httpState.response.content or "") == 0)
		-- Return value can be used as content, return value exisit's and content check is OK.
		local useReturnValue = config.useReturnValueAsContent and returnValue and contentCheckOK

		if useReturnValue and config.serializeHandlerReturnValue then
			-- Serialise the return value and add to content.
			local encodeStatus, encodeErr = pcall(function ()
				local format = httpState.response.responseFormat or "text/plain"
				local contentTypeHandler = ContentTypes[format]

				if contentTypeHandler and contentTypeHandler.to then
					httpState.response.content = tostring(httpState.response.content) ..
						tostring(contentTypeHandler.to(returnValue))
					httpState.response.responseFormat = format
				else
					error(string.format("Could not obtain content type handler for response format '%s'.", format))
				end
			end)

			-- Update route handling status.
			routeHandled = routeHandled and encodeStatus
			returnValOrErr = encodeErr and encodeErr or returnValOrErr

			-- Format error if present.
			if not routeHandled then
				returnValOrErr = string.format("Error serializing %s: %s", commonErrMessage, returnValOrErr)
				log(returnValOrErr, LogLevelMap.ERROR)
			end
		elseif useReturnValue then
			-- Add string representation of return value to content.
			local contentAddStatus, caErr = pcall(function ()
				httpState.response.content = httpState.response.content .. tostring(returnValue)
				httpState.response.responseFormat = "text/plain"
			end)

			-- Update route handling status.
			routeHandled = routeHandled and contentAddStatus
			returnValOrErr = caErr and caErr or returnValOrErr

			-- Format error if present.
			if not routeHandled then
				returnValOrErr = string.format("Error getting tostring representation of %s: %s",
									commonErrMessage,
									returnValOrErr)
			end
		end

		log(string.format("Updating response with return value from route took %s ms.", timer.endTimeNow()), LogLevelMap.DEBUG)

		return routeHandled, returnValOrErr
	end

	--- Handle HTTP authentication requests.
	--
	-- @param httpState Current HTTP state to process.
    -- @param serverState Server state to record 401 if unauthorised.
    -- @return True if client was authorised to request route, false otherwise.
    --
	local function handleAuthentication (httpState)
		local authConfig = siteConfig.authentication
		local securityProvider = authConfig.securityProvider or SecurityProvider()

		log("Site config has HTTP authentication enabled.", LogLevelMap.INFO)

		if authConfig.requireAuthenticationEverywhere then
			log("HTTP authentication enabled across whole site.", LogLevelMap.INFO)
			return securityProvider.authenticate(httpState, log)
		end

		log("HTTP authentication only enabled for specific site routes.", LogLevelMap.INFO)
		local isProtectedRoute = 
			authConfig.authenticationRouteMap.getMatchingRoute(httpState.request.location, httpState.request.method)

		if isProtectedRoute then
			log("Request route is protected by HTTP authentication.", LogLevelMap.INFO)
			return securityProvider.authenticate(httpState, log)
		end

		log("Request route is not protected by HTTP authentication.", LogLevelMap.INFO)
		return true
	end

	--- Try to handle the route presented in the given HTTP state.
	--
	-- @param httpStateWrapper Wrapper table with optional 'state' key holding current HTTP state.
    -- @param serverState Server state to record 404 if route was not handled
    -- @return Bool indicating if the route was handled, return value of route or an err message
    --         and the route handler as a Route object or a fresh HttpState incase of error.
    --
	local function tryHandleRoute (httpStateWrapper, serverState)
		validateParameters(
			{
				httpStateWrapper = {httpStateWrapper, Types._table_}
			})

		if not httpStateWrapper.state then
			return false, "Unable to parse client request.", HttpState("GET", "?", "http", {}, "", {})
		end

		local httpState = httpStateWrapper.state
		local status, returnValOrErr, match = routeMap.handleRoute(httpState, siteConfig)

		if not status and not match then
			serverState.siteError = { httpErrCode = 404 }
		end

		return status, returnValOrErr, match
	end

	--- Get the body of a request from a data pipe. Attempts to
    -- deserialize the content if Content-Type is compatible.
	--
	-- @param dataPipe Data pipe connected to current client.
	-- @param headers Headers recieved from the client.
    -- @return The body as a string or a deserialized value (mixed).
    --
	local function getBody (dataPipe, headers)
		validateParameters(
			{
				dataPipe = {dataPipe, Types._table_},
				headers = {headers, Types._table_}
			})

		local body = ""
		local contentLength = headers["Content-Length"]
		local contentType

		if headers["Content-Type"] then
			contentType = headers["Content-Type"]:match([[(.*);]]) or headers["Content-Type"] -- Discard charset direct if present
		end

		if contentLength then
			body = dataPipe.readChars(tonumber(contentLength))

			if contentType then
				local contentTypeHandler = ContentTypes[contentType]

				if contentTypeHandler and contentTypeHandler.from then
					body = contentTypeHandler.from(body)
				end
			end
		end

		return body
    end

    --- Determine if the host used in the HTTP request is whitelisted in the
    -- site config.
    --
    -- @param httpState Current HTTP state to process.
    -- @param serverState Server state to record 403 if black listed host was used.
    -- @return True if host is white listed, false otherwise.
    --
	local function isWhitelistedHost (httpState, serverState)
		local whiteList = siteConfig.hostWhitelist
		local host, ipAddress = httpState.request.host, httpState.request.ipAddress
		local clientHostname = Dns.tohostname(ipAddress)

		local whiteListedHost = from(whiteList):where(function(h)
			if h[1] == "*" then
				-- All hosts are whitelisted.
				log("Rule exists to whitelist all hosts, skipping host validation.", LogLevelMap.INFO)
				return true
			end

			if h[2] then
				log("Preforming host validation by DNS lookup.", LogLevelMap.INFO)

				return clientHostname == Dns.tohostname(h[1])
			end

			log("Preforming host validation by string comparison.", LogLevelMap.INFO)
			return host == h[1]
		end):any()

		if not whiteListedHost then
			serverState.siteError = { httpErrCode = 403, msg = "The host you have used to access this resource is incorrect." }

			log(string.format("Request was made to host '%s', which is not a whitelisted host for the site '%s'.",
				host, siteConfig.name), LogLevelMap.INFO)
		end

		return whiteListedHost
	end

	--- Prepare a HttpState object using the given HTTP data pipe.
	-- Request properites, HTTP headers, body, authentication data and
    -- current server session are retrieved.
	--
	-- @param dataPipe HTTP data pipe connected to current client.
	-- @param method HTTP method client used to make request.
	-- @param location URL for the resource requested by the client.
	-- @param protocol Protocol client used to make request.
    -- @return A HttpState object describing the current request.
    --
	local function prepareHttpState (dataPipe, method, location, protocol)
		validateParameters(
			{
				dataPipe = {dataPipe, Types._table_}
			})

		if not method or not location or not protocol then	
			log(string.format("Unable to prepare HTTP state, error parsing request parameters" +
				": method: '%s' | location: '%s' | protocol: '%s'", 
				tostring(method), tostring(location), tostring(protocol)), 
				LogLevelMap.ERROR)

			return false
		end

		local timer = Timer()
		local headers = dataPipe.getHeaders()
		local ipAddress, port = dataPipe.getClientPeerName()

		local hostHeader = StringUtils.explode(headers["Host"] or "", ":")
		local host = hostHeader[1] or ServerConfig.host

		local body = getBody(dataPipe, headers)
		local clientSession = SessionData.resolveSessionData(headers["User-Agent"],
								ipAddress, port,
								siteConfig)
		local authorizationData = extractAuthenticationData(headers, method:upper(), log)

		log(string.format("Preparing HTTP state took %s ms.", timer.endTimeNow()), LogLevelMap.DEBUG)

		return HttpState(method, ipAddress, host, port, location, protocol, headers, authorizationData, body, clientSession)
	end

	--- Serve request to client data pipe using site routes, respecting site
    --  configuration and optional client headers(Authentication, Compression etc.).
	--
	-- @param dataPipe HTTP data pipe connected to client to be served content.
	-- @param serverState Current state of the HTTP connection with the client.
    -- @return HttpState object describing the result of handling the request.
    --
	local function serve (dataPipe, serverState)
		validateParameters(
			{
				dataPipe = {dataPipe, Types._table_},
				serverState = {serverState, Types._table_}
			})

		local timer = Timer()
		local httpStateWrapper =
		{
			state = prepareHttpState(dataPipe, serverState.method, serverState.location, serverState.protocol)
		}
		local hostOk = isWhitelistedHost(httpStateWrapper.state, serverState)
		local authorised = siteConfig.authentication.enableAuthentication and
				handleAuthentication(httpStateWrapper.state) or true

		if not authorized then
			serverState.siteErr = {httpErrCode = 401}
		end

		local routeHandled, returnValOrErr, routeMatch = false, nil, nil

		if hostOk and authorised then
			routeHandled, returnValOrErr, routeMatch = tryHandleRoute(httpStateWrapper, serverState)

			if routeHandled then
				routeHandled, returnValOrErr = tryUpdateRepsonseWithReturnValue(routeHandled, returnValOrErr,
					httpStateWrapper.state)
			end
		end

		local siteError = serverState.siteError or serverState.errWithLaunchScript

		determineIfRouteHandled((siteError and false or routeHandled), (siteError and siteError or returnValOrErr),
			routeMatch, httpStateWrapper.state)
		respondToRequest(httpStateWrapper.state, dataPipe)

		local clientPeerName, clientPort = dataPipe.getClientPeerName()

		SessionData.preserveSessionData(httpStateWrapper.state.session,
			httpStateWrapper.state.request.headers["User-Agent"],
			clientPeerName, clientPort,
			siteConfig)

		log(string.format("Serving client request took %s ms.", timer.endTimeNow()), LogLevelMap.DEBUG)

		return httpStateWrapper.state
	end

	return
	{
		serve = serve
	}
end

return ClientRequestHandler
