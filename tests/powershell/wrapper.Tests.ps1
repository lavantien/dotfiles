# Wrapper Tests - Verifies .ps1 scripts correctly invoke their .sh counterparts
# These tests verify the wrapper layer works, not the actual script functionality
# (which is tested by BATS tests for the .sh scripts)

Describe "Wrapper Script - Basic Structure" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $wrapperScripts = @(
            @{ Name = "backup"; Ps1 = "backup.ps1"; Sh = "backup.sh" }
            @{ Name = "restore"; Ps1 = "restore.ps1"; Sh = "restore.sh" }
            @{ Name = "deploy"; Ps1 = "deploy.ps1"; Sh = "deploy.sh" }
            @{ Name = "healthcheck"; Ps1 = "healthcheck.ps1"; Sh = "healthcheck.sh" }
            @{ Name = "uninstall"; Ps1 = "uninstall.ps1"; Sh = "uninstall.sh" }
            @{ Name = "update-all"; Ps1 = "update-all.ps1"; Sh = "update-all.sh" }
            @{ Name = "sync-system-instructions"; Ps1 = "sync-system-instructions.ps1"; Sh = "sync-system-instructions.sh" }
            @{ Name = "git-update-repos"; Ps1 = "git-update-repos.ps1"; Sh = "git-update-repos.sh" }
        )
    }

    Context "Wrapper Files Exist" {

        It "Both .ps1 and .sh files exist for each script" {
            foreach ($script in $wrapperScripts) {
                $ps1Path = Join-Path $Script:RepoRoot $script.Ps1
                $shPath = Join-Path $Script:RepoRoot $script.Sh

                Test-Path $ps1Path | Should -Be $true "Because $($script.Name).ps1 should exist"
                Test-Path $shPath | Should -Be $true "Because $($script.Name).sh should exist"
            }
        }
    }
}

Describe "Wrapper Script - Git Bash Detection" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    }

    Context "Bash Availability Check" {

        It "Git Bash (bash.exe) is available on Windows" {
            # On Windows, Git Bash should be available via Git for Windows
            $bashCmd = Get-Command bash -ErrorAction SilentlyContinue
            $bashCmd | Should -Not -Be $null
            if ($bashCmd) {
                $bashCmd.Source | Should -Match "bash"
            }
        }

        It "Wrapper script has helpful error when bash is missing" {
            # All wrappers should have a helpful error message
            $wrapperContent = Get-Content (Join-Path $Script:RepoRoot "deploy.ps1") -Raw
            $wrapperContent | Should -Match "Git Bash.*not found"
            $wrapperContent | Should -Match "git-scm\.com"
        }
    }

    Context "Error Action Preference" {

        It "Wrapper scripts set ErrorActionPreference to Stop" {
            $wrapperScripts = @(
                "backup/backup.ps1",
                "restore/restore.ps1",
                "deploy.ps1",
                "healthcheck/healthcheck.ps1",
                "uninstall/uninstall.ps1",
                "update-all/update-all.ps1",
                "sync-system-instructions/sync-system-instructions.ps1",
                "git-update-repos/git-update-repos.ps1"
            )

            foreach ($script in $wrapperScripts) {
                $path = Join-Path $Script:RepoRoot $script
                if (Test-Path $path) {
                    $content = Get-Content $path -Raw
                    $content | Should -Match '\$ErrorActionPreference.*Stop' "Because $script should stop on errors"
                }
            }
        }
    }
}

Describe "Wrapper Script - Invocation Pattern" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    }

    Context "Bash Invocation" {

        It "Wrapper invokes .sh script via bash" {
            $wrapperContent = Get-Content (Join-Path $Script:RepoRoot "deploy.ps1") -Raw
            $wrapperContent | Should -Match '& bash'
            $wrapperContent | Should -Match '\.sh'
        }

        It "Wrapper derives .sh path from .ps1 location" {
            $wrapperContent = Get-Content (Join-Path $Script:RepoRoot "deploy.ps1") -Raw
            $wrapperContent | Should -Match "Split-Path"
            $wrapperContent | Should -Match "MyInvocation"
            $wrapperContent | Should -Match "Join-Path"
            $wrapperContent | Should -Match '\.sh'
        }
    }

    Context "Exit Code Propagation" {

        It "Wrapper propagates exit code from bash script" {
            $wrapperContent = Get-Content (Join-Path $Script:RepoRoot "deploy.ps1") -Raw
            $wrapperContent | Should -Match "exit.*\$"
        }
    }
}

Describe "Wrapper Script - Parameter Mapping" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    }

    Context "Common Parameter Mappings" {

        It "backup.ps1 maps -DryRun to --dry-run" {
            $content = Get-Content (Join-Path $Script:RepoRoot "backup.ps1") -Raw
            $content | Should -Match '-DryRun'
            $content | Should -Match '--dry-run'
        }

        It "backup.ps1 maps -Keep to --keep" {
            $content = Get-Content (Join-Path $Script:RepoRoot "backup.ps1") -Raw
            $content | Should -Match '-Keep'
            $content | Should -Match '--keep'
        }

        It "restore.ps1 maps -DryRun to --dry-run" {
            $content = Get-Content (Join-Path $Script:RepoRoot "restore.ps1") -Raw
            $content | Should -Match '-DryRun'
            $content | Should -Match '--dry-run'
        }

        It "uninstall.ps1 maps -DryRun to --dry-run" {
            $content = Get-Content (Join-Path $Script:RepoRoot "uninstall.ps1") -Raw
            $content | Should -Match '-DryRun'
            $content | Should -Match '--dry-run'
        }

        It "git-update-repos.ps1 maps -Username to --username" {
            $content = Get-Content (Join-Path $Script:RepoRoot "git-update-repos.ps1") -Raw
            $content | Should -Match '-Username'
            $content | Should -Match '--username'
        }

        It "git-update-repos.ps1 maps -Commit to --commit" {
            $content = Get-Content (Join-Path $Script:RepoRoot "git-update-repos.ps1") -Raw
            $content | Should -Match '-Commit'
            $content | Should -Match '--commit'
        }

        It "sync-system-instructions.ps1 maps -Commit to --commit" {
            $content = Get-Content (Join-Path $Script:RepoRoot "sync-system-instructions.ps1") -Raw
            $content | Should -Match '-Commit'
            $content | Should -Match '--commit'
        }

        It "sync-system-instructions.ps1 maps -Push to --push" {
            $content = Get-Content (Join-Path $Script:RepoRoot "sync-system-instructions.ps1") -Raw
            $content | Should -Match '-Push'
            $content | Should -Match '--push'
        }
    }
}

Describe "Wrapper Script - Documentation" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    }

    It "Wrapper has usage comment header" {
        $wrapperContent = Get-Content (Join-Path $Script:RepoRoot "deploy.ps1") -Raw
        $wrapperContent | Should -Match "#.*Wrapper.*Invokes.*via Git Bash"
    }

    It "backup.ps1 documents parameters" {
        $wrapperContent = Get-Content (Join-Path $Script:RepoRoot "backup.ps1") -Raw
        $wrapperContent | Should -Match "Usage:"
    }
}
