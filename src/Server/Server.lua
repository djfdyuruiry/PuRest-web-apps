local JSON = require "JSON"

local convertClientSocketFileDescriptorToHttpDataPipe = require "PuRest.Util.Networking.convertClientSocketFileDescriptorToHttpDataPipe"
local clientRequestThreadEntryPoint = require "PuRest.Server.clientRequestThreadEntryPoint"
local HttpDataPipe = require "PuRest.Http.HttpDataPipe"
local log = require "PuRest.Logging.FileLogger"
local LogLevelMap = require "PuRest.Logging.LogLevelMap"
local registerSignalHandler = require "PuRest.Util.System.registerSignalHandler"
local Semaphore = require "PuRest.Util.Threading.Semaphore"
local SessionData = require "PuRest.State.SessionData"
local ServerConfig = require "PuRest.Config.resolveConfig"
local Thread = require "PuRest.Util.Threading.Thread"
local ThreadSlots = require "PuRest.Util.Threading.ThreadSlots"
local ThreadSlotSemaphore = require "PuRest.Util.Threading.ThreadSlotSemaphore"
local try = require "PuRest.Util.ErrorHandling.try"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

local THREAD_TIMEOUT_IN_SECS = 300 -- 5 minutes

--- A web server using the Data Pipe abstraction as the HTTP comms API.
--
-- @param enableHttps Use HTTPS when communciation with clients.
--
local function Server (enableHttps)
	--- Basic settings, loaded from configuration file.
	local useHttps = type(enableHttps) == Types._boolean_ and enableHttps or false
    local serverType = useHttps and "HTTPS" or "HTTP"

	local host = ServerConfig.host
	local port = useHttps and ServerConfig.https.port or ServerConfig.port
    local serverLocation = string.format("%s:%d", host, port)

	--- Advanced server settings.
	local serverRunning = false
	local reasonForShutdown

	--- Server management objects.
	local serverDataPipe, clientSocket

	--- Mutlithreading objects.
    local threads = ServerConfig.workerThreads > 1 and {} or nil
    
    local threadQueue = ServerConfig.workerThreads > 1 and Semaphore() or nil
	local sessionThreadQueue = SessionData.getThreadQueue()

    local function cleanThreadIfDead (thread, threadIndex, threadSlots)
        local threadIsAlive = thread.isAlive()
        local threadId = thread.getThreadId()
        
        log(string.format("Thread %s is alive? %s", threadId, threadIsAlive), LogLevelMap.DEBUG)

        local secondsRunning = thread.getSecondsSinceStart()
        local threadHasBeenRunningForTooLong = secondsRunning > THREAD_TIMEOUT_IN_SECS

        if threadIsAlive and not threadHasBeenRunningForTooLong then
            return
        end
    
        local threadError = thread.getThreadError()

        if threadError then
            log(string.format("Thread %d terminated due to error: %s", threadId, threadError), 
                LogLevelMap.ERROR)
        elseif threadIsAlive and threadHasBeenRunningForTooLong then
            log(string.format("Thread %d has been running for too long (%ds), killing thread", 
                threadId, secondsRunning), LogLevelMap.DEBUG)
        else
            log(string.format("Thread %d has finished", threadId),
                LogLevelMap.DEBUG)
        end
        
        log(string.format("Cleaning dead thread %d", threadId), LogLevelMap.DEBUG)

        thread.safeStop()

        table.remove(threads, threadIndex)

        ThreadSlots.markSlotsAsFree(threadSlots, tonumber(threadId))
    end

    --- Clean any dead threads and donate the id's of dead threads
    -- back to the pool
    --
	local function cleanDeadThreads ()
        local threadSlots = ThreadSlotSemaphore.getThreadSlots()

		for idx, thread in ipairs(threads) do
			if thread then
                cleanThreadIfDead(thread, idx, threadSlots)
			end
        end
        
        ThreadSlotSemaphore.setThreadSlots()
    end

    --- Shutdown the server
    local function stopServer (err, stackTrace)
        local errorMessage

        if err then
            errorMessage = string.format("Terminating server due to error: %s | %s", 
                tostring(err), 
                JSON:encode(stackTrace))
        end
            
        local reason = err and errorMessage or "Server is shutting down"

        serverRunning = false

        reasonForShutdown = tostring(reason or "unknown reason")
        log(string.format("%s server on %s has been shutdown: %s..", 
            serverType, 
            serverLocation, 
            reasonForShutdown), LogLevelMap.WARN)

        if serverDataPipe then
            pcall(serverDataPipe.terminate)
            serverDataPipe = nil
        end
    end

    local function waitForClientAndProcessRequest ()
        local err
        clientSocket, err = serverDataPipe:waitForClient()

        if not clientSocket or err then
            error(err)
        end
        
        log(string.format("%s server on %s Accepted connection with client on fd '%s'.",
            serverType, serverLocation, tostring(clientSocket)), LogLevelMap.INFO)

        if ServerConfig.workerThreads < 1 then
            -- multiple worker threads disabled in configuration, process request in server thread
            processServerState(1, nil, sessionThreadQueue, clientSocket, useHttps)
            return
        end

        -- prepare for new worker thread
        cleanDeadThreads()

        local threadSlots = ThreadSlotSemaphore.getThreadSlots()
        local threadId = ThreadSlots.reserveFirstFreeSlot(threadSlots)

        ThreadSlotSemaphore.setThreadSlots()

        -- multiple worker threads enabled in configuration, process request in the background
        local thread = Thread(clientRequestThreadEntryPoint, tostring(threadId))

        thread.start(threadId, threadQueue.getThreadQueue(), sessionThreadQueue, clientSocket, useHttps)

        table.insert(threads, thread)
        
        -- clear clientSocket, not needed for error handling
        clientSocket = nil
    end

	--- Start listening for clients and accepting requests; this method blocks.
	--
    -- @return The reason the server was shutdown.
    --
    local function startServer ()
        serverDataPipe = HttpDataPipe({host = host, port = port})

        local interruptMsg = "you may kill this server by hitting CTRL+C to interrupt the process"
		log(string.format("Running %s web server on %s, %s.", serverType, serverLocation, interruptMsg), LogLevelMap.INFO)

        serverRunning = true

		while serverRunning do
            try(function()
                waitForClientAndProcessRequest()
            end)
            .catch (function (ex)
                log(string.format("Error occurred when connecting to client / processing client request: %s.", ex),
                    LogLevelMap.ERROR)

                if clientSocket then
                    pcall(function ()
                        local dataPipe = convertClientSocketFileDescriptorToHttpDataPipe(clientSocket)
                        dataPipe.terminate()
                    end)
                    
                    -- clear clientSocket, reset for next listenForClients call
                    clientSocket = nil
                end
            end)
		end

		log(string.format("%s server on %s has been stopped for the following reason: %s", serverType, serverLocation,
				(reasonForShutdown or "No reason given!")), LogLevelMap.WARN)

        if serverDataPipe then
            log(string.format("Closing server port for %s server on %s", serverType, serverLocation), 
                LogLevelMap.INFO)

			pcall(serverDataPipe.terminate)
        end

        return reasonForShutdown
	end

	--- Is the server running?
	--
    -- @return Is the server running?
    --
	local function isRunning ()
		return serverRunning
    end

    --- Create object, handlers for interrupt and terminate handlers are
    -- attached here to enable cleanup of server socket before process end.
    local function construct ()
        if ServerConfig.workerThreads > 1 then
            threadQueue.setLimit(ServerConfig.workerThreads)
        end

        return
        {
            host = host,
            port = port,
            startServer = startServer,
            stopServer = stopServer,
            isRunning = isRunning
        }
    end

    return construct()
end

return setmetatable({
    PUREST_VERSION = "0.6"
},
{
    __call = function(_, enableHttps)
        return Server(enableHttps)
    end
})
