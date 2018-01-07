local ssl = require "ssl"

local convertClientSocketFileDescriptorToHttpDataPipe = require "PuRest.Util.Networking.convertClientSocketFileDescriptorToHttpDataPipe"
local HttpDataPipe = require "PuRest.Http.HttpDataPipe"
local ServerConfig = require "PuRest.Config.resolveConfig"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

--- HTTPS params table using the server config.
local HTTPS_PARAMS =
{
    mode = "server",
    protocol = ServerConfig.https.encryption,
    key = ServerConfig.https.key,
    certificate = ServerConfig.https.certificate,
    verify = "none",
    options = {"all"},
    ciphers = "ALL:!ADH:@STRENGTH",
}

if not ServerConfig.https.enableSSL then
    -- If SSL is not enabled explictly turn it off in params options.
    table.insert(HTTPS_PARAMS.options, "no_sslv2")
    table.insert(HTTPS_PARAMS.options, "no_sslv3")
end

--- Establish a HTTPS connection with a client socket using SSL
-- params in current server config. If there was a problem setting
-- up the encrypted socket or preforming the connection handshake, an
-- error is thrown.
--
-- @param socketFileDescriptor Client socket file descriptor to be encrypted for HTTPS communication.
-- @return An encrypted HttpDataPipe which can be used in place of a client HttpDataPipe.
--
local function initHttps (socketFileDescriptor)
	validateParameters(
		{
			socketFileDescriptor = {socketFileDescriptor, Types._number_}
		})

	local dataPipe = convertClientSocketFileDescriptorToHttpDataPipe(socketFileDescriptor)
	local host, port = dataPipe.getClientPeerName()
	local luaSecSocket, sslWrapError = ssl.wrap(dataPipe.socket, HTTPS_PARAMS)

	if not luaSecSocket or sslWrapError then
		error(string.format("Error wrapping socket connected to %s:%s for HTTPS encryption: %s",
			host,
			port,
			(sslWrapError or "unknown error.")))
	end

	local status, handshakeError = luaSecSocket:dohandshake()

	if not status or handshakeError then
		error(string.format("Error preforming HTTPS handshake for client at %s:%s: %s", 
			host,
			port,
			(handshakeError or "unknown error.")))
	end

	return HttpDataPipe({socket = luaSecSocket, socketHost = host, socketPort = port})
end

return initHttps
