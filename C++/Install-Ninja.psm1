Set-StrictMode -Version Latest
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Install Ninja-build for Windows.
.DESCRIPTION
  Manages the installation of the Ninja build system.
  By version tag as published to GitHub.
.EXAMPLE
  Install-Ninja v1.8.2 -SHA512 9B9CE248240665FCD6404B989F3B3C27ED9682838225E6DC9B67B551774F251E4FF8A207504F941E7C811E7A8BE1945E7BCB94472A335EF15E23A0200A32E6D5
#>
function Install-Ninja {
  [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Low')]
  [OutputType([System.Management.Automation.PathInfo])]
#  [OutputType([String])]
  param(
    [Parameter(ParameterSetName='SHA256')]
    [Parameter(ParameterSetName='SHA512')]
    [Parameter(ParameterSetName='default')]
    [ValidateNotNullOrEmpty()]
    # GitHub release tag. E.g. "v1.9.0".
    $Tag = $(throw 'Tag is a required parameter'),
    [Parameter(ParameterSetName='SHA512',Mandatory)]
    [ValidateLength(128,128)]
    [ValidateNotNullOrEmpty()]
    # Sha512 hash for the downloaded archive.
    [String]$SHA512,
    [Parameter(ParameterSetName='SHA256',Mandatory)]
    [ValidateLength(64,64)]
    [ValidateNotNullOrEmpty()]
    # SHA256 hash for the downloaded archive.
    [String]$SHA256,
    [ValidateScript({ Test-Path -LiteralPath "$_" -PathType Container })]
    [ValidateNotNullOrEmpty()]
    # Where to install to (defaults to the current directory).
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
    if (-not $Quiet) { Write-Host "-- Install Ninja-build ${Tag} ..." }
    if ($SHA512) {
      $Hash_Type = 'SHA512'
      $input_hash = $SHA512
    } elseif ($SHA256) {
      $Hash_Type = 'SHA256'
      $input_hash = $SHA256
    } else {
      Send-Message -Warning "$($MyInvocation.MyCommand): No hash given."
      $input_hash = $null
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
      Write-Verbose `
        'Skip download and extraction. Already present in install location.'
      return $null
    }

    if (-not (Test-Path $Archive) -or
      ( $input_hash -and
        ( $input_hash -ne (Get-FileHash $Archive -Algorithm $Hash_Type).Hash )
      )
    ) {
      if ($PSCmdlet.ShouldProcess($Url, ('download to: ' + $Archive)) ) {
        $Err = Invoke-Curl -URL $Url -OutPath $Archive
      } else { $Err = $null }

      if ($Err) {
        Remove-Temporary $Temporary
        $Err | Send-Message -Error (
          ($MyInvocation.MyCommand).ToString() + ': Download failed'
        )
      }

      if ($input_hash -and -not $WhatIfPreference ) {
        $hash = (Get-FileHash $Archive -Algorithm $Hash_Type).Hash
        if ($input_hash -ne $hash) {
          if (-not $Force) { Remove-Temporary $Temporary }
          Send-Message -Error (
            ($MyInvocation.MyCommand).ToString() + ': download hash changed!') `
            -ContinueOnError:$Force -HideDetails:$Quiet `
            -Details ('Expected: ' + $input_hash), ('Actual:   ' + $hash)
        }
      }
    }

    if ($PSCmdlet.ShouldProcess($Archive, ('deflate in: ' + $Path)) ) {
      Expand-Archive $Archive $Path -FlatPath
    }
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
            -HideDetails:$Quiet
      }
    }

    if (-not $Quiet) {
      Write-Host "-- Install Ninja-build ${Tag} ... done"
    }
    $Path = Join-Path $Path 'ninja.exe'
    if (Test-Path $Path) {
      return (Resolve-Path -LiteralPath $Path)
    } else { return $null }
  }
} #/ function Install-Ninja
##====--------------------------------------------------------------------====##

function Remove-Temporary {
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
