# Unit tests for bootstrap.ps1
# Tests parameter parsing, platform detection, and core functions

BeforeAll {
    # Setup test environment - get repo root
    $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $commonLibPath = Join-Path $RepoRoot "bootstrap\lib\common.ps1"
    . $commonLibPath
}

Describe "Bootstrap Common Functions" {

    Context "Logging Functions" {

        It "Write-Info outputs info message" {
            $output = Write-Info "test message" 6>&1
            $output | Should -Match "\[INFO\] test message"
        }

        It "Write-Success outputs success message" {
            $output = Write-Success "test message" 6>&1
            $output | Should -Match "\[OK\] test message"
        }

        It "Write-Warning outputs warning message" {
            $output = Write-Warning "test message" 6>&1
            $output | Should -Match "\[WARN\] test message"
        }

        It "Write-Error-Msg outputs error message" {
            $output = Write-Error-Msg "test message" 6>&1
            $output | Should -Match "\[ERROR\] test message"
        }
    }

    Context "Command Existence" {

        It "Test-Command returns true for existing commands" {
            Test-Command "ls" | Should -Be $true
        }

        It "Test-Command returns false for non-existent commands" {
            Test-Command "nonexistent_command_xyz123" | Should -Be $false
        }
    }

    Context "Install Functions" {

        It "Invoke-SafeInstall returns result from script block" {
            # Mock successful install - note: function returns array so we check last element
            $result = Invoke-SafeInstall { param($a) $true } "test-package"
            $result[-1] | Should -Be $true
        }

        It "Invoke-SafeInstall handles failures gracefully" {
            # Mock failed install - scriptblock that throws
            $result = Invoke-SafeInstall { param($a) throw "test error" } "test-package"
            $result | Should -Be $false
        }
    }

    Context "Path Management" {

        It "Add-ToPath adds new path to PATH" {
            $newPath = "C:\test-path-$(New-Guid)"
            $originalPath = $env:PATH

            # Create the directory first (Add-ToPath only adds to session PATH if it exists)
            New-Item -ItemType Directory -Path $newPath -Force | Out-Null
            try {
                Add-ToPath $newPath

                $env:PATH.Split(';') | Should -Contain $newPath
            }
            finally {
                # Cleanup
                Remove-Item -Path $newPath -Force -ErrorAction SilentlyContinue
                $env:PATH = $originalPath
            }
        }
    }

    Context "Platform Detection" {

        It "Get-OSPlatform returns a known platform" {
            $platform = Get-OSPlatform
            $platform | Should -BeIn @("windows", "linux", "macos")
        }
    }
}

Describe "Bootstrap Tracking Functions" {

    BeforeEach {
        Reset-Tracking
    }

    It "Track-Installed adds to installed list" {
        $initialCount = $Script:InstalledPackages.Count
        Track-Installed "test-package"
        $Script:InstalledPackages.Count | Should -Be ($initialCount + 1)
    }

    It "Track-Installed adds description when provided" {
        Track-Installed "test-package" "test description"
        $Script:InstalledPackages[-1] | Should -Be "test-package (test description)"
    }

    It "Track-Skipped adds to skipped list" {
        $initialCount = $Script:SkippedPackages.Count
        Track-Skipped "test-package"
        $Script:SkippedPackages.Count | Should -Be ($initialCount + 1)
    }

    It "Track-Skipped adds description when provided" {
        Track-Skipped "test-package" "test description"
        $Script:SkippedPackages[-1] | Should -Be "test-package (test description)"
    }

    It "Track-Failed adds to failed list" {
        $initialCount = $Script:FailedPackages.Count
        Track-Failed "test-package"
        $Script:FailedPackages.Count | Should -Be ($initialCount + 1)
    }

    It "Track-Failed adds description when provided" {
        Track-Failed "test-package" "test description"
        $Script:FailedPackages[-1] | Should -Be "test-package (test description)"
    }
}
