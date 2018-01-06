print('script testLlthreads.lua start')

local luaSocket = require "socket-lanes"
local Threads = require "llthreads.ex"

local threadEntryPoint = function(...)
    print('CHILD: received params:', ...); 

    local args = {...}

    for k,v in pairs(package.loaded) do 
        print(k,v)
    end

    return ...;
end

local socket = luaSocket.tcp();

for k,v in pairs(package.loaded) do 
    print(k,v)
end

local t1 = Threads.new(threadEntryPoint, 'number:', 6543, 'nil:', nil, 'bool:', false); 
local t2 = Threads.new(threadEntryPoint, 'number:', 4453, 'nil:', nil, 'bool:', true); 

assert(t1:start());
--assert(t2:start());


print('PARENT: child 1 returned: ', t1:join())
print('PARENT: child 2 returned: ', t2:join())

print('script testLlthreads.lua end')
