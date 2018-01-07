local FileLogReader = require "PuRest.Logging.FileLogReader"
local generateSiteConfig = require "PuRest.Config.generateSiteConfig"
local LogFiles = require "PuRest.Logging.LogFiles"
local ProcessMonitor = require "PuRest.Util.System.ProcessMonitor"
local processView = require "PuRest.View.processView"
local restAction = require "PuRest.Rest.restAction"
local RouteMap = require "PuRest.Routing.RouteMap"
local ServerConfig = require "PuRest.Config.resolveConfig"
local Route = require "PuRest.Routing.Route"

local function index (_, _, httpState, siteConfig)
	httpState.response.responseFormat = "text/html"

	return processView("index", nil, siteConfig)
end

local function getPerformanceData (_, _, httpState)
    return restAction( function (result)
        result.data = ProcessMonitor.getStats()
    end, httpState)
end

local function getServerLog (_, _, httpState)
    return restAction( function (result)
        result.data = FileLogReader.getMessagesFromLogFile(
            FileLogReader.getLogFilePath(LogFiles.server))
    end, httpState)
end

local function getWorkerLog (urlArgs, _, httpState)
    return restAction( function (result)
        local i = urlArgs["workerNo"]
        result.data = FileLogReader.getMessagesFromLogFile(
            FileLogReader.getLogFilePath(string.format(LogFiles.worker, i)))
    end, httpState)
end

local function getNumWorkerThreads (_, _, httpState)
    return restAction( function (result)
        result.data = ServerConfig.workerThreads
    end, httpState)
end

local routes = RouteMap(true, true)

routes.addRoute(Route("index", "GET", "/", index))
routes.addRoute(Route("performance", "GET", "/api/performance", getPerformanceData))
routes.addRoute(Route("performance", "GET", "/api/getworkerthreads", getNumWorkerThreads))
routes.addRoute(Route("performance", "GET", "/api/logs/server", getServerLog))
routes.addRoute(Route("performance", "GET", "/api/logs/worker/{workerNo}", getWorkerLog))


-- Get copy of default site config.
local siteConfig = generateSiteConfig(true)
siteConfig.name = "PuRest Admin App"
siteConfig.loggingEnabled = false
siteConfig.directoryServingEnabled = false

return
{
	routeMap = routes,
	siteConfig = siteConfig
}
