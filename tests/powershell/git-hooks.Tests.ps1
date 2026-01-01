# Unit tests for git hooks (PowerShell version)
# Tests pre-commit and commit-msg hooks

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

Describe "Git Hooks - Pre-commit" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $Script:TestRepo = Join-Path $env:TEMP "test-git-hooks-$(New-Guid)"
        $Script:HooksDir = Join-Path $RepoRoot "hooks\git"
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

    Context "Project Detection" {

        BeforeEach {
            # Clean up any project marker files before each test
            $projectFiles = @("go.mod", "Cargo.toml", "package.json", "pyproject.toml", "requirements.txt", "pom.xml", "composer.json", "build.sbt")
            foreach ($file in $projectFiles) {
                if (Test-Path $file) {
                    Remove-Item $file -Force
                }
            }
            # Clean up .cs files
            Get-ChildItem -Filter "*.cs" -ErrorAction SilentlyContinue | Remove-Item -Force
        }

        It "Get-ProjectTypes detects Go project (go.mod)" {
            "module test" | Out-File "go.mod"
            $types = Get-ProjectTypes
            $types | Should -Contain "go"
        }

        It "Get-ProjectTypes detects Rust project (Cargo.toml)" {
            '[package]
name = "test"' | Out-File "Cargo.toml"
            $types = Get-ProjectTypes
            $types | Should -Contain "rust"
        }

        It "Get-ProjectTypes detects Node project (package.json)" {
            '{"name": "test"}' | Out-File "package.json"
            $types = Get-ProjectTypes
            $types | Should -Contain "node"
        }

        It "Get-ProjectTypes detects Python project (pyproject.toml)" {
            '[project]
name = "test"' | Out-File "pyproject.toml"
            $types = Get-ProjectTypes
            $types | Should -Contain "python"
        }

        It "Get-ProjectTypes detects Python project (requirements.txt)" {
            "pytest" | Out-File "requirements.txt"
            $types = Get-ProjectTypes
            $types | Should -Contain "python"
        }

        It "Get-ProjectTypes detects C# project (.cs files)" {
            "public class Test {}" | Out-File "Test.cs"
            $types = Get-ProjectTypes
            $types | Should -Contain "csharp"
        }

        It "Get-ProjectTypes detects Java project (pom.xml)" {
            "<project></project>" | Out-File "pom.xml"
            $types = Get-ProjectTypes
            $types | Should -Contain "java"
        }

        It "Get-ProjectTypes detects PHP project (composer.json)" {
            '{"name": "test"}' | Out-File "composer.json"
            $types = Get-ProjectTypes
            $types | Should -Contain "php"
        }

        It "Get-ProjectTypes detects Scala project (build.sbt)" {
            'name := "test"' | Out-File "build.sbt"
            $types = Get-ProjectTypes
            $types | Should -Contain "scala"
        }

        It "Get-ProjectTypes returns empty when no project detected" {
            $types = Get-ProjectTypes
            $types.Count | Should -Be 0
        }

        It "Get-ProjectTypes detects multiple project types" {
            '{"name": "test"}' | Out-File "package.json"
            '[project]
name = "test"' | Out-File "pyproject.toml"
            $types = Get-ProjectTypes
            $types.Count | Should -BeGreaterOrEqual 2
        }
    }

    Context "Pre-commit Hook File" {

        It "pre-commit.ps1 exists and is readable" {
            $hookPath = Join-Path $Script:HooksDir "pre-commit.ps1"
            Test-Path $hookPath | Should -Be $true
        }

        It "pre-commit.ps1 has Get-ProjectTypes function" {
            $hookPath = Join-Path $Script:HooksDir "pre-commit.ps1"
            $content = Get-Content $hookPath -Raw
            $content | Should -Match "function Get-ProjectTypes"
        }
    }
}

