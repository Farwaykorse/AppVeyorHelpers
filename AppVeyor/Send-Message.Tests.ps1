Import-Module -Name "${PSScriptRoot}\Send-Message.psd1" -Force

Set-StrictMode -Version Latest

##====--------------------------------------------------------------------====##
$global:msg_documentation = 'at least 1 empty line above documentation'
$global:msg_interactive = 'executed in interactive PowerShell session'

##====--------------------------------------------------------------------====##
Describe 'Find-SplitLocation' {
  InModuleScope Send-Message {
    It 'has documentation' {
      Get-Help Find-SplitLocation | Out-String |
        Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
    }
    It 'no -WhatIf and -Confirm' {
      Get-Command -Name Find-SplitLocation -Syntax |
        Should -not -Match '-WhatIf.+-Confirm'
    }
    Context 'Input Errors' {
      # Suppress output to the Appveyor Message API.
      Mock Assert-CI { return $false } -ModuleName Send-Message
      It 'throw on missing -Text' {
        { Find-SplitLocation -MaxLength 131 } | Should -Throw 'Text is required'
        { Find-SplitLocation } | Should -Throw 'Text is required'
      }
      It 'throw on missing -MaxLength' {
        { Find-SplitLocation -Text 'x' } | Should -Throw 'MaxLength is required'
        { Find-SplitLocation 'x' } | Should -Throw 'MaxLength is required'
        { Find-SplitLocation 12 } | Should -Throw 'MaxLength is required'
      }
      It 'throw on invalid type' {
        { Find-SplitLocation -MaxLength 'x' } |
          Should -Throw 'Cannot process argument transformation'
      }
    }
    It 'no need to split if within or at the limit' {
      Find-SplitLocation ('some text' + "`n" + 'more  x') 500 | Should -Be 17
      Find-SplitLocation ('some text' + "`r" + 'more  x') 500 | Should -Be 17
      Find-SplitLocation ('some    ' + "`r`n" + 'more   ') 500 | Should -Be 17 `
        -Because 'no white space removal'
      Find-SplitLocation ('some text' + "`n" + 'more  x') 17 | Should -Be 17
    }
    It 'always at a form feed character (FF)' {
      Find-SplitLocation ('0123456789' + "`f" + '123456') 15 | Should -Be 10
      Find-SplitLocation ('0123456789' + "`f`f" + '23456') 15 | Should -Be 10
      Find-SplitLocation ("`f" + '123456789') 15 | Should -Be 0
      Find-SplitLocation ("`f`f" + '123456789') 15 | Should -Be 0
      Find-SplitLocation ("`f" + '123456789' + "`f") 15 | Should -Be 0
      Find-SplitLocation ('0123456789' + "`f") 15 | Should -Be 10
    }
    It 'after the last new-line character within the limit (LF or CR)' {
      Find-SplitLocation ('0123456789' + "`n" + '123456') 15 | Should -Be 10
      Find-SplitLocation ('0123456789' + "`r" + '123456') 10 | Should -Be 10
      Find-SplitLocation ('0123456789' + "`r`n" + '23456') 15 | Should -Be 11
      Find-SplitLocation ('0123456789' + "`n`r" + '23456') 15 | Should -Be 11
      Find-SplitLocation ('0123456789' + "`n" + '123' + "`n" + '56') 15 |
        Should -Be 14
      Find-SplitLocation ('0123456789' + "`n" + '123 56') 15 | Should -Be 10 `
        -Because 'new-line over white-space'
      Find-SplitLocation ("`n" + '123456789' + "`n" + '1') 9 | Should -Be 9
      Find-SplitLocation ("`n" + '1234567 9' + "`n" + '1') 9 | Should -Be 9
    }
    It 'at the last white space within the limit' {
      Find-SplitLocation '123456789 123456' 15 | Should -Be 10
      Find-SplitLocation '123456 89 123456' 15 | Should -Be 10
      Find-SplitLocation '12345678  123456' 15 | Should -Be 10
      Find-SplitLocation ('123456789' + "`t" + '123456') 15 | Should -Be 10
      # except when the white space is the first character
      Find-SplitLocation ' 234567890123456' 9 | Should -Be 9
      Find-SplitLocation '  34567890123456' 9 | Should -Be 2
      Find-SplitLocation ("`t" + '2345678901234') 15 | Should -Be 14
      Find-SplitLocation ("`t" + '234567890123456') 15 | Should -Be 15
      Find-SplitLocation (" `t" + '34567890123456') 15 | Should -Be 2
      Find-SplitLocation ("`t`t" + '34567890123456') 15 | Should -Be 2
    }
    It 'at the first white space directly past the limit' {
      # White space is striped from the end of a section.
      # Maintaining indentation at the start of a section.
      Find-SplitLocation '123456789 12345 7' 15 | Should -Be 16
      Find-SplitLocation '123456789 1234   8' 15 | Should -Be 16
      Find-SplitLocation ('123456789 12345' + "`t" + '7') 15 | Should -Be 16
    }
    It 'at the character at the limit' {
      Find-SplitLocation '01234567890123456' 15 | Should -Be 15
      Find-SplitLocation '012345678901234 6' 10 | Should -Be 10
      Find-SplitLocation ('0123456789' + "`n" + '123456') 8 | Should -Be 8
    }
  } # InModuleScope
} # Find-SplitLocation

