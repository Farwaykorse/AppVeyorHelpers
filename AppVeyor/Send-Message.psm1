Set-StrictMode -Version Latest
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
   AppVeyor compatible console output.
.DESCRIPTION
   Send output to both the console and the AppVeyor message API.
.FUNCTIONALITY
  Messages send to the message API are split into multiple messages when they
  exceed the character limit.
.EXAMPLE
  Send-Message 'Message text or title'
  INFO: Message text or title

  --- Equivalent: ---
  Send-Message -Info 'Message text or title'
.EXAMPLE
  Send-Message -Error 'text or title'
  ERROR: text or title
.EXAMPLE
  Send-Message -Warning 'text or title'
  WARNING: text or title
.EXAMPLE
  Send-Message 'Message title' -Details 'Extensive description'
  INFO: Message text or title
  -- Extensive description
.EXAMPLE
  Send-Message 'Title' -Details 'Multi-line description',
    'with additional information', 'To help understand the problem'
  INFO: Title
  -- Multi-line description
  -- with additional information
  -- To help understand the problem
.EXAMPLE
  Send-Message 'Title' -Details word, 5, 'text with spaces', "and a`n newline"
  INFO: Title
  -- word
  -- 5
  -- text with spaces
  -- and a
  --  newline
.EXAMPLE
  Send-Message 'Title' -Details 'word 5', "text a manual`nNewline" -NoNewLine
  INFO: Title
  -- word 5 text with a manual
  -- Newline
.EXAMPLE
  'Details over',"multiple`nlines" | Send-Message 'Title' -Warning
  WARNING: Title
  Details over
  multiple
  lines
.EXAMPLE
  Send-Message 'Title' -Details text -HideDetails
  INFO: Title
