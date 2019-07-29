Set-StrictMode -Version Latest
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Updates the installed version of vcpkg and any installed packages.
.DESCRIPTION
  Single function installation/updating for vcpkg.
.OUTPUTS
  1. File: "vcpkg_source.hash" creation or modification in the same directory
     as this script.
  2. Instructions to the message API, on how to enable caching, when relevant.
  3. AppVeyor: On failed build of vcpkg, cache saving is disabled with:
     `$env:APPVEYOR_CACHE_SKIP_SAVE = 'true'`
.EXAMPLE
  Update-Vcpkg
  -- Update vcpkg ...
  -- Update vcpkg - git ...
  -- Update vcpkg - git ... done
  -- Update vcpkg - build ...
  -- Update vcpkg - build ... done
  INFO: vcpkg list
  -- catch2:x64-windows        2.7.2-2          A modern, header-only test ...
  -- gtest:x64-linux           2019-01-04-2     GoogleTest and GoogleMock ...
  -- gtest:x64-windows         2019-01-04-2     GoogleTest and GoogleMock ...
  -- ms-gsl:x64-linux          2019-04-19       Microsoft implementation of ...
  -- ms-gsl:x64-windows        2019-04-19       Microsoft implementation of ...
  INFO: vcpkg update
  -- Using local portfile versions. To update the local portfiles, use `git pull
  -- No packages need updating.
  -- Update vcpkg ... done 

  Default operation. Use the latest versions of all packages and rebuild the
  vcpkg tools only on version number changes.
.EXAMPLE
  Update-Vcpkg -Quiet

  Suppress informational output.
.EXAMPLE
  Update-Vcpkg -FixedCommit f700dee8eb4677d89d3919519613dee5e22c766e

  Use to keep a fixed dependencies state. Requires the full commit hash from the
  vcpkg repository.
.EXAMPLE
  Update-Vcpkg -Latest

  Rebuild the vcpkg tool if any change has been made in the "toolsrc" directory.
  This has been recommended by the developers and can prevent issues when a
  braking change is introduced in the tool without a version number update.
  But, this can also result in frequent rebuilds when vcpkg is in development.
.EXAMPLE
  Update-Vcpkg -Path .\

  Use a custom install directory for vcpkg, or point in to an installed version.
  Can be used to create separate install directories, usable with CMake.
.NOTES
  - `-Path <...> -WhatIf` always creates the target folder.
  - Caching on AppVeyor.
    Prevent unnecessary rebuilds of vcpkg by adding $HOME/Tools/cache.
    For ports that need to be build add the "C:\Tools\vcpkg\installed" folder.
#>
function Update-Vcpkg {
  [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Medium')]
#  [OutputType([System.Management.Automation.PathInfo])]
  param(
    # Rebuild vcpkg on each vcpkg tool source change.
    [Switch]$Latest,
    [ValidatePattern('[0-9a-fA-F]{40}')] # full SHA1 hash
    [ValidateNotNullOrEmpty()]
    [Alias('Commit')]
    # Git commit hash to checkout to use a specific state of the vcpkg library.
    [String]$FixedCommit,
    [ValidateScript({
      (Test-Path "$_" -IsValid) -and
        (New-Item -Path "$_" -ItemType Directory -Force |
          Test-Path -PathType Container
        )
    })]
    [ValidateNotNullOrEmpty()]
    # Custom directory to find or install vcpkg.
    [String]$Path,
    [Alias('q')]
    # Reduce console output.
    [Switch]$Quiet
  )
  Begin
  {
    Get-CommonFlagsCaller $PSCmdlet $ExecutionContext.SessionState

    if (-not $Quiet) { Write-Host "-- Update vcpkg ..." }

    # Default cache directory, for controlled cache application.
    $cache_dir = Join-Path (Join-Path (Join-Path $HOME 'Tools') 'cache') 'vcpkg'

    # Temporary fix ----------------------------------------
    if ($env:CI_WINDOWS -eq $null) {
      Send-Message -Warning 'CI_WINDOWS and CI_LINUX not yet defined' -LogOnly
      if ($PSVersionTable.PSVersion.Major -lt 6) {
        if ((Get-WmiObject Win32_OperatingSystem).Caption -match 'Windows') {
          $env:CI_WINDOWS = 'true'
        }
      } else {
        if ((Get-CimInstance CIM_OperatingSystem).Caption -match 'Windows') {
          $env:CI_WINDOWS = 'true'
        }
      }
    } else {
      Send-Message -Warning ('Remove unnecessary code from ' +
        $MyInvocation.MyCommand) -LogOnly
    }
    # /Temporary fix ---------------------------------------

    if ($env:CI_WINDOWS -eq 'true') {
      $vcpkg = 'vcpkg.exe' # Windows
    } else {
      $vcpkg = 'vcpkg' # Linux
    }

    # Set installation location
    if ($Path) {
      $Location = $Path
    } else {
      $Location = Select-VcpkgLocation
    }
  }
  Process
  {
    try {
      Push-Location $Location

      # Git operations
      if (-not $Quiet) { Write-Host "-- Update vcpkg - git ..." }
      Update-Repository -Commit:$FixedCommit
      if (-not $Quiet) { Write-Host "-- Update vcpkg - git ... done" }

      # Determine if (re)building is necessary
      $build = $false
      if ($Latest) {
        $null = Import-CachedVcpkg
        if (Test-ChangedVcpkgSource) {
          $build = $true
        }
      } elseif (-not (Test-Path $vcpkg -PathType Leaf) -or # no vcpkg installed
        (Test-Command './vcpkg update' `
          -match 'different source is available for vcpkg') -or
        (Test-IfReleaseWithIssues)
      ) {
        if (Import-CachedVcpkg) {
          $build = ( (Test-Command './vcpkg update' `
            -match 'different source is available for vcpkg') -or
            (Test-IfReleaseWithIssues)
          )
        } else { $build = $true }
      } elseif ( (Assert-CI) -and
        (Test-Path (Join-Path $cache_dir $vcpkg) -PathType Leaf)
      ) {
        Write-Verbose 'Installed vcpkg is up-to-date.'
        Remove-Item (Join-Path $cache_dir 'vcpkg')
      }
      # Build vcpkg
      if ($build) {
        if (-not $Quiet) { Write-Host "-- Update vcpkg - build ..." }
        if ($PSCmdlet.ShouldProcess('vcpkg', 'bootstrap')) {
          ./bootstrap-vcpkg.bat 1>$null
          Export-CachedVcpkg
        }
        if (-not $Quiet) { Write-Host "-- Update vcpkg - build ... done" }
      }
      # Integrate install
      if ($PSCmdlet.ShouldProcess('vcpkg', 'integrate install')) {
        ./vcpkg integrate install 1>$null
      }
      # Add to PATH
      if (-not (Test-Command 'vcpkg version') ) {
        Add-EnvironmentPath -Path $Location
      }
    } finally {
      if (Assert-CI -and -not (Test-Path $vcpkg -PathType Leaf) ) {
        Write-Verbose 'Disabling cache update. Building vcpkg failed.'
        $env:APPVEYOR_CACHE_SKIP_SAVE = 'true'
      }
      Pop-Location
    }
  }
  End
  {
    if (-not (Test-Command 'vcpkg version') ) {
      if (-not $Quiet) { Write-Host "-- Update vcpkg ... failed" }
      Send-Message -Error 'vcpkg install failed' `
        -ContinueOnError:$WhatIfPreference
      return $null
    }
    # Update packages
    vcpkg list   | Send-Message 'vcpkg list' -LogOnly:$Quiet
    vcpkg update | Send-Message 'vcpkg update' -LogOnly:$Quiet
    if (!($(vcpkg upgrade) -match "^All installed packages are up-to-date")) {
      if ($PSCmdlet.ShouldProcess('upgrade installed packages')) {
        vcpkg upgrade --no-dry-run
      }
    }
    if (-not $Quiet) { Write-Host "-- Update vcpkg ... done" }
  }
} #/ function Update-Vcpkg
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  When available, copies the vcpkg executable from the cache.
.DESCRIPTION
  Only operational on AppVeyor, no effect on other systems.
  Copies vcpkg or vcpkg.exe from the cache directory to the current directory.

  Preconditions:
  - Requires `$cache_dir` to be defined in the calling scope.
    This is only available within the module defining this function.
.OUTPUTS
  Returns a boolean representing the existence of the cached file.
.EXAMPLE
  Import-CachedVcpkg
#>
function Import-CachedVcpkg {
  [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Low')]
  [OutputType([Bool])]
  param()
  Begin
  {
    Get-CommonFlagsCaller $PSCmdlet $ExecutionContext.SessionState

    $Path = Get-Variable -Scope 1 -Name 'cache_dir' -ValueOnly
  }
  Process
  {
    if ( (Assert-CI) -and
      (Test-Path (Join-Path $Path 'vcpkg*') -PathType Leaf)
    ) {
      Resolve-Path -Path (Join-Path $Path 'vcpkg*') |
        Select-String -Pattern '[\\\/]vcpkg(\.exe)?$' |
        ForEach-Object -Process { Copy-Item "$_" -Force }
      return $true
    }
    # Add message log entry with instructions
    ('Vcpkg has been rebuild, but their was no cache available.',"`n",
    'Add the following to your AppVeyor configuration:',"`n`n",
    'cache:',"`n- '${Path}'`n`n",
    'Optionally, enable cacheing on failed builds to reduce build time ',
    'for repeatedly failing jobs. Add in your AppVeyor configuration:',"`n`n",
    'environment:', "`n",
    '  global:',"`n",
    '    APPVEYOR_SAVE_CACHE_ON_ERROR: true'
    ) -join '' |
      Send-Message -Info 'Update-Vcpkg: No Cache Found' -NoNewLine -HideDetails

    return $false
  }
  End {}
}
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Copies the vcpkg(.exe) to the cache directory.
.DESCRIPTION
  Only operational on AppVeyor, no effect on other systems.
  Creates the cache folder when not present.

  Preconditions:
  - vcpkg(.exe) present in current directory.
  - Requires `$cache_dir` to be defined in the calling scope.
    This is only available within the module defining this function.
.EXAMPLE
  Export-CachedVcpkg
#>
function Export-CachedVcpkg {
  [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Medium')]
  param()
  Begin
  {
    Get-CommonFlagsCaller $PSCmdlet $ExecutionContext.SessionState

    $Destination = Get-Variable -Scope 1 -Name 'cache_dir' -ValueOnly
  }
  Process
  {
    if (Assert-CI) {
      New-Item -Path $Destination -ItemType Directory -Force
      Resolve-Path -Path 'vcpkg*' |
        Select-String -Pattern '[\\\/]vcpkg(\.exe)?$' |
        ForEach-Object -Process {
          Copy-Item "$_" -Destination $Destination -Force
        }
    }
  }
  End {}
}
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Returns the install location of vcpkg or fallback to a default location.
.DESCRIPTION
  Tries to find an existing vcpkg installation:
  1. in the standard location used on AppVeyor.
  2. if vcpkg is callable, get the install location.
  3. fallback to using the current user's home directory. Creating
     "$HOME/Tools/vcpkg"
#>
function Select-VcpkgLocation {
  [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Medium')]
  [OutputType([String])]
  param()
  Begin
  {
    Get-CommonFlagsCaller $PSCmdlet $ExecutionContext.SessionState
  }
  Process
  {
    # Find installation location
    if ( (Assert-CI) -and ($env:CI_WINDOWS -eq 'true') -and
      (Test-Path 'C:\Tools\vcpkg\vcpkg.exe' -PathType Leaf)
    ) {
      return 'C:\Tools\vcpkg' # default location on AppVeyor (Windows)
    } elseif (Test-Command 'vcpkg version') {
      return (
        Get-Command vcpkg | Select-Object -ExpandProperty Definition
      ) -replace '[\\\/]vcpkg(.exe)?$',''
    } else {
      $Location = Join-Path (Join-Path $HOME 'Tools') 'vcpkg'
      if ($PSCmdlet.ShouldProcess($Location, 'Create Directory')) {
        return (New-Item $Location -ItemType Directory -Force)
      } else {
        return $Location
      }
    }
  }
  End {}
}
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Checks to determine if a rebuild of vcpkg is required.
#>
function Test-IfReleaseWithIssues {
  [OutputType([Bool])]
  param()

  $match = 'version (0\.0\.113|2018\.11\.23)'
  if ($(./vcpkg version) -match $match) {
    Send-Message -Warning 'This vcpkg release has known issues. Rebuilding ...'
    return $true
  } else { return $false }
}
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Determine if the vcpkg tool source has been updated since the last build.
.OUTPUTS
  1. Boolean: True | False
     True: on first use or without caching.
     False: when matching hash.
  2. File: "vcpkg_source.hash" creation or modification in the same directory
     as this script.
  3. Instructions to the message API, on how to enable caching, when relevant.
.NOTES
  Requires the current working directory to be the root vcpkg directory and a
  git working directory.
#>
function Test-ChangedVcpkgSource {
  [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Medium')]
  [OutputType([Bool])]
  param()
  Begin 
  {
    Get-CommonFlagsCaller $PSCmdlet $ExecutionContext.SessionState

    $executable = 'vcpkg.exe'
    if (-not (Test-Path $executable -PathType Leaf) ) { $executable = 'vcpkg' }

    $loc_1 = Get-Variable -Scope 1 -Name 'cache_dir' -ValueOnly `
      -ErrorAction SilentlyContinue
    $loc_2 = Join-Path $PSScriptRoot 'vcpkg_source.hash'
    if ($loc_1 -and (Test-Path $loc_1 -PathType Container) ) {
      $hash_file = Join-Path $loc_1 'vcpkg_source.hash'
      if (Test-Path $loc_2 -PathType Leaf) {
        Move-Item -Path $loc_2 -Destination $loc_1
      }
    } else {
      $hash_file = $loc_2
    }
  }
  Process
  {
    if (-not (Test-Command 'git status')) {
      if ($WhatIfPreference) { $vcpkg_src_hash = ''; return $true }
      else { throw 'not a git working directory' }
    }

    # Get hash from git
    $vcpkg_src_hash = git log --format=format:"%H" --max-count=1 -- toolsrc

    if (Test-Path -LiteralPath $hash_file -PathType Leaf) {
      if ( (Get-Content -LiteralPath $hash_file) -eq $vcpkg_src_hash ) {
        return $false # no change
      } else {
        return $true  # confirmed change
      }
    }

    # Add message log entry with instructions
    if ($loc_1) {
      $cache_txt = $loc_1
    } else {
      $cache_txt = (
        (Join-Path $PWD.ProviderPath $executable),"`n- '${hash_file}'"
      )
    }
    ('The use of `Update-Vcpkg -Latest` without caching, results in a full ',
      'rebuild of vcpkg for each build job.',"`n",
      'Add the following to your AppVeyor configuration:',"`n`n",
      'cache:',"`n- '${cache_txt}'`n`n",
      'Optionally, enable cacheing on failed builds to reduce build time ',
      'for repeatedly failing jobs. Add in your AppVeyor configuration:',"`n`n",
      'environment:', "`n",
      '  global:',"`n",
      '    APPVEYOR_SAVE_CACHE_ON_ERROR: true'
    ) -join '' | Send-Message -Warning 'Update-Vcpkg -Latest: No Cache Found' `
        -NoNewLine -HideDetails

    return $true # unknown assume change
  }
  End
  {
    # Update/ create file, to be cached
    if ($vcpkg_src_hash) {
      $vcpkg_src_hash > $hash_file
    }
  }
}
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Initialize or update the git repository.
.NOTES
  Operates only on the current directory.
#>
function Update-Repository {
  [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Medium')]
  param(
    # Git commit hash to checkout.
    [String]$Commit
  )
  Begin
  {
    Get-CommonFlagsCaller $PSCmdlet $ExecutionContext.SessionState

    if ($VerbosePreference -eq 'SilentlyContinue') { $git_quiet = '--quiet' }
    else { $git_quiet = '' }
  }
  Process
  {
    if (Test-Path '*' -PathType Leaf) {
      if (Test-Command 'git status') {
        if (Test-Command 'git remote' -Match '.+') {
          if ($PSCmdlet.ShouldProcess($PWD.ProviderPath, 'git fetch')) {
            git fetch $git_quiet
          }
        } else {
          Send-Message -Error ( ($MyInvocation.MyCommand).ToString() +
          ': no remote repositories defined') -Details $PWD.ProviderPath
        }
      } else {
        Send-Message -Error ( ($MyInvocation.MyCommand).ToString() +
          ': Not empty and not a git working directory'
        ) -Details $PWD.ProviderPath
      }
    } else { # empty folder
      Send-Message -Warning ( ($MyInvocation.MyCommand).ToString() +
        ': vcpkg not installed in the expected location.'
      ) -Details $PWD.ProviderPath
      if ($PSCmdlet.ShouldProcess($PWD.ProviderPath, 'git clone')) {
        git clone https://github.com/Microsoft/vcpkg $git_quiet .\
      }
    }
    if ($Commit) {
      if ($PSCmdlet.ShouldProcess($PWD.ProviderPath, 'git checkout')) {
        git checkout $git_quiet $Commit
      }
    } else {
      if ($PSCmdlet.ShouldProcess($PWD.ProviderPath, 'git merge')) {
        git merge $git_quiet
      }
    }
  }
  End {}
}

##====--------------------------------------------------------------------====##
Export-ModuleMember -Function Update-Vcpkg
