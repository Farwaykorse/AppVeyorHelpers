Set-StrictMode -Version Latest
##====--------------------------------------------------------------------====##

<#
.Synopsis
  Test a command for errors or output.
.DESCRIPTION
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
#>
function Test-Command {
  [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Low')]
  [OutputType([Bool])]
  param(
    [Parameter(Position=0,Mandatory)]
    [ValidateNotNullOrEmpty()]
    [String]$Command,
    [Parameter(Position=1,ParameterSetName='imatch',Mandatory)]
    [ValidateNotNullOrEmpty()]
    [Alias('iMatch')]
    [String]$Match,
    [Parameter(Position=1,ParameterSetName='cmatch',Mandatory)]
    [ValidateNotNullOrEmpty()]
    [String]$cMatch,
    [Parameter(ParameterSetName='command')]
    [Switch]$IgnoreExitCode
  )
  if ($Match) {
    return Match-Output -Command:$Command -Match:$Match
  } elseif ($cMatch) {
    return Match-Output -Command:$Command -Match:$cMatch -CaseSensitive
  } else {
    return Test-ErrorFree $Command -IgnoreExitCode:$IgnoreExitCode
  }
}

##====--------------------------------------------------------------------====##
function Match-Output {
  [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Low')]
  param(
    [ValidateNotNullOrEmpty()]
    [String]$Command,
    [ValidateNotNullOrEmpty()]
    [String]$Match,
    [Switch]$CaseSensitive
  )
  trap {
    continue
  }
  if ($CaseSensitive) {
    if ((Invoke-Expression $Command 2>$null 6>&1) -cmatch $Match ) {
      return $true
    }
  } else {
    if ((Invoke-Expression $Command 2>$null 6>&1) -imatch $Match ) {
      return $true
    }
  }
  return $false
}

##====--------------------------------------------------------------------====##
# check if command executes without error
function Test-ErrorFree {
  [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Low')]
  param(
    [ValidateNotNullOrEmpty()]
    [String]$Command,
    [Switch]$IgnoreExitCode
  )
  if (-not $IgnoreExitCode -and $LASTEXITCODE) {
    $LASTEXITCODE = 0 # Hiding global exit code!
  }
  trap {
    return $false
  }
  $err_out = (Invoke-Expression $Command 1>$null 3>$null 4>$null 5>$null 6>$null) 2>&1
  if ($err_out -or (-not $IgnoreExitCode -and $LASTEXITCODE)) {
    return $false
  } else {
    return $true
  }
}

##====--------------------------------------------------------------------====##
Export-ModuleMember -Function Test-Command
