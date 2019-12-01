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
      $env:CI_WINDOWS | Should -BeIn @('true', 'false')
      $env:CI_LINUX | Should -BeIn @('true', 'false')
      if ($env:CI_WINDOWS -ceq 'true') {
        $env:CI_LINUX | Should -BeExactly 'false'
        ### Start Temporary - old build agent. #################################
        # https://help.appveyor.com/discussions/problems/24669
        # New build agent will use lower-case text: true; false.
        Send-Message -Warning 'New build agent: remove compatibility code.' `
          -Details "CI.Tests.ps1`nOnly lower-case values."
      } elseif ($env:CI_WINDOWS -ceq 'True') {
        $env:CI_LINUX | Should -BeExactly 'False'
        # note: also clean up section below.
        #       and in CI.psm1
        ### End Temporary - old build agent. ###################################
      } else {
        $env:CI_WINDOWS | Should -BeExactly 'false'
        $env:CI_LINUX | Should -BeExactly 'true'
      }
    } else { # local
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
    $env:CI_WINDOWS = 'true'
    Assert-Windows | Should -Be $true
    $env:CI_WINDOWS = 'false'
    Assert-Windows | Should -Be $false
    ### Start Temporary - old build agent. #####################################
    $env:CI_WINDOWS = 'True'
    if (Assert-Windows) {
      $env:CI_WINDOWS = $true
      Assert-Windows | Should -Be $true
      $env:CI_WINDOWS = $false
      Assert-Windows | Should -Be $false
    } else {
    ### End Temporary - old build agent. #######################################
    $env:CI_WINDOWS = $true
    Assert-Windows | Should -Be $false
    $env:CI_WINDOWS = $false
    Assert-Windows | Should -Be $false
    ### Start Temporary - old build agent. #####################################
    }
    ### End Temporary - old build agent. #######################################
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

##====--------------------------------------------------------------------====##
Describe 'Assert-Admin' {
  It 'has documentation' {
    Get-Help Assert-Admin | Out-String | Should -MatchExactly 'SYNOPSIS' `
      -Because $msg_documentation
  }
  It 'not throwing' {
    if (-not (Assert-Windows) ) {
      Set-ItResult -Inconclusive -Because 'Requires administrative privileges'
    }
    { Assert-Admin } | Should -not -Throw
    (Assert-Admin).GetType().Name | Should -Be 'Boolean'
  }
  Context 'not on Windows' {
    It 'throws when not on Windows' {
      Mock Assert-Windows { return $false } -ModuleName CI
      { Assert-Admin } | Should -Throw 'only implemented for Windows'
    }
  }
}
