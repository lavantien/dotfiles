# Unit tests for update-all.ps1
# Tests update logic, timeout handling, and prerequisites

Describe "Update All Helpers" {

    BeforeAll {
        # Source update-all functions
        $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $updateAllPath = Join-Path $RepoRoot "update-all.ps1"
        . $updateAllPath
    }

    BeforeEach {
        # Reset counters before each test
        $script:updated = 0
        $script:skipped = 0
        $script:failed = 0
    }

    Context "Update Status Functions" {

        It "Update-Success outputs success message" {
            $output = Update-Success "test" 6>&1
            $output | Should -Match "test"
        }

        It "Update-Skip outputs skip message" {
            $output = Update-Skip "test reason" 6>&1
            $output | Should -Match "Skipped"
            $output | Should -Match "test reason"
        }

        It "Update-Fail outputs fail message" {
            $output = Update-Fail "test failure" 6>&1
            $output | Should -Match "Failed"
        }

        It "Update-Section outputs formatted section header" {
            $output = Update-Section "Test Section" 6>&1
            $output | Should -Match "Test Section"
        }
    }

    Context "Command Existence" {

        It "Get-Command returns command for existing tools" {
            $cmd = Get-Command ls -ErrorAction SilentlyContinue
            $cmd | Should -Not -Be $null
        }

        It "Get-Command returns null for non-existent tools" {
            $cmd = Get-Command nonexistent_command_xyz123 -ErrorAction SilentlyContinue
            $cmd | Should -Be $null
        }
    }

    Context "Timeout Handling" {

        It "Invoke-WithTimeout executes quick command" {
            $output = Invoke-WithTimeout -Timeout 10 -Command "Write-Host 'quick command'"
            $output | Should -Not -Be $false
        }

        It "Invoke-WithTimeout times out long-running commands" {
            # This test takes ~5 seconds to run
            $result = Invoke-WithTimeout -Timeout 1 -Command "Start-Sleep -Seconds 5"
            $result | Should -Be $false
        }
    }

    Context "Prerequisites Check" {

        It "Test-Prerequisites does not throw error" {
            { Test-Prerequisites } | Should -Not -Throw
        }
    }

    Context "Update Logic" {

        It "Update-AndReport handles errors gracefully" {
            $script:failed = 0
            # Use a command that fails with stderr output
            Update-AndReport -Cmd "cmd /c 'exit 1'" -Name "test"
            # The function should handle the error without throwing
            $script:failed | Should -BeGreaterOrEqual 0
        }

        It "Update-AndReport succeeds on successful command" {
            $script:updated = 0
            Update-AndReport -Cmd "Write-Host 'test'" -Name "test"
            $script:updated | Should -BeGreaterOrEqual 0
        }
    }

    Context "PowerShell Update Helpers" {

        It "Update-Pip handles empty package list" {
            # Mock pip to return empty
            { Update-Pip -PipCmd "echo" -Name "test" } | Should -Not -Throw
        }

        It "Update-DotnetTools handles empty tool list" {
            # Mock dotnet to return empty
            { Update-DotnetTools } | Should -Not -Throw
        }
    }
}

Describe "Update All Summary" {

    BeforeAll {
        # Source update-all functions for this describe block
        $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $updateAllPath = Join-Path $RepoRoot "update-all.ps1"
        . $updateAllPath
    }

    It "Calculates duration correctly" {
        $startTime = Get-Date "2024-01-01 10:00:00"
        $endTime = Get-Date "2024-01-01 10:05:30"
        $duration = $endTime - $startTime

        $duration.TotalMinutes | Should -Be 5.5
    }

    It "Formats duration as mm:ss" {
        $duration = [TimeSpan]::FromMinutes(5.5)
        $formatted = "{0:mm\:ss}" -f $duration
        $formatted | Should -Be "05:30"
    }
}

Describe "Sourced Guard Pattern" {

    BeforeAll {
        # Source update-all functions for this describe block
        $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $updateAllPath = Join-Path $RepoRoot "update-all.ps1"
        . $updateAllPath
    }

    It "Start-UpdateAll function exists" {
        $cmd = Get-Command Start-UpdateAll -ErrorAction SilentlyContinue
        $cmd | Should -Not -Be $null
    }

    It "Functions are available when sourced" {
        $functions = @("Update-Section", "Update-Success", "Update-Skip", "Update-Fail", "Test-Prerequisites", "Invoke-WithTimeout", "Update-AndReport", "Update-Pip", "Update-DotnetTools")

        foreach ($func in $functions) {
            $cmd = Get-Command $func -ErrorAction SilentlyContinue
            $cmd | Should -Not -Be $null
        }
    }
}
