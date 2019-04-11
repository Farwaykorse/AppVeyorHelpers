Import-Module -Name "${PSScriptRoot}\Send-Message.psm1" -Force

Set-StrictMode -Version Latest

##====--------------------------------------------------------------------====##
$global:msg_documentation = 'at least 1 empty line above documentation'
$global:msg_interactive = 'executed in interactive PowerShell session'

##====--------------------------------------------------------------------====##
Describe 'Internal Assert-CI' {
  InModuleScope Send-Message {
    It 'has documentation' {
      Get-Help Assert-CI | Out-String | Should -MatchExactly 'SYNOPSIS' `
        -Because $msg_documentation
    }
    It 'checks if on a CI platform' {
      if ($env:APPVEYOR -or $env:CI) {
        Assert-CI | Should -Be $true
      } else {
        Assert-CI | Should -Be $false
      }
    }
  }
}

##====--------------------------------------------------------------------====##
Describe 'Send-Message' {
  It 'has documentation' {
    Get-Help Send-Message | Out-String |
      Should -MatchExactly 'SYNOPSIS' -Because $msg_documentation
  }
  Context 'Input Errors' {
    # Suppress output to Message console.
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
    It 'Throw for empty Message input' {
      { Send-Message -Message '' } |
        Should -Throw 'argument is null or empty'
    }
    It 'Throw for $null Message input' {
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
    It 'Throw for empty Details input' {
      if ($PSVersionTable.PSVersion.major -lt 6) {
        { Send-Message -Message 'title' -Details '' } |
          Should -Throw 'argument is null or empty'
      } else {
        { Send-Message -Message 'title' -Details '' } |
          Should -Throw 'argument is null, empty'
      }
    }
    It 'Throw for $null Details input' {
      { Send-Message -Message 'title' -Details $null } |
        Should -Throw 'argument is null or empty'
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
    It 'With Details, multiple inputs, no label' {
      Send-Message -Info -Message 'text' 'a' 'b' 'c' 6>&1 |
        Should -Be "INFO: text`n-- a`n-- b`n-- c"
      if ($PSVersionTable.PSVersion.major -lt 6) {
        Send-Message -Info -Message 'text' @('a', 'b', 'c') 6>&1 |
          Should -Be "INFO: text`n-- a b c"
        Send-Message -Info -Message 'text' 'a', 'b', 'c' 6>&1 |
          Should -Be "INFO: text`n-- a b c"
      } else {
        Send-Message -Info -Message 'text' @('a', 'b', 'c') 6>&1 |
          Should -Be "INFO: text`n-- a`n-- b`n-- c"
        Send-Message -Info -Message 'text' 'a', 'b', 'c' 6>&1 |
          Should -Be "INFO: text`n-- a`n-- b`n-- c"
      }
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
    It 'With Details, multiple inputs, no label' {
      Send-Message -Warning -Message 'text' 'a' 'b' 'c' 3>&1 |
        Should -Be "text`na`nb`nc"
      if ($PSVersionTable.PSVersion.major -lt 6) {
        Send-Message -Warning -Message 'text' @('a', 'b', 'c') 3>&1 |
          Should -Be "text`na b c"
        Send-Message -Warning -Message 'text' 'a', 'b', 'c' 3>&1 |
          Should -Be "text`na b c"
      } else {
        Send-Message -Warning -Message 'text' @('a', 'b', 'c') 3>&1 |
          Should -Be "text`na`nb`nc"
        Send-Message -Warning -Message 'text' 'a', 'b', 'c' 3>&1 |
          Should -Be "text`na`nb`nc"
      }
    }
    It 'Hide Details' {
      Send-Message -Warning 'text' -Details 'more text' -HideDetails 3>&1 |
        Should -Be 'text'
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
  Context 'Add-AppveyorMessage Details' {
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
    It 'With Details, multiple inputs, no label' {
      Send-Message -Info -Message 'text' 'A' 'B' 'C' 6>$null |
        Should -Be "A`nB`nC"
      if ($PSVersionTable.PSVersion.major -lt 6) {
        Send-Message -Info -Message 'text' @('A', 'B', 'C') 6>$null |
          Should -Be 'A B C'
        Send-Message -Info -Message 'text' 'A', 'B', 'C' 6>$null |
          Should -Be 'A B C'
      } else {
        Send-Message -Info -Message 'text' @('A', 'B', 'C') 6>$null |
          Should -Be "A`nB`nC"
        Send-Message -Info -Message 'text' 'A', 'B', 'C' 6>$null |
          Should -Be "A`nB`nC"
      }
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
}
