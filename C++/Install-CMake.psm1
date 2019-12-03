Set-StrictMode -Version Latest
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Install CMake for Windows.
.DESCRIPTION
  Manages the installation of the CMake build-configuration-system.
  CMake installations are downloaded from the official Kitware repository on
  GitHub, selection by version number (e.g. '3.12.4').
.FUNCTIONALITY
  Different installation strategies:
  - Install in a custom location and make default for this session: `-AddToPath`
  - Install multiple releases side-by-side and save the returned paths for use.
  - Install or update the system version: `-Installer`
    Requires administrative permissions and allows for only one version.
    (Not recommended for CI systems.)

  A custom download and install directory can be set. To limit traffic caching
  of the archive/installer can be achieved with `-KeepArchive`.

  Archive integrity is verified using a hash (SHA512, SHA384, SHA256, SHA1 and
  MD5 hashes are supported). When no hash is supplied hashes are acquired from
  the Kitware/CMake repository.
.EXAMPLE
  Install-CMake -Version 3.16.0 -InstallDir 'C:\CMake' -DownloadDir 'C:\TEMP'
  -- Install CMake 3.16.0 ...
  -- Install CMake 3.16.0 ... done

  Path
  ----
  C:\CMake\cmake-3.16.0-win64-x64\bin\cmake.exe
.EXAMPLE
  Install-CMake -Version 3.16.0 -InstallDir 'C:\CMake' -AddToPath
  -- Install CMake 3.16.0 ...
  -- Install CMake 3.16.0 ... done
.EXAMPLE
  cd C:\folder
  $cmake = @()
  $cmake += Install-CMake -Version 3.16.0 -DownloadDir 'C:\cached' -KeepArchive
  $cmake += Install-CMake -Version 3.15.4 -DownloadDir 'C:\cached' -KeepArchive
  $cmake[0]

  C:\folder\cmake-3.16.0-win64-x64\bin\cmake.exe
.NOTES
  No Linux or MacOSX support.
  Assumes a 64-bit Windows system. Thus only CMake v3.6.0 and newer are supported.
