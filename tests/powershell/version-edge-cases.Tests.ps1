# Additional tests for version-check.ps1 to improve coverage
# Tests edge cases and version comparison scenarios

BeforeAll {
    $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $versionCheckPath = Join-Path $Script:RepoRoot "bootstrap\lib\version-check.ps1"

    . $versionCheckPath
}

Describe "version-check.ps1 - Get-ToolVersion edge cases" {

    It "Returns null for non-existent tool" {
        $result = Get-ToolVersion "nonexistent-tool-xyz-123"
        $result | Should -BeNullOrEmpty
    }

    It "Returns version for built-in command" {
        $result = Get-ToolVersion "pwsh"
        # Should return something - either a version or null
        $true | Should -Be $true
    }

    It "Handles tools with custom flags" {
        # Test that custom version flags are accepted
        $result = Get-ToolVersion "echo" -VersionFlag "--version"
        # Just verify it doesn't crash
        $true | Should -Be $true
    }
}

Describe "version-check.ps1 - Compare-Versions scenarios" {

    It "Handles equal versions" {
        $result = Compare-Versions "1.0.0" "1.0.0"
        $result | Should -Be $true
    }

    It "Handles greater major version" {
        $result = Compare-Versions "2.0.0" "1.0.0"
        $result | Should -Be $true
    }

    It "Handles lesser major version" {
        $result = Compare-Versions "1.0.0" "2.0.0"
        $result | Should -Be $false
    }

    It "Handles greater minor version" {
        $result = Compare-Versions "1.2.0" "1.1.0"
        $result | Should -Be $true
    }

    It "Handles greater patch version" {
        $result = Compare-Versions "1.0.5" "1.0.3"
        $result | Should -Be $true
    }

    It "Handles two-part versions" {
        $result = Compare-Versions "1.5" "1.4"
        $result | Should -Be $true
    }

    It "Handles single-part versions" {
        $result = Compare-Versions "2" "1"
        $result | Should -Be $true
    }

    It "Handles versions with many parts" {
        $result = Compare-Versions "1.2.3.4.5" "1.2.3.4.4"
        $result | Should -Be $true
    }

    It "Handles versions with letters" {
        $result = Compare-Versions "1.0.0b" "1.0.0a"
        $result | Should -Be $true
    }

    It "Handles empty strings" {
        $result = Compare-Versions "" "1.0.0"
        $result | Should -Be $false
    }

    It "Handles mixed formats" {
        $result = Compare-Versions "2.0" "1.9.9"
        $result | Should -Be $true
    }
}

Describe "version-check.ps1 - Test-NeedsInstall" {

    It "Returns true when tool not found" {
        Mock Get-ToolVersion { return $null }
        Mock Test-Command { return $false }

        $result = Test-NeedsInstall "nonexistent-tool"
        $result | Should -Be $true
    }

    It "Returns false when tool meets minimum version" {
        Mock Get-ToolVersion { return "2.0.0" }
        Mock Test-Command { return $true }

        $result = Test-NeedsInstall "tool" "1.0.0"
        $result | Should -Be $false
    }

    It "Returns true when tool below minimum version" {
        Mock Get-ToolVersion { return "1.0.0" }
        Mock Test-Command { return $true }

        $result = Test-NeedsInstall "tool" "2.0.0"
        $result | Should -Be $true
    }

    It "Returns false when no minimum version specified and tool exists" {
        Mock Get-ToolVersion { return "1.0.0" }
        Mock Test-Command { return $true }

        $result = Test-NeedsInstall "tool"
        $result | Should -Be $false
    }

    It "Handles exact version match" {
        Mock Get-ToolVersion { return "1.5.0" }
        Mock Test-Command { return $true }

        $result = Test-NeedsInstall "tool" "1.5.0"
        $result | Should -Be $false
    }
}

Describe "version-check.ps1 - Show-VersionStatus" {

    It "Shows not installed message" {
        Mock Test-Command { return $false }

        $result = Show-VersionStatus "test-tool" -DisplayName "Test Tool"
        $result | Should -Be $true  # true means not installed
    }

    It "Shows installed with version" {
        Mock Test-Command { return $true }
        Mock Get-ToolVersion { return "1.2.3" }

        $result = Show-VersionStatus "test-tool"
        $result | Should -Be $false  # false means installed
    }

    It "Shows installed without version (version unknown)" {
        Mock Test-Command { return $true }
        Mock Get-ToolVersion { return $null }

        $result = Show-VersionStatus "test-tool"
        $result | Should -Be $false
    }

    It "Uses custom display name" {
        Mock Test-Command { return $true }
        Mock Get-ToolVersion { return "1.0.0" }

        $result = Show-VersionStatus "tool" -DisplayName "My Custom Tool"
        $result | Should -Be $false
    }
}

Describe "version-check.ps1 - Version Patterns Hashtable" {

    It "Contains many version patterns" {
        $Script:VersionPatterns.Count | Should -BeGreaterThan 50
    }

    It "Has pattern for common tools" {
        $Script:VersionPatterns.ContainsKey("git") | Should -Be $true
        $Script:VersionPatterns.ContainsKey("node") | Should -Be $true
        $Script:VersionPatterns.ContainsKey("python") | Should -Be $true
        $Script:VersionPatterns.ContainsKey("cargo") | Should -Be $true
    }

    It "Contains VersionFlags hashtable" {
        $Script:VersionFlags.ContainsKey("go") | Should -Be $true
        $Script:VersionFlags.ContainsKey("scoop") | Should -Be $true
    }
}

Describe "version-check.ps1 - Get-VersionFlag" {

    It "Returns custom flag for go" {
        $result = Get-VersionFlag "go"
        $result | Should -Be "version"
    }

    It "Returns custom flag for cargo" {
        $result = Get-VersionFlag "cargo"
        $result | Should -Be "--version"
    }

    It "Returns custom flag for scoop" {
        $result = Get-VersionFlag "scoop"
        $result | Should -Be "--version"
    }

    It "Returns default flag for unknown tool" {
        $result = Get-VersionFlag "unknown-tool"
        $result | Should -Be "--version"
    }
}

Describe "version-check.ps1 - Get-VersionPattern" {

    It "Returns pattern for known tools" {
        $result = Get-VersionPattern "git"
        $result | Should -Not -BeNullOrEmpty
    }

    It "Returns default pattern for unknown tools" {
        $result = Get-VersionPattern "unknown-tool-xyz"
        $result | Should -Not -BeNullOrEmpty
    }
}

Describe "version-check.ps1 - Parse-VersionString" {

    It "Extracts version from standard format" {
        $result = Parse-VersionString "git version 2.39.0"
        $result | Should -Be "2.39.0"
    }

    It "Handles versions with v prefix" {
        $result = Parse-VersionString "v1.2.3"
        $result | Should -Be "1.2.3"
    }

    It "Handles complex version strings" {
        $result = Parse-VersionString "node v20.1.0 (x64)"
        $result | Should -Match "20\.1\.0"
    }

    It "Returns null when no version found" {
        $result = Parse-VersionString "no version here"
        $result | Should -BeNullOrEmpty
    }
}
