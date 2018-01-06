Param([Switch]$installDevDependencies)

$isRunningOnUnix = $PSVersionTable.Platform -and $PSVersionTable.Platform -eq "Unix"
$isRunningOnWindows = -not $PSVersionTable.Platform -or $PSVersionTable.Platform -eq "Win*"

$luaDependencies = @("lanes", "luasocket-lanes", "luasec" 
    "luafilesystem", "luadbi", "md5", 
    "date", "lzlib", "lrexlib-pcre", 
    "lualogging", "lualinq", "xml")

function IsRunningOnOsx
{
    if (-not $isRunningOnUnix)
    {
        return $false
    }

    $osType = sh "$PSScriptRoot/utils/getOsType.sh"

    return $osType -eq "darwin*"
}

function IsLuaDependencyInstalled ($dependency)
{
    return (luarocks list "$dependency").Contains($dependency)
}

function AssertLuaDependencyInstalled ($dependency)
{
    if (-not (IsLuaDependencyInstalled $dependency))
    {
        throw "Error: lua dependecy $dependency did not successfully install, see luarocks output above"
    }
}

function InstallLuaDependencyIfMissing ($dependency)
{
    if ((IsLuaDependencyInstalled $dependency))
    {
        Write-Host "Lua dependency $dependency is already installed"
        return
    }

    Write-Host "Installing lua dependency $dependency..."

    luarocks install "$dependency"
    AssertLuaDependencyInstalled $dependency

    Write-Host "Installed lua dependency $dependency"
}

function MacOsx_InstallOpensslIfMissing
{
    if((brew install openssl).Contains("openssl"))
    {
        Write-Host "Openssl is already installed"
        return
    }

    brew install openssl

    # workaround for osx openssl header and lib locations (conform to expected linux paths)
    ln -s /usr/local/opt/openssl/include/openssl /usr/local/include
    Get-Item "/usr/local/opt/openssl/lib/lib*" | ForEach-Object { ln -vs "$($_.FullName)" /usr/local/lib }
}

function AssertCommandAvailable ($commandName, $downloadUrl)
{
    $command = Get-Command $commandName -ErrorAction Ignore

    if (-not $command)
    {
        throw "Error: $commandName is not installed, please install this to get lua dependencies`n  see $downloadUrl"
    }

    Write-Host "Found command $commandName at path $($command.Source)"
}

function UnixMain
{
    if (-not $isRunningOnUnix)
    { 
        return
    }

    if (-not (Test-Path "/usr/include/openssl" -PathType Container))
    {
        throw "Error: looks like openssl is not installed, this is required for the luasec library" +`
            "  install openssl using your system package manager and try again"
    }

    $script:luaDependencies += "luaposix"
}

function OsxMain
{
    if (-not (IsRunningOnOsx))
    {
        return
    }
    
    MacOsx_InstallOpensslIfMissing
}

function WindowsMain
{
    if (-not $isRunningOnWindows)
    {
        return
    }
    
    #$luaDependencies += "alien"
}

function Main
{
    AssertCommandAvailable "lua" "http://www.lua.org/download.html"
    AssertCommandAvailable "luarocks" "https://github.com/luarocks/luarocks/wiki/Download"

    UnixMain
    OsxMain
    WindowsMain

    if ($installDevDependencies)
    {
        $script:luaDependencies += "luadoc"
    }

    $luaDependencies | ForEach-Object { InstallLuaDependencyIfMissing $_ }
}

Main
