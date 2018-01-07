return
{
	-- Address
	host = "*",
	port = 8888,

	-- Threading
	workerThreads = 50,

	-- Socket parameters
	connectionBacklog = 50,
	connectionTimeOutInMs = 15, -- (Not used as of rev.107)
	httpKeepAliveTimeOutInSecs = 60,
	socketSendBufferSize = 16384, -- Client send buffer (Not supported for HTTPS as of rev.165)
	socketReceiveBufferSize = 8192, -- Server receive buffer

	-- HTTPS
	https =
	{
		enabled = true,
		port = 4430,
		encryption = "tlsv1_1",
		enableSSL = false,
		key = (os.getenv("PUREST_WEB") or os.getenv("PUREST")) .. [[/key.pem]],
		certificate = (os.getenv("PUREST_WEB") or os.getenv("PUREST")) .. [[/cert.pem]]
	},

	-- Server Side Caching
	enableSiteCache = true,
	siteCacheExpiryInSecs = 15,
	enableFileCache = true,
	fileCacheMinFileSizeInMb = 1.25,
	fileCacheMaxFileSizeInMb = 150,

	-- Error template
	systemTemplate = require "PuRest.Html.SystemTemplate",

	-- App loading
	htmlDirectory = os.getenv("PUREST_WEB") or os.getenv("PUREST"),
    siteNamesCaseSensitive = false,
	launchScriptNames = {"index.lua", "launch.lua", "init.lua"},

	-- HTTP compression
	supportHttpCompression = true,
	httpCompressionLevel = 3,
    httpCompressionMinContentSizeInBytes = 1024,

	-- PHP support
	phpBinPath = os.getenv("PUREST_PHP") or "php",

	-- App config
	siteDefaults = require "PuRest.Config.DefaultSiteConfig",

	-- Logging
	logging =
	{
		-- TODO: consider allow using different log classes here (i.e. file or stdout)
		logPath = os.getenv("PUREST_WEB") or os.getenv("PUREST"),
		maxLogFileSize = 1024,
        clearDownIntervalInSecs = 60,
		maxLogLevel = "DEBUG"
	}
}
