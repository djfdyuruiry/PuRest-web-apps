local mime = require("mime")

local AuthenticationTypes = require "PuRest.Security.AuthenticationTypes"
local LogLevelMap = require "PuRest.Logging.LogLevelMap"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

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
        }, "extractAuthenticationData")

	if requestHeaders["Authorization"] then
		if requestHeaders["Authorization"]:match(AuthenticationTypes.Basic) then
			logProxyFunction("Detected basic HTTP authentication.", LogLevelMap.INFO)

			local base64Data = requestHeaders["Authorization"]:match("Basic (.+)")
			local data = mime.unb64(base64Data)
			local userName, password = data:match("(.+):(.+)")

			return
			{
				userName = userName,
				password = password
			}
		elseif requestHeaders["Authorization"]:match(AuthenticationTypes.Digest) then
			logProxyFunction("Detected digest HTTP authentication.", LogLevelMap.INFO)

			local user = requestHeaders["Authorization"]:match([[username="([^\"]+)"]])
			local uri = requestHeaders["Authorization"]:match([[uri="([^\"]+)"]])
			local nc = requestHeaders["Authorization"]:match([[nc=([0-9]+)]])
			local nonce = requestHeaders["Authorization"]:match([[nonce="([^\"]+)"]])
			local cnonce = requestHeaders["Authorization"]:match([[cnonce="([^\"]+)"]])
			local response = requestHeaders["Authorization"]:match([[response="([^\"]+)"]])

			return
			{
				userName = user,
				requestMethod = method,
				requestPath = uri,
				nc = nc,
				nonce = nonce,
				cnonce = cnonce,
				response = response
			}
		end
	end

	logProxyFunction("No HTTP authentication Detected ('Authorization' HTTP header not present in request).", LogLevelMap.INFO)

	return nil
end

return extractAuthenticationData
