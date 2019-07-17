Import-Module -Name "${PSScriptRoot}\Install-Ninja.psd1" -Force

Set-StrictMode -Version Latest

##====--------------------------------------------------------------------====##
$global:msg_documentation = 'at least 1 empty line above documentation'

##====--------------------------------------------------------------------====##
Describe 'Install-Ninja' {
  # Suppress output to the Appveyor Message API.
  Mock Assert-CI { return $false } -ModuleName Send-Message

  It 'has documentation' {
    Get-Help Install-Ninja | Out-String |
      Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
  }
  It 'supports -WhatIf and -Confirm' {
    Get-Command -Name Install-Ninja -Syntax |
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
    It 'throws on missing -Tag' {
      { Install-Ninja } | Should -Throw 'Tag is a required parameter'
    }
    It 'throws on empty -Tag' {
      { Install-Ninja -Tag } | Should -Throw 'missing an argument'
    }
    It 'throws on empty string -Tag' {
      { Install-Ninja -Tag '' } | Should -Throw 'argument is null or empty'
    }
    It 'throws on $null -Tag' {
      { Install-Ninja -Tag $null } | Should -Throw 'argument is null or empty'
    }
    It 'throws on empty -Hash' {
      { Install-Ninja -Tag 'v1.8.2' -Hash } |
        Should -Throw 'missing an argument'
      { Install-Ninja -Tag 'v1.8.2' -SHA256 } |
        Should -Throw 'missing an argument' `
        -Because '-SHA256 is an alias of -Hash'
      { Install-Ninja -Tag 'v1.8.2' -SHA512 } |
        Should -Throw 'missing an argument' `
        -Because '-SHA512 is an alias of -Hash'
    }
    It 'throws on empty string -Hash' {
      { Install-Ninja -Tag 'v1.8.2' -Hash '' } |
        Should -Throw 'argument is null or empty'
    }
    It 'throws on $null -Hash' {
      { Install-Ninja -Tag 'v1.8.2' -Hash $null } |
        Should -Throw 'argument is null or empty'
    }
    It 'throws when -Hash length is not 36, 40, 64, 96 or 128 characters' {
      { Install-Ninja -Tag 'v1.8.2' -SHA512 '123456789' 1>$null 6>$null } |
        Should -Throw 'Unsupported hash type'
    }
    It 'throws on use of both -SHA512 and -SHA256' {
      { Install-Ninja -Tag 'v1.8.2' -SHA256 `
        'EE94E44F83E04C32D7F301155708B0D513AA783AC8C0C953DC0C70EC3334FED1' `
        -SHA512 `
        '0000E248240665FCD6404B989F3B3C27ED9682838225E6DC9B67B551774F251E4FF8A207504F941E7C811E7A8BE1945E7BCB94472A335EF15E23A0200A32E6D5'
      } | Should -Throw 'specified more than once'
    }
    It 'throws on empty -InstallDir' {
      { Install-Ninja -Tag 'v1.8.2' -InstallDir } |
        Should -Throw 'missing an argument'
    }
    It 'throws on empty string -InstallDir' {
      { Install-Ninja -Tag 'v1.8.2' -InstallDir '' } |
        Should -Throw 'argument is null or empty'
    }
    It 'throws on $null -InstallDir' {
      { Install-Ninja -Tag 'v1.8.2' -InstallDir $null } |
        Should -Throw 'argument is null or empty'
    }
    It 'throws on non-existing directory -InstallDir' {
      { Install-Ninja -Tag 'v1.8.2' -InstallDir 'TestDrive:\nonExistingDir' } |
        Should -Throw 'validation script'
    }
    It 'throws when -InstallDir points to a file' {
      New-Item -Path TestDrive:\ -Name file.txt
      { Install-Ninja -Tag 'v1.8.2' -InstallDir 'TestDrive:\file.txt' } |
        Should -Throw 'validation script'
    }
  }

  Context 'WhatIf' {
    New-Item 'TestDrive:\dir' -ItemType Directory -Force
    $start_path = $PWD
    $original_path = $env:path

    Context 'Clean system' {
      It 'before: no archive present' {
        $Temporary = Join-Path $env:TEMP 'ninja-v1.8.2'
        Test-Path -LiteralPath "$(Join-Path $Temporary 'ninja-win.zip')" |
          Should -Be $false
        Test-Path -LiteralPath "$Temporary" | Should -Be $false
      }
      It 'before: no executable present' {
        Test-Path -LiteralPath 'TestDrive:\dir\ninja-v1.8.2\ninja.exe' |
          Should -Be $false
      }
       It 'Call with -WhatIf' {
         { Install-Ninja -Tag 'v1.8.2' -InstallDir 'TestDrive:\dir' `
           -SHA512 CF83E1357EEFB8BDF1542850D66D8007D620E4050B5715DC83F4A921D36CE9CE47D0D13C5D85F2B0FF8318D2877EEC2F63B931BD47417A81A538327AF927DA3E `
           -WhatIf 6>$null } | Should -not -Throw
         Install-Ninja -Tag 'v1.8.2' -InstallDir 'TestDrive:\dir' -Hash `
           CF83E1357EEFB8BDF1542850D66D8007D620E4050B5715DC83F4A921D36CE9CE47D0D13C5D85F2B0FF8318D2877EEC2F63B931BD47417A81A538327AF927DA3E `
           -WhatIf | Should -Be $null
       }
       It 'after: no archive present' {
         $Temporary = Join-Path $env:TEMP 'ninja-v1.8.2'
         Test-Path -LiteralPath "$(Join-Path $Temporary 'ninja-win.zip')" |
           Should -Be $false
         Test-Path -LiteralPath "$Temporary" | Should -Be $false
       }
       It 'after: no executable present' {
         Test-Path -LiteralPath 'TestDrive:\dir\ninja-v1.8.2\ninja.exe' |
           Should -Be $false
       }
       It 'no change in current working directory' {
         $PWD.Path | Should -Be $start_path.Path
       }
       if ($PWD -ne $start_path) { cd $start_path }
    }
    Context 'AddToPath' {
      It 'Call with -WhatIf and -AddToPath' {
        $Temporary = Join-Path $env:TEMP 'ninja-v1.8.2'
        if (Test-Path -LiteralPath 'TestDrive:\dir\ninja-v1.8.2\ninja.exe') {
          Set-ItResult -Inconclusive -Because 'ninja.exe is already present'
        } elseif (
          Test-Path -LiteralPath "$(Join-Path $Temporary 'ninja-win.zip')"
        ) {
          Set-ItResult -Inconclusive -Because 'archive present'
        } elseif ( Test-Path -LiteralPath "$Temporary" ) {
          Set-ItResult -Inconclusive -Because 'download directory present'
        }
        { Install-Ninja -Tag 'v1.8.2' -InstallDir 'TestDrive:\dir' -Hash `
          CF83E1357EEFB8BDF1542850D66D8007D620E4050B5715DC83F4A921D36CE9CE47D0D13C5D85F2B0FF8318D2877EEC2F63B931BD47417A81A538327AF927DA3E `
          -WhatIf -AddToPath 6>$null } | Should -not -Throw
        Install-Ninja -Tag 'v1.8.2' -InstallDir 'TestDrive:\dir' -Hash `
          CF83E1357EEFB8BDF1542850D66D8007D620E4050B5715DC83F4A921D36CE9CE47D0D13C5D85F2B0FF8318D2877EEC2F63B931BD47417A81A538327AF927DA3E `
          -WhatIf -AddToPath | Should -Be $null
      }
      It 'after: no archive present' {
        $Temporary = Join-Path $env:TEMP 'ninja-v1.8.2'
        Test-Path -LiteralPath "$(Join-Path $Temporary 'ninja-win.zip')" |
          Should -Be $false
        Test-Path -LiteralPath "$Temporary" | Should -Be $false
      }
      It 'after: no executable present' {
        Test-Path -LiteralPath 'TestDrive:\dir\ninja-v1.8.2\ninja.exe' |
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

  Context 'mock download failure' {
    Mock Invoke-Curl {
      return 'curl: (1) some error'
    } -ModuleName Install-Ninja

    It 'start: no archive present' {
      $Temporary = Join-Path $env:TEMP 'ninja-v1.8.2'
      Test-Path -LiteralPath "$(Join-Path $Temporary 'ninja-win.zip')" |
        Should -Be $false
      Test-Path -LiteralPath "$Temporary" | Should -Be $false
    }
    It 'failing' {
      { Install-Ninja -Tag 'v1.8.2' -InstallDir 'TestDrive:\' -Quiet `
        3>$null 6>$null
      } | Should -Throw 'Download failed'
      Assert-MockCalled Invoke-Curl -ModuleName Install-Ninja
    }
  }

  Context 'mock already installed' {
    ($Path, $Temporary) = Join-Path ('TestDrive:\', $env:TEMP) 'ninja-v1.8.2'
    New-Item $Temporary -Name 'ninja-win.zip' -Force
    New-Item $Path -ItemType Directory -Force
    New-Item $Path -Name 'ninja.exe' -Force
    Mock Invoke-Curl -ModuleName Install-Ninja
    Mock Expand-Archive -ModuleName Install-Ninja

    It 'return path to ninja.exe' {
      { Install-Ninja -Tag 'v1.8.2' -InstallDir 'TestDrive:\' `
        3>$null 6>$null
      } | Should -not -Throw
      (Install-Ninja -Tag 'v1.8.2' -InstallDir 'TestDrive:\' `
        3>$null 6>$null)[1] | Should -Match '.*ninja-v1.8.2[\\\/]ninja.exe'
      Assert-MockCalled Invoke-Curl -ModuleName Install-Ninja -Times 0 `
        -Exactly
      Assert-MockCalled Expand-Archive -ModuleName Install-Ninja -Times 0 `
        -Exactly
    }
    It 'removed archive after install' {
      Test-Path $Temporary -PathType Container | Should -Be $false
      Test-Path $Path -PathType Container | Should -Be $true
      Test-Path ($Path + '\ninja.exe') -PathType Leaf | Should -Be $true
    }
    New-Item $Temporary -Name 'ninja-win.zip' -Force
    It 'Verbose' {
      (Install-Ninja -Tag 'v1.8.2' -InstallDir 'TestDrive:\' -Verbose `
        3>$null 6>$null 1>$null) 4>&1 |
        Should -Match 'Skip download and extraction'
      Assert-MockCalled Invoke-Curl -ModuleName Install-Ninja -Times 0 `
        -Exactly -Scope It
      Assert-MockCalled Expand-Archive -ModuleName Install-Ninja -Times 0 `
        -Exactly -Scope It
    }
    It 'WhatIf' {
      { Install-Ninja -Tag 'v1.8.2' -InstallDir 'TestDrive:\' -WhatIf `
        -Hash E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855 `
        3>$null 6>$null
      } | Should -not -Throw
      Assert-MockCalled Invoke-Curl -ModuleName Install-Ninja -Times 0 `
        -Exactly -Scope It
      Assert-MockCalled Expand-Archive -ModuleName Install-Ninja -Times 0 `
        -Exactly -Scope It
    }
    It 'Force' {
      New-Item $Temporary -Name 'ninja-win.zip' -Force
      { Install-Ninja -Tag 'v1.8.2' -InstallDir 'TestDrive:\' -Force `
        -Hash E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855 `
        3>$null 6>$null
      } | Should -not -Throw
      New-Item $Temporary -Name 'ninja-win.zip' -Force
      ( Install-Ninja -Tag 'v1.8.2' -InstallDir 'TestDrive:\' -Force `
        -Hash E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855 `
        1>$null 6>$null ) 3>&1 | Should -match 'Overwriting existing files'
      New-Item $Temporary -Name 'ninja-win.zip' -Force
      Install-Ninja -Tag 'v1.8.2' -InstallDir 'TestDrive:\' -Force `
        -Hash E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855 `
        3>$null 6>$null | Should -match '.*ninja-v1.8.2[\\\/]ninja.exe'
      Assert-MockCalled Invoke-Curl -ModuleName Install-Ninja -Times 0 `
        -Exactly -Scope It
      Assert-MockCalled Expand-Archive -ModuleName Install-Ninja -Times 3 `
        -Exactly -Scope It
    }
  }

  Context 'mock archive exists' {
    $Temporary = Join-Path $env:TEMP 'ninja-v1.8.2'
    New-Item -Path $Temporary -Name 'ninja-win.zip' -Force 1>$null
    Mock Invoke-Curl -ModuleName Install-Ninja
    Mock Expand-Archive {
      New-Item 'TestDrive:\ninja-v1.8.2' -ItemType Directory -Force
      New-Item 'TestDrive:\ninja-v1.8.2\ninja.exe' -Force
    } -ModuleName Install-Ninja

    It 'use existing archive' {
      { Install-Ninja -Tag 'v1.8.2' -InstallDir 'TestDrive:\' `
        3>$null 6>$null
      } | Should -not -Throw
      Assert-MockCalled Invoke-Curl -ModuleName Install-Ninja -Times 0 `
        -Exactly
      Assert-MockCalled Expand-Archive -ModuleName Install-Ninja -Times 1 `
        -Exactly
    }
    It 'removed archive after install' {
      Test-Path $Temporary -PathType Container | Should -Be $false
    }
    It 'use existing archive (SHA512)' {
      New-Item -Path $Temporary -Name 'ninja-win.zip' -Force 1>$null
      { Install-Ninja -Tag 'v1.8.2' -InstallDir 'TestDrive:\' `
        -Hash CF83E1357EEFB8BDF1542850D66D8007D620E4050B5715DC83F4A921D36CE9CE47D0D13C5D85F2B0FF8318D2877EEC2F63B931BD47417A81A538327AF927DA3E `
        6>$null
      } | Should -not -Throw
    }
    It 'use existing archive (SHA256)' {
      New-Item -Path $Temporary -Name 'ninja-win.zip' -Force 1>$null
      { Install-Ninja -Tag 'v1.8.2' -InstallDir 'TestDrive:\' `
        -Hash E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855 `
        6>$null
      } | Should -not -Throw
    }
    It 'use existing archive (SHA384)' {
      New-Item -Path $Temporary -Name 'ninja-win.zip' -Force 1>$null
      { Install-Ninja -Tag 'v1.8.2' -InstallDir 'TestDrive:\' `
        -Hash 72B9E9D279B86EFAE28CF0B960157179BB9A2F641842797F8DB468909B03186C542446BAF7414ACCEA367E6A233E7FFF `
        6>$null
      } | Should -not -Throw
    }
    It 'use existing archive (SHA1)' {
      New-Item -Path $Temporary -Name 'ninja-win.zip' -Force 1>$null
      { Install-Ninja -Tag 'v1.8.2' -InstallDir 'TestDrive:\' `
        -Hash C68F192E85A12927443BBF535D27B4AA830E7B32 6>$null
      } | Should -not -Throw
    }
    It 'use existing archive (MD5)' {
      New-Item -Path $Temporary -Name 'ninja-win.zip' -Force 1>$null
      { Install-Ninja -Tag 'v1.8.2' -InstallDir 'TestDrive:\' `
        -Hash 14764496D99BB5EA99E761DAB9A38BC4 6>$null
      } | Should -not -Throw
    }
  }

  Context 'mock download' {
    New-Item 'TestDrive:\' -Name 'dir' -ItemType Directory -Force
    $Temporary = Join-Path $env:TEMP 'ninja-v1.8.2'
    Mock Invoke-Curl {
      New-Item -Path $Temporary -Name 'ninja-win.zip' -Force 1>$null
    } -ModuleName Install-Ninja
    Mock Expand-Archive -ModuleName Install-Ninja

    It 'start: no archive present' {
      Test-Path -LiteralPath "$(Join-Path $Temporary 'ninja-win.zip')" |
        Should -Be $false
      Test-Path -LiteralPath "$Temporary" | Should -Be $false
    }
    It 'start: no executable present' {
      Test-Path -LiteralPath 'TestDrive:\dir\ninja-v1.8.2\ninja.exe' |
        Should -Be $false
    }


    It 'throw final check (no hash)' {
      { Install-Ninja -Tag 'v1.8.2' -InstallDir 'TestDrive:\dir' -Quiet `
        3>$null 6>$null
      } | Should -Throw 'Failed to find ninja.exe in expected location.'
    }
    Assert-MockCalled Invoke-Curl -ModuleName Install-Ninja
    Assert-MockCalled Expand-Archive -ModuleName Install-Ninja
    It 'throw final check (SHA512)' {
      { Install-Ninja -Tag 'v1.8.2' -InstallDir 'TestDrive:\dir' `
        -SHA512 CF83E1357EEFB8BDF1542850D66D8007D620E4050B5715DC83F4A921D36CE9CE47D0D13C5D85F2B0FF8318D2877EEC2F63B931BD47417A81A538327AF927DA3E `
        6>$null
      } | Should -Throw 'Failed to find ninja.exe in expected location.'
    }
    It 'throw final check (SHA256)' {
      { Install-Ninja -Tag 'v1.8.2' -InstallDir 'TestDrive:\dir' `
        -SHA256 E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855 `
        6>$null
      } | Should -Throw 'Failed to find ninja.exe in expected location.'
    }

    Context 'mock download and extraction' {
      Mock Expand-Archive {
        $installpath = 'TestDrive:\dir\ninja-v1.8.2'
        New-Item $installpath -ItemType Directory -Force 1>$null
        New-Item (Join-Path $installpath 'ninja.exe') -Force 1>$null
      } -ModuleName Install-Ninja
      AfterEach {
        $installpath = 'TestDrive:\dir\ninja-v1.8.2'
        if (Test-Path $installpath -PathType Container) {
          Remove-Item $installpath -Recurse
        }
      }

      It 'success (no hash)' {
        { Install-Ninja -Tag 'v1.8.2' -InstallDir 'TestDrive:\dir' -Quiet `
          3>$null 6>$null
        } | Should -not -Throw
        Assert-MockCalled Invoke-Curl -ModuleName Install-Ninja -Times 1 `
          -Exactly -Scope It
        Assert-MockCalled Expand-Archive -ModuleName Install-Ninja -Times 1 `
          -Exactly -Scope It
      }
      It 'success (SHA512)' {
        { Install-Ninja -Tag 'v1.8.2' -InstallDir 'TestDrive:\dir' `
          -SHA512 CF83E1357EEFB8BDF1542850D66D8007D620E4050B5715DC83F4A921D36CE9CE47D0D13C5D85F2B0FF8318D2877EEC2F63B931BD47417A81A538327AF927DA3E `
          6>$null
        } | Should -not -Throw
        Assert-MockCalled Invoke-Curl -ModuleName Install-Ninja -Times 1 `
          -Exactly -Scope It
        Assert-MockCalled Expand-Archive -ModuleName Install-Ninja -Times 1 `
          -Exactly -Scope It
      }
      It 'success (SHA256)' {
        { Install-Ninja -Tag 'v1.8.2' -InstallDir 'TestDrive:\dir' `
          -SHA256 E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855 `
          6>$null
        } | Should -not -Throw
      }
      It 'success return type' {
        Install-Ninja -Tag 'v1.8.2' -InstallDir 'TestDrive:\dir' `
          -SHA512 CF83E1357EEFB8BDF1542850D66D8007D620E4050B5715DC83F4A921D36CE9CE47D0D13C5D85F2B0FF8318D2877EEC2F63B931BD47417A81A538327AF927DA3E `
          6>$null | Should -BeOfType System.Management.Automation.PathInfo
      }
      It 'success return path' {
        Install-Ninja -Tag 'v1.8.2' -InstallDir 'TestDrive:\dir' `
          -SHA512 CF83E1357EEFB8BDF1542850D66D8007D620E4050B5715DC83F4A921D36CE9CE47D0D13C5D85F2B0FF8318D2877EEC2F63B931BD47417A81A538327AF927DA3E `
          6>$null | Should -Be 'TestDrive:\dir\ninja-v1.8.2\ninja.exe'
      }
      It 'wrong/ changed hash (SHA512)' {
        { Install-Ninja -Tag 'v1.8.2' -InstallDir 'TestDrive:\dir' `
          -SHA512 0000E248240665FCD6404B989F3B3C27ED9682838225E6DC9B67B551774F251E4FF8A207504F941E7C811E7A8BE1945E7BCB94472A335EF15E23A0200A32E6D5 `
          6>$null
        } | Should -Throw 'download hash changed'
        Assert-MockCalled Invoke-Curl -ModuleName Install-Ninja -Times 1 `
          -Exactly -Scope It
        Assert-MockCalled Expand-Archive -ModuleName Install-Ninja -Times 0 `
          -Exactly -Scope It
      }
      It 'wrong/ changed hash (SHA256)' {
        { Install-Ninja -Tag 'v1.8.2' -InstallDir 'TestDrive:\dir' `
          -SHA256 4FF8A207504F941E7C811E7A8BE1945E7BCB94472A335EF15E23A0200A32E6D5 `
          6>$null
        } | Should -Throw 'download hash changed'
        Assert-MockCalled Invoke-Curl -ModuleName Install-Ninja -Times 1 `
          -Exactly -Scope It
        Assert-MockCalled Expand-Archive -ModuleName Install-Ninja -Times 0 `
          -Exactly -Scope It
      }
      It 'no archive remaining' {
        Test-Path -LiteralPath "$(Join-Path $Temporary 'ninja-win.zip')" |
          Should -Be $false
        Test-Path -LiteralPath "$Temporary" | Should -Be $false
      }
    }
  }
}

