function printWithHeader ($message)
{
	$messageLength = $message.Length
	$horizontalLine = "=" * ($messageLength + 6)

	Write-Host $horizontalLine
	Write-Host "   $message   "
	Write-Host $horizontalLine
}

function printWithBuffer ($message)
{
	Write-Host
	Write-Host $message
	Write-Host
}

if ([String]::IsNullOrEmpty($env:PUREST_WEB))
{
	$env:PUREST_WEB = "$PSScriptRoot/web"
}

if ([String]::IsNullOrEmpty($env:PUREST_CFG))
{
	$env:PUREST_CFG = "$PSScriptRoot/cfg/cfg.lua"
}

printWithBuffer "Using PUREST_WEB as html directory for server => '$($env:PUREST_WEB)'"

$defaultLuaPath = lua -e "print(package.path)"
$defaultLuaCPath = lua -e "print(package.cpath)"

$libExtension = "dll"

if ($PSVersionTable.Platform -and ($PSVersionTable.Platform -eq "Unix"))
{
	$libExtension = "so"
}

$luaBasePath = "$PSScriptRoot/lua"
$env:LUA_PATH = "$defaultLuaPath;?;?.lua;./?.lua;$luaBasePath/?/?.lua;$luaBasePath/?/init.lua;$luaBasePath/?.lua;$luaBasePath/init.lua;$luaBasePath/?/src/?.lua;$luaBasePath/init.lua;$luaBasePath/?/src/?/?.lua;$luaBasePath/?/src/init.lua;$($env:PUREST_WEB)/?/?.lua;$($env:PUREST_WEB)/?/init.lua;$($env:PUREST_WEB)/?.lua;$($env:PUREST_WEB)/init.lua;$($env:PUREST_WEB)/?/src/?.lua;$($env:PUREST_WEB)/init.lua;$($env:PUREST_WEB)/?/src/?/?.lua;$($env:PUREST_WEB)/?/src/init.lua"
$env:LUA_CPATH = "$defaultLuaCPath;$PSScriptRoot/bin/?.$libExtension;$PSScriptRoot/bin/?/core.$libExtension;$PSScriptRoot/bin/?/?.$libExtension"

printWithHeader "Environment Variables"
printWithBuffer (Get-ChildItem env: | Out-String)

$ErrorActionPreference = "Continue"

lua -e "require 'PuRest.load'"

# dump logs to console
Get-ChildItem "$PSScriptRoot/web" -Filter "*.log" | ForEach-Object `
{ 
	printWithHeader $_.Name

	Write-Host
	Get-Content $_.FullName
	Write-Host
}

if ([Environment]::UserInteractive)
{
	Read-Host "Press enter to exit..."
}