##====--------------------------------------------------------------------====##
Describe 'Split-Text' {
  InModuleScope Send-Message {
    It 'has documentation' {
      Get-Help Split-Text | Out-String |
        Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
    }
    It 'no -WhatIf and -Confirm' {
      Get-Command -Name Split-Text -Syntax |
        Should -not -Match '-WhatIf.+-Confirm'
    }

    Context 'Input Errors' {
      # Suppress output to the Appveyor Message API.
      Mock Assert-CI { return $false } -ModuleName Send-Message
      It 'throw on missing -Text' {
        { Split-Text -MaxLength 131 } | Should -Throw 'Text is required'
        { Split-Text } | Should -Throw 'Text is required'
      }
      It 'throw on missing -MaxLength' {
        { Split-Text -Text 'x' } | Should -Throw 'MaxLength is required'
        { Split-Text 'x' } | Should -Throw 'MaxLength is required'
        { Split-Text 5 } | Should -Throw 'MaxLength is required'
      }
      It 'throw on invalid type' {
        { Split-Text -MaxLength 'x' } |
          Should -Throw 'Cannot process argument transformation'
      }
    }
    It 'Return type' {
      # Internal logic depends on the result of `GetType().Name`!
      $out = Split-Text ('0123456789' + "`n" + '123456') 500
      $out | Should -BeOfType 'String'
      $out.GetType().Name | Should -Be 'String'
      $out = Split-Text ('0123456789' + "`n" + '123456') 15
      $out | Should -BeOfType 'String'
      $out.GetType().Name | Should -Be 'Object[]'
    }
    It 'no need to split if within or at the limit' {
      $out = Split-Text ('some text' + "`n" + 'more  x') 500
      $out.Length | Should -Be 17
      $out | Should -Match '^some text\nmore  x$'
      $out = Split-Text ('  some text' + "`n" + '  more  x') 500
      $out.Length | Should -Be 21
      $out | Should -Match '^  some text\n  more  x$'
    }
    It 'strip' {
      (Split-Text ('some    ' + "`r`n" + 'more   ') 500).Length |
        Should -Be 14 -Because 'stripped trailing spaces'
      (Split-Text ('some    ' + "`r`n" + 'more' + "`t`t") 500).Length |
        Should -Be 14 -Because 'stripped trailing tabs'
      (Split-Text ('   some    ' + "`r`n" + 'more') 500).Length |
        Should -Be 17 -Because 'do not strip leading spaces'
      (Split-Text ("`t`t" + 'some    ' + "`r`n" + 'more') 500).Length |
        Should -Be 16 -Because 'do not strip leading tabs'
      (Split-Text ('some    ' + "`r`n" + 'more' + "`f`f") 500).Length |
        Should -Be 14 -Because 'stripped trailing form feeds'
      (Split-Text ("`f`f" + 'some    ' + "`r`n" + 'more') 500).Length |
        Should -Be 14 -Because 'stripped leading form feeds'
      (Split-Text ("`n`n" + 'some    ' + "`r`n" + 'more') 500).Length |
        Should -Be 14 -Because 'stripped leading newlines'
      (Split-Text ("`r`n" + 'some    ' + "`r`n" + 'more') 500).Length |
        Should -Be 14 -Because 'stripped leading newlines'
      (Split-Text ('some    ' + "`r`n" + 'more' + "`r`n") 500).Length |
        Should -Be 14 -Because 'stripped trailing newlines'
    }
    It 'split at LF or CR' {
      $out = Split-Text ('0123456789' + "`n" + '123456') 15
      $out.Length | Should -Be 2
      $out[0] | Should -Be '0123456789'
      $out[1] | Should -Be '123456'
      $out = Split-Text ('0123456789' + "`r" + '123456') 15
      $out.Length | Should -Be 2
      $out[0] | Should -Be '0123456789'
      $out[1] | Should -Be '123456'
      $out = Split-Text ('0123456789' + "`r`n" + '23456') 15
      $out.Length | Should -Be 2
      $out[0] | Should -Be '0123456789'
      $out[1] | Should -Be '23456'
      $out = Split-Text ('0123456789' + "`n" + '123' + "`n" + '56') 15
      $out.Length | Should -Be 2
      $out[0] | Should -Match '^0123456789\n123$'
      $out[1] | Should -Be '56'
      $out = Split-Text ('0123456789' + "`n" + '123 56') 15
      $out.Length | Should -Be 2
      $out[0] | Should -Be '0123456789' -Because 'new line over white space'
      $out[1] | Should -Be '123 56'
      $out = Split-Text (' 123456789' + "`n" + '123456') 15
      $out.Length | Should -Be 2
      $out[0] | Should -Be ' 123456789' -Because 'do not trim leading space'
      $out[1] | Should -Be '123456'
      $out = Split-Text ("`t" + '123456789' + "`n" + '123456') 15
      $out.Length | Should -Be 2
      $out[0] | Should -Be ("`t" + '123456789') `
        -Because 'do not trim leading tab'
      $out[1] | Should -Be '123456'
      $out[0].Length | Should -Be 10
      $out = Split-Text ("`r`n" + '23456789' + "`n" + '1') 9
      $out.Length | Should -Be 2
      $out[0] | Should -Be '23456789'
      $out[1] | Should -Be '1'
      $out = Split-Text ("`n`n" + '34567 9' + "`n" + '12' + "`n" + '345') 10
      $out.Length | Should -Be 2
      $out[0] | Should -Match '^34567 9\n12$'
      $out[1] | Should -Be '345'
    }
    It 'split at white space' {
      $out = Split-Text ('0123456789 123456') 15
      $out.Length | Should -Be 2
      $out[1] | Should -Be '123456'
      $out = Split-Text ('0123456 89 123456') 15
      $out.Length | Should -Be 2
      $out[1] | Should -Be '123456'
      $out = Split-Text ('012345678  123456') 15
      $out.Length | Should -Be 2
      $out[1] | Should -Be '123456'
      $out = Split-Text ('0123456789 1234 6') 15
      $out.Length | Should -Be 2
      $out[1] | Should -Be '6'
      $out = Split-Text (' 1234567890123456') 9
      $out.Length | Should -Be 2
      $out[0] | Should -Be ' 12345678'
      $out[1] | Should -Be '90123456'
      $out = Split-Text ('0123456789' + "`t" + '123456' + "`t") 15
      $out.Length | Should -Be 2
      $out[0] | Should -Be '0123456789'
      $out[1] | Should -Be '123456'
      $out = Split-Text ("`t" + '123456789012345') 9
      $out.Length | Should -Be 2
      $out[0] | Should -Match '^\t12345678'
      $out[1] | Should -Be '9012345'
    }
    It 'split after MaxLength character' {
      $out = Split-Text ('01234567890123456') 15
      $out.Length | Should -Be 2
      $out = Split-Text ('012345678901234 6') 10
      $out.Length | Should -Be 2
      $out = Split-Text ('0123456789' + "`n" + '123456') 8
      $out.Length | Should -Be 3
      $out[1] | Should -Be '89'
      $out[2] | Should -Be '123456'
      $out = Split-Text (' 1234567890123456') 9
      $out.Length | Should -Be 2
      $out[0] | Should -Be ' 12345678'
      $out[1] | Should -Be '90123456'
    }
    It 'always split at form feed character (FF)' {
      $out = Split-Text ("`f" + '1234567890') 500
      $out.Length | Should -Be 10 -Because 'ignore when first character'
      $out = Split-Text ('0123456789' + "`f" + '12345') 500
      $out.Length | Should -Be 2
      $out[0] | Should -Be '0123456789'
      $out[1] | Should -Be '12345'
      $out = Split-Text ('0123456789' + "`f") 500
      $out.Length | Should -Be 10
      $out = Split-Text ('0123456789' + "`f`f`f`f" + '45') 500
      $out.Length | Should -Be 2
      $out[0] | Should -Be '0123456789'
      $out[1] | Should -Be '45'
      $out = Split-Text ('0123' + "`f" + '56789' + "`f" + '12345') 500
      $out.Length | Should -Be 3
      $out = Split-Text ('0123456789' + "`f" + '12345') 12
      $out.Length | Should -Be 2
      $out[0] | Should -Be '0123456789'
      $out = Split-Text ('0123' + "`f" + '56789' + "`n" + '12345') 12
      $out.Length | Should -Be 2
      $out[0] | Should -Be '0123'
      $out = Split-Text ('0123456789' + "`f" + '12345') 8
      $out.Length | Should -Be 3 -Because 'first splits at character limit'
      $out[0] | Should -Be '01234567'
      $out[1] | Should -Be '89'
      $out[2] | Should -Be '12345'
      $out = Split-Text ('123456789' + "`f" + '12345') 10
      $out.Length | Should -Be 2
      $out[0].Length | Should -Be 9
      $out[0] | Should -Be '123456789'
      $out[1] | Should -Be '12345'
    }
  } # InModuleScope
} # Split-Text

