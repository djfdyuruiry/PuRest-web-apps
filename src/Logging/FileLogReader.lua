local FileSystemUtilites = require "PuRest.Util.File.FileSystemUtils"
local LogFiles = require "PuRest.Logging.LogFiles"
local ServerConfig = require "PuRest.Config.resolveConfig"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

--- Get all messages from a log file.
--
-- @param logPath Full path to the log file.
-- @param buildMsgTable Return a table with entry per line instead of log file contents.
-- @return The contents of the log file as a string or a table with string entry per line.
--
local function getMessagesFromLogFile (logPath, buildMsgTable)
    validateParameters(
        {
            logPath = {logPath, Types._string_}
        })

	local messages = buildMsgTable and {} or ""

	local file, err, errCode = io.open(logPath, "r")

	if not file then
		error(string.format("Error when getting messages from log file '%s' -> %s (%s).", logPath, err, errCode))
	end

	for message in file:lines() do
		if buildMsgTable then
			table.insert(messages, message)
		else
			messages = messages == "" and message or messages .. "\r\n" .. message
		end
	end

	return messages
end

--- Get the full path to a server log file.
--
-- @param logFile Log file in log path.
-- @return The full path to the given log file.
--
local function getLogFilePath (logFile)
    validateParameters(
        {
            logFile = {logFile, Types._string_}
        })

	return (string.format("%s/%s", ServerConfig.logging.logPath, logFile):gsub("//", "/"))
end

--- Get all log files produced by the server
--
-- @return Table of log file contents.
--          Format: { server = #serverLogContents#, workers = {[1] = #workerOneLogContents#...}}
--
local function getServerLogs ()
	local logMessages =
	{
		workers = {}
	}

	local serverLogPath = getLogFilePath(LogFiles.server)

	if FileSystemUtilites.fileExists(serverLogPath) then
		logMessages.server = getMessagesFromLogFile(serverLogPath)
	end

	for i = 1, ServerConfig.workerThreads do
		local workerLogPath = getLogFilePath(string.format(LogFiles.worker, i))

		if FileSystemUtilites.fileExists(workerLogPath) then
			table.insert(logMessages.workers, getMessagesFromLogFile(workerLogPath))
		end
	end

	return logMessages
end

return
{
	getServerLogs = getServerLogs,
	getLogFilePath = getLogFilePath,
	getMessagesFromLogFile = getMessagesFromLogFile
}
