-- TODO: have build mechanism to exclude alien from dependecies completely on non-windows system
--require "alien"

local Process = require "PuRest.Util.System.Process"
local StringUtils = require "PuRest.Util.Data.StringUtils"
local try = require "PuRest.Util.ErrorHandling.try"

-- TODO: replace platform_get call with luarocks logic or consider defining this upfront using powershell or similar
-- see https://github.com/luarocks/luarocks/blob/master/src/luarocks/core/cfg.lua
local PLATFORM = "UNIX"--apr.platform_get()

--[[ WIN32 OS calls. ]]

--- Get a handle on the current process.
--
-- @param kernel32Handle Alien handle to the kernel 32 DLL.
-- @return A pointer to the current process handle.
--
local function getProcessHandleWin32 (kernel32Handle)
	kernel32Handle = kernel32Handle or alien.load("kernel32.dll");

	local GetCurrentProcess = kernel32Handle.GetCurrentProcess
	GetCurrentProcess:types{ ret = "pointer", abi = "stdcall" }

	return GetCurrentProcess()
end

--- Get the PID of the current process.
--
-- @param kernel32Handle Alien handle to the kernel 32 DLL.
-- @param win32ProcessHandle Handle on the current process.
-- @return Process id as a number.
--
local function getPidWin32 (kernel32Handle, win32ProcessHandle)
	kernel32Handle = kernel32Handle or alien.load("kernel32.dll");
	win32ProcessHandle = win32ProcessHandle or getProcessHandleWin32(kernel32Handle)

	local GetProcessId = kernel32Handle.GetProcessId
	GetProcessId:types{ ret = "int", abi = "stdcall", "pointer" }

	return GetProcessId(win32ProcessHandle)
end

--- Use the Win32 C API to get performance data.
-- Fetches memory usage of process and PID.
--
-- @return A table of performance statistics.
--
local function getWin32Stats ()
	local stats = {}
	local kernel32  = alien.load("kernel32.dll");

	local GetProcessMemoryInfo

	try(function ()
		GetProcessMemoryInfo = kernel32.GetProcessMemoryInfo
	end)
	.catch(function ()
		GetProcessMemoryInfo = kernel32.K32GetProcessMemoryInfo
	end)

	GetProcessMemoryInfo:types{ ret = "void", abi = "stdcall", "pointer", "pointer", "int" }

	local PROCESS_MEMORY_COUNTERS = alien.defstruct({
		{"cb", "int"},
		{"PageFaultCount", "int"},
		{"PeakWorkingSetSize", "size_t"},
		{"WorkingSetSize", "size_t"},
		{"QuotaPeakPagedPoolUsage", "size_t"},
		{"QuotaPagedPoolUsage", "size_t"},
		{"QuotaPeakNonPagedPoolUsage", "size_t"},
		{"QuotaNonPagedPoolUsage", "size_t"},
		{"PagefileUsage", "size_t"},
		{"PeakPagefileUsage", "size_t"},
		{"PrivateUsage", "size_t"}
	})
	local PROCESS_MEMORY_COUNTERS_SIZE = alien.sizeof("size_t") * 9 + alien.sizeof("int") * 2

	local processHandle = getProcessHandleWin32(kernel32)
	local memoryInfo = PROCESS_MEMORY_COUNTERS:new()

	memoryInfo.cb = PROCESS_MEMORY_COUNTERS_SIZE

	GetProcessMemoryInfo(processHandle, memoryInfo(), PROCESS_MEMORY_COUNTERS_SIZE)

	stats.memoryUsageInBytes = memoryInfo.PrivateUsage;
	stats.pid = getPidWin32(kernel32, processHandle);


	return stats
end

--[[ UNIX OS calls. ]]


--- Get the PID of the current process.
--
-- @return Process id as a number.
--
local function getPidUnix ()
	local getPidProcess = Process("echo $PPID", "Get PuRest PID")
	local pidStr = getPidProcess.run()
	local pid = tonumber(pidStr)

	if not pid then
		error("Error while trying to request PID from OS")
	end

	return pid
