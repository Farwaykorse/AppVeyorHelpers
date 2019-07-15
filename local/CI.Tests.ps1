Import-Module -Name "${PSScriptRoot}\CI.psd1" -Force

Set-StrictMode -Version Latest

##====--------------------------------------------------------------------====##
$global:msg_documentation = 'at least 1 empty line above documentation'

##====--------------------------------------------------------------------====##
Describe 'Assert-CI' {
  It 'has documentation' {
    Get-Help Assert-CI | Out-String | Should -MatchExactly 'SYNOPSIS' `
      -Because $msg_documentation
  }
  It 'checks if on a CI platform' {
    if ($env:APPVEYOR -or $env:CI) {
      Assert-CI | Should -Be $true
    } else {
      Assert-CI | Should -Be $false
    }
  }
}
