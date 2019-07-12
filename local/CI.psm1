Set-StrictMode -Version Latest
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Check if executed on the AppVeyor CI platform.
.DESCRIPTION
  Basic check for variables, allows for mocking to disable pushing to the
  AppVeyor Message API.
#>
function Assert-CI {
  return ($env:APPVEYOR -or $env:CI)
}
##====--------------------------------------------------------------------====##

Export-ModuleMember -Function Assert-CI
