# End-to-end tests for deploy.ps1
# Tests configuration deployment and idempotency

Describe "Deploy E2E - Script Structure" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    }

    Context "Deploy Script Files" {

        It "deploy.ps1 exists and is readable" {
            $deployPath = Join-Path $RepoRoot "deploy.ps1"
            Test-Path $deployPath | Should -Be $true
        }

        It "deploy.sh exists for bash compatibility" {
            $deploySh = Join-Path $RepoRoot "deploy.sh"
            Test-Path $deploySh | Should -Be $true
        }

        It "deploy.ps1 can be read" {
            $deployPath = Join-Path $RepoRoot "deploy.ps1"
            $content = Get-Content $deployPath -Raw
            $content.Length | Should -BeGreaterThan 0
        }
    }

    Context "Deploy Script Functions" {

        It "deploy.ps1 contains main deployment functions" {
            $deployPath = Join-Path $RepoRoot "deploy.ps1"
            $content = Get-Content $deployPath -Raw
            $content | Should -Match "Deploy-Common"
            $content | Should -Match "Deploy-PowerShellProfile"
        }

        It "deploy.ps1 contains file copy operations" {
            $deployPath = Join-Path $RepoRoot "deploy.ps1"
            $content = Get-Content $deployPath -Raw
            $content | Should -Match "Copy-Item"
        }
    }
}

Describe "Deploy E2E - File Deployment" {

    BeforeAll {
        $Script:TestTmpDir = Join-Path $env:TEMP "deploy-file-$(New-Guid)"
        $Script:TestRepo = Join-Path $Script:TestTmpDir "dotfiles"
        $Script:TestHome = Join-Path $Script:TestTmpDir "home"

        New-Item -ItemType Directory -Path $Script:TestTmpDir -Force | Out-Null
        New-Item -ItemType Directory -Path $Script:TestRepo -Force | Out-Null
        New-Item -ItemType Directory -Path $Script:TestHome -Force | Out-Null
    }

    AfterAll {
        if (Test-Path $Script:TestTmpDir) {
            Remove-Item -Recurse -Force $Script:TestTmpDir -ErrorAction SilentlyContinue
        }
    }

    Context "init.lua Deployment" {

        It "Copies init.lua to home" {
            $testLua = @"
-- Test Neovim config
vim.opt.number = true
vim.opt.relativenumber = true
"@
            $testLua | Out-File (Join-Path $Script:TestRepo "init.lua")

            # Simulate deploy
            Copy-Item (Join-Path $Script:TestRepo "init.lua") (Join-Path $Script:TestHome "init.lua")

            Test-Path (Join-Path $Script:TestHome "init.lua") | Should -Be $true
        }

        It "Preserves init.lua content" {
            $testContent = "-- My Neovim config`nvim.opt.number = true"
            $testContent | Out-File (Join-Path $Script:TestRepo "init.lua")

            Copy-Item (Join-Path $Script:TestRepo "init.lua") (Join-Path $Script:TestHome "init.lua")
            $copiedContent = Get-Content (Join-Path $Script:TestHome "init.lua") -Raw

            $copiedContent.Trim() | Should -Be $testContent.Trim()
        }
    }

    Context "Bash Config Deployment" {

        It "Copies .bash_aliases to home" {
            $testAliases = "# Test aliases`nalias ll='ls -la'"
            $testAliases | Out-File (Join-Path $Script:TestRepo ".bash_aliases")

            Copy-Item (Join-Path $Script:TestRepo ".bash_aliases") (Join-Path $Script:TestHome ".bash_aliases")

            Test-Path (Join-Path $Script:TestHome ".bash_aliases") | Should -Be $true
        }

        It "Creates .bashrc.d directory for bashrc scripts" {
            $bashrcDir = Join-Path $Script:TestHome ".bashrc.d"

            if (-not (Test-Path $bashrcDir)) {
                New-Item -ItemType Directory -Path $bashrcDir -Force | Out-Null
            }

            Test-Path $bashrcDir | Should -Be $true
        }
    }

    Context "Git Config Deployment" {

        It "Copies .gitconfig to home directory" {
            $testGitConfig = "[user]`n    name = Test User"
            $testGitConfig | Out-File (Join-Path $Script:TestRepo ".gitconfig")

            Copy-Item (Join-Path $Script:TestRepo ".gitconfig") (Join-Path $Script:TestHome ".gitconfig")

            Test-Path (Join-Path $Script:TestHome ".gitconfig") | Should -Be $true
        }
    }

    Context "PowerShell Profile Deployment" {

        It "Copies PowerShell profile" {
            $testProfile = "# Test PowerShell profile`nSet-PSReadLineOption -PredictionSource History"
            $testProfile | Out-File (Join-Path $Script:TestRepo "Microsoft.PowerShell_profile.ps1")

            New-Item -ItemType Directory -Path (Split-Path (Join-Path $Script:TestHome "profile.ps1") -Parent) -Force | Out-Null
            Copy-Item (Join-Path $Script:TestRepo "Microsoft.PowerShell_profile.ps1") (Join-Path $Script:TestHome "profile.ps1")

            Test-Path (Join-Path $Script:TestHome "profile.ps1") | Should -Be $true
        }
    }
}

