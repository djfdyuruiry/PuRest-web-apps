return
{
	-- Details
	name = "",
	fullPath = "/",

	-- Address
	hostWhitelist = {{"*", false}},

	-- File Serving
	fileServingEnabled = true,
	directoryServingEnabled = true,
	doNotServeTheseFiles = {"*.lua"},

	-- Session handling
	sessions =
	{
		timeoutInMins = 60,
		peerNameSessionsEnabled= true,
		userAgentSessionsEnabled= true
	},

	-- Route handling
	routes =
	{
		useReturnValueAsContent = true,
		serializeHandlerReturnValue = true,
		appendReturnValueToContent = false
	},

	-- Security
	authentication =
	{
		enableAuthentication = false,
		requireAuthenticationEverywhere = false,
		securityProvider = {},
		authenticationRouteMap = {}
	},

	-- Log site messages
	logging =
	{
		siteLoggingEnabled = true,
		logLevel = nil
	}
}
