local Serialization = require "PuRest.Util.Data.Serialization"
local StringUtils = require "PuRest.Util.Data.StringUtils"
local Types = require "PuRest.Util.ErrorHandling.Types"
local Url = require "PuRest.Http.Url"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

--- A map of MIME types to serilization handlers for different
-- formats of string based data. Use the from and to methods returned
-- to serialize/deserialize your content. If the MIME type is not supported
-- the map will default to using the tostring standard library function for
-- both to and from methods.
local contentTypes =
{
	["application/json"] =
	{
		from = Serialization.parseJson,
		to = Serialization.serializeToJson
	},

	["application/xml"] =
	{
		from = Serialization.parseXml,
		to = Serialization.serializeToXml
	},

	["application/x-www-form-urlencoded"] =
	{
		from = Url.parseQueryString,
		to = nil
	},

	["multipart/form-data"] =
	{
		from = Url.parseQueryString,
		to = nil
	},

	["text/csv"] =
	{
		from = function (content)
			validateParameters(
				{
					content = {content, Types._string_}
				},
				"ContentTypes.fromTextCsv")

			return StringUtils.explode(content, [[,]])
		end,
		to = function (data)
			validateParameters(
				{
					data = {data, Types._table_}
				},
				"ContentTypes.toTextCsv")

			return StringUtils.implode(data, [[,]])
		end
	},

	["text/plain"] =
	{
		from = tostring,
		to = tostring
	},

	["text/xml"] =
	{
		from = Serialization.parseXml,
		to = Serialization.serializeToXml
	},
}

return setmetatable(contentTypes,
	{
		__index = function (tbl, key)
			local entry = rawget(tbl, key)

            --- Default to text/plain if MIME type is unsupported.
			return entry and entry or rawget(tbl, "text/plain")
		end
	})
