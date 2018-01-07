if #arg < 2 then
	print("Please pass regex to look for and the worker thread numbers. ex. PurestLogParser '(pattern)' (number)")
	return
end

local logPath = os.getenv("PUREST") or os.getenv("PUREST_WEB")

if not logPath then
	print("Unable to get PuRest log path, check PUREST or PUREST_WEB environment variables or server config.")
	return
end

local pattern = arg[1]

for idx, threadNo in ipairs(arg) do
	if idx ~= 1 then
		pcall(function ()
			for line in io.lines(string.format([[%s\server_request_worker_%d.log]], logPath, threadNo)) do
				if line:match(pattern) then
					print(line)
				end
			end
		end)
	end
end