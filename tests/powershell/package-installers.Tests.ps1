# Tests for package installer functions in windows.ps1
# These tests exercise the code paths to improve coverage

BeforeAll {
    $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $commonLibPath = Join-Path $Script:RepoRoot "bootstrap\lib\common.ps1"
    $versionCheckPath = Join-Path $Script:RepoRoot "bootstrap\lib\version-check.ps1"
    $windowsPlatformPath = Join-Path $Script:RepoRoot "bootstrap\platforms\windows.ps1"

    . $commonLibPath
    . $versionCheckPath
    . $windowsPlatformPath

    # Initialize script variables
    $Script:DryRun = $false
    $Script:Verbose = $false
    $Script:Interactive = $false
    Reset-Tracking
}

Describe "windows.ps1 - Get-PackageDescription - All Entries" {

    It "Returns correct description for git" {
        Get-PackageDescription "git" | Should -Be "version control"
    }

    It "Returns correct description for node" {
        Get-PackageDescription "node" | Should -Be "Node.js runtime"
    }

    It "Returns correct description for nodejs" {
        Get-PackageDescription "nodejs" | Should -Be "Node.js runtime"
    }

    It "Returns correct description for python" {
        Get-PackageDescription "python" | Should -Be "Python runtime"
    }

    It "Returns correct description for go" {
        Get-PackageDescription "go" | Should -Be "Go runtime"
    }

    It "Returns correct description for rust" {
        Get-PackageDescription "rust" | Should -Be "Rust toolchain"
    }

    It "Returns correct description for scoop" {
        Get-PackageDescription "scoop" | Should -Be "package manager"
    }

    It "Returns correct description for winget" {
        Get-PackageDescription "winget" | Should -Be "Windows package manager"
    }

    It "Returns correct description for chocolatey" {
        Get-PackageDescription "chocolatey" | Should -Be "package manager"
    }

    It "Returns correct description for npm" {
        Get-PackageDescription "npm" | Should -Be "Node.js package manager"
    }

    It "Returns correct description for prettier" {
        Get-PackageDescription "prettier" | Should -Be "code formatter"
    }

    It "Returns correct description for eslint" {
        Get-PackageDescription "eslint" | Should -Be "JavaScript linter"
    }

    It "Returns correct description for ruff" {
        Get-PackageDescription "ruff" | Should -Be "Python linter"
    }

    It "Returns correct description for black" {
        Get-PackageDescription "black" | Should -Be "Python formatter"
    }

    It "Returns correct description for fzf" {
        Get-PackageDescription "fzf" | Should -Be "fuzzy finder"
    }

    It "Returns correct description for zoxide" {
        Get-PackageDescription "zoxide" | Should -Be "smart directory navigation"
    }

    It "Returns correct description for bat" {
        Get-PackageDescription "bat" | Should -Be "enhanced cat"
    }

    It "Returns correct description for eza" {
        Get-PackageDescription "eza" | Should -Be "enhanced ls"
    }

    It "Returns correct description for lazygit" {
        Get-PackageDescription "lazygit" | Should -Be "Git TUI"
    }

    It "Returns correct description for gh" {
        Get-PackageDescription "gh" | Should -Be "GitHub CLI"
    }

    It "Returns correct description for rg" {
        Get-PackageDescription "rg" | Should -Be "text search"
    }

    It "Returns correct description for ripgrep" {
        Get-PackageDescription "ripgrep" | Should -Be "text search"
    }

    It "Returns correct description for fd" {
        Get-PackageDescription "fd" | Should -Be "file finder"
    }

    It "Returns correct description for gopls" {
        Get-PackageDescription "gopls" | Should -Be "Go LSP"
    }

    It "Returns correct description for rust-analyzer" {
        Get-PackageDescription "rust-analyzer" | Should -Be "Rust LSP"
    }

    It "Returns correct description for pyright" {
        Get-PackageDescription "pyright" | Should -Be "Python LSP"
    }

    It "Returns correct description for clangd" {
        Get-PackageDescription "clangd" | Should -Be "C/C++ LSP"
    }

    It "Returns empty string for unknown package" {
        Get-PackageDescription "unknown-xyz-123" | Should -Be ""
    }
}

Describe "windows.ps1 - Install-NpmGlobal - Code Paths" {

    It "Handles missing npm command" {
        Mock Get-Command { return $false }

        $result = Install-NpmGlobal "test-package"
        $result | Should -Be $false
    }

    It "Extracts command name from scoped package" {
        Mock Get-Command { param($cmd) $cmd -eq "npm" }
        Mock Test-NeedsInstall { return $false }

        $result = Install-NpmGlobal "@test-org/test-package"
        $result | Should -Be $true
    }

    It "Extracts command name from unscoped package" {
        Mock Get-Command { param($cmd) $cmd -eq "npm" }
        Mock Test-NeedsInstall { return $false }

        $result = Install-NpmGlobal "test-package"
        $result | Should -Be $true
    }

    It "Handles dry run mode" {
        $Script:DryRun = $true
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $true }

        $result = Install-NpmGlobal "test-package"
        $result | Should -Be $true
        $Script:DryRun = $false
    }
}

