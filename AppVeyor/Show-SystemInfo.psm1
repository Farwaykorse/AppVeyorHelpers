Set-StrictMode -Version Latest
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Build system information.
.DESCRIPTION
  Display some basic information and software versions present on the Build
  system.
.EXAMPLE
  Show-SystemInfo
  -- CI Session Configuration --
  OS / platform:      Microsoft Windows Server 2019 Datacenter / 64-bit
  Image:              Visual Studio 2019
  Configuration:      Debug
  Platform:           x64
  ------------------------------------------------------------------------------
  Initial path:       C:\projects\sampleproject
.EXAMPLE
  Show-SystemInfo -PowerShell -CMake
  -- CI Session Configuration --
  OS / platform:      Microsoft Windows Server 2019 Datacenter / 64-bit
  Image:              Visual Studio 2019
  Configuration:      Debug
  Platform:           x64
  PowerShell:         5.1.17763.503
  PS Core:            6.2.0
  CMake:              3.14.4
  ------------------------------------------------------------------------------
  Initial path:       C:\projects\sampleproject
.EXAMPLE
  Show-SystemInfo -All | Send-Message 'SystemInfo' -HideDetails
  -- CI Session Configuration --
  OS / platform: Microsoft Windows Server 2019 Datacenter / 64-bit
  Image:              Visual Studio 2019
  Configuration:      Debug
  Platform:           x64
  PowerShell:         5.1.17763.503
  PS Core:            6.2.0
  7-zip:              19.00
  LLVM/clang:         8.0.0
  CMake:              3.14.4
  Python:             2.7.16
  ------------------------------------------------------------------------------
  Initial path:       C:\projects\sampleproject
#>
function Show-SystemInfo {
  param(
    [ValidateScript({ $_ -ge 0 })]
    [Alias('ColumnWidth')]
    # Alignment of data/ first column width (default 20 characters).
    [Int]$Align = 20,
    [switch]$All,
    [switch]$CMake,
    [switch]$LLVM,
    [switch]$PowerShell,
    [switch]$Python,
    [switch]$SevenZip,
    [switch]$Curl
  )
  Begin
  {
    $bar = ('-').PadRight(80,'-')
    $out = @()
    if (Assert-CI) {
      if ($env:APPVEYOR_SCHEDULED_BUILD) {
        $out += ('Scheduled Build.')
      }
      if ($env:APPVEYOR_FORCED_BUILD) {
        $out += ('Forced Build, started by "New build" button.')
      }
      if ($env:APPVEYOR_RE_BUILD) {
        $out += ('Build started by "Re-build commit/PR" button.')
      }
      if ($env:APPVEYOR_RE_RUN_INCOMPLETE) {
        $out += ('Build started by "Re-run incomplete" button.')
      }
      if ($env:APPVEYOR_REPO_TAG -eq 'true') {
        $out += ('Build of tag: ' + $env:APPVEYOR_TAG_NAME)
      }
    }
    if (Assert-CI) {
      $out += ('-- CI Session Configuration --').PadRight(80,'-')
    } else { $out += ('-- Local System Configuration --').PadRight(80,'-') }
    # System
    $out += Join-Info 'OS / platform' $(
      if ($PSVersionTable.PSVersion.Major -lt 6) {
        $((Get-WmiObject Win32_OperatingSystem).Caption) + ' / ' +
        $((Get-WmiObject Win32_OperatingSystem).OSArchitecture)
      } else {
        $((Get-CimInstance CIM_OperatingSystem).Caption) + ' / ' +
        $((Get-CimInstance CIM_OperatingSystem).OSArchitecture)
      }
    )
    # AppVeyor default matrix
    if (Assert-CI -and $env:APPVEYOR_BUILD_WORKER_IMAGE) {
      $out += Join-Info 'Image' $env:APPVEYOR_BUILD_WORKER_IMAGE
    }
    if (Assert-CI -and $env:CONFIGURATION) {
      $out += Join-Info 'Configuration' $env:CONFIGURATION
    }
    if (Assert-CI -and $env:PLATFORM) {
      $out += Join-Info 'Platform' $env:PLATFORM
    }

    # Information on software installed on AppVeyor.
    # Enabled by -All and a specific switch.
    if ($PowerShell -or $All) {
      if ( $PSVersionTable.PSVersion.Major -lt 6 ) {
        $out += Join-Info PowerShell $PSVersionTable.PSVersion.ToString()
        if ( Test-Command 'pwsh { exit 0 }') {
          $out += Join-Info 'PS Core' $(
            pwsh { $PSVersionTable.PSVersion.ToString() }
          )
        }
      } else {
        $out += Join-Info 'PS Core' $PSVersionTable.PSVersion.ToString()
        if ( Test-Command 'powershell { exit 0 }') {
          $out += Join-Info 'PowerShell' $(
            powershell { $PSVersionTable.PSVersion.ToString() }
          )
        }
      }
    }
    if ($SevenZip -or $All) { $out += Join-Info 7-zip $(Show-7zipVersion) }
    if ($LLVM -or $All)     { $out += Join-Info LLVM/clang $(Show-LLVMVersion) }
    if ($CMake -or $All)    { $out += Join-Info CMake $(Show-CMakeVersion) }
    if ($Python -or $All)   { $out += Join-Info Python $(Show-PythonVersion) }
    if ($Curl -or $All)     { $out += Join-Info Curl $(Show-CurlVersion) }
  }
  Process
  {
  }
  End
  {
    $out += $bar
    $out += Join-Info 'Initial path' $pwd.Path
    if (Assert-CI) {
      $out += Join-Info '$env:APPVEYOR_BUILD_FOLDER' $env:APPVEYOR_BUILD_FOLDER
    }
    Write-Output ($out -join "`n"); $out = ''
  }
} #/ function Show-SystemInfo
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Return "<Info>:        <Data>" with constant alignment.
.EXAMPLE
  Join-Info 'Some item' 'The information regarding this item.'
  Some item:         The information regarding this item.'
