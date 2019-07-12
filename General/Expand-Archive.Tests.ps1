Import-Module -Name "${PSScriptRoot}\Expand-Archive.psd1" -Force

Set-StrictMode -Version Latest

##====--------------------------------------------------------------------====##
$global:msg_documentation = 'at least 1 empty line above documentation'

##====--------------------------------------------------------------------====##
# Helper function to check for helper file required for the test.
function Test-InconclusiveMissingFile {
  param(
    [ValidateNotNullOrEmpty()]
    $Path,
    [Switch] $Not
  )
  if (-not $Not -and -not (Test-Path "$Path" -PathType Leaf) ) {
    Set-ItResult -Inconclusive -Because ('missing sample file: ' + "$Path")
  } elseif ($Not -and (Test-Path "$Path" -PathType Leaf) ) {
    Set-ItResult -Inconclusive -Because ('should not exist: ' + "$Path")
  }
} 
##====--------------------------------------------------------------------====##

Describe 'Expand-Archive' {
  It 'has documentation' {
    Get-Help Expand-Archive | Out-String |
      Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
  }
  It 'supports -WhatIf and -Confirm' {
    Get-Command -Name Expand-Archive -Syntax |
      Should -Match '-Whatif.*-Confirm'
  }

  Context 'System Requirements' {
    Import-Module -Name "${PSScriptRoot}\..\General\Test-Command.psd1"

    It '7z should be available on the search Path' {
      Test-Command '7z' | Should -Be $true
    }
  }

  Context 'Input Errors' {
    $test_drive = (Resolve-Path 'TestDrive:').ProviderPath
    $archive = Join-Path "$test_drive" 'something.zip'
    $wrong_archive = Join-Path "$test_drive" 'something'
    New-Item -Name something.zip -Path "$test_drive" -ItemType File
    It 'throws on missing -Archive' {
      { Expand-Archive -TargetDir .\ } |
        Should -Throw 'Archive is a required parameter'
    }
    It 'throws on empty -Archive' {
      { Expand-Archive -Archive } | Should -Throw 'missing an argument'
    }
    It 'throws on empty string -Archive' {
      { Expand-Archive -Archive '' } | Should -Throw 'argument is null or empty'
    }
    It 'throws on $null -Archive' {
      { Expand-Archive -Archive $null } |
        Should -Throw 'argument is null or empty'
    }
    It 'throws on non-existing archive' {
      Test-InconclusiveMissingFile -not $wrong_archive
      { Expand-Archive -Archive "$wrong_archive" } |
        Should -Throw '-Archive does not exist'
    }
    It 'after, test-file existing created' {
      Test-Path "$archive" -PathType Leaf | Should -Be $true
    }
    It 'throws on empty -TargetDir' {
      Test-Path "$archive" -PathType Leaf | Should -Be $true
      { Expand-Archive -Archive "$archive" -TargetDir } |
        Should -Throw 'missing an argument'
    }
    It 'throws on empty string -TargetDir' {
      Test-InconclusiveMissingFile $archive
      { Expand-Archive -Archive "$archive" -TargetDir '' } |
        Should -Throw 'argument is null or empty'
    }
    It 'throws on $null -TargetDir' {
      Test-InconclusiveMissingFile $archive
      { Expand-Archive -Archive "$archive" -TargetDir $null } |
        Should -Throw 'argument is null or empty'
    }
    It 'throws on -FlatPath without -TargetDir' {
      Test-InconclusiveMissingFile $archive
      { Expand-Archive -Archive "$archive" -FlatPath } |
        Should -Throw '-FlatPath requires -TargetDir'
    }
  }

  Context 'a .zip archive' {
    $test_drive = (Resolve-Path 'TestDrive:').ProviderPath
    $archive_name = 'archive'
    $archive = Join-Path "$test_drive" "${archive_name}.zip"
    $file_1 = 'Expand-Archive.Tests.ps1'
    $this_file = Resolve-Path (Join-Path $PSScriptRoot $file_1)

    It 'create zip' {
      Test-Path $archive -PathType Leaf | Should -Be $false `
        -Because 'Archive already exists.'
      { 7z a -bso0 -y "$archive" "$this_file" } | Should -not -Throw
      Test-Path "$archive" -PathType Leaf | Should -Be $true `
        -Because 'Archive not in expected location.'
    }

    Context 'wildcard' {
      It 'accepts wildcard characters' {
        Test-InconclusiveMissingFile $archive
        In -Path "$test_drive" {
          { Expand-Archive -Archive (Join-Path $test_drive '*.zip') `
            -TargetDir .\ *>$null } | Should -not -Throw
        }
      }
    }

    Context 'WhatIf' {
      $target_dir = Join-Path "$test_drive" 'output'
      It 'before, not extracted' {
        Test-InconclusiveMissingFile $archive
        Test-Path (Join-Path "$target_dir" "$file_1") | Should -Be $false
      }
      It 'before, no new directory' {
        Test-InconclusiveMissingFile $archive
        Test-Path "$target_dir" -PathType Container | Should -Be $false
      }
      It 'extract with -WhatIf' {
        Test-InconclusiveMissingFile $archive
        { Expand-Archive -Archive "$archive" -TargetDir "$target_dir" -WhatIf
        } | Should -not -Throw
      }
      It 'after, not extracted' {
        Test-InconclusiveMissingFile $archive
        Test-Path (Join-Path "$target_dir" "$file_1") | Should -Be $false
      }
      It 'after, no new directory' {
        Test-InconclusiveMissingFile $archive
        Test-Path "$target_dir" -PathType Container | Should -Be $false
      }
    }
    Context 'extract - to existing directory' {
      $target_dir = "$test_drive"
      It 'before, not extracted' {
        Test-InconclusiveMissingFile $archive
        Test-Path (Join-Path "$target_dir" "$file_1") | Should -Be $false
        Test-Path (Join-Path "$target_dir" $archive_name) -PathType Container |
          Should -Be $false
      }
      It 'extract' {
        Test-InconclusiveMissingFile $archive
        Expand-Archive -Archive "$archive" -TargetDir "$target_dir"
      }
      It 'after, extracted' {
        Test-InconclusiveMissingFile $archive
        Test-Path (Join-Path "$target_dir" "$file_1") | Should -Be $true
        Test-Path (Join-Path "$target_dir" $archive_name) -PathType Container |
          Should -Be $false
      }
      It 'extract again (overwrite)' {
        Test-InconclusiveMissingFile $archive
        $file = (Join-Path "$target_dir" "$file_1")
        Test-InconclusiveMissingFile $file
        $size = (Get-Item "$file").Length
        'some text' >> $file # modify file
        (Get-Item "$file").Length | Should -not -BeExactly $size `
          -Because 'the file size should have increased for this test.'
        { Expand-Archive -Archive "$archive" -TargetDir "$target_dir" } |
          Should -not -Throw
        Test-Path "$file" | Should -Be $true
        (Get-Item "$file").Length | Should -BeExactly $size
        Test-Path (Join-Path "$target_dir" $archive_name) -PathType Container |
          Should -Be $false
      }
    }
    Context 'extract - to new directory' {
      $target_dir = Join-Path "$test_drive" 'output'
      It 'before, not extracted' {
        Test-InconclusiveMissingFile $archive
        Test-Path "$target_dir" -PathType Container | Should -Be $false
        Test-Path (Join-Path "$test_drive" "$file_1") | Should -Be $false
      }
      It 'extract' {
        Test-InconclusiveMissingFile $archive
        Expand-Archive -Archive "$archive" -TargetDir "$target_dir"
      }
      It 'after, extracted' {
        Test-InconclusiveMissingFile $archive
        Test-Path (Join-Path "$target_dir" "$file_1") | Should -Be $true
        Test-Path (Join-Path "$target_dir" $archive_name) -PathType Container |
          Should -Be $false
      }
    }
    Context 'extract -FlatPath' {
      $target_dir = Join-Path "$test_drive" 'output'
      It 'before, not extracted' {
        Test-InconclusiveMissingFile $archive
        Test-Path (Join-Path "$test_drive" "$file_1") | Should -Be $false
        Test-Path (Join-Path "$target_dir" $archive_name) -PathType Container |
          Should -Be $false
      }
      It 'extracting' {
        Test-InconclusiveMissingFile $archive
        Expand-Archive -Archive "$archive" -TargetDir "$target_dir" -FlatPath
      }
      It 'after, extracting' {
        Test-InconclusiveMissingFile $archive
        Test-Path (Join-Path "$target_dir" "$file_1") | Should -Be $true
        Test-Path (Join-Path "$target_dir" $archive_name) -PathType Container |
          Should -Be $false
      }
    }
    Context 'extract no -TargetDir' {
      $target_dir = "$test_drive"
      It 'before, not extracted' {
        Test-InconclusiveMissingFile $archive
        Test-Path (Join-Path "$target_dir" "$file_1") | Should -Be $false
        Test-Path (Join-Path "$target_dir" $archive_name) -PathType Container |
          Should -Be $false
      }
      It 'extract' {
        Test-InconclusiveMissingFile $archive
        In -Path $test_drive { Expand-Archive -Archive "$archive" }
      }
      It 'after, extract (no -TargetDir)' {
        Test-InconclusiveMissingFile $archive
        Test-Path (Join-Path "$target_dir" $archive_name) -PathType Container |
          Should -Be $true
        if ( $PSVersionTable.PSVersion.Major -lt 6 ) {
          $file = [IO.Path]::Combine("$test_drive", $archive_name, $file_1)
        } else {
          $file = Join-Path "$test_drive" $archive_name $file_1
        }
        Test-Path $file | Should -Be $true
      }
    }
    Context 'ShowProgress' {
      It 'output of the progress indicator' {
        Test-InconclusiveMissingFile $archive
        In -Path $test_drive {
          Expand-Archive -Archive "$archive" -ShowProgress
        }
        # TODO
      }
    }
  }

  Context 'a .zip archive with directories' {
    $test_drive = (Resolve-Path 'TestDrive:').ProviderPath
    $archive_name = 'archive'
    $archive = Join-Path "$test_drive" "${archive_name}.zip"
    $file_1 = 'file.txt'
    $directory = 'dir'
    $dir_file = Join-Path $directory $file_1

    It 'create zip archive' {
      Test-Path $archive -PathType Leaf | Should -Be $false `
        -Because 'Archive already exists.'
      New-Item "$test_drive" -Name 'dir' -ItemType Directory
      'some text' > (Join-Path "$test_drive" $dir_file)

      { 7z a -bso0 -y -sdel "$archive" (Join-Path "$test_drive" $directory) } |
        Should -not -Throw

      Test-Path "$archive" -PathType Leaf | Should -Be $true `
        -Because 'Archive not in expected location.'
      Test-Path -Path (Join-Path "$test_drive" $directory) -PathType Container |
        Should -Be $false -Because 'Archived files should be deleted.'
    }

    Context 'extract' {
      $target_dir = Join-Path "$test_drive" 'output'
      It 'before, not extracted' {
        Test-InconclusiveMissingFile $archive
        Test-Path "$target_dir" -PathType Container | Should -Be $false
        Test-Path (Join-Path "$target_dir" "$dir_file") | Should -Be $false
        Test-Path (Join-Path "$target_dir" "$file_1") | Should -Be $false
        Test-Path (Join-Path "$test_drive" "$file_1") | Should -Be $false
        Test-Path (Join-Path "$target_dir" $archive_name) -PathType Container |
          Should -Be $false
      }
      It 'extract' {
        Test-InconclusiveMissingFile $archive
        Expand-Archive -Archive "$archive" -TargetDir "$target_dir"
      }
      It 'after, extracted' {
        Test-InconclusiveMissingFile $archive
        Test-Path "$target_dir" -PathType Container | Should -Be $true
        Test-Path (Join-Path "$target_dir" "$dir_file") | Should -Be $true
        Test-Path (Join-Path "$target_dir" "$file_1") | Should -Be $false
        Test-Path (Join-Path "$test_drive" "$file_1") | Should -Be $false
        Test-Path (Join-Path "$target_dir" $archive_name) -PathType Container |
          Should -Be $false
      }
    }
    Context 'extract -FlatPath' {
      $target_dir = Join-Path "$test_drive" 'output'
      It 'before, not extracted' {
        Test-InconclusiveMissingFile $archive
        Test-Path "$target_dir" -PathType Container | Should -Be $false
        Test-Path (Join-Path "$target_dir" "$dir_file") | Should -Be $false
        Test-Path (Join-Path "$target_dir" "$file_1") | Should -Be $false
        Test-Path (Join-Path "$test_drive" "$file_1") | Should -Be $false
        Test-Path (Join-Path "$target_dir" $archive_name) -PathType Container |
          Should -Be $false
      }
      It 'extracting' {
        Test-InconclusiveMissingFile $archive
        Expand-Archive -Archive "$archive" -TargetDir "$target_dir" -FlatPath
      }
      It 'after, extracting' {
        Test-InconclusiveMissingFile $archive
        Test-Path "$target_dir" -PathType Container | Should -Be $true
        Test-Path (Join-Path "$target_dir" "$dir_file") | Should -Be $false
        Test-Path (Join-Path "$target_dir" "$file_1") | Should -Be $true
        Test-Path (Join-Path "$test_drive" "$file_1") | Should -Be $false
        Test-Path (Join-Path "$target_dir" $archive_name) -PathType Container |
          Should -Be $false
      }
    }
    Context 'extract no -TargetDir' {
      $target_dir = "$test_drive"
      It 'before, not extracted' {
        Test-InconclusiveMissingFile $archive
        Test-Path (Join-Path "$target_dir" "$file_1") | Should -Be $false
        Test-Path (Join-Path "$target_dir" "$dir_file") | Should -Be $false
        Test-Path (Join-Path "$target_dir" $archive_name) -PathType Container |
          Should -Be $false
      }
      It 'extract' {
        Test-InconclusiveMissingFile $archive
        In -Path $test_drive { Expand-Archive -Archive "$archive" }
      }
      It 'after, extract (no -TargetDir)' {
        Test-InconclusiveMissingFile $archive
        Test-Path (Join-Path "$target_dir" $archive_name) -PathType Container |
          Should -Be $true
        if ( $PSVersionTable.PSVersion.Major -lt 6 ) {
          $file = [IO.Path]::Combine("$test_drive", $archive_name, $dir_file)
        } else {
          $file = Join-Path "$test_drive" $archive_name $dir_file
        }
        Test-Path $file | Should -Be $true
      }
    }
  }

}