Describe "windows.ps1 - Install-GoPackage - Code Paths" {

    It "Handles missing go command" {
        Mock Get-Command { return $false }

        $result = Install-GoPackage "github.com/test/pkg"
        $result | Should -Be $false
    }

    It "Extracts command name from package path" {
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $false }

        $result = Install-GoPackage "github.com/test/cli"
        $result | Should -Be $true
    }

    It "Uses provided CmdName parameter" {
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $false }

        $result = Install-GoPackage "github.com/test/pkg" -CmdName "testcmd"
        $result | Should -Be $true
    }

    It "Handles dry run mode" {
        $Script:DryRun = $true
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $true }

        $result = Install-GoPackage "github.com/test/pkg"
        $result | Should -Be $true
        $Script:DryRun = $false
    }
}

Describe "windows.ps1 - Install-CargoPackage - Code Paths" {

    It "Handles missing cargo command" {
        Mock Get-Command { return $false }

        $result = Install-CargoPackage "test-package"
        $result | Should -Be $false
    }

    It "Handles dry run mode" {
        $Script:DryRun = $true
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $true }

        $result = Install-CargoPackage "test-package"
        $result | Should -Be $true
        $Script:DryRun = $false
    }
}

Describe "windows.ps1 - Install-PipGlobal - Code Paths" {

    It "Handles missing python" {
        Mock Get-Command { return $false }

        $result = Install-PipGlobal "test-package"
        $result | Should -Be $false
    }

    It "Handles python3 as fallback" {
        Mock Get-Command { param($cmd) $cmd -eq "python3" }
        Mock Test-NeedsInstall { return $false }

        $result = Install-PipGlobal "test-package"
        $result | Should -Be $true
    }

    It "Handles dry run mode" {
        $Script:DryRun = $true
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $true }

        $result = Install-PipGlobal "test-package"
        $result | Should -Be $true
        $Script:DryRun = $false
    }
}

Describe "windows.ps1 - Install-DotnetTool - Code Paths" {

    It "Handles missing dotnet" {
        Mock Get-Command { return $false }

        $result = Install-DotnetTool "test-tool"
        $result | Should -Be $false
    }

    It "Handles dry run mode" {
        $Script:DryRun = $true
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $true }

        $result = Install-DotnetTool "test-tool"
        $result | Should -Be $true
        $Script:DryRun = $false
    }
}

Describe "windows.ps1 - Install-ChocoPackage - Code Paths" {

    It "Handles missing choco" {
        Mock Get-Command { return $false }

        $result = Install-ChocoPackage "test"
        $result | Should -Be $false
    }

    It "Uses CheckCmd parameter" {
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $false }

        $result = Install-ChocoPackage "test" -CheckCmd "testcmd"
        $result | Should -Be $true
    }

    It "Handles dry run mode" {
        $Script:DryRun = $true
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $true }

        $result = Install-ChocoPackage "test"
        $result | Should -Be $true
        $Script:DryRun = $false
    }
}

Describe "windows.ps1 - Test-CoursierInstalled - All Paths" {

    It "Checks scoop shim path" {
        Mock Test-Path { param($path) $path -like "*shims*coursier.cmd" }

        $result = Test-CoursierInstalled
        $result | Should -Be $true
    }

    It "Checks cs.exe path" {
        Mock Test-Path { param($path) $path -like "*cs.exe" }
        Mock Get-Command { return $false }

        $result = Test-CoursierInstalled
        $result | Should -Be $true
    }

    It "Checks Get-Command as fallback" {
        Mock Test-Path { return $false }
        Mock Get-Command { return $true }

        $result = Test-CoursierInstalled
        $result | Should -Be $true
    }

    It "Returns false when not found" {
        Mock Test-Path { return $false }
        Mock Get-Command { return $false }

        $result = Test-CoursierInstalled
        $result | Should -Be $false
    }
}

Describe "windows.ps1 - Get-CoursierExe - All Paths" {

    It "Returns scoop shim when exists" {
        Mock Test-Path { param($path) $path -like "*shims*coursier.cmd" }
        Mock Join-Path { return "C:\scoop\shims\coursier.cmd" }

        $result = Get-CoursierExe
        $result | Should -Be "C:\scoop\shims\coursier.cmd"
    }

    It "Returns cs.exe path when exists" {
        Mock Test-Path { param($path) $path -like "*cs.exe" }
        Mock Join-Path { return "C:\local\bin\cs.exe" }

        $result = Get-CoursierExe
        $result | Should -Be "C:\local\bin\cs.exe"
    }

    It "Returns null when not found" {
        Mock Test-Path { return $false }

        $result = Get-CoursierExe
        $result | Should -BeNullOrEmpty
    }
}

