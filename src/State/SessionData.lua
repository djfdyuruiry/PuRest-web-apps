local getSession = require "PuRest.State.getSession"
local Semaphore = require "PuRest.Util.Threading.Semaphore"
local setSessionData = require "PuRest.State.setSession"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

--- Sessions store semaphore to share sessions across
-- worker threads on server.
local sessionsSemaphore = Semaphore(nil,
	{
		clientSessions = {},
		userAgentSessions = {}
	}
)

--- Get the underlying thread queue for the sessions store.
--
-- @return The thread queue for the session semaphore.
--
local function getThreadQueue ()
	return sessionsSemaphore.getThreadQueue()
end

--- Set the thread queue to be used by the sessions store.
--
-- @param threadQueue Thread queue to use in the sessions semaphore.
--
local function setThreadQueue (threadQueue)
	validateParameters(
		{
			threadQueue = {threadQueue, Types._userdata_}
		}, "SessionData.setThreadQueue")

	sessionsSemaphore = Semaphore(threadQueue)
end

--- Create a formatted session id for user agent based session.
--
-- @param clientPeerName Client host name.
-- @param userAgent Client user agent string.
-- @return A plain text identifer for a user agent session.
--
local function createUserAgentId (clientPeerName, userAgent)
	return string.format("%s:%s", clientPeerName, userAgent)
end

--- Create a formatted session id for a peer name based session.
--
-- @param clientPeerName Client host name.
-- @param clientPort Client port.
-- @return A plain text identifer for a peer name session.
--
local function createPeerNameId(clientPeerName, clientPort)
	return string.format("%s:%s", clientPeerName, clientPort)
end

--- Resolves the session data for a request by user agent/peer name values.
-- Site config is used to determine supported session types and if a user
-- agent string is present and user sessions are enabled it is used over a peer
-- name session.
--
-- @param userAgent optional Client user agent string.
-- @param clientPeerName Client peer name / host.
-- @param clientPort Client port.
-- @param siteConfig Config for site requesting session data.
-- @return Session data table and ID for session in sessions store.
--
local function resolveSessionData (userAgent, clientPeerName, clientPort, siteConfig)
	validateParameters(
		{
			clientPeerName = {clientPeerName, Types._string_},
            clientPort = {clientPort, Types._string_},
			siteConfig = {siteConfig, Types._table_}
		}, "SessionData.resolveSessionData")

	local sessions = sessionsSemaphore()
	local clientSessionData, sessionId

	local sessionsEnabled = siteConfig.sessions.peerNameSessionsEnabled
	local userSessionsEnabled = siteConfig.sessions.userAgentSessionsEnabled

	if userSessionsEnabled and userAgent then
		clientSessionData, sessionId = getSession(sessions, createUserAgentId(clientPeerName, userAgent), siteConfig, true)
	elseif sessionsEnabled then
		clientSessionData, sessionId = getSession(sessions, createPeerNameId(clientPeerName, clientPort), siteConfig, false)
	end

	sessionsSemaphore()
    --TODO: Investigate potential issue with session being requested by two threads and result not being merged, but second one to call perserve gets data written.

	return clientSessionData, sessionId
end

--- Perserve the session data for a request by user agent/peer name values.
-- Site config is used to determine supported session types and if a user
-- agent string is present and user sessions are enabled it is used over a peer
-- name session.
--
-- @param sessionData Session data table.
-- @param userAgent optional Client user agent string.
-- @param clientPeerName Client peer name / host.
-- @param clientPort Client port.
-- @param siteConfig Config for site requesting session data.
--
local function preserveSessionData (sessionData, userAgent, clientPeerName, clientPort, siteConfig)
	validateParameters(
		{
			sessionData = {sessionData, Types._table_},
			clientPeerName = {clientPeerName, Types._string_},
            clientPort = {clientPort, Types._string_},
			siteConfig = {siteConfig, Types._table_}
		}, "SessionData.preserveSessionData")

	local sessions = sessionsSemaphore()
	local sessionsEnabled = siteConfig.sessions.peerNameSessionsEnabled
	local userSessionsEnabled = siteConfig.sessions.userAgentSessionsEnabled

	if userSessionsEnabled and userAgent then
		setSessionData(sessions, sessionData, createUserAgentId(clientPeerName, userAgent), siteConfig, true)
	elseif sessionsEnabled then
		setSessionData(sessions, sessionData, createPeerNameId(clientPeerName, clientPort), siteConfig, false)
	end

	sessionsSemaphore()
end

return
{
	getThreadQueue = getThreadQueue,
	setThreadQueue = setThreadQueue,
	resolveSessionData = resolveSessionData,
	preserveSessionData = preserveSessionData
}
