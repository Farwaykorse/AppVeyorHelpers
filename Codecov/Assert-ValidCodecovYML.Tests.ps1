Import-Module -Name "${PSScriptRoot}\Assert-ValidCodecovYML.psd1" -Force

Set-StrictMode -Version Latest

##====--------------------------------------------------------------------====##
$global:msg_documentation = 'at least 1 empty line above documentation'

##====--------------------------------------------------------------------====##
Describe 'Internal Test-DefaultLocations' {
  InModuleScope Assert-ValidCodecovYML {
    It 'has documentation' {
      Get-Help Test-DefaultLocations | Out-String |
        Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
    }
    It 'returns a String' {
      Test-DefaultLocations | Should -BeOfType String
    }
    It 'return a path' {
      Test-Path $(Test-DefaultLocations) -IsValid | Should -Be $true
    }
    It 'should match \.?codecov.yml$' {
      Test-DefaultLocations | Should -Match '\.?codecov.yml$'
    }
    Context 'Not on CI platform' {
      $OriginalValue = $env:APPVEYOR_BUILD_FOLDER
      $env:APPVEYOR_BUILD_FOLDER = $null

      New-Item -Path TestDrive:\ -Name dir -ItemType Directory
      New-Item -Path TestDrive:\dir -Name codecov.yml
      In 'TestDrive:\dir' {
        It 'find in current directory' {
          Test-DefaultLocations | Should -Be './codecov.yml'
        }
        New-Item -Path .\ -Name .codecov.yml
        It 'prefer .codecov.yml over codecov.yml' {
          Test-DefaultLocations | Should -Be './.codecov.yml'
        }
        New-Item -Path TestDrive:\ -Name codecov.yml
        It 'ignore project root' {
          Test-DefaultLocations | Should -Be './.codecov.yml'
          New-Item -Path TestDrive:\ -Name .codecov.yml
          Test-DefaultLocations | Should -Be './.codecov.yml'
        }
      }
      $env:APPVEYOR_BUILD_FOLDER = $OriginalValue
    }
    Context 'on CI platform' {
      $OriginalValue = $env:APPVEYOR_BUILD_FOLDER
      $env:APPVEYOR_BUILD_FOLDER = 'TestDrive:'

      New-Item -Path TestDrive:\ -Name dir -ItemType Directory
      New-Item -Path TestDrive:\dir -Name codecov.yml
      In 'TestDrive:\dir' {
        It 'find in current directory' {
          Test-DefaultLocations | Should -Be './codecov.yml'
        }
        New-Item -Path .\ -Name .codecov.yml
        It 'prefer .codecov.yml over codecov.yml' {
          Test-DefaultLocations | Should -Be './.codecov.yml'
        }
        New-Item -Path TestDrive:\ -Name codecov.yml
        It 'prefer project root' {
          Test-DefaultLocations | Should -Be 'TestDrive:/codecov.yml'
        }
        New-Item -Path TestDrive:\ -Name .codecov.yml
        It 'prefer .codecov.yml over codecov.yml' {
          Test-DefaultLocations | Should -Be 'TestDrive:/.codecov.yml'
        }
      }
      $env:APPVEYOR_BUILD_FOLDER = $OriginalValue
    }
    It 'variables should be restored' {
      if ($env:APPVEYOR) {
        $env:APPVEYOR_BUILD_FOLDER | Should -Be $true
      } else {
        $env:APPVEYOR_BUILD_FOLDER | Should -Be $null
      }
    }
  }
}

