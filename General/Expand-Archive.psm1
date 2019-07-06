Set-StrictMode -Version Latest
##====--------------------------------------------------------------------====##

<#
.SYNOPSIS
  Extract archive.
.DESCRIPTION
  Fast and simple extraction of any archive (like) format.
  Wrapper around 7z.
.EXAMPLE
  Expand-Archive archive.zip .\

  Equivalent to: Expand-Archive -Archive archive.zip -TargetDir .\
  Extracts the contents of archive.zip in the current directory.
.EXAMPLE
  Expand-Archive archive.zip

  Extracts archive content to .\archive
.EXAMPLE
  Expand-Archive archive.zip .\ -FlatPath

  Extracts the contents of archive.zip in the current directory.
  Ignoring any internal directory structures.
.EXAMPLE
  Expand-Archive large-archive.zip .\ -ShowProgress
  
  For very large archives, taking a long time to extract, it is useful to
  display the progress indicator to prevent job cancellation due to inactivity.
#>
function Expand-Archive {
  [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Low')]
  param(
    [ValidateScript({ Test-Path -Path "$_" })]
    [ValidateNotNullOrEmpty()]
    [SupportsWildcards()]
    # Archive to be deflated.
    [String]$Archive = $(throw 'Archive is a required parameter'),
    [ValidateScript({ Test-Path -Path "$_" -IsValid })]
    [ValidateNotNullOrEmpty()]
    # Where to extracted the archive contents to.
    [String]$TargetDir,
    # Extract files without directories.
    [Switch]$FlatPath,
    # Report progress. Use for long operations to prevent inactivity time-outs.
    [Switch]$ShowProgress
  )
  Begin
  {
    if ($FlatPath -and -not $TargetDir) {
      throw '-FlatPath requires -TargetDir'
    }
    if (-not $TargetDir) {
      $TargetDir = '.\' +
        [System.IO.Path]::GetFileNameWithoutExtension($Archive)
    }

    $flags = @()
    $flags += '-y' # Yes on all queries
    if ($VerbosePreference -eq 'SilentlyContinue') {
      $flags += '-bso0' # Suppress output
    }
    if ($FlatPath) { $flags += 'e' } else { $flags += 'x' }
    if (-not $ShowProgress) { $flags += '-bd' }
    [String]$command = (
      '7z ' + ($flags -join ' ') + ' ' + "`"$Archive`"" +
      ' -o' + "`"$TargetDir`""
    )
  }
  Process
  {
    if ($TargetDir -and
      $PSCmdlet.ShouldProcess($Archive, ('extract to: ' + $TargetDir))
    ) {
      Invoke-Expression -Command $command
    }
  }
  End
  {
  }
} #/ function Expand-Archive
##====--------------------------------------------------------------------====##

Export-ModuleMember -Function Expand-Archive
