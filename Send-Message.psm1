Set-StrictMode -Version Latest
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
   AppVeyor compatible console output.
.DESCRIPTION
   Send output to both the console and the AppVeyor message API.
.FUNCTIONALITY
  
.EXAMPLE
  Send-Message 'Message text or title'
  INFO: Message text or title

  --- Equivalent: ---
  Message 'Message text or title'
  Send-Message 'Message text or title' -Info
.EXAMPLE
  Send-Message -Error 'text or title'
  ERROR: text or title

  --- Equivalent: ---
  Error 'text or title'
.EXAMPLE
  Send-Message -Warning 'text or title'
  WARNING: text or title

  --- Equivalent: ---
  Warning 'text or title'
.EXAMPLE
  Send-Message 'Message title' -Details 'Extensive description'
  INFO: Message text or title
  -- Extensive description

  --- Equivalent: ---
  Send-Message 'Message title' 'Extensive description'
.EXAMPLE
  Send-Message 'Title' -Details 'Multi-line description', 'with additional information', 'To help understand the problem'
  INFO: Title
  -- Multi-line description
  -- with additional information
  -- To help understand the problem

  --- Equivalent: ---
  Send-Message 'Title' 'Multi-line description' 'Notice: no commas!'
.EXAMPLE
  Send-Message 'Title' word 5 'text with spaces' "and a `n newline"
  INFO: Title
  -- word
  -- 5
  -- text with spaces
  -- and a 
  --  newline

  --- Equivalent: ---
  Send-Message 'Title' -Details word, 5, 'text with spaces', "and a `n newline"
  (Notice the use of the ',' operator.)
.EXAMPLE
  Send-Message 'Title' word 5 "text a manual `n newline" -NoNewLine
  INFO: Title
  -- word 5 text with a manual 
  -- newline
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
    [parameter(Position=1,ValueFromRemainingArguments,ValueFromPipeline,
      ParameterSetName='ErrorDetails',Mandatory)]
    [parameter(Position=1,ValueFromRemainingArguments,ValueFromPipeline,
      ParameterSetName='WarningDetails',Mandatory)]
    [parameter(Position=1,ValueFromRemainingArguments,ValueFromPipeline,
      ParameterSetName='Details',Mandatory)]
    [ValidateNotNullOrEmpty()]
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
    # Concatenate all inputs to Details into a single string.
    [parameter(ParameterSetName='Details')]
    [parameter(ParameterSetName='ErrorDetails')]
    [parameter(ParameterSetName='WarningDetails')]
    [Switch]$NoNewLine
  )
  Begin
  {
    $intDetails = @();
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
          $intDetails -join ' ' -replace "`n ([^\s])", "`n`$1"
        } else {
          $intDetails -join "`n"
        }
      )
    }
    if (Assert-CI) {
      # Send to AppVeyor Message API
      $AppVeyor = 'Add-AppveyorMessage ${Message} -Category '
      if       ($Error) {   $AppVeyor += 'Error'
      } elseif ($Warning) { $AppVeyor += 'Warning'
      } else {              $AppVeyor += 'Information'
      }
      if ($intDetails) { $AppVeyor += ' -Details $intDetails' }
      Invoke-Expression -Command $AppVeyor
    }
    if ($Error) {
      Write-Host "ERROR: $Message" -ForegroundColor White -BackgroundColor Red
      if ($intDetails -and -not $HideDetails) {
        Write-Host $intDetails -ForegroundColor Red
      }
      if (-not $ContinueOnError) {
        if (Assert-CI) {
          $Host.SetShouldExit(1)
        } else { throw $Message }
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
} # /function Send-Message
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Check if executed on the AppVeyor CI platform.
.DESCRIPTION
  Basic check for variables, allows for simple mocking.
#>
function Assert-CI {
  return ($env:APPVEYOR -or $env:CI)
}
##====--------------------------------------------------------------------====##

Export-ModuleMember -Function Send-Message
