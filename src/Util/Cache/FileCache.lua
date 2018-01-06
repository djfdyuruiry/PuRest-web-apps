local luaFileSystem = require "lfs"

local log = require "PuRest.Logging.FileLogger"
local LogLevelMap = require "PuRest.Logging.LogLevelMap"
local ServerConfig = require "PuRest.Config.resolveConfig"
local Timer = require "PuRest.Util.Time.Timer"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

local fileCache =  {}

--- Determine if the passed file in cache is still valid,
-- @param cacheFile The cache entry for the file.
-- @param filePath Full path to the file referenced in the cache entry.
-- @return True if the cache entry is valid or false and a string
--          explaining why the entry is invalid.
--
local function isFileStillValid(cacheFile, filePath)
	local fileStats = luaFileSystem.attributes(filePath)

	if not fileStats then
		return false, "deleted"
	elseif fileStats.modification > cacheFile.lastModified then
		return false, "modified"
	end

	return true
end

--- Attempt to load a given file from the cache.
-- @param filePath Full path to the file to load.
-- @param httpState State of the current HTTP request.
-- @return True if the file was loaded and the contents and file format(MIME type).
--			Otherwise false and a string explaining why the file could not be loaded.
--
local function loadFromFileCache (filePath, httpState)
	validateParameters(
		{
			filePath = {filePath, Types._string_},
			httpState = {httpState, Types._table_}
		}, "FileCache.loadFromFileCache")

	local timer = Timer()
	local cacheFile = fileCache[filePath]

	if ServerConfig.enableFileCache and cacheFile then
		local isValid, invalidReason = isFileStillValid(cacheFile, filePath)

		if isValid then
			log(string.format("Loaded '%s' from file cache.", filePath), LogLevelMap.INFO)
			log(string.format("Loading file from cache took %s ms.", timer.endTimeNow()), LogLevelMap.DEBUG)

			return true, cacheFile.content, cacheFile.format
		else
			fileCache[filePath] = nil

			log(string.format("File '%s' has been %s and will be removed from cache.", filePath, invalidReason),
				LogLevelMap.INFO)

			return false, invalidReason
		end
	elseif not ServerConfig.enableFileCache then
		return false, "file cache disabled in server config"
	elseif not cacheFile then
		return false, "file is not in cache"
	end

	return false, "unknown"
end

--- Update a file in the cache.
-- @param filePath Full path to the file to update.
-- @param fileContent Contents of the file.
-- @param fileFormat Format of the file. (MIME type)
-- @return True if the cache was updated. Otherwise false and a string explaining
--          why the cache could not be updated.
--
local function updateFileCache (filePath, fileContent, fileFormat)
	validateParameters(
		{
			filePath = {filePath, Types._string_},
			fileContent = {fileContent, Types._string_},
			fileFormat = {fileFormat, Types._string_},
		}, "FileCache.updateFileCache")

	local timer = Timer()
	local fileStats = luaFileSystem.attributes(filePath)

	if not ServerConfig.enableFileCache then
		return false, "file cache disabled in server config"
	elseif fileStats.size < ServerConfig.fileCacheMinFileSizeInMb * 1000000 then
		log(string.format("Not adding '%s' to file cache as it is too small.", filePath), LogLevelMap.INFO)
		return false, "file is too small"
	elseif fileStats.size > ServerConfig.fileCacheMaxFileSizeInMb * 1000000 then
		log(string.format("Not adding '%s' to file cache as it is too large.", filePath), LogLevelMap.INFO)
		return false, "file is too large"
	end

	fileCache[filePath] =
	{
		content = fileContent,
		format = fileFormat,
		lastModified = fileStats.modification
	}

	log(string.format("Added '%s' to file cache.", filePath), LogLevelMap.INFO)
	log(string.format("Adding file to cache took %s ms.", timer.endTimeNow()), LogLevelMap.DEBUG)

	return true
end

return
{
	loadFromCache = loadFromFileCache,
	updateCache = updateFileCache
}