.EXAMPLE
  Join-Info 'Some item' 'The information regarding this item.' -Length 15
  Some item:    The information regarding this item.'
.EXAMPLE
  Join-Info 'Long item name' 'The information regarding this item.' -Length 5
  Long item name: The information regarding this item.'

  A string longer then the set Length shifts the Data item out of alignment.
#>
function Join-Info {
  [OutputType([String])]
  param(
    [AllowEmptyString()]
    [String]$Name = $(throw 'Name is a required parameter'),
    [AllowEmptyString()]
    [String]$Data = $(throw 'Data is a required parameter'),
    [ValidateScript({ $_ -ge 0 })]
    [Int]$Length = 0 # Characters
  )
  if (-not $Length) {
    $Length = Get-Variable -Scope 1 -Name Align -ValueOnly `
      -ErrorAction SilentlyContinue
  }
  if ($Name) { $Name = ($Name + ': ') }
  return ($( $Name.PadRight($Length,' ') ) + $Data)
}
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Acquire the version number from CMake.
#>
function Show-CMakeVersion {
  [OutputType([String])]
  param()
  if (Test-Command 'cmake --version') {
    return ($(cmake --version) -split ' ' | Select-String -Pattern '^[0-9].+')
  } else { return ' ?' }
}

<#
.SYNOPSIS
  Acquire the version number from 7-zip.
#>
function Show-7zipVersion {
  [OutputType([String])]
  param()
  if (Test-Command '7z') {
    return (
      ($(7z) -split "`n" | Select-Object -Skip 1 -First 1) -split ' : ' |
        Select-Object -First 1
    ) -split ' ' | Select-Object -Skip 1 -First 1
  } else { return ' ?' }
}

<#
.SYNOPSIS
  Acquire the version number from the default python install.
.NOTES
  Python v2.7 outputs to the error stream.
#>
function Show-PythonVersion {
  [OutputType([String])]
  param()
  if (Test-Command 'python --version 2>$null') {
    return ( ($(python --version) 2>&1) -split ' ' |
      Select-String -Pattern '^[0-9].+' )
  } else { return ' ?' }
}

<#
.SYNOPSIS
  Acquire the version number from LLVM/clang.
#>
function Show-LLVMVersion {
  [OutputType([String])]
  param()
  if (Test-Command 'clang-cl --version') {
    return (
      ($(clang-cl --version) | Select-String -Pattern version) -split ' ' |
        Select-String -Pattern '^[0-9].+'
    )
  } else { return ' ?' }
}

<#
.SYNOPSIS
  Acquire the version number from Curl.
#>
function Show-CurlVersion {
  [OutputType([String])]
  param()
  if (Test-Command 'curl.exe -V') {
    return (
      $(curl.exe -V) -split ' ' |
        Select-String -Pattern '^([0-9]+\.)+[0-9]+.*'
    )
  } else { return ' ?' }
}

##====--------------------------------------------------------------------====##

Export-ModuleMember -Function Show-SystemInfo
