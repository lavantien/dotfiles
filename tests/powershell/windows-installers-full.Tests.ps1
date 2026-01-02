# Full tests for all windows.ps1 installer functions
# Targets every installer function and parameter combination

BeforeAll {
    $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $windowsPlatformPath = Join-Path $Script:RepoRoot "bootstrap\platforms\windows.ps1"
    $commonLibPath = Join-Path $Script:RepoRoot "bootstrap\lib\common.ps1"

    . $commonLibPath
    . $windowsPlatformPath

    $Script:DryRun = $false
    $Script:Verbose = $false
    $Script:Interactive = $false
    Reset-Tracking
}

Describe "windows.ps1 - All Install Functions Dry Run" {

    BeforeEach {
        $Script:DryRun = $true
        Mock Test-NeedsInstall { return $true }
    }

    # All install functions with basic parameters
    It "Install-ScoopPackage basic" {
        Mock Get-Command { return $true }
        $result = Install-ScoopPackage "test"
        $result | Should -Be $true
    }

    It "Install-ScoopPackage multiple packages" {
        Mock Get-Command { return $true }
        $result = Install-ScoopPackage "pkg1", "pkg2"
        $result | Should -Be $true
    }

    It "Install-WingetPackage basic" {
        Mock Get-Command { return $true }
        $result = Install-WingetPackage "Test.App"
        $result | Should -Be $true
    }

    It "Install-WingetPackage with DisplayName" {
        Mock Get-Command { return $true }
        $result = Install-WingetPackage "Test.App" -DisplayName "Test Display"
        $result | Should -Be $true
    }

    It "Install-WingetPackage with Source" {
        Mock Get-Command { return $true }
        $result = Install-WingetPackage "Test.App" -Source "test-source"
        $result | Should -Be $true
    }

    It "Install-ChocoPackage basic" {
        Mock Get-Command { return $true }
        $result = Install-ChocoPackage "test"
        $result | Should -Be $true
    }

    It "Install-ChocoPackage multiple" {
        Mock Get-Command { return $true }
        $result = Install-ChocoPackage "pkg1", "pkg2"
        $result | Should -Be $true
    }

    It "Install-NpmGlobal basic" {
        Mock Get-Command { return $true }
        $result = Install-NpmGlobal "test-package"
        $result | Should -Be $true
    }

    It "Install-NpmGlobal with custom registry" {
        Mock Get-Command { return $true }
        $result = Install-NpmGlobal "test-package" -Registry "https://registry.npmjs.org"
        $result | Should -Be $true
    }

    It "Install-GoPackage basic" {
        Mock Get-Command { return $true }
        $result = Install-GoPackage "github.com/test/pkg"
        $result | Should -Be $true
    }

    It "Install-GoPackage with version" {
        Mock Get-Command { return $true }
        $result = Install-GoPackage "github.com/test/pkg@latest"
        $result | Should -Be $true
    }

    It "Install-CargoPackage basic" {
        Mock Get-Command { return $true }
        $result = Install-CargoPackage "test"
        $result | Should -Be $true
    }

    It "Install-CargoPackage with Features" {
        Mock Get-Command { return $true }
        $result = Install-CargoPackage "test" -Features "feature1,feature2"
        $result | Should -Be $true
    }

    It "Install-PipGlobal basic" {
        Mock Get-Command { return $true }
        $result = Install-PipGlobal "test"
        $result | Should -Be $true
    }

    It "Install-PipGlobal with IndexUrl" {
        Mock Get-Command { return $true }
        $result = Install-PipGlobal "test" -IndexUrl "https://test.pypi.org/simple"
        $result | Should -Be $true
    }

    It "Install-PipGlobal with User" {
        Mock Get-Command { return $true }
        $result = Install-PipGlobal "test" -User
        $result | Should -Be $true
    }

    It "Install-DotnetTool basic" {
        Mock Get-Command { return $true }
        $result = Install-DotnetTool "test"
        $result | Should -Be $true
    }

    It "Install-DotnetTool with version" {
        Mock Get-Command { return $true }
        $result = Install-DotnetTool "test" -Version "1.0.0"
        $result | Should -Be $true
    }
}

