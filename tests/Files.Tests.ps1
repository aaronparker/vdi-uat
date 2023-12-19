<#
    .SYNOPSIS
        Use Pester to check on files on disk.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "", Justification = "This OK for the tests files.")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "", Justification = "Outputs to log host.")]
[CmdletBinding()]
param()

BeforeDiscovery {

    # Get the list of software to test
    $Path = $PWD.Path
    $Files = Get-Content -Path $([System.IO.Path]::Combine($Path, "tests", "Files.json")) | ConvertFrom-Json
}

BeforeAll {
}

# Per script tests
Describe "Validate <App.Name>" -ForEach $Files {
    BeforeDiscovery {
        $FilesExist = $_.FilesExist
        $FilesNotExist = $_.FilesNotExist
    }

    BeforeAll {
    }

    Context "Application configuration tests" {
        It "Should exist in the path: <_>" -ForEach $FilesExist {
            $_ | Should -Exist
        }

        It "Should not exist in the path: <_>" -ForEach $FilesNotExist {
            $_ | Should -Not -Exist
        }
    }
}

AfterAll {
}
