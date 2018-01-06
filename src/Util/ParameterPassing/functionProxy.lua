local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"
local Types = require "PuRest.Util.ErrorHandling.Types"

--- Return a function which will call the given function with given arguments.
--
-- @param functionToCall Function to be called.
-- @param arg0-10 Arguments to pass to the function.
-- @returns Proxy function to call original function with arguments.
--
local function functionProxy (functionToCall, arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10)
	validateParameters(
		{
            functionToCall = {functionToCall, Types._function_}
		},
		"functionProxy")

	return function()
		return functionToCall(arg0, arg1, arg2, arg3, arg4,arg5, arg6, arg7, arg8, arg9, arg10)
	end
end

return functionProxy
