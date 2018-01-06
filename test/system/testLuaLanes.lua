print('script testLuaLanes.lua start')

local l = require 'lanes'.configure(); 

local g = l.gen("io", function(a)
    print('child thread started with parameter: ', a)
end);

local t1 = g(34);
local t2 = g(54);

print(t1:join())
print(t2:join())

print('script testLuaLanes.lua end')
