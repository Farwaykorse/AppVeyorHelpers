<#
  Module manifest for 'Send-TestResult'.
#>
@{
##====--------------------------------------------------------------------====##
RootModule = 'Send-TestResult.psm1'
ModuleVersion = '0.3'
Author = 'Roelf-Jilling Wolthuis'
Copyright = 'Copyright (c) 2019 Farwaykorse (R-J Wolthuis).
Code released under the MIT license.'
# CompanyName = 'Unknown'
Description = 'Upload results from unit-tests to the test console on AppVeyor.'
# GUID = 'd0a9150d-b6a4-4b17-a325-e3a24fed0aa9'
# HelpInfoURI = ''

##====--------------------------------------------------------------------====##
# Requirements

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '5.1'
# Name of the Windows PowerShell host required by this module
# PowerShellHostName = ''
# Minimum version of the Windows PowerShell host required by this module
# PowerShellHostVersion = ''
# Minimum version of the .NET Framework required by this module
# DotNetFrameworkVersion = ''
# Minimum version of the common language runtime (CLR) required by this module
# CLRVersion = ''
# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

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
RequiredModules = @(
  @{ModuleName="${PSScriptRoot}\Send-Message.psd1"; ModuleVersion='0.1'},
  @{ModuleName="${PSScriptRoot}\..\local\All.psd1"; ModuleVersion='0.1'}
)

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

##====--------------------------------------------------------------------====##
# Export configuration

# Functions to export from this module
FunctionsToExport = 'Send-TestResult'
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

##====--------------------------------------------------------------------====### List of all modules packaged with this module
# List of all modules packaged with this module
ModuleList = @('.\Send-Message.psd1')

# List of all files packaged with this module
FileList = @(
  'Send-TestResult.psd1',
  'Send-TestResult.psm1',
  'Send-TestResult.Tests.ps1'
)

}