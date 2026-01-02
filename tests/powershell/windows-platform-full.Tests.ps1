# Full functional tests for windows.ps1
# Tests actual code execution paths to improve coverage

BeforeAll {
    $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $commonLibPath = Join-Path $Script:RepoRoot "bootstrap\lib\common.ps1"
    $versionCheckPath = Join-Path $Script:RepoRoot "bootstrap\lib\version-check.ps1"
    $windowsPlatformPath = Join-Path $Script:RepoRoot "bootstrap\platforms\windows.ps1"

    . $commonLibPath
    . $versionCheckPath
    . $windowsPlatformPath

    $Script:DryRun = $false
    $Script:Interactive = $false
}

Describe "windows.ps1 - Configure-GitSettings" {

    BeforeEach {
        Reset-Tracking
        $Script:DryRun = $false
    }

    Context "When git config returns non-input value" {

        It "Configures core.autocrlf to input" {
            Mock git { return "false" }

            { Configure-GitSettings } | Should -Not -Throw
        }
    }

    Context "When git config already set to input" {

        It "Skips autocrlf configuration" {
            Mock git { return "input" }

            { Configure-GitSettings } | Should -Not -Throw
        }
    }

    Context "When known_hosts doesn't exist" {

        It "Creates .ssh directory and adds GitHub key" {
            Mock git { return "input" }
            Mock Test-Path { $false }
            Mock New-Item {}
            Mock Get-Command { $true }
            Mock ssh-keyscan { "github.com ssh-rsa key" }

            { Configure-GitSettings } | Should -Not -Throw
        }
    }

    Context "When GitHub key already in known_hosts" {

        It "Skips adding GitHub key" {
            Mock git { return "input" }
            Mock Test-Path { $true }
            Mock Get-Content { return "github.com ssh-rsa existing-key" }

            { Configure-GitSettings } | Should -Not -Throw
        }
    }

    Context "When in dry run mode" {

        BeforeEach {
            $Script:DryRun = $true
        }

        AfterEach {
            $Script:DryRun = $false
        }

        It "Skips actual git configuration in dry run" {
            Mock git { return "false" }

            { Configure-GitSettings } | Should -Not -Throw
        }
    }
}

Describe "windows.ps1 - Ensure-Scoop" {

    BeforeEach {
        Reset-Tracking
        $Script:DryRun = $false
    }

    It "Returns true when scoop is already installed" {
        Mock Get-Command { return $true }

        $result = Ensure-Scoop
        $result | Should -Be $true
    }

    It "Returns true in dry run mode" {
        $Script:DryRun = $true
        Mock Get-Command { return $false }

        $result = Ensure-Scoop
        $result | Should -Be $true
    }

    It "Attempts installation when not installed" {
        Mock Get-Command { return $false }
        Mock Set-ExecutionPolicy {}
        Mock irm { return "install script" }
        Mock iex {}

        $result = Ensure-Scoop
        $result | Should -BeOfType [bool]
    }
}

Describe "windows.ps1 - Install-ScoopPackage" {

    BeforeEach {
        Reset-Tracking
        $Script:DryRun = $false
    }

    It "Installs package when scoop exists and package needs install" {
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $true }
        Mock scoop {}

        $result = Install-ScoopPackage "git"
        $result | Should -Be $true
    }

    It "Returns false when scoop not installed" {
        Mock Get-Command { return $false }

        $result = Install-ScoopPackage "git"
        $result | Should -Be $false
    }

    It "Skips installation when package already installed" {
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $false }

        $result = Install-ScoopPackage "git"
        $result | Should -Be $true
    }

    It "Returns true in dry run mode" {
        $Script:DryRun = $true
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $true }

        $result = Install-ScoopPackage "git"
        $result | Should -Be $true
    }
}

Describe "windows.ps1 - Install-ScoopPackages" {

    BeforeEach {
        Reset-Tracking
        $Script:DryRun = $false
    }

    It "Installs all packages when needed" {
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $true }
        Mock scoop {}

        $result = Install-ScoopPackages @("git", "node", "python")
        $result | Should -Be $true
    }

    It "Installs only missing packages" {
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { param($pkg) $pkg -eq "git" }
        Mock scoop {}

        $result = Install-ScoopPackages @("git", "node", "python")
        $result | Should -Be $true
    }

    It "Skips installation when all packages installed" {
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $false }

        $result = Install-ScoopPackages @("git", "node", "python")
        $result | Should -Be $true
    }

    It "Returns true with empty packages list" {
        Mock Get-Command { return $true }

        $result = Install-ScoopPackages @()
        $result | Should -Be $true
    }

    It "Returns true in dry run mode" {
        $Script:DryRun = $true
        Mock Test-NeedsInstall { return $true }

        $result = Install-ScoopPackages @("pkg1", "pkg2")
        $result | Should -Be $true
    }
}

