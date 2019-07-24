@{
RootModule = 'Update-Vcpkg.psm1'
ModuleVersion = '0.1'
Author = 'Roelf-Jilling Wolthuis'
Copyright = 'Copyright (c) 2019 Farwaykorse (R-J Wolthuis).
Code released under the MIT license.'
# CompanyName = 'Unknown'
Description = ''
# GUID = 'd0a9150d-b6a4-4b17-a325-e3a24fed0aa9'
# HelpInfoURI = ''

##====--------------------------------------------------------------------====##
# Requirements

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '5.1'

##====--------------------------------------------------------------------====##
# Import configuration

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @(
  @{ModuleName="${PSScriptRoot}\..\local\All.psd1"; ModuleVersion='0.3'},
  @{ModuleName="${PSScriptRoot}\..\General\Test-Command.psd1"; ModuleVersion='0.3'},
  @{ModuleName="${PSScriptRoot}\..\AppVeyor\Send-Message.psd1"; ModuleVersion='0.4'}
)

##====--------------------------------------------------------------------====##
# Export configuration

# Functions to export from this module
FunctionsToExport = 'Update-Vcpkg'
# Cmdlets to export from this module
CmdletsToExport = ''
# Variables to export from this module
VariablesToExport = ''
# Aliases to export from this module
AliasesToExport = ''

##====--------------------------------------------------------------------====##
# List of all files packaged with this module
FileList = @(
  'Update-Vcpkg.psd1',
  'Update-Vcpkg.psm1',
  'Update-Vcpkg.Tests.ps1'
)
}
