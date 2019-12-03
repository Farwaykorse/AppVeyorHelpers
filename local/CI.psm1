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

<#
.SYNOPSIS
  Checks if executed on the Microsoft Windows Platform.
#>
function Assert-Windows {
  if ($null -ne $env:CI_WINDOWS) {
    ### Temporary - old build agent. ###########################################
    return ($env:CI_WINDOWS -eq 'true')
    <### new build agent.
    return ($env:CI_WINDOWS -ceq 'true')
    #>
  }
  return (
    ($PSVersionTable.PSVersion.Major -lt 6) -or
    ((Get-CimInstance CIM_OperatingSystem).Caption -match 'Windows')
  )
}
##====--------------------------------------------------------------------====##

Export-ModuleMember -Function Assert-CI, Assert-Windows