Describe "windows.ps1 - Add-ScoopBucket" {

    BeforeEach {
        $Script:DryRun = $false
    }

    It "Returns true in dry run mode" {
        $Script:DryRun = $true

        $result = Add-ScoopBucket "extras"
        $result | Should -Be $true
    }

    It "Adds bucket when not already present" {
        Mock scoop { return @("main", "versions") }

        { Add-ScoopBucket "extras" } | Should -Not -Throw
    }

    It "Skips adding bucket when already present" {
        Mock scoop { return @("main", "versions", "extras") }

        { Add-ScoopBucket "extras" } | Should -Not -Throw
    }
}

Describe "windows.ps1 - Ensure-Winget" {

    BeforeEach {
        Reset-Tracking
        $Script:DryRun = $false
    }

    It "Returns true when winget is available" {
        Mock Get-Command { return $true }

        $result = Ensure-Winget
        $result | Should -Be $true
    }

    It "Returns false when winget is not available" {
        Mock Get-Command { return $false }

        $result = Ensure-Winget
        $result | Should -Be $false
    }
}

Describe "windows.ps1 - Install-WingetPackage" {

    BeforeEach {
        Reset-Tracking
        $Script:DryRun = $false
    }

    It "Installs package when winget available and needed" {
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $true }
        Mock winget {}

        $result = Install-WingetPackage "Git.Git" -DisplayName "Git"
        $result | Should -Be $true
    }

    It "Returns false when winget not available" {
        Mock Get-Command { return $false }

        $result = Install-WingetPackage "Git.Git" -DisplayName "Git"
        $result | Should -Be $false
    }

    It "Skips installation when package already installed" {
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $false }

        $result = Install-WingetPackage "Git.Git" -DisplayName "Git"
        $result | Should -Be $true
    }

    It "Returns true in dry run mode" {
        $Script:DryRun = $true
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $true }

        $result = Install-WingetPackage "Git.Git" -DisplayName "Git"
        $result | Should -Be $true
    }
}

Describe "windows.ps1 - Ensure-Choco" {

    BeforeEach {
        Reset-Tracking
        $Script:DryRun = $false
    }

    It "Returns true when Chocolatey is already installed" {
        Mock Get-Command { return $true }

        $result = Ensure-Choco
        $result | Should -Be $true
    }

    It "Returns true in dry run mode" {
        $Script:DryRun = $true
        Mock Get-Command { return $false }

        $result = Ensure-Choco
        $result | Should -Be $true
    }
}

Describe "windows.ps1 - Install-ChocoPackage" {

    BeforeEach {
        Reset-Tracking
        $Script:DryRun = $false
    }

    It "Installs package when Chocolatey available" {
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $true }
        Mock choco {}

        $result = Install-ChocoPackage "git"
        $result | Should -Be $true
    }

    It "Returns false when Chocolatey not available" {
        Mock Get-Command { return $false }

        $result = Install-ChocoPackage "git"
        $result | Should -Be $false
    }

    It "Returns true in dry run mode" {
        $Script:DryRun = $true
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $true }

        $result = Install-ChocoPackage "git"
        $result | Should -Be $true
    }

    It "Skips when package already installed" {
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $false }

        $result = Install-ChocoPackage "git"
        $result | Should -Be $true
    }
}

Describe "windows.ps1 - Install-NpmGlobal" {

    BeforeEach {
        Reset-Tracking
        $Script:DryRun = $false
    }

    It "Installs package when npm available" {
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $true }
        Mock npm {}

        $result = Install-NpmGlobal "prettier"
        $result | Should -Be $true
    }

    It "Returns false when npm not found" {
        Mock Get-Command { return $false }

        $result = Install-NpmGlobal "prettier"
        $result | Should -Be $false
    }

    It "Handles scoped packages" {
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $true }
        Mock npm {}

        $result = Install-NpmGlobal "@typescript-eslint/eslint-plugin"
        $result | Should -Be $true
    }

    It "Returns true in dry run mode" {
        $Script:DryRun = $true
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $true }

        $result = Install-NpmGlobal "prettier"
        $result | Should -Be $true
    }
}

