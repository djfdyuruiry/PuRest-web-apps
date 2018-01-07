local generateSiteConfig = require "PuRest.Config.generateSiteConfig"

local routes = forceRequire "employees.api.rest"
local EmployeesController = forceRequire "employees.EmployeesController"

routes.addRoute(EmployeesController.index)
routes.addRoute(EmployeesController.employee)

local siteConfig = generateSiteConfig(true)
siteConfig.directoryServingEnabled = false

return
{
	routeMap = routes,
    siteConfig = siteConfig
}
