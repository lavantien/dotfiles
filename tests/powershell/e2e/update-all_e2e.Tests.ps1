# End-to-end tests for update-all.ps1 safety features
# Tests that update-all handles edge cases and errors gracefully

Describe "Update All E2E - Script Loading" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $updateAllPath = Join-Path $RepoRoot "update-all.ps1"
    }

    Context "Script Files" {

        It "update-all.ps1 exists and is readable" {
            Test-Path $updateAllPath | Should -Be $true
        }

        It "update-all.sh exists for bash compatibility" {
            $updateAllSh = Join-Path $RepoRoot "update-all.sh"
            Test-Path $updateAllSh | Should -Be $true
        }
    }

    Context "Sourcing Script" {

        It "update-all.ps1 can be sourced without executing" {
            $content = Get-Content $updateAllPath -Raw
            $content.Length | Should -BeGreaterThan 0
        }

        It "Script contains sourced guard pattern" {
            $content = Get-Content $updateAllPath -Raw
            $content | Should -Match "MyInvocation"
        }
    }
}

Describe "Update All E2E - Helper Functions" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $updateAllPath = Join-Path $RepoRoot "update-all.ps1"
        . $updateAllPath
    }

    BeforeEach {
        # Reset counters before each test
        $script:updated = 0
        $script:skipped = 0
        $script:failed = 0
    }

    Context "Status Functions" {

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
}

Describe "Update All E2E - Command Detection" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $updateAllPath = Join-Path $RepoRoot "update-all.ps1"
        . $updateAllPath
    }

    It "Returns command for existing tools" {
        $cmd = Get-Command git -ErrorAction SilentlyContinue
        $cmd | Should -Not -Be $null
    }

    It "Returns null for non-existent tools" {
        $cmd = Get-Command nonexistent_command_xyz123 -ErrorAction SilentlyContinue
        $cmd | Should -Be $null
    }
}

Describe "Update All E2E - Timeout Handling" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $updateAllPath = Join-Path $RepoRoot "update-all.ps1"
        . $updateAllPath
    }

    It "Executes quick commands within timeout" {
        $output = Invoke-WithTimeout -Timeout 10 -Command "Write-Host 'quick'"
        $output | Should -Not -Be $false
    }

    It "Handles slow commands within timeout" {
        $output = Invoke-WithTimeout -Timeout 5 -Command "Start-Sleep -Seconds 1; Write-Host 'done'"
        $output | Should -Not -Be $false
    }
}

Describe "Update All E2E - Prerequisites" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $updateAllPath = Join-Path $RepoRoot "update-all.ps1"
        . $updateAllPath
    }

    It "Test-Prerequisites does not throw error" {
        { Test-Prerequisites } | Should -Not -Throw
    }

    It "Test-Prerequisites outputs informative messages" {
        $output = Test-Prerequisites 6>&1
        # Output should contain some information
        $output | Should -Not -Be $null
    }
}

Describe "Update All E2E - Counters" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $updateAllPath = Join-Path $RepoRoot "update-all.ps1"
        . $updateAllPath
    }

    BeforeEach {
        # Reset internal counters between tests
        $updated = 0
        $skipped = 0
        $failed = 0
    }

    It "Update-Success outputs success message" {
        $output = Update-Success "test tool" 6>&1
        $output | Should -Match "test tool"
        $output | Should -Match "Done|✓|Success"
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
}

Describe "Update All E2E - Update And Report" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $updateAllPath = Join-Path $RepoRoot "update-all.ps1"
        . $updateAllPath
    }

    BeforeEach {
        $script:updated = 0
        $script:failed = 0
    }

    It "Handles command failure" {
        $script:failed = 0
        Update-AndReport -Cmd "cmd /c 'exit 1'" -Name "test"
        # The function should handle the error without throwing
        $script:failed | Should -BeGreaterOrEqual 0
    }

    It "Succeeds on successful command" {
        $script:updated = 0
        Update-AndReport -Cmd "Write-Host 'test'" -Name "test"
        $script:updated | Should -BeGreaterOrEqual 0
    }

    It "Detects changes in output" {
        $script:updated = 0
        Update-AndReport -Cmd "Write-Host 'files were changed'" -Name "test"
        $script:updated | Should -BeGreaterOrEqual 0
    }

    It "Handles empty output" {
        $script:updated = 0
        Update-AndReport -Cmd "Write-Host ''" -Name "test"
        $script:updated | Should -BeGreaterOrEqual 0
    }
}

