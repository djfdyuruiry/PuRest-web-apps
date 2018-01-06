local luaLinq = require "lualinq"
local from = luaLinq.from

local luaFileSystem = require "lfs"

local getNextDirectoryEntry = require "PuRest.Util.File.getNextDirectoryEntry"
local log = require "PuRest.Logging.FileLogger"
local LogLevelMap = require "PuRest.Logging.LogLevelMap"
local StringUtils = require "PuRest.Util.Data.StringUtils"
local SystemTemplate = require "PuRest.Html.SystemTemplate"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

local FILE_ICON_B64 = [[<img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAMAAABEpIrGAAAAA3NCSVQICAjb4U/gAAAACXBIWXMAAADdAAAA3QFwU6IHAAAAGXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAJlQTFRF////AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAvrCY7gAAADJ0Uk5TAAECAwQFBggLEhgeJygrMDlBW2NmZ2hye3yEiIqLjZOXnKGlqLC3vL3H0uDh6O7w/P1SOQt4AAAAu0lEQVQ4T73T2xLBMBSF4TbUJsRZqO0saJFivf/DuaKk4qIz/HdJvplMZnaC4L9FlCc+nE+vyEuKYgYs+VEKcs/nuEA+V1wAC5j4G5ghm+y/gOgGAMd80wWEpZTyZa8I+G1dEtSVqomWUqruAQdgHQPAwQPaWjcbI6112wNCIqJqUKHQA3YAkHVO2HlAj5l5LAbcK/vMlT13t9Zau/KAvtnIoTHG9Mte8WuQ8lvu0IoETu7YC3L69HF+1B182iK7BrpDMwAAAABJRU5ErkJgggeb283528b34a5594cde454b90d3397b7"/>]]
local FOLDER_ICON_B64 = [[<img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAA3QAAAN0BcFOiBwAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAAG4SURBVFiF7dc9a1RBFMbx3xERJfhSGAKbQklhkUptTGsniB9BEMVC0E/gx9BGUBSxFgSxEQSxiaS1UNSo+BIMYrRIE4tjcddlc5PdubJeVyEHpjkzd85/nnPnzExkpnHatrFG3wL4FwC2b+aMiIM4pAz4OjNfjkSQmb2GCdxFNmzfMNU/x++26N+GEXEFF3EN9/FjCPtJXMICVoetEY9wKzM/1DvrAEt4npnHh0z4a+wZ3MSrAkBgVpXOucxcWI+3PgWruN5EOhzuru42dhTGTuEdHpRS8AbPMvNUSYHu+Bs4i694XxjewSTuZObp3hw1gPmu71hDgMA5nMD+Bp/MYldm7u55alLdw9tR/upCKh7iRb+vvs8/q/LVlk3jY79jM4CdEbGnJYBOEwBaUCEiJrAXn4YBLLcFoJKfcSmgkp+CAm0C/AcKZOYK1loCmFaV7qWBAF1bbgmggy+ZuVYCaKsYbShCgwCe4EhE7PtTkbuF7Sgeb+irvwsi4oDqjH+Kq1gZMf4kLmMGM5m5XoUBh8YFLGp+NSu1RZwvXslqSgTmVOVzFPuO+RwQaCDA37Kxvwu2AMYO8BNIsYqy2VCcKwAAAABJRU5ErkJggg49d8ca5a38ce62d24e3c543466393f91"/>]]

local PAGE_TITLE = [[Directory Listings for '%s%s']]
local LISTINGS_HTML = [[<h2>%s</h2><hr/><table>%s%s</table><hr/><i>Served by PuRest Web Server</i>]]
local ENTRY_HTML = [[<tr><td>##%s##</td><td><a href="%s">%s</a></td></tr>]]

local DIR_404_ERR_0 = "The system cannot find the path specified"
local DIR_404_ERR_1 = "No such file or directory"

--- Check the directory entry provided is not hidden (starts with '.') and
-- that it is not a file with a dissallowed name, specified in the site configs
-- 'doNotServeTheseFiles' field.
--
-- @param entry Directory entry to test.
-- @param doNotServeTheseFiles An array of file patterns not to serve.
-- @return True if directory is OK to serve, false otherwise.
--
local function isOkToServe (entry, doNotServeTheseFiles)
	if StringUtils.startsWith(entry.name, ".") then
		return false
	end

	if entry.type == "directory" then
		return true
	end

	local numMatchingFileSets = from(doNotServeTheseFiles):where(function (fileSet)
		local regexFileSet = (fileSet:gsub("*", ".*"))
		return (entry.name:match(regexFileSet)) ~= nil
	end):count()

	return numMatchingFileSets == 0
end

--- List the contents of a directory in a site and serve as HTML.
--
-- @param _ Ignored (route handler logic)
-- @param _ Ignored (route handler logic)
-- @param httpState State of the current HTTP request.
-- @param siteConfig Config of the site trying to serve the directory.
--
local function serveDirectory (_, _, httpState, siteConfig)
	validateParameters(
		{
			httpState = {httpState, Types._table_},
			siteConfig = {siteConfig, Types._table_}
		}, "listDirectoryContents")

	-- Build directory path and open directory.
	local sitePath = (siteConfig.fullPath:gsub([[\]], "/")):gsub([[\]], "/")
	local directory = (string.format("%s/%s", sitePath, httpState.request.location)):gsub("//", "/")

    local dirReader, dirMetatable
	local _, dirError = pcall(function()
        dirReader, dirMetatable = luaFileSystem.dir(directory)
    end)

	local dirExists = dirReader and not dirError

	-- Check if directory listing is disabled or error occured when opening directory.
	if not siteConfig.directoryServingEnabled or dirError then
		if dirExists then
			error({ httpErrCode = 403, msg = "Directory Listing is not enabled for this site." })
		elseif type(dirError) == Types._string_ and
               (dirError:lower() == DIR_404_ERR_0:lower() or
                dirError:lower() == DIR_404_ERR_1:lower()) then
			error({ httpErrCode = 404 })
        else
			error(string.format("Error when getting directory listings for '%s' -> %s.", directory, dirError or "unknown error"))
		end
	end

	log(string.format("Fetching directory listings for '%s'.", directory), LogLevelMap.INFO)

	local numListings = 0
	local directoriesHtml = [[<tr><td>##directory##</td><td><a href="../">..</a></td></tr>]]
	local filesHtml = ""

	-- Get all files/sub-directories in directory, except those matching do not serve file types.
	local entry = getNextDirectoryEntry(directory, dirReader, dirMetatable)

    while entry do
		if isOkToServe(entry, siteConfig.doNotServeTheseFiles) then
			numListings = numListings + 1
			if entry.type == "directory" then
				local link = string.format("./%s/", entry.name)
				directoriesHtml = directoriesHtml .. string.format(ENTRY_HTML, entry.type, link, entry.name)
			else
				local link = string.format("./%s", entry.name)
				filesHtml = filesHtml .. string.format(ENTRY_HTML, entry.type, link, entry.name)
			end
        end

        entry = getNextDirectoryEntry(directory, dirReader, dirMetatable)
	end

	-- Inject Base64 icon links.
	directoriesHtml = directoriesHtml:gsub("##directory##", FOLDER_ICON_B64)
	filesHtml = filesHtml:gsub("##file##", FILE_ICON_B64)

	log(string.format("Listing %d entries for the directory '%s'.",
		numListings, directory), LogLevelMap.INFO)

	local title = string.format(PAGE_TITLE, siteConfig.name ~= "/" and siteConfig.name or "", httpState.request.location)
	local innerHtml = string.format(LISTINGS_HTML, title, directoriesHtml, filesHtml)

	httpState.response.content = string.format(SystemTemplate, title, innerHtml)
	httpState.response.responseFormat = "text/html"
end

return serveDirectory
