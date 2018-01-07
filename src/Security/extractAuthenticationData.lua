local mime = require("mime")

local AuthenticationTypes = require "PuRest.Security.AuthenticationTypes"
local LogLevelMap = require "PuRest.Logging.LogLevelMap"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

local function extractBasicAuthenticationData (requestHeaders)
	local base64Data = requestHeaders["Authorization"]:match("Basic (.+)")
	local data = mime.unb64(base64Data)
	local userName, password = data:match("(.+):(.+)")

	return
	{
		type = AuthenticationTypes.Basic,
		userName = userName,
		password = password
	}
end

local function extractDigestAuthenticationData (requestHeaders, method)
	local user = requestHeaders["Authorization"]:match([[username="([^\"]+)"]])
	local uri = requestHeaders["Authorization"]:match([[uri="([^\"]+)"]])
	local nc = requestHeaders["Authorization"]:match([[nc=([0-9]+)]])
	local nonce = requestHeaders["Authorization"]:match([[nonce="([^\"]+)"]])
	local cnonce = requestHeaders["Authorization"]:match([[cnonce="([^\"]+)"]])
	local response = requestHeaders["Authorization"]:match([[response="([^\"]+)"]])

	return
	{
		type = AuthenticationTypes.Digest,
		userName = user,
		requestMethod = method,
		requestPath = uri,
		nc = nc,
		nonce = nonce,
		cnonce = cnonce,
		response = response
	}
end

--- Examine HTTP request headers and extract any HTTP authentication data present.
--
-- @param requestHeaders HTTP request headers.
-- @param method HTTP method used in request.
-- @param logProxyFunction Function to use to print log methods.
--
-- @return A table containing HTTP authentication data or nil if no appropriate were headers found.
--
local function extractAuthenticationData (requestHeaders, method, logProxyFunction)
    validateParameters(
        {
            requestHeaders = {requestHeaders, Types._table_},
            method = {method, Types._string_},
            logProxyFunction = {logProxyFunction, Types._function_}
		})
		
	local authorizationHeader = requestHeaders["Authorization"] or ""

	if authorizationHeader:match(AuthenticationTypes.Basic) then
		logProxyFunction("Detected basic HTTP authentication in request", LogLevelMap.INFO)

		return extractBasicAuthenticationData(requestHeaders)
	elseif authorizationHeader:match(AuthenticationTypes.Digest) then
		logProxyFunction("Detected digest HTTP authentication in request", LogLevelMap.INFO)

		return extractDigestAuthenticationData(requestHeaders, method)
	elseif authorizationHeader == "" then
		logProxyFunction("No HTTP Authorization header value in request", LogLevelMap.DEBUG)
	end

	logProxyFunction(string.format("Unsupported HTTP Authorization header value in request: %s", authorizationHeader), 
		LogLevelMap.WARN)

	return nil
end

return extractAuthenticationData
