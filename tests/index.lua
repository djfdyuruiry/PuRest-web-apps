--[[
	Test site to be used in manual and automated testing
	of the web server, areas covered by this site:

		- Page Requests (/index.html)
		- URL Parameters (/)
		- URL Routing (/params/{x} | /params/{x}/{x} | /{x}/params | /{x}/params/{x} | /{x}/params/{x}/{x} | /{x}/{x}/params)
		- REST API (/api/test)
		- Server Sessions (/session)
		- MVC Views (/view.lhtml)
		- Web Form Data Upload (/form)
		- HTTP Authentication (Digest) (/authentication_test.html)
]]

local generateSiteConfig = require "PuRest.Config.generateSiteConfig"
local processView = require "PuRest.View.processView"
local RouteMap = require "PuRest.Routing.RouteMap"
local Route = require "PuRest.Routing.Route"
local SecurityProvider = require "PuRest.Security.SecurityProvider"
local Serialization = require "PuRest.Util.Data.Serialization"
local ServerConfig = require "PuRest.Config.resolveConfig"
local Types = require "PuRest.Util.ErrorHandling.Types"

local OUTPUT_HTML = [[
	<html>
		<head>
			<title>%s</title>
		</head>
		<body>%s</body>
	</html>
]]

-- Server debug web page, prints out the various data received from the client.
local function debugPage (urlArgs, queryStringArgs, httpState, siteConfig)
	httpState.response.responseFormat = "text/html"

	local session = httpState.session
	session.clientVisits = session.clientVisits or 0
	session.clientVisits = session.clientVisits + 1

	local model =
	{
		serialize = function(s)
			return Serialization.serializeToJson(s, true)
		end,
		serverConfig = ServerConfig,
		session = session
	}

	return processView("debug", model, siteConfig, urlArgs, queryStringArgs, httpState)
end

--URL PARAMS
local function urlParamsTest (urlArgs, _, httpState)
	local write = httpState.response.write
	local title = "URL Parameters Test"
	local urlArgHtml = ""

	for k, v in pairs(urlArgs) do
		if tostring(k):match("^param") then
			urlArgHtml = urlArgHtml .. string.format("<p id='%s'>%s</p>", k, tostring(v))
		end
	end

	httpState.response.responseFormat = "text/html"

	write(string.format(OUTPUT_HTML, title, urlArgHtml))
end

--URL ROUTING
local function urlRoutingTest (_, _, httpState)
	local write = httpState.response.write

	httpState.response.responseFormat = "text/html"

	write(string.format(OUTPUT_HTML, "URL Routing Test", "<h1>Routed to alternate index page!</h1>"))
end

--REST API
local function restApiTest (_, _, httpState)
	httpState.response.responseFormat = "application/json"

	return
	{
		id = 0,
		status = "SUCCESS",
		values = {0,1,2,3,4,5}
	}
end

--SESSIONS
local function sessionTest (_, _, httpState)
	local write = httpState.response.write
	local session = httpState.session

	session.clientVisits = session.clientVisits or 0
	session.clientVisits = session.clientVisits + 1

	httpState.response.responseFormat = "text/html"

	write(string.format(OUTPUT_HTML, "Session Test", "<h3 id='sessionVisits'>" ..session.clientVisits .. "</h1>"))
end

--MVC VIEW TEST
local function mvcViewTest (_, _, httpState, siteConfig)
	httpState.response.responseFormat = "text/html"

	return processView("view", {title = "MVC View Test", name = "bob"}, siteConfig)
end

--FORM SUBMISSION
local function formDataTest (_, queryStringArgs, httpState)
	local write = httpState.response.write
	local formData = httpState.request.method == "GET" and queryStringArgs or httpState.request.body
	local body = ""

	if type(formData) == Types._table_ then
		for key, value in pairs(formData) do
			body = body .. string.format("<p id='%s'>%s</p>", key, value)
		end
	else
		body = string.format("<h1>Non web form data POSTed to server (Type: %s), data in body: %s</h1>",
			(httpState.request.headers["Content-Type"] or "unknown content type"),
			tostring(httpState.request.body))
	end

	httpState.response.responseFormat = "text/html"

	write(string.format(OUTPUT_HTML, "Form Data Test", body))
end

local function methodTest (_, _, httpState)
	local write = httpState.response.write

	httpState.response.responseFormat = "text/html"

	write(string.format(OUTPUT_HTML, "HTTP Method Test", "<h1>Acceptable HTTP method used to request route!</h1>"))
end

local function responseSerializationTest (_, _, httpState)
	httpState.response.responseFormat = httpState.request.headers["Content-Type"]:match([[(.*);]]) or httpState.request.headers["Content-Type"]

	if httpState.response.responseFormat == "application/json" then
		return
		{
			field = "value"
		}
	elseif httpState.response.responseFormat == "application/xml" then
		local xmlTable = {}

		xmlTable[1] = "value"
		xmlTable.xml = "field"

		return xmlTable
	elseif httpState.response.responseFormat == "text/csv" then
		return { 1, 2, 3 }
	end
end

-- Routes
local routes = RouteMap(true, true)

	-- URL Parameter variations
routes.addRoute(Route("urlParamsTest", "*", "/params/{param0}", urlParamsTest))
routes.addRoute(Route("urlParamsTest", "*", "/params/{param0}/{param1}", urlParamsTest))
routes.addRoute(Route("urlParamsTest", "*", "/{param0}/params", urlParamsTest))
routes.addRoute(Route("urlParamsTest", "*", "/{param0}/params/{param1}", urlParamsTest))
routes.addRoute(Route("urlParamsTest", "*", "/{param0}/params/{param1}/{param2}", urlParamsTest))
routes.addRoute(Route("urlParamsTest", "*", "/{param0}/{param1}/params", urlParamsTest))

routes.addRoute(Route("urlRouteTest", "*", "/", urlRoutingTest))
routes.addRoute(Route("restApiTest", "*", "/api/test", restApiTest))
routes.addRoute(Route("sessionTest", "*", "/session", sessionTest))
routes.addRoute(Route("mvcViewTest", "*", "/view", mvcViewTest))
routes.addRoute(Route("formDataTest", "*", "/form", formDataTest))

routes.addRoute(Route("httpMethodTest", "GET", "/method", methodTest))
routes.addRoute(Route("httpMethodTest", "POST", "/responsecontent", responseSerializationTest))

routes.addRoute(Route("debug", "*", "/debug", debugPage))

-- Site config
local siteConfig = generateSiteConfig(true)

siteConfig.name = "PuRest Test Site"
table.insert(siteConfig.doNotServeTheseFiles, "*.bmp")

-- Authentication config.
siteConfig.authentication.enableAuthentication = true
siteConfig.authentication.requireAuthenticationEverywhere = false

-- Security provider.
siteConfig.authentication.securityProvider = SecurityProvider(siteConfig.name, "Digest")

siteConfig.authentication.securityProvider.authorize = function (authorizationData)
	return authorizationData and authorizationData.userName:lower() == "user", "password"
end

siteConfig.authentication.authenticationRouteMap = RouteMap(false, false)
siteConfig.authentication.authenticationRouteMap.addRoute(Route("authenticationTest", "*", "/authentication_test.html", function() end))


return
{
	routeMap = routes,
	siteConfig = siteConfig
}
