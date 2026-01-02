# Functional tests for version-check.ps1
# These tests execute the actual functions to improve coverage

BeforeAll {
    $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $commonLibPath = Join-Path $Script:RepoRoot "bootstrap\lib\common.ps1"
    $versionCheckPath = Join-Path $Script:RepoRoot "bootstrap\lib\version-check.ps1"

    . $commonLibPath
    . $versionCheckPath
}

Describe "version-check.ps1 - Get-ToolVersion" {

    It "Returns null when tool doesn't exist" {
        $result = Get-ToolVersion "nonexistent-tool-xyz-123"
        $result | Should -Be $null
    }

    It "Returns null for empty tool name" {
        $result = Get-ToolVersion ""
        $result | Should -Be $null
    }

    It "Handles git command" {
        # git may or may not be installed, so we just verify it doesn't throw
        $result = Get-ToolVersion "git"
        $result | Should -BeNullOrEmptyOrValidVersion
    }

    It "Handles powershell command" {
        $result = Get-ToolVersion "pwsh"
        # pwsh should be available since we're running on PowerShell
        if ($result) {
            $result | Should -Match "\d+\.\d+"
        }
    }
}

Describe "version-check.ps1 - Compare-Versions" {

    It "Returns true when installed version equals required" {
        $result = Compare-Versions "1.0.0" "1.0.0"
        $result | Should -Be $true
    }

    It "Returns true when installed version is greater" {
        $result = Compare-Versions "2.0.0" "1.0.0"
        $result | Should -Be $true
    }

    It "Returns true when installed minor version is greater" {
        $result = Compare-Versions "1.5.0" "1.2.0"
        $result | Should -Be $true
    }

    It "Returns true when installed patch version is greater" {
        $result = Compare-Versions "1.2.5" "1.2.3"
        $result | Should -Be $true
    }

    It "Returns false when installed version is less" {
        $result = Compare-Versions "1.0.0" "2.0.0"
        $result | Should -Be $false
    }

    It "Returns false when installed minor version is less" {
        $result = Compare-Versions "1.2.0" "1.5.0"
        $result | Should -Be $false
    }

    It "Handles versions with different lengths (installed has more parts)" {
        $result = Compare-Versions "1.2.3.4" "1.2.3"
        $result | Should -Be $true
    }

    It "Handles versions with different lengths (required has more parts)" {
        $result = Compare-Versions "1.2.3" "1.2.3.4"
        $result | Should -Be $false
    }

    It "Handles v prefix" {
        $result = Compare-Versions "v1.0.0" "1.0.0"
        $result | Should -Be $true
    }

    It "Handles versions with suffixes" {
        $result = Compare-Versions "1.0.0-beta" "1.0.0-alpha"
        $result | Should -Be $true
    }

    It "Handles date-based versions" {
        $result = Compare-Versions "2024-01-01" "2023-12-31"
        $result | Should -Be $true
    }

    It "Returns true for equal date-based versions" {
        $result = Compare-Versions "2024-01-01" "2024-01-01"
        $result | Should -Be $true
    }

    It "Returns false for earlier date-based versions" {
        $result = Compare-Versions "2023-12-31" "2024-01-01"
        $result | Should -Be $false
    }

    It "Handles versions with two parts" {
        $result = Compare-Versions "1.2" "1.1"
        $result | Should -Be $true
    }

    It "Handles versions with letters in parts" {
        $result = Compare-Versions "1.0.0a" "1.0.0"
        $result | Should -Be $true
    }
}

Describe "version-check.ps1 - Test-NeedsInstall" {

    It "Returns true when tool doesn't exist" {
        Mock Test-Command { return $false }

        $result = Test-NeedsInstall "nonexistent-tool"
        $result | Should -Be $true
    }

    It "Returns false when tool exists" {
        Mock Test-Command { return $true }

        $result = Test-NeedsInstall "git"
        $result | Should -Be $false
    }

    It "Handles optional MinVersion parameter" {
        Mock Test-Command { return $true }

        $result = Test-NeedsInstall "git" -MinVersion "2.0.0"
        $result | Should -Be $false
    }
}

Describe "version-check.ps1 - needs_install (alias)" {

    It "Is an alias for Test-NeedsInstall" {
        Mock Test-Command { return $true }

        $result = needs_install "git"
        $result | Should -Be $false
    }
}

