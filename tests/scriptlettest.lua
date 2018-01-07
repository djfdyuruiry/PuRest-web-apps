JSON = require "json"

local Scriptlet = require "PuRest.View.Scriptlet"

local lhtml = [[
<!doctype html>
<html>
<head>
	<title>
		<%= string.format("Pu(R)est | %s", config.name) %>
	</title>
</head>
<body>
	<% model.num = 20 %>

	<script>
		var model = <%$ { some = "arbitrary data" } %>;
	</script>

	<div data-bind="annoy>you">
	    <% for idx, item in ipairs(model.basketItems) do
			write(string.format("<h1>%s</h1>", item.name))
			write(string.format("<h3>%s</h3>", item.price))
        end %>
	</div>
</body>
<html>
]]

local env = Scriptlet.buildEnvironment(
	{
		num = 1,
		str = "one",
		basketItems =
		{
			{name = "Toilet Roll", price = "£1.30"},
			{name = "Biscuits", price = "£0.65"} ,
			{name = "Milk", price = "£0.99" }
		}
	},
	{ name = "site" } )

local scriptlets, html = Scriptlet.harvestFromBuffer(lhtml)

for _, scriptlet in ipairs(scriptlets) do
	local executionStatus, returnValOrErr = Scriptlet.evaluate(scriptlet, env)

	if not executionStatus then
		error(string.format("Error processing view '%s', script '%s': %s", "test", scriptlet.script,
			returnValOrErr))
	end

	if not returnValOrErr then
		-- Clear UID marker from HTML.
		returnValOrErr = ""
	end

	html = html:gsub(scriptlet.replaceUid, returnValOrErr)
end

print(html)
print("===========================")
print(JSON:encode_pretty(env.model))