#>
function Install-CMake {
  [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Low')]
  [OutputType([System.Management.Automation.PathInfo])]
  param(
    [ValidateNotNullOrEmpty()]
    # CMake version. E.g. "3.14.5".
    [String]$Version = $(throw 'Version is a required parameter'),
    [ValidatePattern('^[0-9a-fA-F]+$')]
    [ValidateNotNullOrEmpty()]
    # Hash matching the downloaded archive.
    [String]$Hash,
    [Parameter(ParameterSetName='default')]
    [ValidateScript({ Test-Path -LiteralPath "$_" -PathType Container })]
    [ValidateNotNullOrEmpty()]
    # An existing directory to install to (defaults to the current directory).
    [String]$InstallDir = $pwd,
    [ValidateScript({ Test-Path -LiteralPath "$_" -PathType Container })]
    [ValidateNotNullOrEmpty()]
    # An existing directory to download to (defaults to the temporary path).
    [String]$DownloadDir = "${env:TEMP}",
    [Parameter(ParameterSetName='default')]
    # Add this version to the begin of the current search path.
    [Switch]$AddToPath,
    [Parameter(ParameterSetName='installer',Mandatory)]
    # Get installer. Replaces installed version.
    [Switch]$Installer,
    # Do not remove the archive after installation.
    [Switch]$KeepArchive,
    [Alias('q')]
    # Reduce console output.
    [Switch]$Quiet,
    # Continue on invalid hash or failed adding to the search path.
    [Switch]$Force
  )
  Begin
  {
    Get-CommonFlagsCaller $PSCmdlet $ExecutionContext.SessionState

    if (-not $Quiet) { Write-Host "-- Install CMake ${Version} ..." }

    $Version = $Version -replace '^v',''

    $Url_base = ('https://github.com/Kitware/CMake/releases/download',
      ('v' + $Version)) -join '/'

    # Constructing the File Name
    $EXT = 'zip'
    $Toolset = 'win64-x64'
    if ($Installer) {
      if (-not (Assert-Admin) ) {
        Send-Message -Error (
        ($MyInvocation.MyCommand).ToString() +
        ': Installer requires administrative permissions!') `
        -ContinueOnError:$Force
      }
      $EXT = 'msi'
      if ($env:Path -match ' \(x86\)\\CMake\\bin') {
        $Toolset = 'win32-x86'
      }
    }
    $FileName = "cmake-${Version}-${Toolset}.${EXT}" # v3.6.0+

    # Get file validation hash from GitHub
    if (-not $Hash) {
      if (-not $Quiet) { Write-Host '-- get hash from GitHub' }
      $tmp = Get-HashFromGitHub -FileName:$FileName `
        -URL:$($($Url_base, "cmake-${Version}-SHA-256.txt") -join '/')
      if ($tmp) { $Hash = $tmp }
    }

    # Check if known hash type
    if ($Hash) {
      switch ($Hash.Length) {
        64  { $HashType = 'SHA256'; break }
        128 { $HashType = 'SHA512'; break }
        32  { $HashType = 'MD5'; break }
        96  { $HashType = 'SHA384'; break }
        40  { $HashType = 'SHA1'; break }
        default {
          Send-Message -Error (
            ($MyInvocation.MyCommand).ToString() + ': Unsupported hash type!') `
            -ContinueOnError:$Force -HideDetails:$Quiet `
            -Details ('Length: ' + $Hash.Length),
             'Supported hash types: SHA(1|256|384|512)|MD5'
        }
      }
    } else {
      Send-Message -Warning (
        $($MyInvocation.MyCommand).ToString() + ': No hash found or given.'
      )
    }

    $Url = ($Url_base, $FileName) -join '/'
    $Temporary = Join-Path $DownloadDir ('cmake-' + $Version)
    $Archive = Join-Path $Temporary $FileName

    # $Temporary   dir  {TEMP|DownloadDir}\cmake-v3.14.5
    # $Archive     file {TEMP|DownloadDir}\cmake-v3.14.5\{...}.(zip|msi)
    # $InstallDir  dir  {InstalDir}
    # $Path        dir  {InstalDir}\cmake-v3.14.5-win64-x64\bin
    Write-Verbose "Temporary:  $Temporary"
    Write-Verbose "Archive:    $Archive"
    Write-Verbose "InstallDir: $InstallDir"
    # Write-Verbose $Path
  }
  Process
  {
    if (-not $Installer) {
      $Path = Join-Path $InstallDir ('cmake-' + $Version + '-*' )
      if (Test-Path $Path) { $Path = Join-Path (Resolve-Path $Path) 'bin' }
      if (Test-Path (Join-Path $Path 'cmake.exe') -PathType Leaf ) {
        Write-Verbose "Items: $(Get-ChildItem $Path)"
        if ($Force) {
          Send-Message -Warning 'Overwriting existing files' -Details $Path
        } else {
          Write-Verbose `
            'Skip download and extraction. Already present in install location.'
          return
        }
      }
    }

    # Download (if not present or not matching Hash)
    if ($Force -or -not (Test-Path $Archive -PathType Leaf) -or
      ( $Hash -and
        ( $Hash -ne (Get-FileHash $Archive -Algorithm $HashType).Hash )
      )
    ) {
      if ($PSCmdlet.ShouldProcess($Url, ('download to: ' + $Archive)) ) {
        if (-not $Quiet) { Write-Host ('-- download ' + $FileName) }
        $Err = Invoke-Curl -URL $Url -OutPath $Archive
      } else { $Err = $null }

      if ($Err) {
        Remove-Temporary $Temporary
        $Err | Send-Message -Error (
          ($MyInvocation.MyCommand).ToString() + ': Download failed'
        )
      }

      # Download verification
      if ($Hash -and -not $WhatIfPreference ) {
        $NewHash = (Get-FileHash $Archive -Algorithm $HashType).Hash
        if ($Hash -ne $NewHash) {
          if (-not $Force) { Remove-Temporary $Temporary }
          Send-Message -Error (
            ($MyInvocation.MyCommand).ToString() + ': download hash changed!') `
            -ContinueOnError:$Force -HideDetails:$Quiet `
            -Details ('Expected: ' + $Hash), ('Actual:   ' + $NewHash)
        }
      }
    } else {
      Write-Verbose 'Skip download. Archive already present.'
    }

    # Extract/Install
    if ($Installer) {
      if ($PSCmdlet.ShouldProcess($Archive, ('install')) ) {
        if (-not $Quiet) { Write-Host ('-- install ...') }
        Start-Process -Wait -FilePath msiexec `
          -ArgumentList /i, "$Archive", /quiet, /norestart
      }
    } else {
      if ($PSCmdlet.ShouldProcess($Archive, ('deflate in: ' + $InstallDir)) ) {
        if (-not $Quiet) { Write-Host ('-- extract ...') }
        Expand-Archive $Archive $InstallDir -ShowProgress
      }
    }

    if (-not $KeepArchive) { Remove-Temporary $Temporary }

    # Verify Extraction
    if (-not $Installer) {
      $Path = Join-Path $InstallDir ('cmake-' + $Version + '-*' )
      if (Test-Path -Path $Path -PathType Container) {
        $Path = Join-Path (Resolve-Path $Path) 'bin'
      }
      if (Test-Path $Path -PathType Container) {
        $Path = Resolve-Path $Path
      }
      if (-not (Test-Path (Join-Path $Path 'cmake.exe') -PathType Leaf ) -and
        -not $WhatIfPreference
      ) {
        Send-Message -Error (($MyInvocation.MyCommand).ToString() +
          ': Failed to find cmake.exe in expected location.')
      }
    }
  }
  End
  {
    # AddToPath
    if ($AddToPath) {
      if (Test-Command 'cmake --version') {
        Send-Message -Warning (
          'Suppressing existing install. ' + $(cmake --version)
        )
      }
      Push-Path -Path:$Path
    }

    if (($Installer -or $AddToPath) -and -not $WhatIfPreference) {
      Assert-DefaultCMake -Version:$Version -HideErrorDetails:$Quiet
    }

    if (-not $Quiet) {
      Write-Host "-- Install CMake ${Version} ... done"
    }

    if (-not ($Installer -or $AddToPath)) {
      # return path to cmake.exe
      $out = Join-Path $Path 'cmake.exe'
      if (Test-Path $out) {
        return (Resolve-Path -LiteralPath $out)
      } else { return $null }
    }
  } # /End
} # /function Install-CMake
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Add a string to the front of the current session path.
#>
function Push-Path {
  [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Low')]
  param(
    [String]$Path
  )
  Get-CommonFlagsCaller $PSCmdlet $ExecutionContext.SessionState

  if ( $PSCmdlet.ShouldProcess($Path,'add to search path') ) {
    $env:PATH = "${Path};$env:PATH"
  }
}
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Verify if CMake is available on the path, in the expected version.
.DESCRIPTION
  Throws an error when CMake is not available or not the expected version.
#>
function Assert-DefaultCMake {
  param(
    [ValidateNotNullOrEmpty()]
    [String]$Version = $(throw 'Version is a required parameter'),
    [Switch]$HideErrorDetails
  )
  if (-not (Test-Command 'cmake --version') ) {
    '-- $env:Path --', ($env:Path -replace ';',"`n") |
      Send-Message -Error 'Failed to find CMake on the search path.' `
        -HideDetails:$HideErrorDetails
  } elseif (
      $(cmake --version) -join ' ' -notmatch $($Version -replace '\.','\.')
    ) {
    Send-Message -Error 'CMake reports unexpected version id.' `
      -Details ('Expected: ' + $Version), 'cmake --version reports:',
        $(cmake --version)
  }
}
##====--------------------------------------------------------------------====##

function Remove-Temporary {
  [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Low')]
  param(
    [ValidatePattern('^[^\\\/\~]')]
    [String]$Path
  )
  if (Test-Path -LiteralPath $Path -PathType Container) {
    Remove-Item -LiteralPath $Path -Recurse
  } elseif (Test-Path -LiteralPath $Path -PathType Leaf) {
    Remove-Item -LiteralPath $Path
  }
}
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Get the SHA-256 hashes from GitHub.
.DESCRIPTION
  Download a file with hashes from GitHub and extract the one matching the file.
#>
function Get-HashFromGitHub {
  [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Low')]
  [OutputType([String])]
  param(
    [ValidateNotNullOrEmpty()]
    [String]$Url = $(throw 'Url is a required parameter'),
    [ValidateNotNullOrEmpty()]
    [String]$FileName = $(throw 'FileName is a required parameter'),
    [ValidateScript({ Test-Path -LiteralPath "$_" -PathType Container })]
    [ValidateNotNullOrEmpty()]
    [String]$DownloadDir = "${env:TEMP}"
  )
  Begin
  {
    Get-CommonFlagsCaller $PSCmdlet $ExecutionContext.SessionState

    $hash_file = Join-Path $DownloadDir 'CMake_hash_SHA-256.txt'
    $Name_regex = (' .*' + $FileName + '$')
  }
  Process
  {
    if ($PSCmdlet.ShouldProcess($Url, ('download to: ' + $hash_file)) ) {
      $Err = Invoke-Curl -URL "$Url" -OutPath $hash_file
    } else { $Err = $null }

    if ($Err -or $WhatIfPreference) {
      return $null
    } else {
      # Select hash matching $FileName
      $hash = $(
        (Get-Content $hash_file) -match $Name_regex -replace $Name_regex, ''
      )
      Write-Verbose ('Hash from GitHub: ' + $hash)
      return $hash
    }
  }
  End
  {
    Remove-Temporary $hash_file
  }
}
##====--------------------------------------------------------------------====##

Export-ModuleMember -Function Install-CMake
