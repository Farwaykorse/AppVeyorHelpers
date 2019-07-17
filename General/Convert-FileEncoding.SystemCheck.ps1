# Warn when PowerShell v6 or newer is not available on the system.
# Convert-FileEncoding default encoding UTF8noBom and UTF8BOM require this.
#
# This warning is relevant for AppVeyor image: Visual Studio 2013

if ( $PSVersionTable.PSVersion.Major -lt 6 ) {
  if ( -not (Test-Command 'pwsh { exit 0 }') ) {
    Import-Module -Name "${PSScriptRoot}\..\AppVeyor\Send-Message.psd1"
    Send-Message -Warning `
      -Message 'Convert-FileEncoding default encoding not supported.' `
      -Details ('The default encoding setting UTF8noBOM requires PowerShell ' +
        'Core to be available.'), 'Install PowerShell Core.'
  }
}
