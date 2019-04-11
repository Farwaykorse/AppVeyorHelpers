## Ensure the function is available
Import-Module -Name "${PSScriptRoot}\Convert-FileEncoding.psm1" -Force

Set-StrictMode -Version Latest

##====--------------------------------------------------------------------====##
$global:msg_documentation = 'at least 1 empty line above documentation'

##====--------------------------------------------------------------------====##
Describe 'Internal Get-EndOfLineCount' {
  InModuleScope Convert-FileEncoding {
    It 'has documentation' {
      Get-Help Get-EndOfLineCount | Out-String |
        Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
    }
    It 'supports -WhatIf and -Confirm' {
      Get-Command -Name Convert-FileEncoding -Syntax |
        Should -Match '-Whatif.*-Confirm'
    }
    Context 'specific -LineEnding' {
      It 'count Unix' {
        Get-EndOfLineCount "some`n" Unix | Should -Be 1
        Get-EndOfLineCount "`nAft" Unix | Should -Be 1
        Get-EndOfLineCount "`n" Unix | Should -Be 1
        Get-EndOfLineCount "`n`nAft" Unix | Should -Be 2
        Get-EndOfLineCount "At`r`nSome" Unix | Should -Be 0
        Get-EndOfLineCount "At`n`nSome" Unix | Should -Be 2
        Get-EndOfLineCount "At`r`n" Unix | Should -Be 0
        Get-EndOfLineCount "`n`nAft`r`nSome`n" Unix | Should -Be 3
      }
      It 'count Windows' {
        Get-EndOfLineCount "some`r`n" Windows | Should -Be 1
        Get-EndOfLineCount "`r`n`nAft" Windows | Should -Be 1
        Get-EndOfLineCount "`r`n" Windows | Should -Be 1
        Get-EndOfLineCount "some`n`r`n" Windows | Should -Be 1
        Get-EndOfLineCount "At`r`nSome" Windows | Should -Be 1
        Get-EndOfLineCount "At`r`r`nSome" Windows | Should -Be 1
        Get-EndOfLineCount "At`r`n`rSome" Windows | Should -Be 1
        Get-EndOfLineCount "`r`n`nAft`r`nSome`n`r`n" Windows | Should -Be 3
      }
      It 'count Cr' {
        Get-EndOfLineCount "some`r" Cr | Should -Be 1
        Get-EndOfLineCount "`rAft" Cr | Should -Be 1
        Get-EndOfLineCount "`r" Cr | Should -Be 1
        Get-EndOfLineCount "`r`n`nAft`r`nSome`n`r" Cr | Should -Be 1
        Get-EndOfLineCount "`n`nAft`r`nSome`r`n" Cr | Should -Be 0
        Get-EndOfLineCount "`n`nAft`r`r`nSome`r`n" Cr | Should -Be 1
      }
    }
    Context 'return all counts' {
      It 'Unix only' {
          $Count = Get-EndOfLineCount "`n`nX`nSome`n"
        $Count.CRLF | Should -Be 0
        $Count.LF | Should -Be 4
        $Count.CR | Should -Be 0
      }
      It 'Windows only' {
          $Count = Get-EndOfLineCount "`r`nX`r`nSome`r`n"
        $Count.CRLF | Should -Be 3
        $Count.LF | Should -Be 0
        $Count.CR | Should -Be 0
      }
      It 'CR only' {
          $Count = Get-EndOfLineCount "`r`rX`rSome`r"
        $Count.CRLF | Should -Be 0
        $Count.LF | Should -Be 0
        $Count.CR | Should -Be 4
      }
      It 'mixed' {
          $Count = Get-EndOfLineCount "`r`r`nX`n`n`rSome`r"
        $Count.CRLF | Should -Be 1
        $Count.LF | Should -Be 2
        $Count.CR | Should -Be 3
      }
    }
    Context 'Input Errors' {
      It 'Mandatory parameter -Text' {
        { Get-EndOfLineCount } | Should -Throw 'Text is a required parameter'
        { Get-EndOfLineCount -LineEnding LF } |
          Should -Throw 'Text is a required parameter'
      }
      It 'Throw on missing Text input' {
        { Get-EndOfLineCount -Text } | Should -Throw 'Missing an argument'
      }
      It 'Allow empty Text input' {
        { Get-EndOfLineCount -Text '' } | Should -Not -Throw
        Get-EndOfLineCount -Text '' -LineEnding LF | Should -Be 0
      }
      It 'Allow $null Text input' {
        { Get-EndOfLineCount -Text $null } | Should -Not -Throw
      }
      It 'Throw for empty Preferred Line Ending' {
        { Get-EndOfLineCount "`r" -LineEnding } |
          Should -Throw 'Missing an argument'
      }
      It 'Throw for empty Preferred Line Ending' {
        { Get-EndOfLineCount "`r" -LineEnding '' } |
          Should -Throw 'argument is null or empty'
      }
      It 'Throw for $null Preferred Line Ending' {
        { Get-EndOfLineCount "`r" -LineEnding $null } |
          Should -Throw 'argument is null or empty'
      }
      It 'Throw for unknown line ending choice' {
        { Get-EndOfLineCount "`n" Wrong } |
          Should -Throw 'Unexpected LineEnding'
      }
    }
  }
}

