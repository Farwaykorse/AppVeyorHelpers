Import-Module -Name "${PSScriptRoot}\Send-TestResult.psm1" -Force

Set-StrictMode -Version Latest

##====--------------------------------------------------------------------====##
$global:msg_documentation = 'at least 1 empty line above documentation'

##====--------------------------------------------------------------------====##
Describe 'Send-TestResult' {
  It 'has documentation' {
    Get-Help Send-TestResult | Out-String |
      Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
  }
  It 'supports -WhatIf and -Confirm' {
    Get-Command -Name Send-TestResult -Syntax |
      Should -Match '-Whatif.*-Confirm'
  }
  Context 'Input Errors' {
    # Suppress output to the Appveyor Message API.
    Mock Assert-CI { return $false } -ModuleName Send-Message

    New-Item -Path TestDrive:\ -Name file.xml -ItemType File
    '<?xml version="1.0" encoding="UTF-8"?>' >> TestDrive:\file.xml
    New-Item -Path TestDrive:\ -Name emptyfile.json -ItemType File
    New-Item -Path TestDrive:\ -Name 'name with spaces.xml' -ItemType File
    '<?xml version="1.0"?>' >> 'TestDrive:\name with spaces.xml'

    # parameter: Path
    It 'Required parameter Path' {
      { Send-TestResult } | Should -Throw 'Path is a required parameter'
    }
    It 'Throw on missing -Path input' {
      { Send-TestResult -Path } | Should -Throw 'Missing an argument'
    }
    It 'Throw on empty -Path input' {
      { Send-TestResult -Path '' } | Should -Throw 'argument is null or empty'
    }
    It 'Throw on $null -Path input' {
      { Send-TestResult -Path $null } |
        Should -Throw 'argument is null or empty'
    }
    It 'Throw on unsupported file extensions' {
      { Send-TestResult -Path 'TestDrive:\file' } |
        Should -Throw 'does not match'
      { Send-TestResult -Path 'TestDrive:\file.txt' } |
        Should -Throw 'does not match'
    }
    It 'Throw on non-existing files' {
      { Send-TestResult -Path 'TestDrive:\nonExisting.xml' } |
        Should -Throw 'validation script for the argument'
      { Send-TestResult -Path 'TestDrive:\nonExisting.json' } |
        Should -Throw 'validation script for the argument'
    }
    It 'No Throw when spaces in path' {
      { Send-TestResult -Path 'TestDrive:\name with spaces.xml' JUnit } |
        Should -not -Throw
    }
    It 'Support wildcard characters' {
      { Send-TestResult -Path 'TestDrive:\*.xml' JUnit } |
        Should -not -Throw
      { Send-TestResult -Path 'TestDrive:\fil?.xml' JUnit } |
        Should -not -Throw
    }
    It 'Warn on empty file and skip upload' {
      Send-TestResult -Path 'TestDrive:\emptyfile.json' JUnit 3>&1 |
        Should -Match '^Send-TestResult: .* empty file'
    }
    It 'Aliases for Path' {
      { Send-TestResult -Report 'TestDrive:\emptyfile.json' JUnit 3>$null } |
        Should -not -Throw
      Assert-MockCalled Assert-CI -Exactly 1 -Scope It -ModuleName Send-Message
      { Send-TestResult -File 'TestDrive:\emptyfile.json' JUnit 3>$null } |
        Should -not -Throw
      { Send-TestResult -FileName 'TestDrive:\emptyfile.json' JUnit 3>$null } |
        Should -not -Throw
      Assert-MockCalled Assert-CI -Exactly 3 -Scope It -ModuleName Send-Message
    }
    # parameter: Format
    It 'Required parameter Format' {
      { Send-TestResult -Path 'TestDrive:\file.xml' } |
        Should -Throw 'Format is a required parameter'
    }
    It 'Throw on missing -Format input' {
      { Send-TestResult -Path 'TestDrive:\file.xml' -Format } |
        Should -Throw 'Missing an argument'
    }
    It 'Throw on empty -Format input' {
      { Send-TestResult -Path 'TestDrive:\file.xml' -Format '' } |
        Should -Throw 'argument is null or empty'
    }
    It 'Throw on $null -Format input' {
      { Send-TestResult -Path 'TestDrive:\file.xml' -Format $null } |
        Should -Throw 'argument is null or empty'
    }
    It 'No Throw on valid -Format input' {
      { Send-TestResult -Path 'TestDrive:\file.xml' -Format JUnit } |
        Should -not -Throw
      { Send-TestResult -Path 'TestDrive:\file.xml' -Format NUnit } |
        Should -not -Throw
      { Send-TestResult -Path 'TestDrive:\file.xml' -Format XUnit } |
        Should -not -Throw
      { Send-TestResult -Path 'TestDrive:\file.xml' -Format NUnit3 } |
        Should -not -Throw
      { Send-TestResult -Path 'TestDrive:\file.xml' -Format MSTest } |
        Should -not -Throw
    }
    It 'Throw on unknown -Format input' {
      { Send-TestResult -Path 'TestDrive:\file.xml' -Format Unit } |
        Should -Throw 'does not belong to the set'
      { Send-TestResult -Path 'TestDrive:\file.xml' -Format JUnitXX } |
        Should -Throw 'does not belong to the set'
      { Send-TestResult -Path 'TestDrive:\file.xml' -Format 'JUnit ' } |
        Should -Throw 'does not belong to the set'
      { Send-TestResult -Path 'TestDrive:\file.xml' -Format CTest } |
        Should -Throw 'does not belong to the set'
    }
  }
}
