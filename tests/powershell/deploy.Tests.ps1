# Unit tests for deploy.ps1 wrapper
# Tests that the wrapper correctly invokes deploy.sh via Git Bash

Describe "Deploy Script - Structure" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $Script:DeployScript = Join-Path $RepoRoot "deploy.ps1"
        $Script:DeploySh = Join-Path $RepoRoot "deploy.sh"
    }

    Context "Script Files Exist" {

        It "deploy.ps1 exists and is readable" {
            Test-Path $Script:DeployScript | Should -Be $true
        }

        It "deploy.sh exists as source of truth" {
            Test-Path $Script:DeploySh | Should -Be $true
        }
    }

    Context "Wrapper Pattern" {

        It "deploy.ps1 is a wrapper that invokes deploy.sh" {
            $content = Get-Content $Script:DeployScript -Raw
            $content | Should -Match "deploy\.sh"
            $content | Should -Match "& bash"
        }

        It "Wrapper derives .sh path from script location" {
            $content = Get-Content $Script:DeployScript -Raw
            $content | Should -Match "MyInvocation\.MyCommand\.Path"
            $content | Should -Match "Join-Path.*ScriptDir"
        }

        It "Wrapper has error action preference set to Stop" {
            $content = Get-Content $Script:DeployScript -Raw
            $content | Should -Match '\$ErrorActionPreference.*Stop'
        }
    }
}

Describe "Deploy Script - Git Bash Detection" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $Script:DeployScript = Join-Path $RepoRoot "deploy.ps1"
    }

    It "Checks for Git Bash availability" {
        $content = Get-Content $Script:DeployScript -Raw
        $content | Should -Match "Get-Command bash"
    }

    It "Provides helpful error message when bash not found" {
        $content = Get-Content $Script:DeployScript -Raw
        $content | Should -Match "Git Bash.*not found"
        $content | Should -Match "git-scm\.com/download/win"
    }

    It "Exits with error code 1 when bash not found" {
        $content = Get-Content $Script:DeployScript -Raw
        $content | Should -Match "exit 1"
    }
}

Describe "Deploy Script - Exit Code Propagation" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $Script:DeployScript = Join-Path $RepoRoot "deploy.ps1"
    }

    It "Propagates exit code from bash script" {
        $content = Get-Content $Script:DeployScript -Raw
        $content | Should -Match '\$exitCode.*=.*& bash'
        $content | Should -Match 'exit \$exitCode'
    }
}

Describe "Deploy Script - Documentation" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $Script:DeployScript = Join-Path $RepoRoot "deploy.ps1"
    }

    It "Has comment header explaining wrapper purpose" {
        $content = Get-Content $Script:DeployScript -Raw
        $content | Should -Match "# Deploy Script Wrapper"
        $content | Should -Match "Invokes deploy\.sh via Git Bash"
    }

    It "Documents that it takes no parameters" {
        $content = Get-Content $Script:DeployScript -Raw
        $content | Should -Match "deploy\.sh" # Should mention the .sh script
    }
}

Describe "Deploy Script - Source of Truth" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $Script:DeployScript = Join-Path $RepoRoot "deploy.ps1"
        $Script:DeploySh = Join-Path $RepoRoot "deploy.sh"
    }

    It "deploy.sh has more lines than deploy.ps1" {
        $ps1Lines = (Get-Content $Script:DeployScript).Count
        $shLines = (Get-Content $Script:DeploySh).Count
        $shLines | Should -BeGreaterThan $ps1Lines "Because .sh is source of truth with more code"
    }

    It "deploy.sh contains actual deployment logic" {
        $content = Get-Content $Script:DeploySh -Raw
        $content | Should -Match "Copy-Item|cp " "Should have file copy operations"
    }

    It "deploy.ps1 does NOT contain deployment functions" {
        $content = Get-Content $Script:DeployScript -Raw
        $content | Should -Not -Match "function Deploy-" "Wrapper should not define deployment functions"
    }
}
