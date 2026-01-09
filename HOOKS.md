# Universal Hooks

This directory contains cross-platform hooks for Git and Claude Code.

## Git Hooks

Auto-detect project type and run appropriate format/lint/check commands.

### Supported Languages
- Go (gofmt, goimports, golangci-lint, go vet)
- Rust (cargo fmt, clippy, cargo check)
- C/C++ (clang-format, clang-tidy, cppcheck)
- JavaScript/TypeScript (Prettier, ESLint, tsc/svelte-check)
- Python (ruff/black, isort, mypy)
- C# (dotnet format, dotnet build)
- Java (spotless, google-java-format, checkstyle)
- Scala (scalafmt, sbt compile)
- PHP (Laravel Pint, php-cs-fixer, PHPStan, Psalm)

### Files
- `pre-commit` - Bash version for Linux/macOS/Git Bash/WSL
- `pre-commit.ps1` - PowerShell version for Windows native
- `commit-msg` - Bash version for conventional commits enforcement
- `commit-msg.ps1` - PowerShell version for conventional commits enforcement

## Claude Code Hooks

### Files
- `quality-check.ps1` - Runs format/lint/check after file edits

### Hook Events
- `PostToolUse` - Runs after Write/Edit/MultiEdit operations
- Returns structured output showing pass/fail for each tool

## Installation

### Git Hooks

#### Linux/macOS/WSL
```bash
# Set global hooks directory
git config --global init.templatedir ~/.config/git/hooks
git config --global core.hooksPath ~/.config/git/hooks

# Copy hooks
mkdir -p ~/.config/git/hooks
cp hooks/git/pre-commit ~/.config/git/hooks/
cp hooks/git/commit-msg ~/.config/git/hooks/
chmod +x ~/.config/git/hooks/pre-commit
chmod +x ~/.config/git/hooks/commit-msg
```

#### Windows (PowerShell)
```powershell
# Set global hooks directory
git config --global init.templatedir $env:USERPROFILE\.config\git\hooks
git config --global core.hooksPath $env:USERPROFILE\.config\git\hooks

# Copy hooks
New-Item -ItemType Directory -Force -Path $env:USERPROFILE\.config\git\hooks
Copy-Item hooks/git/pre-commit.ps1 $env:USERPROFILE\.config\git\hooks\
Copy-Item hooks/git/commit-msg.ps1 $env:USERPROFILE\.config\git\hooks\
```

#### Git Configuration
Add to `~/.gitconfig` (Linux/macOS) or `%USERPROFILE%\.gitconfig` (Windows):
```ini
[init]
    defaultBranch = main
[core]
    hooksPath = ~/.config/git/hooks  # Linux/macOS
    # hooksPath = C:/Users/YourName/.config/git/hooks  # Windows
```

### Claude Code Hooks

#### Settings Configuration
Add to your Claude Code `settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "pwsh -NoProfile -ExecutionPolicy Bypass -File ~/.claude/quality-check.ps1"
          }
        ]
      }
    ]
  }
}
```

#### Copy Hook File
```bash
# Linux/macOS
mkdir -p ~/.claude
cp hooks/claude/quality-check.ps1 ~/.claude/

# Windows PowerShell
New-Item -ItemType Directory -Force -Path $env:USERPROFILE\.claude
Copy-Item hooks\claude\quality-check.ps1 $env:USERPROFILE\.claude\
```

## Usage

The hooks run automatically:
- **Git hooks**: Run before commits (pre-commit) and during commit message creation (commit-msg)
- **Claude Code hooks**: Run after file editing operations

### Bypassing Hooks
```bash
# Git
git commit --no-verify -m "message"

# Claude Code
# Temporarily disable in settings.json
```

## Platform Detection

The hooks auto-detect the operating system:
- **Linux**: Detected via `uname -s` returning "Linux"
- **macOS**: Detected via `uname -s` returning "Darwin"
- **Windows**: Detected via `uname -s` returning "MINGW*", "MSYS*", or "CYGWIN*"

## Troubleshooting

### Windows: Execution Policy
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Git Bash on Windows
The bash versions of hooks work in Git Bash without modification.

### WSL
The bash versions work in WSL without modification.

### Debug Mode
Set `VERBOSE=1` environment variable to see detailed output.
