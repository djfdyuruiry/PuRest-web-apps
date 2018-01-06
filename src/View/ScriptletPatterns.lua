local Regex = require "rex_pcre"

local ScriptletTypes = require "PuRest.View.ScriptletTypes"

local psp = {}

psp[ScriptletTypes.PlainHtml] = Regex.new([[(<[^>^<]+>)]], "sU")
psp[ScriptletTypes.Executor] = Regex.new([[\s*<%(?<charData>.*)%>]], "sU")
psp[ScriptletTypes.Printer] = Regex.new([[\s*<%=(?<charData>.*)%>]], "sU")
psp[ScriptletTypes.JsPrinter] = Regex.new([[\s*<%\$(?<charData>.*)%>]], "sU")

return psp
