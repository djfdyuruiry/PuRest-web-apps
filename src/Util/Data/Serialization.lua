JSON = require "JSON"

local json = JSON
local xml = require "xml"

local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

--- Parse a JSON object from the given string, returns
--  eqivalent Lua table or false and the error msg on error.
--
-- @param jsonString JSON string to parse.
-- @return Deserialized value on success or false and error string.
--
local function parseJson(jsonString)
	validateParameters(
		{
			jsonString = {jsonString, Types._string_}
		}, "Serialization.parseJson")

	local jsonObj

	local status, err = pcall(function()
		jsonObj = json:decode(jsonString)
	end)

	if not status then
		return false, err
	end

	return jsonObj
end

--- Serialize a lua value into a JSON string.
--
-- @param value The lua value to serialize.
-- @param prettyPrint Add indents and newlines to JSON?
-- @return JSON string on success or false and error string.
--
local function serializeToJson(value, prettyPrint)
	local jsonString

	local status, err = pcall(function()
		jsonString = prettyPrint and json:encode_pretty(value) or json:encode(value)
	end)

	if not status then
		return false, err
	end

	return jsonString
end

--- Deserialize a XML fragement into a Lua table.
--
-- @param xmlString The XML string to parse.
-- @return Table decorated with XML values on success or false and error string.
--
local function parseXml(xmlString)
	validateParameters(
		{
			xmlString = {xmlString, Types._string_}
		}, "Serialization.parseXml")

	local xmlTable

	local status, err = pcall(function()
		xmlTable = xml.load(xmlString)
	end)

	if not status then
		return false, err
	end

	return xmlTable
end

--- Serialize a Lua table into a XML fragement.
--
-- @param xmlDecoratedTable The XML decorated table to serialize.
-- @return XML string on success or false and error string.
--
local function serializeToXml(xmlDecoratedTable)
	validateParameters(
		{
			xmlDecoratedTable = {xmlDecoratedTable, Types._table_}
		}, "Serialization.serializeToXml")

	local xmlString

	local status, err = pcall(function()
		xmlString = xml.dump(xmlDecoratedTable)
	end)

	if not status then
		return false, err
	end

	return xmlString
end

return
{
	parseJson = parseJson,
	serializeToJson = serializeToJson,
	parseXml = parseXml,
	serializeToXml = serializeToXml
}
