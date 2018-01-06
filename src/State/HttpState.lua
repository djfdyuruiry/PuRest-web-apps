local date = require "date"

local gzipCompressString = require "PuRest.Util.Data.gzipCompressString"
local log = require "PuRest.Logging.FileLogger"
local LogLevelMap = require "PuRest.Logging.LogLevelMap"
local TextCodeDictionary = require "PuRest.State.TextCodeDictionary"
local Server = require "PuRest.Server.Server"
local ServerConfig = require "PuRest.Config.resolveConfig"
local Timer = require "PuRest.Util.Time.Timer"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

local PROTECTED_HEADERS =
{
    "Connection",
    "Content-Type",
    "Server",
    "Content-Encoding",
    "Date",
    "Content-Length"
}

--- Represents a HTTP request and response as it is processed
-- by server logic and end user web apps. The request field describes
-- the original request and the response field provides a write method
-- to write to the response body, check for client support of HTTP compression
-- via the shouldCompress method. To get a fully formatted HTTP response as a
-- string use the getFormattedHeadersAndContent method of the response field
--
-- @param method HTTP method used. (Request)
-- @param ipAddress IP address of client. (Request)
-- @param host Host header value. (Request)
-- @param port Client port as a string. (Request)
-- @param location Location string from HTTP header. (Request)
-- @param protocol Protocol specified in HTTP header. (Request)
-- @param headers Table of HTTP headers collected. (Request)
-- @param authorizationData optional A table of authorization data extracted from HTTP headers. (Request)
-- @param body optional Text body of the HTTP request.
-- @param session Table holding session data for client on requested site.
--
local function HttpState (method, ipAddress, host, port, location, protocol,
                          headers, authorizationData, body, session)
	validateParameters(
		{
			method = {method, Types._string_},
			host = {host, Types._string_},
			location = {location, Types._string_},
			protocol = {protocol, Types._string_},
			headers = {headers, Types._table_},
			session = {session, Types._table_}
		},
		"HttpState")

	--- State of the HTTP request.
	local request =
	{
		method = method,
		ipAddress = ipAddress,
		host = host,
		port = port,
		location = location,
		protocol = protocol,
		headers = headers,
		authorizationData = authorizationData,
		body = body
	}

	--- State of the HTTP response.
	local response =
	{
		content = "",
		status = 200,
		responseFormat = "text/plain",
		headers = {}
	}

	--- Proxy function to append output to the response content string.
	-- Behaves like string.format(), so you can pass format parameters with
	-- the string.
	--
	-- @param str The string to append.
	-- @param ... Additional parameters to format string.
	--
	response.write = function (str, ...)
		validateParameters(
			{
				str = {str, Types._string_}
			}, "HttpState.response.write")

		-- Use str as format string if additonal parameters were passed in.
		if ... then
			str = string.format(str, ...)
		end

		response.content = string.format("%s%s", response.content, str)
    end

    --- Is the specified header name in the list of protected server headers?
    --
    -- @param headerName A string specifing the header name to check.
    -- @return True if the given header is protected, false otherwise.
    --
    local function isProtectedHttpHeader (headerName)
        validateParameters(
            {
                headerName = {headerName, Types._string_}
            }, "HttpState.isProctectHttpHeader")

        for _, header in ipairs(PROTECTED_HEADERS) do
            if headerName:lower() == header:lower() then
                return true
            end
        end

        return false
    end

    --- Should the response body be compressed? Check the the Accept-Encoding HTTP
    -- header indicates the client supports gzip compression.
    --
    -- @param responseContent String containing content for HTTP response.
    -- @return True if response body should be compressed, false otherwise.
    --
    response.shouldCompress = function (responseContent)
        validateParameters(
            {
                responseContent = {responseContent, Types._string_}
            }, "HttpState.response.shouldCompress")

        if not ServerConfig.supportHttpCompression
           or ServerConfig.httpCompressionLevel < 1
           or string.len(responseContent) < ServerConfig.httpCompressionMinContentSizeInBytes then
            return false
        end

        local encoding = request.headers["Accept-Encoding"]

        if encoding and encoding:match("gzip") then
            log("Marking response body for compression as client supports gzip.", LogLevelMap.INFO)
            return true
        end

        return false
    end

	--- Get formatted headers and content from response. Alt parameters
	-- are used if any of the request/response fields are nil. Returned header
    -- string has neccessary double '/r/n' appended to the end.
	--
    -- The alternate parameters here speicify data to use if the related fields in
    -- the response or request tables are nil.
    --
	-- @param protocolAlt Alternate HTTP protocol.
	-- @param statusAlt Alternate HTTP status code.
	-- @param contentAlt Alternate response content.
	-- @param respFormatAlt Alternate response content format.
	-- @return String containing formatted headers and a string containing the content(possibly compressed).
	--
	response.getFormattedHeadersAndContent = function(protocolAlt, statusAlt, contentAlt, respFormatAlt)
        validateParameters(
            {
                protocolAlt = {protocolAlt, Types._string_},
                statusAlt = {statusAlt, Types._number_},
                contentAlt = {contentAlt, Types._string_},
                respFormatAlt = {respFormatAlt, Types._string_}
            }, "HttpState.response.getFormattedHeadersAndContent")

        local timer = Timer()

        local protocol = request.protocol or protocolAlt
        local status = response.status or statusAlt
        local textCode = TextCodeDictionary[status]

        local date, dateErr = date():fmt("${http}")
        local responseFormat = response.responseFormat or respFormatAlt
        local responseContent = response.content or contentAlt

        -- HTTP basic response line, e.g. "HTTP 200 OK".
		local headers = string.format("%s %d %s\r\n", protocol, status, textCode)

        -- Date header, e.g. "Date: Tue, 15 Nov 1994 08:12:31 GMT".
        if not date or dateErr then
            log(string.format("Unable to fetch current datetime to use in 'Date' header of HTTP response: %s.",
                (dateErr or "unknown error")), LogLevelMap.WARN)
        else
            headers = headers .. string.format("Date: %s\r\n", date)
        end

        --[[ Connection, Content-Type and Server headers, e.g.
                "Connection: close"
                "Content-Type: text/html; charset=utf-8"
                "Server: Apache/2.4.1 (Unix)"
        --]]
        -- TODO: replace platform_get call with luarocks logic or consider defining this upfront using powershell or similar
        -- see https://github.com/luarocks/luarocks/blob/master/src/luarocks/core/cfg.lua
		local headers = string.format("%sConnection: %s\r\nContent-Type: %s; charset=UTF-8\r\nServer: PuRest/%s (%s)\r\n",
                headers, (request.headers["Connection"] or "close"), responseFormat,
                Server.PUREST_VERSION, ("UNIX" or "?"))

        -- Compress content if possible using gzip.
		if response.shouldCompress(responseContent) then
			local compressTimer = Timer()
            local isIe = false -- TODO: Check if the requesting browser is IE versions ?-? and truncate gzip bytes.

            -- Add Content-Encoding header to signal HTTP compression to client.
			headers = headers .. "Content-Encoding: gzip\r\n"
			responseContent = gzipCompressString(responseContent, ServerConfig.httpCompressionLevel, isIe)

			log(string.format("Compressing response content took %s ms.", compressTimer.endTimeNow()), LogLevelMap.DEBUG)
		end

        if type(response.headers) == Types._table_ then
            --Add any additional headers specified in the response table, excluding protected headers.
            for headerName, headerValue in pairs(response.headers) do
                local headerNameStr = tostring(headerName)

                if not isProtectedHttpHeader(headerNameStr) then
                    headers = headers .. string.format("%s: %s\r\n", headerNameStr, tostring(headerValue))
                end
            end
        else
            log(string.format("Unable to load custom headers into HTTP response: headers field of response object was of type %s, but table was expected",
                type(response.headers)), LogLevelMap.WARN)
        end

        -- Content-Length header (added here to account for changed size after compression), e.g. "Content-Length: 348".
		headers = headers .. string.format("Content-Length: %d\r\n\r\n", #responseContent)

		log(string.format("Getting formatted headers and content took %s ms.", timer.endTimeNow()), LogLevelMap.DEBUG)

		return headers, responseContent
	end

	return
	{
		request = request,
		response = response,
		session = session
	}
end

return HttpState
