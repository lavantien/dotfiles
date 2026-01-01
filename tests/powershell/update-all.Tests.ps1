# Unit tests for update-all.ps1 wrapper
# Tests that the wrapper correctly invokes update-all.sh via Git Bash

Describe "Update-All Script - Structure" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $Script:UpdateAllPs1 = Join-Path $RepoRoot "update-all.ps1"
        $Script:UpdateAllSh = Join-Path $RepoRoot "update-all.sh"
    }

    Context "Script Files Exist" {

        It "update-all.ps1 exists and is readable" {
            Test-Path $Script:UpdateAllPs1 | Should -Be $true
        }

        It "update-all.sh exists as source of truth" {
            Test-Path $Script:UpdateAllSh | Should -Be $true
        }
    }

    Context "Wrapper Pattern" {

        It "update-all.ps1 is a wrapper that invokes update-all.sh" {
            $content = Get-Content $Script:UpdateAllPs1 -Raw
            $content | Should -Match "update-all\.sh"
            $content | Should -Match "& bash"
        }

        It "Wrapper derives .sh path from script location" {
            $content = Get-Content $Script:UpdateAllPs1 -Raw
            $content | Should -Match "MyInvocation\.MyCommand\.Path"
            $content | Should -Match "Join-Path.*ScriptDir"
        }

        It "Wrapper has error action preference set to Stop" {
            $content = Get-Content $Script:UpdateAllPs1 -Raw
            $content | Should -Match '\$ErrorActionPreference.*Stop'
        }
    }
}

Describe "Update-All Script - Git Bash Detection" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $Script:UpdateAllPs1 = Join-Path $RepoRoot "update-all.ps1"
    }

    It "Checks for Git Bash availability" {
        $content = Get-Content $Script:UpdateAllPs1 -Raw
        $content | Should -Match "Get-Command bash"
    }

    It "Provides helpful error message when bash not found" {
        $content = Get-Content $Script:UpdateAllPs1 -Raw
        $content | Should -Match "Git Bash.*not found"
        $content | Should -Match "git-scm\.com/download/win"
    }

    It "Exits with error code 1 when bash not found" {
        $content = Get-Content $Script:UpdateAllPs1 -Raw
        $content | Should -Match "exit 1"
    }
}

Describe "Update-All Script - Exit Code Propagation" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $Script:UpdateAllPs1 = Join-Path $RepoRoot "update-all.ps1"
    }

    It "Propagates exit code from bash script" {
        $content = Get-Content $Script:UpdateAllPs1 -Raw
        $content | Should -Match '\$exitCode.*=.*& bash'
        $content | Should -Match 'exit \$exitCode'
    }
}

Describe "Update-All Script - Argument Passing" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $Script:UpdateAllPs1 = Join-Path $RepoRoot "update-all.ps1"
    }

    It "Passes all arguments through to bash script" {
        $content = Get-Content $Script:UpdateAllPs1 -Raw
        $content | Should -Match '\$args'
    }

    It "Uses proper argument syntax for bash invocation" {
        $content = Get-Content $Script:UpdateAllPs1 -Raw
        # Verify bash is invoked
        $content | Should -Match 'bash'
        # Verify variable names are used
        $content | Should -Match '\$shScript'
        $content | Should -Match '\$args'
    }
}

Describe "Update-All Script - Source of Truth" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $Script:UpdateAllPs1 = Join-Path $RepoRoot "update-all.ps1"
        $Script:UpdateAllSh = Join-Path $RepoRoot "update-all.sh"
    }

    It "update-all.sh has significantly more lines than update-all.ps1" {
        $ps1Lines = (Get-Content $Script:UpdateAllPs1).Count
        $shLines = (Get-Content $Script:UpdateAllSh).Count
        $shLines | Should -BeGreaterThan ($ps1Lines * 2) "Because .sh is source of truth with all logic"
    }

    It "update-all.sh contains update logic" {
        $content = Get-Content $Script:UpdateAllSh -Raw
        $content | Should -Match "update|upgrade|install" "Should have update operations"
    }

    It "update-all.ps1 does NOT contain update functions" {
        $content = Get-Content $Script:UpdateAllPs1 -Raw
        $content | Should -Not -Match "function Update-" "Wrapper should not define update functions"
    }
}

Describe "Update-All Script - Documentation" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $Script:UpdateAllPs1 = Join-Path $RepoRoot "update-all.ps1"
    }

    It "Has comment header explaining wrapper purpose" {
        $content = Get-Content $Script:UpdateAllPs1 -Raw
        $content | Should -Match "# Update All Script Wrapper"
        $content | Should -Match "Invokes update-all\.sh via Git Bash"
    }

    It "Documents usage in header comment" {
        $content = Get-Content $Script:UpdateAllPs1 -Raw
        $content | Should -Match "Updates all package managers"
    }
}
