# End-to-end tests for update-all.ps1 wrapper
# Tests that the wrapper correctly invokes update-all.sh via Git Bash

Describe "Update All E2E - Script Structure" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $updateAllPs1 = Join-Path $RepoRoot "update-all.ps1"
        $updateAllSh = Join-Path $RepoRoot "update-all.sh"
    }

    Context "Script Files" {

        It "update-all.ps1 exists and is readable" {
            Test-Path $updateAllPs1 | Should -Be $true
        }

        It "update-all.sh exists as source of truth" {
            Test-Path $updateAllSh | Should -Be $true
        }

        It "update-all.ps1 is much smaller than update-all.sh" {
            $ps1Lines = (Get-Content $updateAllPs1).Count
            $shLines = (Get-Content $updateAllSh).Count
            $shLines | Should -BeGreaterThan ($ps1Lines * 2) "Because .sh is source of truth"
        }
    }

    Context "Wrapper Pattern" {

        It "update-all.ps1 is a wrapper that invokes update-all.sh" {
            $content = Get-Content $updateAllPs1 -Raw
            $content | Should -Match "update-all\.sh"
            $content | Should -Match "& bash"
        }

        It "Wrapper derives script path dynamically" {
            $content = Get-Content $updateAllPs1 -Raw
            $content | Should -Match "MyInvocation"
            $content | Should -Match "ScriptDir"
        }
    }
}

Describe "Update All E2E - Error Handling" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $updateAllPs1 = Join-Path $RepoRoot "update-all.ps1"
    }

    Context "Git Bash Detection" {

        It "update-all.ps1 checks for bash before invoking" {
            $content = Get-Content $updateAllPs1 -Raw
            $content | Should -Match "Get-Command bash"
        }

        It "update-all.ps1 has helpful error when bash not found" {
            $content = Get-Content $updateAllPs1 -Raw
            $content | Should -Match "Git Bash.*not found"
            $content | Should -Match "git-scm\.com"
        }

        It "update-all.ps1 exits with error code when bash not found" {
            $content = Get-Content $updateAllPs1 -Raw
            $content | Should -Match "exit 1"
        }
    }
}

Describe "Update All E2E - Exit Code Propagation" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $updateAllPs1 = Join-Path $RepoRoot "update-all.ps1"
    }

    It "Propagates exit code from bash script" {
        $content = Get-Content $updateAllPs1 -Raw
        $content | Should -Match '\$exitCode.*=.*& bash'
        $content | Should -Match 'exit \$exitCode'
    }
}

Describe "Update All E2E - Argument Passing" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $updateAllPs1 = Join-Path $RepoRoot "update-all.ps1"
    }

    It "Passes all arguments through to bash script" {
        $content = Get-Content $updateAllPs1 -Raw
        $content | Should -Match '\$args'
    }

    It "Uses proper argument syntax for bash invocation" {
        $content = Get-Content $updateAllPs1 -Raw
        # Verify bash is invoked
        $content | Should -Match 'bash'
        # Verify variable names are used
        $content | Should -Match '\$shScript'
        $content | Should -Match '\$args'
    }
}

Describe "Update All E2E - Documentation" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $updateAllPs1 = Join-Path $RepoRoot "update-all.ps1"
    }

    It "Has wrapper documentation header" {
        $content = Get-Content $updateAllPs1 -Raw
        $content | Should -Match "# Update All Script Wrapper"
        $content | Should -Match "Invokes update-all\.sh"
    }
}
