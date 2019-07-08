Import-Module -Name "${PSScriptRoot}\Show-SystemInfo.psd1" -Force

Set-StrictMode -Version Latest

##====--------------------------------------------------------------------====##
$global:msg_documentation = 'at least 1 empty line above documentation'

##====--------------------------------------------------------------------====##
Describe 'Internal Join-Info' {
  InModuleScope Show-SystemInfo {
    It 'has documentation' {
      Get-Help Join-Info | Out-String |
        Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
    }
    Context 'Input Errors' {
      It 'throws on missing -Name' {
        { Join-Info -Data 'abc' } | Should -Throw 'Name is a required parameter'
        { Join-Info } | Should -Throw 'Name is a required parameter'
      }
      It 'throws on missing -Data' {
        { Join-Info -Name 'some' } |
          Should -Throw 'Data is a required parameter'
        { Join-Info 'some' } | Should -Throw 'Data is a required parameter'
      }
      It '-Name can be empty' {
          { Join-Info -Name '' -Data 'text' } | Should -not -Throw
          { Join-Info '' 'text' } | Should -not -Throw
      }
      It '-Data can be empty' {
          { Join-Info -Name 'text' -Data '' } | Should -not -Throw
          { Join-Info 'text' '' } | Should -not -Throw
      }
      It 'no throw on -Length empty or $null' {
        { Join-Info -Name 'some' -Data 'text' -Length '' } | Should -not -Throw
        { Join-Info -Name 'some' -Data 'text' -Length $null } |
          Should -not -Throw
      }
      It 'negative -Length' {
        { Join-Info -Name 'some' -Data 'text' -Length -1 } |
          Should -Throw 'validation script'
      }
    }
    Context 'Basic operation' {
      It 'align to default length of 15' {
        Join-Info 'some' 'text' | Should -Match 'some:.*text'
        (Join-Info 'some' 'text').Length | Should -Be 19 -Because '15+4'
        Join-Info 'some' 'text' | Should -MatchExactly 'some:          text' `
          -Because 'default Length = 15'
        Join-Info 'some' 'text' |
          Should -not -MatchExactly 'some:    text' -Because 'test-error'
      }
      It '-Name longer than (15-2=13) characters' {
        Join-Info '1234567890123' 'text' |
          Should -Match '1234567890123: text'
        (Join-Info '1234567890123' 'text').Length |
          Should -Be 19 -Because '13+2+4'
        Join-Info '12345678901234' 'text' |
          Should -Match '12345678901234: text'
        (Join-Info '12345678901234' 'text').Length |
          Should -Be 20 -Because '14+2+4'
        Join-Info '123456789012345678901234567890' 'text' |
          Should -Match '123456789012345678901234567890: text'
        (Join-Info '123456789012345678901234567890' 'text').Length |
          Should -Be 36 -Because '30+2+4'
      }
      It 'align to different -Length' {
        Join-Info 'some' 'text' -Length 10 | Should -Match 'some:.*text'
        (Join-Info 'some' 'text' -Length 10).Length |
          Should -Be 14 -Because '10+4'
        Join-Info 'some' 'text' -Length 10 |
          Should -MatchExactly 'some:     text'
      }
      It 'all numbers' {
        { Join-Info 12 111 5 } | Should -not -Throw
        Join-Info 12 111 5 | Should -MatchExactly '12:  111'
      }
      It 'empty -Name' {
          Join-Info '' 'text' -Length 5 | Should -MatchExactly '     text'
      }
      It 'empty -Data' {
          Join-Info 'item' '' -Length 10 | Should -MatchExactly 'item:     '
      }
    }
  }
}

Describe 'Internal Show-<software>Version' {
  InModuleScope Show-SystemInfo {
    Context 'CMake' {
      $available = $(Test-Command 'cmake --version')
      It 'no throw' {
          { Show-CMakeVersion } | Should -not -Throw
      }
      It 'return version number' {
        if (-not $available) {
          Set-ItResult -Inconclusive -Because ('no cmake')
        }
        Show-CMakeVersion | Should -match '^([0-9]+\.)+[0-9]+(-rc)?$'
      }
    }
    Context '7-zip' {
      $available = $(Test-Command '7z')
      It 'no throw' {
          { Show-7zipVersion } | Should -not -Throw
      }
      It 'return version number' {
        if (-not $available) {
          Set-ItResult -Inconclusive -Because ('no 7-zip')
        }
        Show-7zipVersion | Should -match '^([0-9]+\.)+[0-9]+$'
      }
    }
    Context 'Python' {
      $available = $(Test-Command 'python --version')
      It 'no throw' {
          { Show-PythonVersion } | Should -not -Throw
      }
      It 'return version number' {
        if (-not $available) {
          Set-ItResult -Inconclusive -Because ('no cmake')
        }
        Show-PythonVersion | Should -match '^([0-9]+\.)+[0-9]+$'
      }
    }
    Context 'LLVM/clang' {
      $available = $(Test-Command 'clang-cl --version')
      It 'no throw' {
          { Show-LLVMVersion } | Should -not -Throw
      }
      It 'return version number' {
        if (-not $available) {
          Set-ItResult -Inconclusive -Because ('no cmake')
        }
        Show-LLVMVersion | Should -match '^([0-9]+\.)+[0-9]$'
      }
    }
    Context 'mock software unavailable' {
      Mock Test-Command { return $false } -ModuleName Show-SystemInfo
      It 'CMake' {
        Show-CMakeVersion | Should -MatchExactly ' ?'
      }
      It '7-zip' {
        Show-7zipVersion | Should -MatchExactly ' ?'
      }
      It 'Python' {
        Show-PythonVersion | Should -MatchExactly ' ?'
      }
      It 'LLVM' {
        Show-LLVMVersion | Should -MatchExactly ' ?'
      }
    }
  }
}
##====--------------------------------------------------------------------====##

Describe 'Show-SystemInfo' {
  It 'has documentation' {
    Get-Help Show-SystemInfo | Out-String |
      Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
  }
  Context 'Basic operation' {
    It 'no throw' {
      { Show-SystemInfo } | Should -not -Throw
    }
    It 'no throw on -PowerShell' {
      { Show-SystemInfo -PowerShell } | Should -not -Throw
    }
    It 'no throw on -CMake' {
      { Show-SystemInfo -CMake } | Should -not -Throw
    }
    It 'no throw on -LLVM' {
      { Show-SystemInfo -LLVM } | Should -not -Throw
    }
    It 'no throw on -Python' {
      { Show-SystemInfo -Python } | Should -not -Throw
    }
    It 'no throw on -SevenZip' {
      { Show-SystemInfo -SevenZip } | Should -not -Throw
    }
    It 'no throw on -All' {
      { Show-SystemInfo -All } | Should -not -Throw
    }
  }
  Context 'mock (not) on CI' {
    if (Assert-CI) {
      $real_CI = $true
      Mock Assert-CI { return $false } -ModuleName Show-SystemInfo
    } else {
      $real_CI = $false
      Mock Assert-CI { return $true } -ModuleName Show-SystemInfo
    }
    if (-not $real_CI) {
      $env:APPVEYOR_BUILD_WORKER_IMAGE = 'ABC'
      $env:CONFIGURATION = 'Configuration_Z'
      $env:PLATFORM = 'platform_X'
    }
    It 'no throw' {
      { Show-SystemInfo } | Should -not -Throw
    }
    if (-not $real_CI) {
      $env:APPVEYOR_BUILD_WORKER_IMAGE = ''
      $env:CONFIGURATION = ''
      $env:PLATFORM = ''
    }
  }
}
##====--------------------------------------------------------------------====##
