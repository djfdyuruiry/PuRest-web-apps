--[[
    Provides log entry point to output formatted messages
    across multiple threads using LuaLogging to log files.

    usage -> log(msg, level, threadId)
 ]]
require "logging"
require "logging.rolling_file"

local luaFileSystem = require "lfs"

local CurrentThreadId = require "PuRest.Util.Threading.CurrentThreadId"
local LogFiles = require "PuRest.Logging.LogFiles"
local LogLevelMap = require "PuRest.Logging.LogLevelMap"
local ServerConfig = require "PuRest.Config.resolveConfig"
local Time = require "PuRest.Util.Time.Time"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

local nextLogCheck = Time.getTimeNowInSecs() + ServerConfig.logging.clearDownIntervalInSecs

--- Check that file is not over log file size in the server config, if
-- it is delete it.
--
-- @param logPath Absolute path the the log file to check.
-- @return Nothing if file size OK or file was deleted, false and an error string is return if
--         if log path could not be opened.
--
local function checkLogFileSize (logPath)
    validateParameters(
        {
            logPath = {logPath, Types._string_}
        },
        "FileLogger.checkLogFileSize")

    nextLogCheck = Time.getTimeNowInSecs() + ServerConfig.logging.clearDownIntervalInSecs

    local fileStat, err = luaFileSystem.attributes(logPath)

    if not fileStat or err then
        return false, err
    end

	if (fileStat.size / 1024) > ServerConfig.logging.maxLogFileSize then
        return os.remove(logPath)
    end
end

--- Log a message to a file, if the thread id is less than one
-- the message goes to the server log, other wise one of the worker logs.
--
-- @param threadId Id of thread calling log function.
-- @param msg Message to log.
-- @param level Level of the log message.
--
local function logToFile (threadId, msg, level)
	validateParameters(
		{
			threadId = {threadId, Types._number_},
			msg = {msg, Types._string_},
			level = {level, Types._string_}
		},
		"FileLogger.log")

	local logToUse = threadId < 1 and LogFiles.server or string.format(LogFiles.worker, threadId)
	local logPath = (string.format("%s/%s", ServerConfig.logging.logPath, logToUse):gsub("//", "/"))

    if Time.getTimeNowInSecs() > nextLogCheck then
        checkLogFileSize(logPath)
    end
    
	local logger = logging.rolling_file(logPath, ServerConfig.logging.maxLogFileSize)

	logger:log(level, msg)

	-- Force log to flush to file...
	logger = nil
	collectgarbage()
end

--- Log a message using the logToFile function. If the
-- level of the message is higher than the max level in
-- server config then the message is discarded.
--
-- @param threadId optional Id of thread calling log method.
-- @param level optional Level of the log message.
-- @param msg Message to log.
--
local function log (msg, level, threadId)
	if not msg or tostring(msg) == "" then
		return
	end

	threadId = threadId and threadId or CurrentThreadId.getCurrentThreadId()
	threadId = tonumber(threadId or 0)

	msg = threadId > 0 and string.format("[Thread %d] %s", threadId, msg) or msg

	if not level or type(level) ~= Types._number_ then
		level = LogLevelMap.INFO
	end

	if level > LogLevelMap[ServerConfig.logging.maxLogLevel] then
		return
	end

	logToFile(threadId, tostring(msg), LogLevelMap[level])
end

return log
