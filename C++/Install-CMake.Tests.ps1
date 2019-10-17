Import-Module -Name "${PSScriptRoot}\Install-CMake.psd1" -Force

Set-StrictMode -Version Latest

##====--------------------------------------------------------------------====##
$global:msg_documentation = 'at least 1 empty line above documentation'

##====--------------------------------------------------------------------====##
Describe 'Internal Assert-DefaultCMake' {
  InModuleScope Install-CMake {
    # Suppress output to the Appveyor Message API.
    Mock Assert-CI { return $false } -ModuleName Send-Message

    It 'has documentation' {
      Get-Help Assert-DefaultCMake | Out-String |
        Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
    }
    It 'no support for -WhatIf and -Confirm' {
      Get-Command -Name Assert-DefaultCMake -Syntax |
        Should -Match -not '-Whatif.*-Confirm'
    }
    Context 'Input Errors' {
      It 'throws on missing -Version' {
        { Assert-DefaultCMake } |
          Should -Throw 'Version is a required parameter'
        { Assert-DefaultCMake -HideErrorDetails } |
          Should -Throw 'Version is a required parameter'
      }
      It 'throws on $null or empty -Version' {
        { Assert-DefaultCMake -Version '' } | Should -Throw 'null or empty'
        { Assert-DefaultCMake -Version $null } | Should -Throw 'null or empty'
        { Get-HashFromGitHub '' 'text' } | Should -Throw 'null or empty'
        { Assert-DefaultCMake -Version } | Should -Throw 'missing an argument'
      }
    }
    Context 'mocked: not installed' {
      Mock Test-Command { return $false } -ModuleName Install-CMake

      It 'throws when CMake not on path' {
        { Assert-DefaultCMake -Version '3.12.4' 6>$null } |
          Should -Throw 'failed to find CMake'
        Assert-MockCalled Test-Command -ModuleName Install-CMake
      }
    }
    Context 'working' {
      It 'non-existing version' {
        if (-not (Test-Command 'cmake --version') ) {
            Set-ItResult -Inconclusive -Because 'CMake not on path'
        }
        { Assert-DefaultCMake -Version 'xx-some-thing' 6>$null } |
          Should -Throw 'unexpected version'
      }
    }
  }
}

