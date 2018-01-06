local loadstring = loadstring or load

local DBI = require "DBI"

local setfenv = require "PuRest.Util.setfenv"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

--- Metatable shared by all DbiDatabaseInterface object to allow dynamic data retrieval.
--
-- Uses the index format get{tableName} to load all the data from a given table and
-- get{tableName}ById(idColumnName, idValue) to fetch a row(s) requiring id column name and value.
-- Deleting row(s) can be done via a call to delete{tableName}ById, requiring id column name and value.
local DB_QUERY_METATABLE =
{
	__index = function (databaseInterface, method)
		if method:match("get(.*)ById$") then
			local table = method:match("get(.*)ById$")

			return function (idColumn, id)
				return rawget(databaseInterface, "getTableRowByPk")(table, idColumn, id)
			end
		elseif method:match("get(.*)$") then
			local table = method:match("get(.*)$")

			return function ()
				return rawget(databaseInterface, "getTableData")(table)
			end
        elseif method:match("delete(.*)ById$") then
            local table = method:match("delete(.*)ById$")

            return function (idColumn, id)
                return rawget(databaseInterface, "deleteTableRowByPk")(table, idColumn, id)
            end
        end
	end
}

--- Provides an abstract interface for working with a database
-- on a server type that LuaDBI supports (MySQL, PostgreSQL and SQLite3).
--
-- This class supports calling a method with the format get{tableName} to
-- load all the data from a given table and get{tableName}ById(idColumnName, idValue)
-- to fetch a row(s) based on a column and value. Deleting row(s) can be done via a
-- call to
--
-- Alternatively you can call execQuery(sql, paramsTable), which dynamically binds
-- parameters to a SQL query which uses prepared statement syntax, then returns the
-- resulting row(s).
--
-- Connection to database is established in the constructor and maintained between calls if
-- keepAlive parameter is not false/nil.
--
-- @param dbConfig Config table to use whrn setting up the DB connection.
--                 Format: {driver, dbName, user, password, host, port} (all strings)
-- @param keepAlive optional Refresh the connection if it goes down?
-- @param noAutoCommit optional Do not automatically commit changes to the database?
--
local function DbiDatabaseInterface (dbConfig, keepAlive, noAutoCommit)
	validateParameters(
		{
			dbConfig = {dbConfig, Types._table_},
            dbConfig_driver = {dbConfig.driver, Types._string_},
            dbConfig_dbName = {dbConfig.dbName, Types._string_},
            dbConfig_user = {dbConfig.user, Types._string_},
            dbConfig_password = {dbConfig.password, Types._string_},
            dbConfig_host = {dbConfig.host, Types._string_},
            dbConfig_port = {dbConfig.port, Types._string_}
		}, "DbiDatabaseInterface")

    local config = dbConfig
	local dbCon
	local lastError

    --- Detect if lastError contains a value or concered object is nil.
    -- If so, throw and error using the msg parameter formatted with lastError.
    --
    -- @param obj Object related to possible error condition.
    -- @param msg Message to show when error is detected, at most one '%s' format
    --            specifiers must be present to format the msg with error details.
    --
    local function detectError (obj, msg)
        if not obj or lastError then
            if obj and type(obj) == Types._userdata_ and obj["close"] then
                obj:close()
            end

            error(string.format(msg, tostring(lastError or "unknown")))
        end
    end

    --- Attempt to close the current connection with the DB.
    local function close ()
        if dbCon then
            dbCon:close()
        end
    end

    --- Parameters from database config are used to connect to the
    -- specified database; an error is thrown if this fails.
    --
    local function connect ()
        dbCon, lastError = DBI.Connect(config.driver, config.dbName, config.user, config.password, config.host, config.port)

        detectError(dbCon, string.format("Error occurred while attempting to connect to the '%s' database%s",
            config.dbName, ": %s."))

        if not noAutoCommit then
            dbCon:autocommit(true)
        end
    end

    --- Attempt to commit any changes to the DB.
    local function commit ()
        if dbCon then
            dbCon:commit()
        end
    end

    --- Ensure that the DB connection object is valid and connected.
    -- If keep alive was specified in constructor an attempt is made to
    -- reconnect to the database if there is a problem detected.
    --
	local function ensureDbAlive ()
		if not dbCon or not dbCon:ping() then
            if keepAlive then
                pcall(close)
                connect()
            else
			    error(string.format("The database connection to '%s' has been closed/deleted.", config.dbName))
            end
		end
    end

    --- Fetch all rows stored in a given table.
    --
    -- @param tableName The name of the table in the database.
    -- @return A table containing a object for each row in the given table.
    --
	local function getTableData (tableName)
		validateParameters(
			{
				tableName = {tableName, Types._string_}
			}, "DbiDatabaseInterface.getTableData")

		ensureDbAlive()

		tableName = tableName:lower()

		local st
		st, lastError = dbCon:prepare(string.format("SELECT * FROM `%s`", tableName))

		detectError(st, string.format("Error perparing query to get data from '%s' table%s", tableName, ": %s."))

		local data = {}

		local status
		status, lastError = st:execute()

		detectError(status, string.format("Error executing query to get data from '%s' table%s", tableName, ": %s."))

		for row in st:rows(true) do
			table.insert(data, row)
		end

		st:close()

		return data, #data
	end

    --- Fetch all rows stored in a given table that have the id
    -- value assigned to the column named in the idColumn parameter.
    --
    -- @param tableName The name of the table in the database.
    -- @param idColumn The name of the ID column to look for id value in.
    -- @param id The value of the id to look for in the idColumn.
    -- @return A table containing a object for each row with id value in the given table.
    --
	local function getTableRowByPk (tableName, idColumn, id)
        if id then
            -- Automatically any non-nil value to a string
            id = tostring(id)
        end

		validateParameters(
			{
				tableName = {tableName, Types._string_},
				idColumn = {idColumn, Types._string_},
				id = {id, Types._string_}
			}, "DbiDatabaseInterface.getTableRowByPk")

		tableName = tableName:lower()
		idColumn = idColumn:lower()

		ensureDbAlive()

		local st
		st, lastError = dbCon:prepare(string.format("SELECT * FROM `%s` WHERE `%s`=?", tableName, idColumn))

		detectError(st, string.format("Error perparing query to get row from '%s' table%s", tableName, ": %s."))

		local data

		local status
		status, lastError = st:execute(id)

		detectError(status, string.format("Error executing query to get row from '%s' table%s", tableName, ": %s."))

		for row in st:rows(true) do
			data = row
		end

		st:close()

		return data
    end


    --- Delete all rows stored in a given table that have the id
    -- value assigned to the column named in the idColumn parameter.
    --
    -- @param tableName The name of the table in the database.
    -- @param idColumn The name of the ID column to look for id value in.
    -- @param id The value of the id to look for in the idColumn.
    -- @return The number of rows affected by the statement.
    --
    local function deleteTableRowByPk (tableName, idColumn, id)
        if id then
            -- Automatically any non-nil value to a string
            id = tostring(id)
        end

        validateParameters(
            {
                tableName = {tableName, Types._string_},
                idColumn = {idColumn, Types._string_},
                id = {id, Types._string_}
            }, "DbiDatabaseInterface.deleteTableRowByPk")

        tableName = tableName:lower()
        idColumn = idColumn:lower()

        ensureDbAlive()

        local st
        st, lastError = dbCon:prepare(string.format("DELETE FROM `%s` WHERE `%s`=?", tableName, idColumn))

        detectError(st, string.format("Error perparing query to delete row(s) from '%s' table%s", tableName, ": %s."))

        local data

        local status
        status, lastError = st:execute(id)

        detectError(status, string.format("Error executing query to delete row(s) from '%s' table%s", tableName, ": %s."))

        local numRowsAffected = st:affected()
        st:close()

        return numRowsAffected
    end

    --- Build and run a dynamic call to the execute method of a
    -- DBI prepared statement.
    --
    -- @param preparedStatement The statement to be called.
    -- @param params List of parameters to pass to statement:execute.
    -- @return Return values of prepared statement execute call.
    --
    local function runExecuteProxy (preparedStatement, params)
        local executeProxy = "return st:execute("

        for idx = 1, #params do
            local executeBit = string.format("params[%s]", idx)

            if idx ~= #params then
                executeProxy = string.format("%s%s,", executeProxy, executeBit)
            else
                executeProxy = string.format("%s%s)", executeProxy, executeBit)
            end
        end

        executeProxy = loadstring(executeProxy)
        setfenv(executeProxy, {st = preparedStatement, params = params})

        return executeProxy()
    end

    --- Dynamically binds parameters to an SQL query which uses prepared statement syntax,
    -- then returns the resulting row(s).
    --
    -- @param sql The SQL statment to provide parameters to and execute.
    -- @param params A table of parameters to bind to the query.
    -- @param noResults Is the query a statement that does not return data rows?
    -- @return A table of the result rows, each row is an associative array, or nil and the number
    --          of rows affected if noResults was specified.
    --
    local function execQuery (sql, params, noResults)
        validateParameters(
            {
                sql = {sql, Types._string_}
            }, "DbiDatabaseInterface.execQuery")

        ensureDbAlive()

        local sanitizedSql = sql:gsub("%%", "%%%%")
        local st

        st, lastError = dbCon:prepare(sql)

        detectError(st, string.format("Error preparing sql query '%s'%s", sanitizedSql, ": %s."))

        local data = {}
        local status

        if params then
            if type(params) ~= Types._table_ then
                params = {params}
            end

            status, lastError = runExecuteProxy(st, params)
        else
            status, lastError = st:execute()
        end

        detectError(status, string.format("Error executing sql query '%s'%s", sanitizedSql, ": %s."))

        if not noResults then
            for row in st:rows(true) do
                  table.insert(data, row)
            end
        end

        if not noResults then
            st:close()

            return (#data > 0 and (#data == 1 and data[1] or data) or nil), #data
        else
            local numRowsAffected = st:affected()
            st:close()

            return nil, numRowsAffected
        end
    end

    --- Build a new DbiDatabaseInterface object.
	local function construct()
		connect()

		return setmetatable(
            {
                close = close,
                commit = commit,
                execQuery = execQuery,
                getTableData = getTableData,
                getTableRowByPk = getTableRowByPk,
                deleteTableRowByPk = deleteTableRowByPk
            }, DB_QUERY_METATABLE)
	end

	return construct()
end

return DbiDatabaseInterface
