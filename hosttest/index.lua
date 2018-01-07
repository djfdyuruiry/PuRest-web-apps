local generateSiteConfig = require "PuRest.Config.generateSiteConfig"

local siteConfig = generateSiteConfig(true)
siteConfig.hostWhitelist = {{"lubuntu-vm", false}}

return
{
	siteConfig = siteConfig
}
