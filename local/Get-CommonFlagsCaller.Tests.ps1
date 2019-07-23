Import-Module -Name "${PSScriptRoot}\Get-CommonFlagsCaller.psm1" -Force

Set-StrictMode -Version Latest

##====--------------------------------------------------------------------====##
$global:msg_documentation = 'at least 1 empty line above documentation'

function Test-Preference {
  [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Low')]
  param(
    [Switch]$Enable
  )
  if ($Enable) { Get-CommonFlagsCaller $PSCmdlet $ExecutionContext.SessionState }

  Write-Verbose 'verbose message'

  if ( $PSCmdlet.ShouldProcess('ShouldProcess') ) {
    Write-Output 'risky task'
  }
}

function Test-Calling {
  [CmdletBinding()] # to support -Verbose
  param(
    [Switch]$Enable
  )
  Test-Preference -Enable:$Enable
}

##====--------------------------------------------------------------------====##
Describe 'Get-CommonFlagsCaller' {
  It 'has documentation' {
    Get-Help Get-CommonFlagsCaller | Out-String |
      Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
  }
  It 'no support for -WhatIf and -Confirm' {
    Get-Command -Name Get-CommonFlagsCaller -Syntax |
      Should -not -Match '-WhatIf.*-Confirm'
  }

  Context 'Input Errors' {
    It 'throws on missing -Cmdlet' {
      { Get-CommonFlagsCaller } | Should -Throw 'Missing -Cmdlet $PSCmdlet'
    }
    It 'throws on empty -Cmdlet' {
      { Get-CommonFlagsCaller -Cmdlet } | Should -Throw 'Missing an argument'
    }
    It 'throws on wrong type' {
      { Get-CommonFlagsCaller -Cmdlet 'some string' } |
        Should -Throw 'validation script'
    }
    It 'throws on missing -State' {
      { Get-CommonFlagsCaller -Cmdlet $PSCmdlet } |
        Should -Throw 'Missing -State $ExecutionContext.SessionState'
    }
    It 'throws on empty -State' {
      { Get-CommonFlagsCaller -Cmdlet $PSCmdlet -State } |
        Should -Throw 'Missing an argument'
    }
    It 'throws on wrong type' {
      { Get-CommonFlagsCaller -Cmdlet $PSCmdlet -State 'some string' } |
        Should -Throw 'Cannot convert'
    }
  }
  Context 'Inherit Verbose' {
    It 'helper function should not throw' {
      { Test-Preference } | Should -not -Throw
      { Test-Preference -Enable } | Should -not -Throw
    }
    It 'normal output' {
      Test-Preference | Should -Be 'risky task'
    }
    It 'Verbose output' {
      ((Test-Preference -Verbose 1>$null) 4>&1)[0] |
        Should -Be 'verbose message'
    }
    It 'Calling default: normal output' {
      Test-Calling | Should -Be 'risky task'
    }
    It 'Calling default: Verbose output' {
      Set-ItResult -Skipped -Because 'need a better test'
      ((Test-Calling -Verbose 1>$null) 4>&1) | Should -Be $null
    }
    It 'Calling enhanced: normal output' {
      Test-Calling -Enable | Should -Be 'risky task'
    }
    It 'Calling enhanced: Verbose output' {
      ((Test-Calling -Enable -Verbose 1>$null) 4>&1) | Should -not -Be $null
    }

  }
}
##====--------------------------------------------------------------------====##
