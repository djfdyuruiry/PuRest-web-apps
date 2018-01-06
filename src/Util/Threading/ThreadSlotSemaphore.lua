local Semaphore = require "PuRest.Util.Threading.Semaphore"
local ServerConfig = require "PuRest.Config.resolveConfig"
local ThreadSlots = require "PuRest.Util.Threading.ThreadSlots"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

local threadSlotSemaphore = Semaphore(nil, ThreadSlots.generateThreadSlots(ServerConfig.workerThreads), true)

--- Get the thread queue the thread slot semaphore is using.
--
-- @return The thread queue for the thread slot semaphore.
--
local function getThreadQueue ()
	return threadSlotSemaphore.getThreadQueue()
end

--- Set the thread queue for the thread slot semaphore.
--
-- @param threadQueue The thread queue for the thread slot semaphore.
--
local function setThreadQueue (threadQueue)
	validateParameters(
		{
			threadQueue = {threadQueue, Types._userdata_},
		}, "ThreadSlotSemaphore.loadThreadQueue")

	threadSlotSemaphore = Semaphore(threadQueue, nil, true)
end

--- Lock the semaphore and get the thread slot table.
-- (Values in table set by reference held in semaphore)
--
-- @return The thread slot table.
--
local function getThreadSlots ()
	if threadSlotSemaphore.isHoldingLock() then
		error("ThreadSlotSemaphore.setThreadCount() must be called before calling getThreadCount again.")
	end

	return threadSlotSemaphore()
end

--- Set the thread slot table and unlock the semaphore.
-- (Values in table set by reference held in semaphore)
--
-- TODO: free this when thread finishes
local function setThreadSlots ()
	if not threadSlotSemaphore.isHoldingLock() then
		error("ThreadSlotSemaphore.getThreadCount() must be called before calling setThreadCount.")
	end

	threadSlotSemaphore()
end

return
{
	getThreadQueue = getThreadQueue,
	setThreadQueue = setThreadQueue,
	getThreadSlots = getThreadSlots,
	setThreadSlots = setThreadSlots
}
