# Unit tests for bootstrap.ps1
# Tests parameter parsing, platform detection, and core functions

BeforeAll {
    # Setup test environment
    $Script:TestDir = Join-Path $PSScriptRoot ".."
    . (Join-Path $TestDir "lib\common.ps1")
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

        It "Write-Error outputs error message" {
            $output = Write-Error "test message" 6>&1
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

    Context "Helper Functions" {

        It "Capitalize first letter" {
            $result = & Capitalize "hello"
            $result | Should -Be "Hello"
        }

        It "Join strings with delimiter" {
            $result = Join-ByString "," "a", "b", "c"
            $result | Should -Be "a,b,c"
        }
    }
}

Describe "Bootstrap Install Functions" {

    Context "Safe Install Wrapper" {

        It "Safe-Install returns true on success" {
            # Mock successful install
            $result = Safe-Install { param($a, $b, $c) $true } "test-package" "test-command"
            $result | Should -Be $true
        }

        It "Safe-Install returns false on failure" {
            # Mock failed install
            $result = Safe-Install { param($a, $b, $c) $false } "test-package" "test-command"
            $result | Should -Be $false
        }
    }

    Context "Path Management" {

        It "Add-ToPath adds new path to PATH" {
            $newPath = "C:\test-path-$([guid]::NewGuid())"
            $originalPath = $env:PATH

            Add-ToPath $newPath

            $env:PATH | Should -Match $newPath

            # Cleanup
            $env:PATH = $originalPath
        }

        It "Add-ToPath does not duplicate existing paths" {
            $existingPath = $env:PATH -split ';' | Select-Object -First 1
            $originalPath = $env:PATH

            Add-ToPath $existingPath

            $count = ($env:PATH -split ';' | Where-Object { $_ -eq $existingPath }).Count
            $count | Should -Be 1

            # Cleanup
            $env:PATH = $originalPath
        }
    }
}

Describe "Bootstrap Configuration" {

    Context "Config Loading" {

        It "Load-DotfilesConfig returns without error" {
            # Test with non-existent config (should use defaults)
            { Load-DotfilesConfig -ConfigFile "nonexistent.yaml" } | Should -Not -Throw
        }

        It "Get-ConfigValue returns default for missing key" {
            # Mock empty config
            $script:CONFIG_TEST = ""
            $result = Get-ConfigValue -Key "test" -Default "default_value"
            $result | Should -Be "default_value"
        }
    }

    Context "Skip Package" {

        It "Test-SkipPackage returns false for normal packages" {
            $script:CONFIG_SKIP_PACKAGES = @()
            Test-SkipPackage "package1" | Should -Be $false
        }

        It "Test-SkipPackage returns true for skipped packages" {
            $script:CONFIG_SKIP_PACKAGES = @("package1", "package2")
            Test-SkipPackage "package1" | Should -Be $true
            Test-SkipPackage "package3" | Should -Be $false
        }
    }
}
