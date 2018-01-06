local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

--- Build up arguments for a process and execute it with pipes for
-- standard out/error.
--
-- @param path Path to the process binary.
-- @param humanReadableName Readable version of the process name.
-- @param args optional Table of command line arguments to pass to the process,
--                      with each token on the command line being a sequenital element
--                      (You may need to escape double quotes for some arguments).
-- @param readTimeout Timeout for reading the standard out/error.
--
local function Process (path, humanReadableName, args)
	validateParameters(
		{
			path = {path, Types._string_},
			humanReadableName = {humanReadableName, Types._string_}
		}, "Process.construct")
		
	local humanReadableName = humanReadableName or path
	local argsString = ""

	if args then
		validateParameters(
			{
				args = {args, Types._table_}
			}, "Process.construct")
		
		argsString = table.concat(args, " ")
	end

    --- Read all data from a pipe stream.
    --
    -- @param stream Process pipe stream.
    -- @param streamType Type of stream "out" | "err".
    -- @return String containing all data read from the stream.
    --
	local function readAndCloseStream (stream, streamType, standardErrorFilename)
		local out, readErr = stream:read('*all')

		pcall(function()
			stream:close()
		end)

		if streamType == "err" then
			pcall(function()
				os.remove(standardErrorFilename)
			end)
		end

		if not out and readErr then
			error(string.format("Error while reading from %s steam for '%s' -> %s.", streamType, humanReadableName,
				readErr or "unknown error"))
		end

		return out
	end

    --- Get a pipe stream for a given process.
    --
    -- @param process Process handle to use to get pipe stream.
    -- @param streamType Type of stream "out" | "err".
    -- @return A new stream handle for the pipe specified.
    --
	local function createStream(process, streamType, standardErrorFilename)
		local stream, streamCreateErr

		streamType = streamType:lower()

		if streamType == "out" then
			stream = process
		elseif streamType == "err" then
			stream, streamCreateErr = io.open(standardErrorFilename, "r")
		end

		if not stream then
			error(string.format("Failed to open %s steam for '%s' -> %s.", streamType, humanReadableName,
				streamCreateErr or "unknown error"))
		end

		return stream
	end

    --- Run the process handle with the arguments specified, this
    -- can be called multiple times. An error is thrown if there is an issue setting
    -- up the process or any output was written to standard err from the process.
    --
    -- @return A string containing all the output from process standard out.
    --
	local function run ()
		local standardErrorFilename = os.tmpname()
		local proc, createErr = io.popen(string.format("%s %s 2> %s", path, argsString, standardErrorFilename))

		if not proc then
			error(string.format("Failed to open process for '%s' -> %s.", humanReadableName, createErr or "unknown error"))
		end

		local err = readAndCloseStream(createStream(proc, "err", standardErrorFilename), "err", standardErrorFilename)

		if err and err ~= "" then
			error(string.format("Process '%s' threw an error -> %s.", humanReadableName, err))
		end

		return readAndCloseStream(createStream(proc, "out"), "out")
	end

	return
	{
		run = run
	}
end

return Process
