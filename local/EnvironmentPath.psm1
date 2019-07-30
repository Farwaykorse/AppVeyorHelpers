Set-StrictMode -Version Latest
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Add to the front of the current environment PATH.
#>
function Add-EnvironmentPath {
  [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Medium')]
  param(
    [ValidateScript({ Test-Path -LiteralPath "$_" -PathType 'Container' })]
    [ValidateNotNullOrEmpty()]
    [String]$Path = $(throw 'Path is a required parameter'),
    [Switch]$Front
  )
  Begin
  {
    Get-CommonFlagsCaller $PSCmdlet $ExecutionContext.SessionState
  }
  Process
  {
  }
  End
  {
    if ($PSCmdlet.ShouldProcess('$env:PATH', ('add ' + $Path) )) {
      $env:PATH = "${Path};$env:PATH"
    }
  }
}
##====--------------------------------------------------------------------====##

Export-ModuleMember -Function Add-EnvironmentPath
