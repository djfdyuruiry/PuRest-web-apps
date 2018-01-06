local log = require "PuRest.Logging.FileLogger"
local LogLevelMap = require "PuRest.Logging.LogLevelMap"
local ServerConfig = require "PuRest.Config.resolveConfig"
local Time = require "PuRest.Util.Time.Time"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

local siteCache = ServerConfig.enableSiteCache and {} or nil

--- Get a site from the cache by location, if a site is found but has expired in the
-- cache it will removed from the cache here.
--
-- @param location HTTP header location to map to site.
-- @return Nothing if site cache is disabled or a valid site was not found in cache,
--         otherwise a Site object matching the location given.
--
local function getSiteFromCache (location)
    validateParameters(
        {
            location = {location, Types._string_}
        }, "SiteCache.getSiteFromCache")

	if not ServerConfig.enableSiteCache then
        return
    end

    local cachedSite = siteCache[location]

    if cachedSite and cachedSite.expiryTime and
       Time.getTimeNowInSecs() < cachedSite.expiryTime then
        return cachedSite.site
    elseif siteCache then
        log(string.format("Site '%s' has been expired and will be removed from the site cache.", location),
            LogLevelMap.INFO)

        siteCache[location] = nil
    end
end

--- Get all valid sites from cache, ithis calls getSiteFromCache for
-- each site in cache to check that it has not expired before including
-- it in return table.
--
-- @return Nothing if site cache is disabled, otherwise a table containing an site
--         object for each valid site in cache.
--
local function getSitesFromCache ()
    if not ServerConfig.enableSiteCache then
        return
    end

    local validSites = {}

    for k, _ in pairs(siteCache) do
        local site = getSiteFromCache(k)

        if site then
            table.insert(validSites, site)
        end
    end

    return validSites
end

--- Add/update a site in the cache. Does nothing if site cache
-- is disabled.
--
-- @param location HTTP header location that matches the site.
-- @param site Site object related to location param.
--
local function setSiteInCache (location, site)
    validateParameters(
        {
            location = {location, Types._string_},
            site = {site, Types._table_}
        }, "SiteCache.setSiteInCache")

    if not ServerConfig.enableSiteCache then
        return
    end

    siteCache[location] =
    {
        site = site,
        expiryTime = Time.getTimeNowInSecs() + ServerConfig.siteCacheExpiryInSecs
    }

    log(string.format("Site '%s' has been added to the site cache.", location),
        LogLevelMap.INFO)
end

return
{
    getSiteFromCache = getSiteFromCache,
    getSitesFromCache = getSitesFromCache,
    setSiteInCache = setSiteInCache
}
