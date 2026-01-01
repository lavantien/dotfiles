# Universal Dotfiles

Cross-platform development environment that just works everywhere.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-blue)](https://github.com/lavantien/dotfiles)

Production-grade dotfiles supporting Windows 11, Linux (Ubuntu/Fedora/Arch), and macOS with intelligent auto-detection and graceful fallbacks.

---

## Table of Contents

- [Core Features](#core-features)
- [Idempotency Note](#idempotency-note)
- [Quick Start](#quick-start)
- [Configuration (Optional)](#configuration-optional)
- [Bootstrap Options](#bootstrap-options)
- [Neovim Keybindings](#neovim-keybindings)
- [Shell Aliases](#shell-aliases)
- [Git Hooks](#git-hooks)
- [Universal Update All](#universal-update-all)
- [System Instructions Sync](#system-instructions-sync)
- [Health Check & Troubleshooting](#health-check--troubleshooting)
- [Additional Documentation](#additional-documentation)
- [Updating](#updating)

---

## Core Features

Cross-Platform Support
- Windows 11: Native PowerShell 7+ support
- Linux: Ubuntu, Fedora, Arch, openSUSE
- macOS: Intel and Apple Silicon

Intelligent Automation
- Auto-detection: Detects platform, tools, and project types automatically
- Graceful fallbacks: Works even when some tools aren't installed
- OneDrive-aware: Handles synced Documents folders on Windows

Developer Tools
- 15+ LSP servers: Lua, Go, Rust, C/C++, Python, JS/TS, Java, C#, Dart, Typst, Docker, YAML
- 9+ languages in Git hooks: Auto-formats and lints on commit
- 20+ package managers: Update everything with one command

Quality Assurance
- Conventional commits enforcement
- Claude Code hooks for real-time quality checks
- TDD guard to enforce test-driven development

---

## Idempotency Note

All scripts in this repository are idempotent. They intelligently detect what's already installed, compare versions, and only install or update tools that are missing or outdated. You can safely run any script multiple times without any harm.

This applies to:
- bootstrap/bootstrap.sh and bootstrap/bootstrap.ps1
- deploy.sh and deploy.ps1
- update-all.sh and update-all.ps1
- git-update-repos.sh and git-update-repos.ps1
- sync-system-instructions.sh and sync-system-instructions.ps1

---

## Quick Start

Windows (PowerShell 7+)

```powershell
git clone https://github.com/lavantien/dotfiles.git $HOME/dev/dotfiles
cd $HOME/dev/dotfiles
.\bootstrap\bootstrap.ps1

. $PROFILE
```

Linux / macOS

```bash
git clone https://github.com/lavantien/dotfiles.git ~/dev/dotfiles
cd ~/dev/dotfiles
chmod +x bootstrap/bootstrap.sh
./bootstrap/bootstrap.sh

exec zsh  # or source ~/.zshrc
```

Verify Installation

```bash
which n  # Should point to nvim
which lg  # Should point to lazygit

up  # or update
```

---

## Configuration (Optional)

Bridge Approach Note

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

Default Behavior (No Config Needed)

```powershell
.\bootstrap\bootstrap.ps1

# Uses hardcoded defaults:
# - Categories: "full"
# - Interactive: true
# - No configuration file required
```

Optional Customization

```bash
cp .dotfiles.config.yaml.example ~/.dotfiles.config.yaml
vim ~/.dotfiles.config.yaml

./bootstrap/bootstrap.sh  # Auto-detects config
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

## Bootstrap Options

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
| 6: Deploy Configs | Runs deploy.sh / deploy.ps1 to copy configurations |
| 7: Update All | Runs update-all.sh / update-all.ps1 to update packages and repos |

---

## Neovim Keybindings

Editor Mappings

| Keybinding | Mode | Action |
|------------|------|--------|
| - | Normal | Open file browser (Oil) |
| <leader>b | Normal | Format buffer |
| <leader>e | Normal | Fuzzy find everywhere |
| <leader>f | Normal | Find files |
| <leader>/ | Normal | Grep in current buffer |
| <leader>z | Normal | Live grep (native) |
| <leader>pt | Normal | Toggle Typst preview |
| <leader>ps | Normal | Start live preview |
| <leader>pc | Normal | Close live preview |
| <leader>u | Normal | Update plugins |
| <leader>q | Normal | Quit |

LSP Mappings (<leader> + key)

| Key | Action |
|-----|--------|
| gf | Git files |
| gs | Git status |
| gd | Git diff |
| gh | Git hunks |
| gc | Git commits |
| gl | Git blame |
| gb | Git branches |
| \ | LSP finder (definitions, refs, implementations) |
| dd | Document diagnostics |
| dw | Workspace diagnostics |
| , | Incoming calls |
| . | Outgoing calls |
| a | Code actions |
| s | Document symbols |
| w | Workspace symbols |
| r | References |
| i | Implementations |
| o | Type definitions |
| j | Go to definition |
| v | Go to declaration |

---

## Shell Aliases

File Operations

| Alias | Command | Description |
|-------|---------|-------------|
| n | nvim / vim | Open editor |
| b | bat / cat | View file with syntax highlighting |
| f | fzf --preview bat | Fuzzy finder with live preview |
| ls | eza -la ... | Detailed directory listing |
| e | eza -a ... | Simple directory listing |
| m | mpv | Media player |
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

## Git Hooks

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

## Universal Update All

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

## System Instructions Sync

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

## Health Check & Troubleshooting

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

## Additional Documentation

| Document | Purpose |
|----------|---------|
| QUICKREF.md | Quick reference card and common tasks |
| BRIDGE.md | Bridge approach and configuration system |
| FIX_SUMMARY.md | What was fixed and why |
| COMPLETION_SUMMARY.md | Complete verification summary |

---

## Updating

```bash
cd ~/dev/dotfiles  # or $HOME/dev/dotfiles on Windows
git pull

./bootstrap/bootstrap.sh  # or .\bootstrap\bootstrap.ps1 on Windows

source ~/.zshrc  # or . $PROFILE on Windows
```

---

## License

MIT