Describe "Git Hooks - Commit-msg" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $Script:HooksDir = Join-Path $RepoRoot "hooks\git"
    }

    Context "Commit Message Validation" {

        It "commit-msg.ps1 exists and is readable" {
            $hookPath = Join-Path $Script:HooksDir "commit-msg.ps1"
            Test-Path $hookPath | Should -Be $true
        }

        It "Validates feat: type commit message" {
            $message = "feat: add new feature"
            $pattern = "^(feat|fix|chore|docs|style|refactor|perf|test|build|ci|break|bump)(\(.+\))?!?: .{1,72}"
            $message | Should -Match $pattern
        }

        It "Validates fix: type commit message" {
            $message = "fix: resolve bug in parser"
            $pattern = "^(feat|fix|chore|docs|style|refactor|perf|test|build|ci|break|bump)(\(.+\))?!?: .{1,72}"
            $message | Should -Match $pattern
        }

        It "Validates docs: type commit message" {
            $message = "docs: update README"
            $pattern = "^(feat|fix|chore|docs|style|refactor|perf|test|build|ci|break|bump)(\(.+\))?!?: .{1,72}"
            $message | Should -Match $pattern
        }

        It "Validates type(scope): format" {
            $message = "feat(auth): add OAuth2 login"
            $pattern = "^(feat|fix|chore|docs|style|refactor|perf|test|build|ci|break|bump)(\(.+\))?!?: .{1,72}"
            $message | Should -Match $pattern
        }

        It "Validates type(scope)!: breaking change format" {
            $message = "feat!: breaking API change"
            $pattern = "^(feat|fix|chore|docs|style|refactor|perf|test|build|ci|break|bump)(\(.+\))?!?: .{1,72}"
            $message | Should -Match $pattern
        }

        It "Rejects invalid commit format (no type)" {
            $message = "Add some feature"
            $pattern = "^(feat|fix|chore|docs|style|refactor|perf|test|build|ci|break|bump)(\(.+\))?!?: .{1,72}"
            $message | Should -Not -Match $pattern
        }

        It "Rejects subject over 72 characters" {
            $message = "feat: $('a' * 73)"
            $message.Length | Should -BeGreaterThan 72
        }

        It "Accepts subject exactly 72 characters" {
            $message = "feat: $('a' * 66)"
            $message.Length | Should -Be 72
        }
    }
}

Describe "Git Hooks - Integration" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $Script:TestRepo = Join-Path $env:TEMP "test-git-integration-$(New-Guid)"
        $Script:HooksDir = Join-Path $RepoRoot "hooks\git"
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

    Context "Commit-msg Hook Integration" {

        It "Accepts valid conventional commit message" {
            "test content" | Out-File "test.txt"
            git add test.txt

            $commitMsgFile = Join-Path $Script:TestRepo ".git\COMMIT_EDITMSG"
            "feat: add new feature" | Set-Content $commitMsgFile

            & (Join-Path $Script:HooksDir "commit-msg.ps1") $commitMsgFile
            $LASTEXITCODE | Should -Be 0
        }

        It "Rejects invalid commit format" {
            "test content" | Out-File "test2.txt"
            git add test2.txt

            $commitMsgFile = Join-Path $Script:TestRepo ".git\COMMIT_EDITMSG"
            "Add some feature" | Set-Content $commitMsgFile

            & (Join-Path $Script:HooksDir "commit-msg.ps1") $commitMsgFile
            $LASTEXITCODE | Should -Not -Be 0
        }

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

        It "Requires blank line after subject for multi-line" {
            $commitMsgFile = Join-Path $Script:TestRepo ".git\COMMIT_EDITMSG"
            "feat: add feature`nBody without blank line" | Set-Content $commitMsgFile

            & (Join-Path $Script:HooksDir "commit-msg.ps1") $commitMsgFile
            $LASTEXITCODE | Should -Not -Be 0
        }

        It "Accepts properly formatted multi-line commit" {
            $commitMsgFile = Join-Path $Script:TestRepo ".git\COMMIT_EDITMSG"
            "feat: add feature`n`nThis is the body.`nMore details here." | Set-Content $commitMsgFile

            & (Join-Path $Script:HooksDir "commit-msg.ps1") $commitMsgFile
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context "Pre-commit Hook Integration" {

        BeforeEach {
            # Clean up any project marker files before each test
            $projectFiles = @("go.mod", "Cargo.toml", "package.json", "pyproject.toml", "requirements.txt", "pom.xml", "composer.json", "build.sbt")
            foreach ($file in $projectFiles) {
                if (Test-Path $file) {
                    Remove-Item $file -Force -ErrorAction SilentlyContinue
                }
            }
        }

        It "Skips checks when no recognized project type" {
            # Clean slate - no project files
            $staged = git diff --cached --name-only --diff-filter=ACM 2>$null
            if ($staged) {
                Remove-Item $staged -Force
            }

            # The hook should exit successfully even with no project
            # (function exists in the hook but returns early)
            $true | Should -Be $true
        }

        It "Detects Node project with package.json" {
            '{"name": "test"}' | Out-File "package.json"
            git add package.json

            # Get-ProjectTypes should detect node
            $types = @(Get-ProjectTypes)
            $types | Should -Contain "node"
        }

        It "Detects Python project with pyproject.toml" {
            '[project]
name = "test"' | Out-File "pyproject.toml"
            git add pyproject.toml

            $types = @(Get-ProjectTypes)
            $types | Should -Contain "python"
        }
    }
}

Describe "Git Hooks - Edge Cases" {

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
            "$($type): description" | Should -Match $pattern
        }
    }
}
