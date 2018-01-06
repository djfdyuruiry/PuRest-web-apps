--- Two way map of log levels number<->string. e.g. LogLevelMap[5] = "DEBUG" = LogLevelMap.DEBUG
local logLevelMap =
{
	DEBUG = 5,
	INFO = 4,
	WARN = 3,
	ERROR = 2,
	FATAL = 1,
	NONE = -1
}

logLevelMap[5] = "DEBUG"
logLevelMap[4] = "INFO"
logLevelMap[3] = "WARN"
logLevelMap[2] = "ERROR"
logLevelMap[1] = "FATAL"
logLevelMap[-1] = "NONE"

return logLevelMap
