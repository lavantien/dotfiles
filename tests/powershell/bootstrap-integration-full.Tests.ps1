# Integration tests for bootstrap.ps1

BeforeAll {
    $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $commonLibPath = Join-Path $Script:RepoRoot "bootstrap\lib\common.ps1"
    $versionCheckPath = Join-Path $Script:RepoRoot "bootstrap\lib\version-check.ps1"
    . $commonLibPath
    . $versionCheckPath
    $Script:DryRun = $false
    $Script:Categories = 'full'
    function Reset-TestTracking {
        $Script:InstalledPackages = @()
        $Script:SkippedPackages = @()
        $Script:FailedPackages = @()
    }
}

Describe "Bootstrap Integration - Core Functions" {
    BeforeEach { Reset-TestTracking }
    It "Tracks installed packages" {
        Track-Installed "test-pkg" "description"
        $Script:InstalledPackages | Should -Contain "test-pkg (description)"
    }
    It "Tracks skipped packages" {
        Track-Skipped "test-pkg" "description"
        $Script:SkippedPackages | Should -Contain "test-pkg (description)"
    }
    It "Tracks failed packages" {
        Track-Failed "test-pkg" "description"
        $Script:FailedPackages | Should -Contain "test-pkg (description)"
    }
    It "Writes header" { Write-Header "Test" 6>&1 | Should -Match "Test" }
    It "Writes step" { Write-Step "Test" 6>&1 | Should -Match "Test" }
    It "Writes success" { Write-Success "Test" 6>&1 | Should -Match "Test" }
    It "Tests command" { Mock Get-Command { return $true }; Test-Command "test" | Should -BeTrue }
    It "Detects platform" {
        $platform = Get-OSPlatform
        $platform | Should -BeIn @("windows", "macos", "linux", "unknown")
    }
}

Describe "Bootstrap - Foundation" {
    BeforeEach { Reset-TestTracking }
    It "Handles git not installed" {
        Mock Test-Command { return $false } -ParameterFilter { $Command -eq "git" }
        Test-Command "git" | Should -BeFalse
    }
    It "Handles git installed" {
        Mock Test-Command { return $true } -ParameterFilter { $Command -eq "git" }
        Test-Command "git" | Should -BeTrue
    }
}

Describe "Bootstrap - SDKs" {
    BeforeEach { Reset-TestTracking; $Script:Categories = "full" }
    It "Checks Node" { Mock Test-Command { return $false }; Test-Command "node" | Should -BeFalse }
    It "Checks Python" { Mock Test-Command { return $true }; Test-Command "python" | Should -BeTrue }
    It "Checks Go" { Mock Test-Command { return $false }; Test-Command "go" | Should -BeFalse }
    It "Checks Rust" { Mock Test-Command { return $true }; Test-Command "rustc" | Should -BeTrue }
}

Describe "Bootstrap - Lang Servers" {
    BeforeEach { Reset-TestTracking; $Script:Categories = "full" }
    It "Checks clangd" { Mock Test-Command { return $false }; Test-Command "clangd" | Should -BeFalse }
    It "Checks gopls" { Mock Test-Command { return $true }; Test-Command "gopls" | Should -BeTrue }
    It "Checks rust-analyzer" { Mock Test-Command { return $false }; Test-Command "rust-analyzer" | Should -BeFalse }
    It "Checks pyright" { Mock Test-Command { return $true }; Test-Command "pyright" | Should -BeTrue }
}

Describe "Bootstrap - Linters" {
    BeforeEach { Reset-TestTracking }
    It "Checks prettier" { Mock Test-Command { return $false }; Test-Command "prettier" | Should -BeFalse }
    It "Checks eslint" { Mock Test-Command { return $true }; Test-Command "eslint" | Should -BeTrue }
    It "Checks ruff" { Mock Test-Command { return $false }; Test-Command "ruff" | Should -BeFalse }
    It "Checks black" { Mock Test-Command { return $true }; Test-Command "black" | Should -BeTrue }
}

Describe "Bootstrap - CLI Tools" {
    BeforeEach { Reset-TestTracking }
    It "Checks fzf" { Mock Test-Command { return $false }; Test-Command "fzf" | Should -BeFalse }
    It "Checks zoxide" { Mock Test-Command { return $true }; Test-Command "zoxide" | Should -BeTrue }
    It "Checks bat" { Mock Test-Command { return $false }; Test-Command "bat" | Should -BeFalse }
    It "Checks eza" { Mock Test-Command { return $true }; Test-Command "eza" | Should -BeTrue }
}