##====--------------------------------------------------------------------====##
Describe 'Internal Test-NeedProcessing' {
  InModuleScope Convert-FileEncoding {
    It 'has documentation' {
      Get-Help Test-NeedProcessing | Out-String |
        Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
    }
     Context 'no preference' {
       It 'Text with no EOL' {
         Test-NeedProcessing 'some text' | Should -Be $false
       }
       It 'Empty file' {
         Test-NeedProcessing '' | Should -Be $false
       }
       It 'Text with consistent EOL' {
         Test-NeedProcessing "before`n" | Should -Be $false
         Test-NeedProcessing "`nAft" | Should -Be $false
         Test-NeedProcessing "`n" | Should -Be $false
         Test-NeedProcessing "`n`nAft" | Should -Be $false
         Test-NeedProcessing "`r`rAt" | Should -Be $false
         Test-NeedProcessing "`r`nAft" | Should -Be $false
         Test-NeedProcessing "At`r`nSome`r`n" | Should -Be $false
         Test-NeedProcessing "At`n`nSome" | Should -Be $false
         Test-NeedProcessing "At`r`n" | Should -Be $false
       }
       It 'Text with mixed EOL' {
         Test-NeedProcessing "`noise`r`noise`n" 6>$null | Should -Be $true
         Test-NeedProcessing "`n`noise`r`noise`n" 6>$null | Should -Be $true
         Test-NeedProcessing "`n`noise`right some`n" 6>$null | Should -Be $true
         Test-NeedProcessing "`n`noise`r`r some`n" 6>$null | Should -Be $true
       }
     }
     Context 'with preference' {
       It 'Text with consistent desired EOL' {
         Test-NeedProcessing "At`n`nSome`n`n" Unix | Should -Be $false
         Test-NeedProcessing "At`n`nSome`n`n" Lf | Should -Be $false
         Test-NeedProcessing "At`r some`r`r" Cr | Should -Be $false
         Test-NeedProcessing "At`r`nSome`r`n" Windows | Should -Be $false
         Test-NeedProcessing "At`r`nSome`r`n" CrLF | Should -Be $false
       }
       It 'Text with consistent undesired EOL' {
         Test-NeedProcessing "At`n`nSome`n`n" Windows | Should -Be $true
         Test-NeedProcessing "At`n`nSome`n`n" cr | Should -Be $true
         Test-NeedProcessing "At`r some`r`r" Windows | Should -Be $true
         Test-NeedProcessing "At`r some`r`r" Lf | Should -Be $true
         Test-NeedProcessing "At`r`nSome`r`n" Unix | Should -Be $true
         Test-NeedProcessing "At`r`nSome`r`n" Cr | Should -Be $true
       }
       It 'Text with mixed EOL and desired EOL' {
         Test-NeedProcessing "`noise`r`noise`n" Unix 6>$null | Should -Be $true
         Test-NeedProcessing "`n`noise`r`noise`n" LF 6>$null | Should -Be $true
         Test-NeedProcessing "`n`noise`r`noise`n" Windows 6>$null |
           Should -Be $true
         Test-NeedProcessing "`n`noise`right some`n" CRLF 6>$null |
           Should -Be $true
         Test-NeedProcessing "`n`noise`r`r some`n" CR 6>$null | Should -Be $true
       }
     }
     Context 'Input Errors' {
       It 'Mandatory parameter -Text' {
         { Test-NeedProcessing } | Should -Throw 'Text is a required parameter'
         { Test-NeedProcessing -LineEnding Unix } |
           Should -Throw 'Text is a required parameter'
       }
       It 'Throw on missing Text input' {
         { Test-NeedProcessing -Text } | Should -Throw 'Missing an argument'
       }
       It 'Allow empty Text input' {
         { Test-NeedProcessing -Text '' } | Should -Not -Throw
         { Test-NeedProcessing -Text $null } | Should -Not -Throw
       }
       It 'Throw for empty Preferred Line Ending' {
         { Test-NeedProcessing "`r" -LineEnding } |
           Should -Throw 'Missing an argument'
       }
       It 'Throw for empty Preferred Line Ending' {
         { Test-NeedProcessing "`r" -LineEnding '' } |
           Should -Throw 'does not belong to the set'
       }
       It 'Throw for empty Preferred Line Ending' {
         { Test-NeedProcessing "`r" -LineEnding $null } |
           Should -Throw 'does not belong to the set'
       }
       It 'Throw for unknown line ending choice' {
         { Test-NeedProcessing "`n" Wrong } |
           Should -Throw 'does not belong to the set'
       }
     }
  }
}

