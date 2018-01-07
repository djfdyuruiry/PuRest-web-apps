local luaSocket = require "socket-lanes"
local dns = luaSocket.dns

local ClientDataPipe = require "PuRest.Http.ClientDataPipe"
local functionProxy = require "PuRest.Util.ParameterPassing.functionProxy"
local methodProxy = require "PuRest.Util.ParameterPassing.methodProxy"
local ServerConfig = require "PuRest.Config.resolveConfig"
local ServerDataPipe = require "PuRest.Http.ServerDataPipe"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

local CONSTRUCTOR_PARAM_ERR = "HttpDataPipe: You must pass a table containing either {host=..,port=..} if you want " ..
	"a server data pipe or {socket=..} when building a client HTTP channel."

--- Abstract interface for server components to use to digest a HTTP data stream
-- from a network socket. Server config is applied to socket config and server
-- sockets are bound in the constructor; supports both LuaSocket and LuaSec libraries.
--
-- @param params A table containing either {host=..,port=..} if you want a server data pipe 
--				 	or {socket=..} when building a LuaSocket client HTTP channel
--				 	or {socket=..,socketHost=...,socketPort=...} when building a LuaSocket client HTTP channel
--
-- Below are the fields common to server and client instances:
--
--  socket        -> Get the socket inside the HttpDataPipe.
--
-- Below are the methods common to server and client instances:
--
--  getHostName   -> Get the hostname for the socket.
--
--  terminate     -> Close the socket.
--
-- See ServerDataPipe and ClientDataPipe classes for futher method information.
--
local function HttpDataPipe (params)
	validateParameters(
		{
			params = {params, Types._table_}
		})

	local dataPipe
	local socket
	local usingLuaSecSocket

	local function construct ()
		-- TODO: investigate issues with timeouts...
		--local conTimeout = ServerConfig.connectionTimeOutInMs > 0 and ServerConfig.connectionTimeOutInMs * 1000 or 10000

		if params.host and params.port then
			dataPipe, socket, usingLuaSecSocket = ServerDataPipe(params)
		elseif params.socket then
			dataPipe, socket, usingLuaSecSocket = ClientDataPipe(params)
		else
			error(CONSTRUCTOR_PARAM_ERR)
		end

		dataPipe.socket = socket
		dataPipe.getHostName = functionProxy(dns.gethostname)
		dataPipe.terminate = methodProxy(socket, "close")

		--socket:timeout_set(conTimeout)

	--[[
		Ignore if this set option fails as this requires admin/sudo access

		SO_DEBUG
			Enable socket debugging. Allowed only for processes with the
			CAP_NET_ADMIN capability or an effective user ID of 0.

		see: http://man7.org/linux/man-pages/man7/socket.7.html
	]]
		if not usingLuaSecSocket then
			pcall(methodProxy(socket, "setoption"), "debug", true)
		end

		return dataPipe
	end

	return construct()
end

return HttpDataPipe
