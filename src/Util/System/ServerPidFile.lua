local FileSystemUtils = require "PuRest.Util.File.FileSystemUtils"
local log = require "PuRest.Logging.FileLogger"
local LogLevelMap = require "PuRest.Logging.LogLevelMap"
local ProcessMonitor = require "PuRest.Util.System.ProcessMonitor"
local ServerConfig = require "PuRest.Config.resolveConfig"
local try = require "PuRest.Util.ErrorHandling.try"

local SERVER_PID_FILE_NAME = "purest.pid"
local SERVER_PID_PATH = (string.format("%s/%s", ServerConfig.htmlDirectory, SERVER_PID_FILE_NAME):gsub("//", "/"))

--- Does the PID file exist yet?
--
-- @return True if PID file exists, false otherwise.
--
local function fileExists ()
	return FileSystemUtils.fileExists(SERVER_PID_PATH)
end

--- Record the server PID to a file
--
local function recordServerPid ()
	try(function ()
		local pidFile, err, errCode = io.open(SERVER_PID_PATH, "w")
		local pid = ProcessMonitor.getPid()
		
		if not pid then
			log("Unable to get process id from system", LogLevelMap.WARN)
			return
		end

		if not pidFile then
			error(string.format("Unable to open file '%s' for writing -> %s (%s)", SERVER_PID_PATH, err, errCode))
		end

		pidFile:write(pid)
		pidFile:close()

		log(string.format("Recorded server process pid to file '%s'", SERVER_PID_PATH))
	end)
	.catch(function (ex)
		local errorMessage = string.format("Error while trying to record server pid to file => %s", ex)
		log(errorMessage, LogLevelMap.ERROR)

		error(errorMessage)
	end)
end

--- Read the recorded server PID from a file.
--
-- @return The PID of the server as a number.
--
local function readServerPid ()
	local pid

	try(function ()
		local pidFile, err, errCode = io.open(SERVER_PID_PATH, "r")

		if not pidFile then
			error(string.format("Unable to open file '%s' for reading -> %s (%s)", SERVER_PID_PATH, err, errCode))
		end

		pid = pidFile:read("*all")

		log(string.format("Read server process pid from file '%s'", SERVER_PID_PATH))
	end)
	.catch(function (ex)
		local errorMessage = string.format("Error while trying to read server pid from file => %s", ex)
		log(errorMessage, LogLevelMap.ERROR)

		error(errorMessage)
	end)

	return tonumber(pid)
end

return
{
	fileExists = fileExists,
	recordServerPid = recordServerPid,
	readServerPid = readServerPid
}