end

--- Convert an eTime value from ps command to seconds
--
-- @param eTime Value returned for process uptime by ps command.
-- @param Uptime in seconds as a number.
--
local function getUptimeInSecFromEtime (eTime)
    local uptime = 0
    local daysAndUptime = StringUtils.explode(eTime, "-")
    local days = daysAndUptime[2] and daysAndUptime[1] or nil
    local uptimeStr = days and daysAndUptime[2] or daysAndUptime[1]

    local uptimeParts = StringUtils.explode(uptimeStr, ":")
    local multipler = 1


    for i = #uptimeParts, 1, -1 do
        uptime = uptime + (multipler * tonumber(uptimeParts[i]))
        multipler = multipler * 60
    end

    local daysInSecs = days and tonumber(days) * 24 * 60 * 60 or 0

    return uptime + daysInSecs
end

--- Use the unix ps command to extract performance data.
-- Fetches CPU Usage (% of system), Memory Usage (System available and Process used values),
-- number of threads, PID, Uptime in Secs.
--
-- @return A table of performance statistics.
--
local function getUnixStats ()
	local pid = getPidUnix()
	local psCmd = "ps -p " .. pid .. " -o %cpu,rss,%mem,nlwp,etime | tail -n +2"
	local psProc, openErr = io.popen(psCmd)

	if not psProc or openErr then
		error(string.format("Error opening process handle for '%s' to read stats: %s.", psCmd, (openErr or "unknown error")))
	end

	local psOut, readErr = psProc:read("*all")

	if not psOut or readErr then
		error(string.format("Error reading from process handle for '%s' to read stats: %s.", psCmd, (readErr or "unknown error")))
	end

	psProc:close()

	local stats = StringUtils.explode(psOut, " ")

	if not stats or #stats < 5 then
		error("Error parsing stats information from '%s': no output or not enough fields returned.")
    end

    return
    {
        cpuUsage = tonumber(stats[1]),
		memoryUsageInBytes = tonumber(stats[2]) * 1024,
		memoryUsage = tonumber(stats[3]),
		numThreads = tonumber(stats[4]),
        pid = pid,
        uptimeInSecs = getUptimeInSecFromEtime(stats[5])
    }
end

--[[ Server monitor end user functions. ]]

--- Get the stats for the current process from the OS. (See each field below for [format]type and OS support)
--
--	@return Table of stats; fields: cpuUsage (% - [number] UNIX), memoryUsageInBytes ([number] Win32, UNIX),
--                                   memoryUsage (% - [number] UNIX), numThreads ([number] UNIX), uptimeInSecs ([number] UNIX),
--                                   pid ([number] Win32, UNIX).
--
local function getStats ()
	local stats = {}

	try(function ()
		if PLATFORM == "WIN32" then
			error("windows stats not implemented yet")
			stats = getWin32Stats()
		elseif PLATFORM == "UNIX" then
            stats = getUnixStats()
        end
	end)
	.catch(function (ex)
		error(string.format("Error while getting process stats: Platform -> %s | %s",
			PLATFORM, ex))
	end)

	return stats
end

--- Get the pid for the current process from the OS.
--
--	@return The pid for the current process.
--
local function getPid ()
	local pid

	try(function ()
		if PLATFORM == "WIN32" then 
			error("windows pid not implemented yet")
			pid = getPidWin32()
		elseif PLATFORM == "UNIX" then
            pid = getPidUnix()
		end
	end)
	.catch(function (ex)
		error(string.format("Error while getting process pid: Platform -> %s | %s",
			PLATFORM, ex))
	end)

	return pid
end

--- Provide methods to get information about the current process;
-- PID, performance information and OS platform. Supports Win32 & Linux.
--
return
{
    systemPlatform = PLATFORM,
	getStats = getStats,
	getPid = getPid
}
