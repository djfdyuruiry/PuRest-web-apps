local processView = require "PuRest.View.processView"
local Route = require "PuRest.Routing.Route"
local try = require "PuRest.Util.ErrorHandling.try"

local Employee = forceRequire "employees.entities.Employee"

return
{
    index = Route("index", {"GET", "POST"}, "/", function (_, _, httpState, siteConfig)
        local post = httpState.request.body
        local model = {}

        if type(post) == "table" then
            local postStatus

            try( function()
                local employee = post
                local mode = post.mode
                local emp_no = post.emp_no

                if mode == "edit" then
                    Employee.updateEmployee(employee)
                    postStatus = "Updated employee"
                elseif mode == "delete" then
                    Employee.deleteEmployee(emp_no)
                    postStatus = "Deleted employee"
                elseif mode == "create" then
                    Employee.addEmployee(employee)
                    postStatus = "Added employee"
                end
            end)
            .catch( function (ex)
                postStatus = string.format("Error while processing POST data")
                print(ex)
            end)

            model.postStatus = postStatus
        end

        httpState.response.responseFormat = "text/html"
        return processView("index", model, siteConfig)
    end),

    employee = Route("employee", "GET", "/employee", function (_, query, httpState, siteConfig)
        local model = {}

        if query then
            local mode = query.mode
            local emp_no = query.emp_no

            if mode == "edit" then
                model.employee = Employee.getEmployee(emp_no)
            end

            model.mode = mode
        end

        httpState.response.responseFormat = "text/html"
        return processView("employee", model, siteConfig)
    end)
}