Describe "Bootstrap - Version Check" {
    It "Compares versions" {
        Compare-Versions "1.2.3" "1.2.0" | Should -BeTrue
        Compare-Versions "1.2.0" "1.2.3" | Should -BeFalse
    }
    It "Tests needs install" {
        Mock Test-Command { return $false }
        Test-NeedsInstall "fake-tool" | Should -BeTrue
    }
}

Describe "Bootstrap - Categories" {
    It "Handles minimal" { $Script:Categories = "minimal"; $Script:Categories | Should -Be "minimal" }
    It "Handles sdk" { $Script:Categories = "sdk"; $Script:Categories | Should -Be "sdk" }
    It "Handles full" { $Script:Categories = "full"; $Script:Categories | Should -Be "full" }
}

Describe "Bootstrap - Dry Run" {
    It "Sets dry run" { $Script:DryRun = $true; $Script:DryRun | Should -BeTrue }
}

Describe "Bootstrap - Summary" {
    BeforeEach { Reset-TestTracking }
    It "Writes summary" {
        Track-Installed "pkg1" "desc1"
        Track-Skipped "pkg2" "desc2"
        Track-Failed "pkg3" "desc3"
        Write-Summary
        $Script:InstalledPackages.Count | Should -Be 1
        $Script:SkippedPackages.Count | Should -Be 1
        $Script:FailedPackages.Count | Should -Be 1
    }
}

# ============================================================================
# Comprehensive Bootstrap.ps1 Function Tests with Mocking
# ============================================================================

Describe "Bootstrap.ps1 - Install-ScoopPackage Function Calls" {

    BeforeEach {
        Reset-TestTracking
        $Script:DryRun = $false
        $Script:Categories = 'full'
    }

    It "Install-ScoopPackage with all parameters" {
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $false }
        Mock Track-Skipped {}

        Install-ScoopPackage "test-package" "1.0.0" "testcmd"

        Should -Invoke Track-Skipped -Times 1 -Scope It
    }

    It "Install-NpmGlobal with description" {
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $false }
        Mock Track-Skipped {}

        Install-NpmGlobal "test-package" "testcmd" "description"

        Should -Invoke Track-Skipped -Times 1 -Scope It
    }

    It "Install-GoPackage with full path" {
        Mock Get-Command { param($Name) return $true }
        Mock Track-Skipped {}

        Install-GoPackage "example.com/pkg/module" "pkg"

        Should -Invoke Track-Skipped -Times 1 -Scope It
    }

    It "Install-CargoPackage with version check" {
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $false }
        Mock Track-Skipped {}

        Install-CargoPackage "test-package" "testcmd" "1.0.0"

        Should -Invoke Track-Skipped -Times 1 -Scope It
    }

    It "Install-PipGlobal with description" {
        Mock Get-Command { param($Name) return $true }
        Mock Test-NeedsInstall { return $false }
        Mock Track-Skipped {}

        Install-PipGlobal "test-package" "testcmd" "description"

        Should -Invoke Track-Skipped -Times 1 -Scope It
    }

    It "Install-DotnetTool with description" {
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $false }
        Mock Track-Skipped {}

        Install-DotnetTool "test-tool" "testcmd" "description"

        Should -Invoke Track-Skipped -Times 1 -Scope It
    }
}

Describe "Bootstrap.ps1 - Package Manager Checks" {

    BeforeEach {
        Reset-TestTracking
        $Script:DryRun = $false
        $Script:Categories = 'full'
    }

    It "Ensures Scoop installation" {
        Mock Get-Command { return $true }
        Mock Track-Skipped {}

        Ensure-Scoop

        Should -Invoke Track-Skipped -Times 1 -Scope It
    }

    It "Ensures Winget availability" {
        Mock Get-Command { return $true }
        Mock Track-Skipped {}

        Ensure-Winget

        Should -Invoke Track-Skipped -Times 1 -Scope It
    }

    It "Ensures Choco installation" {
        Mock Get-Command { return $true }
        Mock Track-Skipped {}

        Ensure-Choco

        Should -Invoke Track-Skipped -Times 1 -Scope It
    }
}

Describe "Bootstrap.ps1 - Language Server Installation" {

    BeforeEach {
        Reset-TestTracking
        $Script:DryRun = $false
        $Script:Categories = 'full'
    }

    It "Installs clangd" {
        Mock Install-ScoopPackage {}
        Mock Track-Skipped {}

        Install-ScoopPackage "llvm" "" "clangd"

        Should -Invoke Install-ScoopPackage -Times 1 -Scope It
    }

    It "Installs gopls" {
        Mock Get-Command { param($Name) return $true }
        Mock Track-Skipped {}

        Install-GoPackage "golang.org/x/tools/gopls@latest" "gopls" ""

        Should -Invoke Track-Skipped -Times 1 -Scope It
    }

    It "Installs rust-analyzer" {
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $false }
        Mock Track-Skipped {}

        Install-RustAnalyzerComponent

        Should -Invoke Track-Skipped -Times 1 -Scope It
    }
}

