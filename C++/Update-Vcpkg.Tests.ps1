Import-Module -Name "${PSScriptRoot}\Update-Vcpkg.psd1" -Force

Set-StrictMode -Version Latest

##====--------------------------------------------------------------------====##
$global:msg_documentation = 'at least 1 empty line above documentation'

if (Assert-CI) {
  # Prevent warnings on AppVeyor.
  git config --global user.name "BuildServer"
  git config --global user.email "farwaykorse@example.com"
}

##====--------------------------------------------------------------------====##
Describe 'Internal Select-VcpkgLocation' {
  InModuleScope Update-Vcpkg {
    It 'has documentation' {
      Get-Help Select-VcpkgLocation | Out-String |
        Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
    }
    It 'supports -WhatIf and -Confirm' {
      Get-Command -Name Select-VcpkgLocation -Syntax |
        Should -Match '-WhatIf.*-Confirm'
    }

    Context 'find from executable' {
      Mock Assert-CI { return $true } -ModuleName Update-Vcpkg
      Mock Test-Path { return $true } -ModuleName Update-Vcpkg
      $original_CI_WINDOWS = $env:CI_WINDOWS
      if ($env:CI_WINDOWS -ne 'true') {
        $env:CI_WINDOWS = $true
      }
      It 'default location (Windows)' {
        { Select-VcpkgLocation } | Should -not -Throw
        Select-VcpkgLocation | Should -Be 'C:\Tools\vcpkg'
      }
      $env:CI_WINDOWS = $original_CI_WINDOWS
    }
    Context 'find from executable' {
      Mock Assert-CI { return $false } -ModuleName Update-Vcpkg

      It 'find vcpkg' {
        if (-not (Test-Command 'vcpkg version')) {
          Set-ItResult -Skipped -Because 'vcpkg not on path'
        }
        { Select-VcpkgLocation } | Should -not -Throw
        $Location = Select-VcpkgLocation
        Test-Path $Location -PathType Container | Should -Be $true
        ( (Test-Path (Join-Path $Location 'vcpkg.exe') -PathType Leaf) -or
          (Test-Path (Join-Path $Location 'vcpkg') -PathType Leaf)
        ) | Should -Be $true
        In $Location {
          Test-Command 'git status' | Should -Be $true `
            -Because 'expect a git working directory'
        }
      }

    }
    Context 'fallback location' {
      Mock Assert-CI { return $false } -ModuleName Update-Vcpkg
      Mock Test-Command { return $false } -ModuleName Update-Vcpkg
      $tools_dir = Join-Path $HOME 'Tools'
      $expected = Join-Path $tools_dir 'vcpkg'
      if (-not (Test-Path -Path (Join-Path $expected '*')) ) {
        $empty = $true
        if (Test-Path -Path $expected) { Remove-Item $expected }
        if ( (Test-Path -Path $tools_dir -PathType Container) -and
          -not (Test-Path -Path (Join-Path $tools_dir '*'))
        ) {
          Remove-Item $tools_dir
        }
      } else {
        $empty = $false
      }
      It 'WhatIf' {
        { Select-VcpkgLocation -WhatIf } | Should -not -Throw
        Select-VcpkgLocation -WhatIf | Should -Be $expected
        if ($empty) {
          Test-Path -Path $expected -PathType Container | Should -Be $false
        }
      }
      It 'create directory' {
        { Select-VcpkgLocation } | Should -not -Throw
        Select-VcpkgLocation | Should -Be $expected
        Test-Path -Path $tools_dir -PathType Container | Should -Be $true
        Test-Path -Path $expected -PathType Container | Should -Be $true
      }
      if ($empty) {
        if (Test-Path -Path $expected) { Remove-Item $expected }
        if ( (Test-Path -Path $tools_dir -PathType Container) -and
          -not (Test-Path -Path (Join-Path $tools_dir '*'))
        ) {
          Remove-Item $tools_dir
        }
      }
    }
  }
}

##====--------------------------------------------------------------------====##
Describe 'Internal Test-IfReleaseWithIssue' {
  InModuleScope Update-Vcpkg {
    # Suppress output to the Appveyor Message API.
    Mock Assert-CI { return $false } -ModuleName Send-Message

    It 'has documentation' {
      Get-Help Test-IfReleaseWithIssue | Out-String |
        Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
    }
    It 'no support for -WhatIf and -Confirm' {
      Get-Command -Name Test-IfReleaseWithIssue -Syntax |
        Should -not -Match '-WhatIf.*-Confirm'
    }

    Context 'mock calling vcpkg' {
      In -Path 'TestDrive:\' {
        '"version 2019.02.11"' > vcpkg.ps1
        It 'no throw' {
          { Test-IfReleaseWithIssue } | Should -not -Throw
          Assert-MockCalled Assert-CI -ModuleName Send-Message -Times 0 `
            -Exactly -Scope It
        }
        ( 'Write-Output "Vcpkg package management program version ' +
          '2019.06.26-nohash' + '`n`nSee LICENSE.txt for license information."'
        ) > vcpkg.ps1
        It 'no issue' {
          { Test-IfReleaseWithIssue } | Should -not -Throw
          Test-IfReleaseWithIssue | Should -Be $false
          Assert-MockCalled Assert-CI -ModuleName Send-Message -Times 0 `
            -Exactly -Scope It
        }
        ( 'Write-Output "Vcpkg package management program version ' +
          '0.0.113' + '`n`nSee LICENSE.txt for license information."'
        ) > vcpkg.ps1
        It 'version 0.0.113' {
          { Test-IfReleaseWithIssue 3>$null } | Should -not -Throw
          Test-IfReleaseWithIssue 3>$null | Should -Be $true
          Assert-MockCalled Assert-CI -ModuleName Send-Message -Times 2 `
            -Exactly -Scope It
        }
        ( 'Write-Output "Vcpkg package management program version ' +
          '2018.11.23-nohash' + '`n`nSee LICENSE.txt for license information."'
        ) > vcpkg.ps1
        It 'version 2018.11.23-nohash' {
          Test-IfReleaseWithIssue 3>$null | Should -Be $true
          Assert-MockCalled Assert-CI -ModuleName Send-Message -Times 1 `
            -Exactly -Scope It
        }
        It 'warning output' {
          (Test-IfReleaseWithIssue 1>$null) 3>&1 |
            Should -Match 'This vcpkg release has known issues. Rebuilding'
        }
      }
    }
  }
}

##====--------------------------------------------------------------------====##
Describe 'Internal Test-ChangedVcpkgSource' {
  InModuleScope Update-Vcpkg {
    # Suppress output to the Appveyor Message API.
    Mock Assert-CI { return $false } -ModuleName Send-Message

    It 'has documentation' {
      Get-Help Test-ChangedVcpkgSource | Out-String |
        Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
      Get-Help Test-ChangedVcpkgSource -Full | Out-String |
        Should -MatchExactly 'OUTPUTS' -Because $msg_documentation
    }
    It 'supports -WhatIf and -Confirm' {
      Get-Command -Name Test-ChangedVcpkgSource -Syntax |
        Should -Match '-WhatIf.*-Confirm'
    }

    Context 'WhatIf' {
      $hash_file = Join-Path $PSScriptRoot 'vcpkg_source.hash'
      New-Item 'TestDrive:\' -Name 'dir1' -ItemType Directory

      In -Path 'TestDrive:\dir1' {
        It 'not in a git working directory' {
          { Test-ChangedVcpkgSource -WhatIf } | Should -not -Throw
          Test-ChangedVcpkgSource -WhatIf | Should -Be $true
        }
      }
      In -Path 'TestDrive:\dir1' {
        # Set up test environment.
        git init --quiet
        ( 'Write-Output "Vcpkg package management program version ' +
          '2019.06.26-nohash' + '`n`nSee LICENSE.txt for license information."'
        ) > vcpkg.ps1
        New-Item .\toolsrc -ItemType Directory
        'some text' > .\toolsrc\something.cpp
        git add *
        git commit -m 'initial' --quiet
        # no changes: do not create the .hash file.
        It 'WhatIf' {
          if (Test-Path $hash_file -PathType Leaf) { Remove-Item $hash_file }
          { Test-ChangedVcpkgSource -WhatIf 3>$null } | Should -not -Throw
          Assert-MockCalled Assert-CI -ModuleName Send-Message -Times 1 `
            -Exactly -Scope It
        }
        It 'no vcpkg_source.hash file created' {
          Test-Path $hash_file -PathType Leaf | Should -Be $false
        }
        It 'should still return correctly $true or $false' {
          Test-ChangedVcpkgSource -WhatIf 3>$null | Should -Be $true
          # Create the hash-file.
          Test-ChangedVcpkgSource 3>$null
          Test-ChangedVcpkgSource -WhatIf | Should -Be $false
        }
      }
      if (Test-Path $hash_file -PathType Leaf) { Remove-Item $hash_file }
    }

    Context 'Test Run' {
      $hash_file = Join-Path $PSScriptRoot 'vcpkg_source.hash'
      New-Item 'TestDrive:\' -Name 'dir 2' -ItemType Directory

      In -Path 'TestDrive:\dir 2' {
        It 'throws when not in a Git working directory' {
          { Test-ChangedVcpkgSource } |
            Should -Throw 'not a git working directory'
        }
        # Set up test environment.
        git init --quiet
        ( 'Write-Output "Vcpkg package management program version ' +
          '2019.06.26-nohash' + '`n`nSee LICENSE.txt for license information."'
        ) > vcpkg.ps1
        New-Item .\toolsrc -ItemType Directory
        'some text' > .\toolsrc\something.cpp
        git add *
        git commit -m 'initial' --quiet
        # Verify operation.
        It 'no vcpkg_source.hash' {
          Test-Path (Join-Path $PSScriptRoot 'Update-Vcpkg.psm1') `
            -PathType Leaf | Should -Be $true
          if (Test-Path $hash_file -PathType Leaf) { Remove-Item $hash_file }
          Test-Path $hash_file -PathType Leaf | Should -Be $false
        }
        It 'no throw' {
          { Test-ChangedVcpkgSource 3>$null } | Should -not -Throw `
            -Because 'initial commit'
          { Test-ChangedVcpkgSource 3>$null } | Should -not -Throw `
            -Because 'no change'
        }
        Remove-Item $hash_file
        It 'only initial commit displays a warning' {
          (Test-ChangedVcpkgSource 1>$null) 3>&1 |
            Should -Match 'No Cache Found' -Because 'initial commit'
          (Test-ChangedVcpkgSource 1>$null) 3>&1 | Should -Be $null `
            -Because 'no change'
          Assert-MockCalled Assert-CI -ModuleName Send-Message -Times 1 `
            -Exactly -Scope It
        }
        Remove-Item $hash_file
        It 'initial commit returns $true' {
          Test-ChangedVcpkgSource 3>$null | Should -Be $true
        }
        It 'no change returns $false' {
          Test-ChangedVcpkgSource | Should -Be $false -Because 'no change'
        }
        It 'created vcpkg_source.hash, with a SHA1 hash' {
          Test-Path $hash_file -PathType Leaf | Should -Be $true
          Get-Content $hash_file | Should -Match '[0-9A-F]{40}' `
            -Because 'SHA1 hash'
        }
        # Modify test environment.
        'other things' > .\toolsrc\others.cpp
        git add *
        git commit -m 'other things' --quiet
        # Verify operation.
        It 'change to source returns $true' {
          try { Test-ChangedVcpkgSource 3>&1 | Should -Be $true }
          catch { throw $_ | Should -not -Throw }
        }
        # Modify test environment.
        'add more' >> .\toolsrc\others.cpp
        git add *
        git commit --amend -m 'more' --quiet
        # Verify operation.
        It 'no warning after change to source with vcpkg_source.hash present' {
          (Test-ChangedVcpkgSource 1>$null) 3>&1 | Should -Be $null
        }
      }
      Remove-Item $hash_file
    }
    Context '$cache_dir defined' {
      $hash_file = Join-Path $PSScriptRoot 'vcpkg_source.hash'
      $cache_dir = Join-Path 'TestDrive:\' 'cache'

      # Helper function
      function Invoke-Test {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
          'PSUseDeclaredVarsMoreThanAssignment', 'cache_dir')]
        $cache_dir = Join-Path 'TestDrive:\' 'cache'
        Test-ChangedVcpkgSource
      }
      $working_dir = New-Item 'TestDrive:\' -Name 'dir 3' -ItemType Directory

      In -Path $working_dir {
        # Set up test environment.
        git init --quiet
        ( 'Write-Output "Vcpkg package management program version ' +
          '2019.06.26-nohash' + '`n`nSee LICENSE.txt for license information."'
        ) > vcpkg.ps1
        New-Item .\toolsrc -ItemType Directory
        'some text' > .\toolsrc\something.cpp
        git add *
        git commit -m 'initial' --quiet
        It 'initial run - create vcpkg_source.hash' {
          { Invoke-Test 3>$null } | Should -not -Throw
          Test-Path $hash_file -PathType Leaf | Should -Be $true
          Test-Path $cache_dir -PathType Container | Should -Be $false
        }
        It 'use local when $cache_dir not exists' {
          Invoke-Test | Should -Be $false
          Test-Path $hash_file -PathType Leaf | Should -Be $true
          Test-Path $cache_dir -PathType Container | Should -Be $false
        }
        New-Item $cache_dir -ItemType Directory -Force
        It 'move to $cache_dir when both exist' {
          Test-Path $hash_file -PathType Leaf | Should -Be $true
          Invoke-Test | Should -Be $false
          Test-Path $cache_dir -PathType Container | Should -Be $true
          Test-Path $hash_file -PathType Leaf | Should -Be $false
        }
      } # In
    } # Context $cache_dir defined
  } # InModuleScope Update-Vcpkg
} # Describe Internal Test-ChangedVcpkgSource