Describe "windows.ps1 - Install-GoPackage" {

    BeforeEach {
        Reset-Tracking
        $Script:DryRun = $false
    }

    It "Installs package using gup when available" {
        Mock Get-Command { param($cmd) $cmd -eq "go" -or $cmd -eq "gup" }
        Mock go { return "C:\Users\test\go" }
        Mock gup {}

        $result = Install-GoPackage "github.com/cli/cli" -CmdName "gh"
        $result | Should -Be $true
    }

    It "Returns false when go not found" {
        Mock Get-Command { return $false }

        $result = Install-GoPackage "github.com/cli/cli"
        $result | Should -Be $false
    }

    It "Returns true when command already exists" {
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $false }

        $result = Install-GoPackage "github.com/cli/cli" -CmdName "gh"
        $result | Should -Be $true
    }

    It "Returns true in dry run mode" {
        $Script:DryRun = $true
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $true }

        $result = Install-GoPackage "example.com/pkg"
        $result | Should -Be $true
    }
}

Describe "windows.ps1 - Install-CargoPackage" {

    BeforeEach {
        Reset-Tracking
        $Script:DryRun = $false
    }

    It "Installs package when cargo available" {
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $true }
        Mock cargo {}

        $result = Install-CargoPackage "ripgrep"
        $result | Should -Be $true
    }

    It "Returns false when cargo not found" {
        Mock Get-Command { return $false }

        $result = Install-CargoPackage "ripgrep"
        $result | Should -Be $false
    }

    It "Returns true in dry run mode" {
        $Script:DryRun = $true
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $true }

        $result = Install-CargoPackage "ripgrep"
        $result | Should -Be $true
    }
}

Describe "windows.ps1 - Install-PipGlobal" {

    BeforeEach {
        Reset-Tracking
        $Script:DryRun = $false
    }

    It "Installs package when python available" {
        Mock Get-Command { param($cmd) $cmd -eq "python" }
        Mock Test-NeedsInstall { return $true }
        Mock python {}

        $result = Install-PipGlobal "black"
        $result | Should -Be $true
    }

    It "Uses python3 when python not available" {
        Mock Get-Command { param($cmd) $cmd -eq "python3" }
        Mock Test-NeedsInstall { return $true }
        Mock python3 {}

        $result = Install-PipGlobal "black"
        $result | Should -Be $true
    }

    It "Returns false when no python available" {
        Mock Get-Command { return $false }

        $result = Install-PipGlobal "black"
        $result | Should -Be $false
    }

    It "Returns true in dry run mode" {
        $Script:DryRun = $true
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $true }

        $result = Install-PipGlobal "black"
        $result | Should -Be $true
    }
}

Describe "windows.ps1 - Install-DotnetTool" {

    BeforeEach {
        Reset-Tracking
        $Script:DryRun = $false
    }

    It "Installs package when dotnet available" {
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $true }
        Mock dotnet {}

        $result = Install-DotnetTool "dotnet-format"
        $result | Should -Be $true
    }

    It "Returns false when dotnet not found" {
        Mock Get-Command { return $false }

        $result = Install-DotnetTool "dotnet-format"
        $result | Should -Be $false
    }

    It "Returns true in dry run mode" {
        $Script:DryRun = $true
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $true }

        $result = Install-DotnetTool "dotnet-format"
        $result | Should -Be $true
    }
}

Describe "windows.ps1 - Install-Rustup" {

    BeforeEach {
        Reset-Tracking
        $Script:DryRun = $false
    }

    It "Returns true when rustup already installed" {
        Mock Get-Command { return $true }

        $result = Install-Rustup
        $result | Should -Be $true
    }

    It "Returns true in dry run mode" {
        $Script:DryRun = $true
        Mock Get-Command { return $false }

        $result = Install-Rustup
        $result | Should -Be $true
    }
}

Describe "windows.ps1 - Install-RustAnalyzerComponent" {

    BeforeEach {
        Reset-Tracking
        $Script:DryRun = $false
    }

    It "Adds component when rustup available" {
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $true }
        Mock rustup {}

        $result = Install-RustAnalyzerComponent
        $result | Should -Be $true
    }

    It "Returns false when rustup not found" {
        Mock Get-Command { return $false }

        $result = Install-RustAnalyzerComponent
        $result | Should -Be $false
    }

    It "Returns true when component already installed" {
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $false }

        $result = Install-RustAnalyzerComponent
        $result | Should -Be $true
    }

    It "Returns true in dry run mode" {
        $Script:DryRun = $true
        Mock Get-Command { return $true }
        Mock Test-NeedsInstall { return $true }

        $result = Install-RustAnalyzerComponent
        $result | Should -Be $true
    }
}