##====--------------------------------------------------------------------====##
Describe 'Install-Ninja (online)' -Tag 'online' {
  # Suppress output to the Appveyor Message API.
  Mock Assert-CI { return $false } -ModuleName Send-Message

  Context 'install ninja' {
    $start_path = $PWD
    $Temporary = Join-Path $env:TEMP 'ninja-v1.8.2'
    $test_drive = (Resolve-Path 'TestDrive:').ProviderPath

    It 'Invalid tag = invalid url' {
      { Install-Ninja -Tag 'v1.X' -InstallDir $test_drive 3>$null 6>$null `
      } | Should -Throw 'Download failed'
      Assert-MockCalled Assert-CI -ModuleName Send-Message -Times 3 -Exactly `
        -Scope It
    }
    It 'wrong/ changed hash (SHA512)' {
      { Install-Ninja -Tag 'v1.8.2' -InstallDir $test_drive -SHA512 `
        'XB9CE248240665FCD6404B989F3B3C27ED9682838225E6DC9B67B551774F251E4FF8A207504F941E7C811E7A8BE1945E7BCB94472A335EF15E23A0200A32E6D5' `
        6>$null
      } | Should -Throw 'download hash changed'
    }
    It 'wrong/ changed hash (SHA384)' {
      { Install-Ninja -Tag 'v1.8.2' -InstallDir $test_drive -Hash `
        'X802130CDAB6055D88A8A2A67D854F68D21E1A0223150A1B6FF0B6FED4A4A77C62C90E0BC8A6925268D50DF12C8DEFF6' `
        6>$null
      } | Should -Throw 'download hash changed'
    }
    It 'wrong/ changed hash (SHA256)' {
      { Install-Ninja -Tag 'v1.8.2' -InstallDir $test_drive -Hash `
        'X80313E6C26C0B9E0C241504718E2D8BBC2798B73429933ADF03FDC6D84F0E70' `
        6>$null
      } | Should -Throw 'download hash changed'
    }
    It 'wrong/ changed hash (SHA1)' {
      { Install-Ninja -Tag 'v1.8.2' -InstallDir $test_drive -Hash `
        'X37CC6E144F5CC7C6388A30F3C32AD81B2E0442E' 6>$null
      } | Should -Throw 'download hash changed'
    }
    It 'wrong/ changed hash (MD5)' {
      { Install-Ninja -Tag 'v1.8.2' -InstallDir $test_drive -Hash `
        'XAC14A8126E9E3716700EFD274F4EFC7' 6>$null
        6>$null
      } | Should -Throw 'download hash changed'
    }
    It 'no archive remaining' {
      Test-Path -LiteralPath "$(Join-Path $Temporary 'ninja-win.zip')" |
        Should -Be $false
      Test-Path -LiteralPath "$Temporary" | Should -Be $false
    }
    It 'no change in current working directory' {
      $PWD.Path | Should -Be $start_path.Path
    }
    if ($PWD -ne $start_path) { cd $start_path }
  }

  $original_path = $env:Path
  Context 'add to Path' {
    $start_path = $PWD
    $Temporary = Join-Path $env:TEMP 'ninja-v1.8.2'
    $InstallDir = (Resolve-Path 'TestDrive:\').ProviderPath

    It 'call with -AddToPath' {
      { Install-Ninja -Tag 'v1.8.2' -InstallDir "$InstallDir" -SHA512 `
        '9B9CE248240665FCD6404B989F3B3C27ED9682838225E6DC9B67B551774F251E4FF8A207504F941E7C811E7A8BE1945E7BCB94472A335EF15E23A0200A32E6D5' `
        -AddToPath 3>$null 6>$null
      } | Should -not -Throw
    }
    It 'Warning when ninja available on path' {
      ( Install-Ninja -Tag 'v1.8.2' -InstallDir "$InstallDir" -SHA512 `
        '9B9CE248240665FCD6404B989F3B3C27ED9682838225E6DC9B67B551774F251E4FF8A207504F941E7C811E7A8BE1945E7BCB94472A335EF15E23A0200A32E6D5' `
        -AddToPath 6>$null 1>$null ) 3>&1 |
        Should -Match 'Suppressing existing Ninja install. Version: .*'
    }
    It 'added to the search path' {
      $env:Path | Should -Match ($InstallDir -replace '\\','\\')
    }
    It 'executable is present in expected location' {
      Test-Path -LiteralPath ($InstallDir + 'ninja-v1.8.2\ninja.exe') |
        Should -Be $true
    }
    It 'no archive remaining' {
      Test-Path -LiteralPath "$(Join-Path $Temporary 'ninja-win.zip')" |
        Should -Be $false
      Test-Path -LiteralPath "$Temporary" | Should -Be $false
    }
    It 'no change in current working directory' {
      $PWD.Path | Should -Be $start_path.Path
    }
    if ($PWD -ne $start_path) { cd $start_path }
    Context 'path failure' {
      Mock Test-Command { return $false } -ModuleName Install-Ninja

      It 'throw path info' {
        { Install-Ninja -Tag 'v1.8.2' -InstallDir "$InstallDir" `
          -AddToPath 3>$null 6>$null
      } | Should -Throw 'Failed to find Ninja on the search path.'
      }
    }
  }
  $env:Path = $original_path

  Context 'Overwrite with -Force' {
    ($Path, $Temporary) = Join-Path ('TestDrive:\', $env:TEMP) 'ninja-v1.8.2'
    $InstallDir = (Resolve-Path 'TestDrive:\').ProviderPath
    New-Item $Temporary -Name 'ninja-win.zip' -Force
    New-Item $Path -ItemType Directory -Force
    New-Item $Path -Name 'ninja.exe' -Force
    $zip_hash = (
      Get-FileHash (Join-Path $Temporary 'ninja-win.zip') -Algorithm SHA512
    ).Hash
    $exe_hash = (
      Get-FileHash (Join-Path $Path 'ninja.exe') -Algorithm SHA512
    ).Hash

    It 'run with -Force' {
      $valid_hash = '9B9CE248240665FCD6404B989F3B3C27ED9682838225E6DC9B67B551774F251E4FF8A207504F941E7C811E7A8BE1945E7BCB94472A335EF15E23A0200A32E6D5'
      $zip_hash | Should -not -Be $valid_hash
      { Install-Ninja -Tag v1.8.2 -InstallDir "$InstallDir" -Hash $valid_hash `
        -Force 3>$null 6>$null
      } | Should -not -Throw
    }
    It 'executable was replaced' {
      (Get-FileHash (Join-Path $Path 'ninja.exe') -Algorithm SHA512).Hash |
        Should -not -Be $exe_hash
    }
  }
}
##====--------------------------------------------------------------------====##
