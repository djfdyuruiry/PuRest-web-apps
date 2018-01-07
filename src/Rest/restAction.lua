local MimeTypeDictionary = require "PuRest.Util.File.MimeTypeDictionary"
local try = require "PuRest.Util.ErrorHandling.try"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

local DEFAULT_RES_FORMAT = MimeTypeDictionary["json"]

--- Simple rest action template that executes a function
-- in a try block, passing in the result object which one
-- can assign data/fields to. Try to assign return values
-- to the data field.
--
-- You can also set the response format of the HTTP response and
-- attach handlers which fire when the action throws an error or
-- after action and/or error.
--
-- @param action The function to call with the result object.
-- @param httpState Current HTTP state object.
-- @param finallyHandler optional Handler that fires after action/error blocks finish.
-- @param responseFormat optional Set the HTTP response format to this string.
-- @param errorHandler optional Handler that fires when the action block throws an error.
--
-- @return A table containing that details the result of the rest action.
--          Format: {data, status, error[,...]}
--
local function restAction (action, httpState, finallyHandler, responseFormat, errorHandler)
	validateParameters(
		{
			action = {action, Types._function_},
			httpState = {httpState, Types._table_}
		})

	local responseFormat = type(responseFormat) == Types._string_ and responseFormat or DEFAULT_RES_FORMAT

	httpState.response.responseFormat = responseFormat

	-- Prepare result object template.
	local result =
	{
		data = nil,
		status = "SUCCESS",
		error = nil
	}

	-- Preform action.
	try(
		action,
		result
	)
	.catch(function (ex)
		result.status = "ERROR"
		result.error = ex

		result.data = nil

		-- Pass error to end user.
		if type(errorHandler) == Types._function_ then
			errorHandler(result, ex)
		end
	end)
	.finally( function ()
		-- Pass error to end user.
		if type(finallyHandler) == Types._function_ then
			finallyHandler(result)
		end
	end)

	return result
end

return restAction