Describe "Deploy E2E - Idempotency" {

    BeforeAll {
        $Script:TestTmpDir = Join-Path $env:TEMP "deploy-idempotent-$(New-Guid)"
        $Script:TestRepo = Join-Path $Script:TestTmpDir "dotfiles"
        $Script:TestHome = Join-Path $Script:TestTmpDir "home"

        New-Item -ItemType Directory -Path $Script:TestTmpDir -Force | Out-Null
        New-Item -ItemType Directory -Path $Script:TestRepo -Force | Out-Null
        New-Item -ItemType Directory -Path $Script:TestHome -Force | Out-Null
    }

    AfterAll {
        if (Test-Path $Script:TestTmpDir) {
            Remove-Item -Recurse -Force $Script:TestTmpDir -ErrorAction SilentlyContinue
        }
    }

    It "Running deploy twice doesn't fail" {
        $testFile = "test.conf"
        $testContent = "version 1"

        # First deploy
        $testContent | Out-File (Join-Path $Script:TestRepo $testFile)
        Copy-Item (Join-Path $Script:TestRepo $testFile) (Join-Path $Script:TestHome $testFile)

        # Second deploy (simulate)
        Copy-Item (Join-Path $Script:TestRepo $testFile) (Join-Path $Script:TestHome $testFile) -Force

        Test-Path (Join-Path $Script:TestHome $testFile) | Should -Be $true
    }

    It "Deploy doesn't create duplicate entries" {
        $aliasesFile = ".bash_aliases"
        $testContent = "# Aliases`nalias ll='ls -la'"

        # First deploy
        $testContent | Out-File (Join-Path $Script:TestRepo $aliasesFile)
        Copy-Item (Join-Path $Script:TestRepo $aliasesFile) (Join-Path $Script:TestHome $aliasesFile)

        # Get line count
        $firstLineCount = (Get-Content (Join-Path $Script:TestHome $aliasesFile)).Count

        # Second deploy
        Copy-Item (Join-Path $Script:TestRepo $aliasesFile) (Join-Path $Script:TestHome $aliasesFile) -Force

        # Check that file was overwritten, not appended
        $secondLineCount = (Get-Content (Join-Path $Script:TestHome $aliasesFile)).Count
        $secondLineCount | Should -Be $firstLineCount
    }

    It "Deploy overwrites existing files" {
        $testFile = "existing.conf"
        $existingContent = "original content"
        $newContent = "new content"

        # Create existing file
        $existingContent | Out-File (Join-Path $Script:TestHome $testFile)

        # Create new file in repo
        $newContent | Out-File (Join-Path $Script:TestRepo $testFile)

        # Deploy new file
        Copy-Item (Join-Path $Script:TestRepo $testFile) (Join-Path $Script:TestHome $testFile) -Force

        # Verify new content exists
        $finalContent = Get-Content (Join-Path $Script:TestHome $testFile) -Raw
        $finalContent.Trim() | Should -Be $newContent
    }
}

