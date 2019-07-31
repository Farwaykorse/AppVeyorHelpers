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
    { Assert-CI } | Should -not -Throw
    (Assert-CI).GetType().Name | Should -Be 'Boolean'
    if ($env:APPVEYOR -or $env:CI) {
      Assert-CI | Should -Be $true
    } else {
      Assert-CI | Should -Be $false
    }
  }
}

##====--------------------------------------------------------------------====##
Describe 'Assert-Windows' {
  It 'has documentation' {
    Get-Help Assert-Windows | Out-String | Should -MatchExactly 'SYNOPSIS' `
      -Because $msg_documentation
  }
  It 'checks if on Microsoft Windows' {
    { Assert-Windows } | Should -not -Throw
    (Assert-Windows).GetType().Name | Should -Be 'Boolean'
  }
  It 'expected environment' {
    if (Assert-CI) {
      $env:CI_WINDOWS | Should -not -Be $null
      $env:CI_LINUX | Should -not -Be $null
      $env:CI_WINDOWS | Should -BeIn @('True', 'False')
      $env:CI_LINUX | Should -BeIn @('True', 'False')
      if ($env:CI_WINDOWS -ceq 'True') {
        $env:CI_LINUX | Should -BeExactly 'False'
      } else {
        $env:CI_WINDOWS | Should -BeExactly 'False'
        $env:CI_LINUX | Should -BeExactly 'True'
      }
    } else {
      $env:CI_WINDOWS | Should -Be $null
      $env:CI_LINUX | Should -Be $null
    }
  }
  It 'expected output' {
    if ($PSVersionTable.PSVersion.Major -lt 6) {
      Assert-Windows | Should -Be $true
      (Get-WmiObject Win32_OperatingSystem).Caption | Should -Match 'Windows'
    } else {
      if ((Get-CimInstance CIM_OperatingSystem).Caption -Match 'Windows') {
        Assert-Windows | Should -Be $true
        (Get-CimInstance CIM_OperatingSystem).Caption |
          Should -Match 'Microsoft Windows'
      } else {
        Assert-Windows | Should -Be $false
      }
    }
  }
  $original_CI_WINDOWS = $env:CI_WINDOWS
  It 'use environment variable CI_WINDOWS' {
    $env:CI_WINDOWS = 'True'
    Assert-Windows | Should -Be $true
    $env:CI_WINDOWS = 'False'
    Assert-Windows | Should -Be $false
    $env:CI_WINDOWS = $true
    Assert-Windows | Should -Be $true
    $env:CI_WINDOWS = $false
    Assert-Windows | Should -Be $false
    $env:CI_WINDOWS = 1
    Assert-Windows | Should -Be $false
    $env:CI_WINDOWS = 'someText'
    Assert-Windows | Should -Be $false
  }
  $env:CI_WINDOWS = $null
  It 'PowerShell 5: only on Windows' {
    if ($PSVersionTable.PSVersion.Major -lt 6) {
      Assert-Windows | Should -Be $true
    } else {
      Set-ItResult -Inconclusive -Because 'ran in pwsh'
    }
  }
  $env:CI_WINDOWS = $original_CI_WINDOWS
}
