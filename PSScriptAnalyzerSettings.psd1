# Configuration for PSScriptAnalyzer
# https://github.com/PowerShell/PSScriptAnalyzer#explicit
#
# Run the tests from the project root:
#  Invoke-ScriptAnalyzer -Path .\ -Recurse -ReportSummary
# List suppressed warnings: -SuppressedOnly
#
# Local rule suppressing:
#  .NET: SuppressMessageAttribute
#  [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
#    'RuleName',
#    '', # CheckId: name of parameter (required)
#    Justification = 'Just an example',
#    Scope = 'Function' # Function|Class
#    Target = '.*' # Regex and glob matching class or function
#  )]
#

@{
  #Severity = @('Error', 'Warning', 'Information')
  #IncludeDefaultRules = $true
  #IncludeRules = @()
  ExcludeRules = @(
    # TODO $Error in Send-Message (major change)
    'PSAvoidAssignmentToAutomaticVariable',
    'PSAvoidGlobalVars',            # TODO local suppression does not work
    'PSAvoidUsingInvokeExpression', # TODO
    'PSAvoidUsingWriteHost',        # TODO
    # '*' is not measurable slower module loading, sensitive to errors.
    # Note: here '*' is only used in module manifest loading other manifests.
    'PSUseToExportFieldsInManifest',
    # No plans to conform to this.
    'PSUseBOMForUnicodeEncodedFile'
  )

}