Describe "windows.ps1 - Install Functions Skip (Already Installed)" {

    BeforeEach {
        $Script:DryRun = $false
        Mock Test-NeedsInstall { return $false }
    }

    It "Install-ScoopPackage skips when installed" {
        Mock Get-Command { return $true }
        $result = Install-ScoopPackage "test"
        $result | Should -Be $true
    }

    It "Install-WingetPackage skips when installed" {
        Mock Get-Command { return $true }
        $result = Install-WingetPackage "Test.App"
        $result | Should -Be $true
    }

    It "Install-ChocoPackage skips when installed" {
        Mock Get-Command { return $true }
        $result = Install-ChocoPackage "test"
        $result | Should -Be $true
    }

    It "Install-NpmGlobal skips when installed" {
        Mock Get-Command { return $true }
        $result = Install-NpmGlobal "test"
        $result | Should -Be $true
    }

    It "Install-GoPackage skips when installed" {
        Mock Get-Command { return $true }
        $result = Install-GoPackage "github.com/test/pkg"
        $result | Should -Be $true
    }
}

Describe "windows.ps1 - Install Functions Missing Package Manager" {

    BeforeEach {
        $Script:DryRun = $false
        Mock Test-NeedsInstall { return $true }
    }

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


Describe "windows.ps1 - Coursier Functions" {

    It "Test-CoursierInstalled returns true when found" {
        Mock Test-Path { return $true }
        $result = Test-CoursierInstalled
        $result | Should -Be $true
    }

    It "Test-CoursierInstalled returns false when not found" {
        Mock Test-Path { return $false }
        Mock Get-Command { return $false }
        $result = Test-CoursierInstalled
        $result | Should -Be $false
    }

    It "Get-CoursierExe returns path when found" {
        # Mock to return true for cs.exe path
        Mock Test-Path {
            if ($args[0] -like "*cs.exe*") { return $true }
            return $false
        }
        $result = Get-CoursierExe
        $result | Should -Not -BeNullOrEmpty
    }

    It "Get-CoursierExe returns command name when not in known paths" {
        Mock Test-Path { return $false }
        $result = Get-CoursierExe
        # Returns "coursier" as fallback (may be in PATH)
        $result | Should -Be "coursier"
    }

    It "Install-CoursierPackage returns false when not installed" {
        Mock Test-CoursierInstalled { return $false }
        $result = Install-CoursierPackage "org:test:test"
        $result | Should -Be $false
    }

    It "Install-CoursierPackage in dry run" {
        $Script:DryRun = $true
        Mock Test-CoursierInstalled { return $true }
        Mock Get-CoursierExe { return "cs.exe" }
        Mock Test-NeedsInstall { return $true }
        $result = Install-CoursierPackage "org:test:test"
        $result | Should -Be $true
    }
}

Describe "windows.ps1 - All Get-PackageDescription calls" {

    # Test all known package descriptions for full coverage
    $allPackages = @(
        "scoop", "winget", "chocolatey", "git", "gh", "lazygit",
        "ripgrep", "fd", "fzf", "bat", "eza", "zoxide", "jq", "tokei",
        "difft", "node", "npm", "python", "pip", "go", "cargo", "rust",
        "rustup", "rust-analyzer", "dotnet", "clangd", "gopls", "pyright",
        "prettier", "eslint", "ruff", "black", "bats", "bashcov", "Pester",
        "msys2", "llvm", "make", "cmake", "curl", "wget", "vim", "neovim",
        "emacs", "helix", "java", "kotlin", "scala", "clojure", "haskell",
        "lua", "perl", "ruby", "deno", "bun", "zig", "swift"
    )

    It "Returns description for all known packages" {
        foreach ($pkg in $allPackages) {
            $result = Get-PackageDescription $pkg
            $result | Should -Not -BeNullOrEmpty
        }
    }

    It "Returns package name for unknown package" {
        $result = Get-PackageDescription "completely-unknown-package-xyz"
        $result | Should -Be "completely-unknown-package-xyz"
    }
}

Describe "windows.ps1 - Windows-Specific Functions" {

    It "Get-WindowsVersion returns version object" {
        $result = Get-WindowsVersion
        $result | Should -Not -BeNullOrEmpty
    }

    It "Get-WindowsVersion is compatible with comparison" {
        $version = Get-WindowsVersion
        $version.ToString() | Should -Match "\d+"
    }
}
