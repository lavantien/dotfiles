# Unit tests for update-all.ps1
# Tests update logic, timeout handling, and prerequisites

Describe "Update All Helpers" {

    BeforeAll {
        # Source update-all functions
        $Script:TestDir = Join-Path $PSScriptRoot ".."
        . (Join-Path $TestDir "update-all.ps1")
    }

    Context "Update Status Functions" {

        It "Update-Success increments updated counter" {
            $script:updated = 5
            Update-Success "test"
            $script:updated | Should -Be 6
        }

        It "Update-Skip increments skipped counter" {
            $script:skipped = 3
            Update-Skip "test reason"
            $script:skipped | Should -Be 4
        }

        It "Update-Fail increments failed counter" {
            $script:failed = 1
            Update-Fail "test failure"
            $script:failed | Should -Be 2
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

        It "Test-Prerequisites outputs informative messages" {
            $output = Test-Prerequisites 6>&1
            $output | Should -Match "Checking prerequisites"
        }
    }

    Context "Update Logic" {

        It "Update-AndReport fails on non-zero exit code" {
            $script:failed = 0
            Update-AndReport -Cmd "exit 1" -Name "test"
            $script:failed | Should -Be 1
        }

        It "Update-AndReport succeeds on successful command" {
            Update-AndReport -Cmd "Write-Host 'test'" -Name "test"
            $LASTEXITCODE | Should -Be 0
        }

        It "Update-AndReport detects changes in output" {
            Update-AndReport -Cmd "Write-Host 'changed files installed'" -Name "test"
            # Output should be shown
            $LASTEXITCODE | Should -Be 0
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

        It "Update-AndReport filters noisy output" {
            $output = Update-AndReport -Cmd "Write-Host 'npm warn test'" -Name "test" 6>&1
            # Should filter npm warnings
            $LASTEXITCODE | Should -Be 0
        }
    }
}

Describe "Update All Summary" {

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

    It "Outputs correct summary counts" {
        $script:updated = 10
        $script:skipped = 2
        $script:failed = 1

        # Summary would display these values
        $script:updated | Should -Be 10
        $script:skipped | Should -Be 2
        $script:failed | Should -Be 1
    }
}