##====--------------------------------------------------------------------====##
Describe 'Internal Convert-EOL' {
  InModuleScope Convert-FileEncoding {
    It 'has documentation' {
      Get-Help Convert-EOL | Out-String |
        Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
    }
    It 'supports -WhatIf and -Confirm' {
      Get-Command -Name Convert-EOL -Syntax |
        Should -Match '-Whatif.*-Confirm'
    }
    Context 'Input Errors' {
      It 'Mandatory parameter -Text' {
        { Convert-EOL -LineEnding LF } |
          Should -Throw 'Text is a required parameter'
      }
      It 'Throw on missing -Text input' {
        { Convert-EOL -Text -LineEnding LF } |
          Should -Throw 'Missing an argument'
      }
      It 'Throw for empty -Text' {
        { Convert-EOL -Text '' -LineEnding LF } |
          Should -Throw 'argument is null or empty'
      }
      It 'Throw for $null -Text' {
        { Convert-EOL $null -LineEnding LF } |
          Should -Throw 'argument is null or empty'
      }
      It 'Mandatory parameter -LineEnding' {
        { Convert-EOL -Text 'some text' } |
          Should -Throw 'LineEnding is a required parameter'
      }
      It 'Throw on missing -LineEnding input' {
        { Convert-EOL -Text 'some text' -LineEnding } |
          Should -Throw 'Missing an argument'
      }
      It 'Throw for empty -LineEnding' {
        { Convert-EOL 'some text' -LineEnding '' } |
          Should -Throw 'argument is null or empty'
      }
      It 'Throw for $null -LineEnding' {
        { Convert-EOL 'some text' -LineEnding $null } |
          Should -Throw 'argument is null or empty'
      }
      It 'Throw for unknown -LineEnding input' {
        { Convert-EOL 'some text' -LineEnding unknown } |
          Should -Throw 'Unknown LineEnding input'
      }
      It 'Should not throw on valid input' {
        $SourcePath = 'placeholder'
        { Convert-EOL 'some text' -LineEnding Unix } | Should -Not -Throw
        { Convert-EOL 'some text' -LineEnding LF } | Should -Not -Throw
        { Convert-EOL 'some text' -LineEnding Windows } | Should -Not -Throw
        { Convert-EOL 'some text' -LineEnding CRLF } | Should -Not -Throw
        { Convert-EOL 'some text' -LineEnding CR } | Should -Not -Throw
      }
    }
    Context 'Operation' {
      $SourcePath = 'placeholder'
      It 'no newline characters' {
        Convert-EOL 'no new-line characters' Unix |
          Should -BeExactly 'no new-line characters'
      }
      It 'CRLF to LF' {
        Convert-EOL "last`r`n" Unix | Should -BeExactly "last`n"
        Convert-EOL "`r`nFirst" Unix | Should -BeExactly "`nFirst"
        Convert-EOL "`r`nMiddle`r`n" Unix | Should -BeExactly "`nMiddle`n"
        Convert-EOL "`r`n`r`nMultiple" Unix | Should -BeExactly "`n`nMultiple"
        Convert-EOL "`r`nMiddle`r`n" LF | Should -BeExactly "`nMiddle`n"
      }
      It 'CRLF to CR' {
        Convert-EOL "last`r`n" Cr | Should -BeExactly "last`r"
        Convert-EOL "`r`nFirst" Cr | Should -BeExactly "`rFirst"
        Convert-EOL "`r`nMiddle`r`n" Cr | Should -BeExactly "`rMiddle`r"
        Convert-EOL "`r`n`r`nMultiple" Cr | Should -BeExactly "`r`rMultiple"
      }
      It 'CRLF to self' {
        Convert-EOL "last`r`n" Windows | Should -BeExactly "last`r`n"
        Convert-EOL "`r`nFirst" Windows | Should -BeExactly "`r`nFirst"
        Convert-EOL "`r`nMiddle`r`n" Windows |
          Should -BeExactly "`r`nMiddle`r`n"
        Convert-EOL "`r`n`r`nMultiple" Windows |
          Should -BeExactly "`r`n`r`nMultiple"
        Convert-EOL "`r`nMiddle`r`n" CRLF | Should -BeExactly "`r`nMiddle`r`n"
      }
      It 'LF to self' {
        Convert-EOL "last`n" Unix | Should -BeExactly "last`n"
        Convert-EOL "`nFirst" Unix | Should -BeExactly "`nFirst"
        Convert-EOL "`nMiddle`n" Unix | Should -BeExactly "`nMiddle`n"
        Convert-EOL "`n`nMultiple" Unix | Should -BeExactly "`n`nMultiple"
        Convert-EOL "`nMiddle`n" LF | Should -BeExactly "`nMiddle`n"
      }
      It 'LF to CR' {
        Convert-EOL "last`n" Cr | Should -BeExactly "last`r"
        Convert-EOL "`nFirst" Cr | Should -BeExactly "`rFirst"
        Convert-EOL "`nMiddle`n" Cr | Should -BeExactly "`rMiddle`r"
        Convert-EOL "`n`nMultiple" Cr | Should -BeExactly "`r`rMultiple"
      }
      It 'LF to CRLF' {
        Convert-EOL "last`n" Windows | Should -BeExactly "last`r`n"
        Convert-EOL "`nFirst" Windows | Should -BeExactly "`r`nFirst"
        Convert-EOL "`nMiddle`n" Windows | Should -BeExactly "`r`nMiddle`r`n"
        Convert-EOL "`n`nMultiple" Windows |
          Should -BeExactly "`r`n`r`nMultiple"
        Convert-EOL "`nMiddle`n" CRLF | Should -BeExactly "`r`nMiddle`r`n"
      }
      It 'CR to LF' {
        Convert-EOL "last`r" Unix | Should -BeExactly "last`n"
        Convert-EOL "`rFirst" Unix | Should -BeExactly "`nFirst"
        Convert-EOL "`rMiddle`r`n" Unix | Should -BeExactly "`nMiddle`n"
        Convert-EOL "`r`rMultiple" Unix | Should -BeExactly "`n`nMultiple"
        Convert-EOL "`rMiddle`r" LF | Should -BeExactly "`nMiddle`n"
      }
      It 'CR to self' {
        Convert-EOL "last`r" Cr | Should -BeExactly "last`r"
        Convert-EOL "`rFirst" Cr | Should -BeExactly "`rFirst"
        Convert-EOL "`rMiddle`r" Cr | Should -BeExactly "`rMiddle`r"
        Convert-EOL "`r`rMultiple" Cr | Should -BeExactly "`r`rMultiple"
      }
      It 'CR to CRLF' {
        Convert-EOL "last`r" Windows | Should -BeExactly "last`r`n"
        Convert-EOL "`rFirst" Windows | Should -BeExactly "`r`nFirst"
        Convert-EOL "`rMiddle`r" Windows | Should -BeExactly "`r`nMiddle`r`n"
        Convert-EOL "`r`rMultiple" Windows |
          Should -BeExactly "`r`n`r`nMultiple"
        Convert-EOL "`rMiddle`r" CRLF | Should -BeExactly "`r`nMiddle`r`n"
      }
    }
    Context '-WhatIf' {
      $SourcePath = 'placeholder'
      It 'CR to CRLF' {
        Convert-EOL "last`r" Windows -WhatIf | Should -BeExactly "last`r"
      }
    }
    Context 'Input from pipeline' {
      $SourcePath = 'placeholder'
      It 'Do not throw for -Text from pipeline' {
        { 'some text' | Convert-EOL -LineEnding LF } |
          Should -Not -Throw
      }
      It 'Throw for empty -Text from pipeline' {
        Set-ItResult -Pending -Because 'Need to catch and process the error.'
      }
      It 'from pipeline: no change' {
        'no change1','no change2' | Convert-EOL -LineEnding LF |
          Should -Be @('no change1','no change2')
      }
      It 'from pipeline: CRLF to LF' {
        "last`r`n","`r`nFirst","`r`nMiddle`r`n","`r`n`r`nMultiple" |
          Convert-EOL -LineEnding Unix | Should -BeExactly @(
            "last`n","`nFirst","`nMiddle`n","`n`nMultiple"
          )
      }
      It 'from pipeline: CRLF to CR' {
        "last`r`n","`r`nFirst","`r`nMiddle`r`n","`r`n`r`nMultiple" |
          Convert-EOL -LineEnding Cr | Should -BeExactly @(
            "last`r","`rFirst","`rMiddle`r","`r`rMultiple"
          )
      }
      It 'from pipeline: CRLF to self' {
        "last`r`n","`r`nFirst","`r`nMiddle`r`n","`r`n`r`nMultiple" |
          Convert-EOL -LineEnding Windows | Should -BeExactly @(
            "last`r`n","`r`nFirst","`r`nMiddle`r`n","`r`n`r`nMultiple"
          )
      }
      It 'from pipeline: LF to self' {
        "last`n","`nFirst","`nMiddle`n","`n`nMultiple" |
          Convert-EOL -LineEnding Unix | Should -BeExactly @(
            "last`n","`nFirst","`nMiddle`n","`n`nMultiple"
          )
      }
      It 'from pipeline: LF to CR' {
        "last`n","`nFirst","`nMiddle`n","`n`nMultiple" |
          Convert-EOL -LineEnding Cr | Should -BeExactly @(
            "last`r","`rFirst","`rMiddle`r","`r`rMultiple"
          )
      }
      It 'from pipeline: LF to CRLF' {
        "last`n","`nFirst","`nMiddle`n","`n`nMultiple" |
          Convert-EOL -LineEnding Windows | Should -BeExactly @(
            "last`r`n","`r`nFirst","`r`nMiddle`r`n","`r`n`r`nMultiple"
          )
      }
      It 'from pipeline: CR to LF' {
        "last`r","`rFirst","`rMiddle`r","`r`rMultiple" |
          Convert-EOL -LineEnding Unix | Should -BeExactly @(
            "last`n","`nFirst","`nMiddle`n","`n`nMultiple"
          )
      }
      It 'from pipeline: CR to self' {
        "last`r","`rFirst","`rMiddle`r","`r`rMultiple" |
          Convert-EOL -LineEnding Cr | Should -BeExactly @(
            "last`r","`rFirst","`rMiddle`r","`r`rMultiple"
          )
      }
      It 'from pipeline: CR to CRLF' {
        "last`r","`rFirst","`rMiddle`r","`r`rMultiple" |
          Convert-EOL -LineEnding Windows | Should -BeExactly @(
            "last`r`n","`r`nFirst","`r`nMiddle`r`n","`r`n`r`nMultiple"
          )
      }
    }
  }
}

