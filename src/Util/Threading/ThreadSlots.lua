local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

--- Generate an array of true (bool) values to represent
-- thread slots.
--
-- @param size The size of the thread slots as a number.
-- @return A table containing thread slot flags as elements.
--
local function generateThreadSlots (size)
	validateParameters(
		{
			size = {size, Types._number_},
		}, "ThreadSlots.generateThreadSlots")

	local slots = {}

	for threadId = 1, size do
		slots[threadId] = true
	end

	return slots
end

--- Reserve the first found free slot in thread slots.
--
-- @param threadSlots A table containing thread slot flags as elements.
-- @return The id of a thread slot that is now reserved for use.
--
local function reserveFirstFreeSlot (threadSlots)
	validateParameters(
		{
			threadSlots = {threadSlots, Types._table_},
		}, "ThreadSlots.reserveFirstFreeSlot")

	for idx, slot in ipairs(threadSlots) do
		if slot == true then
			threadSlots[idx] = false
			return idx
		end
	end

	error("Unable to locate free slot in thread slot list")
end

--- Mark one or more thread slots as free.
--
-- @param threadSlots A table containing thread slot flags as elements.
-- @param indecies A number or table of numbers denoting thread ID(s) to donate
--                 back to the thread pool.
--
local function markSlotsAsFree (threadSlots, indecies)
	local indeciesType = type(indecies)

	if indeciesType == Types._number_ or indeciesType  == Types._table_ then
		indecies = indeciesType == Types._number_ and {indecies} or indecies

		for _, idx in ipairs(indecies) do
			if idx <= #threadSlots then
				threadSlots[idx] = true
			else
				error(string.format("Tried to mark thread slot %d as free, but this exceeds the number of available slots (%d).",
					idx, #threadSlots))
			end
		end
	else
		error(string.format("Bad parameter 'indecies' to markSlotsAsFree, expected number or table, got '%s'.",
			indeciesType))
	end
end

return
{
	generateThreadSlots = generateThreadSlots,
	reserveFirstFreeSlot = reserveFirstFreeSlot,
	markSlotsAsFree = markSlotsAsFree
}
