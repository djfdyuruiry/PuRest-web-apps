return
--- Table containing all Lua types as keys, in the format _%type%_, and
-- each value is the corresponding type string.
{
	_nil_ = type(nil),
	_boolean_ = type(true),
	_number_ = type(0),
	_string_ = type(""),
	_userdata_ = "userdata",
	_function_ = type(function()end),
	_thread_ = "thread",
	_table_ = type({})
}