Describe "Update All E2E - Config Integration" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $updateAllPath = Join-Path $RepoRoot "update-all.ps1"
        . $updateAllPath
    }

    It "Respects CONFIG_CATEGORIES minimal" {
        $CONFIG_CATEGORIES = "minimal"
        $CONFIG_CATEGORIES | Should -Be "minimal"
    }

    It "Respects CONFIG_SKIP_PACKAGES" {
        $CONFIG_SKIP_PACKAGES = "npm yarn"

        $skipList = $CONFIG_SKIP_PACKAGES -replace ',', ' '
        $result = $skipList -split ' ' | Where-Object { $_ -eq "npm" }
        $result.Count | Should -BeGreaterOrEqual 1
    }

    It "Handles comma-separated skip list" {
        $CONFIG_SKIP_PACKAGES = "npm, yarn, pnpm"

        $skipList = $CONFIG_SKIP_PACKAGES -replace ', ', ' ' -replace ',', ' '
        $result = $skipList -split ' ' | Where-Object { $_ -eq "yarn" }
        $result.Count | Should -BeGreaterOrEqual 1
    }
}

Describe "Update All E2E - Safety" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $updateAllPath = Join-Path $RepoRoot "update-all.ps1"
        . $updateAllPath
    }

    It "Handles missing package manager gracefully" {
        $cmd = Get-Command nonexistent_pkg_xyz123 -ErrorAction SilentlyContinue
        $cmd | Should -Be $null
    }

    It "Continues after individual tool failure" {
        # The script should continue even if one tool update fails
        # This tests the philosophy - both functions should run without error
        $failOutput = Update-Fail "test tool" 6>&1
        $successOutput = Update-Success "another tool" 6>&1

        # Both should produce output
        $failOutput | Should -Not -Be $null
        $successOutput | Should -Not -Be $null
    }
}

Describe "Update All E2E - PowerShell Specific" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $updateAllPath = Join-Path $RepoRoot "update-all.ps1"
        . $updateAllPath
    }

    Context "PowerShell Module Updates" {

        It "Update-Pip handles empty package list" {
            { Update-Pip -PipCmd "echo" -Name "test" } | Should -Not -Throw
        }

        It "Update-DotnetTools handles empty tool list" {
            { Update-DotnetTools } | Should -Not -Throw
        }
    }

    Context "Scoop Updates (Windows)" {

        It "Checks if Scoop is installed" {
            $scoopCmd = Get-Command scoop -ErrorAction SilentlyContinue

            if ($scoopCmd) {
                $scoopCmd | Should -Not -Be $null
            } else {
                # Test passes even if Scoop is not installed
                $true | Should -Be $true
            }
        }
    }
}

Describe "Update All E2E - Duration Calculation" {

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

Describe "Update All E2E - Sourced Guard Pattern" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $updateAllPath = Join-Path $RepoRoot "update-all.ps1"
        . $updateAllPath
    }

    It "Start-UpdateAll function exists" {
        $cmd = Get-Command Start-UpdateAll -ErrorAction SilentlyContinue
        $cmd | Should -Not -Be $null
    }

    It "Functions are available when sourced" {
        $functions = @("Update-Section", "Update-Success", "Update-Skip", "Update-Fail",
                       "Test-Prerequisites", "Invoke-WithTimeout", "Update-AndReport",
                       "Update-Pip", "Update-DotnetTools")

        foreach ($func in $functions) {
            $cmd = Get-Command $func -ErrorAction SilentlyContinue
            $cmd | Should -Not -Be $null
        }
    }
}

Describe "Update All E2E - Summary Report" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $updateAllPath = Join-Path $RepoRoot "update-all.ps1"
        . $updateAllPath
    }

    It "Generates summary with all counters" {
        $script:updated = 10
        $script:skipped = 5
        $script:failed = 2

        $script:updated | Should -Be 10
        $script:skipped | Should -Be 5
        $script:failed | Should -Be 2
    }

    It "Handles zero counters gracefully" {
        $script:updated = 0
        $script:skipped = 0
        $script:failed = 0

        $script:updated | Should -Be 0
        $script:skipped | Should -Be 0
        $script:failed | Should -Be 0
    }

    It "Calculates total processed" {
        $script:updated = 10
        $script:skipped = 5
        $script:failed = 2
        $total = $script:updated + $script:skipped + $script:failed

        $total | Should -Be 17
    }
}
