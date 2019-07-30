Import-Module -Name "${PSScriptRoot}\Codecov.psd1" -Force

Set-StrictMode -Version Latest

##====--------------------------------------------------------------------====##
$global:msg_documentation = 'at least 1 empty line above documentation'
$global:Codecov_token = 'd6c1c65d-1656-4321-a080-e0a0eee9a613'

##====--------------------------------------------------------------------====##
Describe 'Internal Check-Installed' {
  InModuleScope Send-Codecov {
    It 'has documentation' {
      Get-Help Check-Installed | Out-String |
        Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
    }
    Context 'Test-Command: $false; uploader is not installed' {
      Mock Test-Command { return $false } -ModuleName Send-Codecov

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
      Mock Test-Command { return $true } -ModuleName Send-Codecov

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
  InModuleScope Send-Codecov {
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

    Context 'Mock: Check-Installed' {
      [Int]$script:counter = 0
      [Int]$script:first_true = 2
      Mock Check-Installed {
        $script:counter += 1
        if ($counter -lt $first_true) { return $false }
        else { return $true }
      } -ModuleName Send-Codecov
      # Suppress output to the Appveyor Message API.
      Mock Assert-CI { return $false } -ModuleName Send-Message

      It 'returns $null when already installed' {
        $script:counter = 0
        $script:first_true = 1
        { Install-Uploader } | Should -not -Throw
        Assert-MockCalled Check-Installed -Exactly 1 -Scope It
        $script:counter = 0
        Install-Uploader | Should -Be $null
        $script:counter = 0
        Install-Uploader -WhatIf *>&1 | Should -Be $null `
          -Because 'immediate return'
      }
      It 'succeed on first try' {
        $script:counter = 0
        $script:first_true = 2
        { Install-Uploader } | Should -not -Throw
        $script:counter = 0
        Install-Uploader | Should -Be $null
        $script:counter = 0
        $out = (Install-Uploader -Verbose 1>$null) 4>&1
        $out[0] | Should -Match '^Installing'
        $out[1] | Should -Match '^Installing.*done'
      }
      It 'installed in user profile' {
        $script:counter = 0
        $script:first_true = 3
        { Install-Uploader } | Should -not -Throw
        $script:counter = 0
        Install-Uploader | Should -Be $null
        $script:counter = 0
        $out = (Install-Uploader -Verbose 1>$null) 4>&1
        $out[0] | Should -Match '^Installing'
        $out[1] | Should -Match '^Retry in user profile'
        $out[2] | Should -Match '^Installing.*done'
      }
      It 'throws when all attempts fail' {
        $script:counter = 0
        $script:first_true = 1000
        { Install-Uploader 2>$null 6>&1 } | Should -Throw
        Assert-MockCalled Check-Installed -Exactly 3 -Scope It
      }
      It '-WhatIf, no throw; no installation' {
        $script:counter = 0
        $script:first_true = 1000
        { Install-Uploader -Whatif } | Should -not -Throw
        Assert-MockCalled Check-Installed -Exactly 1 -Scope It
      }
    }
  }
}

##====--------------------------------------------------------------------====##
Describe 'Internal Correct-BuildName' {
  InModuleScope Send-Codecov {
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
  InModuleScope Send-Codecov {
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
      # $Token AllowEmptyString()
    }
    Context 'WhatIf' {
      It 'BuildName' {
        Send-Report -FilePath 'noFile' -BuildName 'placeholder' -WhatIf `
          -Verbose 4>&1 | Should -Match ' --name placeholder( |$)'
      }
      It 'FilePath' {
        $out = Send-Report -FilePath 'no File' -BuildName 'placeholder' `
          -WhatIf -Verbose 4>&1
        $out | Should -Match ' --file "no File"( |$)'
        $out | Should -Match ' -X ([a-z]+ )?gcov( |$)'
      }
      It 'Flags' {
        Send-Report -FilePath 'no File' -BuildName 'placeholder' `
          -Flags @('some', 'more flags') -WhatIf -Verbose 4>&1 |
          Should -Match ' --flags some more flags( |$)'
      }
    }
    Context 'Mock not CI' {
      Mock Assert-CI { return $false } -ModuleName Send-Codecov
      It 'try WhatIf' {
        Send-Report -FilePath 'noFile' -BuildName 'placeholder' -WhatIf `
          -Verbose 4>&1 | Should -Match ' -X ([a-z]+ )?detect( |$)'
      }
      It 'Token' {
        Send-Report -FilePath 'no File' -BuildName 'placeholder' `
          -Token $Codecov_token -WhatIf -Verbose 4>&1 |
          Should -Match (' --token ' + $Codecov_token + '( |$)')
      }
    }
  } # InModuleScope Send-Codecov
} # Describe 'Internal Send-Report'

##====--------------------------------------------------------------------====##

function Require-CodecovInstalled {
  if (-not $global:CodecovInstalled) {
    Set-ItResult -Inconclusive -Because 'Install failure codecov uploader.'
  }
}

##====--------------------------------------------------------------------====##
Describe 'Send-Codecov' {
  It 'has documentation' {
    Get-Help Send-Codecov | Out-String |
      Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
  }
  Context 'Input Validation, Path' {
    Mock Send-Report { return $FilePath } -ModuleName Send-Codecov
    # Suppress output to the Appveyor Message API.
    Mock Assert-CI { return $false } -ModuleName Send-Message

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
      Require-CodecovInstalled
      { Send-Codecov -Path 'report.html' -BuildName build 6>$null } |
        Should -Throw 'invalid pattern'
    }
    It 'no throw on invalid pattern (multiple paths)' {
      Require-CodecovInstalled
      { Send-Codecov -Path @('report.html','ahaXml') -BuildName build 6>$null
      } | Should -Not -Throw
      Send-Codecov -Path @('report.html','ahaXml') -BuildName build 6>&1 |
        Should -Match 'Invalid pattern'
    }
    It 'throws on non-existing file (single path)' {
      Require-CodecovInstalled
      { Send-Codecov -Path 'report.xml' -BuildName build 6>$null } |
        Should -Throw 'invalid path'
    }
    It 'no throw on non-existing file (multiple paths)' {
      Require-CodecovInstalled
      { Send-Codecov -Path @('report.xml','report2.xml') -BuildName build `
        6>$null
      } | Should -Not -Throw
      Send-Codecov -Path @('report.xml','report2.xml') -BuildName build 6>&1 |
        Should -Match 'Invalid path'
    }
    In TestDrive:\ {
      New-Item -Path . -Name report.xml
      It 'non-existing file (multiple paths)' {
        Require-CodecovInstalled
        { Send-Codecov -Path @('report.xml','report2.xml') -BuildName build `
          3>$null 6>$null
        } | Should -Not -Throw
        Send-Codecov -Path @('report.xml','report2.xml') -BuildName build `
          3>$null 6>&1 | Should -Match 'Invalid path'
      }
      It 'skips on empty file' {
        Require-CodecovInstalled
        { Send-Codecov -Path 'report.xml' -BuildName build 3>$null } |
          Should -Not -Throw
        Send-Codecov -Path 'report.xml' -BuildName build 3>&1 |
          Should -Match 'empty file'
      }
      'text to fill file' > report.xml
      It 'valid call' {
        Require-CodecovInstalled
        Send-Codecov -Path 'report.xml' -BuildName build |
          Should -Match '.*[\\/]report\.xml$'
      }
      It 'wild card characters' {
        Require-CodecovInstalled
        Send-Codecov -Path 'r*.xml' -BuildName build |
          Should -Match '.*[\\/]report\.xml$'
      }
      It 'wild card characters 2' {
        Require-CodecovInstalled
        Send-Codecov -Path 'r?port.xml' -BuildName build |
          Should -Match '.*[\\/]report\.xml$'
      }
      It 'Path separators' {
        Require-CodecovInstalled
        Send-Codecov -Path './report.xml' -BuildName build |
          Should -Match '.*[\\/]report\.xml$'
        Send-Codecov -Path '.\report.xml' -BuildName build |
          Should -Match '.*[\\/]report\.xml$'
      }
    } # In TestDrive:\
    It 'throws on $null or empty Flag' {
      { Send-Codecov '.\*.xml' -BuildName build -Flag } |
        Should -Throw 'missing an argument'
      { Send-Codecov '.\*.xml' -BuildName build -Flag '' } |
        Should -Throw 'argument is null or empty'
      { Send-Codecov '.\*.xml' -BuildName build -Flag $null } |
        Should -Throw 'argument is null or empty'
    }
    It 'throws on an $null or empty Token' {
      { Send-Codecov -Path 'report.xml' -BuildName build -Token } |
        Should -Throw 'missing an argument'
      { Send-Codecov -Path 'report.xml' -BuildName build -Token '' } |
        Should -Throw 'argument is null or empty'
      { Send-Codecov -Path 'report.xml' -BuildName build -Token $null } |
        Should -Throw 'argument is null or empty'
    }
  }
  Context 'Input Validation, BuildName' {
    Mock Send-Report { return $BuildName } -ModuleName Send-Codecov
    New-Item -Path TestDrive: -Name report.xml
    'text' > TestDrive:\report.xml
    It 'BuildName is mandatory' {
      { Send-Codecov -Path '.\*.xml' } | Should -Throw '-BuildName is required'
      Assert-MockCalled Send-Report -ModuleName Send-Codecov -Exactly 0 `
        -Scope It
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
      Require-CodecovInstalled
      Send-Codecov 'TestDrive:\report.xml' -BuildName 'Name Like This 3' |
        Should -MatchExactly 'Name_Like_This_3'
    }
    It 'valid call (with -Flag)' {
      Require-CodecovInstalled
      Send-Codecov 'TestDrive:\report.xml' -BuildName 'Name Like This 3' `
        -Flag unit_tests_2 | Should -MatchExactly 'Name_Like_This_3'
    }
    if ($CodecovInstalled) {
      Assert-MockCalled Send-Report -ModuleName Send-Codecov -Exactly 2 `
        -Scope Context
    }
  }
  Context 'Input Validation, Flag' {
    # Suppress output to the Appveyor Message API.
    Mock Assert-CI { return $false } -ModuleName Send-Message
    Mock Send-Report { return $Flag } -ModuleName Send-Codecov
    New-Item -Path TestDrive: -Name report.xml
    'text' > TestDrive:\report.xml

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
    Assert-MockCalled Send-Report -ModuleName Send-Codecov -Exactly 0 `
      -Scope Context
    It 'Flag has a maximum length of 45 characters' {
      Require-CodecovInstalled
      { Send-Codecov 'TestDrive:\report.xml' -BuildName build `
        -Flag 'abcdefghijklmnopqrstuvwxyz0123456789_abcdefgh'
      } | Should -Not -Throw
      { Send-Codecov 'TestDrive:\report.xml' -BuildName build `
        -Flag 'abcdefghijklmnopqrstuvwxyz0123456789_abcdefghi' 6>$null
      } | Should -Throw 'invalid flag name'
      Assert-MockCalled Send-Report -ModuleName Send-Codecov -Exactly 1 `
        -Scope It
    }
    It 'valid call' {
      Require-CodecovInstalled
      Send-Codecov 'TestDrive:\report.xml' -BuildName build -Flag unit_tests_2 |
        Should -MatchExactly 'unit_tests_2'
      Assert-MockCalled Send-Report -ModuleName Send-Codecov -Exactly 1 `
        -Scope It
    }
  }
  Context 'Input validation Token' {
    In TestDrive:\ {
      Mock Assert-CI { return $false } -ModuleName Send-Message
      Mock Send-Report { return $Token } -ModuleName Send-Codecov
      New-Item -Path TestDrive:\ -Name report.xml
      'text' > report.xml
      New-Item -Name token_file
      $global:Codecov_token > token_file

      It 'existence token file' {
        { Send-Codecov '.\*.xml' -BuildName build -Token '@ABC' 6>$null } |
          Should -Throw 'Invalid file path for Codecov token'
        { Send-Codecov '.\*.xml' -BuildName build -Token '@token_file' 6>$null } |
          Should -not -Throw
        Send-Codecov '.\*.xml' -BuildName build -Token '@token_file' |
          Should -Be '@token_file'
      }
      It 'valid token format' {
        { Send-Codecov '.\*.xml' -BuildName build -Token $Codecov_token `
          6>$null } | Should -not -Throw
        { Send-Codecov '.\*.xml' -BuildName build -Token 'aaale55-ew' `
          6>$null } | Should -Throw 'Invalid Codecov token format'
        Send-Codecov '.\*.xml' -BuildName build -Token $Codecov_token |
          Should -Be $Codecov_token
      }
    }
  }
  Context 'Aliases' {
    Mock Send-Report { return $Path } -ModuleName Send-Codecov
    New-Item -Path TestDrive: -Name report.xml
    'text' > TestDrive:\report.xml
    It 'Path alias: Report' {
      Require-CodecovInstalled
      Send-Codecov -Report 'TestDrive:\report.xml' -BuildName build |
        Should -Match 'report.xml'
    }
    It 'Path alias: File' {
      Require-CodecovInstalled
      Send-Codecov -File 'TestDrive:\Report.xml' -BuildName build |
        Should -Match 'report.xml'
    }
    It 'Path alias: FileName' {
      Require-CodecovInstalled
      Send-Codecov -FileName 'TestDrive:\report.xml' -BuildName build |
        Should -Match 'report.xml'
    }
  }
}
$global:Codecov_token = ''
