local md5 = require "md5"

local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

--- Build an session identifier from plain text and generate a
-- MD5 hash of this new identifier.
--
-- @param sessionIdentifier Plain text session identifier, host:port or host:userAgent.
-- @param siteName Name of the site holding the session.
-- @return MD5 hash of new session id and the new session id in plain text.
--
local function getSessionId (sessionIdentifier, siteName)
	validateParameters(
		{
			sessionIdentifier = {sessionIdentifier, Types._string_},
			siteName = {siteName, Types._string_}
		},
		"getSessionId")

	local sessionId = string.format("%s|%s", siteName, sessionIdentifier)

	return md5.sum(sessionId), sessionId
end

return getSessionId
