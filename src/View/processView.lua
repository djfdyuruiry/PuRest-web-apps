local FileSystemUtilities = require "PuRest.Util.File.FileSystemUtils"
local log = require "PuRest.Logging.FileLogger"
local LogLevelMap = require "PuRest.Logging.LogLevelMap"
local Scriptlet = require "PuRest.View.Scriptlet"
local Timer = require "PuRest.Util.Time.Timer"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

--- Process a view file (dynamic page) on a site to generate a text result.
--
-- @param viewFile Path to the view file on the site. e.g "index.lhtml" or "/subfolder/subfile.lhtml"
-- @param dataModel optional A data model to pass for use by the view logic.
-- @param siteConfig Config of the site currently handling client request.
-- @param urlArgs optional Url arguments table generated from route matching.
-- @param queryStringArgs optional Query string arguments table parsed from HTTP location.
-- @param httpState optional Current HttpState for client request.
-- @param contentType optional Mime type to apply to httpState reponse type.
-- @return Resulting text after processing scriplets in the  view.
--
local function processView (viewFile, dataModel, siteConfig, urlArgs, queryStringArgs, httpState, contentType)
	validateParameters(
		{
			viewFile = {viewFile, Types._string_},
			siteConfig = {siteConfig, Types._table_}
		},
		"processView")

	local timer = Timer()

	local viewFilePath = (string.format("%s/%s.lhtml", siteConfig.fullPath, viewFile):gsub("//", "/"))
	local viewFile = FileSystemUtilities.readAllText(viewFilePath)

	local post = type(httpState) == Types._table_ and httpState.request.body or nil

    if type(contentType) == Types._string_ and contentType ~= "" and
       type(httpState) == Types._table_  then
        httpState.response.responseFormat = contentType
    end

	local model = dataModel or {}
	local env = Scriptlet.buildEnvironment(model, siteConfig, { url = urlArgs, query = queryStringArgs, post = post, state = httpState})

	local scriptlets, outputText = Scriptlet.harvestFromBuffer(viewFile)

	log(string.format("Processing view '%s'.", viewFilePath), LogLevelMap.INFO)

	for _, scriptlet in ipairs(scriptlets) do
		local executionStatus, returnValOrErr = Scriptlet.evaluate(scriptlet, env)

		if not executionStatus then
			error(string.format("Error processing view '%s', script '%s': %s",
				viewFilePath:gsub("<", "&lt;"):gsub(">", "&gt;"),
				scriptlet.script:gsub("<", "&lt;"):gsub(">", "&gt;"),
				returnValOrErr))
		end

		if not returnValOrErr then
			-- Clear UID marker from HTML.
			returnValOrErr = ""
		end

		outputText = outputText:gsub(scriptlet.replaceUid, returnValOrErr)
	end

	log(string.format("Successfully processed view '%s'.", viewFilePath), LogLevelMap.INFO)
	log(string.format("Processing view took %s ms.", timer.endTimeNow()), LogLevelMap.DEBUG)

	return outputText
end

return processView
