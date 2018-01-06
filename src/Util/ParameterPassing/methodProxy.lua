local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"
local Types = require "PuRest.Util.ErrorHandling.Types"

--- Allows storing an instance method in a variable, but
-- keep the implicit object reference passing.
--
-- @param object Table or userdata to call method on.
-- @param method Name of the method to be called.
-- @return Proxy function to call method.
--
local function methodProxy(object, method)
	validateParameters(
		{
			method = {method, Types._string_}
		},
		"methodProxy")

	assert(type(object) == Types._table_ or type(object) == Types._userdata_,
        string.format("Error: object passed to instanceProxy for method '%s' was nil.", method))

	return function (...)
		return object[method](object, ...)
	end
end

return methodProxy
