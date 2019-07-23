@{
RootModule = 'EnvironmentPath.psm1'
ModuleVersion = '0.1'
Author = 'Roelf-Jilling Wolthuis'
Copyright = 'Copyright (c) 2019 Farwaykorse (R-J Wolthuis).
Code released under the MIT license.'
# CompanyName = 'Unknown'
Description = '$env:PATH modification.'
# GUID = 'd0a9150d-b6a4-4b17-a325-e3a24fed0aa9'
# HelpInfoURI = ''

##====--------------------------------------------------------------------====##
# Requirements

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '5.1'

##====--------------------------------------------------------------------====##
# Import configuration

# Script files (.ps1) that are run in the caller's environment prior to importing this module
# ScriptsToProcess = @()
# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()
# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()
# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()
# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()
# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

##====--------------------------------------------------------------------====##
# Export configuration

# Functions to export from this module
FunctionsToExport = 'Add-EnvironmentPath'
# Cmdlets to export from this module
CmdletsToExport = ''
# Variables to export from this module
VariablesToExport = ''
# Aliases to export from this module
AliasesToExport = ''

# Private data to pass to the module specified in RootModule/ModuleToProcess
# PrivateData = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

##====--------------------------------------------------------------------====##
# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
FileList = @(
  'EnvironmentPath.psd1',
  'EnvironmentPath.psm1',
  'EnvironmentPath.Tests.ps1'
)
}