#>
function Send-Message {
  param(
    [parameter(Position=0,Mandatory)]
    [ValidateNotNullOrEmpty()]
    [alias('m','Title')]
    # Message string is always displayed and serves as title in the Message log.
    [String]$Message,
    [parameter(ValueFromPipeline,ParameterSetName='ErrorDetails',Mandatory)]
    [parameter(ValueFromPipeline,ParameterSetName='WarningDetails',Mandatory)]
    [parameter(ValueFromPipeline,ParameterSetName='Details',Mandatory)]
    [AllowEmptyString()]
    [alias('d','Body')]
    # Additional information. Reported on the Message log.
    [String[]]$Details,
    [parameter(ParameterSetName='Info')]
    [parameter(ParameterSetName='Details')]
    # Publish as an informational message in the Message console (default).
    [Switch]$Info,
    [parameter(ParameterSetName='Warning',Mandatory)]
    [parameter(ParameterSetName='WarningDetails',Mandatory)]
    # Publish as warning in the Message console.
    [Switch]$Warning,
    [parameter(ParameterSetName='Error',Mandatory)]
    [parameter(ParameterSetName='ErrorDetails',Mandatory)]
    # Publish as an error in the Message console.
    [Switch]$Error,
    [parameter(ParameterSetName='Error')]
    [parameter(ParameterSetName='ErrorDetails')]
    # Display and publish to the message console, but do not throw and continue
    # execution.
    [Switch]$ContinueOnError,
    [parameter(ParameterSetName='Details')]
    [parameter(ParameterSetName='ErrorDetails')]
    [parameter(ParameterSetName='WarningDetails')]
    [alias('Hide','h')]
    # Don't show Details on the console, only in the Message log.
    [Switch]$HideDetails,
    # Only display in the Message log, no message on the build console.
    # This is only useful on AppVeyor.
    # Implies -HideDetails and -ContinueOnError.
    [Switch]$LogOnly,
    [parameter(ParameterSetName='Details')]
    [parameter(ParameterSetName='ErrorDetails')]
    [parameter(ParameterSetName='WarningDetails')]
    # Concatenate all inputs to Details into a single string.
    [Switch]$NoNewLine,
    [parameter(ParameterSetName='Details')]
    [parameter(ParameterSetName='ErrorDetails')]
    [parameter(ParameterSetName='WarningDetails')]
    [ValidateRange(1,[Int32](2147483647))]
    # Separate into multiple messages on message API when exceeded.
    [Int]$MaxLength = 1000
  )
  Begin
  {
    $intDetails = @();
    if ($LogOnly -and -not ($ContinueOnError)) { $ContinueOnError = $true }
  }
  Process
  {
    if ($Details) {
      $intDetails += $Details
    }
  }
  End
  {
    if ($intDetails) {
      $intDetails = $(
        if ($NoNewLine) {
          $intDetails -join ' ' -replace "`n ([^ ])", "`n`$1"
        } else {
          $intDetails -join "`n"
        }
      )
      $intDetails = $intDetails -replace '[ \t]*\r?\n',"`n"
    }
    if (Assert-CI) {
      # Send to AppVeyor Message API
      $textSplit = Split-Text $intDetails -MaxLength:$MaxLength
      if ( -not ($intDetails) -or
        ( $textSplit.GetType().Name -eq 'String') # less than MaxLength
      ) {
        $AppVeyor = 'Add-AppveyorMessage ${Message} -Category '
        if       ($Error) {   $AppVeyor += 'Error'
        } elseif ($Warning) { $AppVeyor += 'Warning'
        } else {              $AppVeyor += 'Information'
        }
        if ($intDetails) { $AppVeyor += ' -Details $intDetails' }
        Invoke-Expression -Command $AppVeyor
      } else { # Divide over multiple messages
        $i = 0
        foreach ($part in $textSplit) {
          $i++
          if ($Error) {
            $continue = ($ContinueOnError -or ($i -lt $textSplit.Length) )
            Send-Message -Error:$Error -LogOnly:$true `
              -Message ($Message + ' [' + $i + '/' + $textSplit.Length + ']') `
              -Details:$part -HideDetails:$HideDetails -MaxLength:$MaxLength `
              -ContinueOnError:$continue
          } else { # -Warning or -Info
            Send-Message -Warning:$Warning -LogOnly:$true `
              -Message ($Message + ' [' + $i + '/' + $textSplit.Length + ']') `
              -Details:$part -HideDetails:$HideDetails -MaxLength:$MaxLength
          }
        }
      }
    }
    if (-not $LogOnly) {
      if ($Error) {
        Write-Host "ERROR: $Message" -ForegroundColor White -BackgroundColor Red
        if ($intDetails -and -not $HideDetails) {
          Write-Host $intDetails -ForegroundColor Red
        }
        if (-not $ContinueOnError) {
          if (Assert-CI) { $Host.SetShouldExit(1) }
          throw $Message
        }
      } elseif ($Warning) {
        if ($intDetails -and -not $HideDetails) { $Message += "`n${intDetails}" }
        Write-Warning $Message
      } else {
        if ($intDetails -and -not $HideDetails) {
          $Message += "`n$("-- $intDetails" -replace "`n", "`n-- ")"
        }
        Write-Host "INFO: $Message"
      }
    }
  }
} # /function Send-Message
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Determine where to split the text to stay within the maximum length.
.DESCRIPTION
  Order of preference:
  1. split at a form feed (FF)
  2. no need to split if within or at the limit.
  3. split at the last new-line (LF or CR) character within the limit.
  4. split after the last white space character within the limit.
  5. split after the character at the limit.
#>
function Find-SplitLocation {
  [OutputType([Int32])]
  param(
    [String]$Text = $(throw '-Text is required'),
    [Int]$MaxLength = $(throw '-MaxLength is required')
  )
  $loc = $Text.IndexOf("`f") # FF
  if ( ($loc -ge 0) -and ($loc -le $MaxLength) ) {
    return $loc
  }
  if ($Text.Length -gt $MaxLength) {
    $loc = [System.Math]::Max(
      $Text.LastIndexOf("`n", $MaxLength), # LF
      $Text.LastIndexOf("`r", $MaxLength)  # CR
    )
  } else {
    return $Text.Length
  }
  if ($loc -le 0) {
    $loc = [System.Math]::Max(
      $Text.LastIndexOf(' ', $MaxLength),
      $Text.LastIndexOf("`t", $MaxLength)
    ) + 1 # don't start next section with the white space character
    if ($loc -le 1) {
      return $MaxLength
    }
  }
  return $loc
}
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Returns the input text as an array of sections with the given maximum length.
.DESCRIPTION
  Order of preference:
  1. split at a form feed (FF)
  2. no need to split if within or at the limit.
  3. split at the last new-line (LF or CR) character within the limit.
  4. split after the last white space character within the limit.
  5. split after the character at the limit.
.NOTES
  Special UTF-8 characters consisting of multiple characters, can break when
  splitting at the character limit.
#>
function Split-Text {
  [OutputType([String[]])]
  param(
    [String]$Text = $(throw '-Text is required'),
    [Int]$MaxLength = $(throw '-MaxLength is required')
  )
  Begin
  {
    $work = $Text.TrimStart("`f","`r","`n").TrimEnd()
    $out = @()
  }
  Process
  {
    while ($true) {
      $loc = Find-SplitLocation $work $MaxLength
      if ($loc -eq 0) { break }
      $out += $work.Substring(0, $loc).TrimEnd()
      $work = $work.Substring($loc).TrimStart("`f","`r","`n")
    }
  }
  End
  {
    return $out
  }
}
##====--------------------------------------------------------------------====##

Export-ModuleMember -Function Send-Message
