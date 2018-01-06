local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"
local Types = require "PuRest.Util.ErrorHandling.Types"

--- Convert a string into a table of characters.
--
-- @param subject String to convert to a char array.
-- @return A table with each element being the characters as they appear in the subject.
--
local function toCharArray (subject)
	validateParameters(
		{
			subject = {subject, Types._string_}
		},
		"StringUtils.toCharArray")

	local buffer = {}

	for char in subject:gmatch(".") do
		table.insert(buffer, char)
	end

	return buffer
end

--- Convert a table of characters into a string.
--
-- @param charArray Table of characters to convert to a string.
-- @return A string with each character being the characters as they appear in the charArray.
--
local function fromCharArray (charArray)
	validateParameters(
		{
			charArray = {charArray, Types._table_}
		},
		"StringUtils.fromCharArray")

	local buffer = ""

	for _, char in ipairs(charArray) do
		buffer = buffer .. char
	end

	return buffer
end

--- Iterate over a string, one character at a time.
--
-- @param subject The string to iterate over.
-- @param charHandlerFunction Handler to call with each character, return false from here to stop iteration.
-- @returns True if all characters were iterated through, false if handler broke (as in the statement 'break') the iteration.
--
local function forEachChar (subject, charHandlerFunction)
	validateParameters(
		{
			subject = {subject, Types._string_},
			charHandlerFunction = {charHandlerFunction, Types._function_}
		},
		"StringUtils.forEachChar")

	local buffer = ""
	local idx = 1

	for char in subject:gmatch(".") do
		local returnVal = charHandlerFunction(char, idx, buffer)

		if returnVal == false then
			return false
		end

		buffer = buffer .. char
		idx = idx + 1
	end

	return true
end

--- Explode a string into a table of strings, using the
--	given delimiter.
--
-- @param subject The string to explode.
-- @param delimiter The character(s) that denotes a new sub string.
-- @return Table with an entry per delimited value.
--
local function explode (subject, delimiter)
	validateParameters(
		{
			subject = {subject, Types._string_},
			delimiter = {delimiter, Types._string_}
		},
		"StringUtils.explode")

    local buffer = ""
    local parts = {}

    if subject == delimiter then
		return parts
    end

    forEachChar(subject, function (char, _)
		if char == delimiter then
			if buffer ~= "" then
					table.insert(parts, buffer)
					buffer = ""
			end
		else
			buffer = buffer .. char
		end
    end)

    -- Use output of last iteration.
    if buffer ~= "" then
    	table.insert(parts, buffer)
    end

    return parts
end

--- Take a table and convert it to a string, delimiting each value.
--
-- @param array Table of elements to convert to string, treated like a single dimensional array.
-- @param delimiter Delimiter to use to seperate values.
-- @return String with each value in the table added, delimited by the delimiter string.
--
local function implode (array, delimiter)
	validateParameters(
		{
            array = { array, Types._table_},
			delimiter = {delimiter, Types._string_}
		},
		"StringUtils.implode")

	local implodedString

	for _, value in ipairs(array) do
		implodedString = string.format("%s%s",
			(implodedString and implodedString .. delimiter or ""),
			tostring(value))
	end

	return implodedString
end

--- Does the subject string start with the given string
--	to match?
--
-- @param subject String to check for starting string.
-- @param stringToMatch String to look for at the beginning of the subject.
-- @return True if the subject starts with stringToMatch, otherwise false.
--
local function startsWith (subject, stringToMatch)
	validateParameters(
		{
			subject = {subject, Types._string_},
			stringToMatch = {stringToMatch, Types._string_}
		},
		"StringUtils.startsWith")

    local chars = toCharArray(subject)

	local match = forEachChar(stringToMatch, function (char, idx)
		if chars[idx] ~= char then
			return false
		end
	end)

	return match
end

--- Literal string replacement using character buffers instead of patterns.
--
-- @param subject The string to scan.
-- @param matchString Pattern to match for replacement.
-- @param replaceString String to replace any matches in subject.
-- @return Subject with any matches replaced.
--
local function plainReplace(subject, matchString, replaceString)
	validateParameters(
		{
			subject = {subject, Types._string_},
			matchString = {matchString, Types._string_},
			replaceString = {replaceString, Types._string_}
		},
		"StringUtils.plainReplace")

	local offset = 0
	local buffer = ""

	forEachChar (subject, function (char)
		buffer = buffer .. char
		offset = offset + 1

		local startIdx, endIdx = string.find(buffer, matchString, nil, true)

		if startIdx then
			buffer = buffer:sub(0, startIdx - 1) .. buffer:sub(endIdx + 1)
			offset = endIdx + offset
		end
	end)


	return buffer
end

return
{
	toCharArray = toCharArray,
	fromCharArray = fromCharArray,
	forEachChar = forEachChar,
	explode = explode,
	implode = implode,
	startsWith = startsWith,
	plainReplace = plainReplace
}