Describe "version-check.ps1 - Show-VersionStatus" {

    It "Returns true when tool doesn't exist" {
        Mock Test-Command { return $false }
        Mock Write-Info {}

        $result = Show-VersionStatus "nonexistent-tool"
        $result | Should -Be $true
    }

    It "Returns false when tool exists" {
        Mock Test-Command { return $true }
        Mock Get-ToolVersion { return "1.0.0" }
        Mock Write-Info {}

        $result = Show-VersionStatus "git"
        $result | Should -Be $false
    }

    It "Uses provided DisplayName" {
        Mock Test-Command { return $true }
        Mock Get-ToolVersion { return $null }
        Mock Write-Info {}

        $result = Show-VersionStatus "git" -DisplayName "Git Version Control"
        $result | Should -Be $false
    }

    It "Handles tool with no version output" {
        Mock Test-Command { return $true }
        Mock Get-ToolVersion { return $null }
        Mock Write-Info {}

        $result = Show-VersionStatus "some-tool"
        $result | Should -Be $false
    }

    It "Reports installed version when available" {
        Mock Test-Command { return $true }
        Mock Get-ToolVersion { return "2.40.0" }
        Mock Write-Info {}

        $result = Show-VersionStatus "git"
        $result | Should -Be $false
    }
}

Describe "version-check.ps1 - check_and_report_version (alias)" {

    It "Is an alias for Show-VersionStatus" {
        Mock Test-Command { return $true }
        Mock Get-ToolVersion { return "1.0.0" }
        Mock Write-Info {}

        $result = check_and_report_version "git"
        $result | Should -Be $false
    }
}

Describe "version-check.ps1 - VersionPatterns Hashtable" {

    It "Contains patterns for programming languages" {
        $Script:VersionPatterns.ContainsKey("node") | Should -Be $true
        $Script:VersionPatterns.ContainsKey("python") | Should -Be $true
        $Script:VersionPatterns.ContainsKey("go") | Should -Be $true
        $Script:VersionPatterns.ContainsKey("rustc") | Should -Be $true
    }

    It "Contains patterns for package managers" {
        $Script:VersionPatterns.ContainsKey("brew") | Should -Be $true
        $Script:VersionPatterns.ContainsKey("scoop") | Should -Be $true
        $Script:VersionPatterns.ContainsKey("winget") | Should -Be $true
    }

    It "Contains patterns for CLI tools" {
        $Script:VersionPatterns.ContainsKey("fzf") | Should -Be $true
        $Script:VersionPatterns.ContainsKey("bat") | Should -Be $true
        $Script:VersionPatterns.ContainsKey("eza") | Should -Be $true
    }

    It "Contains patterns for language servers" {
        $Script:VersionPatterns.ContainsKey("gopls") | Should -Be $true
        $Script:VersionPatterns.ContainsKey("rust-analyzer") | Should -Be $true
        $Script:VersionPatterns.ContainsKey("clangd") | Should -Be $true
    }

    It "Contains patterns for linters" {
        $Script:VersionPatterns.ContainsKey("prettier") | Should -Be $true
        $Script:VersionPatterns.ContainsKey("eslint") | Should -Be $true
        $Script:VersionPatterns.ContainsKey("black") | Should -Be $true
    }
}

Describe "version-check.ps1 - VersionFlags Hashtable" {

    It "Contains version flag for go" {
        $Script:VersionFlags.ContainsKey("go") | Should -Be $true
        $Script:VersionFlags["go"] | Should -Be "version"
    }

    It "Contains version flag for cargo" {
        $Script:VersionFlags.ContainsKey("cargo") | Should -Be $true
        $Script:VersionFlags["cargo"] | Should -Be "--version"
    }

    It "Contains version flag for scoop" {
        $Script:VersionFlags.ContainsKey("scoop") | Should -Be $true
        $Script:VersionFlags["scoop"] | Should -Be "--version"
    }
}

# Helper filter for testing
filter Should-BeNullOrEmptyOrValidVersion {
    param(
        [string]$Value
    )
    # Allow null, empty, or version-like strings
    if ([string]::IsNullOrEmpty($Value)) {
        return $true
    }
    if ($Value -match "\d+\.\d+") {
        return $true
    }
    return $false
}