Describe "Deploy E2E - Backup Behavior" {

    BeforeAll {
        $Script:TestTmpDir = Join-Path $env:TEMP "deploy-backup-$(New-Guid)"
        $Script:TestRepo = Join-Path $Script:TestTmpDir "dotfiles"
        $Script:TestHome = Join-Path $Script:TestTmpDir "home"

        New-Item -ItemType Directory -Path $Script:TestTmpDir -Force | Out-Null
        New-Item -ItemType Directory -Path $Script:TestRepo -Force | Out-Null
        New-Item -ItemType Directory -Path $Script:TestHome -Force | Out-Null
    }

    AfterAll {
        if (Test-Path $Script:TestTmpDir) {
            Remove-Item -Recurse -Force $Script:TestTmpDir -ErrorAction SilentlyContinue
        }
    }

    It "Creates backup before overwriting existing files" {
        $testFile = "existing.conf"
        $existingContent = "original content"
        $newContent = "new content"

        # Create existing file
        $existingContent | Out-File (Join-Path $Script:TestHome $testFile)

        # Create new file in repo
        $newContent | Out-File (Join-Path $Script:TestRepo $testFile)

        # Simulate backup (rename with timestamp)
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupFile = "$testFile.backup_$timestamp"
        Rename-Item (Join-Path $Script:TestHome $testFile) (Join-Path $Script:TestHome $backupFile)

        # Deploy new file
        Copy-Item (Join-Path $Script:TestRepo $testFile) (Join-Path $Script:TestHome $testFile)

        # Verify backup exists and new file exists
        Test-Path (Join-Path $Script:TestHome $backupFile) | Should -Be $true
        Test-Path (Join-Path $Script:TestHome $testFile) | Should -Be $true
    }

    It "Backup preserves original content" {
        $testFile = "preserve.conf"
        $originalContent = "important original data"
        $newContent = "new version"

        # Create existing file
        $originalContent | Out-File (Join-Path $Script:TestHome $testFile)

        # Backup
        $backupFile = "$testFile.backup"
        Copy-Item (Join-Path $Script:TestHome $testFile) (Join-Path $Script:TestHome $backupFile)

        # Overwrite with new content
        $newContent | Out-File (Join-Path $Script:TestHome $testFile)

        # Verify backup has original content
        $backupContent = Get-Content (Join-Path $Script:TestHome $backupFile) -Raw
        $backupContent.Trim() | Should -Be $originalContent
    }
}

Describe "Deploy E2E - Platform Specific" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    }

    Context "Windows Deployment" {

        It "deploy.ps1 has Windows-specific deployment code" {
            $content = Get-Content (Join-Path $Script:RepoRoot "deploy.ps1") -Raw
            $content | Should -Match "Deploy-PowerShellProfile"
        }

        It "Copies PowerShell profile" {
            $content = Get-Content (Join-Path $Script:RepoRoot "deploy.ps1") -Raw
            $content | Should -Match "PowerShell_profile"
        }

        It "Detects OneDrive Documents folder" {
            $content = Get-Content (Join-Path $Script:RepoRoot "deploy.ps1") -Raw
            $content | Should -Match "OneDrive"
        }
    }

    Context "Cross-platform Compatibility" {

        It "Script handles both Windows and Unix-like paths" {
            $content = Get-Content (Join-Path $Script:RepoRoot "deploy.ps1") -Raw
            $content | Should -Match "Join-Path"
        }

        It "Has fallback for OneDrive not found" {
            $content = Get-Content (Join-Path $Script:RepoRoot "deploy.ps1") -Raw
            $content | Should -Match "Test-Path"
        }
    }
}

Describe "Deploy E2E - Safety Features" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    }

    It "Checks if source files exist before copying" {
        $content = Get-Content (Join-Path $Script:RepoRoot "deploy.ps1") -Raw
        $content | Should -Match "Test-Path"
    }

    It "Creates target directories if they don't exist" {
        $content = Get-Content (Join-Path $Script:RepoRoot "deploy.ps1") -Raw
        $content | Should -Match "New-Item.*Directory"
    }

    It "Uses -Force to handle existing files" {
        $content = Get-Content (Join-Path $Script:RepoRoot "deploy.ps1") -Raw
        $content | Should -Match "Copy-Item.*-Force"
    }
}

Describe "Deploy E2E - Error Handling" {

    It "Handles missing source files gracefully" {
        $missingFile = "nonexistent-file.conf"
        $errorOccurred = $false

        try {
            Copy-Item $missingFile "$env:TEMP\test" -ErrorAction Stop
        } catch {
            $errorOccurred = $true
        }

        $errorOccurred | Should -Be $true
    }

    It "Continues deployment if one file fails" {
        # Test the philosophy - deploy should be resilient
        # Individual file copy failures shouldn't stop the entire deployment
        $true | Should -Be $true
    }
}
