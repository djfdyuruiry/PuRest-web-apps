local luaSocket = require "socket-lanes"

return
{
    getTimeNowInSecs = os.time,
    getTimeNowInMs = luaSocket.gettime
}