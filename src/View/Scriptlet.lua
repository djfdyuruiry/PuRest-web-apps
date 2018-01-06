local loadstring = loadstring or load

local Regex = require "rex_pcre"

local ScriptletPatterns = require "PuRest.View.ScriptletPatterns"
local ScriptletTypes = require "PuRest.View.ScriptletTypes"
local Serialization = require "PuRest.Util.Data.Serialization"
local setfenv = require "PuRest.Util.setfenv"
local try = require "PuRest.Util.ErrorHandling.try"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

local JS_EVAL_TEMPLATE = [[eval('(%s)')]]

local function buildScriptletEnvironment (viewModel, siteConfig, requestData)
	validateParameters(
		{
			viewModel = {viewModel, Types._table_},
			siteConfig = {siteConfig, Types._table_},
			requestData = {requestData, Types._table_}
		},
		"Scriptlet.buildScriptletEnvironment")

	local environment =
	{
		model = viewModel,
		config = siteConfig,
		url = requestData.url,
		query = requestData.query,
		post = requestData.post,
		state = requestData.state,
        view = {},
        try = try,
		__writeCache__ = ""
	}

	environment.write = function (string)
		environment.__writeCache__ = environment.__writeCache__ .. string
	end

	return setmetatable(environment, {__index = _G})
end

local function getNextScriptletInBuffer (buffer)
	validateParameters(
		{
			buffer = {buffer, Types._string_}
		},
		"Scriptlet.getNextScriptletInBuffer")

	local nextBufferBitRegex = Regex.new([[\s*<%.+%>]], "sU")
	local nextBufferBit = {nextBufferBitRegex:exec(buffer)}
	local scriptletType = ScriptletTypes.JsPrinter

	while #nextBufferBit > 0 and scriptletType ~= -1 do
		local subject = buffer:sub(nextBufferBit[1], nextBufferBit[2])
		local matchInfo = { ScriptletPatterns[scriptletType]:exec(subject) }

		if #matchInfo > 0 then
			local uid = string.format("#%s#", tostring({}):sub(8))

			return
			{
				scriptletType = scriptletType,
				script = matchInfo[3]["charData"],
				replaceUid = uid
			}, string.format("%s%s%s", buffer:sub(1, nextBufferBit[1] - 1), uid,
				buffer:sub(nextBufferBit[2] + 1))
		end

		scriptletType = scriptletType - 1
	end
end

local function harvestScriptletsFromBuffer (buffer)
	validateParameters(
		{
			buffer = {buffer, Types._string_}
		},
		"Scriptlet.harvestScriptletsFromBuffer")

	local scriptlets = {}

	local scriplet, choppedBuffer = getNextScriptletInBuffer(buffer)

	if scriptlet then
		buffer = choppedBuffer
	end

	while scriplet do
		scriplet, choppedBuffer = getNextScriptletInBuffer(buffer)

		if scriplet then
			table.insert(scriptlets, scriplet)

			buffer = choppedBuffer
		end
	end

	return scriptlets, buffer
end

local function evaluateScriptlet (scriptlet, environment, keepPreviousOutput)
	validateParameters(
		{
			scriptlet = {scriptlet, Types._table_}
		},
		"Scriptlet.evaluateScriptlet")

	local scriptletType = scriptlet.scriptletType
	local script = scriptlet.script
	local evaluateDict = {}

	if not keepPreviousOutput then
		environment.__writeCache__ = ""
	end

	evaluateDict[ScriptletTypes.PlainHtml] = function ()
		return true, scriptlet.script
	end

	evaluateDict[ScriptletTypes.Executor] = function ()
		return pcall(function ()
			local execScript, err = loadstring(script)

			if err then
				error(err)
			end

			setfenv(execScript, environment)

			execScript()
			return environment.__writeCache__
		end)
	end

	evaluateDict[ScriptletTypes.Printer] = function ()
		return pcall(function ()
			local execScript, err = loadstring(string.format("return %s",
				(script:gsub("return", ""))))

			if err then
				error(err)
			end

			setfenv(execScript, environment)

			return tostring(execScript())
		end)
	end

	evaluateDict[ScriptletTypes.JsPrinter] = function ()
		return pcall(function ()
			local execScript, err = loadstring(string.format("return %s",
				(script:gsub("return", ""))))

			if err then
				error(err)
			end

			setfenv(execScript, environment)

			local json = Serialization.serializeToJson(execScript())
			return string.format(JS_EVAL_TEMPLATE, json)
		end)
	end

	return evaluateDict[scriptletType]()
end

return
{
	buildEnvironment = buildScriptletEnvironment,
	evaluate = evaluateScriptlet,
	harvestFromBuffer = harvestScriptletsFromBuffer,
	getNextScriptletInBuffer = getNextScriptletInBuffer
}