##====--------------------------------------------------------------------====##
Describe 'Internal Stop-Execution' {
  InModuleScope Send-Message {
    It 'supports -WhatIf and -Confirm' {
      Get-Command -Name Stop-Execution -Syntax |
        Should -Match '-Whatif.*-Confirm'
    }
    Context 'CI' {
      Mock Assert-CI { return $true } -ModuleName Send-Message

      It 'WhatIf' {
        { Stop-Execution -WhatIf -Message 'xX' } | Should -Throw 'xX' 
      }
    }
  }
} # Internal Stop-Execution

##====--------------------------------------------------------------------====##
Describe 'Send-Message' {
  It 'has documentation' {
    Get-Help Send-Message | Out-String |
      Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
  }
  It 'no -WhatIf and -Confirm' {
    Get-Command -Name Send-Message -Syntax |
      Should -not -Match '-WhatIf.*-Confirm'
  }
  Context 'Input Errors' {
    # Suppress output to the Appveyor Message API.
    Mock Assert-CI { return $false } -ModuleName Send-Message

    It 'Mandatory parameter Message' {
      if ([Environment]::UserInteractive) {
        Set-ItResult -Inconclusive -Because $msg_interactive
      }
      { Send-Message } | Should -Throw
    }
    It 'Throw on missing Message input' {
      { Send-Message -Message } | Should -Throw 'Missing an argument'
    }
    It 'Throw for empty or $null Message input' {
      { Send-Message -Message '' } |
        Should -Throw 'argument is null or empty'
      { Send-Message -Message $null } |
        Should -Throw 'argument is null or empty'
    }
    It 'Throw for $null Message input (alias)' {
      { Send-Message -Title $null } |
        Should -Throw 'argument is null or empty'
      { Send-Message -m $null } |
        Should -Throw 'argument is null or empty'
    }
    It 'Throw on missing Details input' {
      { Send-Message -Message 'title' -Details } |
        Should -Throw 'Missing an argument'
    }
    It 'Allow empty Details input' {
      { Send-Message -Message 'title' -Details '' 6>$null } | Should -not -Throw
    }
    It 'Throw for $null Details input' {
      { Send-Message -Message 'title' -Details $null } |
        Should -Throw 'Cannot bind argument to parameter'
    }
    It 'Throw on missing parameter flag for Details' {
      { Send-Message -Message 'title' 'details text' } |
        Should -Throw 'parameter cannot be found'
      { Send-Message 'title' 'details text' } |
        Should -Throw 'parameter cannot be found'
      { Send-Message 'title' -Details 'text' 6>$null } | Should -not -Throw
    }
    It 'Throw for missing MaxLength input' {
      { Send-Message 'title' -Details '...' -MaxLength } |
        Should -Throw 'Missing an argument for parameter'
    }
    It 'Throw for missing MaxLength input' {
      { Send-Message 'title' -Details '...' -MaxLength $null } |
        Should -Throw 'less than the minimum allowed range'
    }
    It 'Throw for MaxLength outside range' {
      { Send-Message 'title' -Details '...' -MaxLength 0 } |
        Should -Throw 'less than the minimum allowed range'
      { Send-Message 'title' -Details '...' -MaxLength -1 } |
        Should -Throw 'less than the minimum allowed range'
      { Send-Message 'title' -Details '...' `
        -MaxLength ([System.Math]::Pow(2,31)-1) 6>$null } | Should -not -Throw
      { Send-Message 'title' -Details '...' `
        -MaxLength ([System.Math]::Pow(2,31))
      } | Should -Throw 'Cannot process argument transformation'
    }
    It 'Mandatory parameter Details when setting HideDetails' {
      { Send-Message -Message 'title' -HideDetails } |
        Should -Throw 'Parameter set cannot be resolved'
      { Send-Message -Message 'title' -Hide } |
        Should -Throw 'Parameter set cannot be resolved' -Because 'Alias'
      { Send-Message -Message 'title' -HideDetails -Details 'a' 6>$null } |
        Should -Not -Throw
    }
    It 'Mandatory parameter Details when setting NoNewLine' {
      { Send-Message -Message 'title' -NoNewLine } |
        Should -Throw 'Parameter set cannot be resolved'
      { Send-Message -Message 'title' -NoNewLine -Details 'a' 6>$null } |
        Should -Not -Throw
    }
    It 'Mandatory parameter Details when setting HideDetails and NoNewLine' {
      { Send-Message -Message 'title' -HideDetails -NoNewLine } |
        Should -Throw 'Parameter set cannot be resolved'
      { Send-Message -Message 'title' -Hide -NoNewLine -Details 'a' 6>$null } |
        Should -Not -Throw
    }
    It 'Mandatory parameter Details when setting MaxLength' {
      { Send-Message -Message 'title' -MaxLength 12 } |
        Should -Throw 'Parameter set cannot be resolved'
      { Send-Message -Message 'title' -MaxLength 12 -Details 'a' 6>$null } |
        Should -Not -Throw
    }
    It 'ContinueOnError & Info invalid combination' {
      { Send-Message -Info -Message 'title' -ContinueOnError } |
        Should -Throw 'Parameter set cannot be resolved'
      { Send-Message -Message 'title' -ContinueOnError } |
        Should -Throw 'Parameter set cannot be resolved'
    }
    It 'ContinueOnError & Warning invalid combination' {
      { Send-Message -Warning -Message 'title' -ContinueOnError } |
        Should -Throw 'Parameter set cannot be resolved'
    }
    It 'ContinueOnError invalid combination (requiring Details)' {
      if ([Environment]::UserInteractive) {
        Set-ItResult -Inconclusive -Because $msg_interactive
      }
      { Send-Message -Info -Message 'title' -ContinueOnError -HideDetails } |
        Should -Throw 'Parameter set cannot be resolved'
      { Send-Message -Info -Message 'title' -ContinueOnError -NoNewLine } |
        Should -Throw 'Parameter set cannot be resolved'
      { Send-Message -Info -Message 'title' -ContinueOnError -HideDetails `
        -NoNewLine } | Should -Throw 'Parameter set cannot be resolved'
    }
    It 'Info & Warning invalid combination' {
      { Send-Message -Info -Warning -Message 'title' } | Should -Throw
    }
    It 'Info & Error invalid combination' {
      { Send-Message -Info -Error -Message 'title' } | Should -Throw
    }
    It 'Warning & Error invalid combination' {
      { Send-Message -Warning -Error -Message 'title' } | Should -Throw
    }
  }

  Context 'Reduce size of -Details' {
    # Suppress output to Message console.
    Mock Assert-CI { return $false } -ModuleName Send-Message

    It 'replace CRLF with LF' {
      $title = 'title'
      $text = ('some text' + "`r`n" + 'more text' + "`r`n`r`n" + '...')
      $result = (Send-Message -Warning $title -Details $text 3>&1)
      $result | Should -Be "title`nsome text`nmore text`n`n..." `
        -Because '3 times CRLF'
      $result = (Send-Message -Warning $title -Details $text -NoNewLine 3>&1)
      $result | Should -Be "title`nsome text`nmore text`n`n..." `
        -Because '3 times CRLF'
    }
    It 'strip spaces before LF' {
      $title = 'title'
      $text = ('some text' + "`n" + 'more text ' + "`n`n" + '...   ' + "`n")
      $result = (Send-Message -Warning $title -Details $text 3>&1)
      $result | Should -Be "title`nsome text`nmore text`n`n...`n" `
        -Because '4 spaces'
      # Combined with replace CRLF with LF.
      $text = (
        'some text' + "`t`t" + "`r`n" + 'more text' + "   `r`n`r`n" + '...'
      )
      $result = (Send-Message -Warning $title -Details $text 3>&1)
      $result | Should -Be "title`nsome text`nmore text`n`n..."
      $result = (Send-Message -Warning $title -Details $text -NoNewLine 3>&1)
      $result | Should -Be "title`nsome text`nmore text`n`n..."
    }
    It 'array input (adds LF)' {
      'a',' ','b' | Send-Message 'title' 6>&1 |
        Should -Be "INFO: title`n-- a`n-- `n-- b" `
        -Because 'space before newline removed'
      Send-Message 'title' -Details @('a',' ','b') 6>&1 |
        Should -Be "INFO: title`n-- a`n-- `n-- b"
      'a',"`t",'b' | Send-Message 'title' 6>&1 |
        Should -Be "INFO: title`n-- a`n-- `n-- b" `
        -Because 'tab before newline removed'
      'a',"`tX",'b',"`fX",'c' | Send-Message 'title' 6>&1 |
        Should -Be "INFO: title`n-- a`n-- `tX`n-- b`n-- `fX`n-- c"
    }
    It 'array input, -NoNewLine' {
      'a','b','c' | Send-Message 'title' -NoNewLine 6>&1 |
        Should -Be "INFO: title`n-- a b c"
      'a',' ','b' | Send-Message 'title' -NoNewLine 6>&1 |
        Should -Be "INFO: title`n-- a   b"
      'a','','b' | Send-Message 'title' -NoNewLine 6>&1 |
        Should -Be "INFO: title`n-- a b" -Because 'ignore empty elements'
      Send-Message 'title' -Details @('a','','b') -NoNewLine 6>&1 |
        Should -Be "INFO: title`n-- a  b" -Because 'not if not piped'
      Send-Message 'title' -Details @('a',$null,'b') -NoNewLine 6>&1 |
        Should -Be "INFO: title`n-- a  b" -Because 'not if not piped'
    }
    It 'different input forms for -Details' {
      # piped, ignore empty
      'a','','b' | Send-Message 'title' 6>&1 |
        Should -Be "INFO: title`n-- a`n-- b" -Because 'ignore empty elements'
      @('a','','b') | Send-Message 'title' 6>&1 |
        Should -Be "INFO: title`n-- a`n-- b"
      # array/ not empty
      'a',' ','b' | Send-Message 'title' 6>&1 |
        Should -Be "INFO: title`n-- a`n-- `n-- b" -Because 'not empty'
      Send-Message 'title' -Details @('a','','b') 6>&1 |
        Should -Be "INFO: title`n-- a`n-- `n-- b"
      Send-Message 'title' -Details 'a','','b' 6>&1 |
        Should -Be "INFO: title`n-- a`n-- `n-- b"
      Send-Message 'title' -Details 'a','      ','b' 6>&1 |
        Should -Be "INFO: title`n-- a`n-- `n-- b"
    }
  } # Context: Reduce size of -Details

  Context 'Info' {
    # Suppress output to Message console.
    Mock Assert-CI { return $false } -ModuleName Send-Message

    It 'Title only (all channels)' {
      Send-Message -Info -Message 'text' *>&1 | Should -Be 'INFO: text'
      Send-Message -Info 'some text' *>&1 | Should -Be 'INFO: some text'
      Send-Message 'some text' -Info *>&1 | Should -Be 'INFO: some text'
    }
    It 'Title only (channel 6 only)' {
      Send-Message -Info -Message 'text' 6>&1 | Should -Be 'INFO: text'
    }
    It 'Info is the default' {
      Send-Message 'some text' 6>&1 | Should -Be 'INFO: some text'
    }
    It 'With Details (all channels)' {
      Send-Message -Info -Message 'text' -Details 'more text' *>&1 |
        Should -Be "INFO: text`n-- more text"
    }
    It 'With Details (channel 6 only)' {
      Send-Message -Info -Message 'text' -Details 'more text' 6>&1 |
        Should -Be "INFO: text`n-- more text"
    }
    It 'With Details, multiple inputs (array)' {
      Send-Message -Info -Message 'text' -Details @('a', 'b', 'c') 6>&1 |
        Should -Be "INFO: text`n-- a`n-- b`n-- c"
      Send-Message -Info -Message 'text' -Details 'a', 'b', 'c' 6>&1 |
        Should -Be "INFO: text`n-- a`n-- b`n-- c"
    }
    It 'Hide Details' {
      Send-Message -Info 'text' -Details 'more text' -HideDetails 6>&1 |
        Should -Be 'INFO: text'
    }
    It 'With Details, NoNewLine' {
      Send-Message -Info -Message 'text' -Details 'more text' -NoNewLine 6>&1 |
        Should -Be "INFO: text`n-- more text"
      Send-Message -Info -Message 'text' -Details "More`nText" -NoNewLine 6>&1 |
        Should -Be "INFO: text`n-- More`n-- Text"
    }
    It 'With Details, NoNewLine (array)' {
      Send-Message -Info 'text' -Details @('a', 'b', 'c') -NoNewLine 6>&1 |
        Should -Be "INFO: text`n-- a b c"
      Send-Message -Info 'text' -Details 'a', 'b', 'c' -NoNewLine 6>&1 |
        Should -Be "INFO: text`n-- a b c"
    }
    It 'piped Details' {
      'a','b','c' | Send-Message -Info 'title' 6>&1 |
        Should -Be "INFO: title`n-- a`n-- b`n-- c"
    }
    It 'piped Details, NoNewLine' {
      'a','b','c' | Send-Message -Info 'title' -NoNewLine 6>&1 |
        Should -Be "INFO: title`n-- a b c"
    }
    It 'piped Details, HideDetails' {
      'a','b','c' | Send-Message -Info 'title' -HideDetails 6>&1 |
        Should -Be "INFO: title"
    }
  }

  Context 'Warning' {
    # Suppress output to Message console.
    Mock Assert-CI { return $false } -ModuleName Send-Message

    It 'Title only (all channels)' {
      Send-Message -Warning -Message 'text' *>&1 | Should -Be 'text'
      Send-Message -Warning 'some text' *>&1 | Should -Be 'some text'
      Send-Message 'some text' -Warning *>&1 | Should -Be 'some text'
    }
    It 'Title only (channel 3 only)' {
      Send-Message -Warning -Message 'text' 3>&1 | Should -Be 'text'
    }
    It 'With Details (all channels)' {
      Send-Message -Warning -Message 'text' -Details 'more text' *>&1 |
        Should -Be "text`nmore text"
    }
    It 'With Details (channel 3 only)' {
      Send-Message -Warning -Message 'text' -Details 'more text' 3>&1 |
        Should -Be "text`nmore text"
    }
    It 'With Details, multiple inputs (array)' {
      Send-Message -Warning -Message 'text' -Details @('a', 'b', 'c') 3>&1 |
        Should -Be "text`na`nb`nc"
      Send-Message -Warning -Message 'text' -Details 'a', 'b', 'c' 3>&1 |
        Should -Be "text`na`nb`nc"
    }
    It 'Hide Details' {
      Send-Message -Warning 'text' -Details 'more text' -HideDetails 3>&1 |
        Should -Be 'text'
    }
    It 'Log Only' {
      Send-Message -Warning 'text' -Details 'more text' -LogOnly 3>&1 |
        Should -Be $null
    }
    It 'NoNewLine' {
      Send-Message -Warning -Message 'text' -Details 'more text' 3>&1 |
        Should -Be "text`nmore text"
    }
    It 'piped Details' {
      'a','b','c' | Send-Message -Warning 'title' 3>&1 |
        Should -Be "title`na`nb`nc"
    }
    It 'piped Details, NoNewLine' {
      'a','b','c' | Send-Message -Warning 'title' -NoNewLine 3>&1 |
        Should -Be "title`na b c"
    }
    It 'piped Details, HideDetails' {
      'a','b','c' | Send-Message -Warning 'title' -HideDetails 3>&1 |
        Should -Be "title"
    }
    It 'piped Details, LogOnly' {
      'a','b','c' | Send-Message -Warning 'title' -LogOnly 3>&1 |
        Should -Be $null
    }
  }

  Context 'Error' {
    # Suppress output to Message console.
    Mock Assert-CI { return $false } -ModuleName Send-Message

    It 'should throw when not on CI' {
      { Send-Message -Error 'title' 6>$null } | Should -Throw 'title'
    }
    It 'Title only (all channels) -ContinueOnError' {
      Send-Message -Error -Message 'some text' -ContinueOnError *>&1 |
        Should -Be 'ERROR: some text'
      Send-Message -Error 'some text' -ContinueOnError *>&1 |
        Should -Be 'ERROR: some text'
      Send-Message 'some text' -Error -ContinueOnError *>&1 |
        Should -Be 'ERROR: some text'
    }
    It 'Title only (channel 6 only) -ContinueOnError' {
      Send-Message -Error -Message 'text' -ContinueOnError 6>&1 |
        Should -Be 'ERROR: text'
    }
    It 'Details (channel 6 only) -ContinueOnError' {
      Send-Message -Error -Message 'text' -Details 'more text' `
        -ContinueOnError 6>&1 | Should -Be @('ERROR: text', 'more text')
    }
    It '-LogOnly implies -ContinueOnError' {
      { Send-Message -Error 'text' -LogOnly } | Should -not -Throw
      Send-Message -Error -Message 'some text' -LogOnly *>&1 |
        Should -Be $null
    }
  }
  Context 'Call to Add-AppveyorMessage' {
    # Enable output to Message console.
    Mock Assert-CI { return $true } -ModuleName Send-Message
    # Catch call to Add-AppveyorMessage, evaluated in reverse order of creation.
    # Catch all:
    Mock Invoke-Expression { return $false } -ModuleName Send-Message
    # Return Command:
    Mock Invoke-Expression { return $Command } -ModuleName Send-Message `
      -ParameterFilter { $Command }

    It 'call Add-AppveyorMessage' {
      Send-Message -Message 'text' 6>$null |
        Should -MatchExactly '^Add-AppveyorMessage .*'
      Send-Message -Info -Message 'text' 6>$null |
        Should -MatchExactly '^Add-AppveyorMessage .*'
      Send-Message -Warning -Message 'text' 3>$null |
        Should -MatchExactly '^Add-AppveyorMessage .*'
      Send-Message -Error -Message 'text' -ContinueOnError 6>$null |
        Should -MatchExactly '^Add-AppveyorMessage .*'
    }
    It 'Category Information' {
      Send-Message -Info -Message 'text' 6>$null |
        Should -Match ' -Category Information'
      Send-Message -Message 'text' 6>$null |
        Should -Match ' -Category Information'
    }
    It 'Category Warning' {
      Send-Message -Warning -Message 'text' 3>$null |
        Should -Match ' -Category Warning'
    }
    It 'Category Error' {
      Send-Message -Error -Message 'text' -ContinueOnError 6>$null |
        Should -Match ' -Category Error'
    }
    It 'Convey Details' {
      Send-Message 'text' -Details 'some text' 6>$null |
        Should -Match ' -Details \$.'
    }
  }

  Context 'Call to Add-AppveyorMessage - return Details' {
    # Enable output to Message console.
    Mock Assert-CI { return $true } -ModuleName Send-Message
    # Catch call to Add-AppveyorMessage, evaluated in reverse order of creation.
    Mock Invoke-Expression { return $false } -ModuleName Send-Message
    # Get parameter after -Details -> return content
    Mock Invoke-Expression {
      $param = [regex]::Match($Command,' -Details[\s:]+\$[^\s"]+').ToString()
      return Get-Variable $param.Remove(0,11) -ValueOnly
    } -ModuleName Send-Message `
      -ParameterFilter { $Command -and $Command -match ' -Details \$.' }

    It 'Title only' {
      Send-Message 'text' 6>$null | Should -Be $false
    }
    It 'With Details' {
      Send-Message 'text' -Details 'some text' 6>$null |
        Should -Be 'some text'
    }
    It 'With Details, multiple inputs (array)' {
      Send-Message -Info -Message 'text' -Details @('A', 'B', 'C') 6>$null |
        Should -Be "A`nB`nC"
      Send-Message -Info -Message 'text' -Details 'A', 'B', 'C' 6>$null |
        Should -Be "A`nB`nC"
    }
    It 'Hide Details' {
      Send-Message -Info 'text' -Details 'more text' -HideDetails 6>$null |
        Should -Be 'more text'
    }
    It 'NoNewLine' {
      Send-Message -Info -Message 'text' -Details 'more text' 6>$null |
        Should -Be "more text"
    }
    It 'piped Details' {
      'A','B','C' | Send-Message -Info 'title' 6>$null |
        Should -Be "A`nB`nC"
    }
    It 'With Details, NoNewLine' {
      Send-Message -Info -Message 'text' -Details 'more text' -NoNewLine `
        6>$null | Should -Be 'more text'
      Send-Message -Info -Message 'text' -Details "More`nText" -NoNewLine `
        6>$null | Should -Be "More`nText"
    }
    It 'With Details, NoNewLine (array)' {
      Send-Message -Info 'text' -Details @('a', 'b', 'c') -NoNewLine 6>$null |
        Should -Be "a b c"
      Send-Message -Info 'text' -Details 'a', 'b', 'c' -NoNewLine 6>$null |
        Should -Be "a b c"
    }
    It 'piped Details, HideDetails' {
      'A','B','C' | Send-Message -Info 'title' -HideDetails 6>$null |
        Should -Be "A`nB`nC"
    }
    It 'piped Details, NoNewLine' {
      'a','b','c' | Send-Message -Info 'title' -NoNewLine 6>$null |
        Should -Be "a b c"
    }
  }

  Context 'split Details message' {
    # Enable output to Message console.
    Mock Assert-CI { return $true } -ModuleName Send-Message
    # Catch call to Add-AppveyorMessage, evaluated in reverse order of creation.
    Mock Invoke-Expression { return $false } -ModuleName Send-Message
    # Get parameter after -Details -> return content
    Mock Invoke-Expression {
      $param = [regex]::Match($Command,' -Details[\s:]+\$[^\s"]+').ToString()
      return Get-Variable $param.Remove(0,11) -ValueOnly
    } -ModuleName Send-Message `
      -ParameterFilter { $Command -and $Command -match ' -Details \$.' }

    It 'no need to split if within or at the limit' {
      $out = Send-Message 'title' -Details ('some text' + "`n" + 'more  x') `
        6>$null
      $out.Length | Should -Be 17
      $out | Should -Match '^some text\nmore  x$'
      (Send-Message 'title' -Details ('some    ' + "`r`n" + 'more   ') 6>$null `
        ).Length | Should -Be 12
      $out = Send-Message 'title' `
        -Details ('  some text' + "`n" + '  more  x') 6>$null
      $out.Length | Should -Be 21
      $out | Should -Match '^  some text\n  more  x$'
      (Send-Message 'title' -Details ('some    ' + "`r`n" + 'more' + "`t`t") `
        6>$null).Length | Should -Be 11
    }
    It 'split at LF or CR' {
      $out = Send-Message 'title' -Details ('0123456789' + "`n" + '123456') `
        -MaxLength 15 6>$null
      $out.Length | Should -Be 2
      $out[0] | Should -Be '0123456789'
      $out[1] | Should -Be '123456'
      $out = Send-Message 'title' -Details ('0123456789' + "`r" + '123456') `
        -MaxLength 15 6>$null
      $out.Length | Should -Be 2
      $out[0] | Should -Be '0123456789'
      $out[1] | Should -Be '123456'
      $out = Send-Message 'title' -Details ('0123456789' + "`r`n" + '23456') `
        -MaxLength 15 6>$null
      $out.Length | Should -Be 2
      $out[0] | Should -Be '0123456789'
      $out[1] | Should -Be '23456'
      $out = Send-Message 'title' -Details `
        ('0123456789' + "`n" + '123' + "`n" + '56') -MaxLength 15 6>$null
      $out.Length | Should -Be 2
      $out[0] | Should -Match '^0123456789\n123$'
      $out[1] | Should -Be '56'
      $out = Send-Message 'title' -Details ('0123456789' + "`n" + '123 56') `
        -MaxLength 15 6>$null
      $out.Length | Should -Be 2
      $out[0] | Should -Be '0123456789' -Because 'new line over white space'
      $out[1] | Should -Be '123 56'
      $out = Send-Message 'title' -Details (' 123456789' + "`n" + '123456') `
        -MaxLength 15 6>$null
      $out.Length | Should -Be 2
      $out[0] | Should -Be ' 123456789' -Because 'do not trim leading space'
      $out[1] | Should -Be '123456'
      $out = Send-Message 'title' -Details `
        ("`t" + '123456789' + "`n" + '123456') -MaxLength 15 6>$null
      $out.Length | Should -Be 2
      $out[0] | Should -Be ("`t" + '123456789') `
        -Because 'do not trim leading tab'
      $out[1] | Should -Be '123456'
      $out[0].Length | Should -Be 10
      $out = Send-Message 'title' -Details ("`r`n" + '23456789' + "`n" + '1') `
        -MaxLength 9 6>$null
      $out.Length | Should -Be 2
      $out[0] | Should -Be '23456789'
      $out[1] | Should -Be '1'
      $out = Send-Message 'title' -Details `
        ("`n`n" + '34567 9' + "`n" + '12' + "`n" + '345') -MaxLength 10 6>$null
      $out.Length | Should -Be 2
      $out[0] | Should -Match '^34567 9\n12$'
      $out[1] | Should -Be '345'
    }
    It 'split at white space' {
      $out = Send-Message 'title' -Details ('0123456789 123456') -MaxLength 15 `
        6>$null
      $out.Length | Should -Be 2
      $out[1] | Should -Be '123456'
      $out = Send-Message 'title' -Details ('0123456 89 123456') -MaxLength 15 `
        6>$null
      $out.Length | Should -Be 2
      $out[1] | Should -Be '123456'
      $out = Send-Message 'title' -Details ('012345678  123456') -MaxLength 15 `
        6>$null
      $out.Length | Should -Be 2
      $out[1] | Should -Be '123456'
      $out = Send-Message 'title' -Details ('0123456789 1234 6') -MaxLength 15 `
        6>$null
      $out.Length | Should -Be 2
      $out[1] | Should -Be '6'
      $out = Send-Message 'title' -Details (' 1234567890123456') -MaxLength 9 `
        6>$null
      $out.Length | Should -Be 2
      $out[0] | Should -Be ' 12345678'
      $out[1] | Should -Be '90123456'
      $out = Send-Message 'title' -Details `
        ('0123456789' + "`t" + '123456' + "`t") -MaxLength 15 6>$null
      $out.Length | Should -Be 2
      $out[0] | Should -Be '0123456789'
      $out[1] | Should -Be '123456'
      $out = Send-Message 'title' -Details ("`t" + '123456789012345') `
        -MaxLength 9 6>$null
      $out.Length | Should -Be 2
      $out[0] | Should -Match '^\t12345678'
      $out[1] | Should -Be '9012345'
    }
    It 'split after MaxLength character' {
      '123456789012345' | Send-Message 'title' -HideDetails -LogOnly |
        Should -Be '123456789012345'
      '123456789012345' | Send-Message 'title' -MaxLength 10 -LogOnly |
        Should -Be @('1234567890','12345')
      $out = Send-Message 'title' -Details '01234567890123456' -MaxLength 15 `
        6>$null
      $out.Length | Should -Be 2
      $out[0] | Should -Be '012345678901234'
      $out[1] | Should -Be '56'
      $out = Send-Message 'title' -Details '012345678901234 6' -MaxLength 15 `
        6>$null
      $out.Length | Should -Be 2
      $out[0] | Should -Be '012345678901234'
      $out[1] | Should -Be '6'
      $out = Send-Message 'title' -Details '012345678901234 6' -MaxLength 10 `
        6>$null
      $out.Length | Should -Be 2
      $out[0] | Should -Be '0123456789'
      $out[1] | Should -Be '01234 6'
      $out = Send-Message 'title' -Details ('0123456789' + "`n" + '123456') `
        -MaxLength 15 6>$null
      $out.Length | Should -Be 2
      $out[0] | Should -Be '0123456789'
      $out[1] | Should -Be '123456'
      $out = Send-Message 'title' -Details ('0123456789' + "`n" + '123456') `
        -MaxLength 8 6>$null
      $out.Length | Should -Be 3
      $out[1] | Should -Be '89'
      $out[2] | Should -Be '123456'
      $out = Send-Message 'title' -Details (' 1234567890123456') -MaxLength 9 `
        6>$null
      $out.Length | Should -Be 2
      $out[0] | Should -Be ' 12345678'
      $out[1] | Should -Be '90123456'
    }
    It 'always split at form feed character (FF)' {
      $out = Send-Message 'title' -Details ("`f" + '1234567890') 6>$null
      $out.Length | Should -Be 11
      $out = Send-Message 'title' -Details ("`f" + '1234567890') -MaxLength 9 `
        6>$null
      $out.Length | Should -Be 2
      $out[0].Length | Should -Be 9
      $out = Send-Message 'title' -Details ('0123456789' + "`f" + '12345') `
        6>$null
      $out.Length | Should -Be 2
      $out[0] | Should -Be '0123456789'
      $out[1] | Should -Be '12345'
      $out = Send-Message 'title' -Details ('0123456789' + "`f") 6>$null
      $out.Length | Should -Be 11
      $out = Send-Message 'title' -Details ('123456789' + "`f") -MaxLength 7 `
        6>$null
      $out.Length | Should -Be 2
      $out[1].Length | Should -Be 2
      $out[1] | Should -Be '89'
      $out = Send-Message 'title' -Details ('0123456789' + "`f`f`f`f" + '45') `
        6>$null
      $out.Length | Should -Be 2
      $out[0] | Should -Be '0123456789'
      $out[1] | Should -Be '45'
      $out = Send-Message 'title' -Details ('0123' + "`f" + '56789' + "`f" +
        '12345') 6>$null
      $out.Length | Should -Be 3
      $out = Send-Message 'title' -Details ('0123456789' + "`f" + '12345') `
        -MaxLength 12 6>$null
      $out.Length | Should -Be 2
      $out[0] | Should -Be '0123456789'
      $out = Send-Message 'title' -Details ('0123' + "`f" + '56789' + "`n" +
        '12345') -MaxLength 12 6>$null
      $out.Length | Should -Be 2
      $out[0] | Should -Be '0123'
      $out = Send-Message 'title' -Details ('0123456789' + "`f" + '12345') `
        -MaxLength 8 6>$null
      $out.Length | Should -Be 3 -Because 'first splits at character limit'
      $out[0] | Should -Be '01234567'
      $out[1] | Should -Be '89'
      $out[2] | Should -Be '12345'
    }
  } # Context 'split Details message'

  Context 'Call to Add-AppveyorMessage - return Message (title)' {
    # Enable output to Message console.
    Mock Assert-CI { return $true } -ModuleName Send-Message
    # Catch call to Add-AppveyorMessage.
    Mock Invoke-Expression { return $false } -ModuleName Send-Message
    Mock Send-Message {
      return $Message
    } -ModuleName Send-Message -ParameterFilter { $Message }

    It 'verify multi-message title' {
      $out = Send-Message -Message 'title' -Details '123456789' -LogOnly
      $out | Should -Be $false
      $out = Send-Message -Message 'titleX' -Details '123456789' -LogOnly `
        -MaxLength 6
      $out.Length | Should -Be 2
      $out[0] | Should -Be 'titleX [1/2]'
      $out[1] | Should -BeExactly 'titleX [2/2]' -Because 'case sensitive'
      $out = Send-Message -Message 'title' -Details ('123456789' + "`f" + `
        '12345') -LogOnly
      $out.Length | Should -Be 2
      $out = Send-Message -Message 'title' -Details ('123456789' + "`f" + `
        '12345') -LogOnly -MaxLength 8
      $out.Length | Should -Be 3
      $out[0] | Should -Be 'title [1/3]'
      $out[1] | Should -Be 'title [2/3]'
      $out[2] | Should -Be 'title [3/3]'
    }
    It 'verify multi-message title (warning)' {
      $out = Send-Message -Warning 'issue' -Details '123456789' -LogOnly `
        -MaxLength 6
      $out.Length | Should -Be 2
      $out[0] | Should -Be 'issue [1/2]'
      $out[1] | Should -Be 'issue [2/2]'
    }
    It 'verify multi-message title (error)' {
      $out = Send-Message -Error 'issue' -Details '123456789' -LogOnly `
        -MaxLength 6
      $out.Length | Should -Be 2
      $out[0] | Should -Be 'issue [1/2]'
      $out[1] | Should -Be 'issue [2/2]'
    }
  }

  Context 'split Details Error message' {
    # Enable output to Message console.
    Mock Assert-CI { return $true } -ModuleName Send-Message
    # Catch call to Add-AppveyorMessage, preventing calls to AppveyorMessage.
    Mock Invoke-Expression { } -ModuleName Send-Message
    Mock Stop-Execution { return 'error2' } -ModuleName Send-Message
    # Get parameter after -Details -> return content
    Mock Send-Message {
      if ($ContinueOnError -eq $true) { return $Details }
      else { return 'error1' }
    } -ModuleName Send-Message -ParameterFilter { $ContinueOnError }

    # only last part of message throws and stops execution
    It 'last part should error' {
      $out = (Send-Message -Error 'title' -Details '123456789012345' `
        -MaxLength 5 6>$null)
      $out.Length | Should -Be 3
      $out[0] | Should -Be '12345'
      $out[1] | Should -Be '67890'
      $out[2] | Should -Be 'error2'
    }
  }
}

Describe 'LiveTest Send-Message' {
  It '1000 character limit on AppVeyor' {
    if (-not (Assert-CI)) {
      Set-ItResult -Inconclusive -Because 'not on AppVeyor'
    }
    $text = ('Character_1000_is_a_"|"_' +
        'preceded_by_a_countdown_and_followed_by_"X12345"._' +
        'The_X_should_not_show_up_in_either_message.').PadRight(990,'_')
    $text += '987654321|X12345'
    Send-Message 'Live Test: 1000 character limit on AppVeyor' -Details $text `
      -LogOnly -MaxLength 1001
  }
}

Describe 'LiveTest Send-Message' {
  It 'Info' {
    Send-Message -Info 'Test Info' -Details ('some text' + "`n" + `
      'more text') -LogOnly
  }
  It 'Warning' {
    Send-Message -Warning 'Test Warning' -Details ('some text' + "`n" + `
      'more text') -LogOnly
  }
  It 'Error' {
    Send-Message -Error 'Test Warning' -Details ('some text' + "`n" + `
      'more text') -LogOnly
  }
}
