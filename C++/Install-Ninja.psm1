Set-StrictMode -Version Latest
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Install Ninja-build for Windows.
.DESCRIPTION
  Manages the installation of the Ninja build system.
  By version tag as published to GitHub.
.EXAMPLE
  Install-Ninja v1.8.2 -Hash 9B9CE248240665FCD6404B989F3B3C27ED9682838225E6DC9B67B551774F251E4FF8A207504F941E7C811E7A8BE1945E7BCB94472A335EF15E23A0200A32E6D5
  -- Install Ninja-build v1.8.2 ...
  -- Install Ninja-build v1.8.2 ... done

  Download Ninja-build and install to `.\ninja-v1.8.2\`.
.EXAMPLE
  Install-Ninja -Tag v1.8.2 -HASH $SHA_hash -AddToPath
  -- Install Ninja-build v1.8.2 ...
  -- Install Ninja-build v1.8.2 ... done

  [Preferred usage]
  Add the ninja to the front of `$env:PATH`. To allow execution with: `ninja`.
.EXAMPLE
  $NinjaExe = Install-Ninja -Tag v1.8.2 -Hash $SHA_hash -AddToPath

  Save the path to `ninja.exe` in a variable.
.EXAMPLE
  Install-Ninja v1.8.2 -Hash $SHA_hash -InstallDir ~\tools\ninja
  -- Install Ninja-build v1.8.2 ...
  -- Install Ninja-build v1.8.2 ... done

  Download Ninja-build and install to `~\tools\ninja\ninja-v1.8.2\`.
  The given directory needs to exist.
.EXAMPLE
  Install-Ninja -Tag v1.8.2
  -- Install Ninja-build v1.8.2 ...
  WARNING: Install-Ninja: No hash given.
  -- Install Ninja-build v1.8.2 ... done
.EXAMPLE
  Install-Ninja -Tag v1.8.2 -Quiet
  WARNING: Install-Ninja: No hash given.
.EXAMPLE
  Install-Ninja -Tag v1.8.2 -Hash aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  -- Install Ninja-build v1.8.2 ...
  ERROR: Install-Ninja: download hash changed!
  Expected: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  Actual:   9B9CE248240665FCD6404B989F3B3C27ED9682838225E6DC9B67B551774F251E4FF8A207504F941E7C811E7A8BE1945E7BCB94472A335EF15E23A0200A32E6D5
#>
function Install-Ninja {
  [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Low')]
  [OutputType([System.Management.Automation.PathInfo])]
#  [OutputType([String])]
  param(
    [ValidateNotNullOrEmpty()]
    [Alias('Version')]
    # GitHub release tag. E.g. "v1.9.0".
    $Tag = $(throw 'Tag is a required parameter'),
    [ValidatePattern('[0-9a-zA-Z]+')]
    [ValidateNotNullOrEmpty()]
    [Alias('SHA256', 'SHA512')]
    # Hash matching the downloaded archive.
    [String]$Hash,
    [ValidateScript({ Test-Path -LiteralPath "$_" -PathType Container })]
    [ValidateNotNullOrEmpty()]
    # An existing directory to install to (defaults to the current directory).
    [String]$InstallDir = $pwd,
    # Add this ninja version to the begin of the current search path.
    [Switch]$AddToPath,
    [Alias('q')]
    # Reduce console output.
    [Switch]$Quiet,
    # Continue on invalid hash or failed adding Ninja to the search path.
    [Switch]$Force
  )
  Begin
  {
    Get-CommonFlagsCaller $PSCmdlet $ExecutionContext.SessionState

    if (-not $Quiet) { Write-Host "-- Install Ninja-build ${Tag} ..." }

    if ($Hash) {
      switch ($Hash.Length) {
        128 { $HashType = 'SHA512'; break }
        64  { $HashType = 'SHA256'; break }
        32  { $HashType = 'MD5'; break }
        96  { $HashType = 'SHA384'; break }
        40  { $HashType = 'SHA1'; break }
        default {
          Send-Message -Error (
            $($MyInvocation.MyCommand).ToString() + ': Unsupported hash type!') `
            -ContinueOnError:$Force -HideDetails:$Quiet `
            -Details ('Length: ' + $Hash.Length),
             'Supported hash types: SHA(1|256|384|512)|MD5'
        }
      }
    } else {
      Send-Message -Warning (
        $($MyInvocation.MyCommand).ToString() + ': No hash given.'
      )
    }
    ($Path, $Temporary) = Join-Path ($InstallDir, $env:TEMP) ('ninja-' + $Tag)
    $FileName = 'ninja-win.zip'
    $Archive = Join-Path $Temporary $FileName
    $Url = ('https://github.com/ninja-build/ninja/releases/download', $Tag,
      $FileName) -join '/'
  }
  Process
  {
    if (Test-Path (Join-Path $Path 'ninja.exe')) {
      if ($Force) {
        Join-Path $Path 'ninja.exe' |
          Send-Message -Warning 'Overwriting existing files'
      } else {
        Write-Verbose `
          'Skip download and extraction. Already present in install location.'
        return $null
      }
    }

    if (-not (Test-Path $Archive) -or
      ( $Hash -and
        ( $Hash -ne (Get-FileHash $Archive -Algorithm $HashType).Hash )
      )
    ) {
      $Err = $null
      $Err = Invoke-Curl -URL $Url -OutPath $Archive

      if ($Err) {
        Remove-Temporary $Temporary
        $Err | Send-Message -Error (
          ($MyInvocation.MyCommand).ToString() + ': Download failed'
        )
      }

      if ($Hash -and -not $WhatIfPreference ) {
        $NewHash = (Get-FileHash $Archive -Algorithm $HashType).Hash
        if ($Hash -ne $NewHash) {
          Remove-Temporary $Temporary
          Send-Message -Error (
            ($MyInvocation.MyCommand).ToString() + ': download hash changed!') `
            -ContinueOnError:$Force -HideDetails:$Quiet `
            -Details ('Expected: ' + $Hash), ('Actual:   ' + $NewHash)
        }
      }
    }

    Expand-Archive $Archive $Path -FlatPath
  }
  End
  {
    Remove-Temporary $Temporary

    if (-not (Test-Path (Join-Path $Path 'ninja.exe')) -and
      -not $WhatIfPreference
    ) {
      Send-Message -Error (($MyInvocation.MyCommand).ToString() +
        ': Failed to find ninja.exe in expected location.')
    }

    if ($AddToPath -and $PSCmdlet.ShouldProcess($Path, 'add to search path')) {
      if (Test-Command 'ninja --version') {
        Send-Message -Warning (
          'Suppressing existing Ninja install. Version: ' + $(ninja --version)
        )
      }
      $env:PATH = "${Path};$env:PATH"

      if (-not (Test-Command 'ninja --version') ) {
        '-- $env:Path --', ($env:Path -replace ';',"`n") |
          Send-Message -Error 'Failed to find Ninja on the search path.' `
            -HideDetails:$Quiet -ContinueOnError:$Force
      }
    }

    $Path = Join-Path $Path 'ninja.exe'
    if (-not $Quiet) {
      Write-Host "-- Install Ninja-build ${Tag} ... done"
    }
    if (Test-Path $Path) {
      return (Resolve-Path -LiteralPath $Path)
    } else { return $null }
  }
} #/ function Install-Ninja
##====--------------------------------------------------------------------====##

function Remove-Temporary {
  [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Medium')]
  param(
    [ValidatePattern('^[^\\\/\~]')]
    [ValidateScript({ "$_" -match (('^' + $env:TEMP) -replace '\\','\\') })]
    [String]$Path
  )
  if (Test-Path -LiteralPath $Path -PathType Container) {
    Remove-Item -LiteralPath $Path -Recurse
  }
}

Export-ModuleMember -Function Install-Ninja
