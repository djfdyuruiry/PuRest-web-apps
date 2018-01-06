local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

--- Validate the given server config.
--
-- @param config The server config table to validate.
-- @return True if config validates OK, otherwise false and a string containing an error.
--
local function validateServerConfig (serverConfig)
	return pcall(validateParameters,
		{
			config = { serverConfig, Types._table_},
			host = { serverConfig.host, Types._string_},
			port = { serverConfig.port, Types._number_},
			workerThreads = { serverConfig.workerThreads, Types._number_},
			connectionBacklog = { serverConfig.connectionBacklog, Types._number_},
			connectionTimeOutInMs = { serverConfig.connectionTimeOutInMs, Types._number_},
			httpKeepAliveTimeOutInSecs = { serverConfig.httpKeepAliveTimeOutInSecs, Types._number_},
			socketSendBufferSize = { serverConfig.socketSendBufferSize, Types._number_},
			socketReceiveBufferSize = { serverConfig.socketReceiveBufferSize, Types._number_},
			https = { serverConfig.https, Types._table_},
			https_enabled = { serverConfig.https.enabled, Types._boolean_},
			https_encryption = { serverConfig.https.encryption, Types._string_},
			https_enableSSL = { serverConfig.https.enableSSL, Types._boolean_},
			https_key = { serverConfig.https.key, Types._string_},
			https_certificate = { serverConfig.https.certificate, Types._string_},
			enableSiteCache = { serverConfig.enableSiteCache, Types._boolean_},
			siteCacheExpiryInSecs = { serverConfig.siteCacheExpiryInSecs, Types._number_},
			enableFileCache = { serverConfig.enableFileCache, Types._boolean_},
			fileCacheMinFileSizeInMb = { serverConfig.fileCacheMinFileSizeInMb, Types._number_},
			fileCacheMaxFileSizeInMb = { serverConfig.fileCacheMaxFileSizeInMb, Types._number_},
			systemTemplate = { serverConfig.systemTemplate, Types._string_},
			htmlDirectory = { serverConfig.htmlDirectory, Types._string_},
            siteNamesCaseSensitive = { serverConfig.siteNamesCaseSensitive, Types._boolean_},
			launchScriptNames = { serverConfig.launchScriptNames, Types._table_},
			supportHttpCompression = { serverConfig.supportHttpCompression, Types._boolean_},
			httpCompressionLevel = { serverConfig.httpCompressionLevel, Types._number_},
            httpCompressionMinContentSizeInBytes = { serverConfig.httpCompressionMinContentSizeInBytes, Types._number_},
			logging = { serverConfig.logging, Types._table_},
			logging_logPath = { serverConfig.logging.logPath, Types._string_},
			logging_maxLogFileSize = { serverConfig.logging.maxLogFileSize, Types._number_},
			logging_maxLogLevel = { serverConfig.logging.maxLogLevel, Types._string_},
            logging_clearDownIntervalInSecs = { serverConfig.logging.clearDownIntervalInSecs, Types._number_},
			siteDefaults = {serverConfig.siteDefaults, Types._table_}
		}, "validateServerConfig")
end

--- Validate the given site config.
--
-- @param config The site config table to validate.
-- @return True if config validates OK, otherwise false and a string containing an error.
--
local function validateSiteConfig (siteConfig)
	if not siteConfig then
		return pcall(validateParameters,
			{
				siteConfig = {siteConfig, Types._table_ }
			}, "validateSiteConfig")
	end

	return pcall(validateParameters,
		{
			siteConfig_name = {siteConfig.name, Types._string_},
			siteConfig_hostWhitelist = {siteConfig.hostWhitelist, Types._table_},
			siteConfig_fileServingEnabled = {siteConfig.fileServingEnabled, Types._boolean_},
			siteConfig_directoryServingEnabled = {siteConfig.directoryServingEnabled, Types._boolean_},
			siteConfig_doNotServeTheseFiles = {siteConfig.doNotServeTheseFiles, Types._table_},
			siteConfig_sessions = {siteConfig.sessions, Types._table_},
			siteConfig_sessions_peerNameSessionsEnabled = {siteConfig.sessions.peerNameSessionsEnabled, Types._boolean_},
			siteConfig_sessions_userAgentSessionsEnabled = {siteConfig.sessions.userAgentSessionsEnabled, Types._boolean_},
			siteConfig_routes = {siteConfig.routes, Types._table_},
			siteConfig_routes_useReturnValueAsContent = {siteConfig.routes.useReturnValueAsContent, Types._boolean_},
			siteConfig_routes_serializeHandlerReturnValue = {siteConfig.routes.serializeHandlerReturnValue, Types._boolean_},
			siteConfig_routes_appendReturnValueToContent = {siteConfig.routes.appendReturnValueToContent, Types._boolean_},
			siteConfig_authentication = {siteConfig.authentication, Types._table_},
			siteConfig_authentication_enableAuthentication = {siteConfig.authentication.enableAuthentication, Types._boolean_},
			siteConfig_authentication_requireAuthenticationEverywhere = {siteConfig.authentication.requireAuthenticationEverywhere, Types._boolean_},
			siteConfig_authentication_securityProvider = {siteConfig.authentication.securityProvider, Types._table_},
			siteConfig_authentication_authenticationRouteMap = {siteConfig.authentication.authenticationRouteMap, Types._table_},
			siteConfig_logging = {siteConfig.logging, Types._table_},
			siteConfig_logging_siteLoggingEnabled = {siteConfig.logging.siteLoggingEnabled, Types._boolean_}
		}, "validateSiteConfig")
end

--- Validate the given config; return value is true if config validates OK, otherwise false
-- and a string containing an error.
--
-- @param config The config table to validate.
-- @return True if config validates OK, otherwise false and a string containing an error.
--
local function validateConfig (config)
	local validateStatus, validateErr = validateServerConfig(config)

	if validateStatus then
		-- Server config is OK, check the site default config
		validateStatus, validateErr = validateSiteConfig(config.siteDefaults)
	end

	return validateStatus, validateErr
end

return
{
	validateConfig = validateConfig,
	validateServerConfig = validateServerConfig,
	validateSiteConfig = validateSiteConfig
}
