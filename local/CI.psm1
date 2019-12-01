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
  [OutputType([Bool])]
  param()
  return ($env:APPVEYOR -or $env:CI)
}
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Checks if executed on the Microsoft Windows Platform.
#>
function Assert-Windows {
  [OutputType([Bool])]
  param()
  if ($env:CI_WINDOWS -ne $null) {
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

<#
.SYNOPSIS
  Checks if executed with administrative privileges.
#>
function Assert-Admin {
  [OutputType([Bool])]
  param()
  if (Assert-Windows) {
    return (
      [Security.Principal.WindowsPrincipal] `
      [Security.Principal.WindowsIdentity]::GetCurrent() `
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  } else { throw 'Assert-Admin is only implemented for Windows' }
}
##====--------------------------------------------------------------------====##

Export-ModuleMember -Function Assert-CI, Assert-Windows, Assert-Admin
