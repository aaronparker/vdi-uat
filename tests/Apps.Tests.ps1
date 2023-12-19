<#
    .SYNOPSIS
        Use Pester and Evergreen to validate installed apps.
#>
[CmdletBinding()]
param()

BeforeDiscovery {
    # Get the list of software to test
    $Path = $PWD.Path
    $Applications = Get-Content -Path $([System.IO.Path]::Combine($Path, "tests", "Apps.json")) | ConvertFrom-Json
}

BeforeAll {
    # Import module
    Import-Module "Evergreen" -Force
}

# Per script tests
Describe "Validate <_.Name>" -ForEach $Applications {
    BeforeDiscovery {
        $FilesExist = $_.FilesExist
        $ShortcutsNotExist = $_.ShortcutsNotExist
        $ServicesDisabled = $_.ServicesDisabled
    }

    BeforeAll {
        #region Functions
        function Get-InstalledSoftware {
            [OutputType([System.Object[]])]
            [CmdletBinding()]
            param ()

            $UninstallKeys = @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
            )
            $Apps = @()
            foreach ($Key in $UninstallKeys) {
                try {
                    $propertyNames = "DisplayName", "DisplayVersion", "Publisher", "UninstallString", "PSPath", "WindowsInstaller", "InstallDate", "InstallSource", "HelpLink", "Language", "EstimatedSize", "SystemComponent"
                    $Apps += Get-ItemProperty -Path $Key -Name $propertyNames -ErrorAction "SilentlyContinue" | `
                        . { process { if ($null -ne $_.DisplayName) { $_ } } } | `
                        Where-Object { $_.SystemComponent -ne 1 } | `
                        Select-Object -Property @{n = "Name"; e = { $_.DisplayName } }, @{n = "Version"; e = { $_.DisplayVersion } }, "Publisher", "UninstallString", @{n = "RegistryPath"; e = { $_.PSPath -replace "Microsoft.PowerShell.Core\\Registry::", "" } }, "PSChildName", "WindowsInstaller", "InstallDate", "InstallSource", "HelpLink", "Language", "EstimatedSize" | `
                        Sort-Object -Property "DisplayName", "Publisher"
                }
                catch {
                    throw $_.Exception.Message
                }
            }
            return $Apps
        }
        #endregion

        # Get the Software list; Output the installed software to the pipeline for Packer output
        $InstalledSoftware = Get-InstalledSoftware | Sort-Object -Property "Publisher", "Version"

        # Get details for the current application
        $App = $_

        # Construct a static object, if the app is not supported by Evergreen
        if ([SYstem.String]::IsNullOrEmpty($App.Filter)) {
            $Latest = [PSCustomObject]@{
                Version = "1.1.0"
            }
        }
        else {
            $Latest = Invoke-Expression -Command $App.Filter
        }

        # Match the app from the list of installed apps
        if ($null -ne $App.Installed) {
            $Installed = $InstalledSoftware | `
                Where-Object { $_.Name -match $App.Installed } | `
                Sort-Object -Property @{ Expression = { [System.Version]$_.Version }; Descending = $true } | `
                Select-Object -First 1
        }
        else {
            $Installed = "App does not have Installed property"
        }
    }

    Context "Validate installed application" {
        It "Should be installed" {
            $Installed | Should -Not -BeNullOrEmpty
        }
    }

    Context "Application configuration tests" {
        It "Should be the current version or better" {
            [System.Version]$Installed.Version | Should -BeGreaterOrEqual ([System.Version]$Latest.Version)
        }

        It "Should have application file installed: <_>" -ForEach $FilesExist {
            $_ | Should -Exist
        }

        It "Should have shortcut deleted or removed: <_>" -ForEach $ShortcutsNotExist {
            $_ | Should -Not -Exist
        }

        It "Should have the service disabled: <_>" -ForEach $ServicesDisabled {
            (Get-Service -Name $_).StartType | Should -Be "Disabled"
        }
    }
}

AfterAll {
    #region Functions
    function Get-InstalledSoftware {
        [OutputType([System.Object[]])]
        [CmdletBinding()]
        param ()

        $UninstallKeys = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )
        $Apps = @()
        foreach ($Key in $UninstallKeys) {
            try {
                $propertyNames = "DisplayName", "DisplayVersion", "Publisher", "UninstallString", "PSPath", "WindowsInstaller", "InstallDate", "InstallSource", "HelpLink", "Language", "EstimatedSize", "SystemComponent"
                $Apps += Get-ItemProperty -Path $Key -Name $propertyNames -ErrorAction "SilentlyContinue" | `
                    . { process { if ($null -ne $_.DisplayName) { $_ } } } | `
                    Where-Object { $_.SystemComponent -ne 1 } | `
                    Select-Object -Property @{n = "Name"; e = { $_.DisplayName } }, @{n = "Version"; e = { $_.DisplayVersion } }, "Publisher", "UninstallString", @{n = "RegistryPath"; e = { $_.PSPath -replace "Microsoft.PowerShell.Core\\Registry::", "" } }, "PSChildName", "WindowsInstaller", "InstallDate", "InstallSource", "HelpLink", "Language", "EstimatedSize" | `
                    Sort-Object -Property "DisplayName", "Publisher"
            }
            catch {
                throw $_.Exception.Message
            }
        }
        return $Apps
    }
    #endregion

    $Path = $PWD.Path
    $params = @{
        Path              = "$Path\InstalledApplications.csv"
        Encoding          = "Utf8"
        NoTypeInformation = $true
        Verbose           = $true
    }
    Get-InstalledSoftware | Export-Csv @params
}
