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
            $wrapperContent | Should -Match "ScriptDir"
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

Describe "Wrapper Script - Regression Tests" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $bashWrappers = @(
            "backup.ps1",
            "restore.ps1",
            "deploy.ps1",
            "healthcheck.ps1",
            "uninstall.ps1",
            "update-all.ps1",
            "sync-system-instructions.ps1",
            "git-update-repos.ps1"
        )
    }

    Context "bootstrap.ps1 Platform Detection" {

        It "bootstrap.ps1 calls Windows-native bootstrap first" {
            $content = Get-Content (Join-Path $Script:RepoRoot "bootstrap.ps1") -Raw
            # Should check for bootstrap/bootstrap.ps1
            $content | Should -Match 'bootstrap\\bootstrap\.ps1'
            # Should have a variable name like windowsBootstrap
            $content | Should -Match 'windowsBootstrap|windowsBootstrap'
            # Should invoke it with splatting if found
            $content | Should -Match '&.*windowsBootstrap|& \$windowsBootstrap'
        }

        It "bootstrap.ps1 has parameter hashtable for Windows bootstrap" {
            $content = Get-Content (Join-Path $Script:RepoRoot "bootstrap.ps1") -Raw
            # Should build splattable parameters hashtable
            $content | Should -Match '\$params\s*=\s*@\{\}'
            # Should use splatting (@params) not string concatenation
            $content | Should -Match '@params'
        }

        It "bootstrap.ps1 only falls back to bash if Windows bootstrap missing" {
            $content = Get-Content (Join-Path $Script:RepoRoot "bootstrap.ps1") -Raw
            # Should have Test-Path check before invoking Windows bootstrap
            $content | Should -Match 'Test-Path.*windowsBootstrap'
            # The bash fallback should come after the Windows bootstrap check
            $windowsBootstrapPos = $content.IndexOf('bootstrap\\bootstrap.ps1')
            $bashFallbackPos = $content.IndexOf('./bootstrap.sh')
            $bashFallbackPos | Should -BeGreaterThan $windowsBootstrapPos "Because bash fallback should come after Windows bootstrap check"
        }
    }

    Context "Login Shell Usage" {

        It "Wrapper uses login shell (-l flag) for proper PATH setup" {
            foreach ($script in $bashWrappers) {
                $content = Get-Content (Join-Path $Script:RepoRoot $script) -Raw
                $content | Should -Match '-l.*"-c"|"-l".*"-c"' "Because $script should use login shell for proper Git Bash environment"
            }
        }

        It "Wrapper does NOT use absolute paths to invoke bash scripts" {
            foreach ($script in $bashWrappers) {
                $content = Get-Content (Join-Path $Script:RepoRoot $script) -Raw
                # Should NOT use patterns like: bash /c/Users/.../script.sh
                # Should use relative paths like: ./script.sh
                $content | Should -Match '\./[\w-]+\.sh' "Because $script should use relative path to avoid conversion issues"
            }
        }

        It "Wrapper changes directory before invoking bash" {
            foreach ($script in $bashWrappers) {
                $content = Get-Content (Join-Path $Script:RepoRoot $script) -Raw
                # Should Set-Location to script directory
                $content | Should -Match 'Set-Location.*ScriptDir|cd.*ScriptDir'
                # Should have try/finally to restore location
                $content | Should -Match 'finally'
                $content | Should -Match 'Set-Location.*origLocation'
            }
        }
    }

    Context "Array Splatting" {

        It "Wrapper uses @ for splatting bash args, not $" {
            foreach ($script in $bashWrappers) {
                $content = Get-Content (Join-Path $Script:RepoRoot $script) -Raw
                # Should use & bash @bashArgs, not & bash $bashArgs
                $content | Should -Match '& bash @bashArgs|& bash @\$bashArgs' "Because $script should use @ for array splatting"
            }
        }

        It "Wrapper does not incorrectly pass args with $ prefix" {
            foreach ($script in $bashWrappers) {
                $content = Get-Content (Join-Path $Script:RepoRoot $script) -Raw
                # Should NOT contain patterns like & bash $bashArgs (wrong splatting)
                $content | Should -Not -Match '& bash \$\w+\s*$' "Because $script should not use $var for array splatting (line end)"
                # Note: We allow @bashArgs patterns
            }
        }
    }

    Context "Path Construction" {

        It "Wrapper constructs bash args array with -c flag" {
            foreach ($script in $bashWrappers) {
                $content = Get-Content (Join-Path $Script:RepoRoot $script) -Raw
                # Should build args array with -l and -c flags
                $content | Should -Match '\$bashArgs|@bashArgs'
                $content | Should -Match '"-c"'
            }
        }

        It "Wrapper uses relative script path in -c command string" {
            foreach ($script in $bashWrappers) {
                $content = Get-Content (Join-Path $Script:RepoRoot $script) -Raw
                # The -c command should use ./script.sh, not absolute path
                $content | Should -Match '\./[\w-]+\.sh\s*\$argList|"\./[\w-]+\.sh'
            }
        }
    }

    Context "Exit Code Handling" {

        It "Wrapper captures LASTEXITCODE from bash invocation" {
            foreach ($script in $bashWrappers) {
                $content = Get-Content (Join-Path $Script:RepoRoot $script) -Raw
                $content | Should -Match '\$exitCode\s*=\s*\$LASTEXITCODE|\$LASTEXITCODE'
            }
        }

        It "Wrapper exits with captured exit code" {
            foreach ($script in $bashWrappers) {
                $content = Get-Content (Join-Path $Script:RepoRoot $script) -Raw
                $content | Should -Match 'exit\s+\$exitCode'
            }
        }
    }
}