Describe "windows.ps1 - Ensure-Coursier - All Paths" {

    It "Returns true when already installed" {
        Mock Test-CoursierInstalled { return $true }

        $result = Ensure-Coursier
        $result | Should -Be $true
    }

    It "Installs via scoop when available" {
        Mock Test-CoursierInstalled { return $false }
        Mock Get-Command { param($cmd) $cmd -eq "scoop" }
        Mock scoop {}
        Mock Refresh-Path {}

        $result = Ensure-Coursier
        $result | Should -Be $true
    }

    It "Returns false when scoop not available" {
        Mock Test-CoursierInstalled { return $false }
        Mock Get-Command { return $false }

        $result = Ensure-Coursier
        $result | Should -Be $false
    }

    It "Handles dry run mode" {
        $Script:DryRun = $true
        Mock Test-CoursierInstalled { return $false }

        $result = Ensure-Coursier
        $result | Should -Be $true
        $Script:DryRun = $false
    }
}

Describe "windows.ps1 - Install-CoursierPackage - All Paths" {

    It "Returns false when coursier not installed" {
        Mock Test-CoursierInstalled { return $false }

        $result = Install-CoursierPackage "org.test:test"
        $result | Should -Be $false
    }

    It "Handles dry run mode" {
        $Script:DryRun = $true
        Mock Test-CoursierInstalled { return $true }
        Mock Get-CoursierExe { return "cs.exe" }
        Mock Test-NeedsInstall { return $true }

        $result = Install-CoursierPackage "org.test:test"
        $result | Should -Be $true
        $Script:DryRun = $false
    }

    It "Handles already installed packages" {
        Mock Test-CoursierInstalled { return $true }
        Mock Get-CoursierExe { return "cs.exe" }
        Mock Test-NeedsInstall { return $false }

        $result = Install-CoursierPackage "org.test:test"
        $result | Should -Be $true
    }
}

Describe "windows.ps1 - Install-ScoopPackages - All Paths" {

    It "Handles empty package list" {
        Mock Get-Command { return $true }

        $result = Install-ScoopPackages @()
        $result | Should -Be $true
    }

    It "Installs only needed packages" {
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { param($pkg) $pkg -eq "git" }
        Mock scoop {}

        $result = Install-ScoopPackages @("git", "node")
        $result | Should -Be $true
    }

    It "Handles all packages installed" {
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $false }

        $result = Install-ScoopPackages @("git", "node")
        $result | Should -Be $true
    }

    It "Handles dry run mode" {
        $Script:DryRun = $true
        Mock Test-NeedsInstall { return $true }

        $result = Install-ScoopPackages @("pkg1", "pkg2")
        $result | Should -Be $true
        $Script:DryRun = $false
    }
}

Describe "windows.ps1 - Install-Rustup - All Paths" {

    It "Returns true when already installed" {
        Mock Get-Command { return $true }

        $result = Install-Rustup
        $result | Should -Be $true
    }

    It "Returns true in dry run mode" {
        $Script:DryRun = $true
        Mock Get-Command { return $false }

        $result = Install-Rustup
        $result | Should -Be $true
        $Script:DryRun = $false
    }
}

Describe "windows.ps1 - Install-RustAnalyzerComponent - All Paths" {

    It "Returns false when rustup not available" {
        Mock Get-Command { return $false }

        $result = Install-RustAnalyzerComponent
        $result | Should -Be $false
    }

    It "Handles already installed" {
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $false }

        $result = Install-RustAnalyzerComponent
        $result | Should -Be $true
    }

    It "Handles dry run mode" {
        $Script:DryRun = $true
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $true }

        $result = Install-RustAnalyzerComponent
        $result | Should -Be $true
        $Script:DryRun = $false
    }
}

Describe "windows.ps1 - Ensure-Winget - All Paths" {

    It "Returns true when available" {
        Mock Get-Command { return $true }

        $result = Ensure-Winget
        $result | Should -Be $true
    }

    It "Returns false when not available" {
        Mock Get-Command { return $false }

        $result = Ensure-Winget
        $result | Should -Be $false
    }
}

Describe "windows.ps1 - Ensure-Choco - All Paths" {

    It "Returns true when available" {
        Mock Get-Command { return $true }

        $result = Ensure-Choco
        $result | Should -Be $true
    }

    It "Returns true in dry run mode" {
        $Script:DryRun = $true
        Mock Get-Command { return $false }

        $result = Ensure-Choco
        $result | Should -Be $true
        $Script:DryRun = $false
    }
}

Describe "windows.ps1 - Add-ScoopBucket - All Paths" {

    It "Returns true for already added bucket" {
        Mock scoop { return @("main", "extras", "versions") }

        $result = Add-ScoopBucket "extras"
        $result | Should -Be $true
    }

    It "Returns true in dry run mode" {
        $Script:DryRun = $true
        Mock scoop { return @("main") }

        $result = Add-ScoopBucket "extras"
        $result | Should -Be $true
        $Script:DryRun = $false
    }
}
