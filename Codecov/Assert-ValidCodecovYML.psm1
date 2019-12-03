Set-StrictMode -Version Latest
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Upload codecov.yml file for validation.
.DESCRIPTION
  Upload the codecov.yml file to codecov.io to be validated.
  If valid the processed file is returned as an info message to the AppVeyor
  message console.
.EXAMPLE
  Assert-ValidCodecovYML
  INFO: Validated Codecov yml

  Assumes the codecov file is in a default hard-coded location.
.EXAMPLE
  Assert-ValidCodecovYML -Path './.codecov.yml'
  INFO: Validated Codecov yml

  Use a path relative to the current directory.
.OUTPUTS
  $true when validation succeeded
  $false when validation failed
  $null in case of a connection error
#>
function Assert-ValidCodecovYML {
  [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Medium')]
  [OutputType([Bool])]
  param(
    # Path to the yml-file. (codecov.yml or .codecov.yml)
    # Note that when it matches multiple files only the first match is used.
    [SupportsWildcards()]
    [ValidatePattern('(^|[\\\/])\.?codecov\.yml$')]
    [ValidateNotNullOrEmpty()]
    [Alias('File','FileName')]
    [String]$Path
  )
  Begin
  {
    Get-CommonFlagsCaller $PSCmdlet $ExecutionContext.SessionState

    Write-Verbose 'Validate Yaml file at codecov.io/validate'
    if (-not $Path) {
      $Path = Test-DefaultLocation
    }
    [Object[]]$Path = Resolve-Path $Path -ErrorAction SilentlyContinue
    if (-not $Path) {
      Send-Message -Error -Message ( $MyInvocation.MyCommand.ToString() +
        ': no Codecov configuration file detected.' )
    } elseif ($Path.Count -gt 1) {
      $Path | Send-Message -Warning ( $MyInvocation.MyCommand.ToString() +
        'Multiple matches found. Processing first match only.' )
    }
    Write-Verbose ('Resolved path: ' + $Path[0].Path)
    $content = Get-Content -Raw -LiteralPath ($Path[0].Path)
    if ($null -eq $content) {
      Send-Message -Error -Message "$($MyInvocation.MyCommand): Empty File"
    }
    $Uri = 'https://codecov.io/validate'
  }
  Process
  {
    if ($PSCmdlet.ShouldProcess($Path[0].Path, "Upload to $Uri")) {
      if ($PSVersionTable.PSVersion.Major -lt 6) {
        try {
          $output = Invoke-RestMethod -Uri $Uri `
            -Body (Get-Content -Raw -LiteralPath ($Path[0].Path)) -Method POST
        } catch [System.Net.WebException] {
          if ($null -eq $_.Exception.Response) {
            Send-Message -Warning ('Failed to connect to "' + $Uri + '"!') `
              -Details ($_).ToString().Trim()
            return $null
          } else {
            if ($_.Exception.Response.StatusCode.value__) {
              $details = (
              $_.Exception.Response.StatusCode.value__).ToString().Trim()
            }
            if ($_.Exception.Response.StatusDescription) {
              $details += (' ' + (
                $_.Exception.Response.StatusDescription).ToString().Trim() )
            }
          }
          Send-Message -Error -Message `
            "Validation of Codecov YAML failed!" `
            -Details $details, ($_).ToString().Trim() -ContinueOnError
          return $false
        }
      } else { # PS v6+
        try {
          try {
            $output = Invoke-RestMethod -Uri $Uri `
              -Body (Get-Content -Raw -LiteralPath ($Path[0].Path)) -Method POST
          } catch [System.Net.Sockets.SocketException] { # PS v6+
            Send-Message -Warning ('Socket: Failed to connect to "' + $Uri +
              '"!') -Details ($_).ToString().Trim()
            return $null
          }
        } catch [System.Net.Http.HttpRequestException] {
          if ($_.Exception.Response.StatusCode.value__) {
            $details = (
            $_.Exception.Response.StatusCode.value__).ToString().Trim()
          } else { $details = '' }
          if ($_.Exception.Response.ReasonPhrase) {
            $details += (' ' + (
              $_.Exception.Response.ReasonPhrase).ToString().Trim() + "`n")
          }
          Send-Message -Error -Message `
            "Validation of Codecov YAML failed!" `
            -Details ($details + ($_).ToString().Trim()) -ContinueOnError
          return $false
        }
      }
      Send-Message -Info -Message `
        "Validated Codecov yml" `
        -Details $output.ToString() -HideDetails
      return $true
    } else { return $false }
  }
} #/ function Assert-ValidCodecovYML
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Try a few locations for the existence of a (.)codecov.yml file.
#>
function Test-DefaultLocation {
  if ($env:APPVEYOR_BUILD_FOLDER) {
    $Path = ($env:APPVEYOR_BUILD_FOLDER + '/.codecov.yml')
    if (Test-Path $Path) { return $Path }
    $Path = ($env:APPVEYOR_BUILD_FOLDER + '/codecov.yml')
    if (Test-Path $Path) { return $Path }
  }
  $Path = './.codecov.yml'
  if (Test-Path $Path) { return $Path }
  return './codecov.yml'
}
##====--------------------------------------------------------------------====##

Export-ModuleMember -Function Assert-ValidCodecovYML
