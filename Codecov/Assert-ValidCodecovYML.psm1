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
    Write-Verbose 'Validate Yaml file at codecov.io/validate'
    if (-not $Path) {
      $Path = Test-DefaultLocations
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
    if ($content -eq $null ) {
      Send-Message -Error -Message "$($MyInvocation.MyCommand): Empty File"
    }
    $Uri = 'https://codecov.io/validate'
  }
  Process
  {
    if ($PSCmdlet.ShouldProcess($Path[0].Path, "Upload to $Uri")) {
      try {
        $output = Invoke-RestMethod -Uri https://codecov.io/validate `
          -Body (Get-Content -Raw -LiteralPath ($Path[0].Path)) -Method POST
      } catch {
        if ($_.Exception.Response.StatusCode.value__) {
          $details = (
            $_.Exception.Response.StatusCode.value__).ToString().Trim()
        }
        if ($PSVersionTable.PSVersion.Major -lt 6) { # confirmed for v5.1
          if ($_.Exception.Response.StatusDescription) {
            $details += (
              $_.Exception.Response.StatusDescription).ToString().Trim()
          }
        } else { # confirmed for v6.1.2
          if ($_.Exception.Response.ReasonPhrase) {
            $details += ($_.Exception.Response.ReasonPhrase).ToString().Trim()
          }
        }
        Send-Message -Error -Message `
          "Validation of Codecov YAML failed!" `
          -ContinueOnError -Details $details, $_.ErrorDetails
        return $false
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
function Test-DefaultLocations {
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
