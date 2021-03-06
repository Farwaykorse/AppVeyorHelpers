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
      It 'align to default length of 20' {
        $Align = 20
        Join-Info 'some' 'text' | Should -Match 'some:.*text'
        (Join-Info 'some' 'text').Length | Should -Be 24 -Because '20+4'
        Join-Info 'some' 'text' |
          Should -MatchExactly 'some:               text' `
          -Because ('default Length = ' + $Align)
        Join-Info 'some' 'text' |
          Should -not -MatchExactly 'some:    text' -Because 'test-error'
      }
      It 'align to different inherited length of 17' {
        $Align = 17
        Join-Info 'some' 'text' | Should -Match 'some:.*text'
        (Join-Info 'some' 'text').Length | Should -Be 21 -Because '17+4'
        Join-Info 'some' 'text' | Should -MatchExactly 'some:            text' `
          -Because ('$Align = ' + $Align)
        Join-Info 'some' 'text' |
          Should -not -MatchExactly 'some:    text' -Because 'test-error'
      }
      It '-Name longer than (15-2=13) characters' {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
          'PSUseDeclaredVarsMoreThanAssignment', 'Align')]
        $Align = 15
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
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
          'PSUseDeclaredVarsMoreThanAssignment', 'Align')]
        $Align = 15
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
          Set-ItResult -Inconclusive -Because ('no CMake')
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
      # Note: Python v2.7 writes to error stream:
      $available = $(Test-Command 'python --version 2>$null')
      It 'no throw' {
          { Show-PythonVersion } | Should -not -Throw
      }
      It 'return version number' {
        if (-not $available) {
          Set-ItResult -Inconclusive -Because ('no python')
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
          Set-ItResult -Inconclusive -Because ('no clang-cl')
        }
        Show-LLVMVersion | Should -match '^([0-9]+\.)+[0-9]+$'
      }
    }
    Context 'Curl' {
      $available = $(Test-Command 'curl.exe -V')
      It 'no throw' {
          { Show-CurlVersion } | Should -not -Throw
      }
      It 'return version number' {
        if (-not $available) {
          Set-ItResult -Inconclusive -Because ('no Curl')
        }
        Show-CurlVersion | Should -match '^([0-9]+\.)+[0-9]+$'
      }
    }
    Context 'vcpkg' {
      $available = $(Test-Command 'vcpkg version')
      It 'no throw' {
          { Show-VcpkgVersion } | Should -not -Throw
      }
      It 'return version number' {
        if (-not $available) {
          Set-ItResult -Inconclusive -Because ('no vcpkg')
        }
        Show-VcpkgVersion | Should -match '^([0-9]+\.)+[0-9]+'
      }
    }
    Context 'Ninja' {
      $available = $(Test-Command 'ninja --version')
      It 'no throw' {
          { Show-NinjaVersion } | Should -not -Throw
      }
      It 'return version number' {
        if (-not $available) {
          Set-ItResult -Inconclusive -Because ('no Ninja')
        }
        Show-NinjaVersion | Should -match '^([0-9]+\.)+[0-9]+'
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
      It 'Curl' {
        Show-CurlVersion | Should -MatchExactly ' ?'
      }
      It 'vcpkg' {
        Show-VcpkgVersion | Should -MatchExactly ' ?'
      }
      It 'Ninja' {
        Show-NinjaVersion | Should -MatchExactly ' ?'
      }
    }
  }
}
##====--------------------------------------------------------------------====##

Describe 'Show-SystemInfo' {
  # Suppress output to the Appveyor Message API.
  Mock Assert-CI { return $false } -ModuleName Send-Message

  It 'has documentation' {
    Get-Help Show-SystemInfo | Out-String |
      Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
  }
  Context 'Basic operation' {
    It 'no throw' {
      { Show-SystemInfo } | Should -not -Throw
    }
    It 'no throw on -Path' {
      { Show-SystemInfo -Path } | Should -not -Throw
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
    It 'no throw on -Curl' {
      { Show-SystemInfo -Curl } | Should -not -Throw
    }
    It 'no throw on -Vcpkg' {
      { Show-SystemInfo -Vcpkg } | Should -not -Throw
    }
    It 'no throw on -Ninja' {
      { Show-SystemInfo -Ninja } | Should -not -Throw
    }
    It 'no throw on -All' {
      { Show-SystemInfo -All } | Should -not -Throw
    }
    It 'no throw on -Align empty or $null' {
      { Show-SystemInfo -Align '' } | Should -not -Throw
      { Show-SystemInfo -Align $null } | Should -not -Throw
    }
    It 'negative -Align' {
      { Show-SystemInfo -Align -1 } | Should -Throw 'validation script'
    }
  }
  Context 'Setting Align' {
    It 'default alignment (20 characters)' {
      Show-SystemInfo | Should -match '\n.{19} [^ ]'
    }
    It '-Align 25' {
      Show-SystemInfo -Align 25 | Should -match '\n.{24} [^ ]'
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
