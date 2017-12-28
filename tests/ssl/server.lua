local apr = require "apr"
local ssl = require "ssl"

local AprToLuaSocketWrapper = require "PuRest.Security.LuaSecInterop.AprToLuaSocketWrapper"

local params = {
	mode = "server",
	protocol = "tlsv1",
	key = [[/home/user/src/lua/purest-web-apps/key.pem]],
	certificate = [[/home/user/src/lua/purest-web-apps/cert.pem]],
	verify = "none",
	options = {"all", "no_sslv2", "no_sslv3"},
	ciphers = "ALL:!ADH:@STRENGTH",
}

local socket = apr.socket_create()

socket:bind("127.0.0.1", 3164)
socket:listen(10)

while true do
    local status,err = pcall(function()
        local clientSocket = socket:accept()

        local client = AprToLuaSocketWrapper(clientSocket)

        client, err = ssl.wrap(client, params)

        if err then
            print(err)
            return
        end

        print(client:dohandshake())
        line, a, b, c, d = client:receive("*l")
        print(a,b,c,d)
        while line and line ~= "" do
            print(line)
            line, a, b, c, d = client:receive("*l")
            print(a,b,c,d)
        end

        print("out")

        print(client:send("HTTP/1.1 200 OK\r\nConnection: close\r\n\r\nHi"))
        print(client:close())
    end)

    if not status then print(err) end
end

