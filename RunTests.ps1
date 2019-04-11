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
Import-Module "${PSScriptRoot}\Send-Message.psm1"

[Object[]]$manifest = Resolve-Path "${PSScriptRoot}\*.psd1" -Relative
ForEach ($file in $manifest) {
  $(Test-ModuleManifest -Path $file).NestedModules |
    Format-Table Name,ExportedCommands -Wrap | Out-String |
    Send-Message -Info -Message "Module: $file" -HideDetails
}

Import-Module "${PSScriptRoot}\AppVeyorHelpers.psd1"

##====--------------------------------------------------------------------====##
# Install Pester
##====--------------------------------------------------------------------====##
if (-not (Get-Module Pester)) {
  Send-Message -Warning "Pester is not installed."
  $(Import-Module Pester)
  if (Get-Module Pester) {
    Write-Host 'Imported existing Pester version.'
  } else {
    Install-Module Pester -Force
  }
}
Get-Module Pester -ListAvailable

##====--------------------------------------------------------------------====##
# Pester Configuration
##====--------------------------------------------------------------------====##
# Specifies the test files run by Pester.
# Here: Only run dedicated test-files in directory alongside this script.
[Object[]]$Script = "${PSScriptRoot}\*.Tests.ps1"
# Runs only tests in Describe blocks named to match this pattern.
[String[]]$TestName = @('*')
[String[]]$Tag = ''
[String[]]$ExcludeTag = 'AlwaysExclude'

[String]$OutputFile = 'ScriptTestResults.xml'
[String]$OutputFormat = 'NUnitXML'
[String]$OutputFormatUpload = 'NUnit'

[Object[]]$CodeCoverage = @{
  Path="${PSScriptRoot}\*.ps?1"; IncludeTests=$false;
}
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
$result = Invoke-Pester `
  -Script $Script -TestName $TestName                 `
  -Tag $Tag -ExcludeTag $ExcludeTag                   `
  -OutputFormat $OutputFormat -OutputFile $OutputFile `
  -CodeCoverage $CodeCoverage                         `
  -CodeCoverageOutputFile $CodeCoverageOutputFile     `
  -CodeCoverageOutputFileFormat $CodeCoverageOutputFileFormat `
  -Show $Show -PassThru

if (-not $env:AppVeyor) {
  Write-Verbose 'No AppVeyor environment detected. Uploads disabled.'
  $UseWhatif = $true
}
Send-TestResult -File $OutputFile -Format $OutputFormatUpload `
  -WhatIf:$UseWhatif
Send-Codecov -File $CodeCoverageOutputFile -BuildName:$BuildName -Flag:$Flag `
  -Whatif:$UseWhatif
Write-Verbose 'Run Pester unit tests ... done'

if ($result.FailedCount -gt 0) {
  throw "$($result.FailedCount) tests failed."
}
