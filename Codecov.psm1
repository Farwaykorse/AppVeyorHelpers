Set-StrictMode -Version Latest
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Upload code coverage reports to codecov.io.
.DESCRIPTION
  Installs and executes the Codecov.io upload tool.
  Sends the reports (XML) to codecov.io, annotated with git and build
  information obtained from the CI environment (when available).
  Supplying a name for the build is mandatory to identify the configuration.
.EXAMPLE
  Send-Codecov '.\report.xml' -BuildName 'VS2019 C++17 x64 Debug'
  
  Report to be combined with any others matching the build name.
  Spaces in the BuildName are replaced with underscores "_".
.EXAMPLE
  Send-Codecov '.\coverage\*.xml' -BuildName build -Flag unittests
  
  Setting the optional Flag parameter specifies the report within the build.
  Note that codecov.io supports a limited set of characters for flags.
  Only lower-case letters, numbers and the underscore.
#>
function Send-Codecov {
  [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Low')]
  param(
    # Path to coverage report.
    [Parameter(Position=0)]
    [SupportsWildcards()]
    [ValidateNotNullOrEmpty()]
    [Alias('Report','File','FileName')]
    [Object[]]$Path = $(throw '-Path is required'),
    # BuildName used on codecov.io, to identify the configuration.
    [Parameter(Position=1)]
    [ValidateNotNullOrEmpty()]
    [String]$BuildName = $(throw '-BuildName is required'),
    [ValidateNotNullOrEmpty()]
    # Flag used on codecov.io, to identify the content.
    [String]$Flag
  )
  Begin
  {
    Install-Uploader -Verbose
    $BuildName = Correct-BuildName($BuildName)
    Write-Verbose "BuildName: $BuildName"
    if ($Flag -and ($Flag -cnotmatch '^[a-z0-9_]{1,45}$')) {
      Send-Message -Error -Message `
        "$($MyInvocation.MyCommand): Invalid flag name for codecov.io" `
        -Details $Flag 
    }
  }
  Process
  {
    foreach ($item in $Path) {
      if (-not ($item -imatch '.*\.xml$')) {
        Send-Message -Error -Message `
          "$($MyInvocation.MyCommand): Invalid pattern: ${item}" `
          -ContinueOnError:$($Path.Count -ne 1)
        continue
      }
      [Object[]]$ResolvedList = Resolve-Path -Path $item `
        -ErrorAction SilentlyContinue
      if (-not $ResolvedList) {
        Send-Message -Error -Message `
          "$($MyInvocation.MyCommand): Invalid path (non-existing): ${item}" `
          -ContinueOnError:$($Path.Count -ne 1)
        continue
      }
      foreach ($FilePath in $ResolvedList) {
        Write-Verbose "Report: ${FilePath}"
        if ( $(Get-Content -Raw -LiteralPath ($FilePath.Path) ) -eq $null ) {
          Send-Message -Warning -Message `
            "$($MyInvocation.MyCommand): Skip, empty file: ${FilePath}"
          continue
        }
        Send-Report -FilePath:$FilePath -BuildName:$BuildName -Flag:$Flag
      }
    }
  }
} #/ function Send-Codecov
##====--------------------------------------------------------------------====##

[Bool]$CodecovInstalled = $false

<#
.SYNOPSIS
  Test if the codecov uploader is available.
.DESCRIPTION
  Wrapper for Test-Command.
  The test is expensive, so the result is cached in the global variable
  `CodecovInstalled`.
