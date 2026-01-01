# Universal Dotfiles

![Coverage](https://img.shields.io/badge/coverage-20%25-red) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-blue)](https://github.com/lavantien/dotfiles)

Production-grade dotfiles supporting Windows 11, Linux (Ubuntu/Fedora/Arch), and macOS with intelligent auto-detection and graceful fallbacks. A truly Universal SWE Dotfiles (Neovim/WezTerm/zsh/pwsh, Claude Code/Git Hooks, Linux/Windows) with batteries included: 15+ LSP servers, 10+ language formatters/linters, TDD enforcement, and comprehensive Git and Claude Code workflow automation. All configured, tested, and just clone and run.

---

## Table of Contents

- [1. Architecture Note](#1-architecture-note)
- [2. Core Features](#2-core-features)
- [3. Idempotency Note](#3-idempotency-note)
- [4. Quick Start](#4-quick-start)
- [5. Bridge Approach Note](#5-bridge-approach-note)
- [6. Bootstrap Options](#6-bootstrap-options)
- [7. Configuration (Optional)](#7-configuration-optional)
- [8. Git Hooks](#8-git-hooks)
- [9. Claude Code Integration](#9-claude-code-integration)
- [10. Universal Update All](#10-universal-update-all)
- [11. System Instructions Sync](#11-system-instructions-sync)
- [12. Health Check & Troubleshooting](#12-health-check--troubleshooting)
- [13. Testing](#13-testing)
- [14. Code Coverage](#14-code-coverage)
- [15. Updating](#15-updating)
- [16. Shell Aliases](#16-shell-aliases)
- [17. Neovim Keybindings](#17-neovim-keybindings)
- [18. Additional Documentation](#18-additional-documentation)

---

## 1. Architecture Note

**.sh scripts are the single source of truth.** All core logic lives in bash scripts (*.sh).

**.ps1 scripts are thin compatibility wrappers.** On Windows, PowerShell scripts invoke their .sh counterparts via Git Bash, providing a native Windows experience while maintaining a single implementation.

```
┌─────────────────────────────────────────────────────────────┐
│                    Windows (PowerShell)                     │
├─────────────────────────────────────────────────────────────┤
│  script.ps1  ──►  bash script.sh  ──►  Core Logic           │
│  (wrapper)        (Git Bash)          (source of truth)     │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    Linux / macOS                            │
├─────────────────────────────────────────────────────────────┤
│  ./script.sh  ──►  Core Logic                               │
│  (direct)          (source of truth)                        │
└─────────────────────────────────────────────────────────────┘
```

**Benefits:**
- Single implementation to maintain and test
- .sh scripts work natively on Linux/macOS and via Git Bash on Windows
- .ps1 wrappers provide Windows convenience with familiar parameter names
- All features develop in .sh first, then automatically available on Windows

**Git Installation:**
On Windows, Git (including Git Bash) is automatically installed via winget during bootstrap. No manual installation required.

---

## 2. Core Features

Cross-Platform Support
- Windows 11: Native PowerShell 7+ support
- Linux: Ubuntu, Fedora, Arch, openSUSE
- macOS: Intel and Apple Silicon

Intelligent Automation
- Auto-detection: Detects platform, tools, and project types automatically
- Graceful fallbacks: Works even when some tools are not installed
- OneDrive-aware: Handles synced Documents folders on Windows
- Always latest: Bootstrap installs/updates all tools to latest versions

---

### What Gets Installed

**Package Managers**
- Windows: Scoop (CLI tools), winget (heavy apps like Visual Studio, LLVM)
- Linux: System (apt/dnf/pacman/zypper), Homebrew (optional)
- macOS: Homebrew (primary)

**C/C++ Toolchain**
- Windows: Visual Studio Community (latest), LLVM (latest)
- Linux: GCC (latest), LLVM/Clang (latest)
- macOS: LLVM/Clang (latest)

**Core SDKs** (always latest)
- Node.js LTS
- Python 3.x
- Go
- Rust (via rustup)
- dotnet LTS
- OpenJDK LTS

**Language Servers** (Neovim LSP + Claude Code - 15 servers)
- clangd (C/C++)
- csharp-ls (C#)
- docker-language-server (Dockerfile)
- docker-compose-language-server (Docker Compose)
- gopls (Go)
- intelephense (PHP)
- jdtls (Java)
- lua-language-server (Lua)
- pyright (Python)
- rust-analyzer (Rust)
- tinymist (Typst)
- tombi (TOML)
- ts_ls (JavaScript/TypeScript)
- yaml-language-server (YAML)
- dartls (Dart - optional, requires Dart SDK)

**Linters & Formatters** (for Git Hooks + Claude Code)
- JS/TS: prettier, eslint, tsc
- Python: ruff, black, isort, mypy
- Go: goimports, go fmt, golangci-lint, go vet
- Rust: cargo fmt, clippy, cargo check
- C/C++: clang-format, clang-tidy, cppcheck
- C#: dotnet format, dotnet build
- Java: spotless, google-java-format, checkstyle
- Bash: shellcheck, shfmt
- PHP: Laravel Pint, php-cs-fixer, PHPStan, Psalm
- Scala: scalafmt

**Essential CLI Tools**
- fzf - Fuzzy finder
- zoxide - Smart cd navigation
- bat - Better cat
- eza - Better ls
- lazygit - Terminal Git UI
- gh - GitHub CLI
- ripgrep (rg) - Fast grep
- fd - Fast find
- tokei - Code stats (full category)
- difftastic - Structured diff (full category)

**Testing & Coverage**
- bats - Bash testing
- Pester - PowerShell testing with coverage
- bashcov - Bash coverage reports (universal, Ruby gem)

---

### Installation Categories

| Category | What's Installed | Use Case |
|----------|------------------|----------|
| minimal | Package managers, git, CLI tools only | Quick setup |
| sdk | minimal + Node.js, Python, Go, Rust, dotnet, JDK | No LSPs |
| full | sdk + all LSPs + linters/formatters | Complete environment (default) |

---

### Quality Assurance

- 270+ automated tests covering all major components
- Conventional commits enforcement
- Claude Code hooks for real-time quality checks
- TDD guard to enforce test-driven development
- Auto-formats and lints on commit for 15+ languages
- 15+ LSP servers configured in Neovim for IDE-like experience

---

## 3. Idempotency Note

All scripts in this repository are idempotent. They intelligently detect what's already installed, compare versions, and only install or update tools that are missing or outdated. You can safely run any script multiple times without any harm.

This applies to all core scripts (.sh is source of truth, .ps1 is wrapper):
- bootstrap.sh / bootstrap.ps1
- deploy.sh / deploy.ps1
- update-all.sh / update-all.ps1
- git-update-repos.sh / git-update-repos.ps1
- sync-system-instructions.sh / sync-system-instructions.ps1
- backup.sh / backup.ps1
- restore.sh / restore.ps1
- healthcheck.sh / healthcheck.ps1
- uninstall.sh / uninstall.ps1

---

## 4. Quick Start

Windows (PowerShell 7+)

```powershell
git clone https://github.com/lavantien/dotfiles.git $HOME/dev/dotfiles
cd $HOME/dev/dotfiles
.\bootstrap.ps1

# Git (including Git Bash) is auto-installed via winget during bootstrap
# No manual Git installation required

. $PROFILE
```

Linux / macOS

```bash
git clone https://github.com/lavantien/dotfiles.git ~/dev/dotfiles
cd ~/dev/dotfiles
chmod +x bootstrap.sh
./bootstrap.sh

exec zsh  # or source ~/.zshrc
```

Verify Installation

```bash
which n  # Should point to nvim
which lg  # Should point to lazygit

up  # or update
```

---

## 5. Bridge Approach Note

This repository uses a bridge approach that maintains backward compatibility while supporting optional configuration.

Works perfectly without configuration:
- Run bootstrap scripts directly - they use hardcoded defaults (categories: full)
- Zero setup required
- Existing workflows unchanged

Optional configuration available:
- Create ~/.dotfiles.config.yaml from example file
- Customize settings like categories, editor, github_username, etc.
- Scripts auto-detect and use config if present

Priority: Command-line flags > Config file > Hardcoded defaults

For details: See BRIDGE.md and QUICKREF.md

---

## 6. Bootstrap Options

Installation Categories

| Category | Description |
|----------|-------------|
| minimal | Foundation (package managers, git) + CLI tools only |
| sdk | Minimal + programming language SDKs (Node, Python, Go, Rust) |
| full | SDK + language servers + linters/formatters (default) |

Command-Line Options

| Option | Bash | PowerShell | Default |
|--------|-------|-----------|---------|
| Non-interactive | -y, --yes | -Y | Prompt for confirmation |
| Dry-run | --dry-run | -DryRun | Install everything |
| Categories | --categories sdk | -Categories sdk | full |
| Skip update | --skip-update | -SkipUpdate | Update package managers |
| Help | -h, --help | -Help | Show help |

What Gets Installed

| Phase | Tools |
|-------|-------|
| 1: Foundation | Package managers (Homebrew, Scoop), git |
| 2: Core SDKs | Node.js, Python, Go, Rust |
| 3: Language Servers | clangd, gopls, rust-analyzer, pyright, typescript-language-server, yaml-language-server |
| 4: Linters & Formatters | prettier, eslint, ruff, goimports, golangci-lint, clang-format |
| 5: CLI Tools | fzf, zoxide, bat, eza, lazygit, gh, ripgrep, fd, tokei, difftastic |
| 5: Testing & Coverage | bats (all), bashcov (all), Pester (Windows) |
| 6: Deploy Configs | Runs deploy.sh / deploy.ps1 to copy configurations |
| 7: Update All | Runs update-all.sh / update-all.ps1 to update packages and repos |

---

## 7. Configuration (Optional)

Default Behavior (No Config Needed)

```powershell
.\bootstrap.ps1

# Uses hardcoded defaults:
# - Categories: "full"
# - Interactive: true
# - No configuration file required
```

Optional Customization

```bash
cp .dotfiles.config.yaml.example ~/.dotfiles.config.yaml
vim ~/.dotfiles.config.yaml

./bootstrap.sh  # Auto-detects config
```

Configuration Priority

1. Command-line flags (highest): --categories minimal
2. Config file (middle): ~/.dotfiles.config.yaml
3. Hardcoded defaults (lowest): Script defaults

Common Config Options

| Setting | Values | Default | Description |
|----------|---------|---------|-------------|
| categories | minimal, sdk, full | full | Installation size |
| editor | nvim, vim, code, nano | (none) | Preferred editor |
| theme | gruvbox-light, etc. | (none) | Default theme |
| github_username | your github username | lavantien | Git repo management |
| base_dir | path to git repos | ~/dev/github | Repository location |
| auto_commit_changes | true, false | false | Auto-commit synced files |

---

## 8. Git Hooks

Supported Languages

| Language | Formatter | Linter | Type Check |
|----------|-----------|--------|------------|
| Go | gofmt, goimports | golangci-lint | go vet |
| Rust | cargo fmt | clippy | cargo check |
| C/C++ | clang-format | clang-tidy, cppcheck | compiler |
| JS/TS | Prettier | ESLint | tsc, svelte-check |
| Python | ruff, black | ruff, flake8 | mypy |
| C# | dotnet format | Roslyn analyzers | dotnet build |
| Java | spotless, google-java-format | checkstyle | javac |
| PHP | Laravel Pint, php-cs-fixer | PHPStan, Psalm | - |
| Bash | shfmt | shellcheck | - |
| Scala | scalafmt | scalac (compiler) | scalac |

What Hooks Do

Pre-commit (runs automatically before git commit):
1. Runs formatter on staged files
2. Runs linter
3. Runs type checker (if applicable)
4. Re-stages any auto-fixed files

Commit-msg (validates commit messages):
- Enforces Conventional Commits format
- Validates types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert

Valid Commit Messages

```
feat(auth): add OAuth2 login support
fix(api): resolve null pointer in user service
docs(readme): update installation instructions
refactor(core): extract payment logic to separate module
test(user): add unit tests for registration flow
```

Bypass Hooks (Emergency)

```bash
git commit --no-verify -m "wip: emergency fix"
```

---

## 9. Claude Code Integration

First-class support for Claude Code with quality checks and TDD enforcement.

Quality Check Hook

Automatically runs format/lint/type-check after any file write operation:

```json
// ~/.claude/settings.json (Linux/macOS)
// %USERPROFILE%\.claude\settings.json (Windows)
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

Quality Check Tools Used

Claude Code's quality check hook uses the same tools as the git hooks (see Section 8):

| Category | Tools |
|----------|-------|
| **Formatters** | prettier, ruff, black, isort, goimports, go fmt, cargo fmt, clang-format, dotnet format, spotless, google-java-format, shfmt, scalafmt, php-cs-fixer, Laravel Pint |
| **Linters** | eslint, ruff, flake8, golangci-lint, clippy, clang-tidy, cppcheck, mypy, shellcheck, PHPStan, Psalm, checkstyle |
| **Type Checkers** | tsc, go vet, cargo check, mypy, dotnet build, javac |

The quality check automatically detects the file type and runs the appropriate tool. See Section 8 (Git Hooks) for the complete language-by-language breakdown.

TDD Guard

Enforces Test-Driven Development practices when working with Claude Code:
- Red-Green-Refactor cycle enforcement
- Prevents adding multiple tests at once
- Prevents over-implementation
- Ensures tests exist before implementation

The TDD guard instructions are located at .claude/tdd-guard/data/instructions.md.

Deploy Claude Code Hooks

```bash
# The deploy script automatically copies Claude hooks to:
# ~/.claude/ (Linux/macOS)
# %USERPROFILE%\.claude\ (Windows)

# Just add hooks configuration to your Claude Code settings.json
```

---

## 10. Universal Update All

One command to update everything on your system.

```bash
# Linux/macOS
up  # or: update

# Windows (PowerShell)
up  # or: update
```

Supported Package Managers (20+)

System Package Managers:
APT, DNF, Pacman, Zypper, Homebrew, Snap, Flatpak, Scoop, winget, Chocolatey

Language Package Managers:
npm, yarn, pnpm, gup/go, cargo, rustup, pip/pip3, poetry, dotnet, gem, composer, tlmgr

---

## 11. System Instructions Sync

Single source of truth for AI assistant instructions across all repositories.

Files Distributed

| File | Purpose |
|------|---------|
| CLAUDE.md | Claude Code project instructions |
| AGENTS.md | Agent-specific behavior instructions |
| GEMINI.md | Gemini-specific instructions |
| RULES.md | Master system prompt |

Git Repository Management

```bash
# Update all repos (includes instruction sync)
./git-update-repos.sh

# Same with auto-commit
./git-update-repos.sh -c

# Windows
.\git-update-repos.ps1 -Commit
```

Standalone Sync

```bash
# Sync instructions to all repos
./sync-system-instructions.sh

# Sync + commit + push (for headless Claude Code)
./sync-system-instructions.sh -c -p

# Windows
.\sync-system-instructions.ps1 -Commit -Push
```

---

## 12. Health Check & Troubleshooting

Health Check

```bash
# Run health check
./healthcheck.sh

# PowerShell
.\healthcheck.ps1

# With JSON output (for CI/CD)
./healthcheck.sh --format json
```

Quick Troubleshooting

| Issue | Solution |
|--------|----------|
| Git hooks not running | git config --global core.hooksPath ~/.config/git/hooks |
| PowerShell execution policy | Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser |
| Neovim plugins not installing | In Neovim run :PackUpdate |
| zoxide not jumping to directories | Use directories normally for a few days to let zoxide learn |

For detailed troubleshooting, see QUICKREF.md.

---

## 13. Testing

Comprehensive test suite ensuring reliability across all platforms and components.

Test Coverage

| Suite | Tests | Description |
|-------|-------|-------------|
| PowerShell | 141 | Wrapper validation, bootstrap, config, git hooks, E2E |
| Bash | 233 | Unit tests for deploy, backup, restore, healthcheck, uninstall, sync, git-update |
| **Total** | **374** | Cross-platform test coverage |

Test Areas Covered

- Bootstrap Process: Platform detection, package installation, idempotency
- Configuration System: YAML parsing, defaults, platform-specific settings
- Deployment: File copying, backup behavior, OneDrive handling
- Git Hooks: Commit message validation, project type detection, pre-commit checks
- Update Scripts: Package manager detection, timeout handling, safety features
- Edge Cases: Error handling, missing dependencies, graceful failures

Running Tests

```bash
# PowerShell tests
cd tests/powershell
pwsh -NoProfile -File run-tests.ps1

# Run specific test suite
pwsh -NoProfile -File check-git-e2e.ps1

# Bash tests (requires bats)
cd tests/bash
bats bootstrap_test.bats
bats git-hooks_test.bats
```

Test Philosophy

- Unit tests verify individual functions and components
- E2E tests validate real-world workflows in isolated environments
- Tests are self-contained and clean up after themselves
- All tests are deterministic and can run in any order

---

## 14. Code Coverage

Universal coverage measurement using bashcov for bash scripts and Pester for PowerShell scripts.

**bashcov** (primary, universal) - Ruby gem that provides bash coverage on all platforms (Windows/Linux/macOS) without Docker.

**Pester** - PowerShell code coverage using AST-based analysis.

Coverage Tools

| Platform | Bash | PowerShell |
|----------|------|------------|
| Windows | bashcov (Ruby gem) | Pester |
| Linux | bashcov (Ruby gem) | Pester |
| macOS | bashcov (Ruby gem) | Pester |

**No Docker required** - bashcov works natively on all platforms with Ruby.

Tool Installation (Automatic)

All coverage tools are automatically installed by the bootstrap scripts:

```bash
# Linux/macOS
./bootstrap.sh
# Installs: Ruby, bashcov gem, bats, and all dependencies

# Windows PowerShell
.\bootstrap.ps1
# Installs: Ruby (Scoop), bashcov gem, Pester, bats
```

Manual Installation

If needed, install manually:

```bash
# bashcov (requires Ruby first)
gem install bashcov

# Verify installation
bashcov --version
bats --version
```

Running Coverage Reports

```bash
# Universal script (all platforms)
./tests/coverage.sh

# Bash-only coverage via Docker (all platforms)
./tests/coverage-docker.sh

# Bash-only coverage native (Linux/macOS)
./tests/coverage-bash.sh

# PowerShell-only coverage
pwsh -NoProfile -File tests/powershell/coverage.ps1

# Windows - full report with README update
.\tests\coverage-report.ps1 -UpdateReadme
```

Coverage Output

The coverage scripts generate:

- `coverage.json` - Combined coverage data for CI/CD
- `coverage-badge.svg` - Dynamic badge for README
- `coverage/bashcov/index.html` - Detailed HTML report (bashcov coverage)

Badge Color Scale

| Coverage | Color |
|----------|-------|
| >= 80% | brightgreen |
| >= 70% | green |
| >= 60% | yellowgreen |
| >= 50% | yellow |
| >= 40% | orange |
| < 40% | red |

Coverage Calculation

- **PowerShell**: Measured via Pester v5.7+ code coverage feature
- **Bash**: Measured via bashcov (universal Ruby gem, works on all platforms)
- **Combined**: Weighted average (60% PowerShell + 40% bash based on codebase complexity)

---

## 15. Updating

```bash
cd ~/dev/dotfiles  # or $HOME/dev/dotfiles on Windows
git pull

./bootstrap.sh  # or .\bootstrap.ps1 on Windows

source ~/.zshrc  # or . $PROFILE on Windows
```

---

## 16. Shell Aliases

File Operations

| Alias | Command | Description |
|-------|---------|-------------|
| ls | eza -la ... | Detailed directory listing |
| df | difft | Difftastic diff |
| t | tokei | Code statistics |

Directory Navigation (Zoxide)

| Alias | Description |
|-------|-------------|
| z <pattern> | Jump to directory matching pattern (fuzzy match) |
| zi | Interactive directory selection with fzf |
| zd <filter> | Jump with partial filter, shows interactive if no match |

Git Aliases

| Alias | Command |
|-------|---------|
| gs | git status |
| gl | git log |
| glg | git log --graph |
| glf | git log --follow |
| gb | git branch |
| gd | git diff |
| ga | git add |
| gaa | git add . |
| gcm | git commit -m |
| gp | git push |
| gf | git fetch |
| gm | git merge |
| gc | git checkout |
| gcb | git checkout -b |
| gt | git tag |

Docker Aliases

| Alias | Command |
|-------|---------|
| d | docker |
| ds | docker start |
| dx | docker stop |
| dp | docker ps |
| dpa | docker ps -a |
| di | docker images |
| dl | docker logs |
| dlf | docker logs -f |
| dc | docker compose |
| dcp | docker compose ps |
| dcpa | docker compose ps -a |
| dcu | docker compose up |
| dcd | docker compose down |
| dcl | docker compose logs |
| dclf | docker compose logs -f |

Utility Aliases

| Alias | Description |
|-------|-------------|
| up / update | Update all packages |
| ep | Edit profile |
| rprof | Reload profile |

---

## 17. Neovim Keybindings

Leader key is Space.

From init.lua:

| Keybinding | Mode | Action |
|------------|------|--------|
| - | Normal | Open parent directory (Oil) |
| `<leader>q` | Normal | Quit |
| `<leader>x` | Normal | Write and source config |
| `<leader>'` | Normal | Search forward (#) |
| `<leader>pt` | Normal | Toggle Typst preview |
| `<leader>ps` | Normal | Start Typst preview |
| `<leader>pc` | Normal | Close Typst preview |
| `<leader>;` | Normal | Typst preview pick |
| `<leader>b` | Normal | Format buffer (LSP) |
| `<leader>u` | Normal | Update plugins |
| `<leader>e` | Normal | Fuzzy find everywhere (FzfLua) |
| `<leader>n` | Normal | Fuzzy combine (FzfLua) |
| `<leader>/` | Normal | Grep in current buffer (FzfLua) |
| `<leader>z` | Normal | Live grep native (FzfLua) |
| `<leader>f` | Normal | Find files (FzfLua) |
| `<leader>h` | Normal | Help tags (FzfLua) |
| `<leader>k` | Normal | Keymaps (FzfLua) |
| `<leader>l` | Normal | Location list (FzfLua) |
| `<leader>m` | Normal | Marks (FzfLua) |
| `<leader>t` | Normal | Quickfix (FzfLua) |

Git Mappings (using FzfLua)

| Key | Action |
|-----|--------|
| `<leader>gf` | Git files |
| `<leader>gs` | Git status |
| `<leader>gd` | Git diff |
| `<leader>gh` | Git hunks |
| `<leader>gc` | Git commits |
| `<leader>gl` | Git blame |
| `<leader>gb` | Git branches |
| `<leader>gt` | Git tags |
| `<leader>gk` | Git stash |

LSP Mappings (using FzfLua)

| Key | Action |
|-----|--------|
| `<leader>\` | LSP finder (definitions, refs, implementations) |
| `<leader>dd` | Document diagnostics |
| `<leader>dw` | Workspace diagnostics |
| `<leader>,` | Incoming calls |
| `<leader>.` | Outgoing calls |
| `<leader>a` | Code actions |
| `<leader>s` | Document symbols |
| `<leader>w` | Workspace symbols |
| `<leader>r` | References |
| `<leader>i` | Implementations |
| `<leader>o` | Type definitions |
| `<leader>j` | Go to definition |
| `<leader>v` | Go to declaration |

---

## 18. Additional Documentation

| Document | Purpose |
|----------|---------|
| QUICKREF.md | Quick reference card and common tasks |
| BRIDGE.md | Bridge approach and configuration system |
| FIX_SUMMARY.md | What was fixed and why |
| COMPLETION_SUMMARY.md | Complete verification summary |

---

## License

MIT