##====--------------------------------------------------------------------====##
Describe 'Internal Get-HashFromGitHub' {
  InModuleScope Install-CMake {
    It 'has documentation' {
      Get-Help Get-HashFromGitHub | Out-String |
        Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
    }
    It 'supports -WhatIf and -Confirm' {
      Get-Command -Name Install-CMake -Syntax |
        Should -Match '-Whatif.*-Confirm'
    }
    Context 'Input Errors' {
      It 'throws on missing -Url' {
        { Get-HashFromGitHub } | Should -Throw 'url is a required parameter'
        { Get-HashFromGitHub -FileName 'x' } |
          Should -Throw 'Url is a required parameter'
      }
      It 'throws on missing -FileName' {
        { Get-HashFromGitHub -Url 'abc' } |
          Should -Throw 'FileName is a required parameter'
      }
      It 'throws on $null or empty -Url' {
          { Get-HashFromGitHub -Url '' -FileName 'text' } |
            Should -Throw 'null or empty'
          { Get-HashFromGitHub '' 'text' } | Should -Throw 'null or empty'
          { Get-HashFromGitHub -Url $null -FileName 'text' } |
            Should -Throw 'null or empty'
      }
      It 'throws on $null or empty -FileName' {
          { Get-HashFromGitHub -Url 'http://example.org' -FileName '' } |
            Should -Throw 'null or empty'
          { Get-HashFromGitHub 'http://example.org' '' } |
            Should -Throw 'null or empty'
          { Get-HashFromGitHub -Url 'http://example.org' -FileName $null } |
            Should -Throw 'null or empty'
      }
      It 'throws on $null or empty -DownloadDir' {
        { Get-HashFromGitHub -Url 'http://example.org/' -FileName 'text' `
          -DownloadDir '' } | Should -Throw 'null or empty'
        { Get-HashFromGitHub -Url 'http://example.org/' -FileName 'text' `
          -DownloadDir $null } | Should -Throw 'null or empty'
      }
      It 'invalid path -DownloadDir' {
        { Get-HashFromGitHub 'http://example.org/' -FileName 'some' `
          -DownloadDir 'text' } | Should -Throw 'validation script'
      }
    }
    Context 'WhatIf' {
      It 'WhatIf' {
        Get-HashFromGitHub -Url (
          'https://github.com/Kitware/CMake/releases/download/' +
          'v3.6.1/cmake-3.6.1-SHA-256.txt'
          ) -FileName 'cmake-3.6.1-win64-x64.zip' -Whatif | Should -Be $null
      }
    }
    Context 'Basic operation' {
      It 'normal operation' {
        Get-HashFromGitHub -Url (
          'https://github.com/Kitware/CMake/releases/download/' +
          'v3.6.0/cmake-3.6.0-SHA-256.txt'
          ) -FileName 'cmake-3.6.0-win64-x64.zip' | Should -Be `
          '24c6fe91991ece9deae9a926bc925ec0b9d5702ffe174ed85062dc5a6fccf0f4'
      }
      It 'non-existing download' {
        Get-HashFromGitHub -Url (
          'https://github.com/Kitware/CMake/releases/download/' +
          'v3.6.X/cmake-3.6.X-SHA-256.txt'
          ) -FileName 'cmake-3.6.X-win64-x64.zip' | Should -Be $null
      }
      It 'non-existing FileName' {
        Get-HashFromGitHub -Url (
          'https://github.com/Kitware/CMake/releases/download/' +
          'v3.6.0/cmake-3.6.0-SHA-256.txt'
          ) -FileName 'cmake-3.6.0-other.zip' | Should -Be $null
      }
      It 'incomplete FileName' {
        Get-HashFromGitHub -Url (
          'https://github.com/Kitware/CMake/releases/download/' +
          'v3.6.0/cmake-3.6.0-SHA-256.txt'
          ) -FileName 'cmake-3.6.0-win64-x64' | Should -Be $null
      }
    }
  }
}

##====--------------------------------------------------------------------====##
Describe 'Install-CMake' {
  # Suppress output to the Appveyor Message API.
  Mock Assert-CI { return $false } -ModuleName Send-Message

  # Empty file hashes
  $empty_MD5 =  'D41D8CD98F00B204E9800998ECF8427E'
  $empty_SHA1 = 'DA39A3EE5E6B4B0D3255BFEF95601890AFD80709'
  $empty_SHA256 = `
    'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855'
  $empty_SHA384 = `
    '38B060A751AC96384CD9327EB1B1E36A21FDB71114BE07434C0CC7BF63F6E1DA274EDEBFE76F65FBD51AD2F14898B95B'
  $empty_SHA512 = `
    'CF83E1357EEFB8BDF1542850D66D8007D620E4050B5715DC83F4A921D36CE9CE47D0D13C5D85F2B0FF8318D2877EEC2F63B931BD47417A81A538327AF927DA3E'


  It 'has documentation' {
    Get-Help Install-CMake | Out-String |
      Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
  }
  It 'supports -WhatIf and -Confirm' {
    Get-Command -Name Install-CMake -Syntax |
      Should -Match '-Whatif.*-Confirm'
  }

  Context 'System Requirements' {
    Import-Module -Name "${PSScriptRoot}\..\General\Test-Command.psd1"

    It 'curl.exe should be available on the search Path' {
      Test-Command 'curl.exe --version' | Should -Be $true
    }
    It '7z should be available on the search Path' {
      Test-Command '7z' | Should -Be $true
    }
  }

  Context 'Input Errors' {
    It 'throws on missing -Version' {
      { Install-CMake } | Should -Throw 'Version is a required parameter'
    }
    It 'throws on empty -Version' {
      { Install-CMake -Version } | Should -Throw 'missing an argument'
    }
    It 'throws on empty string -Version' {
      { Install-CMake -Version '' } | Should -Throw 'argument is null or empty'
    }
    It 'throws on $null -Version' {
      { Install-CMake -Version $null } |
        Should -Throw 'argument is null or empty'
    }
    It 'throws on missing -Version tag' {
      { Install-CMake '3.12.4' } |
        Should -Throw 'positional parameter cannot be found'
    }
    It 'throws on empty -Hash' {
      { Install-CMake -Version '3.12.4' -Hash } |
        Should -Throw 'missing an argument'
    }
    It 'throws on empty string -Hash' {
      { Install-CMake -Version '3.12.4' -Hash '' } |
        Should -Throw 'argument is null or empty'
    }
    It 'throws on $null -Hash' {
      { Install-CMake -Version '3.12.4' -Hash $null } |
        Should -Throw 'argument is null or empty'
    }
    It 'throws when -Hash length is not 32, 40, 64, 96 or 128 characters' {
      { Install-CMake -Version '3.12.4' -Hash '123456789' 1>$null 6>$null } |
        Should -Throw 'Unsupported hash type'
    }
    It 'throws on use of invalid characters in the hash' {
      { Install-CMake -Version '3.12.4' `
        -Hash 'D41D8CD98F00B204E980 998ECF8427E' 1>$null 6>$null
      } | Should -Throw 'does not match'
      { Install-CMake -Version '3.12.4' `
        -Hash 'D41D8CD98F00B204E980g998ECF8427E' 1>$null 6>$null
      } | Should -Throw 'does not match'
    }
    It 'throws on empty -InstallDir' {
      { Install-CMake -Version '3.12.4' -InstallDir } |
        Should -Throw 'missing an argument'
    }
    It 'throws on empty string -InstallDir' {
      { Install-CMake -Version '3.12.4' -InstallDir '' } |
        Should -Throw 'argument is null or empty'
    }
    It 'throws on $null -InstallDir' {
      { Install-CMake -Version '3.12.4' -InstallDir $null } |
        Should -Throw 'argument is null or empty'
    }
    It 'throws on non-existing directory -InstallDir' {
      { Install-CMake -Version '3.12.4' `
        -InstallDir 'TestDrive:\nonExistingDir'
      } | Should -Throw 'validation script'
    }
    It 'throws when -InstallDir points to a file' {
      New-Item -Path TestDrive:\ -Name file.txt
      { Install-CMake -Version '3.12.4' -InstallDir 'TestDrive:\file.txt' } |
        Should -Throw 'validation script'
    }
    It 'throws on empty -DownloadDir' {
      { Install-CMake -Version '3.12.4' -DownloadDir } |
        Should -Throw 'missing an argument'
    }
    It 'throws on empty string -DownloadDir' {
      { Install-CMake -Version '3.12.4' -DownloadDir '' } |
        Should -Throw 'argument is null or empty'
    }
    It 'throws on $null -DownloadDir' {
      { Install-CMake -Version '3.12.4' -DownloadDir $null } |
        Should -Throw 'argument is null or empty'
    }
    It 'throws on non-existing directory -DownloadDir' {
      { Install-CMake -Version '3.12.4' `
        -DownloadDir 'TestDrive:\nonExistingDir'
      } | Should -Throw 'validation script'
    }
    It 'throws when -DownloadDir points to a file' {
      New-Item -Path TestDrive:\ -Name file.txt -Force
      { Install-CMake -Version '3.12.4' -DownloadDir 'TestDrive:\file.txt' } |
        Should -Throw 'validation script'
    }
    It 'throws when -Installer is used together with -AddToPath' {
      { Install-CMake -Version '3.12.4' -Installer -AddToPath } |
        Should -Throw 'Parameter set cannot be resolved'
    }
    It 'throws when -Installer is used together with -InstallDir' {
      { Install-CMake -Version '3.12.4' -Installer -InstallDir 'TestDrive:\' } |
        Should -Throw 'Parameter set cannot be resolved'
    }
    It 'accepts switch -Quiet' {
      New-Item 'TestDrive:\install' -ItemType Directory -Force
      { Install-CMake -Version '3.12.4' -Quiet -WrongThing } |
        Should -Throw "parameter name 'WrongThing'"
      { Install-CMake -Version '3.12.4' -DownloadDir 'TestDrive:\' `
        -InstallDir 'TestDrive:\install' -AddToPath `
        -Quiet -WrongThing
      } | Should -Throw "parameter name 'WrongThing'"
      { Install-CMake -Version '3.12.4' -DownloadDir 'TestDrive:\' -Installer `
        -Quiet -WrongThing
      } | Should -Throw "parameter name 'WrongThing'"
    }
    It 'accepts switch -KeepArchive' {
      { Install-CMake -Version '3.12.4' -KeepArchive -WrongThing } |
        Should -Throw "parameter name 'WrongThing'"
      { Install-CMake -Version '3.12.4' -DownloadDir 'TestDrive:\' `
        -InstallDir 'TestDrive:\install' -AddToPath -Quiet `
        -KeepArchive -WrongThing
      } | Should -Throw "parameter name 'WrongThing'"
      { Install-CMake -Version '3.12.4' -DownloadDir 'TestDrive:\' -Installer `
        -Quiet `
        -KeepArchive -WrongThing
      } | Should -Throw "parameter name 'WrongThing'"
    }
    It 'accepts switch -Force' {
       { Install-CMake -Version '3.12.4' -Force -WrongThing } |
        Should -Throw "parameter name 'WrongThing'"
      { Install-CMake -Version '3.12.4' -DownloadDir 'TestDrive:\' `
        -InstallDir 'TestDrive:\install' -AddToPath -Quiet -KeepArchive `
        -Force -WrongThing
      } | Should -Throw "parameter name 'WrongThing'"
      { Install-CMake -Version '3.12.4' -DownloadDir 'TestDrive:\' -Installer `
        -Quiet -KeepArchive `
        -Force -WrongThing
      } | Should -Throw "parameter name 'WrongThing'"
    }
  }

  Context 'WhatIf (zip)' {
    New-Item 'TestDrive:\dir' -ItemType Directory -Force
    $start_path = $PWD
    $original_path = $env:path

    Context 'Clean system' {
      It 'before: no archive present' {
        $Temporary = Join-Path $env:TEMP 'CMake-3.12.4'
        Test-Path -LiteralPath "$(
          Join-Path $Temporary 'cmake-3.12.4-win64-x64.zip'
        )" | Should -Be $false
        Test-Path -LiteralPath "$Temporary" | Should -Be $false
      }
      It 'before: no executable present' {
        Test-Path -LiteralPath 'TestDrive:\dir\CMake-3.12.4\cmake.exe' |
          Should -Be $false
      }
      It 'Call with -WhatIf' {
        { Install-CMake -Version '3.12.4' -InstallDir 'TestDrive:\dir' -Hash `
          $empty_MD5 -WhatIf 6>$null
        } | Should -not -Throw
      }
      It 'show "Install CMake" console messages' {
        $out = (
          Install-CMake -Version '3.12.4' -InstallDir 'TestDrive:\dir' -Hash `
          $empty_MD5 -WhatIf 6>&1
        )
        $out.Length | Should -Be 3
        $out[0] | Should -Match 'Install CMake v?[0-9].* [\.]{3}$'
        $out[1] | Should -Match 'Install CMake .* [\.]{3} done$'
        $out[2] | Should -Be $null
      }
      It '-Quiet hide "Install CMake" console messages' {
        Install-CMake -Version '3.12.4' -InstallDir 'TestDrive:\dir' -Hash `
          $empty_MD5 -WhatIf -Quiet | Should -Be $null
      }
      It 'after: no archive present' {
        $Temporary = Join-Path $env:TEMP 'CMake-3.12.4'
        Test-Path -LiteralPath "$(
          Join-Path $Temporary 'cmake-3.12.4-win64-x64.zip'
        )" | Should -Be $false
        Test-Path -LiteralPath "$Temporary" | Should -Be $false
      }
      It 'after: no executable present' {
        Test-Path -LiteralPath 'TestDrive:\dir\CMake-3.12.4\cmake.exe' |
          Should -Be $false
      }
      It 'no change in current working directory' {
        $PWD.Path | Should -Be $start_path.Path
      }
      if ($PWD -ne $start_path) { cd $start_path }
    }
    Context 'AddToPath' {
      # Suppress output to the Appveyor Message API.
      Mock Assert-CI { return $false } -ModuleName Send-Message

      It 'Call with -WhatIf and -AddToPath' {
        $Temporary = Join-Path $env:TEMP 'CMake-3.12.4'
        if (Test-Path -LiteralPath 'TestDrive:\dir\CMake-3.12.4\cmake.exe') {
          Set-ItResult -Inconclusive -Because 'cmake.exe is already present'
        } elseif (
          Test-Path -LiteralPath "$(
            Join-Path $Temporary 'cmake-3.12.4-win64-x64.zip'
          )"
        ) {
          Set-ItResult -Inconclusive -Because 'archive present'
        } elseif ( Test-Path -LiteralPath "$Temporary" ) {
          Set-ItResult -Inconclusive -Because 'download directory present'
        }
        { Install-CMake -Version '3.12.4' -InstallDir 'TestDrive:\dir' -Hash `
          $empty_MD5 -WhatIf -AddToPath -Quiet 3>$null
        } | Should -not -Throw
       { Install-CMake -Version '3.12.4' -InstallDir 'TestDrive:\dir' -Hash `
          $empty_MD5 -WhatIf -AddToPath -KeepArchive -Quiet 3>$null
        } | Should -not -Throw
        Install-CMake -Version '3.12.4' -InstallDir 'TestDrive:\dir' -Hash `
          $empty_MD5 -WhatIf -AddToPath -Quiet 3>$null | Should -Be $null
        Install-CMake -Version '3.12.4' -InstallDir 'TestDrive:\dir' -Hash `
          $empty_MD5 -WhatIf -AddToPath -KeepArchive -Quiet 3>$null |
          Should -Be $null
      }
      It 'after: no archive present' {
        $Temporary = Join-Path $env:TEMP 'CMake-3.12.4'
        Test-Path -LiteralPath "$(
          Join-Path $Temporary 'cmake-3.12.4-win64-x64.zip'
        )" | Should -Be $false
        Test-Path -LiteralPath "$Temporary" | Should -Be $false
      }
      It 'after: no executable present' {
        Test-Path -LiteralPath 'TestDrive:\dir\CMake-3.12.4\cmake.exe' |
          Should -Be $false
      }
      It 'no change in current working directory' {
        $PWD.Path | Should -Be $start_path.Path
      }
      if ($PWD -ne $start_path) { cd $start_path }
      It 'no change in search path' {
        $env:Path | Should -Be $original_path
      }
      if ($env:Path -ne $original_path) { $env:Path = $original_path }
    }
  }

  Context 'WhatIf (Installer)' {
    Mock Assert-Admin { return $true } -ModuleName Install-CMake
    It 'before: no installer present' {
      $Temporary = Join-Path $env:TEMP 'CMake-3.12.4'
      Test-Path -LiteralPath "$(
        Join-Path $Temporary 'cmake-3.12.4-win64-x64.msi'
      )" | Should -Be $false
      Test-Path -LiteralPath "$Temporary" | Should -Be $false
    }
    It 'test' {
      Install-CMake -Version 3.12.4 -Installer -WhatIf -Quiet -Hash $empty_MD5 |
        should -Be $null
    }
    It 'after: no installer present' {
      $Temporary = Join-Path $env:TEMP 'CMake-3.12.4'
      Test-Path -LiteralPath "$(
        Join-Path $Temporary 'cmake-3.12.4-win64-x64.msi'
      )" | Should -Be $false
      Test-Path -LiteralPath "$Temporary" | Should -Be $false
    }
    It 'error when not an admin' {
      Mock Assert-Admin { return $false } -ModuleName Install-CMake
      { Install-CMake -Version 3.12.4 -Installer -WhatIf -Quiet `
        -Hash $empty_MD5 6>$null
      } | Should -Throw 'Installer requires administrative permissions!'
    }
  }

  Context 'mock download failure' {
    Mock Invoke-Curl { return 'curl: (1) some error' } -ModuleName Install-CMake

    It 'start: no archive present' {
      $Temporary = Join-Path $env:TEMP 'CMake-3.12.4'
      Test-Path -LiteralPath "$(
        Join-Path $Temporary 'cmake-3.12.4-win64-x64.zip'
      )" | Should -Be $false
      Test-Path -LiteralPath "$Temporary" | Should -Be $false
    }
    It 'failing download' {
      { Install-CMake -Version '3.12.4' -InstallDir 'TestDrive:\' -Quiet `
        3>$null 6>$null
      } | Should -Throw 'Download failed'
      Assert-MockCalled Invoke-Curl -ModuleName Install-CMake
    }
  }

  Context 'mocked file-operations' {
    # Suppress output to the Appveyor Message API.
    Mock Assert-CI { return $false } -ModuleName Send-Message
    Mock Invoke-Curl {
      New-Item $OutPath -ItemType File -Force *>$null
    } -ModuleName Install-CMake
    Mock Get-HashFromGitHub { return $null } -ModuleName Install-CMake
    Mock Expand-Archive {
      if (-not (Test-Path $Archive -PathType Leaf)) {
          throw '-Archive does not exist.'
      }
      $internalDir = 'cmake-3.12.4-win64-x64'
      $fullDirPath = Join-Path (Join-Path $InstallDir $internalDir) 'bin'
      New-Item $fullDirPath -ItemType Directory -Force 1>$null
      New-Item (Join-Path $fullDirPath 'cmake.exe') -ItemType File -Force `
      1>$null
    } -ModuleName Install-CMake
    BeforeEach {
      $location = Join-Path "$install_dir" 'cmake-3.12.4-win64-x64'
      if (Test-Path -Path './cmake-3.12.4-win64-x64' -PathType Container) {
        Remove-Item './cmake-3.12.4-win64-x64/' -Recurse
      } elseif (Test-Path -Path "$location" -PathType Container) {
        Remove-Item "$location" -Recurse
      }
    }
    $install_dir = New-Item 'TestDrive:/XInstall' -ItemType Directory -Force

    It 'call Install-CMake' {
      { Install-CMake -Version 3.12.4 -Quiet 3>$null } | Should -Not -Throw
      Assert-MockCalled Invoke-Curl -ModuleName Install-CMake
      Assert-MockCalled Expand-Archive -ModuleName Install-CMake
      Assert-MockCalled Get-HashFromGitHub -ModuleName Install-CMake
    }
    It 'show "Install CMake" console messages' {
      $out = (
        Install-CMake -Version '3.12.4' -Hash $empty_SHA512 6>&1
      )
      $out.Length | Should -Be 5
      $out[0] | Should -Match 'Install CMake v?[0-9].* [\.]{3}$'
      $out[3] | Should -Match 'Install CMake .* [\.]{3} done$'
      $out[4] | Should -Match 'cmake\.exe$'
      Assert-MockCalled Get-HashFromGitHub -ModuleName Install-CMake -Scope It `
        -Times 0 -Exactly
      Assert-MockCalled Invoke-Curl -ModuleName Install-CMake -Scope It `
        -Times 1 -Exactly
      Assert-MockCalled Expand-Archive -ModuleName Install-CMake -Scope It `
        -Times 1 -Exactly
    }
    It '-Quiet hide "Install CMake" console messages' {
      Install-CMake -Version '3.12.4' -Hash $empty_SHA512 -KeepArchive -Quiet |
        Should -Match 'cmake\.exe$'
      Assert-MockCalled Invoke-Curl -ModuleName Install-CMake -Scope It `
        -Times 1 -Exactly
      Assert-MockCalled Expand-Archive -ModuleName Install-CMake -Scope It `
        -Times 1 -Exactly
    }
    It 'supported hash types: MD5' {
      { Install-CMake -Version '3.12.4' -Hash $empty_MD5 -KeepArchive -Quiet
      } | Should -Not -Throw
      Assert-MockCalled Invoke-Curl -ModuleName Install-CMake -Scope It `
        -Times 0 -Exactly
      Assert-MockCalled Expand-Archive -ModuleName Install-CMake -Scope It `
        -Times 1 -Exactly
    }
    It 'supported hash types: SHA1' {
      { Install-CMake -Version '3.12.4' -Hash $empty_SHA1 -KeepArchive -Quiet
      } | Should -Not -Throw
    }
    It 'supported hash types: SHA256' {
      { Install-CMake -Version '3.12.4' -Hash $empty_SHA256 -KeepArchive -Quiet
      } | Should -Not -Throw
    }
    It 'supported hash types: SHA384' {
      { Install-CMake -Version '3.12.4' -Hash $empty_SHA384 -KeepArchive -Quiet
      } | Should -Not -Throw
    }
    It 'supported hash types: SHA512' {
      { Install-CMake -Version '3.12.4' -Hash $empty_SHA512 -KeepArchive -Quiet
      } | Should -Not -Throw
      Assert-MockCalled Invoke-Curl -ModuleName Install-CMake -Scope It `
        -Times 0 -Exactly
    }
    It 'invalid archive hash (MD5)' {
      $wrong_hash = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      { Install-CMake -Version '3.12.4' -Hash $wrong_hash -Quiet 6>$null } |
        Should -Throw 'download hash changed'
      if (Test-Path -Path "$env:TEMP/cmake-3.12.4" -PathType Container){
        $true | Should -Be $false -Because 'archive clean up on error'
      }
      { Install-CMake -Version '3.12.4' -Hash $wrong_hash -KeepArchive -Quiet `
        6>$null
      } | Should -Throw 'download hash changed'
    }
    It '-Force: no throw on invalid archive hash' {
      $wrong_hash = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      { Install-CMake -Version '3.12.4' -Hash $wrong_hash -Quiet -Force 6>$null
      } | Should -Not -Throw
      $out = (
        Install-CMake -Version '3.12.4' -Hash $wrong_hash -Quiet -Force 6>&1 `
          3>$null
      )
      $out.Length | Should -Be 2
      $out[0] | Should -Match 'download hash changed!$'
      Assert-MockCalled Invoke-Curl -ModuleName Install-CMake -Scope It `
        -Times 2 -Exactly
    }
    It '-Force: overwrite archive and install' {
      Install-CMake -Version '3.12.4' -Hash $empty_SHA512 -Quiet -Force `
        -KeepArchive 
      Assert-MockCalled Get-HashFromGitHub -ModuleName Install-CMake -Scope It `
        -Times 0 -Exactly
      Assert-MockCalled Invoke-Curl -ModuleName Install-CMake -Scope It `
        -Times 1 -Exactly
      Assert-MockCalled Expand-Archive -ModuleName Install-CMake -Scope It `
        -Times 1 -Exactly
      $out = (
        Install-CMake -Version '3.12.4' -Hash $empty_SHA512 -Quiet -Force 3>&1
      )
      Assert-MockCalled Invoke-Curl -ModuleName Install-CMake -Scope It `
        -Times 2 -Exactly
      Assert-MockCalled Expand-Archive -ModuleName Install-CMake -Scope It `
        -Times 2 -Exactly
      $out[0] | Should -Match 'Overwriting existing files'
    }
    It 'custom DownloadDir' {
      # Download to TEMP dir (default)
      Install-CMake -Version '3.12.4' -Hash $empty_SHA512 -KeepArchive -Quiet
      Assert-MockCalled Invoke-Curl -ModuleName Install-CMake -Scope It `
        -Times 1 -Exactly
      # Remove installed
      if (Test-Path -Path './cmake-3.12.4-win64-x64' -PathType Container) {
        Remove-Item "./cmake-3.12.4-win64-x64/" -Recurse
      } else { $false | Should -Be $true }
      # Download to custom folder
      $target_dir = New-Item 'TestDrive:\dir' -ItemType Directory -Force
      Install-CMake -Version '3.12.4' -Hash $empty_SHA512 -KeepArchive `
        -DownloadDir $target_dir -Quiet
      Assert-MockCalled Invoke-Curl -ModuleName Install-CMake -Scope It `
        -Times 2 -Exactly
      # Remove installed
      if (Test-Path -Path './cmake-3.12.4-win64-x64' -PathType Container) {
        Remove-Item "./cmake-3.12.4-win64-x64/" -Recurse
      } else { $false | Should -Be $true }
      # Install using existing archive in custom directory
      Install-CMake -Version '3.12.4' -Hash $empty_SHA512 `
        -DownloadDir $target_dir -Quiet
      Assert-MockCalled Invoke-Curl -ModuleName Install-CMake -Scope It `
        -Times 2 -Exactly
      # Remove installed
      if (Test-Path -Path './cmake-3.12.4-win64-x64' -PathType Container) {
        Remove-Item "./cmake-3.12.4-win64-x64/" -Recurse
      } else { $false | Should -Be $true }
      # Install using existing archive
      Install-CMake -Version '3.12.4' -Hash $empty_SHA512 -Quiet
      Assert-MockCalled Invoke-Curl -ModuleName Install-CMake -Scope It `
        -Times 2 -Exactly
      Assert-MockCalled Expand-Archive -ModuleName Install-CMake -Scope It `
        -Times 4 -Exactly
    }
    It 'custom InstallDir' {
      { Install-Cmake -Version 3.12.4 -Hash $empty_SHA384 `
        -InstallDir $install_dir -Quiet
      } | Should -Not -Throw
    }
    It 'skip download and extraction if version already installed (zip)' {
      # First run installing CMake
      Install-CMake -Version '3.12.4' -Hash $empty_SHA512 -Quiet
      # Second run for same version
      Install-CMake -Version '3.12.4' -Hash $empty_SHA512 -Quiet
      Assert-MockCalled Expand-Archive -ModuleName Install-CMake -Scope It `
        -Times 1 -Exactly
      Assert-MockCalled Invoke-Curl -ModuleName Install-CMake -Scope It `
        -Times 1 -Exactly
    }
    It 'test-logic: no install leak' {
      if (Test-Path -Path './cmake-3.12.4-win64-x64' -PathType Container) {
        Remove-Item "./cmake-3.12.4-win64-x64/" -Recurse
        $false | Should -Be $true
      } else { $true | Should -Be $true }
    }
    It 'test-logic: no install leak (custom InstallDir)' {
      $location = Join-Path "$install_dir" 'cmake-3.12.4-win64-x64'
      if (Test-Path -Path "$location" -PathType Container) {
        Remove-Item "$location" -Recurse
        $false | Should -Be $true
      } else { $true | Should -Be $true }
    }
    It 'test-logic: no archive leak (in TEMP directory)' {
      if (Test-Path -Path "$env:TEMP/cmake-3.12.4" -PathType Container) {
        Remove-Item "$env:TEMP/cmake-3.12.4/" -Recurse
        $false | Should -Be $true
      } else { $true | Should -Be $true }
    }
    It 'test-logic: no archive leak (in custom directory)' {
      if (Test-Path -Path 'TestDrive:/dir/cmake-3.12.4' -PathType Container) {
        Remove-Item 'TestDrive:/dir/cmake-3.12.4/' -Recurse
        $false | Should -Be $true
      } else { $true | Should -Be $true }
    }
  }

  Context 'mock extraction failure' {
    # Suppress output to the Appveyor Message API.
    Mock Assert-CI { return $false } -ModuleName Send-Message
    Mock Invoke-Curl {
      New-Item $OutPath -ItemType File -Force *>$null
    } -ModuleName Install-CMake
    Mock Expand-Archive {
      if (-not (Test-Path $Archive -PathType Leaf)) {
          throw '-Archive does not exist.'
      }
      $internalDir = 'cmake-3.12.4-win64-x64'
      $fullDirPath = Join-Path (Join-Path $InstallDir $internalDir) 'bin'
      New-Item $fullDirPath -ItemType Directory -Force *>$null
      # not cmake.exe
    } -ModuleName Install-CMake
    BeforeEach {
      if (Test-Path -Path './cmake-3.12.4-win64-x64' -PathType Container) {
        Remove-Item './cmake-3.12.4-win64-x64/' -Recurse
      }
    }
    New-Item 'TestDrive:/dir' -ItemType Directory -Force

    It 'throws when cmake.exe not in expected location' {
      { Install-Cmake -Version 3.12.4 -Hash $empty_SHA512 6>$null } |
        Should -Throw 'Failed to find cmake.exe'
    }
    It 'throws when cmake.exe not in custom InstallDir' {
      { Install-Cmake -Version 3.12.4 -Hash $empty_SHA384 `
        -InstallDir 'TestDrive:/dir' 6>$null
      } | Should -Throw 'Failed to find cmake.exe'
    }
  }
}

Describe 'Install-CMake (online)' {
  Context 'mocked File operations' {
    # Suppress output to the Appveyor Message API.
    Mock Assert-CI { return $false } -ModuleName Send-Message
    Mock Invoke-Curl {
      New-Item $OutPath -ItemType File -Force *>$null
    } -ModuleName Install-CMake `
      -ParameterFilter { $OutPath -and -not $OutPath.endswith('.txt') }
    Mock Expand-Archive {
      if (-not (Test-Path $Archive -PathType Leaf)) {
          throw '-Archive does not exist.'
      }
      $internalDir = 'cmake-3.12.4-win64-x64'
      $fullDirPath = Join-Path (Join-Path $InstallDir $internalDir) 'bin'
      New-Item $fullDirPath -ItemType Directory -Force 1>$null
      New-Item (Join-Path $fullDirPath 'cmake.exe') -ItemType File -Force `
      1>$null
    } -ModuleName Install-CMake
    BeforeEach {
      $location = Join-Path "$install_dir" 'cmake-3.12.4-win64-x64'
      if (Test-Path -Path './cmake-3.12.4-win64-x64' -PathType Container) {
        Remove-Item './cmake-3.12.4-win64-x64/' -Recurse
      } elseif (Test-Path -Path "$location" -PathType Container) {
        Remove-Item "$location" -Recurse
      }
    }
    $install_dir = New-Item 'TestDrive:/XInstall' -ItemType Directory -Force

    It 'Wrong file-hash' {
      { Install-CMake -Version 3.12.4 -Quiet 6>$null } |
        Should -Throw 'download hash changed!'
      Assert-MockCalled Invoke-Curl -ModuleName Install-CMake -Scope It `
        -Times 1 -Exactly
      Assert-MockCalled Expand-Archive -ModuleName Install-CMake -Scope It `
        -Times 0 -Exactly
    }
  }
  Context 'AddToPath' {
    $old_Path = $env:Path
    It 'Install CMake v3.12.4' {
      { Install-CMake -Version '3.12.4' -InstallDir "$env:TEMP" -AddToPath } |
        Should -not -Throw
      $env:Path -match ('^'+ $env:TEMP -replace '\\','\\') | Should -Be $true
    }
    It 'still in path' {
      $env:Path -match ('^'+ $env:TEMP -replace '\\','\\') | Should -Be $true
    }
    $env:Path = $old_Path
  }
  Context 'Installer' {
    It 'Install CMake v3.16.0' {
      if ((Assert-Windows) -and -not (Assert-Admin)) {
        Set-ItResult -Inconclusive -Because 'Requires administrative privileges'
      }
      { Install-CMake -Version '3.16.0' -Installer } | Should -not -Throw
    }
  }

}