##====--------------------------------------------------------------------====##
# Helper function.
# Call Convert-FileEncoding in different scope, to prevent re-invoking Pester.
function Invoke-BackgroundPwsh {
  param(
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path -LiteralPath "$_" })]
    $Path,
    [ValidateNotNullOrEmpty()]
    $Encoding,
    $LineEnding
  )
  if ($LineEnding) {
    if ($Encoding) {
      Convert-FileEncoding -Path:$Path -Encoding:$Encoding `
        -LineEnding:$LineEnding
    } else {
      Convert-FileEncoding -Path:$Path -LineEnding:$LineEnding
    }
  } elseif ($Encoding) {
    Convert-FileEncoding -Path:$Path -Encoding:$Encoding
  } else {
    Convert-FileEncoding -Path:$Path
  }
}

Describe 'Convert-FileEncoding' {
  # Temporary working directory (Pesters TestDrive:\)
  New-Item -Path TestDrive:\ -Name file.txt
  'some text with Unicode ʩ' > TestDrive:\file.txt

  It 'has documentation' {
    Get-Help Convert-FileEncoding | Out-String |
      Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
  }
  Context 'Input Errors' {
    It 'Mandatory parameter -SourcePath' {
      { Convert-FileEncoding } |
        Should -Throw 'SourcePath is a required parameter'
      { Convert-FileEncoding -Encoding UTF8 -LineEnding Unix } |
        Should -Throw 'SourcePath is a required parameter'
      { Convert-FileEncoding -Encoding UTF8 } |
        Should -Throw 'SourcePath is a required parameter'
    }
    It 'Throw on missing SourcePath input' {
      { Convert-FileEncoding -SourcePath } | Should -Throw 'Missing an argument'
    }
    It 'Throw for empty SourcePath input' {
      { Convert-FileEncoding -SourcePath '' } |
        Should -Throw 'argument is null or empty'
    }
    It 'Throw for $null SourcePath input' {
      { Convert-FileEncoding -SourcePath $null } |
        Should -Throw 'argument is null or empty'
    }
    It 'Throw for non-existing SourcePath' {
      { Convert-FileEncoding -SourcePath 'TestDrive:\wrong.txt' } |
        Should -Throw 'validation script'
    }
    It 'Throw on missing Encoding input' {
      { Convert-FileEncoding -SourcePath 'TestDrive:\file.txt' -Encoding } |
        Should -Throw 'Missing an argument'
    }
    It 'Throw for empty Encoding input' {
      { Convert-FileEncoding -SourcePath 'TestDrive:\file.txt' -Encoding '' } |
        Should -Throw 'does not belong to the set'
    }
    It 'Throw for $null Encoding input' {
      { Convert-FileEncoding -SourcePath 'TestDrive:\file.txt' `
        -Encoding $null } | Should -Throw 'does not belong to the set'
    }
    It 'Throw for unknown Encoding input' {
      { Convert-FileEncoding -SourcePath 'TestDrive:\file.txt' `
        -Encoding WrongInSomeWay } | Should -Throw 'does not belong to the set'
    }
    It 'Throw for unsupported Encoding input' {
      { Convert-FileEncoding -SourcePath 'TestDrive:\file.txt' `
        -Encoding Default } | Should -Throw 'does not belong to the set'
      { Convert-FileEncoding -SourcePath 'TestDrive:\file.txt' `
        -Encoding OEM } | Should -Throw 'does not belong to the set'
      { Convert-FileEncoding -SourcePath 'TestDrive:\file.txt' `
        -Encoding Byte } | Should -Throw 'does not belong to the set'
      { Convert-FileEncoding -SourcePath 'TestDrive:\file.txt' `
        -Encoding UTF7 } | Should -Throw 'does not belong to the set'
      { Convert-FileEncoding -SourcePath 'TestDrive:\file.txt' `
        -Encoding UTF32 } | Should -Throw 'does not belong to the set'
      { Convert-FileEncoding -SourcePath 'TestDrive:\file.txt' `
        -Encoding String } | Should -Throw 'does not belong to the set'
      { Convert-FileEncoding -SourcePath 'TestDrive:\file.txt' `
        -Encoding BigEndianUnicode } |
        Should -Throw 'does not belong to the set'
      { Convert-FileEncoding -SourcePath 'TestDrive:\file.txt' `
        -Encoding Unknown } | Should -Throw 'does not belong to the set'
    }
    It 'Throw on missing LineEnding input' {
      { Convert-FileEncoding -SourcePath 'TestDrive:\file.txt' -LineEnding } |
        Should -Throw 'Missing an argument'
    }
    It 'Throw for empty LineEnding input' {
      { Convert-FileEncoding -SourcePath 'TestDrive:\file.txt' `
        -LineEnding '' } | Should -Throw 'does not belong to the set'
    }
    It 'Throw for $null LineEnding input' {
      { Convert-FileEncoding -SourcePath 'TestDrive:\file.txt' `
        -LineEnding $null } | Should -Throw 'does not belong to the set'
    }
    It 'Throw for unknown LineEnding input' {
      { Convert-FileEncoding -SourcePath 'TestDrive:\file.txt' `
        -LineEnding Wrong } | Should -Throw 'does not belong to the set'
    }
  }

  Context 'character encoding' {
    New-Item -Path TestDrive:\ -Name ascii.txt
    New-Item -Path TestDrive:\ -Name utf8.txt
    New-Item -Path TestDrive:\ -Name utf8BOM.txt
    New-Item -Path TestDrive:\ -Name utf8NoBOM.txt
    'some text with Unicode ʩ' > TestDrive:\ascii.txt
    'some text with Unicode ʩ' > TestDrive:\utf8.txt
    'some text with Unicode ʩ' > TestDrive:\utf8BOM.txt
    'some text with Unicode ʩ' > TestDrive:\utf8NoBOM.txt

    It 'files should be equal' {
      $(Get-Content -Path 'TestDrive:\file.txt' -Raw) |
        Should -Be $(Get-Content -Path 'TestDrive:\utf8.txt' -Raw)
    }
    It 'after encoding to ANSI' {
      Convert-FileEncoding -Path 'TestDrive:\ascii.txt' -Encoding ASCII
      $(Get-Content -Path 'TestDrive:\ascii.txt' -Raw) |
        Should -Not -Be $(Get-Content -Path 'TestDrive:\file.txt' -Raw)
    }
    It 'after encoding to ASCII no match to string' {
      'TestDrive:\ascii.txt' |
        Should -Not -FileContentMatch 'some text with Unicode ʩ'
    }
    It 'after encoding to UTF-8' {
      Convert-FileEncoding -Path 'TestDrive:\utf8.txt' -Encoding UTF8
      $(Get-Content -Path 'TestDrive:\utf8.txt' -Raw) |
        Should -Be $(Get-Content -Path 'TestDrive:\file.txt' -Raw)
    }
    It 'after encoding to UTF-8 match string' {
      'TestDrive:\utf8.txt' |
        Should -FileContentMatchExactly 'some text with Unicode ʩ'
    }
    if ($PSVersionTable.PSVersion.Major -lt 6) {
      # Pester does not behave well here.
      # Call Convert-FileEncoding in different scope.
      $tmp_drive = (Resolve-Path TestDrive:\).ProviderPath
      Invoke-BackgroundPwsh "$tmp_drive\utf8BOM.txt" UTF8BOM
      Invoke-BackgroundPwsh "$tmp_drive\utf8NoBOM.txt" UTF8NoBOM
    } else {
      Convert-FileEncoding -Path 'TestDrive:\utf8BOM.txt' -Encoding UTF8BOM
      Convert-FileEncoding -Path 'TestDrive:\utf8NoBOM.txt' -Encoding UTF8NoBOM
    }
    It 'after encoding to UTF-8 with BOM' {
      $(Get-Content -Path 'TestDrive:\utf8BOM.txt' -Raw) |
        Should -Not -Be $(Get-Content -Path 'TestDrive:\ascii.txt' -Raw)
    }
    It 'after encoding to UTF-8 with BOM match string' {
      'TestDrive:\utf8BOM.txt' |
        Should -FileContentMatchExactly 'some text with Unicode ʩ'
    }
    It 'after encoding to UTF-8 without BOM' {
      $(Get-Content -Path 'TestDrive:\utf8NoBOM.txt' -Raw) |
        Should -Not -Be $(Get-Content -Path 'TestDrive:\ascii.txt' -Raw)
    }
    It 'after encoding to UTF-8 without BOM match string' {
      'TestDrive:\utf8NoBOM.txt' |
        Should -FileContentMatchExactly 'some text with Unicode ʩ'
    }
    It 'with and without BOM are not equal (with PS v5.1)' {
      if ($PSVersionTable.PSVersion.Major -ge 6) {
        Set-ItResult -Skipped -Because 'PS v6+ seems to hide the BOM'
      }
      $(Get-Content -Path 'TestDrive:\utf8NoBOM.txt' -Raw) |
        Should -Not -Be $(Get-Content -Path 'TestDrive:\utf8BOM.txt' -Raw)
    }
    It 'with and without BOM should match after removing BOM' {
      if ($PSVersionTable.PSVersion.Major -lt 6) {
        Invoke-BackgroundPwsh "$tmp_drive\utf8BOM.txt" UTF8NoBOM
      } else {
        Convert-FileEncoding -Path 'TestDrive:\utf8BOM.txt' -Encoding UTF8NoBOM
      }
      $(Get-Content -Path 'TestDrive:\utf8BOM.txt' -Raw) |
        Should -Be $(Get-Content -Path 'TestDrive:\utf8NoBOM.txt' -Raw)
    }
  }

  Context 'line ending' {
    New-Item -Path TestDrive:\ -Name base.txt
    New-Item -Path TestDrive:\ -Name file1.txt
    New-Item -Path TestDrive:\ -Name file2.txt
    "`nSome text`r`rWith`nMultiple lines`r`n" > TestDrive:\base.txt
    "`nSome text`r`rWith`nMultiple lines`r`n" > TestDrive:\file1.txt
    "`nSome text`r`rWith`nMultiple lines`r`n" > TestDrive:\file2.txt

    if ($PSVersionTable.PSVersion.Major -lt 6) {
      $tmp_drive = (Resolve-Path TestDrive:\).ProviderPath
    }
    It 'files should be equal' {
      $(Get-Content -Path 'TestDrive:\file1.txt' -Raw) |
        Should -Be $(Get-Content -Path 'TestDrive:\base.txt' -Raw)
    }
    It 'Pester function: FileContentMatchMultiLine' {
      'TestDrive:\base.txt' | Should `
        -FileContentMatchMultiLine '^\nSome text\r\rWith\nMultiple lines\r\n'
    }
    It 'files should be equally converted' {
      if ($PSVersionTable.PSVersion.Major -lt 6) {
        Invoke-BackgroundPwsh "$tmp_drive\base.txt" 6>$null
        Invoke-BackgroundPwsh "$tmp_drive\file1.txt" 6>$null
      } else {
        Convert-FileEncoding -Path 'TestDrive:\base.txt' 6>$null
        Convert-FileEncoding -Path 'TestDrive:\file1.txt' 6>$null
      }
      $(Get-Content -Path 'TestDrive:\file1.txt' -Raw) |
        Should -Be $(Get-Content -Path 'TestDrive:\base.txt' -Raw)
    }
    It 'files should not change with encoding' {
      $(Get-Content -Path 'TestDrive:\file2.txt' -Raw) |
        Should -Be $(Get-Content -Path 'TestDrive:\base.txt' -Raw)
    }
    It 'maintain line-endings when changing the encoding' {
      'TestDrive:\base.txt' | Should `
        -FileContentMatchMultiLine '^\nSome text\r\rWith\nMultiple lines\r\n'
    }
    It 'after setting Unix line-endings' {
      if ($PSVersionTable.PSVersion.Major -lt 6) {
        Invoke-BackgroundPwsh -Path "$tmp_drive\file1.txt" -LineEnding Unix `
          6>$null
      } else {
        Convert-FileEncoding -Path 'TestDrive:\file1.txt' -LineEnding Unix `
          6>$null
      }
      $(Get-Content -Path 'TestDrive:\file1.txt' -Raw) |
        Should -Not -Be $(Get-Content -Path 'TestDrive:\base.txt' -Raw)
    }
    It 'match after changing to Unix' {
      'TestDrive:\file1.txt' | Should `
        -FileContentMatchMultiLine '^\nSome text\n\nWith\nMultiple lines\n'
    }
    It 'after setting LF line-endings' {
      if ($PSVersionTable.PSVersion.Major -lt 6) {
        Invoke-BackgroundPwsh -Path "$tmp_drive\file2.txt" -LineEnding LF `
          6>$null
      } else {
        Convert-FileEncoding -Path 'TestDrive:\file2.txt' -LineEnding LF `
          6>$null
      }
      $(Get-Content -Path 'TestDrive:\file2.txt' -Raw) |
        Should -Not -Be $(Get-Content -Path 'TestDrive:\base.txt' -Raw)
      $(Get-Content -Path 'TestDrive:\file2.txt' -Raw) |
        Should -Be $(Get-Content -Path 'TestDrive:\file1.txt' -Raw)
    }
    It 'after setting Windows line-endings' {
      if ($PSVersionTable.PSVersion.Major -lt 6) {
        Invoke-BackgroundPwsh -Path "$tmp_drive\file1.txt" -LineEnding Windows
      } else {
        Convert-FileEncoding -Path 'TestDrive:\file1.txt' -LineEnding Windows
      }
      $(Get-Content -Path 'TestDrive:\file1.txt' -Raw) |
        Should -Not -Be $(Get-Content -Path 'TestDrive:\base.txt' -Raw)
      $(Get-Content -Path 'TestDrive:\file1.txt' -Raw) |
        Should -Not -Be $(Get-Content -Path 'TestDrive:\file2.txt' -Raw) `
          -Because 'it is uses Unix line-endings'
    }
    It 'match after changing to Windows' {
      'TestDrive:\file1.txt' | Should -FileContentMatchMultiLine `
        '^\r\nSome text\r\n\r\nWith\r\nMultiple lines\r\n'
    }
    It 'after setting CRLF line-endings' {
      if ($PSVersionTable.PSVersion.Major -lt 6) {
        Invoke-BackgroundPwsh -Path "$tmp_drive\file2.txt" -LineEnding CRLF
      } else {
        Convert-FileEncoding -Path 'TestDrive:\file2.txt' -LineEnding CRLF
      }
      $(Get-Content -Path 'TestDrive:\file2.txt' -Raw) |
        Should -Not -Be $(Get-Content -Path 'TestDrive:\base.txt' -Raw)
      $(Get-Content -Path 'TestDrive:\file2.txt' -Raw) |
        Should -Be $(Get-Content -Path 'TestDrive:\file1.txt' -Raw)
    }
    It 'after setting CR line-endings' {
      if ($PSVersionTable.PSVersion.Major -lt 6) {
        Invoke-BackgroundPwsh -Path "$tmp_drive\file1.txt" -LineEnding CR
      } else {
        Convert-FileEncoding -Path 'TestDrive:\file1.txt' -LineEnding CR
      }
      $(Get-Content -Path 'TestDrive:\file1.txt' -Raw) |
        Should -Not -Be $(Get-Content -Path 'TestDrive:\base.txt' -Raw)
      $(Get-Content -Path 'TestDrive:\file1.txt' -Raw) |
        Should -Not -Be $(Get-Content -Path 'TestDrive:\file2.txt' -Raw) `
          -Because 'it uses Windows line-endings'
    }
    It 'match after changing to CR' {
      'TestDrive:\file1.txt' | Should `
        -FileContentMatchMultiLine '^\rSome text\r\rWith\rMultiple lines\r'
    }
  }
  Context 'Both Encoding and LineEnding' {
    New-Item -Path TestDrive:\ -Name base.txt
    New-Item -Path TestDrive:\ -Name file1.txt
    "`rSome text`rWith Multiple lines`r`nAnd Unicode ʩ`n" > TestDrive:\base.txt
    "`rSome text`rWith Multiple lines`r`nAnd Unicode ʩ`n" > TestDrive:\file1.txt
    It 'To UTF8 Windows' {
      Convert-FileEncoding 'TestDrive:\file1.txt' UTF8 Windows 6>$null
      $(Get-Content -Path 'TestDrive:\file1.txt' -Raw) |
        Should -Not -Be $(Get-Content -Path 'TestDrive:\base.txt' -Raw)
    }
    It 'To ASCII Unix' {
      Convert-FileEncoding 'TestDrive:\file1.txt' ASCII Unix
      $(Get-Content -Path 'TestDrive:\file1.txt' -Raw) |
        Should -Not -Be $(Get-Content -Path 'TestDrive:\base.txt' -Raw)
    }
  }
  if ($PSVersionTable.PSVersion.Major -lt 6) {
    Context 'Without pwsh v6+' {
      Mock Test-Command { return $false } -ModuleName Convert-FileEncoding
      It 'break when pwsh v6+ is not available' {
        { Convert-FileEncoding 'TestDrive:\file.txt' UTF8NoBOM 6>$null } |
          Should -Throw 'UTF8NoBOM requires at least PowerShell version 6'
      }
    }
  }
}
