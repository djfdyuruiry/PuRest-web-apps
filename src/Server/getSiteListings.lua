local luaFileSystem = require "lfs"

local getNextDirectoryEntry = require "PuRest.Util.File.getNextDirectoryEntry"
local log = require "PuRest.Logging.FileLogger"
local LogLevelMap = require "PuRest.Logging.LogLevelMap"
local ServerConfig = require "PuRest.Config.resolveConfig"
local Site = require "PuRest.Server.Site"
local SiteCache = require "PuRest.Util.Cache.SiteCache"
local StringUtils = require "PuRest.Util.Data.StringUtils"

--- Get a listing of all sites in server HTML directory. If
-- cache is enabled this is used if it is valid or the HTML
-- directory is scanned and the result is stored in the cache,
-- again if enabled.
--
-- @return A table of site objects, one per valid detected site.
--
local function getSiteListings ()
	--- Build sites in HTML directory.
	local sites = {}
	local numSitesAdded = 0

	local dirReader, dirMetatable
	local _, error = pcall(function()
		dirReader, dirMetatable = luaFileSystem.dir(ServerConfig.htmlDirectory)
	end)

	if not dirReader or error then
		error(string.format("Unable to open HTML directory '%s': %s.",
			ServerConfig.htmlDirectory, error or "unknown error"))
	end

	log(string.format("Building internal list of sites found in config HTML directory '%s'.",
			ServerConfig.htmlDirectory), LogLevelMap.INFO)

	local entry = getNextDirectoryEntry(ServerConfig.htmlDirectory, dirReader, dirMetatable)

	while entry do
		if entry.type == "directory" and not StringUtils.startsWith(entry.name, ".") then
            local dirName = ServerConfig.siteNamesCaseSensitive and entry.name or entry.name:lower()
            local site

            if ServerConfig.enableSiteCache then
                local potentialCache = SiteCache.getSiteFromCache(dirName)

                if potentialCache then
                    site = potentialCache
                end
            end

            if not site then
			    site = Site("http", entry.name, entry.path)
                SiteCache.setSiteInCache(dirName, site)
            end

            table.insert(sites, site)
			numSitesAdded = numSitesAdded + 1
		end

		entry = getNextDirectoryEntry(ServerConfig.htmlDirectory, dirReader, dirMetatable)
	end

	log(string.format("Loaded %d sites from HTML directory.", numSitesAdded), LogLevelMap.INFO)

	return sites
end

return getSiteListings