#>
function Check-Installed {
  [CmdletBinding()]
  param()
  if (-not $global:CodecovInstalled) {
    Write-Verbose 'Calling Codecov Python uploader to test if installed.'
    if (Test-Command -Command `
      'python -m codecov' -cMatch 'Detecting CI provider'
    ) {
      Set-Variable -Name CodecovInstalled -Value $true -Scope Global
    } else { return $false }
  } 
  return $true
}
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Install the Codecov uploader with the Python package installer pip.
#>
function Install-Uploader {
  [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Medium')]
  param()
  if ($(Check-Installed)) { return }
  if ($PSCmdlet.ShouldProcess(
    'Installing Codecov uploader ...', # Verbose/ WhatIf
    'Are you sure you want to run "pip install codecov" on this system?',
    'Install Codecov uploader') # Caption
  ) {
    $(pip --disable-pip-version-check -q install codecov) 1>$null
    if (-not $(Check-Installed)) {
      Write-Verbose 'Retry in user profile ...'
      $(pip --disable-pip-version-check -q install codecov --user) 1>$null
      if (-not $(Check-Installed)) {
        $(pip --disable-pip-version-check install codecov) |
          Send-Message -Error 'Installing Codecov uploader failed.'
      }
    }
    Write-Verbose 'Installing Codecov uploader ... done'
  }
} # function Install-Uploader
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Clean-up any generated name.
.FUNCTIONALITY
  Strip leading/trailing white-space.
  Replace any white space with a single underscore. (Codecov)
#>
function Correct-BuildName {
  param(
    [String]$BuildName = $(throw '-BuildName is required')
  )
  return $BuildName -replace '^\s+|\s+$','' -replace '\s+','_'
}
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Upload the coverage report to codecov.io.
#>
function Send-Report {
  [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Medium')]
  param(
    [ValidateNotNullOrEmpty()]
    [String]$FilePath = $(throw '-FilePath is required'),
    [ValidateNotNullOrEmpty()]
    [String]$BuildName = $(throw '-BuildName is required'),
    [AllowNull()]
    [AllowEmptyString()]
    [String]$Flag
  )
  if ($PSCmdlet.ShouldProcess($FilePath, "Upload to codecov.io")) {
    if ( $Flag ) {
      $(python -m codecov -n $BuildName -f "$FilePath" -X gcov -F $Flag) 2>$null
    } else { # no Flag
      $(python -m codecov -n $BuildName -f "$FilePath" -X gcov) 2>$null
    }
  }
}
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Upload codecov.yml file for validation.
.DESCRIPTION
  Upload the codecov.yml file to codecov.io to be validated.
  If valid the processed file is returned as an info message to the AppVeyor
  message console.
.EXAMPLE
  Assert-ValidCodecovYML
  INFO: Validated Codecov yml

  Assumes the codecov file is in a default hard-coded location.
.EXAMPLE
  Assert-ValidCodecovYML -Path './.codecov.yml'
  INFO: Validated Codecov yml

  Use a path relative to the current directory.
#>
function Assert-ValidCodecovYML {
  [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Medium')]
  [OutputType([Bool])]
  param(
    # Path to the yml-file. (codecov.yml or .codecov.yml)
    # Note that when it matches multiple files only the first match is used.
    [SupportsWildcards()]
    [ValidatePattern('(^|[\\\/])\.?codecov\.yml$')]
    [ValidateNotNullOrEmpty()]
    [Alias('File','FileName')]
    [String]$Path
  )
  Begin
  {
    Write-Verbose 'Validate Yaml file at codecov.io/validate'
    if (-not $Path) {
      $Path = Test-DefaultLocations
    }
    [Object[]]$Path = Resolve-Path $Path -ErrorAction SilentlyContinue
    if (-not $Path) {
      Send-Message -Error -Message ( $MyInvocation.MyCommand.ToString() +
        ': no Codecov configuration file detected.' )
    } elseif ($Path.Count -gt 1) {
      $Path | Send-Message -Warning ( $MyInvocation.MyCommand.ToString() +
        'Multiple matches found. Processing first match only.' )
    }
    Write-Verbose ('Resolved path: ' + $Path[0].Path)
    $content = Get-Content -Raw -LiteralPath ($Path[0].Path)
    if ($content -eq $null ) {
      Send-Message -Error -Message "$($MyInvocation.MyCommand): Empty File"
    }
    $Uri = 'https://codecov.io/validate'
  }
  Process
  {
    if ($PSCmdlet.ShouldProcess($Path[0].Path, "Upload to $Uri")) {
      try {
        $output = Invoke-RestMethod -Uri https://codecov.io/validate `
          -Body (Get-Content -Raw -LiteralPath ($Path[0].Path)) -Method POST
      } catch {
        if ($PSVersionTable.PSVersion.Major -lt 6) { # confirmed for v5.1
          $details= "($(
            $_.Exception.Response.StatusCode.value__)) $(
            $_.Exception.Response.StatusDescription)"
        } else { # confirmed for v6.1.2
          $details= "($(
            $_.Exception.Response.StatusCode.value__)) $(
            $_.Exception.Response.ReasonPhrase)"
        }
        Send-Message -Error -Message `
          "$($MyInvocation.MyCommand): Validation of Codecov YAML failed!" `
          -ContinueOnError -Details $details, $_.ErrorDetails
        return $false
      }
      Send-Message -Info -Message `
        "$($MyInvocation.MyCommand): Validated Codecov yml" `
        -Details $output.ToString() -HideDetails
      return $true
    } else { return $false }
  }
} #/ function Assert-ValidCodecovYML
##====--------------------------------------------------------------------====##

function Test-DefaultLocations {
  if ($env:APPVEYOR) {
    Write-Verbose 'Fall back to root of build directory.'
    $Path = (${env:APPVEYOR_BUILD_FOLDER} + '/.codecov.yml')
    if (Test-Path $Path) { return $Path }
    $Path = (${env:APPVEYOR_BUILD_FOLDER} + '/codecov.yml')
    if (Test-Path $Path) { return $Path }
  }
  $Path = ('./.codecov.yml')
  if (Test-Path $Path) { return $Path }
  $Path = ('./codecov.yml')
  return $Path
}



Export-ModuleMember `
  -Function Send-Codecov, Assert-ValidCodecovYML `
  -Variable CodecovInstalled
