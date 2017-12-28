local restAction = require "PuRest.Rest.restAction"
local RouteMap = require "PuRest.Routing.RouteMap"
local Route = require "PuRest.Routing.Route"

local Employee = forceRequire "employees.entities.Employee"

local restApi = RouteMap(true, true)

restApi.addRoute(Route("addEmployee", "POST", "/api/employees", function (_, _, httpState)
    return restAction( function (result)
        local employee = httpState.request.body

        result.data = Employee.addEmployee(employee)

        httpState.response.status = 201
    end, httpState, function ()
        Employee.cleanup()
    end)
end))

restApi.addRoute(Route("getEmployee", "GET", "/api/employees/{emp_no}", function (urlArgs, _, httpState)
    return restAction( function (result)
        local employee = Employee.getEmployee(urlArgs["emp_no"])

        if not employee then
            result.error = "Unable to find employee in database."
            result.status = "ERROR"
        else
            result.data = employee
        end
    end, httpState, function ()
        Employee.cleanup()
    end)
end))

restApi.addRoute(Route("updateEmployee", "PUT", "/api/employees/{emp_no}", function (urlArgs, _, httpState)
    return restAction( function (result)
        local employee = httpState.request.body
        employee.emp_no = urlArgs["emp_no"]

        result.data = Employee.updateEmployee(employee)
    end, httpState, function ()
        Employee.cleanup()
    end)
end))

restApi.addRoute(Route("deleteEmployee", "DELETE", "/api/employees/{emp_no}", function (urlArgs, _, httpState)
    return restAction( function ()
        Employee.deleteEmployee(urlArgs["emp_no"])
    end, httpState, function ()
        Employee.cleanup()
    end)
end))

restApi.addRoute(Route("searchForEmployees", "POST", "/api/employees/search", function (_, _, httpState)
    return restAction( function (result)
        local post = httpState.request.body or {}
        local names = post.names

        result.data = Employee.searchForEmployees(names)
    end, httpState, function ()
        Employee.cleanup()
    end)
end))

return restApi
