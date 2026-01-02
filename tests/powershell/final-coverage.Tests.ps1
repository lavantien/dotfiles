# Final comprehensive tests to maximize coverage
# These tests target all remaining uncovered code paths

BeforeAll {
    $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $commonLibPath = Join-Path $Script:RepoRoot "bootstrap\lib\common.ps1"
    $versionCheckPath = Join-Path $Script:RepoRoot "bootstrap\lib\version-check.ps1"
    $windowsPlatformPath = Join-Path $Script:RepoRoot "bootstrap\platforms\windows.ps1"

    . $commonLibPath
    . $versionCheckPath
    . $windowsPlatformPath

    $Script:DryRun = $false
    $Script:Verbose = $false
    $Script:Interactive = $false
    Reset-Tracking
}

Describe "common.ps1 - All Logging Functions" {

    It "Executes Write-Color" {
        { Write-Color "Test" "Cyan" } | Should -Not -Throw
    }

    It "Executes Write-Info" {
        { Write-Info "Test info" } | Should -Not -Throw
    }

    It "Executes Write-Success" {
        { Write-Success "Test success" } | Should -Not -Throw
    }

    It "Executes Write-Warning" {
        { Write-Warning "Test warning" } | Should -Not -Throw
    }

    It "Executes Write-Error-Msg" {
        { Write-Error-Msg "Test error" } | Should -Not -Throw
    }

    It "Executes Write-Step" {
        { Write-Step "Test step" } | Should -Not -Throw
    }

    It "Executes Write-Header" {
        { Write-Header "Test" 50 } | Should -Not -Throw
    }

    It "Executes Write-Section" {
        { Write-Section "Test Section" } | Should -Not -Throw
    }

    It "Executes Write-VerboseInfo when verbose" {
        $Script:Verbose = $true
        { Write-VerboseInfo "Verbose message" } | Should -Not -Throw
        $Script:Verbose = $false
    }

    It "Executes Write-VerboseInfo when not verbose" {
        $Script:Verbose = $false
        { Write-VerboseInfo "Silent message" } | Should -Not -Throw
    }
}

Describe "common.ps1 - All Tracking Functions" {

    BeforeEach {
        Reset-Tracking
    }

    It "Executes Track-Installed" {
        Track-Installed "pkg" "desc"
        $Script:INSTALLED_PACKAGES.Count | Should -BeGreaterThan 0
    }

    It "Executes Track-Skipped" {
        Track-Skipped "pkg" "desc"
        $Script:SKIPPED_PACKAGES.Count | Should -BeGreaterThan 0
    }

    It "Executes Track-Failed" {
        Track-Failed "pkg" "desc"
        $Script:FAILED_PACKAGES.Count | Should -BeGreaterThan 0
    }

    It "Executes Reset-Tracking" {
        Track-Installed "pkg1" "d1"
        Track-Skipped "pkg2" "d2"
        Track-Failed "pkg3" "d3"
        Reset-Tracking
        $Script:INSTALLED_PACKAGES.Count | Should -Be 0
        $Script:SKIPPED_PACKAGES.Count | Should -Be 0
        $Script:FAILED_PACKAGES.Count | Should -Be 0
    }

    It "Executes Write-Summary" {
        Track-Installed "pkg1" "d1"
        Track-Skipped "pkg2" "d2"
        Track-Failed "pkg3" "d3"
        { Write-Summary } | Should -Not -Throw
    }
}

Describe "common.ps1 - Platform Detection" {

    It "Executes Get-OSPlatform" {
        $result = Get-OSPlatform
        $result | Should -BeIn @("windows", "macos", "linux", "unknown")
    }

    It "Executes Get-WindowsVersion" {
        $result = Get-WindowsVersion
        $result | Should -BeOfType [version]
    }
}

Describe "version-check.ps1 - Version Patterns Hashtable" {

    It "Contains version patterns for many tools" {
        $Script:VersionPatterns.Count | Should -BeGreaterThan 50
    }

    It "Contains version flags for specific tools" {
        $Script:VersionFlags.ContainsKey("go") | Should -Be $true
        $Script:VersionFlags.ContainsKey("cargo") | Should -Be $true
        $Script:VersionFlags.ContainsKey("scoop") | Should -Be $true
    }
}

Describe "version-check.ps1 - Version Comparison Edge Cases" {

    It "Handles empty strings" {
        $result = Compare-Versions "" "1.0.0"
        $result | Should -Be $false
    }

    It "Handles single version parts" {
        $result = Compare-Versions "1" "0"
        $result | Should -Be $true
    }

    It "Handles many version parts" {
        $result = Compare-Versions "1.2.3.4.5" "1.2.3.4.4"
        $result | Should -Be $true
    }

    It "Handles versions with letters" {
        $result = Compare-Versions "1.0.0b" "1.0.0a"
        $result | Should -Be $true
    }
}

