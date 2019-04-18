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
      if ($PSCmdlet.ShouldProcess($FilePath,'Upload to AppVeyor Test console'))
      {
        if (-not $UseWhatIf) {
          $web_client = New-Object 'System.Net.WebClient'
          $web_client.UploadFile("${URL}", "${FilePath}")
        }
      }
    }
  }
} #/ function Send-TestResult
##====--------------------------------------------------------------------====##

Export-ModuleMember -Function Send-TestResult, Limit-TestResultUpload
