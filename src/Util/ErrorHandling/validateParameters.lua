local getCallingFunctionInfo = require "PuRest.Util.Reflection.getCallingFunctionInfo"
local Types = require "PuRest.Util.ErrorHandling.Types"

local function assertParameterTypeIsCorrect (name, parameter, callerInfo)
	local displayName = tostring(name)
	local expectedParameterType = parameter[2]

	if type(expectedParameterType) ~= Types._string_ then
		error(string.format("No type specified for parameter '%s', for function '%s'", 
			displayName, 
			callerInfo))
	end

	local actualParameterType = type(parameter[1])
	local paramTypeCorrect = actualParameterType == expectedParameterType

	assert(paramTypeCorrect, string.format("bad argument '%s' to function '%s', excepted %s got %s", 
		displayName,
		callerInfo, 
		expectedParameterType, 
		actualParameterType))
end

--- Validate the parameters given to a function by performing type checking.
--
-- @param paramsDictionary Dictionary with entries in the format: name => {value, expectedType[, optional = true|false]}.
-- @param funcName The name of the function calling for validation (NOT USED).
-- @param callingSelf Base case for validateParameters recursion.
--
local function validateParameters (paramsDictionary, _, callingSelf)
	if not callingSelf then
		validateParameters(
			{
				paramsDictionary = {paramsDictionary, Types._table_}
			},
			"validateParameters", true)
	end

    local callerInfo = getCallingFunctionInfo()

	for name, parameter in pairs(paramsDictionary) do
		local isOptional = false

		if type(parameter.isOptional) == Types._boolean_ then
			isOptional = parameter.isOptional
		end

		if not isOptional or (isOptional and parameter[1]) then
			assertParameterTypeIsCorrect(name, parameter, callerInfo)
		end
	end
end

return validateParameters