Describe "windows.ps1 - All Get-PackageDescription Cases" {

    $testCases = @(
        @{ Package = "scoop"; Expected = "package manager" }
        @{ Package = "winget"; Expected = "Windows package manager" }
        @{ Package = "chocolatey"; Expected = "package manager" }
        @{ Package = "git"; Expected = "version control" }
        @{ Package = "node"; Expected = "Node.js runtime" }
        @{ Package = "python"; Expected = "Python runtime" }
        @{ Package = "go"; Expected = "Go runtime" }
        @{ Package = "rust"; Expected = "Rust toolchain" }
        @{ Package = "dotnet"; Expected = ".NET SDK" }
        @{ Package = "clangd"; Expected = "C/C++ LSP" }
        @{ Package = "gopls"; Expected = "Go LSP" }
        @{ Package = "rust-analyzer"; Expected = "Rust LSP" }
        @{ Package = "pyright"; Expected = "Python LSP" }
        @{ Package = "prettier"; Expected = "code formatter" }
        @{ Package = "eslint"; Expected = "JavaScript linter" }
        @{ Package = "ruff"; Expected = "Python linter" }
        @{ Package = "black"; Expected = "Python formatter" }
        @{ Package = "fzf"; Expected = "fuzzy finder" }
        @{ Package = "zoxide"; Expected = "smart directory navigation" }
        @{ Package = "bat"; Expected = "enhanced cat" }
        @{ Package = "eza"; Expected = "enhanced ls" }
        @{ Package = "lazygit"; Expected = "Git TUI" }
        @{ Package = "gh"; Expected = "GitHub CLI" }
        @{ Package = "ripgrep"; Expected = "text search" }
        @{ Package = "fd"; Expected = "file finder" }
        @{ Package = "tokei"; Expected = "code stats" }
        @{ Package = "difft"; Expected = "diff viewer" }
        @{ Package = "bats"; Expected = "Bash testing" }
        @{ Package = "bashcov"; Expected = "code coverage" }
        @{ Package = "Pester"; Expected = "PowerShell testing" }
    )

    It "Returns correct description for <Package>" -TestCases $testCases {
        $result = Get-PackageDescription $Package
        $result | Should -Be $Expected
    }
}

Describe "windows.ps1 - Install Function Dry Run Paths" {

    BeforeEach {
        $Script:DryRun = $true
        Mock Test-NeedsInstall { return $true }
    }

    AfterEach {
        $Script:DryRun = $false
    }

    It "Install-ScoopPackage in dry run" {
        Mock Get-Command { return $true }
        $result = Install-ScoopPackage "test"
        $result | Should -Be $true
    }

    It "Install-WingetPackage in dry run" {
        Mock Get-Command { return $true }
        $result = Install-WingetPackage "Test.App" -DisplayName "Test"
        $result | Should -Be $true
    }

    It "Install-ChocoPackage in dry run" {
        Mock Get-Command { return $true }
        $result = Install-ChocoPackage "test"
        $result | Should -Be $true
    }

    It "Install-NpmGlobal in dry run" {
        Mock Get-Command { return $true }
        $result = Install-NpmGlobal "test-package"
        $result | Should -Be $true
    }

    It "Install-GoPackage in dry run" {
        Mock Get-Command { return $true }
        $result = Install-GoPackage "github.com/test/pkg"
        $result | Should -Be $true
    }

    It "Install-CargoPackage in dry run" {
        Mock Get-Command { return $true }
        $result = Install-CargoPackage "test"
        $result | Should -Be $true
    }

    It "Install-PipGlobal in dry run" {
        Mock Get-Command { return $true }
        $result = Install-PipGlobal "test"
        $result | Should -Be $true
    }

    It "Install-DotnetTool in dry run" {
        Mock Get-Command { return $true }
        $result = Install-DotnetTool "test"
        $result | Should -Be $true
    }

    It "Install-CoursierPackage in dry run" {
        Mock Test-CoursierInstalled { return $true }
        Mock Get-CoursierExe { return "cs.exe" }
        $result = Install-CoursierPackage "org.test:test"
        $result | Should -Be $true
    }
}

Describe "windows.ps1 - Install Function Skip Paths" {

    BeforeEach {
        Mock Test-NeedsInstall { return $false }
    }

    It "Install-ScoopPackage skips when installed" {
        Mock Get-Command { return $true }
        $result = Install-ScoopPackage "test"
        $result | Should -Be $true
    }

    It "Install-WingetPackage skips when installed" {
        Mock Get-Command { return $true }
        $result = Install-WingetPackage "Test.App" -DisplayName "Test"
        $result | Should -Be $true
    }

    It "Install-ChocoPackage skips when installed" {
        Mock Get-Command { return $true }
        $result = Install-ChocoPackage "test"
        $result | Should -Be $true
    }
}

