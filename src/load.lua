local registerSignalHandler = require "PuRest.Util.System.registerSignalHandler"
local try = require "PuRest.Util.ErrorHandling.try"

local function outputServerErrors (serverErrors)
    io.stderr:write("Server terminated with errors:")

    for _, error in ipairs(serverErrors) do
        io.stderr:write(error)
        io.stderr:write()
    end
end

local function startServerWithHttps (serverErrors)
    local SessionData = require "PuRest.State.SessionData"
    local startServer = require "PuRest.Server.startServer"
    local ThreadSlotSemaphore = require "PuRest.Util.Threading.ThreadSlotSemaphore"

    -- Prepare data sharing semaphores.
    local sessionQueue = SessionData.getThreadQueue()
    local threadSlotQueue = ThreadSlotSemaphore.getThreadQueue()

    -- Start HTTPS server.
    local serverThreads = 
    {
        startServer(threadSlotQueue, sessionQueue, false), 
        startServer(threadSlotQueue, sessionQueue, true)
    }

    local cancelThreads = function()
        serverThreads[1].safeStop()
        serverThreads[2].safeStop()
    end
    
    registerSignalHandler("SIGINT", cancelThreads)
    registerSignalHandler("SIGTERM", cancelThreads)

    
    
    for _, thread in ipairs(serverThreads) do
        thread.join()

        local threadError = thread.getThreadError()
        
        if threadError then
            table.insert(serverErrors, threadError)
        end
    end
end

local function startServerWithoutHttps (serverErrors)
    local Server = require "PuRest.Server.Server"

    try(function()
        local server = Server()
            
        local stopServer = function ()
            server.stopServer()
        end

        registerSignalHandler("SIGINT", stopServer)
        registerSignalHandler("SIGTERM", stopServer)
        
        server.startServer()
    end).
    catch(function (ex)
        table.insert(serverErrors, ex)
    end)
end

local function load()
    local serverErrors = {}

    try(function()
        -- Assert a suitable environment variable is present
        assert((os.getenv("PUREST_WEB") or os.getenv("PUREST")), 
            "Please set the PUREST_WEB or PUREST environment variables!")
        
        -- Init threading lib
        require "lanes".configure()

        -- Ensure server config is loaded before any server code runs.
        local ServerConfig = require "PuRest.Config.resolveConfig"
        local ServerPidFile = require "PuRest.Util.System.ServerPidFile"

        ServerPidFile.recordServerPid()

        if not ServerConfig.https.enabled then
            startServerWithoutHttps(serverErrors)
        else
            startServerWithHttps(serverErrors)
        end
    end).
    catch(function(ex)
        table.insert(serverErrors, ex)
    end)

    if #serverErrors > 0 then
        outputServerErrors(serverErrors)
        os.exit(1)
    end

    os.exit(0)
end

load()