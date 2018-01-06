local lanes = require "lanes"

local sleep = require "PuRest.Util.Threading.sleep"
local Time = require "PuRest.Util.Time.Time"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

local PENDING_SLEEP_INTERVAL_MS = 0.1
local PENDING_STATUS_TIMEOUT_MS = 30000

local function Thread (entryPoint, humanReadableId, errorMessageTemplate)
    validateParameters(
		{
            entryPoint = {entryPoint, Types._function_},
            humanReadableId = {humanReadableId, Types._string_, isOptional = true},
            errorMessageTemplate = {errorMessageTemplate, Types._string_, isOptional = true}
        }, "Thread.construct")

    local thread
    local threadId
    local threadError
    local threadStartTime

    local function getThreadId ()
        return threadId
    end

    local function isAlive ()
        assert(thread, "isAlive cannot be called until Thread has been started")

        return thread.status == "running" or thread.status == "waiting"
    end

    local function getSecondsSinceStart ()
        assert(thread, "getSecondsSinceStart cannot be called until Thread has been started")

        return Time.getTimeNowInSecs() - threadStartTime
    end

    local function safeStop()
        assert(thread, "safeStop cannot be called until Thread has been started")

        pcall(function()
            thread:cancel()
        end)
    end

    local function getThreadHandle ()
        return thread
    end

    local function buildThreadId ()
        assert((thread or humanReadableId), 
            "buildThreadId can only be called after thread has been started or a human readable id was specified")

        return humanReadableId and humanReadableId or tostring(thread):sub(10)
    end

    local function assertThreadStarted ()
        if not thread or threadError then
            error(string.format("Error occurred when starting thread with id '%s': %s", 
                (thread and buildThreadId() or "?")
                (threadError or "unknown error")))
        end
    
        local pendingWaitingTimeInMs = 0
    
        while thread.status == "pending" and pendingWaitingTimeInMs < PENDING_STATUS_TIMEOUT_MS do
            sleep(PENDING_SLEEP_INTERVAL_MS)
            
            pendingWaitingTimeInMs = pendingWaitingTimeInMs + PENDING_SLEEP_INTERVAL_MS
        end
    
        assert(thread.status ~= "pending",
            string.format("Thread with id '%s' stuck in 'pending' state for %f ms", 
                buildThreadId(), pendingWaitingTimeInMs))
    
        if thread.status == "error" then
            local _, err = thread:join()
            
            errorMessageTemplate = errorMessageTemplate or "%s"
    
            error(string.format(errorMessageTemplate, err))
        end
    end

    local function start (...)
        assert((not thread), string.format("Thread with id '%s' has already been started", threadId))

        local threadGenerator = lanes.gen("*", {cancelstep = true}, entryPoint)

        thread, threadError = threadGenerator(...)

        assertThreadStarted()

        threadId = buildThreadId()
        threadStartTime = Time.getTimeNowInSecs()
    end

    local function join ()
        assert((thread), 
            "join can only be called after thread has been started")

        local exitStatus, potentialThreadError = thread:join()

        if not exitStatus or potentialThreadError then
            threadError = potentialThreadError
        end
    end

    local function setThreadErrorIfThreadInErrorState()
        assert((thread), 
            "setThreadErrorIfThreadInErrorState can only be called after thread has been started")

        if thread.status == "error" then
            local _, potentialThreadError = thread:join()

            threadError = potentialThreadError or "unknown error"
        end
    end

    local function getThreadError ()
        if not threadError and thread then
            setThreadErrorIfThreadInErrorState()
        end

        return threadError
    end

    return
    {
        start = start,
        safeStop = safeStop,
        join = join,
        getThreadId = getThreadId,
        getThreadError = getThreadError,
        isAlive = isAlive,
        getSecondsSinceStart = getSecondsSinceStart,
        getThreadHandle = getThreadHandle
    }
end

return Thread
