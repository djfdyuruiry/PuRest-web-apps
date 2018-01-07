local methodProxy = require "PuRest.Util.ParameterPassing.methodProxy"
local ServerConfig = require "PuRest.Config.resolveConfig"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

-- ClientDataPipe class, available methods:
--
--  isBaseSocketLuaSocketWrapper  -> Is the base socket an instance of LuaSocketWrapper?
--
--  getClientPeerName             -> Get the network peer name and socket, pass in true to get both values
--                                           together in one string delimited by a ':'.
--
--  getMethodLocationProtocol     -> See HttpDataPipe getMethodLocationProtocol method above.
--
--  getHeaders                    -> See HttpDataPipe getHeaders method above.
--
--  read                          -> Read data from socket. (format specifier can be passed in)
--
--  readLine                      -> Read a line of text from the socket.
--
--  readChars                     -> Read a number of characters from the socket,
--                                           only parameter is number of chars.
--
--  write                         -> Write data to the socket.
--
local function ClientDataPipe(params)
    validateParameters(
        {
            params_socket = {params.socket, Types._userdata_}
        })

	-- certain features don't work with LuaSec sockets, we need a flag to avoid these
    local usingLuaSecSocket = params.socket.setoption == nil

    if usingLuaSecSocket then
        validateParameters(
            {
                params_socketHost = {params.socketHost, Types._string_},
                params_socketPort = {params.socketPort, Types._string_}
            })
    end

	-- LuaSocket or LuaSec socket class instance
	local socket

	-- LuaSec sockets don't support getting client details, instead we pass these in params
	local socketHost, socketPort

	local function readLine ()
		local response, err = socket:receive("*l")

		if err then
			error(string.format("Socket receive line error: '%s'", tostring(err)))
		end

		return response
	end

	--- Read in a line from the data pipe and pattern match inital HTTP request line.
	--
	-- @return Captures for method, location and protocol.
    --
	local function getMethodLocationProtocol ()
		local request = readLine() or ""
		return request:match('^(%w+)%s+(%S+)%s+(%S+)')
	end

	--- Get all headers from the start of a HTTP request stream.
    --
	-- @return HTTP header dictionary.
	--
    local function getHeaders ()
		local headers = {}
		local line = readLine()

		while line do
			line = line:gsub("\r", "") or line
			local name, value = line:match '^(%S+):%s+(.-)$'

			-- An empty line separates request headers and the body.
			if not name then
				break
			end

			headers[name] = value or ""
			line = readLine()
		end

		return headers
	end

	local function getClientPeerName (format)
		local host, port
		
		if not usingLuaSecSocket then
			host, port = socket:getpeername()
		else
			host, port = socketHost, socketPort
		end

		if format then
			return tostring(host) .. ":" .. tostring(port) 
		else
			return tostring(host), tostring(port)
		end
    end

    local function isBaseSocketLuaSocketWrapper()
        return usingLuaSecSocket
    end

    local function construct()
        socket = params.socket
			
        if usingLuaSecSocket then 
            socketHost = params.socketHost
            socketPort = params.socketPort
        end

        if ServerConfig.socketSendBufferSize > 0 and not usingLuaSecSocket then
            socket:setoption("sndbuf", ServerConfig.socketSendBufferSize)
        end

        local dataPipe =
        {
            getClientPeerName = getClientPeerName,
            getMethodLocationProtocol = getMethodLocationProtocol,
            getHeaders = getHeaders,
            read = methodProxy(socket, "receive"),
            readLine = readLine,
            readChars = methodProxy(socket, "receive"),
            write = methodProxy(socket, "send"),
            isBaseSocketLuaSocketWrapper = isBaseSocketLuaSocketWrapper
		}
		
		return dataPipe, socket, usingLuaSecSocket
    end

    return construct()
end

return ClientDataPipe
