Set-StrictMode -Version Latest
##====--------------------------------------------------------------------====##

<#
.Synopsis
  Test a command for errors or output.
.DESCRIPTION
  Executes any command, but be aware of side effects!
  Mode 1:
  Executes any command and tests for errors or a non-zero exit code.
  Mode 2:
  If a match is given errors are ignored, only checks if the output matches the
  supplied regular expression.
.FUNCTIONALITY
  By default matches with the success stream (1) and the information stream (6).
.EXAMPLE
  Test-Command -Command 'Throw "some error"'
  False
.EXAMPLE
  Test-Command -Command 'PowerShell exit 123'
  False
.EXAMPLE
  Test-Command -Command 'PowerShell exit 123' -IgnoreExitCode
  True
.EXAMPLE
  Test-Command -Command 'Write-Output "hey"' -cMatch 'HEY'
  False
.EXAMPLE
  Test-Command -Command 'PowerShell { Write-Output "hey"; exit 1 }' -Match '^.e'
  True
.EXAMPLE
  Test-Command -Command 'Write-Host "hey"' -Match 'hey'
  True
.EXAMPLE
  Test-Command 'Write-Error something'
  False
.EXAMPLE
  Test-Command 'Write-Error something 2>&1' -cMatch 'thing'
  True
.OUTPUTS
  A Boolean value is returned. True when execution succeeds without errors or
  the output sting matches.
  $LASTEXITCODE is always 0 after execution in Mode 1 (non-matching).
.NOTES
  Not capable of containing $Hosts.SetShouldExit().
#>
function Test-Command {
  [OutputType([Bool])]
  param(
    [Parameter(Position=0,Mandatory)]
    [ValidateNotNullOrEmpty()]
    # Command to evaluate.
    [String]$Command,
    [Parameter(Position=1,ParameterSetName='imatch',Mandatory)]
    [ValidateNotNullOrEmpty()]
    [Alias('iMatch')]
    # Return string to match (case insensitive).
    [String]$Match,
    [Parameter(Position=1,ParameterSetName='cmatch',Mandatory)]
    [ValidateNotNullOrEmpty()]
    # Return string to match (case sensitive).
    [String]$cMatch,
    [Parameter(ParameterSetName='command')]
    # Evaluate command for thrown exceptions, but ignore non-zero exit-codes.
    [Switch]$IgnoreExitCode
  )
  if ($Match) {
    return Test-Output -Command:$Command -Match:$Match
  } elseif ($cMatch) {
    return Test-Output -Command:$Command -Match:$cMatch -CaseSensitive
  } else {
    return Test-ErrorFree $Command -IgnoreExitCode:$IgnoreExitCode
  }
}
##====--------------------------------------------------------------------====##

function Test-Output {
  param(
    [ValidateNotNullOrEmpty()]
    [String]$Command,
    [ValidateNotNullOrEmpty()]
    [String]$Match,
    [Switch]$CaseSensitive
  )
  try {
    if ($CaseSensitive) {
      if ((Invoke-Expression $Command 2>$null 6>&1) -cmatch $Match ) {
        return $true
      }
    } else {
      if ((Invoke-Expression $Command 2>$null 6>&1) -imatch $Match ) {
        return $true
      }
    }
  } catch {}
  return $false
}
##====--------------------------------------------------------------------====##

# check if command executes without error
function Test-ErrorFree {
  param(
    [ValidateNotNullOrEmpty()]
    [String]$Command,
    [Switch]$IgnoreExitCode
  )
  Begin
  {
    $global:LASTEXITCODE = 0 # Hiding global exit code!
  }
  Process
  {
    try {
      $err_out = (
        Invoke-Expression $Command 1>$null 3>$null 4>$null 5>$null 6>$null
      ) 2>&1
    } catch {
      return $false
    }
    if (!$? -or $err_out -or (-not $IgnoreExitCode -and $LASTEXITCODE)) {
      return $false
    } else {
      return $true
    }
  }
  End
  {
    $global:LASTEXITCODE = 0
  }
}
##====--------------------------------------------------------------------====##

Export-ModuleMember -Function Test-Command