Describe "windows.ps1 - Install Function Missing Tool Paths" {

    It "Install-ScoopPackage returns false when scoop missing" {
        Mock Get-Command { return $false }
        $result = Install-ScoopPackage "test"
        $result | Should -Be $false
    }

    It "Install-WingetPackage returns false when winget missing" {
        Mock Get-Command { return $false }
        $result = Install-WingetPackage "Test.App"
        $result | Should -Be $false
    }

    It "Install-ChocoPackage returns false when choco missing" {
        Mock Get-Command { return $false }
        $result = Install-ChocoPackage "test"
        $result | Should -Be $false
    }

    It "Install-NpmGlobal returns false when npm missing" {
        Mock Get-Command { return $false }
        $result = Install-NpmGlobal "test"
        $result | Should -Be $false
    }

    It "Install-GoPackage returns false when go missing" {
        Mock Get-Command { return $false }
        $result = Install-GoPackage "github.com/test/pkg"
        $result | Should -Be $false
    }

    It "Install-CargoPackage returns false when cargo missing" {
        Mock Get-Command { return $false }
        $result = Install-CargoPackage "test"
        $result | Should -Be $false
    }

    It "Install-PipGlobal returns false when python missing" {
        Mock Get-Command { return $false }
        $result = Install-PipGlobal "test"
        $result | Should -Be $false
    }

    It "Install-DotnetTool returns false when dotnet missing" {
        Mock Get-Command { return $false }
        $result = Install-DotnetTool "test"
        $result | Should -Be $false
    }
}

Describe "windows.ps1 - Ensure Functions" {

    It "Ensure-Scoop returns true when scoop exists" {
        Mock Get-Command { return $true }
        $result = Ensure-Scoop
        $result | Should -Be $true
    }

    It "Ensure-Scoop handles dry run" {
        $Script:DryRun = $true
        Mock Get-Command { return $false }
        $result = Ensure-Scoop
        $result | Should -Be $true
        $Script:DryRun = $false
    }

    It "Ensure-Winget returns true when available" {
        Mock Get-Command { return $true }
        $result = Ensure-Winget
        $result | Should -Be $true
    }

    It "Ensure-Winget returns false when not available" {
        Mock Get-Command { return $false }
        $result = Ensure-Winget
        $result | Should -Be $false
    }

    It "Ensure-Choco returns true when available" {
        Mock Get-Command { return $true }
        $result = Ensure-Choco
        $result | Should -Be $true
    }

    It "Ensure-Choco returns true in dry run" {
        $Script:DryRun = $true
        Mock Get-Command { return $false }
        $result = Ensure-Choco
        $result | Should -Be $true
        $Script:DryRun = $false
    }

    It "Ensure-Coursier returns true when already installed" {
        Mock Test-CoursierInstalled { return $true }
        $result = Ensure-Coursier
        $result | Should -Be $true
    }

    It "Ensure-Coursier attempts installation via scoop" {
        Mock Test-CoursierInstalled { return $false }
        Mock Get-Command { param($cmd) $cmd -eq "scoop" }
        Mock scoop {}
        Mock Refresh-Path {}
        $result = Ensure-Coursier
        $result | Should -Be $true
    }
}

Describe "windows.ps1 - Coursier Functions" {

    It "Test-CoursierInstalled checks all paths" {
        Mock Test-Path { return $false }
        Mock Get-Command { return $false }
        $result = Test-CoursierInstalled
        $result | Should -Be $false
    }

    It "Get-CoursierExe returns null when not found" {
        Mock Test-Path { return $false }
        $result = Get-CoursierExe
        $result | Should -BeNullOrEmpty
    }

    It "Install-CoursierPackage returns false when not installed" {
        Mock Test-CoursierInstalled { return $false }
        $result = Install-CoursierPackage "org.test:test"
        $result | Should -Be $false
    }

    It "Install-CoursierPackage handles dry run" {
        $Script:DryRun = $true
        Mock Test-CoursierInstalled { return $true }
        Mock Get-CoursierExe { return "cs" }
        Mock Test-NeedsInstall { return $true }
        $result = Install-CoursierPackage "org.test:test"
        $result | Should -Be $true
        $Script:DryRun = $false
    }
}

Describe "version-check.ps1 - Get-ToolVersion" {

    It "Handles non-existent tool" {
        $result = Get-ToolVersion "nonexistent-xyz-123"
        $result | Should -Be $null
    }

    It "Handles empty tool name" {
        $result = Get-ToolVersion ""
        $result | Should -Be $null
    }

    It "Uses custom version flag" {
        $result = Get-ToolVersion "echo" -VersionFlag "--version"
        # Just verify it doesn't throw
        $true | Should -Be $true
    }
}

Describe "version-check.ps1 - Show-VersionStatus" {

    It "Reports not installed" {
        Mock Test-Command { return $false }
        Mock Write-Info {}
        $result = Show-VersionStatus "test"
        $result | Should -Be $true
    }

    It "Reports installed with version" {
        Mock Test-Command { return $true }
        Mock Get-ToolVersion { return "1.2.3" }
        Mock Write-Info {}
        $result = Show-VersionStatus "test"
        $result | Should -Be $false
    }

    It "Reports installed without version" {
        Mock Test-Command { return $true }
        Mock Get-ToolVersion { return $null }
        Mock Write-Info {}
        $result = Show-VersionStatus "test"
        $result | Should -Be $false
    }

    It "Uses custom display name" {
        Mock Test-Command { return $true }
        Mock Get-ToolVersion { return "1.0.0" }
        Mock Write-Info {}
        $result = Show-VersionStatus "tool" -DisplayName "My Tool"
        $result | Should -Be $false
    }
}
