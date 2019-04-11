## Ensure the module is available
Import-Module -Name ${PSScriptRoot}\Codecov.psm1 -Force

Set-StrictMode -Version Latest

$global:msg_documentation = 'at least 1 empty line above documentation'

##====--------------------------------------------------------------------====##
Describe 'Assert-ValidCodecovYML' {
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
    It 'Multiple matches' {
      { Assert-ValidCodecovYML -Path 'TestDrive:\*codecov.yml' *>$null } |
        Should -Throw 'Empty File'
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
      { Assert-ValidCodecovYML -Path 'TestDrive:\InvalidDir\codecov.yml' } |
        Should -Throw 'validation script'
    }
    New-Item -Path TestDrive:\ -Name directory -ItemType Directory
    It 'non-existent file' {
      { Assert-ValidCodecovYML -Path 'TestDrive:\directory\codecov.yml' } |
        Should -Throw 'validation script'
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

##====--------------------------------------------------------------------====##
Describe 'Internal Check-Installed' {
  InModuleScope Codecov {
    It 'has documentation' {
      Get-Help Check-Installed | Out-String |
        Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
    }
    Context 'Test-Command: $false; uploader is not installed' {
      Mock Test-Command { return $false } -ModuleName Codecov

      $script:CodecovInstalled = $true
      It 'Check-Installed variable $true, skip expensive test' {
        Check-Installed | Should -BeTrue
        Check-Installed | Should -BeOfType System.Boolean
      }
      $script:CodecovInstalled = $false
      It 'Check-Installed failure' {
        Check-Installed | Should -BeFalse
      }
    }
    Context 'Test-Command: $true; uploader is installed' {
      Mock Test-Command { return $true } -ModuleName Codecov

      $script:CodecovInstalled = $false
      It 'Check-Installed returns $true' {
        Check-Installed | Should -BeTrue
      }
      It 'Check-Installed sets $global:CodecovInstalled' {
        $CodecovInstalled | Should -BeTrue
      }
    }
    Set-Variable CodecovInstalled $false -Scope Global
  }
}

##====--------------------------------------------------------------------====##
Describe 'Internal Install-Uploader' {
  InModuleScope Codecov {
    It 'has documentation' {
      Get-Help Install-Uploader | Out-String |
        Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
    }
    It 'supports -WhatIf and -Confirm' {
      Get-Command -Name Install-Uploader -Syntax |
        Should -Match '-Whatif.*-Confirm'
    }
    It 'pip is installed' {
      Test-Command 'pip --version' -Match 'python' | Should -BeTrue `
        -Because 'pip, the package installer for Python is required'
    }
    It 'Install-Uploader' {
      { Install-Uploader 2>$null } | Should -Not -Throw
    }
    It 'tests Check-Installed (install succeeded)' {
      Check-Installed | Should -BeTrue
    }
    Context 'Check-Installed = $true' {
      Mock Check-Installed { return $true } -ModuleName Codecov

      It 'runs without error' {
        { Install-Uploader -Verbose } | Should -Not -Throw
        Assert-MockCalled Check-Installed -Exactly 1 -Scope It
      }
      It 'should return $null' {
        Install-Uploader | Should -Be $null
      }
      It 'no WhatIf or confirmation' {
        Install-Uploader -WhatIf *>&1 | Should -Be $null `
          -Because 'immediate return'
      }
    }
    Context 'Check-Installed = $false' {
      Mock Check-Installed { return $false } -ModuleName Codecov
      Mock Send-Message { throw $Message } -ModuleName Codecov

      It 'throws when all attempts fail' {
        { Install-Uploader 2>$null 6>&1 } | Should -Throw
          Assert-MockCalled Send-Message -Exactly 1 -Scope It
      }
    }
  }
}

##====--------------------------------------------------------------------====##
Describe 'Internal Correct-BuildName' {
  InModuleScope Codecov {
    It 'has documentation' {
      Get-Help Correct-BuildName | Out-String |
        Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
    }
    It 'BuildName input required' {
      { Correct-BuildName } | Should -Throw 'BuildName is required'
    }
    It 'trim white-space' {
      Correct-BuildName '  Begin' | Should -MatchExactly 'Begin'
      Correct-BuildName 'End   ' | Should -MatchExactly 'End'
      Correct-BuildName "`tBegin" | Should -MatchExactly 'Begin'
      Correct-BuildName "End`t`t" | Should -MatchExactly 'End'
    }
    It 'replace spaces' {
      Correct-BuildName 'In Between    These' |
        Should -MatchExactly 'In_Between_These'
      Correct-BuildName 'Name Like This' | Should -MatchExactly 'Name_Like_This'
    }
    It 'replace tabs' {
      Correct-BuildName "In`tBetween" | Should -MatchExactly 'In_Between'
      Correct-BuildName "In`t`tBetween" | Should -MatchExactly 'In_Between'
      Correct-BuildName "In`t `tBetween" | Should -MatchExactly 'In_Between'
    }
  }
}

##====--------------------------------------------------------------------====##
Describe 'Internal Send-Report' {
  InModuleScope Codecov {
    It 'has documentation' {
      Get-Help Send-Report | Out-String |
        Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
    }
    It 'supports -WhatIf and -Confirm' {
      Get-Command -Name Send-Report -Syntax |
        Should -Match '-Whatif.*-Confirm'
    }
    It 'try WhatIf' {
      Send-Report -FilePath 'noFile' -BuildName 'placeholder' -WhatIf
    }
    Context 'Input Validation' {
      It 'throws on missing -FilePath' {
        { Send-Report -BuildName build } | Should -Throw '-FilePath is required'
      }
      It 'throws on missing -BuildName' {
        { Send-Report -FilePath 'aha' } | Should -Throw '-BuildName is required'
      }
      It 'throws on empty -FilePath' {
        { Send-Report -FilePath -BuildName build } |
          Should -Throw 'missing an argument'
      }
      It 'throws on empty -BuildName' {
        { Send-Report -FilePath path -BuildName } |
          Should -Throw 'missing an argument'
      }
      It 'throws on empty -FilePath 2' {
        { Send-Report -FilePath '' -BuildName build } |
          Should -Throw 'argument is null or empty'
      }
      It 'throws on empty -BuildName 2' {
        { Send-Report -FilePath path -BuildName '' } |
          Should -Throw 'argument is null or empty'
      }
      It 'throws on $null -FilePath' {
        { Send-Report -FilePath $null -BuildName build } |
          Should -Throw 'argument is null or empty'
      }
      It 'throws on $null -BuildName' {
        { Send-Report -FilePath path -BuildName $null } |
          Should -Throw 'argument is null or empty'
      }
      # $Flag AllowNull() and AllowEmptyString()
    }
  }
}

##====--------------------------------------------------------------------====##
Describe 'Send-Codecov' {
  It 'has documentation' {
    Get-Help Send-Codecov | Out-String |
      Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
  }
  Context 'Input Validation, Path' {
    Mock Send-Report { return $FilePath } -ModuleName Codecov
    It 'Path is mandatory' {
      { Send-Codecov -BuildName build } | Should -Throw '-Path is required'
    }
    It 'throws on missing path' {
      { Send-Codecov -Path } | Should -Throw 'Missing an argument'
    }
    It 'throws on an empty path' {
      # Confirmed difference between v5.1 and v6.1.2
      if ($PSVersionTable.PSVersion.Major -lt 6) {
        { Send-Codecov -Path '' -BuildName build } |
          Should -Throw 'argument is null or empty'
      } else {
        { Send-Codecov -Path '' -BuildName build } |
        Should -Throw 'argument is null, empty'
      }
    }
    It 'throws on $null path' {
      { Send-Codecov -Path $null -BuildName build } |
        Should -Throw 'argument is null or empty'
    }
    It 'throws on invalid pattern (single path)' {
      { Send-Codecov -Path 'report.html' -BuildName build 6>$null } |
        Should -Throw 'invalid pattern'
    }
    It 'no throw on invalid pattern (multiple paths)' {
      { Send-Codecov -Path @('report.html','ahaXml') -BuildName build 6>$null
      } | Should -Not -Throw
      Send-Codecov -Path @('report.html','ahaXml') -BuildName build 6>&1 |
        Should -Match 'Invalid pattern'
    }
    It 'throws on non-existing file (single path)' {
      { Send-Codecov -Path 'report.xml' -BuildName build 6>$null } |
        Should -Throw 'invalid path'
    }
    It 'no throw on non-existing file (multiple paths)' {
      { Send-Codecov -Path @('report.xml','report2.xml') -BuildName build `
        6>$null
      } | Should -Not -Throw
      Send-Codecov -Path @('report.xml','report2.xml') -BuildName build 6>&1 |
        Should -Match 'Invalid path'
    }
    In TestDrive:\ {
      New-Item -Path . -Name report.xml
      It 'non-existing file (multiple paths)' {
        { Send-Codecov -Path @('report.xml','report2.xml') -BuildName build `
          3>$null 6>$null
        } | Should -Not -Throw
        Send-Codecov -Path @('report.xml','report2.xml') -BuildName build `
          3>$null 6>&1 | Should -Match 'Invalid path'
      }
      It 'skips on empty file' {
        { Send-Codecov -Path 'report.xml' -BuildName build 3>$null } |
          Should -Not -Throw
        Send-Codecov -Path 'report.xml' -BuildName build 3>&1 |
          Should -Match 'empty file'
      }
      'text to fill file' > report.xml
      It 'valid call' {
        Send-Codecov -Path 'report.xml' -BuildName build |
          Should -Match '.*[\\/]report\.xml$'
      }
      It 'wild card characters' {
        Send-Codecov -Path 'r*.xml' -BuildName build |
          Should -Match '.*[\\/]report\.xml$'
      }
      It 'wild card characters 2' {
        Send-Codecov -Path 'r?port.xml' -BuildName build |
          Should -Match '.*[\\/]report\.xml$'
      }
      It 'Path separators' {
        Send-Codecov -Path './report.xml' -BuildName build |
          Should -Match '.*[\\/]report\.xml$'
        Send-Codecov -Path '.\report.xml' -BuildName build |
          Should -Match '.*[\\/]report\.xml$'
      }
    }
  }
  Context 'Input Validation, BuildName' {
    Mock Send-Report { return $BuildName } -ModuleName Codecov
    New-Item -Path TestDrive: -Name report.xml
    'text' > TestDrive:\report.xml
    It 'BuildName is mandatory' {
      { Send-Codecov -Path '.\*.xml' } | Should -Throw '-BuildName is required'
      Assert-MockCalled Send-Report -ModuleName Codecov -Exactly 0 -Scope It
    }
    It 'throws on missing BuildName' {
      { Send-Codecov -Path '.\*.xml' -BuildName } |
        Should -Throw 'Missing an argument'
    }
    It 'throws on an empty BuildName' {
      { Send-Codecov -Path '.\*.xml' -BuildName '' } |
        Should -Throw 'argument is null or empty'
    }
    It 'throws on $null BuildName' {
      { Send-Codecov -Path '.\*.xml' -BuildName $null } |
        Should -Throw 'argument is null or empty'
    }
    It 'valid call' {
      Send-Codecov 'TestDrive:\report.xml' -BuildName 'Name Like This 3' |
        Should -MatchExactly 'Name_Like_This_3'
    }
    It 'valid call (with -Flag)' {
      Send-Codecov 'TestDrive:\report.xml' -BuildName 'Name Like This 3' -Flag unit_tests_2 |
        Should -MatchExactly 'Name_Like_This_3'
    }
    Assert-MockCalled Send-Report -ModuleName Codecov -Exactly 2 -Scope Context
  }
  Context 'Input Validation, Flag' {
    Mock Send-Report { return $Flag } -ModuleName Codecov
    New-Item -Path TestDrive: -Name report.xml
    'text' > TestDrive:\report.xml
    It 'throws on empty Flag' {
      { Send-Codecov '.\*.xml' -BuildName build -Flag } |
        Should -Throw 'missing an argument'
    }
    It 'throws on empty Flag' {
      { Send-Codecov '.\*.xml' -BuildName build -Flag '' } |
        Should -Throw 'argument is null or empty'
    }
    It 'throws on $null Flag' {
      { Send-Codecov '.\*.xml' -BuildName build -Flag $null } |
        Should -Throw 'argument is null or empty'
    }
    It 'Flag takes no upper-case characters' {
      { Send-Codecov '.\*.xml' -BuildName build -Flag 'ABC' 6>$null } |
        Should -Throw 'invalid flag name'
    }
    It 'Flag takes no "-"' {
      { Send-Codecov '.\*.xml' -BuildName build -Flag 'a-c' 6>$null } |
        Should -Throw 'invalid flag name'
    }
    It 'Flag takes no special characters' {
      { Send-Codecov '.\*.xml' -BuildName build -Flag '#abc' 6>$null } |
        Should -Throw 'invalid flag name'
    }
    Assert-MockCalled Send-Report -ModuleName Codecov -Exactly 0 -Scope Context
    It 'Flag has a maximum length of 45 characters' {
      { Send-Codecov 'TestDrive:\report.xml' -BuildName build `
        -Flag 'abcdefghijklmnopqrstuvwxyz0123456789_abcdefgh'
      } | Should -Not -Throw
      { Send-Codecov 'TestDrive:\report.xml' -BuildName build `
        -Flag 'abcdefghijklmnopqrstuvwxyz0123456789_abcdefghi' 6>$null
      } | Should -Throw 'invalid flag name'
      Assert-MockCalled Send-Report -ModuleName Codecov -Exactly 1 -Scope It
    }
    It 'valid call' {
      Send-Codecov 'TestDrive:\report.xml' -BuildName build -Flag unit_tests_2 |
        Should -MatchExactly 'unit_tests_2'
      Assert-MockCalled Send-Report -ModuleName Codecov -Exactly 1 -Scope It
    }
  }
  Context 'Aliases' {
    Mock Send-Report { return $Path } -ModuleName Codecov
    New-Item -Path TestDrive: -Name report.xml
    'text' > TestDrive:\report.xml
    It 'Path alias: Report' {
      Send-Codecov -Report 'TestDrive:\report.xml' -BuildName build |
        Should -Match 'report.xml'
    }
    It 'Path alias: File' {
      Send-Codecov -File 'TestDrive:\Report.xml' -BuildName build |
        Should -Match 'report.xml'
    }
    It 'Path alias: FileName' {
      Send-Codecov -FileName 'TestDrive:\report.xml' -BuildName build |
        Should -Match 'report.xml'
    }
  }
}
