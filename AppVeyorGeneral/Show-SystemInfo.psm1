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
  OS / platform: Microsoft Windows Server 2019 Datacenter / 64-bit
  Image:         Visual Studio 2019
  Configuration: Debug
  Platform:      x64
  -------------------------------------------------------------
  Initial path:  C:\projects\sampleproject
.EXAMPLE
  Show-SystemInfo -PowerShell -CMake
  -- CI Session Configuration --
  OS / platform: Microsoft Windows Server 2019 Datacenter / 64-bit
  Image:         Visual Studio 2019
  Configuration: Debug
  Platform:      x64
  PowerShell:    5.1.17763.503
  PS Core:       6.2.0
  CMake:         3.14.4
  -------------------------------------------------------------
  Initial path:  C:\projects\sampleproject
.EXAMPLE
  Show-SystemInfo -All | Send-Message 'SystemInfo' -HideDetails
  -- CI Session Configuration --
  OS / platform: Microsoft Windows Server 2019 Datacenter / 64-bit
  Image:         Visual Studio 2019
  Configuration: Debug
  Platform:      x64
  PowerShell:    5.1.17763.503
  PS Core:       6.2.0
  7-zip:         19.00
  LLVM/clang:    8.0.0
  CMake:         3.14.4
  Python:        2.7.16
  -------------------------------------------------------------
  Initial path:  C:\projects\sampleproject
#>
function Show-SystemInfo {
  param(
    [switch]$All,
    [switch]$CMake,
    [switch]$LLVM,
    [switch]$PowerShell,
    [switch]$Python,
    [switch]$SevenZip
  )
  Begin
  {
    $out = @()
    if (Assert-CI) { $out += ('-- CI Session Configuration --') }
    else { $out += ('-- Local System Configuration --') }
    if (Test-Command 'Get-WmiObject Win32_OperatingSystem') { # not in PS6.1
      $out += Join-Info 'OS / platform' (
        $((Get-WmiObject Win32_OperatingSystem).Name -split "[|]" |
          Select-Object -First 1) + ' / ' +
        $((Get-WmiObject Win32_OperatingSystem).OSArchitecture)
      )
    }
    if ($env:APPVEYOR_BUILD_WORKER_IMAGE) {
      $out += Join-Info 'Image' $env:APPVEYOR_BUILD_WORKER_IMAGE
    }
    if ($env:CONFIGURATION) {
      $out += Join-Info 'Configuration' $env:CONFIGURATION
    }
    if ($env:PLATFORM) { $out += Join-Info 'Platform' $env:PLATFORM }

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
  }
  Process
  {
  }
  End
  {
    $out += ('-------------------------------------------------------------')
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
  Return "<Info>:   <Data>" with constant alignment.
.EXAMPLE
  Join-Info 'Some item' 'The information regarding this item.'
  Some item:    The information regarding this item.'
.EXAMPLE
  Join-Info 'Some item' 'The information regarding this item.' -Length 20
  Some item:         The information regarding this item.'
.EXAMPLE
  Join-Info 'Long item name' 'The information regarding this item.'
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
    [Int]$Length = 15 # Characters
  )
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
#>
function Show-PythonVersion {
  [OutputType([String])]
  param()
  if (Test-Command 'python --version') {
    return ($(python --version) -split ' ' | Select-String -Pattern '^[0-9].+')
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

##====--------------------------------------------------------------------====##

Export-ModuleMember -Function Show-SystemInfo
