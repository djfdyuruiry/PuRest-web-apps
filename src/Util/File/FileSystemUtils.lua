local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

local UNABLE_TO_OPEN_FILE_ERR = "Unable to open file: %s"

--- Attempt to open a file and report if it opened successfully.
--
-- @param fileName Absolute path to the file.
-- @return True and a handle on the file if it exists or false otherwise.
--
local function tryOpenFile (fileName, openMode)
	validateParameters(
		{
			fileName = {fileName, Types._string_}
		}, "FileSystemUtils.tryOpenFile")

	local fileHandle = io.open(fileName, openMode and openMode or "rb")
	local fileExists = fileHandle ~= nil

	return fileExists, fileHandle
end

--- Attempt to close a file and report if it closed successfully.
--
-- @param fileHandle A handle on the file.
-- @return True if handle was valid and file closed false otherwise.
--
local function tryCloseFile (fileHandle)
	if fileHandle then
		fileHandle:close()
		return true
	end

	return false
end

--- Check if a file exists.
--
-- @param fileName Absolute path to the file.
-- @return True if it exists, false otherwise.
--
local function fileExists (fileName)
	validateParameters(
		{
			fileName = {fileName, Types._string_}
		}, "FileSystemUtils.fileExists")

	local fileExists, fileHandle = tryOpenFile(fileName)

	tryCloseFile(fileHandle)

	return fileExists
end

--- Read all text from a file.
--
-- @param fileName Absolute path to the file.
-- @return Content fo the file as a string.
--
local function readAllText (fileName)
	validateParameters(
		{
			fileName = {fileName, Types._string_}
		}, "FileSystemUtils.readAllText")

	local isOk, file = tryOpenFile(fileName)

	if isOk then
		local content = file:read("*all") or ""

		tryCloseFile(file)
		return content
	else
		error(string.format(UNABLE_TO_OPEN_FILE_ERR, fileName))
	end
end

--- Write a string to a file.
--
-- @param fileName Absolute path to the file.
-- @text Content to write to the file.
-- @append Append content instead of overwrite?
--
local function writeAllText (fileName, text, append)
	validateParameters(
		{
			fileName = {fileName, Types._string_},
			text = {text, Types._string_}
		}, "FileSystemUtils.writeAllText")

	local isOk, file = tryOpenFile(fileName, append and "a" or "w")

	if isOk then
		file:write(append and ("\n" .. text) or text)
		tryCloseFile(file)
	else
		error(string.format(UNABLE_TO_OPEN_FILE_ERR, fileName))
	end
end

return
{
	tryOpenFile = tryOpenFile,
	tryCloseFile = tryCloseFile,
	fileExists = fileExists,
	readAllText = readAllText,
	writeAllText = writeAllText
}