##====--------------------------------------------------------------------====##
Describe 'Internal Import-CachedVcpkg' {
  # Suppress output to the Appveyor Message API.
  Mock Assert-CI { return $false } -ModuleName Send-Message

  InModuleScope Update-Vcpkg {
    It 'has documentation' {
      Get-Help Import-CachedVcpkg | Out-String |
        Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
      Get-Help Import-CachedVcpkg -Full | Out-String |
        Should -MatchExactly 'OUTPUTS' -Because $msg_documentation
    }
    It 'supports -WhatIf and -Confirm' {
      Get-Command -Name Import-CachedVcpkg -Syntax |
        Should -Match '-WhatIf.*-Confirm'
    }

    It '$cached_dir or $Location not defined' {
      Mock Assert-CI { return $true } -ModuleName 'Update-Vcpkg'

      { Import-CachedVcpkg 2>$null } | Should -Throw
      [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseDeclaredVarsMoreThanAssignment', 'cache_dir')]
      $cached_dir = 'TestDrive:\'
      { Import-CachedVcpkg 2>$null } | Should -Throw
      $cached_dir = ''
      [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseDeclaredVarsMoreThanAssignment', 'Location')]
      $Location = 'TestDrive:\'
      { Import-CachedVcpkg 2>$null } | Should -Throw
    }

    Context 'WhatIf' {
      Mock Assert-CI { return $true } -ModuleName 'Update-Vcpkg'
      [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseDeclaredVarsMoreThanAssignment', 'cache_dir')]
      $cache_dir = 'TestDrive:\cache'
      $target_dir = 'TestDrive:\target'
      New-Item -Path $target_dir -ItemType Directory
      New-Item -Path $cache_dir -ItemType Directory
      function Invoke-Import {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
          'PSUseDeclaredVarsMoreThanAssignment', 'cache_dir')]
        $cache_dir = 'TestDrive:\cache'
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
          'PSUseDeclaredVarsMoreThanAssignment', 'Location')]
        $Location = 'TestDrive:\target'
        return (Import-CachedVcpkg -WhatIf)
      }
      In -Path $target_dir {
        Remove-Item -Path $cache_dir/* -Force
        Remove-Item -Path ./* -Force

        It 'do not copy file (vcpkg)' {
          New-Item -Path $cache_dir -Name 'vcpkg' -ItemType File
          Test-Path 'vcpkg' -PathType Leaf | Should -Be $false
          { Invoke-Import } | Should -not -Throw
          Test-Path 'vcpkg' -PathType Leaf | Should -Be $false
        }
        It 'do not copy file (vcpkg.exe)' {
          Remove-Item -Path $cache_dir/* -Force
          Remove-Item -Path ./* -Force
          New-Item -Path $cache_dir -Name 'vcpkg.exe' -ItemType File
          { Invoke-Import } | Should -not -Throw
          Test-Path 'vcpkg.exe' -PathType Leaf | Should -Be $false
        }
      }
    }

    Context '$cache_dir defined' {
      Mock Assert-CI { return $true } -ModuleName 'Update-Vcpkg'
      [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseDeclaredVarsMoreThanAssignment', 'cache_dir')]
      $cache_dir = 'TestDrive:\cache 1'
      $target_dir = 'TestDrive:\target 1'
      New-Item -Path $target_dir -ItemType Directory
      function Invoke-Import {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
          'PSUseDeclaredVarsMoreThanAssignment', 'cache_dir')]
        $cache_dir = 'TestDrive:\cache 1'
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
          'PSUseDeclaredVarsMoreThanAssignment', 'Location')]
        $Location = 'TestDrive:\target 1'
        return Import-CachedVcpkg
      }
      In -Path $target_dir {
        It 'non-existing directory' {
          { Invoke-Import 6>$null } | Should -not -Throw
          Invoke-Import 6>$null | Should -Be $false
        }
        It 'empty existing directory' {
          New-Item -Path $cache_dir -ItemType Directory
          { Invoke-Import 6>$null } | Should -not -Throw
          Invoke-Import 6>$null | Should -Be $false
        }
        It 'copy vcpkg' {
          New-Item -Path $cache_dir -Name 'vcpkg' -ItemType File
          Test-Path 'vcpkg' -PathType Leaf | Should -Be $false
          { Invoke-Import } | Should -not -Throw
          Test-Path 'vcpkg' -PathType Leaf | Should -Be $true
        }
        It 'overwrite file in target directory' {
          $old_size = (Get-Item (Join-Path $target_dir 'vcpkg')).Length
          'some text' >> (Join-Path $cache_dir 'vcpkg')
          { Invoke-Import } | Should -not -Throw
          (Get-Item (Join-Path $target_dir 'vcpkg')).Length |
            Should -not -Be $old_size
        }
        It 'copy vcpkg.exe' {
          Remove-Item -Path $cache_dir/* -Force
          Remove-Item -Path ./* -Force
          New-Item -Path $cache_dir -Name 'vcpkg.exe' -ItemType File
          Test-Path 'vcpkg' -PathType Leaf | Should -Be $false
          Test-Path 'vcpkg.exe' -PathType Leaf | Should -Be $false
          { Invoke-Import } | Should -not -Throw
          Test-Path 'vcpkg.exe' -PathType Leaf | Should -Be $true
        }
        It 'do not copy vcpkg.txt' {
          Remove-Item -Path $cache_dir/* -Force
          Remove-Item -Path ./* -Force
          New-Item -Path $cache_dir -Name 'vcpkg.txt' -ItemType File
          { Invoke-Import } | Should -not -Throw
          Test-Path 'vcpkg.txt' -PathType Leaf | Should -Be $false
          Test-Path 'vcpkg' -PathType Leaf | Should -Be $false
          Test-Path 'vcpkg.exe' -PathType Leaf | Should -Be $false
        }
        It 'do not copy from subdirectories' {
          Remove-Item -Path $cache_dir/* -Force
          Remove-Item -Path ./* -Force
          New-Item -Path $cache_dir -Name 'dir'-ItemType Directory
          New-Item -Path (Join-Path $cache_dir 'dir') -Name 'vcpkg.exe' `
            -ItemType File
          { Invoke-Import 6>$null } | Should -not -Throw
          (Invoke-Import 1>$null) 6>&1 | Should -Match 'No Cache Found'
          Test-Path 'vcpkg.exe' -PathType Leaf | Should -Be $false
          Test-Path 'dir' -PathType Container | Should -Be $false
        }
        It 'multiple files matching "vcpkg*"' {
          New-Item -Path $cache_dir -Name 'vcpkg' -ItemType File -Force
          New-Item -Path $cache_dir -Name 'vcpkg.exe' -ItemType File -Force
          Remove-Item -Path * -Recurse -Force
          { Invoke-Import 6>$null } | Should -not -Throw
          Test-Path 'vcpkg' -PathType Leaf | Should -Be $true
          Test-Path 'vcpkg.exe' -PathType Leaf | Should -Be $true
        }
        It 'not a directory (no throw)' {
          Remove-Item -Path $cache_dir -Recurse -Force
          Remove-Item -Path * -Force
          New-Item -Path $cache_dir -ItemType File
          { Invoke-Import 6>$null } | Should -not -Throw
          Invoke-Import 6>$null | Should -Be $false
          Test-Path 'vcpkg' -PathType Leaf | Should -Be $false
        }
        It 'not a file' {
          Remove-Item -Path $cache_dir
          New-Item -Path $cache_dir -ItemType Directory
          New-Item -Path $cache_dir -Name 'vcpkg' -ItemType Directory
          { Invoke-Import 6>$null } | Should -not -Throw
          Invoke-Import 6>$null | Should -Be $false
          Test-Path 'vcpkg' | Should -Be $false
        }
        It 'a folder and a file' {
          New-Item -Path $cache_dir -Name 'vcpkg.exe' -ItemType File
          { Invoke-Import } | Should -not -Throw
          Test-Path 'vcpkg.exe' -PathType Leaf | Should -Be $true
          Test-Path 'vcpkg' | Should -Be $true
        }
      }
    }
  }
}

##====--------------------------------------------------------------------====##
Describe 'Internal Export-CachedVcpkg' {
  InModuleScope Update-Vcpkg {
    It 'has documentation' {
      Get-Help Export-CachedVcpkg | Out-String |
        Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
    }
    It 'supports -WhatIf and -Confirm' {
      Get-Command -Name Export-CachedVcpkg -Syntax |
        Should -Match '-WhatIf.*-Confirm'
    }

    Context '$cache_dir not defined' {
      Mock Assert-CI { return $true } -ModuleName 'Update-Vcpkg'

      It 'should throw' {
        { Export-CachedVcpkg 2>$null } | Should -Throw
      }
    }

    Context 'WhatIf' {
      Mock Assert-CI { return $true } -ModuleName 'Update-Vcpkg'
      [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseDeclaredVarsMoreThanAssignment', 'cache_dir')]
      $cache_dir = 'TestDrive:\cache'
      $vcpkg_dir = 'TestDrive:\vcpkg'
      New-Item -Path $vcpkg_dir -ItemType Directory
      New-Item -Path $cache_dir -ItemType Directory
      function Invoke-Export {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
          'PSUseDeclaredVarsMoreThanAssignment', 'cache_dir')]
        $cache_dir = 'TestDrive:\cache'
        return (Export-CachedVcpkg -WhatIf)
      }
      In -Path $vcpkg_dir {
        Remove-Item -Path $cache_dir/* -Force
        Remove-Item -Path ./* -Force

        It 'do not copy file (vcpkg)' {
          New-Item -Name 'vcpkg' -ItemType File
          { Invoke-Export } | Should -not -Throw
          Test-Path (Join-Path $cache_dir 'vcpkg') -PathType Leaf |
            Should -Be $false
        }
        It 'do not copy file (vcpkg.exe)' {
          Remove-Item -Path $cache_dir/* -Force
          Remove-Item -Path ./* -Force
          New-Item -Name 'vcpkg.exe' -ItemType File
          { Invoke-Export } | Should -not -Throw
          Test-Path (Join-Path $cache_dir 'vcpkg.exe') -PathType Leaf |
            Should -Be $false
        }
      }
    }

    Context '$cache_dir defined' {
      Mock Assert-CI { return $true } -ModuleName 'Update-Vcpkg'
      [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseDeclaredVarsMoreThanAssignment', 'cache_dir')]
      $cache_dir = 'TestDrive:\cache 1'
      $vcpkg_dir = 'TestDrive:\vcpkg dir'
      New-Item -Path $vcpkg_dir -ItemType Directory
      function Invoke-Export {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
          'PSUseDeclaredVarsMoreThanAssignment', 'cache_dir')]
        $cache_dir = 'TestDrive:\cache 1'
        return Export-CachedVcpkg
      }
      $file_vcpkg = Join-Path $cache_dir 'vcpkg'
      $file_exe = Join-Path $cache_dir 'vcpkg.exe'

      In -Path $vcpkg_dir {
        Remove-Item -Path ./* -Force
        It 'no files to cache' {
          { Invoke-Export } | Should -not -Throw
          Test-Path $file_exe | Should -Be $false
          Test-Path $file_vcpkg | Should -Be $false
        }
        It 'copy vcpkg' {
          New-Item -Name 'vcpkg' -ItemType File
          Test-Path $file_vcpkg -PathType Leaf | Should -Be $false
          { Invoke-Export } | Should -not -Throw
          Test-Path $file_vcpkg -PathType Leaf | Should -Be $true
        }
        It 'overwrite file in cache directory' {
          $old_size = (Get-Item $file_vcpkg).Length
          'some text' >> ./vcpkg
          { Invoke-Export } | Should -not -Throw
          (Get-Item $file_vcpkg).Length | Should -not -Be $old_size
        }
        It 'copy vcpkg.exe' {
          Remove-Item -Path $cache_dir/* -Force
          Remove-Item -Path ./* -Force
          New-Item -Name 'vcpkg.exe' -ItemType File
          Test-Path $file_vcpkg | Should -Be $false
          Test-Path $file_exe -PathType Leaf | Should -Be $false
          { Invoke-Export } | Should -not -Throw
          Test-Path $file_exe -PathType Leaf | Should -Be $true
        }
        It 'do not copy vcpkg.txt' {
          Remove-Item -Path $cache_dir/* -Force
          Remove-Item -Path ./* -Force
          New-Item -Path $vcpkg_dir -Name 'vcpkg.txt' -ItemType File
          { Invoke-Export } | Should -not -Throw
          Test-Path (Join-Path $cache_dir 'vcpkg.txt') -PathType Leaf |
            Should -Be $false
          Test-Path $file_vcpkg | Should -Be $false
          Test-Path $file_exe -PathType Leaf | Should -Be $false
        }
        It 'do not copy from subdirectories' {
          Remove-Item -Path $cache_dir/* -Force
          Remove-Item -Path ./* -Force
          New-Item -Name 'dir'-ItemType Directory
          New-Item -Path (Join-Path $vcpkg_dir 'dir') -Name 'vcpkg.exe' `
            -ItemType File
          { Invoke-Export } | Should -not -Throw
          Test-Path $file_exe | Should -Be $false
          Test-Path (Join-Path $cache_dir 'dir') -PathType Container |
            Should -Be $false
        }
        It 'multiple files matching "vcpkg(\.exe)?"' {
          Remove-Item -Path $cache_dir/* -Recurse -Force
          Remove-Item -Path ./* -Recurse -Force
          New-Item -Name 'vcpkg' -ItemType File -Force
          New-Item -Name 'vcpkg.exe' -ItemType File -Force
          { Invoke-Export } | Should -not -Throw
          Test-Path $file_vcpkg -PathType Leaf | Should -Be $true
          Test-Path $file_exe -PathType Leaf | Should -Be $true
        }
      }
    }
  }
}

##====--------------------------------------------------------------------====##
Describe 'Internal Update-Repository' {
  InModuleScope Update-Vcpkg {
    # Suppress output to the Appveyor Message API.
    Mock Assert-CI { return $false } -ModuleName Send-Message

    It 'has documentation' {
      Get-Help Update-Repository | Out-String |
        Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
    }
    It 'supports -WhatIf and -Confirm' {
      Get-Command -Name Update-Repository -Syntax |
        Should -Match '-WhatIf.*-Confirm'
    }
  }
}

Describe 'Internal Update-Repository (online)' -Tag 'online' {
  InModuleScope Update-Vcpkg {
    # Suppress output to the Appveyor Message API.
    Mock Assert-CI { return $false } -ModuleName Send-Message

    Context 'WhatIf' {
      $dir = New-Item 'TestDrive:\dir0' -ItemType Directory
      In -Path $dir {
        It 'empty folder: clone & warning' {
          { Update-Repository -WhatIf 3>$null } | Should -not -Throw
          Update-Repository -WhatIf 3>&1 |
            Should -Match 'vcpkg not installed in the expected location'
        }
      }
      $dir = New-Item 'TestDrive:\dir1' -ItemType Directory
      In -Path $dir {
        New-Item -Name 'file' -ItemType File
        It 'throw on non-empty directory without git' {
          { Update-Repository -WhatIf 6>$null } |
            Should -Throw 'not empty and not a git working directory'
        }
        git init
        It 'throw on non-empty git directory without remote' {
          { Update-Repository -WhatIf 6>$null } |
            Should -Throw 'no remote repositories defined'
        }
      }
      $dir = New-Item 'TestDrive:\dir2' -ItemType Directory
      In -Path $dir {
        git clone https://github.com/Farwaykorse/AppVeyorHelpers.git --quiet .\
        It 'fetch & merge' {
          { Update-Repository -WhatIf } | Should -not -Throw
        }
        It 'specific commit: checkout' {
          { Update-Repository -WhatIf `
            -Commit 64dd542dd02994e6925c5abf4b4b7618acfcfbb5
          } | Should -not -Throw
        }
        It '-Verbose' {
          { Update-Repository -Verbose -WhatIf } | Should -not -Throw
        }
      }
    }
    Context 'normal operation' {
      $dir = New-Item 'TestDrive:\dir2' -ItemType Directory
      In -Path $dir {
        It 'clone & merge' {
          { Update-Repository 3>$null } | Should -not -Throw
        }
        It 'fetch & checkout' {
          { Update-Repository -Commit ea9d29c05b110f203184eb4602b23325557de9c3 `
            3>$null } | Should -not -Throw
        }
      }
    }
  }
}

##====--------------------------------------------------------------------====##
function Assert-RequirementsVcpkg {
  if ($env:APPVEYOR_BUILD_WORKER_IMAGE -match 'Visual Studio 2013') {
    Set-ItResult -Skipped -Because 'not supported for VS2013'
  }
}

Describe 'Update-Vcpkg' {
  # Suppress output to the Appveyor Message API.
  Mock Assert-CI { return $false } -ModuleName Send-Message
  AfterEach {
    $env:APPVEYOR_CACHE_SKIP_SAVE = ''
  }

  It 'has documentation' {
    Get-Help Update-Vcpkg | Out-String |
      Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
  }
  It 'supports -WhatIf and -Confirm' {
    Get-Command -Name Update-Vcpkg -Syntax |
      Should -Match '-WhatIf.*-Confirm'
  }

  Context 'Input Validation' {
    It 'throws on empty -FixedCommit' {
      { Update-Vcpkg -FixedCommit } | Should -Throw 'missing an argument'
    }
    It 'throws on empty string -FixedCommit' {
      { Update-Vcpkg -FixedCommit '' } |
        Should -Throw 'argument is null or empty'
    }
    It 'throws on $null -FixedCommit' {
      { Update-Vcpkg -FixedCommit $null } |
        Should -Throw 'argument is null or empty'
    }
    It 'throws when -FixedCommit length is not 40 characters' {
      { Update-Vcpkg -FixedCommit '123456789' } |
        Should -Throw 'does not match'
    }
    It 'throws when -FixedCommit contains invalid characters' {
      { Update-Vcpkg -FixedCommit 'CF83E1357XXXXXXDF1542850D66D8007D620E405'} |
        Should -Throw 'does not match'
    }
    It 'throws on empty -Path' {
      { Update-Vcpkg -Path } | Should -Throw 'missing an argument'
    }
    It 'throws on empty string -Path' {
      { Update-Vcpkg -Path '' } | Should -Throw 'argument is null or empty'
    }
    It 'throws on $null -Path' {
      { Update-Vcpkg -Path $null } | Should -Throw 'argument is null or empty'
    }
    It 'throws when -Path points to a file' {
      New-Item -Path TestDrive:\ -Name file.txt -ItemType File
      { Update-Vcpkg -Path 'TestDrive:\file.txt' } |
        Should -Throw 'validation script'
    }
    Context 'Input Validation: -Path' {
      Mock Select-VcpkgLocation { throw 'unexpected' } -ModuleName Update-Vcpkg
      In -Path 'TestDrive:\' {
        It 'invalid path' {
          #{ Update-vcpkg -Path '/../..' } | Should -Throw 'validation script'
          { Update-vcpkg -Path './*' } | Should -Throw 'validation script'
          { Update-vcpkg -Path './?' } | Should -Throw 'validation script'
        }
        $path = 'TestDrive:\path'
        New-Item -Path $path -ItemType File
        It 'throw: -Path is an existing file' {
          { Update-vcpkg -Path $path } | Should -Throw 'validation script'
        }
        Remove-Item $path
        $path = 'TestDrive:\path'
        New-Item -Path $path -ItemType Directory
        New-Item -Path $path -Name 'somefile.txt' -ItemType File
        It 'throw: non-empty, not a git working directory' {
          Assert-RequirementsVcpkg
          { Update-vcpkg -Path $path 3>$null 6>$null } |
            Should -Throw 'not empty and not a git working directory'
          if (Assert-CI) {
            $env:APPVEYOR_CACHE_SKIP_SAVE | Should -Be $true
            Assert-MockCalled -CommandName Assert-CI -ModuleName Send-Message `
              -Scope It -Times 3 -Exactly
          } else {
            $env:APPVEYOR_CACHE_SKIP_SAVE | Should -Be $null
            Assert-MockCalled -CommandName Assert-CI -ModuleName Send-Message `
              -Scope It -Times 2 -Exactly
          }
        }
      }
    }
    It 'throws on empty -CachePath' {
      { Update-Vcpkg -CachePath } | Should -Throw 'missing an argument'
    }
    It 'throws on empty string -CachePath' {
      { Update-Vcpkg -CachePath '' } | Should -Throw 'argument is null or empty'
    }
    It 'throws on $null -CachePath' {
      { Update-Vcpkg -CachePath $null } |
        Should -Throw 'argument is null or empty'
    }
    It 'throws on non-existing -CachePath' {
      { Update-Vcpkg -CachePath 'TestDrive:\non-existing\location' } |
        Should -Throw 'validation script'
    }
    It 'throws when -CachePath points to a file' {
      New-Item -Path TestDrive:\ -Name file.txt -ItemType File -Force
      { Update-Vcpkg -CachePath 'TestDrive:\file.txt' } |
        Should -Throw 'validation script'
    }
    $cache = New-Item -Path 'TestDrive:\' -name 'some_cache' -ItemType Container
    It 'warning from -CachePath' {
      Assert-RequirementsVcpkg
      Mock Assert-CI { return $false } -ModuleName Update-Vcpkg
      (Update-Vcpkg -CachePath $cache -WhatIf 6>$null) 3>&1 |
        Should -Match 'CachePath has no use outside the AppVeyor environment'
      (Update-Vcpkg -CachePath 'TestDrive:\some_cache' -Quiet -WhatIf `
        6>$null) 3>&1 | Should -Be $null
    }

  } # /Context: Input Validation
  Context 'WhatIf & Path' {
    Mock Test-Command { return $false } -ModuleName Update-Vcpkg
    Mock Add-EnvironmentPath { return $null } -ModuleName Update-Vcpkg
    Mock Assert-CI { return $false } -ModuleName Update-Vcpkg
    Mock Select-VcpkgLocation { throw 'unexpected' } -ModuleName Update-Vcpkg

    # clone / merge
    $vcpkg_dir = New-Item -Path 'TestDrive:\' -Name 'vc 1' -ItemType Directory
    It '-Path (existing) clone & merge' {
      Assert-RequirementsVcpkg
      [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseDeclaredVarsMoreThanAssignment', 'vcpkg_dir')]
      $path = Join-Path $vcpkg_dir 'vcpkg'
      { Update-Vcpkg -Path $vcpkg_dir -WhatIf *>$null } |
        Should -not -Throw
      (Update-Vcpkg -Path $vcpkg_dir -Quiet -WhatIf 1>$null) 3>&1 6>$null |
        Should -Match 'Update-Repository: vcpkg not installed'
      Test-Path (Join-Path $vcpkg_dir '*') | Should -Be $false
      Test-Path -Path (Join-Path $PSScriptRoot 'vcpkg_source.hash') |
        Should -Be $false
      $env:APPVEYOR_CACHE_SKIP_SAVE | Should -Be $null
    }
    $vcpkg_dir = Join-Path (Join-Path 'TestDrive:\' 'vc 2') 'vcpkg'
    It '-Path (non-existing) - creates directory' {
      Assert-RequirementsVcpkg
      [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseDeclaredVarsMoreThanAssignment', 'vcpkg_dir')]
      $path = Join-Path $vcpkg_dir 'vcpkg'
      { Update-Vcpkg -Path $vcpkg_dir -Quiet -WhatIf *>$null } |
        Should -not -Throw
      (Update-Vcpkg -Path $vcpkg_dir -Quiet -WhatIf 1>$null) 3>&1 6>$null |
        Should -Match 'Update-Repository: vcpkg not installed'
      Test-Path (Join-Path $vcpkg_dir '*') | Should -Be $false
      Test-Path -Path $vcpkg_dir -PathType Container | Should -Be $true
      $env:APPVEYOR_CACHE_SKIP_SAVE | Should -Be $null
    }
    # clone / checkout
    $vcpkg_dir = New-Item -Path 'TestDrive:\' -Name 'vc 3' -ItemType Directory
    It '-FixedCommit: clone & checkout' {
      Assert-RequirementsVcpkg
      [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseDeclaredVarsMoreThanAssignment', 'vcpkg_dir')]
      $path = Join-Path $vcpkg_dir 'vcpkg'
      { Update-Vcpkg -Path $vcpkg_dir `
        -FixedCommit CF83E1357000000DF1542850D66D8007D620E405 -Quiet -WhatIf `
        *>$null
      } | Should -not -Throw
      (Update-Vcpkg -Path $vcpkg_dir `
        -FixedCommit CF83E1357000000DF1542850D66D8007D620E405 -Quiet -WhatIf `
        1>$null) 3>&1 6>$null |
        Should -Match 'Update-Repository: vcpkg not installed'
      Test-Path (Join-Path $vcpkg_dir '*') | Should -Be $false
      $env:APPVEYOR_CACHE_SKIP_SAVE | Should -Be $null
    }

    # Work-around issue with asynchronous file IO on Windows.
    $capture = Join-Path 'TestDrive:\' '*'
    while ($true) {
      if ((Remove-Item $capture -Recurse -Force -ErrorAction Continue *>&1
      ) -ne $null) {
        Start-Sleep -Seconds 0.5
      } else { break }
    }
    # /Work-around
  }
  Context 'WhatIf & Latest; mock Location' {
    Mock Assert-CI { return $false } -ModuleName Update-Vcpkg
    Mock Select-VcpkgLocation { (Join-Path 'TestDrive:\' 'loc').ToString() } `
      -ModuleName Update-Vcpkg
    $vcpkg_dir = New-Item -Path 'TestDrive:\' -Name 'loc' -ItemType Directory

    It 'no changes with -Latest -WhatIf' {
      Assert-RequirementsVcpkg
      if (-not (Test-Command 'vcpkg version')) {
        Set-ItResult -Skipped -Because 'requires installed vcpkg'
      }
      { Update-Vcpkg -Latest -Quiet -WhatIf 3>$null 6>$null } |
        Should -not -Throw
      Test-Path -Path (Join-Path $PSScriptRoot 'vcpkg_source.hash') |
        Should -Be $false
      Update-Vcpkg -Latest -Quiet -WhatIf 3>&1 6>$null |
        Should -Match 'Update-Repository: vcpkg not installed'
      $env:APPVEYOR_CACHE_SKIP_SAVE | Should -Be $null
    }
    # Work-around issue with asynchronous file IO on Windows.
    while ($true) {
      if ((Remove-Item $vcpkg_dir -Recurse -Force -ErrorAction Continue *>&1
      ) -ne $null) {
        Start-Sleep -Seconds 0.5
      } else { break }
    }
    # /Work-around
  }
  Context 'WhatIf: build after retrieval from cache (mocked)' {
    Mock Update-Repository { return $null } -ModuleName Update-Vcpkg
    Mock Import-CachedVcpkg { return $true } -ModuleName Update-Vcpkg
    Mock Test-IfReleaseWithIssue { return $true } -ModuleName Update-Vcpkg
    $vcpkg_dir = New-Item -Path 'TestDrive:\' -Name 'vc 4' -ItemType Directory
    # Mock vcpkg
    ( 'param([String]$input)' +
      'if ($input -eq "update") { Write-Output "No packages need updating."' +
      '} elseif ($input -eq "upgrade") {' +
      '  Write-Output "All installed packages are up-to-date"' +
      '} else { Write-Output "..." }'
    ) > (Join-Path $vcpkg_dir 'vcpkg.ps1')

    It 'build after retrieval from cache (mocked)' {
      Assert-RequirementsVcpkg
      { Update-Vcpkg -Path $vcpkg_dir -Quiet -WhatIf 3>$null } |
        Should -not -Throw
      Assert-MockCalled -CommandName Update-Repository `
        -ModuleName update-Vcpkg -Times 1 -Exactly -Scope It
      Assert-MockCalled -CommandName Import-CachedVcpkg `
        -ModuleName update-Vcpkg -Times 1 -Exactly -Scope It
      Assert-MockCalled -CommandName Test-IfReleaseWithIssue `
        -ModuleName update-Vcpkg -Times 1 -Exactly -Scope It
      $env:APPVEYOR_CACHE_SKIP_SAVE | Should -Be $null
    }
    Mock Test-IfReleaseWithIssue { return $false } -ModuleName Update-Vcpkg
    It 'no build after retrieval from cache (mocked)' {
      Assert-RequirementsVcpkg
      { Update-Vcpkg -Path $vcpkg_dir -Quiet -WhatIf 3>$null } |
        Should -not -Throw
      Assert-MockCalled -CommandName Update-Repository `
        -ModuleName update-Vcpkg -Times 1 -Exactly -Scope It
      Assert-MockCalled -CommandName Import-CachedVcpkg `
        -ModuleName update-Vcpkg -Times 1 -Exactly -Scope It
      Assert-MockCalled -CommandName Test-IfReleaseWithIssue `
        -ModuleName update-Vcpkg -Times 1 -Exactly -Scope It
      $env:APPVEYOR_CACHE_SKIP_SAVE | Should -Be $null
    }
    # Work-around issue with asynchronous file IO on Windows.
    while ($true) {
      if ((Remove-Item $vcpkg_dir -Recurse -Force -ErrorAction Continue *>&1
      ) -ne $null) {
        Start-Sleep -Seconds 0.5
      } else { break }
    }
    # /Work-around
  }

  Context 'WhatIf: no cache needed' {
    Mock Update-Repository { return $null } -ModuleName Update-Vcpkg
    Mock Import-CachedVcpkg { return $true } -ModuleName Update-Vcpkg
    Mock Test-IfReleaseWithIssue { return $false } -ModuleName Update-Vcpkg
    Mock Assert-CI { return $true } -ModuleName Update-Vcpkg
    Mock Test-Path { return $true } -ModuleName Update-Vcpkg
    Mock Remove-Item { return $null } -ModuleName Update-Vcpkg
    $vcpkg_dir = New-Item -Path 'TestDrive:\' -Name 'vc 5' -ItemType Directory
    # Mock vcpkg
    ( 'param([String]$input)' +
      'if ($input -eq "update") { Write-Output "No packages need updating."' +
      '} elseif ($input -eq "upgrade") {' +
      '  Write-Output "All installed packages are up-to-date"' +
      '} else { Write-Output "..." }'
    ) > (Join-Path $vcpkg_dir 'vcpkg.ps1')

    It 'vcpkg is up-to-date' {
      Assert-RequirementsVcpkg
      { Update-Vcpkg -Path $vcpkg_dir -Quiet -Verbose -WhatIf 4>$null } |
        Should -not -Throw
      Assert-MockCalled -CommandName Update-Repository `
        -ModuleName Update-Vcpkg -Times 1 -Exactly -Scope It
      Assert-MockCalled -CommandName Import-CachedVcpkg `
        -ModuleName Update-Vcpkg -Times 0 -Exactly -Scope It
      Assert-MockCalled -CommandName Test-IfReleaseWithIssue `
        -ModuleName Update-Vcpkg -Times 1 -Exactly -Scope It
      Assert-MockCalled -CommandName Remove-Item `
        -ModuleName Update-Vcpkg -Times 1 -Exactly -Scope It
      $env:APPVEYOR_CACHE_SKIP_SAVE | Should -Be $null
    }
    # Work-around issue with asynchronous file IO on Windows.
    while ($true) {
      if ((Remove-Item $vcpkg_dir -Recurse -Force -ErrorAction Continue *>&1
      ) -ne $null) {
        Start-Sleep -Seconds 0.5
      } else { break }
    }
    # /Work-around
  }
  $original_CI_WINDOWS = $env:CI_WINDOWS
  It 'failed build' {
    Assert-RequirementsVcpkg # not for image: Visual Studio 2013
    Mock Push-Location { throw 'something' } -ModuleName Update-vcpkg
    Mock Assert-CI { return $true } -ModuleName Update-vcpkg
    Mock Test-Path { return $false } -ModuleName Update-vcpkg
    # should not be called
    Mock Update-Repository { throw 'do not call' } -ModuleName Update-Vcpkg
    Mock Import-CachedVcpkg { throw 'do not call' } -ModuleName Update-Vcpkg
    Mock Export-CachedVcpkg { throw 'do not call' } -ModuleName Update-Vcpkg
    Mock Test-IfReleaseWithIssue { throw 'do not' } -ModuleName Update-Vcpkg
    Mock Add-EnvironmentPath { throw 'do not call' } -ModuleName Update-Vcpkg

    $env:CI_WINDOWS = 'True'
    { Update-Vcpkg 6>$null 3>$null } | Should -Throw 'something'
    $env:APPVEYOR_CACHE_SKIP_SAVE | Should -Be $true
    $env:CI_WINDOWS = 'False'
    { Update-Vcpkg 6>$null 3>$null } | Should -Throw 'something'
  }
  $env:CI_WINDOWS = $original_CI_WINDOWS

  $original_image = $env:APPVEYOR_BUILD_WORKER_IMAGE
  Context 'Visual Studio 2013' {
    Mock Assert-CI { return $true } -ModuleName Update-Vcpkg
    $env:APPVEYOR_BUILD_WORKER_IMAGE = 'Visual Studio 2013'
    Mock Test-Command { return $false } -ModuleName Update-Vcpkg
    Mock Select-VcpkgLocation { return 'TestDrive:\' } -ModuleName Update-Vcpkg
    # should not be called
    Mock Update-Repository { throw 'do not call' } -ModuleName Update-Vcpkg
    Mock Import-CachedVcpkg { throw 'do not call' } -ModuleName Update-Vcpkg
    Mock Export-CachedVcpkg { throw 'do not call' } -ModuleName Update-Vcpkg
    Mock Test-IfReleaseWithIssue { throw 'do not' } -ModuleName Update-Vcpkg
    Mock Add-EnvironmentPath { throw 'do not call' } -ModuleName Update-Vcpkg

    It 'vcpkg requires minimally VS2015 on Windows' {
      { Update-Vcpkg *>$null } | Should -not -Throw
      Assert-MockCalled -CommandName Test-Command `
        -ModuleName Update-Vcpkg -Times 1 -Exactly -Scope It
      Assert-MockCalled -CommandName Select-VcpkgLocation `
        -ModuleName Update-Vcpkg -Times 1 -Exactly -Scope It
      $out = (Update-Vcpkg -Quiet 1>$null) 6>&1
      $out[0] | Should -Match 'Vcpkg requires minimally Visual Studio 2015'
      Assert-MockCalled -CommandName Test-Command `
        -ModuleName update-Vcpkg -Times 2 -Exactly -Scope It
      $env:APPVEYOR_CACHE_SKIP_SAVE | Should -Be $null
    }
  }
  $env:APPVEYOR_BUILD_WORKER_IMAGE = $original_image
} # /Describe 'Update-Vcpkg'
##====--------------------------------------------------------------------====##
