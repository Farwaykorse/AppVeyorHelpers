Import-Module -Name "${PSScriptRoot}\Invoke-Curl.psd1" -Force

Set-StrictMode -Version Latest

##====--------------------------------------------------------------------====##
Import-Module -Name "${PSScriptRoot}\Test-Command.psd1" -minimumVersion 0.3

$global:msg_documentation = 'at least 1 empty line above documentation'
# Test file:
$Url = 'https://github.com/Farwaykorse/AppVeyorHelpers/releases/download/download-test/image.zip'
$Sha512Hash = '50748C4BA79DA01A0358CCF134AE45DB0A3EE1D95A6EBEA35A58E766D67193B527F64EAF864958B994C283ECD950F7C31F07DF9478090AA5DE4E90A38B066539'

##====--------------------------------------------------------------------====##
Describe 'Invoke-Curl (offline)' {
  It 'has documentation' {
    Get-Help Invoke-Curl | Out-String |
      Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
  }
  It 'supports -WhatIf and -Confirm' {
    Get-Command -Name Invoke-Curl -Syntax |
      Should -Match '-WhatIf.*-Confirm'
  }

  Context 'System Requirements' {
    It 'curl.exe should be available on the search Path' {
      Test-Command 'curl.exe --version' | Should -Be $true
    }
  }

  Context 'Input Errors' {
    It 'throws on missing -URL' {
      { Invoke-Curl } | Should -Throw 'URL is a required parameter'
    }
    It 'throws on empty -URL' {
      { Invoke-Curl -URL } | Should -Throw 'missing an argument'
    }
    It 'throws on empty string -URL' {
      { Invoke-Curl -URL '' } | Should -Throw 'argument is null or empty'
    }
    It 'throws on $null -URL' {
      { Invoke-Curl -URL $null } | Should -Throw 'argument is null or empty'
    }
    It 'throws on missing -OutPath' {
      { Invoke-Curl -URL 'http://example.org' } |
        Should -Throw 'OutPath is a required parameter'
    }
    It 'throws on empty -OutPath' {
      { Invoke-Curl -URL 'http://example.org' -OutPath } |
        Should -Throw 'missing an argument'
    }
    It 'throws on empty string -OutPath' {
      { Invoke-Curl -URL 'http://example.org' -OutPath '' } |
        Should -Throw 'argument is null or empty'
    }
    It 'throws on $null -OutPath' {
      { Invoke-Curl -URL 'http://example.org' -OutPath $null } |
        Should -Throw 'argument is null or empty'
    }
    It 'throws on invalid path name -OutPath' {
      { Invoke-Curl -URL 'http://example.org' -OutPath 'T/estDrive:\?' } |
        Should -Throw 'validation script'
    }
    It 'throws on empty -Retry' {
      { Invoke-Curl -URL 'http://example.org' -OutPath '.\' -Retry } |
        Should -Throw 'missing an argument'
    }
    It 'throws on -Retry out of range' {
      { Invoke-Curl -URL 'http://example.org' -OutPath '.\' -Retry 101 } |
        Should -Throw 'greater than the maximum allowed range'
      { Invoke-Curl -URL 'http://example.org' -OutPath '.\' -Retry -1 } |
        Should -Throw 'less than the minimum allowed range'
    }
    It 'throws on empty -RetryDelay' {
      { Invoke-Curl -URL 'http://example.org' -OutPath '.\' -RetryDelay } |
        Should -Throw 'missing an argument'
    }
    It 'throws on -RetryDelay out of range' {
      { Invoke-Curl -URL 'http://example.org' -OutPath '.\' -RetryDelay 1201 } |
        Should -Throw 'greater than the maximum allowed range'
      { Invoke-Curl -URL 'http://example.org' -OutPath '.\' -RetryDelay 29 } |
        Should -Throw 'less than the minimum allowed range'
    }
    It 'throws on string input in -RetryDelay' {
      { Invoke-Curl -URL 'http://example.org' -OutPath '.\' -RetryDelay 'q'
      } | Should -Throw 'cannot convert value'
    }
    It 'throws on $null -RetryDelay' {
      { Invoke-Curl -URL 'http://example.org' -OutPath '.\' -RetryDelay $null
      } | Should -Throw 'The 0 argument is less than the minimum allowed range'
    }
    It 'throws on empty -RetryTimeout' {
      { Invoke-Curl -URL 'http://example.org' -OutPath '.\' -RetryTimeout } |
        Should -Throw 'missing an argument'
    }
    It 'throws on -RetryTimeout out of range' {
      { Invoke-Curl -URL 'http://example.org' -OutPath '.\' -RetryTimeout 1801
      } | Should -Throw 'greater than the maximum allowed range'
      { Invoke-Curl -URL 'http://example.org' -OutPath '.\' -RetryTimeout 29 } |
        Should -Throw 'less than the minimum allowed range'
    }
    It 'throws on string input in -RetryTimeout' {
      { Invoke-Curl -URL 'http://example.org' -OutPath '.\' -RetryTimeout 'q'
      } | Should -Throw 'cannot convert value'
    }
    It 'throws on $null -RetryTimeout' {
      { Invoke-Curl -URL 'http://example.org' -OutPath '.\' -RetryTimeout $null
      } | Should -Throw 'the 0 argument is less than the minimum allowed range'
    }
  }

  Context 'WhatIf' {
    New-Item 'TestDrive:\' -Name dir -ItemType Directory -Force
    $start_path = $PWD
    It 'before: no archive present' {
      Test-Path -LiteralPath 'TestDrive:\dir\image.zip' |
        Should -Be $false
    }
    It 'download image.zip to a directory' {
      { Invoke-Curl -URL $Url -OutPath 'TestDrive:\dir' -WhatIf } |
        Should -not -Throw
    }
    It 'after: no archive present' {
      Test-Path -LiteralPath 'TestDrive:\dir\image.zip' |
        Should -Be $false
    }
    It 'no change in current working directory' {
      $PWD.Path | Should -Be $start_path.Path
    }
    if ($PWD -ne $start_path) { Set-Location $start_path }

    It 'download image.zip to a specific file name' {
      { Invoke-Curl -URL $Url -OutPath 'TestDrive:\dir2\file.zip' -WhatIf } |
        Should -not -Throw
    }
    It 'after: no archive present' {
      Test-Path -LiteralPath 'TestDrive:\dir2\file.zip' |
        Should -Be $false
      Test-Path -LiteralPath 'TestDrive:\dir2' -PathType Container |
        Should -Be $false
    }
    It 'no change in current working directory' {
      $PWD.Path | Should -Be $start_path.Path
    }
    if ($PWD -ne $start_path) { Set-Location $start_path }
  }
}

##====--------------------------------------------------------------------====##
Describe 'Invoke-Curl (online)' -Tag 'online' {
  Context 'download a file' {
    $start_path = $PWD
    It 'download image.zip to a directory' {
      { Invoke-Curl -URL $Url -OutPath 'TestDrive:\' } | Should -not -Throw
    }
    It 'download succeeded' {
      Test-Path -LiteralPath 'TestDrive:\image.zip' -PathType Leaf |
        Should -Be $true
    }
    It 'valid hash' {
      (Get-FileHash 'TestDrive:\image.zip' -Algorithm SHA512).Hash |
        Should -Be $Sha512Hash
    }
    It 'overwrite file' {
      { Invoke-Curl -URL $Url -OutPath 'TestDrive:\' } | Should -not -Throw
    }
    It 'set -Retry 0' {
      { Invoke-Curl -URL $Url -OutPath 'TestDrive:\' -Retry 0 } |
      Should -not -Throw
    }
    It 'no change in current working directory' {
      $PWD.Path | Should -Be $start_path.Path
    }
    if ($PWD -ne $start_path) { Set-Location $start_path }
    It 'download image.zip to a specific file name' {
      { Invoke-Curl -URL $Url -OutPath 'TestDrive:\file.zip' } |
        Should -not -Throw
    }
    It 'download succeeded (specific file name)' {
      Test-Path -LiteralPath 'TestDrive:\file.zip' -PathType Leaf |
        Should -Be $true
    }
    It 'valid hash (specific file name)' {
      (Get-FileHash 'TestDrive:\file.zip' -Algorithm SHA512).Hash |
        Should -Be $Sha512Hash
    }
    It 'no change in current working directory' {
      $PWD.Path | Should -Be $start_path.Path
    }
    if ($PWD -ne $start_path) { Set-Location $start_path }
    It 'download image.zip to a specific path' {
      { Invoke-Curl -URL $Url -OutPath 'TestDrive:\dir\file.zip' } |
        Should -not -Throw
    }
    #ls TestDrive:\ | write-host
    It 'created directory (specific path)' {
      Test-Path -LiteralPath 'TestDrive:\dir' -PathType Container |
        Should -Be $true
    }
    It 'download succeeded (specific path)' {
      Test-Path -LiteralPath 'TestDrive:\dir\file.zip' -PathType Leaf |
        Should -Be $true
    }
    It 'valid hash (specific path)' {
      (Get-FileHash 'TestDrive:\dir\file.zip' -Algorithm SHA512).Hash |
        Should -Be $Sha512Hash
    }
    It 'no change in current working directory' {
      $PWD.Path | Should -Be $start_path.Path
    }
    if ($PWD -ne $start_path) { Set-Location $start_path }
  }

  Context 'download failures' {
    $start_path = $PWD
    $Wrong_URL = 'https://github.com/Farwaykorse/AppVeyorHelpers/releases/download/download-test/wrong'
    It 'invalid url should not throw' {
      { Invoke-Curl -URL $Wrong_URL -OutPath .\ -Retry 0 } |
        Should -not -Throw
    }
    It 'invalid url' {
      Invoke-Curl -URL $Wrong_URL -OutPath .\ -Retry 0 | Should -Be `
        'curl: (22) The requested URL returned error: 404 Not Found'
    }
    It 'sets exit code 22' {
      if ($PSVersionTable.PSVersion.Major -lt 6 -or -not $(Assert-CI) ) {
        $LASTEXITCODE | Should -Be 22
      } else {
        # pwsh only on AppVeyor
        $LASTEXITCODE | Should -Be 0 -Because 'different behaviour on AppVeyor'
      }
    }
    It 'connection refused to localhost' {
      Invoke-Curl -URL https://localhost/file -OutPath . -Retry 0 | Should -Be `
        'curl: (7) Failed to connect to localhost port 443: Connection refused'
    }
    It 'sets exit code 7' {
      if ($PSVersionTable.PSVersion.Major -lt 6 -or -not $(Assert-CI) ) {
        $LASTEXITCODE | Should -Be 7
      } else {
        # pwsh only on AppVeyor
        $LASTEXITCODE | Should -Be 0 -Because 'different behaviour on AppVeyor'
      }
    }
    It 'no change in current working directory' {
      $PWD.Path | Should -Be $start_path.Path
    }
    if ($PWD -ne $start_path) { Set-Location $start_path }
  }

}
##====--------------------------------------------------------------------====##
