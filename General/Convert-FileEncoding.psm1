Set-StrictMode -Version Latest
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Change the character encoding used in a text file.
.DESCRIPTION
  Re-encode files to use a different character encoding.
  The default is Unicode UTF-8 without a byte-order-mark. (UTF8NoBOM)

  Optionally set a consistent new-line character style.
.NOTES
  1. UTF-8 without BOM (UTF8NoBOM) requires at least PowerShell v6.
     When pwsh (PowerShell core) is present on the system it will be called for
     conversions not supported by the active version.
  2. Encoding: UTF8 is equivalent to UTF8BOM.
  3. LineEnding: Windows is equivalent to CRLF and Unix is equivalent to LF.
.EXAMPLE
  Convert-FileEncoding '.\*.md'
  
  All markdown files in the current directory are converted to use UTF-8
  without a byte-order-mark. This is the default behaviour. Equivalent to:
  Convert-FileEncoding -SourcePath '.\*.md' -Encoding UTF8NoBOM
.EXAMPLE
  Convert-FileEncoding -Path '.\some.txt' -Encoding ASCII

  Only convert the file some.txt to use the ASCII character set.
  Be aware: Not all characters are supported in ASCII, potential loss of data.
  -Path can be used as an alias for -SourcePath.
.EXAMPLE
  Convert-FileEncoding '.\*.md' -LineEnding Unix

  Convert the file to the default character encoding: UTF-8 without BOM, and
  replace all line-endings with a line-feed (LF or \n).
.EXAMPLE
  Convert-FileEncoding '.\*.md' UTF8NoBOM Unix

  Minimal to set everything.
#>
function Convert-FileEncoding {
  [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Medium')]
  param(
    [ValidateScript({ Test-Path -Path "$_" })]
    [ValidateNotNullOrEmpty()]
    [SupportsWildcards()]
    [Alias('Path')]
    [String]$SourcePath,
    [ValidateSet('ASCII','UTF8','UTF8BOM','UTF8NoBOM')]
    [String]$Encoding = 'UTF8NoBOM',
    [ValidateSet('Lf','CrLf','Cr','Windows','Unix')]
    [Alias('EOL')]
    [String]$LineEnding
  )
  Begin
  {
    Get-CommonFlagsCaller $PSCmdlet $ExecutionContext.SessionState

    if (-not ($SourcePath -or $MyInvocation.ExpectingInput) ) {
       throw '-SourcePath is a required parameter'
    }
    # Check environment.
    $UsePWSH = $null
    if ( ( $PSVersionTable.PSVersion.Major -lt 6 ) -and
         ( @('UTF8NoBOM','UTF8BOM') -contains $Encoding )
    ) {
      Write-Verbose 'Legacy PowerShell detected. No support for $Encoding.'
      if (Test-Command 'Get-Command pwsh') {
        Write-Verbose "Running $(${MyInvocation}.MyCommand) in Pwsh."
        $UsePWSH = $true
      } else {
        throw "$Encoding requires at least PowerShell version 6"
      }
    }
  }
  Process
  {
    if ($UsePWSH) {
      Write-Verbose 'Start a new shell: pwsh'
      if ($LineEnding) {
        Invoke-Expression -Command "pwsh {
          Import-Module `"${PSScriptRoot}\Convert-FileEncoding.psd1`"
          $(${MyInvocation}.MyCommand) -SourcePath `"$SourcePath`" ```
            -Encoding:$Encoding -LineEnding:$LineEnding
        }"
      } else {
        Invoke-Expression -Command "pwsh {
          Import-Module `"${PSScriptRoot}\Convert-FileEncoding.psd1`"
          $(${MyInvocation}.MyCommand) -SourcePath `"$SourcePath`" ```
            -Encoding:$Encoding
        }"
      }
    } else {
      # Execute in current shell:
      ForEach ($file in $(Get-ChildItem $SourcePath)) {
        Write-Verbose "Converting $file to $Encoding"
        $CACHE = Get-Content $file -Raw
        if ($LineEnding -and (Test-NeedProcessing $CACHE $LineEnding)) {
          $CACHE = Convert-EOL $CACHE -LineEnding:$LineEnding
        }
        Set-Content -Path $file.FullName -Value $CACHE -Encoding $Encoding `
          -Force -NoNewline
      }
    }
  }
  End
  {
  }
} #/ function Convert-FileEncoding
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Replace newline characters.
.DESCRIPTION
  Replace any occurrence of CRLF (Windows), LF (Unix) or CR (legacy MacOS).
.NOTES
  1. $SourcePath needs to be defined in calling scope!
  2. Expects execution only after Test-MixedEOL returns True.
     Bulletproofing the logic by input validation.
#>
function Convert-EOL {
  [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Low')]
  [OutputType([String])]
  param(
    [Parameter(ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [String]$Text,
    [ValidateNotNullOrEmpty()]
    [String]$LineEnding = $(throw '-LineEnding is a required parameter')
  )
  Begin
  {
    Get-CommonFlagsCaller $PSCmdlet $ExecutionContext.SessionState

    if (-not ($Text -or $MyInvocation.ExpectingInput) ) {
       throw '-Text is a required parameter'
    }
    Write-Verbose "Replace newline characters with $LineEnding"
    switch -regex ($LineEnding)
    {
      '^Lf|Unix'     { $new = "`n";   break }
      'CrLf|Windows' { $new = "`r`n"; break }
      'Cr$'          { $new = "`r";   break }
      default        { throw "Unknown LineEnding input." }
    }
  }
  Process
  {
    if ($PSCmdlet.ShouldProcess($([ref]$SourcePath).Value,
        "Replace newline characters")
    ) {
      return $Text -replace '\r?\n|\r',$new
    } else {
      return $Text
    }
  }
  End
  {
  }
} #/ function Convert-EOL
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Decision to process line-endings in the supplied text.
  Returns True on mixed use or when different from preferred line-ending style.
