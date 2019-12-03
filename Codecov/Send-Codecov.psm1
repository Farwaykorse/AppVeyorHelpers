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

  Setting the optional Flags parameter specifies the report within the build.
  Note that codecov.io supports a limited set of characters for flags.
  Only lower-case letters, numbers and the underscore.
.EXAMPLE
  Send-Codecov '.\coverage\*.xml' -BuildName build -Flag @('unittests','flag2')

  Multiple flags can be specified.
  Equivalent to:
  Send-Codecov '.\coverage\*.xml' -BuildName build -Flag 'unittests flag2'
  (Using a space to separate flags.)
.EXAMPLE
  Send-Codecov '.\report.xml' -BuildName 'VS2019 C++17 x64 Debug' -Token a2d1c71d-2565-4321-a080-e0b0eee3c529

  Token is not required for public repositories uploading from Travis, CircleCI
  or AppVeyor.
  The "Repository Upload Token" for your project can be found on the Settings
  page for the repository at https://codecov.io
.EXAMPLE
  Send-Codecov '.\*.xml' -BuildName 'VS2019 C++17 x64' -Token @token_file

  Alternatively the token can be saved in a file and supplied using a @ path.
.NOTES
  Expects execution inside a git worktree or on AppVeyor.
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
    [Alias('Flag')]
    # Flags used on codecov.io, to identify the content. e.g. unittests
    [String[]]$Flags,
    [ValidateNotNullOrEmpty()]
    # Codecov Repository Upload Token, for private repositories.
    # You can also set it in the environment variable "CODECOV_TOKEN".
    # Or supply the path to an token file.
    [String]$Token
  )
  Begin
  {
    Get-CommonFlagsCaller $PSCmdlet $ExecutionContext.SessionState

    $BuildName = Format-BuildName($BuildName)
    Write-Verbose "BuildName: $BuildName"
    if ($Flags) {
      $wrong = @()
      foreach ($item in $Flags) {
        $wrong = $item -split ' ' |
          Select-String -CaseSensitive -NotMatch '^[a-z0-9_]{1,45}$'
      }
      if ($wrong) {
        ('Flags: ' + $Flags -join '; ' + "`n" +
          'Wrong flags: ' + $wrong -join '; '
        ) | Send-Message -Error -Message `
          "$($MyInvocation.MyCommand): Invalid flag name for codecov.io" `
      }
    }

    if ($Token) {
      if ($Token -match '^@.+') {
        if (-not (Test-Path -Path ($Token -replace '@','') -PathType Leaf) ) {
          Send-Message -Error -Message `
            "$($MyInvocation.MyCommand): Invalid file path for Codecov token" `
            -Details "${Token}"
        }
      } elseif ($Token -notmatch '^[a-z0-9-]{36}$') {
        Send-Message -Error -Message `
          "$($MyInvocation.MyCommand): Invalid Codecov token format" `
            -Details "'${Token}' does not match '^[a-z0-9-]{36}$'",
              'You can set the token in the environment variable: CODECOV_TOKEN'
      }
    }

    Install-Uploader -Verbose
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
        Send-Report -FilePath:$FilePath -BuildName:$BuildName -Flags:$Flags `
          -Token:$Token
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
function Assert-CodecovInstalled {
  [CmdletBinding()]
  param()
  Get-CommonFlagsCaller $PSCmdlet $ExecutionContext.SessionState

  if (-not $global:CodecovInstalled) {
    Write-Verbose 'Calling Codecov Python uploader to test if installed.'
    if ( Test-Command -Command 'python -c "import codecov"' ) {
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
  Get-CommonFlagsCaller $PSCmdlet $ExecutionContext.SessionState

  if ($(Assert-CodecovInstalled)) { return }
  if ($PSCmdlet.ShouldProcess(
    'Installing Codecov uploader ...', # Verbose/ WhatIf
    'Are you sure you want to run "pip install codecov" on this system?',
    'Install Codecov uploader') # Caption
  ) {
    $(pip --disable-pip-version-check -qq install codecov)
    if (-not $(Assert-CodecovInstalled)) {
      Write-Verbose 'Retry in user profile ...'
      $(pip --disable-pip-version-check -qq install codecov --user)
      if (-not $(Assert-CodecovInstalled)) {
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
function Format-BuildName {
  param(
    [String]$BuildName = $(throw '-BuildName is required')
  )
  return $BuildName -replace '^\s+|\s+$','' -replace '\s+','_'
}
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Upload the coverage report to codecov.io.
.NOTES
  Expects execution inside a git worktree, with the exception of usage with
  AppVeyor's `shallow_clone: true` setting. Then $env:APPVEYOR_REPO_COMMIT is
  expected and acquired by Codecov.
  For usage see the help: `python -m codecov --help`.
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
    [Alias('Flag')]
    [String[]]$Flags,
    [AllowEmptyString()]
    # Codecov Token or @filename for file containing the token.
    [String]$Token
  )
  Begin
  {
    Get-CommonFlagsCaller $PSCmdlet $ExecutionContext.SessionState

    $codecov_flags = @()
    $disable = @()
    if (-not (Assert-CI)) {
      $disable += 'detect'
      if ($Token) { $codecov_flags += ('--token ' + $Token) }
    }
    if ($BuildName) { $codecov_flags += ('--name ' + $BuildName) }
    if ($FilePath) {
      $codecov_flags += ('--file "' + $FilePath + '"')
      $disable += 'gcov'
    }
    if ( $Flags ) {
      $codecov_flags += ('--flags ' + ($Flags -join ' '))
    }
    if ( $disable ) { $codecov_flags += ('-X ' + ($disable -join ' ')) }
  }
  Process
  {
    Write-Verbose ('codecov ' + ($codecov_flags -join ' '))
    if ($PSCmdlet.ShouldProcess($FilePath, "Upload to codecov.io")) {
      Invoke-Expression (
        'python -m codecov ' + ($codecov_flags -join ' ')
      ) 2>$null
    }
  }
  End {}
}
##====--------------------------------------------------------------------====##

Export-ModuleMember -Function Send-Codecov -Variable CodecovInstalled
