local date = require "date"
local md5 = require "md5"

local AuthenticationTypes = require "PuRest.Security.AuthenticationTypes"
local LogLevelMap = require "PuRest.Logging.LogLevelMap"
local try = require "PuRest.Util.ErrorHandling.try"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

--- Allows a site to provide HTTP authentication to use when a user
-- request comes in. Override the authorize method to validate incoming
-- authorization requests, this is neccessary as the security provider
-- has no knowledge of you usernames/passwords or where to get them.
--
-- Also the onUnauthorized method can be overriden to provide a hook when
-- a client is marked as unauthorized during the authentication process;
-- this is executed after the authroize handler.
--
-- @param realm String to provide to clients as the site's realm.
-- @param authenticationType HTTP authentication scheme to follow.
--
local function SecurityProvider (realm, authenticationType)
	local self = {}

	self.realm = realm and realm or "localhost"
	self.authenticationType = authenticationType and authenticationType or AuthenticationTypes.Basic

	--- Handler called to determine if a user should be authorized, should be overwritten when
	-- class is instantiated.
	--
	-- @param authorizationData Table containing data for current authorization request. This will be
	--                          either the user name and password for Basic authentication and Digest
	--                          will have user name plus digest components (nonce, cnonce, uri, nc and
	--                          response digest).
	-- @param httpState HttpState object detailing current state.
	-- @return For Basic return boolean of user/password combination check and
	--         for Digest check user exists then return true and password or false.
	self.authorize = function (authorizationData, httpState)
		return false
	end

	--- Handler called when a user is unauthorized, should be overwritten when
	-- class is instantiated.
	--
	-- @param authorizationData Table containing data for current authorization request. This will be
	--                          either the user name and password for Basic authentication and Digest
	--                          will have user name plus digest components (nonce, cnonce, uri, nc and
	--                          response digest).
	-- @param httpState HttpState object detailing current state.
	self.onUnauthorized = function (authorizationData, httpState)
	end

	--- Build an MD5 digest for use with Digest authentication.
	-- @param authorizationData Table containing data for current authorization request. This will be
	--                          either the user name and password for Basic authentication and Digest
	--                          will have user name plus digest components (nonce, cnonce, uri, nc and
	--                          response digest).
	-- @param realm String to provide to clients as the site's realm.
	-- @param logProxyFunction Function that takes log messages and appends site details.
	--
	local function buildDigest(authorizationData, realm, logProxyFunction)
        validateParameters(
            {
                authorizationData = {authorizationData, Types._table_},
                realm = {realm, Types._string_},
                logProxyFunction = {logProxyFunction, Types._function_}
            })

		local a1 = string.format("%s:%s:%s", authorizationData.userName, realm, authorizationData.password)
		local a2 = string.format("%s:%s", authorizationData.requestMethod, authorizationData.requestPath)

		local digest = string.format("%s:%s:%s:%s:%s:%s", md5.sum(a1), authorizationData.nonce, authorizationData.nc,
			authorizationData.cnonce, "auth", md5.sum(a2))

		digest = md5.sum(digest)

		logProxyFunction(string.format("Digest Security info - a1: '%s', a2: '%s', digest: '%s'", a1, a2, digest), LogLevelMap.DEBUG)

		return digest
	end

	---
	-- @return A random MD5 nonce for use with digest authentication.
	local function generateNonce()
		local timestamp = date():fmt("${http}")
		local loops = math.random(50, 100)
		local pk = ""

		for _ = 0, loops do
			pk = pk .. string.char(math.random(127))
		end

		return md5.sum(string.format("%s:%s", timestamp, pk))
	end

	--- Handle if a user has been marked as unauthorized by sending WWW-Authenticate header
	-- back to the client with relevant details.
	-- @param httpState HttpState object with current request/response state.
	-- @param authorizationData optional Table containing data for current authorization request. This will be
	--                                   either the user name and password for Basic authentication and Digest
	--                                   will have user name plus digest components (nonce, cnonce, uri, nc and
	--                                   response digest).
	-- @param realm String to provide to clients as the site's realm.
	-- @param logProxyFunction Function that takes log messages and appends site details.
	--
	local function handleUnauthorized(httpState, authorizationData, realm, logProxyFunction)
        validateParameters(
            {
                httpState = {httpState, Types._table_},
                realm = {realm, Types._string_},
                logProxyFunction = {logProxyFunction, Types._function_}
            })

		if authorizationData then
			logProxyFunction(string.format("Unable to authorize User '%s'.", authorizationData.userName), LogLevelMap.INFO)
		else
			logProxyFunction("Authorization data not passed via request headers, could be inital request from client.", LogLevelMap.INFO)
		end

		httpState.response.status = 401

		logProxyFunction("Sending 401 unauthorised HTTP response with 'WWW-Authenticate' header.", LogLevelMap.INFO)

		if self.authenticationType == AuthenticationTypes.Basic then
			httpState.response.headers["WWW-Authenticate"] = string.format([[Basic realm="%s"]], self.realm and self.realm or httpState.request.host)
		elseif self.authenticationType == AuthenticationTypes.Digest then
			httpState.response.headers["WWW-Authenticate"] = string.format([[Digest realm="%s", qop="auth", nonce="%s"]],
				realm, generateNonce())
		end

		if type(self.onUnauthorized) == "function" then
			logProxyFunction("Calling unauthorized handler.")

			try( function()
				self.onUnauthorized(authorizationData, httpState)
			end)
			.catch( function(e)
				logProxyFunction(string.format("Error calling unauthorized handler: %s", e), LogLevelMap.ERROR)
			end)
		else
			logProxyFunction("Attempted to call unauthorized handler, however current value is not a function.")
		end
	end

	--- Attempt to authenticate a user for the current request.
	--
	-- @param httpState HttpState object representing the current request/response state.
	-- @param logProxyFunction Function that takes log messages and appends site details.
	-- @return Was the user for the request authenticated?
	--
	self.authenticate = function (httpState, logProxyFunction)
        validateParameters(
            {
                httpState = {httpState, Types._table_},
                logProxyFunction = {logProxyFunction, Types._function_}
            })

        local authorizationData = httpState.request.authorizationData
		local realm = self.realm and self.realm or httpState.request.host
		local authorized  = false
		local password

		if type(self.authorize) == "function" then
			logProxyFunction("Calling authorize handler.")

			try( function()
				authorized, password = self.authorize(authorizationData, httpState)
			end)
			.catch( function(e)
				authorized, password = false, nil
				logProxyFunction(string.format("Error calling authorize handler: %s", e), LogLevelMap.ERROR)
			end)
		else
			logProxyFunction("Attempted to call authroize handler, however current value is not a function.")
		end

		if self.authenticationType == AuthenticationTypes.Digest and authorized and password then
			-- Do Digest calculation and set authorized based on outcome.
			if not authorizationData then
				authorized = false
			end

			authorizationData.password = password

			authorized = buildDigest(authorizationData, realm, logProxyFunction) == authorizationData.response
		end

		if not authorized then
			handleUnauthorized(httpState, authorizationData, realm, logProxyFunction)
			return false
		end

		if self.authenticationType == AuthenticationTypes.Digest then
			httpState.response.headers["Authentication-Info"] = string.format([[nextnonce="%s"]], generateNonce())
		end

		logProxyFunction(string.format("Authorized user '%s'.", httpState.request.authorizationData.userName), 
			LogLevelMap.INFO)

		return true
	end

	return self
end

return SecurityProvider
