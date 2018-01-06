--- Starts a client thread that processes client requests as recieved 
-- from the given data pipe. The client data pipe is obtained by either 
-- popping from a thread queue or by directly passing the socket object/fd.
--
-- @param threadId Id of the thread that function is running on.
-- @param threadQueue optional Thread queue that has one client socket pushed onto it.
-- @param sessionThreadQueue Thread queue to use to get session data.
-- @param socket optional Client socket to use when processing request.
-- @param useHttps Use HTTPS when communicating with clients.
--
local function clientRequestThreadEntryPoint (threadId, threadQueue, sessionThreadQueue, socket, useHttps)
	-- in new thread, need to get dependencies when executed instead of when included
	local log = require "PuRest.Logging.FileLogger"
	local LogLevelMap = require "PuRest.Logging.LogLevelMap"
	local try = require "PuRest.Util.ErrorHandling.try"
	local Types = require "PuRest.Util.ErrorHandling.Types"
	local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

	-- Validate function parameters.
	validateParameters(
		{
			threadId = {threadId, Types._number_},
			sessionThreadQueue = {sessionThreadQueue, Types._userdata_},
			useHttps = {useHttps, Types._boolean_}
		}, "clientRequestThreadEntryPoint")

	if threadQueue then
		validateParameters(
			{
				threadQueue = {threadQueue, Types._userdata_}
			}, "clientRequestThreadEntryPoint")
	elseif not socket then
		error("clientRequestThreadEntryPoint requires a value for either the threadQueue or socket parameter.")
	end

	local outputVariables = 
	{
		clientDataPipe = nil,
		peername = nil
	}
	
	try(function() 
		local processServerState = require "PuRest.Server.processServerState"
		
		processServerState(threadId, threadQueue, sessionThreadQueue, socket, useHttps, outputVariables)
	end).
	catch(function(err)
		-- Detect any errors that occurred outside the main HTTP request loop.
		log(string.format("Error while running thread with id %d: %s", threadId, err), LogLevelMap.ERROR)

		if clientDataPipe then
			log(string.format("Attempting to close socket connection with client '%s' after error on thread with id %d",
				peername, threadId), LogLevelMap.INFO)
		
			pcall(clientDataPipe.terminate)
		end
	end).
	finally(function()
		-- increase worker thread semaphore
	end)
end

return clientRequestThreadEntryPoint