##====--------------------------------------------------------------------====##
Describe 'Assert-ValidCodecovYML' {
  # Suppress output to the Appveyor Message API.
  Mock Assert-CI { return $false } -ModuleName Send-Message
  # Temporary working directory (Pesters TestDrive:\)
  New-Item -Path TestDrive:\ -Name codecov.yml  # Valid
  New-Item -Path TestDrive:\ -Name .codecov.yml # Valid
  New-Item -Path TestDrive:\ -Name codecov.xml
  New-Item -Path TestDrive:\ -Name codecovXyml
  New-Item -Path TestDrive:\ -Name Ycodecov.yml
  It 'has documentation' {
    Get-Help Assert-ValidCodecovYML | Out-String |
      Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
  }
  It 'supports -WhatIf and -Confirm' {
    Get-Command -Name Assert-ValidCodecovYML -Syntax |
      Should -Match '-Whatif.*-Confirm'
  }
  Context 'Internal Validation' {
    It 'fail on empty file' {
      { Assert-ValidCodecovYML -Path 'TestDrive:\codecov.yml' 6>$null } |
        Should -Throw 'Empty File'
    }
    It 'fail on empty file 2' {
      { Assert-ValidCodecovYML -Path 'TestDrive:\.codecov.yml' 6>$null } |
        Should -Throw 'Empty File'
    }
  }
  Context 'Multiple matches' {
    It 'Multiple matches' {
      New-Item -Path TestDrive:\ -Name dir1 -ItemType Directory
      New-Item -Path TestDrive:\dir1 -Name codecov.yml
      New-Item -Path TestDrive:\ -Name dir2 -ItemType Directory
      New-Item -Path TestDrive:\dir2 -Name codecov.yml
      # Warning + Error
      { Assert-ValidCodecovYML -Path 'TestDrive:\*\codecov.yml' *>$null } |
        Should -Throw 'Empty File'
      { Assert-ValidCodecovYML -Path 'TestDrive:\*codecov.yml' 6>$null } |
        Should -Throw 'does not match'
    }
  }
  Context 'Alias' {
    It 'Alias File' {
      { Assert-ValidCodecovYML -File 'TestDrive:\codecov.yml' 6>$null } |
        Should -Throw 'Empty File'
    }
    It 'Alias FileName' {
      { Assert-ValidCodecovYML -FileName 'TestDrive:\codecov.yml' 6>$null } |
        Should -Throw 'Empty File'
    }
  }
  Context 'No input' {

  }
  Context 'Input Validation' {
    It 'fail on missing argument' {
      { Assert-ValidCodecovYML -Path } | Should -Throw 'Missing an argument'
    }
    It 'fail on empty path' {
      { Assert-ValidCodecovYML -Path '' } |
        Should -Throw 'argument is null or empty'
    }
    It 'fail on $null path' {
      { Assert-ValidCodecovYML -Path $null } |
        Should -Throw 'argument is null or empty'
    }
    It 'fail on pattern' {
      { Assert-ValidCodecovYML -Path 'TestDrive:\codecov.xml' } |
        Should -Throw 'pattern'
    }
    It 'fail on pattern 2' {
      { Assert-ValidCodecovYML -Path 'TestDrive:\codecovXyml' } |
        Should -Throw 'pattern'
      { Assert-ValidCodecovYML -Path 'TestDrive:\InvalidDir\codecov.xml' } |
        Should -Throw 'pattern'
    }
    It 'non-existent dir' {
      { Assert-ValidCodecovYML -Path 'TestDrive:\InvalidDir\codecov.yml' `
        6>$null } | Should -Throw 'no Codecov configuration file detected'
    }
    New-Item -Path TestDrive:\ -Name directory -ItemType Directory
    It 'non-existent file' {
      { Assert-ValidCodecovYML -Path 'TestDrive:\directory\codecov.yml' `
        6>$null } | Should -Throw 'no Codecov configuration file detected'
    }
    In -Path 'TestDrive:\' {
      It 'passing relative path' {
        { Assert-ValidCodecovYML -Path 'codecov.yml' 6>$null } |
          Should -Throw 'Empty File'
      }
      It 'passing relative path 2' {
        { Assert-ValidCodecovYML -Path '.\codecov.yml' 6>$null } |
          Should -Throw 'Empty File'
      }
      It 'passing relative path 3' {
        { Assert-ValidCodecovYML -Path 'directory\..\codecov.yml' 6>$null } |
          Should -Throw 'Empty File'
      }
    }
  }
  Context 'Check Samples' {
    New-Item -Path TestDrive:\ -Name samples -ItemType Directory
    # valid Sample
    "coverage:`n  precision: 2" > 'TestDrive:\samples\codecov.yml'
    It 'valid sample' {
      Assert-ValidCodecovYML -Path 'TestDrive:\samples\codecov.yml' 6>$null |
        Should -BeTrue
    }
    # invalid sample
    "coverage:`n  somethingRandom: 2" > 'TestDrive:\samples\codecov.yml'
    It 'invalid sample' {
      Assert-ValidCodecovYML -Path 'TestDrive:\samples\codecov.yml' 6>$null |
        Should -BeFalse
    }
  }
}

