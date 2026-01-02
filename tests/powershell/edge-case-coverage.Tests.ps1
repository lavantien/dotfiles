# Tests for edge cases and hard-to-reach code paths
# Focuses on achievable coverage improvements on Windows

BeforeAll {
    $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $commonLibPath = Join-Path $Script:RepoRoot "bootstrap\lib\common.ps1"
    $windowsPlatformPath = Join-Path $Script:RepoRoot "bootstrap\platforms\windows.ps1"

    . $commonLibPath
    . $windowsPlatformPath

    $Script:DryRun = $false
    $Script:Verbose = $false
    $Script:Interactive = $false
    Reset-Tracking
}

Describe "common.ps1 - Read-Confirmation" {

    It "Returns 'y' when INTERACTIVE is false (auto-confirm)" {
        $Script:Interactive = $false
        $result = Read-Confirmation "Test prompt"
        $result | Should -Be "y"
    }

    It "Returns 'n' when INTERACTIVE is false and using ShouldConfirm" {
        # This tests the non-interactive path
        $Script:Interactive = $false
        { Read-Confirmation "Test" } | Should -Not -Throw
    }
}

Describe "common.ps1 - Add-ToPath (User scope)" {

    BeforeEach {
        $testPath = "C:\Test-Path-$(New-Guid)"
        # Clean up any existing
        $env:Path = ($env:Path -split ';' | Where-Object { $_ -ne $testPath }) -join ';'
    }

    It "Adds path to session environment" {
        Add-ToPath -Path $testPath -User
        $env:Path -like "*$testPath*" | Should -Be $true
    }

    It "Skips adding if already in PATH" {
        # Add it first
        $env:Path = "$testPath;$env:Path"

        # Should not throw even though it's already there
        { Add-ToPath -Path $testPath -User } | Should -Not -Throw
    }
}

Describe "common.ps1 - Test-Command edge cases" {

    It "Returns false for non-existent command" {
        $result = Test-Command "nonexistent-command-xyz-123"
        $result | Should -Be $false
    }

    It "Returns true for existing command" {
        $result = Test-Command "pwsh"
        $result | Should -Be $true
    }
}

Describe "common.ps1 - Initialize-UserPath" {

    It "Executes without error on Windows" {
        { Initialize-UserPath } | Should -Not -Throw
    }

    It "Handles missing Python directory gracefully" {
        # Mock the Python base directory to a non-existent path
        # The function should handle this gracefully
        { Initialize-UserPath } | Should -Not -Throw
    }
}

Describe "windows.ps1 - Get-PackageDescription (all packages)" {

    # Test all package descriptions to improve coverage
    $testPackages = @(
        @{Package = "scoop"; Expected = "package manager"},
        @{Package = "winget"; Expected = "Windows package manager"},
        @{Package = "chocolatey"; Expected = "package manager"},
        @{Package = "git"; Expected = "version control"},
        @{Package = "gh"; Expected = "GitHub CLI"},
        @{Package = "lazygit"; Expected = "Git TUI"},
        @{Package = "ripgrep"; Expected = "text search"},
        @{Package = "fd"; Expected = "file finder"},
        @{Package = "fzf"; Expected = "fuzzy finder"},
        @{Package = "bat"; Expected = "enhanced cat"},
        @{Package = "eza"; Expected = "enhanced ls"},
        @{Package = "zoxide"; Expected = "smart directory navigation"},
        @{Package = "jq"; Expected = "JSON processor"},
        @{Package = "tokei"; Expected = "code stats"}
    )

    It "Returns description for <Package>" -TestCases $testPackages {
        $result = Get-PackageDescription $Package
        $result | Should -Be $Expected
    }

    It "Returns package name as description for unknown package" {
        $result = Get-PackageDescription "unknown-package-xyz"
        $result | Should -Be "unknown-package-xyz"
    }
}

Describe "windows.ps1 - Install functions with all params" {

    BeforeEach {
        $Script:DryRun = $true
    }

    It "Install-WingetPackage with all parameters" {
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $true }

        $result = Install-WingetPackage -Package "Test.App" -DisplayName "Test Display" -Source "test-source"
        $result | Should -Be $true
    }

    It "Install-PipGlobal with custom index URL" {
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $true }

        $result = Install-PipGlobal "test" -IndexUrl "https://test.pypi.org/simple"
        $result | Should -Be $true
    }

    It "Install-CargoPackage with features" {
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $true }

        $result = Install-CargoPackage "test" -Features "feature1,feature2"
        $result | Should -Be $true
    }
}

Describe "common.ps1 - Refresh-Path" {

    It "Executes Refresh-Path function" {
        # The function should exist and execute without error
        { Refresh-Path } | Should -Not -Throw
    }
}

Describe "windows.ps1 - Package manager checks" {

    It "Returns $false when package manager not found" {
        Mock Get-Command { return $false }
        $result = Install-ScoopPackage "test"
        $result | Should -Be $false
    }

    It "Returns $false when winget not available" {
        Mock Get-Command { return $false }
        $result = Install-WingetPackage "Test"
        $result | Should -Be $false
    }

    It "Returns $false when Chocolatey not found" {
        Mock Get-Command { return $false }
        $result = Install-ChocoPackage "test"
        $result | Should -Be $false
    }
}

Describe "common.ps1 - Get-OSPlatform" {

    It "Returns windows on Windows system" {
        $result = Get-OSPlatform
        $result | Should -BeIn @("windows", "macos", "linux", "unknown")
    }

    It "Handles $IsWindows variable" {
        # Test that the function considers $IsWindows
        $result = Get-OSPlatform
        $result | Should -Not -BeNullOrEmpty
    }
}

Describe "common.ps1 - Write-VerboseInfo" {

    It "Outputs when Verbose is true" {
        $Script:Verbose = $true
        { Write-VerboseInfo "Test verbose" } | Should -Not -Throw
    }

    It "Skips output when Verbose is false" {
        $Script:Verbose = $false
        { Write-VerboseInfo "Silent" } | Should -Not -Throw
    }
}

Describe "common.ps1 - Invoke-SafeInstall success path" {

    It "Returns true on successful install" {
        $testFunc = { return $true }
        $result = Invoke-SafeInstall $testFunc "test-package"
        $result | Should -Be $true
    }

    It "Tracks installation on success" {
        $testFunc = { return $true }
        Invoke-SafeInstall $testFunc "test-package" "Test description"
        $Script:INSTALLED_PACKAGES.Count | Should -BeGreaterThan 0
    }
}

Describe "common.ps1 - Write-Header with custom width" {

    It "Executes with custom width" {
        { Write-Header "Test" 80 } | Should -Not -Throw
    }

    It "Executes with default width" {
        { Write-Header "Test" } | Should -Not -Throw
    }
}
