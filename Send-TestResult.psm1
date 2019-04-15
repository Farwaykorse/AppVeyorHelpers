Set-StrictMode -Version Latest
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Upload results from unit tests to the AppVeyor Test console.
.FUNCTIONALITY
  Asynchronous background uploading of reports if BitsTransfer is supported.
#>
function Send-TestResult {
  [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Medium')]
  param(
    [ValidateScript({ Test-Path "$_" })]
    [ValidatePattern('.*\.(xml|json)$')]
    [ValidateNotNullOrEmpty()]
    [SupportsWildcards()]
    [Alias('Report','File','FileName')]
    # Path to the file containing the test results.
    [String]$Path = $(throw '-Path is a required parameter'),
    [ValidateSet('JUnit','NUnit','MSTest','XUnit','NUnit3')]
    [ValidateNotNullOrEmpty()]
    # The format used for the report.
    [String]$Format = $(throw '-Format is a required parameter')
  )
  Begin
  {
    if (-not $env:APPVEYOR) {
      Write-Verbose 'Not on AppVeyor CI platform. Upload disabled.'
      $UseWhatIf = $true
    } else {
      $UseWhatIf = $false
    }
    $URL = "https://ci.appveyor.com/api/testresults/${Format}/$($env:APPVEYOR_JOB_ID)"
  }
  Process
  {
    if ($PSCmdlet.ShouldProcess($Path,'Upload to AppVeyor Test console')) {
      [Object[]]$ResolvedList = Resolve-Path -Path $Path
      if (-not $ResolvedList) {
        Send-Message -Error `
          "$($MyInvocation.MyCommand): Invalid path (non-existing): ${item}"
      }
      foreach ($FilePath in $ResolvedList) {
        Write-Verbose "Report: ${FilePath}"
        if ( $(Get-Content -Raw -LiteralPath ($FilePath.Path) ) -eq $null ) {
          Send-Message -Warning `
            "$($MyInvocation.MyCommand): Skip, empty file: ${FilePath}"
          continue
        }
        if (Get-Module BitsTransfer) {
          Start-BitsTransfer -Asynchronous -TransferType Upload `
            -DisplayName 'AppVeyorTestUpload'                   `
            -Description 'Upload results to AppVeyor.'          `
            -RetryInterval 60 -RetryTimeout 1200                `
            -Source "${FilePath}" -Destination "${URL}"         `
            -WhatIf:$UseWhatIf -Confirm:$false
        } elseif (-not $UseWhatIf) {
          $web_client = New-Object 'System.Net.WebClient'
          $web_client.UploadFile("${URL}", "${FilePath}")
        }
      }
    }
  }
} #/ function Send-TestResult
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Report on failed uploads using BitsTransfer.
.Description
  Call in the `on_finish:` script on AppVeyor, to finish all uploads and report
  on any failures.
.EXAMPLE
  Limit-TestResultUpload

  DisplayName
  Description ...
  Error


  RemoteName         : https://example.org/
  LocalName          : R:\TEMP\report.xml
  IsTransferComplete : False
  BytesTotal         : 9551615
  BytesTransferred   : 0
#>
function Limit-TestResultUpload {
  if (-not (Get-Module BitsTransfer)) { return $null }

  Get-BitsTransfer -Name AppVeyorTestUpload |
    Where { $_.Jobstate -eq 'Transferred' } | Complete-BitsTransfer

  $jobs = Get-BitsTransfer -Name AppVeyorTestUpload
  if ($jobs.Count -ne 0) {
    [String[]]$output = @()
    foreach ($item in $jobs) {
      $output += $item.DisplayName
      $output += $item.Description
      $output += $item.JobState
      $output += $($item.FileList | Out-String)
    }
    Send-Message -Error 'Unfinished uploads' -Details $output
  }
}
##====--------------------------------------------------------------------====##

Export-ModuleMember -Function Send-TestResult, Limit-TestResultUpload