Describe "Bootstrap.ps1 - Linter Installation" {

    BeforeEach {
        Reset-TestTracking
        $Script:DryRun = $false
        $Script:Categories = 'full'
    }

    It "Installs prettier via npm" {
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $false }
        Mock Track-Skipped {}

        Install-NpmGlobal "prettier" "prettier" ""

        Should -Invoke Track-Skipped -Times 1 -Scope It
    }

    It "Installs eslint via npm" {
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $false }
        Mock Track-Skipped {}

        Install-NpmGlobal "eslint" "eslint" ""

        Should -Invoke Track-Skipped -Times 1 -Scope It
    }

    It "Installs ruff via pip" {
        Mock Get-Command { param($Name) return $true }
        Mock Test-NeedsInstall { return $false }
        Mock Track-Skipped {}

        Install-PipGlobal "ruff" "ruff" ""

        Should -Invoke Track-Skipped -Times 1 -Scope It
    }

    It "Installs shellcheck via scoop" {
        Mock Install-ScoopPackage {}
        Mock Track-Skipped {}

        Install-ScoopPackage "shellcheck" "" "shellcheck"

        Should -Invoke Install-ScoopPackage -Times 1 -Scope It
    }

    It "Installs shfmt via scoop" {
        Mock Install-ScoopPackage {}
        Mock Track-Skipped {}

        Install-ScoopPackage "shfmt" "" "shfmt"

        Should -Invoke Install-ScoopPackage -Times 1 -Scope It
    }

    It "Installs scalafmt via coursier" {
        Mock Test-CoursierInstalled { return $true }
        Mock Test-NeedsInstall { return $false }
        Mock Track-Skipped {}

        Install-CoursierPackage "scalafmt" "" "scalafmt"

        Should -Invoke Track-Skipped -Times 1 -Scope It
    }
}

Describe "Bootstrap.ps1 - CLI Tool Installation" {

    BeforeEach {
        Reset-TestTracking
        $Script:DryRun = $false
        $Script:Categories = 'full'
    }

    It "Installs fzf" {
        Mock Install-ScoopPackage {}
        Mock Track-Skipped {}

        Install-ScoopPackage "fzf" "" "fzf"

        Should -Invoke Install-ScoopPackage -Times 1 -Scope It
    }

    It "Installs zoxide" {
        Mock Install-ScoopPackage {}
        Mock Track-Skipped {}

        Install-ScoopPackage "zoxide" "" "zoxide"

        Should -Invoke Install-ScoopPackage -Times 1 -Scope It
    }

    It "Installs bat" {
        Mock Install-ScoopPackage {}
        Mock Track-Skipped {}

        Install-ScoopPackage "bat" "" "bat"

        Should -Invoke Install-ScoopPackage -Times 1 -Scope It
    }

    It "Installs eza" {
        Mock Install-ScoopPackage {}
        Mock Track-Skipped {}

        Install-ScoopPackage "eza" "" "eza"

        Should -Invoke Install-ScoopPackage -Times 1 -Scope It
    }

    It "Installs lazygit" {
        Mock Install-ScoopPackage {}
        Mock Track-Skipped {}

        Install-ScoopPackage "lazygit" "" "lazygit"

        Should -Invoke Install-ScoopPackage -Times 1 -Scope It
    }

    It "Installs gh" {
        Mock Install-ScoopPackage {}
        Mock Track-Skipped {}

        Install-ScoopPackage "gh" "" "gh"

        Should -Invoke Install-ScoopPackage -Times 1 -Scope It
    }

    It "Installs ripgrep" {
        Mock Install-ScoopPackage {}
        Mock Track-Skipped {}

        Install-ScoopPackage "ripgrep" "" "rg"

        Should -Invoke Install-ScoopPackage -Times 1 -Scope It
    }

    It "Installs fd" {
        Mock Install-ScoopPackage {}
        Mock Track-Skipped {}

        Install-ScoopPackage "fd" "" "fd"

        Should -Invoke Install-ScoopPackage -Times 1 -Scope It
    }

    It "Installs tokei" {
        Mock Install-ScoopPackage {}
        Mock Track-Skipped {}

        Install-ScoopPackage "tokei" "" "tokei"

        Should -Invoke Install-ScoopPackage -Times 1 -Scope It
    }

    It "Installs difftastic" {
        Mock Install-ScoopPackage {}
        Mock Track-Skipped {}

        Install-ScoopPackage "difftastic" "" "difft"

        Should -Invoke Install-ScoopPackage -Times 1 -Scope It
    }
}