.DESCRIPTION
  Test a String for possible inconsistent use of line-endings.
  Use for validation or decision before processing.
#>
function Test-NeedProcessing {
  [OutputType([Bool])]
  param(
    [String]$Text = $(throw '-Text is a required parameter'),
    [ValidateSet('Lf','CrLf','Cr','Windows','Unix')]
    [String]$LineEnding
  )
  Begin
  {
    switch -regex ($LineEnding) {
      'Unix' { $LineEnding = 'LF'; break }
      'Windows' { $LineEnding = 'CRLF' }
    }
  }
  Process
  {
    $Count = Get-EndOfLineCount $Text

    $sum = 0
    $Count.Values.ForEach({ $sum += $_ })

    return $sum -and (
      ($LineEnding -and $sum -ne $Count[$LineEnding]) -or
      $Count.Values -notcontains $sum
    )
  }
} #/ function Test-NeedProcessing
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Count occurrence of different line-ending characters.
#>
function Get-EndOfLineCount {
  param(
    [ValidateNotNull()]
    [String]$Text = $(throw '-Text is a required parameter'),
    [ValidateNotNullOrEmpty()]
    [String]$LineEnding
  )
  Process
  {
    $Count_CRLF = 0; $Count_LF = 0; $Count_CR = 0
    if ($LineEnding -and !$Text) {
      return 0
    }
    $Count_CRLF = ([regex]::Matches($Text, '\r\n')).Count
    if ($LineEnding -and $LineEnding -match 'CRLF|Windows') {
      return $Count_CRLF
    }
    $Count_LF = ([regex]::Matches($Text,'\n')).Count - $Count_CRLF
    if ($LineEnding -and $LineEnding -match 'LF|Unix') {
      return $Count_LF
    }
    $Count_CR = ([regex]::Matches($Text,'\r')).Count - $Count_CRLF
    if ($LineEnding -and $LineEnding -match 'CR') {
      return $Count_CR
    }
    if ($LineEnding) { throw "Unexpected LineEnding: $LineEnding" }

    return @{
      CRLF = $Count_CRLF;
      LF = $Count_LF;
      CR = $Count_CR
    }
  }
} #/ function Get-EndOfLineCount
##====--------------------------------------------------------------------====##

Export-ModuleMember -Function Convert-FileEncoding
