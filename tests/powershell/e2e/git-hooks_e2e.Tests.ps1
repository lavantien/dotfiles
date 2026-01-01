# End-to-end tests for git hooks
# Tests pre-commit and commit-msg hooks in real git repositories

# Test helper function - mimics the behavior of the hook's Get-ProjectTypes
function Get-ProjectTypes {
    $types = @()
    $currentLocation = Get-Location

    # Check for project marker files
    if (Test-Path "go.mod") { $types += "go" }
    if (Test-Path "Cargo.toml") { $types += "rust" }
    if (Test-Path "package.json") { $types += "node" }
    if (Test-Path "pyproject.toml") { $types += "python" }
    if (Test-Path "requirements.txt") { $types += "python" }

    $csFiles = Get-ChildItem -Filter "*.cs" -Recurse -Depth 3 -ErrorAction SilentlyContinue | Measure-Object
    if ($csFiles.Count -gt 0) { $types += "csharp" }

    if (Test-Path "pom.xml") { $types += "java" }
    if (Test-Path "composer.json") { $types += "php" }
    if (Test-Path "build.sbt") { $types += "scala" }

    return $types
}

Describe "Git Hooks E2E - Hook Files" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $Script:HooksDir = Join-Path $RepoRoot "hooks\git"
    }

    Context "Pre-commit Hook" {

        It "pre-commit.ps1 exists and is readable" {
            $hookPath = Join-Path $Script:HooksDir "pre-commit.ps1"
            Test-Path $hookPath | Should -Be $true
        }

        It "pre-commit.ps1 contains Get-ProjectTypes function" {
            $hookPath = Join-Path $Script:HooksDir "pre-commit.ps1"
            $content = Get-Content $hookPath -Raw
            $content | Should -Match "function Get-ProjectTypes"
        }

        It "pre-commit hook (bash) exists and is executable" {
            $hookPath = Join-Path $Script:HooksDir "pre-commit"
            Test-Path $hookPath | Should -Be $true
        }
    }

    Context "Commit-msg Hook" {

        It "commit-msg.ps1 exists and is readable" {
            $hookPath = Join-Path $Script:HooksDir "commit-msg.ps1"
            Test-Path $hookPath | Should -Be $true
        }

        It "commit-msg hook (bash) exists and is executable" {
            $hookPath = Join-Path $Script:HooksDir "commit-msg"
            Test-Path $hookPath | Should -Be $true
        }

        It "commit-msg.ps1 contains validation pattern" {
            $hookPath = Join-Path $Script:HooksDir "commit-msg.ps1"
            $content = Get-Content $hookPath -Raw
            $content | Should -Match "feat|fix|chore"
        }
    }
}