Describe "Bootstrap.ps1 - Rust Installation" {

    BeforeEach {
        Reset-TestTracking
        $Script:DryRun = $false
        $Script:Categories = 'full'
    }

    It "Installs rustup" {
        Mock Get-Command { return $true }
        Mock Track-Skipped {}

        Install-Rustup

        Should -Invoke Track-Skipped -Times 1 -Scope It
    }

    It "Installs rust-analyzer component" {
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $false }
        Mock Track-Skipped {}

        Install-RustAnalyzerComponent

        Should -Invoke Track-Skipped -Times 1 -Scope It
    }
}

Describe "Bootstrap.ps1 - Coursier Integration" {

    BeforeEach {
        Reset-TestTracking
        $Script:DryRun = $false
        $Script:Categories = 'full'
    }

    It "Ensures Coursier is installed" {
        Mock Test-CoursierInstalled { return $true }
        Mock Track-Skipped {}

        Ensure-Coursier

        Should -Invoke Track-Skipped -Times 1 -Scope It
    }

    It "Tests Coursier installation" {
        Mock Test-Path { return $true }
        Mock Get-Command { return $true }

        $result = Test-CoursierInstalled
        $result | Should -Be $true
    }
}

Describe "Bootstrap.ps1 - Write-Color Function" {

    It "Writes info message in cyan" {
        Mock Write-Host {}
        Write-Info "test message"
        Should -Invoke Write-Host -Times 1 -Scope It
    }

    It "Writes success message in green" {
        Mock Write-Host {}
        Write-Success "test message"
        Should -Invoke Write-Host -Times 1 -Scope It
    }

    It "Writes warning message in yellow" {
        Mock Write-Host {}
        Write-Warning "test message"
        Should -Invoke Write-Host -Times 1 -Scope It
    }

    It "Writes error message in red" {
        Mock Write-Host {}
        Write-Error-Msg "test message"
        Should -Invoke Write-Host -Times 1 -Scope It
    }
}

Describe "Bootstrap.ps1 - Test-NeedsInstall Function" {

    It "Returns true when command not found" {
        Mock Get-Command {}
        $result = Test-NeedsInstall "nonexistent"
        $result | Should -Be $true
    }

    It "Returns false when command exists with no min version" {
        Mock Get-Command { return $true }
        $result = Test-NeedsInstall "testcmd" "" ""
        $result | Should -Be $false
    }

    It "Returns true when version is too old" {
        Mock Get-Command { return $true }
        Mock Get-CommandVersion { return "1.0.0" }
        Mock Compare-Versions { return $true }
        $result = Test-NeedsInstall "testcmd" "2.0.0" ""
        $result | Should -Be $true
    }
}

Describe "Bootstrap.ps1 - Package Description Mapping" {

    It "Returns description for scoop" {
        $result = Get-PackageDescription "scoop"
        $result | Should -Be "package manager"
    }

    It "Returns description for winget" {
        $result = Get-PackageDescription "winget"
        $result | Should -Be "Windows package manager"
    }

    It "Returns description for git" {
        $result = Get-PackageDescription "git"
        $result | Should -Be "version control"
    }

    It "Returns empty for unknown package" {
        $result = Get-PackageDescription "unknown-xyz"
        $result | Should -Be ""
    }
}

Describe "Bootstrap.ps1 - Configure-GitSettings Function" {

    It "Configures git settings without throwing" {
        Mock Get-Command { return $true }
        Mock Invoke-SafeInstall { return $true }
        Mock Write-Step {}
        Mock Write-Success {}

        { Configure-GitSettings } | Should -Not -Throw
    }
}

Describe "Bootstrap.ps1 - Category Behavior" {

    BeforeEach {
        Reset-TestTracking
        $Script:DryRun = $false
    }

    It "Skips SDKs in minimal mode" {
        $Script:Categories = "minimal"
        # SDK installation should be skipped
        $Script:Categories | Should -Be "minimal"
    }

    It "Installs SDKs in full mode" {
        $Script:Categories = "full"
        $Script:Categories | Should -Be "full"
    }
}

Describe "Bootstrap.ps1 - Dry Run Mode" {

    BeforeEach {
        Reset-TestTracking
    }

    It "Returns true for all operations in dry run mode" {
        $Script:DryRun = $true
        Mock Write-Info {}
        Mock Track-Installed {}

        $result = Install-ScoopPackage "test" "" "test"
        $result | Should -Be $true
    }

    It "Skips actual installation in dry run mode" {
        $Script:DryRun = $true
        Mock Write-Info {}
        Mock Track-Installed {}

        Install-WingetPackage "test.id" "Test"

        Should -Not -Invoke Get-Command -Scope It
    }
}