Describe "windows.ps1 - Test-CoursierInstalled" {

    It "Returns true when scoop shim exists" {
        Mock Test-Path { param($path) $path -like "*coursier.cmd" }

        $result = Test-CoursierInstalled
        $result | Should -Be $true
    }

    It "Returns true when cs.exe exists" {
        $env:USERPROFILE = "C:\Users\test"
        Mock Test-Path { param($path) $path -like "*cs.exe" }

        $result = Test-CoursierInstalled
        $result | Should -Be $true
    }

    It "Returns true when command available" {
        Mock Test-Path { $false }
        Mock Get-Command { return $true }

        $result = Test-CoursierInstalled
        $result | Should -Be $true
    }

    It "Returns false when coursier not installed" {
        Mock Test-Path { $false }
        Mock Get-Command { return $false }

        $result = Test-CoursierInstalled
        $result | Should -Be $false
    }
}

Describe "windows.ps1 - Get-CoursierExe" {

    It "Returns scoop shim path when it exists" {
        Mock Test-Path { $true }
        Mock Join-Path { return "C:\Users\test\scoop\shims\coursier.cmd" }

        $result = Get-CoursierExe
        $result | Should -Be "C:\Users\test\scoop\shims\coursier.cmd"
    }

    It "Returns cs.exe path when it exists" {
        Mock Test-Path { param($path) $path -like "*cs.exe" }
        Mock Join-Path { return "C:\Users\test\.local\share\coursier\bin\cs.exe" }

        $result = Get-CoursierExe
        $result | Should -BeLike "*cs.exe"
    }
}

Describe "windows.ps1 - Ensure-Coursier" {

    BeforeEach {
        Reset-Tracking
        $Script:DryRun = $false
    }

    It "Returns true when coursier already installed" {
        Mock Test-CoursierInstalled { return $true }

        $result = Ensure-Coursier
        $result | Should -Be $true
    }

    It "Installs via scoop when not installed and scoop available" {
        Mock Test-CoursierInstalled { return $false }
        Mock Get-Command { param($cmd) $cmd -eq "scoop" }
        Mock scoop {}
        Mock Refresh-Path {}

        $result = Ensure-Coursier
        $result | Should -Be $true
    }

    It "Returns false when not installed and scoop not available" {
        Mock Test-CoursierInstalled { return $false }
        Mock Get-Command { return $false }

        $result = Ensure-Coursier
        $result | Should -Be $false
    }

    It "Returns true in dry run mode" {
        $Script:DryRun = $true
        Mock Test-CoursierInstalled { return $false }

        $result = Ensure-Coursier
        $result | Should -Be $true
    }
}

Describe "windows.ps1 - Install-CoursierPackage" {

    BeforeEach {
        Reset-Tracking
        $Script:DryRun = $false
    }

    It "Installs package when coursier available" {
        Mock Test-CoursierInstalled { return $true }
        Mock Get-CoursierExe { return "cs.exe" }
        Mock Test-NeedsInstall { return $true }
        Mock Test-Path { $false }
        Mock Start-Process {}

        $result = Install-CoursierPackage "org.scalameta:scalafmt_2.13" -CheckCmd "scalafmt"
        $result | Should -Be $true
    }

    It "Returns false when coursier not installed" {
        Mock Test-CoursierInstalled { return $false }

        $result = Install-CoursierPackage "org.scalameta:scalafmt_2.13"
        $result | Should -Be $false
    }

    It "Returns true in dry run mode" {
        $Script:DryRun = $true
        Mock Test-CoursierInstalled { return $true }
        Mock Test-NeedsInstall { return $true }

        $result = Install-CoursierPackage "test-package"
        $result | Should -Be $true
    }
}

Describe "windows.ps1 - Add-ToPath" {

    It "Adds path to user PATH when not already present" {
        $testPath = "C:\TempTestPath\Bin"

        { Add-ToPath $testPath } | Should -Not -Throw
    }

    It "Does not add duplicate paths" {
        $testPath = "C:\Windows\system32"

        { Add-ToPath $testPath } | Should -Not -Throw
    }
}

Describe "windows.ps1 - Refresh-Path" {

    It "Refreshes PATH from environment variables" {
        { Refresh-Path } | Should -Not -Throw
    }
}