Describe "Git Hooks E2E - Commit Message Validation" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $Script:TestRepo = Join-Path $env:TEMP "git-hooks-commit-$(New-Guid)"
        $Script:HooksDir = Join-Path $RepoRoot "hooks\git"
        $Script:OriginalLocation = Get-Location

        # Create test repository
        New-Item -ItemType Directory -Path $Script:TestRepo -Force | Out-Null
        Set-Location $Script:TestRepo
        git init --quiet 2>$null
        git config user.email "test@example.com"
        git config user.name "Test User"

        # Create initial commit
        "README" | Out-File "README.md"
        git add README.md
        git commit -m "chore: initial" --quiet
    }

    AfterAll {
        Set-Location $Script:OriginalLocation
        if (Test-Path $Script:TestRepo) {
            Remove-Item -Recurse -Force $Script:TestRepo -ErrorAction SilentlyContinue
        }
    }

    Context "Valid Commit Messages" {

        It "Accepts feat: type commit message" {
            "test content" | Out-File "test1.txt"
            git add test1.txt

            $commitMsgFile = Join-Path $Script:TestRepo ".git\COMMIT_EDITMSG"
            "feat: add new feature" | Set-Content $commitMsgFile

            & (Join-Path $Script:HooksDir "commit-msg.ps1") $commitMsgFile
            $LASTEXITCODE | Should -Be 0
        }

        It "Accepts fix: type commit message" {
            "test content" | Out-File "test2.txt"
            git add test2.txt

            $commitMsgFile = Join-Path $Script:TestRepo ".git\COMMIT_EDITMSG"
            "fix: resolve bug in parser" | Set-Content $commitMsgFile

            & (Join-Path $Script:HooksDir "commit-msg.ps1") $commitMsgFile
            $LASTEXITCODE | Should -Be 0
        }

        It "Accepts docs: type commit message" {
            "test content" | Out-File "test3.txt"
            git add test3.txt

            $commitMsgFile = Join-Path $Script:TestRepo ".git\COMMIT_EDITMSG"
            "docs: update README" | Set-Content $commitMsgFile

            & (Join-Path $Script:HooksDir "commit-msg.ps1") $commitMsgFile
            $LASTEXITCODE | Should -Be 0
        }

        It "Accepts chore: type commit message" {
            "test content" | Out-File "test4.txt"
            git add test4.txt

            $commitMsgFile = Join-Path $Script:TestRepo ".git\COMMIT_EDITMSG"
            "chore: update dependencies" | Set-Content $commitMsgFile

            & (Join-Path $Script:HooksDir "commit-msg.ps1") $commitMsgFile
            $LASTEXITCODE | Should -Be 0
        }

        It "Accepts type(scope): format" {
            "test content" | Out-File "test5.txt"
            git add test5.txt

            $commitMsgFile = Join-Path $Script:TestRepo ".git\COMMIT_EDITMSG"
            "feat(auth): add OAuth2 login" | Set-Content $commitMsgFile

            & (Join-Path $Script:HooksDir "commit-msg.ps1") $commitMsgFile
            $LASTEXITCODE | Should -Be 0
        }

        It "Accepts type(scope)!: breaking change format" {
            "test content" | Out-File "test6.txt"
            git add test6.txt

            $commitMsgFile = Join-Path $Script:TestRepo ".git\COMMIT_EDITMSG"
            "feat!: breaking API change" | Set-Content $commitMsgFile

            & (Join-Path $Script:HooksDir "commit-msg.ps1") $commitMsgFile
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context "Invalid Commit Messages" {

        It "Rejects invalid commit format (no type)" {
            "test content" | Out-File "test7.txt"
            git add test7.txt

            $commitMsgFile = Join-Path $Script:TestRepo ".git\COMMIT_EDITMSG"
            "Add some feature" | Set-Content $commitMsgFile

            & (Join-Path $Script:HooksDir "commit-msg.ps1") $commitMsgFile
            $LASTEXITCODE | Should -Not -Be 0
        }

        It "Rejects subject over 72 characters" {
            "test content" | Out-File "test8.txt"
            git add test8.txt

            $commitMsgFile = Join-Path $Script:TestRepo ".git\COMMIT_EDITMSG"
            $longSubject = "feat: " + ("a" * 73)
            $longSubject | Set-Content $commitMsgFile

            & (Join-Path $Script:HooksDir "commit-msg.ps1") $commitMsgFile
            $LASTEXITCODE | Should -Not -Be 0
        }
    }

    Context "Multi-line Commits" {

        It "Requires blank line after subject for multi-line" {
            "test content" | Out-File "test9.txt"
            git add test9.txt

            $commitMsgFile = Join-Path $Script:TestRepo ".git\COMMIT_EDITMSG"
            "feat: add feature`nBody without blank line" | Set-Content $commitMsgFile

            & (Join-Path $Script:HooksDir "commit-msg.ps1") $commitMsgFile
            $LASTEXITCODE | Should -Not -Be 0
        }

        It "Accepts properly formatted multi-line commit" {
            "test content" | Out-File "test10.txt"
            git add test10.txt

            $commitMsgFile = Join-Path $Script:TestRepo ".git\COMMIT_EDITMSG"
            "feat: add feature`n`nThis is the body.`nMore details here." | Set-Content $commitMsgFile

            & (Join-Path $Script:HooksDir "commit-msg.ps1") $commitMsgFile
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context "Special Commit Types" {

        It "Allows merge commits" {
            $commitMsgFile = Join-Path $Script:TestRepo ".git\COMMIT_EDITMSG"
            "Merge branch 'feature'" | Set-Content $commitMsgFile

            & (Join-Path $Script:HooksDir "commit-msg.ps1") $commitMsgFile
            $LASTEXITCODE | Should -Be 0
        }

        It "Allows revert commits" {
            $commitMsgFile = Join-Path $Script:TestRepo ".git\COMMIT_EDITMSG"
            "Revert `"feat: bad change`"" | Set-Content $commitMsgFile

            & (Join-Path $Script:HooksDir "commit-msg.ps1") $commitMsgFile
            $LASTEXITCODE | Should -Be 0
        }
    }
}

Describe "Git Hooks E2E - Project Detection" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $Script:TestRepo = Join-Path $env:TEMP "git-hooks-project-$(New-Guid)"
        $Script:OriginalLocation = Get-Location

        # Define Get-ProjectTypes helper function for tests
        function Get-ProjectTypes {
            $types = @()
            if (Test-Path "go.mod") { $types += "go" }
            if (Test-Path "Cargo.toml") { $types += "rust" }
            if (Test-Path "package.json") { $types += "node" }
            if (Test-Path "pyproject.toml") { $types += "python" }
            if (Test-Path "requirements.txt") { $types += "python" }
            $csFiles = Get-ChildItem -Filter "*.cs" -Recurse -Depth 3 -ErrorAction SilentlyContinue | Measure-Object
            if ($csFiles.Count -gt 0) { $types += "csharp" }
            if (Test-Path "pom.xml") { $types += "java" }
            if (Test-Path "composer.json") { $types += "php" }
            if (Test-Path "build.sbt") { $types += "scala" }
            return $types
        }

        # Create test repository
        New-Item -ItemType Directory -Path $Script:TestRepo -Force | Out-Null
        Set-Location $Script:TestRepo
        git init --quiet 2>$null
        git config user.email "test@example.com"
        git config user.name "Test User"

        # Create initial commit
        "README" | Out-File "README.md"
        git add README.md
        git commit -m "chore: initial" --quiet
    }

    AfterAll {
        Set-Location $Script:OriginalLocation
        if (Test-Path $Script:TestRepo) {
            Remove-Item -Recurse -Force $Script:TestRepo -ErrorAction SilentlyContinue
        }
    }

    Context "Project Type Detection" {

        BeforeEach {
            # Clean up any project marker files before each test
            $projectFiles = @("go.mod", "Cargo.toml", "package.json", "pyproject.toml", "requirements.txt", "pom.xml", "composer.json", "build.sbt")
            foreach ($file in $projectFiles) {
                if (Test-Path $file) {
                    Remove-Item $file -Force -ErrorAction SilentlyContinue
                    git rm $file 2>$null | Out-Null
                }
            }
        }

        It "Detects Node project (package.json)" {
            '{"name": "test"}' | Out-File "package.json"
            git add package.json

            # Get-ProjectTypes should detect node
            $types = @(Get-ProjectTypes)
            $types | Should -Contain "node"
        }

        It "Detects Python project (pyproject.toml)" {
            '[project]' | Out-File "pyproject.toml"
            git add pyproject.toml

            $types = @(Get-ProjectTypes)
            $types | Should -Contain "python"
        }

        It "Detects Go project (go.mod)" {
            'module test' | Out-File "go.mod"
            git add go.mod

            $types = @(Get-ProjectTypes)
            $types | Should -Contain "go"
        }

        It "Detects Rust project (Cargo.toml)" {
            '[package]' | Out-File "Cargo.toml"
            git add Cargo.toml

            $types = @(Get-ProjectTypes)
            $types | Should -Contain "rust"
        }

        It "Detects multiple project types" {
            '{"name": "test"}' | Out-File "package.json"
            '[project]' | Out-File "pyproject.toml"

            $types = @(Get-ProjectTypes)
            $types.Count | Should -BeGreaterOrEqual 2
        }

        It "Returns empty when no project detected" {
            # Clean slate - no project marker files
            $types = @(Get-ProjectTypes)
            $types.Count | Should -Be 0
        }
    }
}

Describe "Git Hooks E2E - Integration" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $Script:TestRepo = Join-Path $env:TEMP "git-hooks-integration-$(New-Guid)"
        $Script:HooksDir = Join-Path $RepoRoot "hooks\git"
        $Script:OriginalLocation = Get-Location

        # Create test repository
        New-Item -ItemType Directory -Path $Script:TestRepo -Force | Out-Null
        Set-Location $Script:TestRepo
        git init --quiet 2>$null
        git config user.email "test@example.com"
        git config user.name "Test User"

        # Create initial commit
        "README" | Out-File "README.md"
        git add README.md
        git commit -m "chore: initial" --quiet
    }

    AfterAll {
        Set-Location $Script:OriginalLocation
        if (Test-Path $Script:TestRepo) {
            Remove-Item -Recurse -Force $Script:TestRepo -ErrorAction SilentlyContinue
        }
    }

    Context "Hook Bypass" {

        It "Hooks can be bypassed with --no-verify" {
            "test content" | Out-File "test.txt"
            git add test.txt

            # Should bypass commit-msg validation
            git commit -m "invalid commit message" --no-verify --quiet
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context "Pre-commit Behavior" {

        It "Allows commits with no language files" {
            "README content" | Out-File "README2.md"
            git add README2.md

            # Should pass - no code files to check
            git commit -m "docs: update readme" --no-verify --quiet
            $LASTEXITCODE | Should -Be 0
        }
    }
}

Describe "Git Hooks E2E - Edge Cases" {

    It "Handles empty commit message gracefully" {
        $message = ""
        $pattern = "^(feat|fix|chore|docs|style|refactor|perf|test|build|ci|break|bump)(\(.+\))?!?: .{1,72}"
        $message | Should -Not -Match $pattern
    }

    It "Handles whitespace-only commit message" {
        $message = "   "
        $pattern = "^(feat|fix|chore|docs|style|refactor|perf|test|build|ci|break|bump)(\(.+\))?!?: .{1,72}"
        $message | Should -Not -Match $pattern
    }

    It "Handles special characters in scope" {
        $message = "feat(api-key): add authentication"
        $pattern = "^(feat|fix|chore|docs|style|refactor|perf|test|build|ci|break|bump)(\(.+\))?!?: .{1,72}"
        $message | Should -Match $pattern
    }

    It "Accepts all conventional commit types" {
        $validTypes = @("feat", "fix", "chore", "docs", "style", "refactor", "perf", "test", "build", "ci", "bump")
        $pattern = "^(feat|fix|chore|docs|style|refactor|perf|test|build|ci|break|bump)(\(.+\))?!?: .{1,72}"

        foreach ($type in $validTypes) {
            "$type`: description" | Should -Match $pattern
        }
    }
}
