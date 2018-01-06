local luaLinq = require "lualinq"
local from = luaLinq.from

local FileCache = require "PuRest.Util.Cache.FileCache"
local FileSystemUtils = require "PuRest.Util.File.FileSystemUtils"
local log = require "PuRest.Logging.FileLogger"
local LogLevelMap = require "PuRest.Logging.LogLevelMap"
local MimeTypeDictionary = require "PuRest.Util.File.MimeTypeDictionary"
local processView = require "PuRest.View.processView"
local renderPhp = require "PuRest.Php.renderPhp"
local Timer = require "PuRest.Util.Time.Timer"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"


--- Attempt to load a file and store in the response content field of the given
-- HTTP request. If the file is of a type that needs ran through an interpreter
-- (a script/dynamic page) the final output from the interpreter is used instead.
--
-- The MIME type of the content read/generated from the file is set as the responseFormat
-- field of the given HTTP request.
--
-- An error is thrown with a 404 HTTP code if the file can not or should not be served
-- , based upon the doNotServeTheseFiles field of the given site config. Errors can also
-- be thrown when attempting to generate the final output for any script files/dynamic pages.
--
-- @param urlArgs Url arguments, if any.
-- @param queryStringArgs Query string arguments, if any.
-- @param httpState State of the current HTTP request.
-- @param siteConfig Config of the site trying to serve the file.
--
local function serveFile (urlArgs, queryStringArgs, httpState, siteConfig)
	validateParameters(
		{
			httpState = {httpState, Types._table_},
			siteConfig = {siteConfig, Types._table_}
		}, "serveFile")

	local timer = Timer()

	local location = httpState.request.location
	local queryString = location:match([[.*(?.*)]])

	if queryString then
		location = location:gsub(queryString, "")
	end

	local directory = (siteConfig.fullPath:gsub([[\]], "/")):gsub([[\]], "/")
	local filePath = (string.format("%s/%s", directory, location)):gsub("//", "/")

	filePath = filePath:gsub("//", "/")

	log(string.format("Processing serve request for file '%s'.", filePath), LogLevelMap.INFO)

	local isInCache, fileContents, fileFormat = FileCache.loadFromCache(filePath, httpState)

	if isInCache then
		httpState.response.content = fileContents
		httpState.response.responseFormat = fileFormat
		return
	end

	local fileExt = filePath:match("/[^/]+[.]([^/]+)$") or "*"
	local fileName = filePath:match("/([^/]+)$") or "*"
	local mimeType = MimeTypeDictionary[fileExt]

	if httpState.request.method == "POST" and mimeType ~= MimeTypeDictionary["lhtml"] and mimeType ~= MimeTypeDictionary["php"] then
		error({ httpErrCode = 403, msg = "Static files should be requested using the HTTP GET method." })
	end

	local fileOk, fileHandle = FileSystemUtils.tryOpenFile(filePath)
	local doNotServeFile = not fileOk

	local doNotServeTheseFiles = siteConfig.doNotServeTheseFiles

	if fileOk and #doNotServeTheseFiles > 0 then
		local numMatchingFileSets = from(doNotServeTheseFiles):where(function (fileSet)
			local regexFileSet = (fileSet:gsub("*", ".*"))
			return (fileName:match(regexFileSet)) ~= nil
		end):count()

		doNotServeFile = (numMatchingFileSets ~= 0)
	end

	if doNotServeFile then
		log(string.format("Unable to read file '%s'", filePath), LogLevelMap.INFO)

		FileSystemUtils.tryCloseFile(fileHandle)
		error({httpErrCode = 404})
	end

	if mimeType == MimeTypeDictionary["lhtml"] then
		httpState.response.responseFormat = "text/html"
		httpState.response.content = processView(fileName:gsub("%.lhtml", ""), nil,
												 siteConfig, urlArgs, queryStringArgs, httpState)
	elseif mimeType == MimeTypeDictionary["php"] then
		httpState.response.responseFormat = "text/html"
		httpState.response.content = renderPhp(fileName, siteConfig, urlArgs, queryStringArgs, httpState)
	else
		log(string.format("Loaded file '%s' into HTTP response.", filePath), LogLevelMap.INFO)
		httpState.response.content = fileHandle:read("*all")
		httpState.response.responseFormat = mimeType

		log(string.format("Loading file into HTTP response took %s ms.", timer.endTimeNow()), LogLevelMap.DEBUG)
	end

	FileSystemUtils.tryCloseFile(fileHandle)
	FileCache.updateCache(filePath, httpState.response.content, httpState.response.responseFormat)
end

return serveFile
