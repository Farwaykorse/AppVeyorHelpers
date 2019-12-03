Set-StrictMode -Version Latest
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Download a file using curl.
.DESCRIPTION
  Wrapper around curl.exe.
  Creates the download directory when necessary.
.EXAMPLE
  Invoke-Curl -URL https://example.org/file.zip -OutPath .\dir\new.zip

  If it does not exist, the directory `dir` is created.
  The file `new.zip` is created (or overwritten), with the content from
  `file.zip`.
.EXAMPLE
  Invoke-Curl -URL https://example.org/file.zip -OutPath .\dir

  When the directory `.\dir` exists, a file `file.zip` is created in it with
  the content of the remote `file.zip`.
.OUTPUTS
  Creates the designated file with the file-name and path designated in
  -OutPath, unless the supplied path is an existing directory. Then a file
  matching the download is created in this directory.

  All output is delivered on the standard output channel.
  Without -Verbose, only errors are reported.

  On failure an exit code is set.
#>
function Invoke-Curl {
  [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Low')]
  param(
    [ValidateNotNullOrEmpty()]
    # File to download.
    [String]$URL = $(throw 'URL is a required parameter'),
    [ValidateScript({ Test-Path -LiteralPath "$_" -IsValid })]
    [ValidateNotNullOrEmpty()]
    # Target path.
    [String]$OutPath = $(throw 'OutPath is a required parameter'),
    [ValidateRange(0,100)]
    # Retry request if transient problems occur.
    [Int]$Retry = 5,
    [ValidateRange(30,1200)]
    # Time to wait between retries (seconds).
    [Int]$RetryDelay = 30,
    [ValidateRange(30,1800)]
    # Retry only within this period (seconds).
    [Int]$RetryTimeout = 600
  )
  Begin
  {
    Get-CommonFlagsCaller $PSCmdlet $ExecutionContext.SessionState

    $flags = @(
      '--location',      # -L, Follow redirects.
      '--max-redirs 15', # Maximum number of redirects allowed.
      '--max-time 120',  # -m, Maximum time allowed for transfer.
      "--retry $Retry",
      '--retry-connrefused', # Retry on connection refused (use with --retry).
      "--retry-delay $RetryDelay",
      "--retry-max-time $RetryTimeout"
    )
    if (Test-Path -LiteralPath $OutPath -PathType Container) {
      Push-Location $OutPath
      $flags += @(
        '--remote-name'  # -O, Write output to a file named as the remote file.
      )
    } else {
      if ($OutPath -match '^TestDrive:\\') {
        Write-Verbose ('Pester specific fix. ' +
          'Use of TestDrive:\ conflicts with curl --create-dirs')
        $OutPath = $OutPath -replace '^TestDrive:\\',
          (Resolve-Path TestDrive:\).ProviderPath
      }
      Push-Location $pwd
      $flags += @(
        '--create-dirs', # Create necessary local directory hierarchy.
        '--output', "`"$OutPath`"" # -o, Write to file.
      )
    }
    if ($VerbosePreference -ne 'SilentlyContinue') {
#      $flags += '--verbose' # -v, Make the operation more talkative.
    } else {
      $flags += @(
        '--fail',       # -f, Fail silently on HTTP errors.
        '--silent',     # -s, Silent mode.
        '--show-error'  # -S, Show error even when -s is used.
      )
    }
    [String]$command = ('curl.exe ' + ($flags -join ' ') + ' ' + $URL)
    Write-Verbose $command
  }
  Process
  {
    if ($PSCmdlet.ShouldProcess($OutPath, ('download from: ' + $URL)) ) {
      try { # try-catch for AppVeyor pwsh
        $(Invoke-Expression -Command $command) 2>&1
      } catch {
        Write-Output $_
      }
    }
  }
  End
  {
    Pop-Location
  }
} #/ function Invoke-Curl
##====--------------------------------------------------------------------====##

Export-ModuleMember -Function Invoke-Curl
