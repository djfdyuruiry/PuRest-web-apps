local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"
local StringUtils = require "PuRest.Util.Data.StringUtils"
local Types = require "PuRest.Util.ErrorHandling.Types"

--- Convert a hex value to it's relevant ASCII character
-- value.
--
-- @param hex String containing a hexadecimal value.
-- @return A string containing the character value.
--
local function hexToChar (hex)
    return string.char(tonumber(hex, 16))
end

--- Unescape any URL encoded characters in the given string .
--
-- @param url String containing zero or more URL encoded characters.
-- @return The unescaped string.
--
local function unescape (url)
    return url:gsub("%%(%x%x)", hexToChar)
end

--- Parse a given string for query string key value pairs.
-- The string does not need to be URL escaped.
--
-- @param queryString A string containing query string pairs.
-- @return A table with indexes for each key in query string.
--
local function parseQueryString (queryString)
	validateParameters(
		{
			queryString = {queryString, Types._string_}
		},
		"QueryString.parseQueryString")

	local queryStringDict = {}

	local explodedQueryString = StringUtils.explode(queryString, "&")

	-- Navigate through the exploded query string, storing found
	-- key value pairs.
	for _, kvpStr in ipairs(explodedQueryString) do
		local kvp = StringUtils.explode(kvpStr, "=")
		local key = unescape((kvp[1]:gsub("%+", " ")))
		local value = unescape((kvp[2] and kvp[2]:gsub("%+", " ") or ""))

		queryStringDict[key] = value
	end

	return queryStringDict
end

return
{
    parseQueryString = parseQueryString,
    unescape = unescape
}
