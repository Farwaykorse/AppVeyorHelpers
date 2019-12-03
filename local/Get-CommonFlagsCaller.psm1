Set-StrictMode -Version Latest
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Acquire the preference variables from the calling function.
.DESCRIPTION
  Functions in script modules do not inherit the preference flags.
  This function helps to get the same behaviour as the build-in functions.

  This is equivalent to the following for each of the preference variables:
  if (-not $PSBoundParameters.ContainsKey('Verbose')) {
    $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
  }

  This is based on the work of [Dave Wyatt](https://github.com/dlwyatt).
.LINK
  https://devblogs.microsoft.com/scripting/weekend-scripter-access-powershell-preference-variables/
.EXAMPLE
  function Verb-Name {
    [CmdletBinding()] # Required
    param(...)
    Begin
    {
      Get-CommonFlagsCaller $PSCmdlet $ExecutionContext.SessionState
      ...
    }
  }
.LINK
  about_Preference_Variables
#>
function Get-CommonFlagsCaller {
  [CmdletBinding()]
  param(
    [ValidateScript({
      $_.GetType().FullName -eq 'System.Management.Automation.PSScriptCmdlet'
    })]
    $Cmdlet = $(throw('Missing -Cmdlet $PSCmdlet')),
    [Management.Automation.SessionState]
    $State = $(throw('Missing -State $ExecutionContext.SessionState'))
  )

  $Preferences = @{
    # FlagName     VariableName
    'Verbose'   = 'VerbosePreference';
    'WhatIf'    = 'WhatIfPreference';
    'Confirm'   = 'ConfirmPreference'
  }
  foreach ($Flag in $Preferences.Keys) {
    # Check current environment (do not overwrite manual flags)
    if ($Cmdlet.MyInvocation.BoundParameters.ContainsKey($Flag)) { continue }

    # Get variable from caller
    $CallerVar = $Cmdlet.SessionState.PSVariable.Get($Preferences[$Flag])
    if ($null -eq $CallerVar) { continue }
    Write-Debug ($Flag + ': ' + $CallerVar.Value)

    # Set in calling scope
    if ($State -eq $ExecutionContext.SessionState) {
      # Scope level calling function
      Set-Variable -Scope 1 -Name $CallerVar.Name -Value $CallerVar.Value `
        -Force -Confirm:$false -WhatIf:$false
    } else {
      # Modify given State (for different modules)
      $State.PSVariable.Set($CallerVar.Name, $CallerVar.Value)
    }
  }
}
