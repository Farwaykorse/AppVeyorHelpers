Import-Module -Name "${PSScriptRoot}\EnvironmentPath.psd1" -Force

Set-StrictMode -Version Latest

##====--------------------------------------------------------------------====##
$global:msg_documentation = 'at least 1 empty line above documentation'

##====--------------------------------------------------------------------====##
Describe 'Add-EnvironmentPath' {
  It 'has documentation' {
    Get-Help Add-EnvironmentPath | Out-String |
      Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
  }
  It 'supports -WhatIf and -Confirm' {
    Get-Command -Name Add-EnvironmentPath -Syntax |
      Should -Match '-Whatif.*-Confirm'
  }
  Context 'Input Validation' {
    It 'throws on missing -Pat' {
      { Add-EnvironmentPath } | Should -Throw 'Path is a required parameter'
    }
    It 'throws on empty -Path' {
      { Add-EnvironmentPath -Path } | Should -Throw 'missing an argument'
    }
    It 'throws on empty string -Path' {
      { Add-EnvironmentPath -Path '' } |
        Should -Throw 'argument is null or empty'
    }
    It 'throws on $null -Path' {
      { Add-EnvironmentPath -Path $null } |
        Should -Throw 'argument is null or empty'
    }
    It 'throws on invalid -Path' {
      { Add-EnvironmentPath -Path 'TestDrive:\non-existing' } |
        Should -Throw 'validation script'
      New-Item -Path 'TestDrive:\' -Name 'file' -ItemType File
      { Add-EnvironmentPath -Path 'TestDrive:\file' } |
        Should -Throw 'validation script'
      New-Item -Path 'TestDrive:\' -Name 'folder' -ItemType Directory
      { Add-EnvironmentPath -Path 'TestDrive:\fold*' } |
        Should -Throw 'validation script' -Because 'no wildcards accepted'
    }
  }
  Context 'WhatIf' {
    $backup = $env:PATH
    It 'no throw operation' {
      { Add-EnvironmentPath -Path $HOME -WhatIf } | Should -not -Throw
      $env:PATH | Should -not -Match ('^' + ($HOME -replace '\\','\\') + ';.*')
    }
    It 'no change' {
      $env:PATH | Should -Be $backup
    }
    $env:PATH = $backup
  }
  Context 'normal' {
    $backup = $env:PATH
    It 'no throw operation' {
      { Add-EnvironmentPath -Path $HOME } | Should -not -Throw
      $env:PATH | Should -Match ('^' + ($HOME -replace '\\','\\') + ';.+')
    }
    $env:PATH = $backup
  }
}

##====--------------------------------------------------------------------====##
