param(
  # Enable code coverage reporting.
  [Switch]$Coverage,
  # Enable tests requiring internet access on local builds.
  [Switch]$Online
)

<#
.SYNOPSIS
  Validate the PowerShell environment and run unit tests on functions.
.DESCRIPTION
  Run all unit tests for the PowerShell scripts, upload results to the
  AppVeyor test console, and upload code-coverage to codecov.io.
.EXAMPLE
  .\RunTests.ps1
#>
Set-StrictMode -Version Latest

[String]$local:BuildName = 'PowerShell v' +
  $PSVersionTable.PSVersion.ToString()
if (!$env:APPVEYOR) {
  $BuildName += ' local'
}
$Flag = 'ci_scripts'

##====--------------------------------------------------------------------====##
# Check manifest files
##====--------------------------------------------------------------------====##
Import-Module "${PSScriptRoot}\AppVeyor\Send-Message.psd1"

( Resolve-Path ".\*.psd1", ".\*\*.psd1" |
  ForEach-Object -Process {
    if (-not ($_.Path -match '.*PSScriptAnalyzerSettings\.psd1$') ) {
      Test-ModuleManifest -Path $_
    }
  } | Format-Table -Wrap -AutoSize | Out-String
).Trim() -replace '[ ]*(\r?\n)','$1' |
  Send-Message -Info -Message 'Detected Modules:'

Import-Module "${PSScriptRoot}\AppVeyorHelpers.psd1" -Force
( (Test-ModuleManifest "${PSScriptRoot}\AppVeyorHelpers.psd1"
  ).ExportedFunctions.Values |
  Format-Table -Property Name -HideTableHeaders | Out-String
).Trim() -replace '[ ]*(\r?\n)','$1' |
  Send-Message -Info -Message 'AppVeyorHelpers - Exported Functions:'

##====--------------------------------------------------------------------====##
# Pester Configuration
##====--------------------------------------------------------------------====##
Import-Module "${PSScriptRoot}\local\CI.psd1"

# Specifies the test files run by Pester.
# Here: Only run dedicated test-files in subdirectories relative to this script.
[Object[]]$Script = "${PSScriptRoot}\*\*.Tests.ps1"
# Runs only tests in Describe blocks named to match this pattern.
[String[]]$TestName = @('*')
[String[]]$Tag = ''
[String[]]$ExcludeTag = @('AlwaysExclude')
if (-not ((Assert-CI) -or $Online) ) {
  $ExcludeTag += 'online'
}

[String]$OutputFile = 'ScriptTestResults.xml'
[String]$OutputFormat = 'NUnitXML'
[String]$OutputFormatUpload = 'NUnit'

[Object[]]$CodeCoverage = @(
  @{Path="${PSScriptRoot}\*\*.ps1"; IncludeTests=$false},
  @{Path="${PSScriptRoot}\*\*.psm1"; IncludeTests=$false}
)
[String]$CodeCoverageOutputFile = 'ScriptCodeCoverage.xml'
[String]$CodeCoverageOutputFileFormat = 'JaCoCo'

# Report configuration.
# 'Default','All','Passed','Failed','Pending','Skipped',
#  'Inconclusive','Describe','Context','Summary','Header','Fails'
# Do not use 'none' !
[String[]]$Show = 'All'

##====--------------------------------------------------------------------====##
# Run Unit tests
##====--------------------------------------------------------------------====##
Write-Verbose 'Run Pester unit tests ...'
if ($Coverage) {
  $result = Invoke-Pester `
    -Script $Script -TestName $TestName                 `
    -Tag $Tag -ExcludeTag $ExcludeTag                   `
    -OutputFormat $OutputFormat -OutputFile $OutputFile `
    -CodeCoverage $CodeCoverage                         `
    -CodeCoverageOutputFile $CodeCoverageOutputFile     `
    -CodeCoverageOutputFileFormat $CodeCoverageOutputFileFormat `
    -Show $Show -PassThru
} else {
  $result = Invoke-Pester `
    -Script $Script -TestName $TestName                 `
    -Tag $Tag -ExcludeTag $ExcludeTag                   `
    -OutputFormat $OutputFormat -OutputFile $OutputFile `
    -Show $Show -PassThru
}

if (-not $env:AppVeyor) {
  Write-Verbose 'No AppVeyor environment detected. Uploads disabled.'
  $UseWhatif = $true
} else {
  $UseWhatif = $false
}
Send-TestResult -File $OutputFile -Format $OutputFormatUpload `
  -WhatIf:$UseWhatif
if ($Coverage) {
  try {
    Send-Codecov -File $CodeCoverageOutputFile -BuildName:$BuildName `
      -Flag:$Flag -Whatif:$UseWhatif
  } catch {
    # ignore exit-code
    Write-Verbose 'Send-Codecov failed'
  }
}
Write-Verbose 'Run Pester unit tests ... done'

if ($result.FailedCount -gt 0) {
  throw "$($result.FailedCount) tests failed."
} else {
  Write-Output 'RunTests: success'
}
