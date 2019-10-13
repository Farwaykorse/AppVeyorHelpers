@{
##====--------------------------------------------------------------------====##
RootModule = ''
ModuleVersion = '0.4.1'
Author = 'Roelf-Jilling Wolthuis'
Copyright = 'Copyright (c) 2019 Farwaykorse (R-J Wolthuis).
Code released under the MIT license.'
# CompanyName = 'Unknown'
Description = 'Leveraging AppVeyor features.'
# ID used to uniquely identify this module
# GUID = 'd0a9150d-b6a4-4b17-a325-e3a24fed0aa9'
# HelpInfoURI = ''

##====--------------------------------------------------------------------====##
# Requirements

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '5.1'

##====--------------------------------------------------------------------====##
# Import configuration

NestedModules = @(
  "${PSScriptRoot}\Send-Message.psd1",
  "${PSScriptRoot}\Send-TestResult.psd1",
  "${PSScriptRoot}\Show-SystemInfo.psd1"
)

##====--------------------------------------------------------------------====##
# Export configuration

# Functions to export from this module
FunctionsToExport = '*'
# Cmdlets to export from this module
CmdletsToExport = ''
# Variables to export from this module
VariablesToExport = ''
# Aliases to export from this module
AliasesToExport = ''

##====--------------------------------------------------------------------====##
# List of all modules packaged with this module
# ModuleList = @()
# List of all files packaged with this module
# FileList = @()

}
