--- Map of HTTP status codes to human reabled status text. (Keys are strings)
-- Defaults to empty string on unknown HTTP status code.
local textCodeMap = {}

textCodeMap["200"] = "OK"
textCodeMap["201"] = "Created"
textCodeMap["400"] = "Bad Request"
textCodeMap["401"] = "Unauthorized"
textCodeMap["403"] = "Forbidden"
textCodeMap["404"] = "Not Found"
textCodeMap["500"] = "Internal Server Error"

return setmetatable( textCodeMap,
	{
		__index = function (tbl, key)
			return rawget(tbl, tostring(key)) or ""
		end
	})
