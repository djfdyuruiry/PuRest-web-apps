local ClientRequestHandler = require "PuRest.Server.ClientRequestHandler"
local ConfigValidator = require "PuRest.Config.ConfigValidator"
local FileSystemUtils = require "PuRest.Util.File.FileSystemUtils"
local generateSiteConfig = require "PuRest.Config.generateSiteConfig"
local logProxy = require "PuRest.Logging.FileLogger"
local LogLevelMap = require "PuRest.Logging.LogLevelMap"
local RouteMap = require "PuRest.Routing.RouteMap"
local Route = require "PuRest.Routing.Route"
local Serialization = require "PuRest.Util.Data.Serialization"
local ServerConfig = require "PuRest.Config.resolveConfig"
local StringUtils = require "PuRest.Util.Data.StringUtils"
local SystemTemplate = require "PuRest.Html.SystemTemplate"
local Timer = require "PuRest.Util.Time.Timer"
local try = require "PuRest.Util.ErrorHandling.try"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"
local validateRouteMap = require "PuRest.Routing.validateRouteMap"

local ROOT_ERR_MSG = "Root URL '%s' generated from namespace '%s' is invalid. " ..
	"Make sure it follows this pattern: '<protocol>://<mainUrl>/' (note the trailing slash)"

local DEFAULT_SITE_ROUTE = Route("serverGreeting", "*", [[/]], function (_, _, httpState, siteConfig)
	httpState.response.responseFormat = "text/html"
	httpState.response.content = string.format(SystemTemplate, "PuRest Web Server", [[<h3 style="text-align: center; margin-top: 25%;">PuRest Web Server</h3>]])
end)

