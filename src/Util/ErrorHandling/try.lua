local functionTypeStr = "function"

--- Run a block of code in a traditional try block, with options to chain
-- catch and finally handlers as well.
--
-- Any errors are passed directly as a single variable to the catch block.
--
-- You can pass values that will be passed to the try/catch/finally blocks,
-- but it is recommended that you use local upvalues similar to other
-- languages. This is so you can clean up connections/resources in a final
-- block.
--
-- Example of use:
--
-- local object
--
-- try( function ()
--     object = new Object()
--     object:doRiskyStuff()
-- end)
-- .catch( function (ex)
--     print(ex)
-- end)
-- .finally( function ()
--     if object then
--         object:cleanup()
--     end
-- end)
--
-- @param block The block of code to execute as the try block.
-- @param p0-10 Optional parameters to pass to the block when called.
--
-- @return A table that can be used to chain catch/finally blocks. (Call .catch or .finally of the return value)
--
local function try (block, p0, p1, p2, p3, p4, p5, p6, p7, p8, p9)
	local status, err = true, nil

	if type(block) == functionTypeStr then
		status, err = xpcall(function ()
            block(p0, p1, p2, p3, p4, p5, p6, p7, p8, p9)
        end, debug.traceback)
	end

	local finally = function (block, ...)
		if type(block) == functionTypeStr then
			block(...)
		end
	end

	local catch = function (block, ...)
		if not status and type(block) == functionTypeStr then
			local ex = err or "unknown error occurred"
			block(ex, ...)
		end

		return {
			finally = finally
		}
	end

	return
	{
		catch = catch,
		finally = finally
	}
end

return try
