<#
    .SYNOPSIS
        Test Microsoft Edge
#>
[CmdletBinding()]
param()

Describe "Microsoft Edge configuration" {
    Context "Application preferences" {
        It "Should have written the correct content to master_preferences" {
            (Get-Content -Path "${Env:ProgramFiles(x86)}\Microsoft\Edge\Application\master_preferences" | ConvertFrom-Json).homepage | Should -BeExactly "https://www.microsoft365.com"
        }
    }
}
