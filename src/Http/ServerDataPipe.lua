local luaSocket = require "socket-lanes"

local methodProxy = require "PuRest.Util.ParameterPassing.methodProxy"
local ServerConfig = require "PuRest.Config.resolveConfig"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

-- ServerDataPipe class, available methods:
--
--  waitForClient -> Wait for a client to connect and return client socket.
--
local function ServerDataPipe(params)
    validateParameters(
        {
            params_host = {params.host, Types._string_},
            params_port = {params.port, Types._number_}
        })

    local function construct()
        local socket = luaSocket.tcp()

        local _, bindErr = socket:bind(params.host, params.port)

        if not socket or bindErr then
            error(string.format("Unable to bind server socket to %s:%d: %s.", params.host, params.port,
                (bindErr or "unknown error")))
        end
        
        local conBacklog = ServerConfig.connectionBacklog > 0 and ServerConfig.connectionBacklog or "max"
        
        local _, listenErr = socket:listen(conBacklog)

        if listenErr then
            error(string.format("Unable to listen on server socket to %s:%d: %s.", params.host, params.port,
                (listenErr or "unknown error")))
        end
        
        if ServerConfig.socketReceiveBufferSize > 0 then
            socket:setoption("rcvbuf", ServerConfig.socketReceiveBufferSize)
        end

        local dataPipe =
        {
            waitForClient = methodProxy(socket, "acceptfd")
        }
        
        return dataPipe, socket, false
    end

    return construct()
end

return ServerDataPipe
