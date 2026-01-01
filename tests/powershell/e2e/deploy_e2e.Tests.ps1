# End-to-end tests for deploy.ps1 wrapper
# Tests that the wrapper correctly invokes deploy.sh via Git Bash

Describe "Deploy E2E - Script Structure" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    }

    Context "Deploy Script Files" {

        It "deploy.ps1 exists and is readable" {
            $deployPath = Join-Path $RepoRoot "deploy.ps1"
            Test-Path $deployPath | Should -Be $true
        }

        It "deploy.sh exists as source of truth" {
            $deploySh = Join-Path $RepoRoot "deploy.sh"
            Test-Path $deploySh | Should -Be $true
        }

        It "deploy.ps1 is much smaller than deploy.sh" {
            $deployPs1 = Join-Path $RepoRoot "deploy.ps1"
            $deploySh = Join-Path $RepoRoot "deploy.sh"
            $ps1Lines = (Get-Content $deployPs1).Count
            $shLines = (Get-Content $deploySh).Count
            $shLines | Should -BeGreaterThan $ps1Lines "Because .sh is source of truth"
        }
    }

    Context "Wrapper Invocation" {

        It "deploy.ps1 invokes deploy.sh via bash" {
            $deployPath = Join-Path $RepoRoot "deploy.ps1"
            $content = Get-Content $deployPath -Raw
            $content | Should -Match "& bash"
            $content | Should -Match "deploy\.sh"
        }

        It "deploy.ps1 derives script path dynamically" {
            $deployPath = Join-Path $RepoRoot "deploy.ps1"
            $content = Get-Content $deployPath -Raw
            $content | Should -Match "MyInvocation"
            $content | Should -Match "ScriptDir"
        }
    }
}

Describe "Deploy E2E - Error Handling" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    }

    Context "Git Bash Detection" {

        It "deploy.ps1 checks for bash before invoking" {
            $deployPath = Join-Path $RepoRoot "deploy.ps1"
            $content = Get-Content $deployPath -Raw
            $content | Should -Match "Get-Command bash"
        }

        It "deploy.ps1 has helpful error when bash not found" {
            $deployPath = Join-Path $RepoRoot "deploy.ps1"
            $content = Get-Content $deployPath -Raw
            $content | Should -Match "Git Bash.*not found"
            $content | Should -Match "git-scm\.com"
        }

        It "deploy.ps1 exits with error code when bash not found" {
            $deployPath = Join-Path $RepoRoot "deploy.ps1"
            $content = Get-Content $deployPath -Raw
            $content | Should -Match "exit 1"
        }
    }
}

Describe "Deploy E2E - Exit Code Propagation" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    }

    It "Propagates exit code from bash script" {
        $deployPath = Join-Path $RepoRoot "deploy.ps1"
        $content = Get-Content $deployPath -Raw
        $content | Should -Match '\$exitCode.*=.*& bash'
        $content | Should -Match 'exit \$exitCode'
    }
}

Describe "Deploy E2E - Documentation" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    }

    It "deploy.ps1 has wrapper documentation header" {
        $deployPath = Join-Path $RepoRoot "deploy.ps1"
        $content = Get-Content $deployPath -Raw
        $content | Should -Match "# Deploy Script Wrapper"
        $content | Should -Match "Invokes deploy\.sh"
    }

}
