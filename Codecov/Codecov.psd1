@{
##====--------------------------------------------------------------------====##
RootModule = ''
ModuleVersion = '0.3'
Author = 'Roelf-Jilling Wolthuis'
Copyright = 'Copyright (c) 2019 Farwaykorse (R-J Wolthuis).
Code released under the MIT license.'
# CompanyName = 'Unknown'
Description = 'Code coverage information with codecov.io.'
# GUID = 'd0a9150d-b6a4-4b17-a325-e3a24fed0aa9'
# HelpInfoURI = ''

##====--------------------------------------------------------------------====##
# Requirements

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '5.1'

##====--------------------------------------------------------------------====##
# Import configuration

NestedModules = @(
  "${PSScriptRoot}\Assert-ValidCodecovYML.psd1",
  "${PSScriptRoot}\Send-Codecov.psd1"
)

##====--------------------------------------------------------------------====##
# Export configuration

# Functions to export from this module
FunctionsToExport = '*'
# Cmdlets to export from this module
CmdletsToExport = ''
# Variables to export from this module
VariablesToExport = '*'
# Aliases to export from this module
AliasesToExport = ''

##====--------------------------------------------------------------------====##
# List of all modules packaged with this module
ModuleList = @()
# List of all files packaged with this module
FileList = @(
  'Codecov.psd1',
  'Assert-ValidCodecovYML.psm1',
  'Assert-ValidCodecovYML.Tests.ps1',
  'Send-Codecov.psm1',
  'Send-Codecov.Tests.ps1'
)

}