--- Manages route mapping and serving client requests for a given site hosted on a server
--
--	@param transportProtocol Protocol used to communicate with site, typically this will only ever be HTTP.
--	@param urlNamespace A short hand to specify which root URL belongs to this site, e.g. 'Test', '/', '/science/chemistry'.
--	@param fullPath Where on the servers file system do the files for this site's exist.
--	@param isDefaultSite Optional. Where on the servers file system do the files for this site's exist.
--
local function Site (transportProtocol, urlNamespace, fullPath, isDefaultSite)
	validateParameters(
		{
			transportProtocol = {transportProtocol, Types._string_},
			urlNamespace = {urlNamespace, Types._string_}
		}, "Site")

	local urlNamespace = urlNamespace:lower()
	local formattedNamespaceName
	local fullPath = fullPath
	local fileSystemPath
	local siteConfig

	local transportProtocol = transportProtocol:lower()

	local rootUrl
	local routeMap

	local originalServerLogLevel = ServerConfig.logging.maxLogLevel

	--- Proxy for regular log calls to prepend URL namespace to all messages.
	--
	-- @param msg Log message to pass to original log function.
    --
	local function log (msg, ...)
		validateParameters(
			{
				msg = {msg, Types._string_}
			}, "Site.log")

		logProxy(string.format("%s%s", formattedNamespaceName, msg), ...)
	end

    --- Get current site config.
    --
    -- @return The current site config table.
    --
	local function getSiteConfig ()
		return siteConfig
	end

    --- Get current route map.
    --
    -- @return The current site route map object.
    --
	local function getRouteMap ()
		return routeMap
	end

    --- Reload the server config from defaults and set name/full path properties.
	local function refreshSiteConfig ()
		-- Only take a copy of the defaults, don't reference that table in memory!
		siteConfig = generateSiteConfig()

		if isDefaultSite then
			-- Default site should never refuse a connection based on host!
            siteConfig.name = "default_site"
			siteConfig.hostWhitelist = {{"*", false}}
			siteConfig.directoryServingEnabled = false
			siteConfig.fileServingEnabled = false
        else
            siteConfig.name = urlNamespace
            siteConfig.fullPath = fileSystemPath
        end
	end

	--- Set the route map for this site.
	--
	-- @param routes The route map to load.
    --
	local function setRoutes (routes)
		validateParameters(
		{
			routes = {routes, Types._table_},
			routes_handleRoute = {routes.handleRoute, Types._function_}
		}, "Site.setRoutes")

		routeMap = routes
	end

	--- Format the given HTTP location to replace it's host with a wild-card if
	--	this site is bound to all hosts.
	--
	-- @param httpLocation Format this HTTP location and return formatted value.
	-- @param keepUrlNamespace Keep the site URL namespace as part of the HTTP location?
    --
	local function formatHttpLocation (httpLocation, keepUrlNamespace)
		validateParameters(
			{
				httpLocation = {httpLocation, Types._string_}
			}, "Site.formatHttpLocation")

		if not keepUrlNamespace then
			httpLocation = StringUtils.plainReplace(httpLocation, "HTTP://*/" .. urlNamespace, "")
			httpLocation = httpLocation ~= "" and httpLocation or "/"

			return httpLocation
		end

		local proto = httpLocation:match("(.+)://")
		local location = httpLocation:match(".+://[^/]+[/](.+)")
		local host = httpLocation:match(".+://([^/]+)[/]")

		if not proto or not location then
			return httpLocation
		end

	    return string.format("%s://", proto) ..
			(string.format("%s/%s", host, (location .. "/")):gsub("//", "/"))
	end

	--- Is the given HTTP location a resource found on this site.
	--
	-- @param httpLocation Check this resource.
    --
	local function isOnSite (httpLocation)
		validateParameters(
			{
				httpLocation = {httpLocation, Types._string_}
			}, "Site.isOnSite")

		return StringUtils.startsWith(httpLocation, rootUrl)
	end

	--- Try executing a detected site launch script and load return
	--	values from it, errors are thrown if any issues occur.
	--
	-- @param launchScriptName Absolute path of the launch script to execute.
    --
	local function tryExecutingLaunchScript (launchScriptName)
		validateParameters(
			{
				launchScriptName = {launchScriptName, Types._string_}
			}, "Site.tryExecutingLaunchScript")

		local scriptReturnTable

		-- Attempt to execute launch script.
		try( function ()
			scriptReturnTable = dofile(launchScriptName)
		end)
		.catch ( function (ex)
			scriptReturnTable = nil
			error(string.format("Error loading launch script '%s' for URL namespace '%s': %s.",
				launchScriptName, urlNamespace, ex))
		end)

		if not scriptReturnTable then
			-- Unable to load launch script, abort.
			return
        end

        log(string.format("Executed launch script for site : '%s'.", launchScriptName), LogLevelMap.INFO)
        log(string.format("Launch script '%s' returned table (ref: %s).",
            launchScriptName, tostring(scriptReturnTable)), LogLevelMap.DEBUG)

		try( function ()
			-- Check that the launch script returned a table with a routeMap key.
			validateParameters(
				{
					scriptReturnTable = {scriptReturnTable, Types._table_}
				}, "Site.tryExecutingLaunchScript.setRouteMapFromLaunchScript")

			if scriptReturnTable.routeMap then
				-- Check and load routeMap returned from script.
				local isValid, validationError = validateRouteMap(scriptReturnTable.routeMap)

				if not isValid then
					error(string.format("RouteMap returned is invalid: %s.", validationError))
				end

				routeMap = scriptReturnTable.routeMap
                log(string.format("Loaded route map (ref: %s) from launch script '%s'.",
                    tostring(scriptReturnTable.routeMap), launchScriptName), LogLevelMap.DEBUG)
            end

			if not scriptReturnTable.siteConfig then
				return
			end

			-- If a site config section was returned, check and load this also.
			local isValid, validationError = ConfigValidator.validateSiteConfig(scriptReturnTable.siteConfig)

			if not isValid then
				error(string.format("Site config returned is invalid: %s.", validationError))
			end

			siteConfig = scriptReturnTable.siteConfig
            log(string.format("Loaded site config (ref: %s) from launch script '%s'.",
                tostring(scriptReturnTable.siteConfig), launchScriptName), LogLevelMap.INFO)

            if not siteConfig.fullPath then
				siteConfig.fullPath = (string.format("%s/%s", ServerConfig.htmlDirectory:gsub([[\]], "/"), urlNamespace):gsub("//", "/"))
            end

            siteConfig.name = siteConfig.name ~= "" and siteConfig.name or urlNamespace
		end)
		.catch ( function (ex)
				-- Error loading launch script.
				error(string.format("Launch script '%s' for URL namespace '%s' threw/contains an error: %s.",
					launchScriptName, urlNamespace, ex))
		end)
	end

	--- If a launch script can be found at the root folder of this
	--	site, execute and load return values for the route map and
	--	config; defaults are used if a launch script can not be found.
    --
    -- @return Nothing if no errors occurred or an error string.
    --
	local function loadLaunchScriptIfPresent ()
		local launchScriptName
		local errorExecutingScript

		local timer = Timer()

		-- Attempt to find supported script file in site path.
		for _,launchFileName in ipairs(ServerConfig.launchScriptNames) do
			local absFileName = (string.format("%s/%s", fileSystemPath, launchFileName):gsub("//", "/"))

			if FileSystemUtils.fileExists(absFileName) then
				launchScriptName = absFileName
				break
			end
        end

        -- Load in default config, used if none is returned from script.
        refreshSiteConfig()

		if launchScriptName then
            log(string.format("Found possible launch script for site : '%s'.", launchScriptName), LogLevelMap.INFO)

			local status
			status, errorExecutingScript = pcall(tryExecutingLaunchScript, launchScriptName)

			if not status then
				-- Error loading launch script, load default route map and config.
				refreshSiteConfig()
				routeMap = RouteMap(siteConfig.fileServingEnabled, siteConfig.directoryServingEnabled)

				log(errorExecutingScript, LogLevelMap.ERROR)
				log("Using default route map and default site config due to error while executing launch script", LogLevelMap.WARN)
			elseif not routeMap then
				routeMap = RouteMap(siteConfig.fileServingEnabled, siteConfig.directoryServingEnabled)
            end
		end

		if not routeMap or not launchScriptName then
			-- No launch script found for this site, use default route map to present file system resources or 404.
			routeMap = RouteMap(siteConfig.fileServingEnabled, siteConfig.directoryServingEnabled)

			if isDefaultSite then
				routeMap.addRoute(DEFAULT_SITE_ROUTE)
			end
		end

		log(string.format("Attempting to load launch script took %s ms.", timer.endTimeNow()), LogLevelMap.DEBUG)

		if errorExecutingScript then
			return errorExecutingScript
		end
	end

    --- Set the server logging level back to it original value before site request.
	local function applyServerLoggingConfig ()
		if siteConfig.logging.siteLoggingEnabled and siteConfig.logging.logLevel == nil then
			-- Nothing to do, no custom directives for site.
			return
		end

		ServerConfig.logging.maxLogLevel = originalServerLogLevel
	end

    --- Set the server logging level to the site logging level.
	local function applySiteLoggingConfig ()
		if siteConfig.logging.siteLoggingEnabled and siteConfig.logging.logLevel == nil then
			-- Nothing to do, no custom directives for site.
			return
		end

		originalServerLogLevel = ServerConfig.logging.maxLogLevel

		if not siteConfig.logging.siteLoggingEnabled then
			ServerConfig.logging.maxLogLevel = "NONE"
		elseif type(siteConfig.logging.logLevel) == Types._string_ then
			ServerConfig.logging.maxLogLevel = siteConfig.logging.logLevel
		end
	end

	--- Process given server state using provided client connection,
	--  site URL routes and session data (if enabled in site config).
	--
	-- @param clientDataPipe HttpDataPipe object produced upon client connection.
	-- @param serverState Table containing details on the current server state.
    --
	local function processServerState(clientDataPipe, serverState)
		validateParameters(
			{
				clientDataPipe = {clientDataPipe, Types._table_},
				serverState = {serverState, Types._table_}
			}, "Site.processServerState")

		local timer = Timer();

        -- Remove root URL from request location.
        serverState.location = formatHttpLocation(serverState.location)
		-- Store any error's detected when loading launch script.
		serverState.errWithLaunchScript = loadLaunchScriptIfPresent()

		applySiteLoggingConfig()

		-- Add client handler if not in existing handlers.
		local clientHandler = ClientRequestHandler(routeMap, siteConfig, urlNamespace)

        local status, errOrState = pcall(clientHandler.serve, clientDataPipe, serverState)

		if not status then
			local err = errOrState

			log(string.format("Client handler threw an error (%s), server state:\n%s\n",
					err,
					Serialization.serializeToJson(serverState, true)), LogLevelMap.ERROR)
		else
			local state = errOrState
			local connectionHeader = state.request.headers["Connection"]

            if connectionHeader then
			    serverState.keepConnectionAlive = connectionHeader:lower() == "keep-alive"
            else
                serverState.keepConnectionAlive = false
            end

            -- Clean up any error messages returned, removing full stack traces already printed in logs.
            if serverState.serverErr then
            	serverState.serverErr = serverState.serverErr:match([[(.*)stack traceback:]]) or serverState.serverErr
            end

            if serverState.serverError then
                serverState.serverError = serverState.serverError:match([[(.*)stack traceback:]]) or serverState.serverError
            end

            if serverState.errWithLaunchScript then
            	serverState.errWithLaunchScript = serverState.errWithLaunchScript:match([[(.*)stack traceback:]]) or serverState.errWithLaunchScript
           	end

			log(string.format("Client handler OK, HTTP Code -> %s, server state:\n%s\n", state.response.status,
					Serialization.serializeToJson(serverState, true)), LogLevelMap.INFO)
		end

		log(string.format("Processing server state took %s ms.", timer.endTimeNow()), LogLevelMap.DEBUG)

		applyServerLoggingConfig()
	end

	local function construct ()
		if urlNamespace ~= "/" then
			rootUrl = string.format("%s://", transportProtocol) ..
				(string.format("%s/%s/", "*", urlNamespace):gsub("//", "/")):lower()
		else
			rootUrl =  string.format("%s://", transportProtocol) ..
				(string.format("%s/", "*"):gsub("//", "/")):lower()
		end

		-- Throw error if root URL does not match generic pattern.
		if not rootUrl:match("^.+://.+/$") then
			error(string.format(ROOT_ERR_MSG, rootUrl, urlNamespace))
		end

		-- Build file system path for file handling and launch script execution.
		fileSystemPath = fullPath and fullPath:gsub([[\]], "/"):gsub("//", "/")
				or (string.format("%s/%s", ServerConfig.htmlDirectory:gsub([[\]], "/"), urlNamespace):gsub("//", "/"))

		-- Site related configuration.
		formattedNamespaceName = string.format("Namespace '%s' | ", urlNamespace)
		refreshSiteConfig()

		local launchScriptErr = loadLaunchScriptIfPresent()

		if launchScriptErr then
			log(string.format("Error loading launch script - %s", launchScriptErr), LogLevelMap.ERROR)
		end

		return
		{
			urlNamespace = urlNamespace,
			rootUrl = rootUrl,
			transportProtocol = transportProtocol,
			getSiteConfig = getSiteConfig,
			getRouteMap = getRouteMap,
			setRoutes = setRoutes,
			isOnSite = isOnSite,
			processServerState = processServerState
		}
	end

	return construct()
end

return Site
