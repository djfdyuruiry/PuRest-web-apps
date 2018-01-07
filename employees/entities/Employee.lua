local DbiDatabaseInterface = require "PuRest.Database.DbiDatabaseInterface"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"
local Types = require "PuRest.Util.ErrorHandling.Types"

local EmployeesDbConfig = require "employees.DbProperties"

local db

local function checkIsEmployee (employee, noIdCheck)
    validateParameters ({
        employee = {employee, Types._table_},
        employee_birth_date = {employee.birth_date, Types._string_},
        employee_first_name = {employee.first_name, Types._string_},
        employee_last_name = {employee.last_name, Types._string_},
        employee_gender = {employee.gender, Types._string_},
        employee_hire_date = {employee.hire_date, Types._string_}
    })

    if employee.gender ~= "M" and employee.gender ~= "F" then
        error("Employee gender should be either 'M' or 'F'.")
    end

    if not noIdCheck then
        validateParameters ({
            employee_emp_no = {employee.emp_no, Types._string_},
        })
    end
end

--- Singleton to manage the Employee entity type.

local function getEmployee (emp_no)
    validateParameters ({
        emp_no = {emp_no, Types._string_}
    })

    db = db or DbiDatabaseInterface(EmployeesDbConfig)

    return db.getEmployeesById("emp_no", emp_no)
end

local function addEmployee (employee)
    checkIsEmployee(employee, true)
    db = db or DbiDatabaseInterface(EmployeesDbConfig)

    local sql =
    [[INSERT INTO employees
      (birth_date, first_name, last_name, gender, hire_date)
      VALUES(?, ?, ?, ?, ?)]]

    db.execQuery(sql,
    {
        employee.birth_date,
        employee.first_name,
        employee.last_name,
        employee.gender,
        employee.hire_date
    }, true)

    -- TODO: investigate why LAST_INSERT_ID() does not work :S
    local empNumSql =
    [[SELECT emp_no FROM employees
      ORDER BY emp_no DESC
      LIMIT 1]]

    local result = db.execQuery(empNumSql)

    assert(result, "Database failed to return last added employee.")

    return getEmployee(tostring(result.emp_no))
end

local function updateEmployee (employee)
    checkIsEmployee(employee)
    db = db or DbiDatabaseInterface(EmployeesDbConfig)

    local sql =
    [[UPDATE employees
      SET birth_date=?, first_name=?, last_name=?, gender=?, hire_date=?
      WHERE emp_no=?]]

    db.execQuery(sql,
    {
        employee.birth_date,
        employee.first_name,
        employee.last_name,
        employee.gender,
        employee.hire_date,
        employee.emp_no
    }, true)

    return getEmployee(employee.emp_no)
end

local function deleteEmployee (emp_no)
    validateParameters ({
        emp_no = {emp_no, Types._string_}
    })

    db = db or DbiDatabaseInterface(EmployeesDbConfig)

    return db.deleteEmployeesById("emp_no", emp_no)
end

local function searchForEmployees (names)
    validateParameters ({
        names = {names, Types._table_}
    })

    db = db or DbiDatabaseInterface(EmployeesDbConfig)

    assert(type(names) == "table" or type(names) == "string", "Request object field 'names' must be a string or an array.")

    if type(names) == "string" then
        names = {names}
    end

    local employees = {}
    local sql =
    [[SELECT * FROM employees
      WHERE first_name LIKE ? OR last_name LIKE ?]]

    for _, name in ipairs(names) do
        local results, numResults = db.execQuery(sql, {tostring(name) .. "%", tostring(name) .. "%"})

        if numResults == 1 then
            table.insert(employees, results)
        elseif numResults > 1 then
            for _, resultRow in ipairs(results) do
                table.insert(employees, resultRow)
            end
        end
    end

    return employees
end

local function cleanup()
    if db then
        db:close()
        db = nil
    end
end

return
{
    addEmployee = addEmployee,
    getEmployee = getEmployee,
    updateEmployee = updateEmployee,
    deleteEmployee = deleteEmployee,
    searchForEmployees = searchForEmployees,
    cleanup = cleanup
}