Import-Module -Name ${PSScriptRoot}\Test-Command.psm1 -Force

Set-StrictMode -Version Latest

##====--------------------------------------------------------------------====##
Describe 'Test-Command' {
  It 'has documentation' {
    Get-Help Test-Command | Out-String |
      Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
  }
  It 'supports -WhatIf and -Confirm' {
    Get-Command -Name Test-Command -Syntax |
      Should -Match '-Whatif.*-Confirm'
  }
  Context 'Test-ErrorFree' {
    It 'Write-Host' {
      Test-Command -Command 'Write-Host "text"' | Should -BeTrue
    }
    It 'XXX_non-existing' {
      Test-Command -Command 'XXX_non-existing' | Should -BeFalse
    }
    It 'Should not leak throw' {
      { Test-Command 'echo "error"' } | Should -Not -Throw
    }
    It 'Should not leak throw' {
      { Test-Command 'Throw "error"' } | Should -Not -Throw
    }
    It 'Throw Error' {
      Test-Command 'Throw "This is an error."' | Should -BeFalse
    }
    It 'Should not leak an error' {
      { Test-Command 'Write-Error "text"' } | Should -Not -Throw
    }
    It 'Should detect Write-Error' {
      Test-Command 'Write-Error text' | Should -BeFalse
    }
  }
  Context 'Match-Output' {
    It 'Write-Output, success stream (1)' {
      Test-Command -Command 'Write-Output something' -Match 'something' |
        Should -BeTrue
      Test-Command -Command 'Write-Output something' -Match 'thing' |
        Should -BeTrue
    }
    It 'Write-Information, information stream (6)' {
      Test-Command -Command 'Write-Information something' -Match 'oMe' |
        Should -BeTrue
    }
    It 'Write-Information, information stream (6), case sensitive' {
      Test-Command -Command 'Write-Information something' -cMatch 'ome' |
        Should -BeTrue
      Test-Command -Command 'Write-Information something' -cMatch 'oMe' |
        Should -BeFalse
    }
    It 'Write-Output case InSensitive' {
      Test-Command -Command 'Write-Output something' -Match 'THING' |
        Should -BeTrue
    }
    It 'Write-Output case InSensitive, using -iMatch' {
      Test-Command -Command 'Write-Output something' -iMatch 'THING' |
        Should -BeTrue
    }
    It 'Write-Output case Sensitive' {
      Test-Command -Command 'Write-Output something' -cMatch 'THING' |
        Should -BeFalse
    }
    It 'Regex .*' {
      Test-Command -Command 'Write-Output something' -cMatch '.*' |
        Should -BeTrue
    }
    It 'Regex something -match ^s' {
      Test-Command -Command 'Write-Output something' -cMatch '^s' |
        Should -BeTrue
    }
    It 'Regex something -match ^o' {
      Test-Command -Command 'Write-Output something' -cMatch '^a' |
        Should -BeFalse
    }
    It 'Regex something -match g$' {
      Test-Command -Command 'Write-Output something' -cMatch 'g$' |
        Should -BeTrue
    }
    It 'Regex something -match s$' {
      Test-Command -Command 'Write-Output something' -cMatch 's$' |
        Should -BeFalse
    }
    It 'Regex something -match aha|ome' {
      Test-Command -Command 'Write-Output something' -cMatch 'aha|ome' |
        Should -BeTrue
    }
    It 'Should not leak error' {
      { Test-Command 'Write-Error txt' -cMatch 'txt' } | Should -Not -Throw
      { Test-Command 'Write-Error txt' -iMatch 'txt' } | Should -Not -Throw
      { Test-Command 'Throw error' -iMatch 'txt' } | Should -Not -Throw
    }
    It 'Should check redirected error text' {
      Test-Command 'Write-Error something' -cMatch 'thing' | Should -BeFalse
      Test-Command 'Write-Error something 2>&1' -cMatch 'thing' | Should -BeTrue
    }
  }
  Context 'Input Errors' {
    It 'should fail on empty command expression' {
      { Test-Command -Command '' } | Should -Throw
    }
    It 'should fail on empty command expression 2' {
      { Test-Command '' } | Should -Throw
    }
    It 'should fail on $null command expression' {
      { Test-Command -Command } | Should -Throw
    }
    It 'should fail on $null command expression 2' {
      { Test-Command -Command $null } | Should -Throw
    }
    It 'should fail on empty match expression' {
      { Test-Command -Command 'Write-Host' -Match '' } | Should -Throw
    }
    It 'should fail on empty match expression 2' {
      { Test-Command -Command 'Write-Host' '' } | Should -Throw
    }
    It 'should fail on $null match expression' {
      { Test-Command -Command 'Write-Host' -Match } | Should -Throw
    }
    It 'should fail on $null match expression 2' {
      { Test-Command -Command 'Write-Host' -Match $null } | Should -Throw
    }
  }
}

##====--------------------------------------------------------------------====##
Describe 'Test-Command Expensive' -Tag 'Expensive' {
  Context 'Test-ErrorFree' {
    if ($PSVersionTable.PSVersion.Major -lt 6) {
      $shell = 'PowerShell'
    } else {
      $shell = 'pwsh'
    }
    It 'exit code 0' {
      Test-Command -Command "$shell { exit 0 }" | Should -BeTrue
    }
    It 'exit code 1' {
      Test-Command -Command "$shell { exit 1 }" | Should -BeFalse
    }
    It 'ignore exit code' {
      Test-Command -Command "$shell { exit 1 }" -IgnoreExitCode |
        Should -BeTrue
    }
  }
}
