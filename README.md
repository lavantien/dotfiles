# Universal Dotfiles

> Cross-platform development environment that just works everywhere

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-blue)](https://github.com/lavantien/dotfiles)

A carefully crafted, production-grade dotfiles repository supporting **Windows 11 native**, **Linux (Ubuntu/Fedora/Arch)**, and **macOS**. One repository to rule them all auto-detecting your platform and tools, falling back gracefully when something is missing.

## Source of Truth

This repository is the **single source of truth** for my entire development environment. All configurations, tooling preferences, and AI assistant system instructions flow from here.

When I update something in this dotfiles repo:
1. Configurations are deployed to my home directory via the deploy script
2. System instruction files (CLAUDE.md, AGENTS.md, GEMINI.md, RULES.md) can be distributed to all my GitHub repos via `sync-system-instructions.sh`
3. The `git-update-repos` script automatically calls the sync script after cloning/updating repos
4. Claude Code commits and pushes the distributed files using headless mode

This ensures consistent behavior across all projects and all machines.

---

## Table of Contents

- [Source of Truth](#source-of-truth)
- [Features](#features)
- [Quick Start](#quick-start)
- [Bootstrap / Fresh Machine Setup](#bootstrap--fresh-machine-setup)
- [What Gets Installed](#what-gets-installed)
- [Universal Git Hooks](#universal-git-hooks)
- [Claude Code Integration](#claude-code-integration)
- [Universal Update All](#universal-update-all)
- [System Instructions Sync](#system-instructions-sync)
  - [Standalone Sync](#standalone-sync)
  - [Git Repository Management](#git-repository-management)
- [Neovim Configuration](#neovim-configuration)
- [Shell Aliases](#shell-aliases)
- [Platform-Specific Setup](#platform-specific-setup)
- [Directory Structure](#directory-structure)

---

## Features

### Cross-Platform
- **Windows 11** - Native PowerShell 7+ support
- **Linux** - Ubuntu, Fedora, Arch, openSUSE
- **macOS** - Intel and Apple Silicon

### Intelligent Automation
- **Auto-detection** - Detects platform, tools, and project types automatically
- **Graceful fallbacks** - Works even when some tools aren't installed
- **OneDrive-aware** - Handles synced Documents folders on Windows

### Developer Tools
- **15+ LSP servers** - Lua, Go, Rust, C/C++, Python, JS/TS, Java, C#, Dart, Typst, Docker, YAML, and more
- **9+ languages** in Git hooks - Auto-formats and lints on commit
- **20+ package managers** - Update everything with one command

### Quality Assurance
- **Conventional commits** enforcement
- **Claude Code hooks** for real-time quality checks
- **TDD guard** to enforce test-driven development practices

---

## Quick Start

### Windows (PowerShell 7+)

```powershell
# Clone and bootstrap (installs tools + deploys configs)
git clone https://github.com/lavantien/dotfiles.git $HOME/dev/dotfiles
cd $HOME/dev/dotfiles
.\bootstrap\bootstrap.ps1

# Reload your shell
. $PROFILE
```

### Linux / macOS

```bash
# Clone and bootstrap (installs tools + deploys configs)
git clone https://github.com/lavantien/dotfiles.git ~/dev/dotfiles
cd ~/dev/dotfiles
chmod +x bootstrap/bootstrap.sh
./bootstrap/bootstrap.sh

# Reload your shell
exec zsh  # or source ~/.zshrc
```

### Verify Installation

```bash
# Check that aliases work
which n  # Should point to nvim
which lg  # Should point to lazygit

# Update everything
up  # or update
```

---

## Bootstrap / Fresh Machine Setup

For a **fresh machine** or to **automatically install all development tools**, use the bootstrap script. This installs package managers, SDKs, language servers, linters, and CLI tools.

### Windows (PowerShell 7+)

```powershell
# Clone and bootstrap in one go
git clone https://github.com/lavantien/dotfiles.git $HOME/dev/dotfiles
cd $HOME/dev/dotfiles
.\bootstrap\bootstrap.ps1

# Reload your shell
. $PROFILE
```

### Linux / macOS

```bash
# Clone and bootstrap
git clone https://github.com/lavantien/dotfiles.git ~/dev/dotfiles
cd ~/dev/dotfiles
chmod +x bootstrap/bootstrap.sh
./bootstrap/bootstrap.sh

# Reload your shell
exec zsh  # or source ~/.zshrc
```

### Bootstrap Options

```bash
# Unix (Linux/macOS)
./bootstrap/bootstrap.sh [options]

# Windows (PowerShell)
.\bootstrap\bootstrap.ps1 [options]
```

| Option | Description | Default |
|--------|-------------|---------|
| `-y, --yes` / `-Y` | Non-interactive mode (accept all prompts) | Prompt for confirmation |
| `--dry-run` / `-DryRun` | Show what would be installed without installing | Install everything |
| `--categories` / `-Categories` | Installation category: `minimal`, `sdk`, or `full` | `full` |
| `--skip-update` / `-SkipUpdate` | Skip updating package managers first | Update package managers |
| `-h, --help` / `-Help` | Show help message | - |

### Installation Categories

| Category | Description |
|----------|-------------|
| **minimal** | Foundation (package managers, git) + CLI tools only |
| **sdk** | Minimal + programming language SDKs (Node, Python, Go, Rust) |
| **full** | SDK + language servers + linters/formatters (default) |

### What Gets Installed

The bootstrap script installs tools in phases:

| Phase | Category | Tools |
|-------|----------|-------|
| 1 | Foundation | Package managers (Homebrew, Scoop), git |
| 2 | Core SDKs | Node.js, Python, Go, Rust |
| 3 | Language Servers | clangd, gopls, rust-analyzer, pyright, typescript-language-server, yaml-language-server |
| 4 | Linters & Formatters | prettier, eslint, ruff, goimports, golangci-lint, clang-format |
| 5 | CLI Tools | fzf, zoxide, bat, eza, lazygit, gh, ripgrep, fd, tokei, difftastic |
| 6 | Deploy Configs | Runs `deploy.sh` / `deploy.ps1` to copy configurations |
| 7 | Update All | Runs `update-all.sh` / `update-all.ps1` to update packages and repos |

### Package Sources

| Tool Type | Windows | Linux | macOS |
|-----------|---------|-------|-------|
| System packages | Scoop (preferred), winget | apt, dnf, pacman, zypper | Homebrew |
| Language servers | npm global, go install, cargo, rustup | npm global, go install, cargo, rustup | npm global, go install, cargo, rustup |
| Linters | npm global, pip, go install | npm global, pip, go install | npm global, pip, go install |

### Idempotency

The bootstrap script is **idempotent** - you can run it multiple times safely:

- Checks if tools are already installed
- Compares versions against minimum requirements
- Only installs or updates tools that are missing or outdated
- Skips tools that meet requirements

### Example Output

```
==== Bootstrap macOS Development Environment ====

Options:
  Interactive: true
  Dry Run: false
  Categories: full
  Skip Update: false

? Proceed with bootstrap? [y/N] y

==== Phase 1: Foundation ====
[STEP] Installing Homebrew...
[OK] brew

==== Phase 2: Core SDKs ====
[STEP] Installing node via brew...
[OK] node
...

==== Bootstrap Summary ====

Installed: 15
  - brew, node, python, go, rust, clangd, gopls, ...
Skipped: 5
  - git, fzf, bat, ...
Failed: 0

=== Bootstrap Complete ===
Reload your shell to apply changes
```

### Existing Setups: Deploy Only

If you already have all tools installed and just want to update configurations:

```powershell
# Windows
.\deploy.ps1

# Linux/macOS
./deploy.sh
```

---

## What Gets Installed

| File / Directory | Windows | Linux | macOS | Description |
|------------------|---------|-------|-------|-------------|
| `Microsoft.PowerShell_profile.ps1` | * | - | - | PowerShell 7 profile with aliases and tools |
| `.zshrc` | - | * | * | Zsh configuration with Oh My Zsh, zoxide, fzf |
| `.bash_aliases` | * | * | * | Universal aliases (sourced by zsh too) |
| `.gitconfig` | * | * | * | Git configuration with delta, difftastic support |
| `init.lua` | * | * | * | Neovim config - full IDE setup |
| `lua/` | * | * | * | Neovim plugins and LSP configuration |
| `wezterm.lua` | * | * | * | Wezterm terminal with Catppuccin theme |
| `hooks/git/` | * | * | * | Universal Git hooks (pre-commit, commit-msg) |
| `hooks/claude/` | * | * | * | Claude Code quality hooks |
| `.claude/tdd-guard/` | * | * | * | TDD enforcement for Claude Code |
| `update-all.ps1` | * | - | - | Universal package updater (Windows) |
| `update-all.sh` | - | * | * | Universal package updater (Unix) |
| `git-update-repos.ps1` | * | - | - | Update/clone all GitHub repos (Windows) |
| `git-update-repos.sh` | * | * | * | Update/clone all GitHub repos (Unix) |
| `sync-system-instructions.ps1` | * | - | - | Sync system instructions to all repos (Windows) |
| `sync-system-instructions.sh` | * | * | * | Sync system instructions to all repos (Unix) |
| `.aider.conf.yml` | * | * | * | Aider AI coding assistant config |

---

## Universal Git Hooks

The Git hooks automatically detect your project type and run the appropriate tools. No configuration needed just commit and they work.

### Supported Languages

| Language | Formatter | Linter | Type Check | Unit Tests |
|----------|-----------|--------|------------|------------|
| **Go** | gofmt, goimports | golangci-lint | go vet | go test ./... |
| **Rust** | cargo fmt | clippy | cargo check | cargo test |
| **C/C++** | clang-format | clang-tidy, cppcheck | compiler | - |
| **JavaScript/TypeScript** | Prettier | ESLint | tsc, svelte-check | vitest, jest |
| **Python** | ruff, black | ruff, flake8 | mypy | pytest |
| **C#** | dotnet format | Roslyn analyzers | dotnet build | dotnet test |
| **Java** | spotless, google-java-format | checkstyle | javac | JUnit |
| **Scala** | scalafmt | scalac | scalac | scalatest |
| **PHP** | Laravel Pint, php-cs-fixer | PHPStan, Psalm | PHPStan, Psalm | PHPUnit |

### What Hooks Do

**Pre-commit** (runs automatically before `git commit`):
1. Runs formatter on staged files
2. Runs linter
3. Runs type checker (if applicable)
4. Re-stages any auto-fixed files

**Commit-msg** (validates commit messages):
- Enforces [Conventional Commits](https://www.conventionalcommits.org/) format
- Validates types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`

### Valid Commit Messages

```
feat(auth): add OAuth2 login support
fix(api): resolve null pointer in user service
docs(readme): update installation instructions
refactor(core): extract payment logic to separate module
test(user): add unit tests for registration flow
```

### Bypass Hooks (Emergency)

```bash
git commit --no-verify -m "wip: emergency fix"
```

---

## Claude Code Integration

This repository includes first-class support for [Claude Code](https://claude.ai/code).

### Quality Check Hook

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

### TDD Guard

Enforces Test-Driven Development practices when working with Claude Code:

- **Red-Green-Refactor cycle** enforcement
- Prevents adding multiple tests at once
- Prevents over-implementation
- Ensures tests exist before implementation

The TDD guard instructions are located at `.claude/tdd-guard/data/instructions.md`.

### Deploy Claude Code Hooks

```bash
# The deploy script automatically copies Claude hooks to:
# ~/.claude/ (Linux/macOS)
# %USERPROFILE%\.claude\ (Windows)

# Just add the hooks configuration to your Claude Code settings.json
```

---

## Universal Update All

One command to update **everything** on your system. No more remembering 10 different update commands.

### Usage

```bash
# Linux/macOS
up  # or: update
# Windows (PowerShell)
up  # or: update
```

### Supported Package Managers

**System Package Managers:**
| Manager | Platform |
|---------|----------|
| APT | Debian, Ubuntu |
| DNF | Fedora |
| Pacman | Arch Linux |
| Zypper | openSUSE |
| Homebrew | macOS, Linux |
| Snap | Ubuntu |
| Flatpak | Universal |
| Scoop | Windows |
| winget | Windows 11 |
| Chocolatey | Windows |

**Language Package Managers:**
| Manager | Language |
|---------|----------|
| npm | Node.js |
| yarn | Node.js |
| pnpm | Node.js |
| gup / go | Go |
| cargo | Rust |
| rustup | Rust toolchain |
| pip / pip3 | Python |
| poetry | Python |
| dotnet | C# / .NET |
| gem | Ruby |
| composer | PHP |
| tlmgr | TeX Live |

### Example Output

```
========================================
   Universal Update All - macOS
========================================

[14:32:15] HOMEBREW
  Updated: brew
  [12 packages upgraded]

[14:33:02] NPM (Node.js global packages)
  Updated: npm
  [3 packages upgraded]

[14:33:15] CARGO (Rust packages)
  Updated: cargo
  [5 packages upgraded]

[14:34:01] PIP (Python packages)
  Updated: pip
  [8 packages upgraded]

========================================
           Summary
========================================
  Completed: 5
  Skipped: 0
  Duration: 1m 45s
========================================
```

---

## System Instructions Sync

The system instruction distribution is now modularized. You can sync AI assistant instructions to all repositories independently or as part of the repo update process.

### System Instruction Files

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Claude Code project instructions and workflow guidelines |
| `AGENTS.md` | Agent-specific behavior instructions |
| `GEMINI.md` | Gemini-specific behavior instructions |
| `RULES.md` | Master system prompt and rules |

### Standalone Sync

When you need to distribute updated system instructions without cloning/updating repos:

```bash
# PowerShell (Windows)
.\sync-system-instructions.ps1 [-BaseDir] "path" [-Commit] [-Push]

# Bash (Linux/macOS)
./sync-system-instructions.sh [-d base_dir] [-c] [-p]
```

**Options:**
| Option | Description | Default |
|--------|-------------|---------|
| `-BaseDir` / `-d` | Base directory containing repos | `$HOME/dev/github` |
| `-Commit` / `-c` | Commit changes after syncing | `false` |
| `-Push` / `-p` | Push changes after committing | `false` |

**What it does:**
- Scans all repositories in the base directory
- Compares system instruction files with the dotfiles source
- Copies only changed files to each repository
- Skips the dotfiles repo itself (source of truth)
- Optionally commits changes via git or Claude CLI
- Optionally pushes changes to origin

**Example:**
```bash
# Sync and commit using Claude CLI
./sync-system-instructions.sh -d ~/dev/github -c

# Sync, commit, and push
./sync-system-instructions.sh -d ~/dev/github -c -p
```

### Git Repository Management

The `git-update-repos` script automatically calls the sync script after cloning/updating repositories.

#### Update/Clone All GitHub Repos

```bash
# PowerShell (Windows)
.\git-update-repos.ps1 [-Username] "username" [-BaseDir] "path" [-UseSSH] [-NoSync]

# Bash (Linux/macOS)
./git-update-repos.sh [-u username] [-d base_dir] [-s] [--no-sync]
```

**Options:**
| Option | Description | Default |
|--------|-------------|---------|
| `-Username` / `-u` | GitHub username | `lavantien` |
| `-BaseDir` / `-d` | Base directory for repos | `$HOME/dev/github` |
| `-UseSSH` / `-s` | Use SSH URLs instead of HTTPS | `false` |
| `-NoSync` / `--no-sync` | Skip syncing system instructions | `false` |

**What it does:**
- Fetches all repositories for the specified user via GitHub API
- Clones repositories that don't exist locally
- Pulls latest changes for existing repositories
- **Calls `sync-system-instructions`** to distribute system instruction files
- **Invokes Claude Code** to commit and push the distributed files (if Claude CLI is available)
- Shows summary of cloned, updated, and skipped repos

**Example:**
```bash
# Update all repos and sync instructions (default)
./git-update-repos.sh

# Update repos but skip instruction sync
./git-update-repos.sh --no-sync
```

---

## Neovim Configuration

A full-featured Neovim IDE setup built with **Neovim 0.11+ native packages** no external plugin manager needed.

### Supported Languages (LSP)

| Language | LSP Server | Features |
|----------|------------|----------|
| Lua | lua_ls | Full IDE support |
| Go | gopls | Diagnostics, completion |
| Rust | rust_analyzer | Full IDE support |
| Python | pyright | Type checking |
| JavaScript/TypeScript | ts_ls | Full IDE support |
| C/C++ | clangd | Diagnostics, completion |
| Java | jdtls | Full IDE support |
| C# | csharp_ls | Full IDE support |
| Dart | dartls | Flutter support |
| Typst | tinymist | Live preview |
| Docker | docker_ls, docker_compose_ls | Syntax, validation |
| YAML | yamlls | Validation, completion |
| TOML | tombi | Validation |
| Markdown | codebook | Linting, preview |

### Key Plugins

- **gruvbox.nvim** - Beautiful color scheme (light mode by default)
- **nvim-treesitter** - Advanced syntax highlighting
- **fzf-lua** - Blazing fast fuzzy finder
- **oil.nvim** - File browser as a buffer
- **nvim-web-devicons** - File icons
- **fidget.nvim** - LSP progress indicator
- **typst-preview.nvim** - Live Typst preview
- **live-preview.nvim** - Markdown/HTML/CSV live preview

### Key Mappings

| Keybinding | Mode | Action |
|------------|------|--------|
| `-` | Normal | Open file browser (Oil) |
| `<leader>b` | Normal | Format buffer |
| `<leader>e` | Normal | Fuzzy find everywhere |
| `<leader>f` | Normal | Find files |
| `<leader>/` | Normal | Grep in current buffer |
| `<leader>z` | Normal | Live grep (native) |
| `<leader>pt` | Normal | Toggle Typst preview |
| `<leader>ps` | Normal | Start live preview |
| `<leader>pc` | Normal | Close live preview |
| `<leader>u` | Normal | Update plugins |
| `<leader>q` | Normal | Quit |

**LSP Mappings** (all `<leader>` + key):

| Key | Action |
|-----|--------|
| `gf` | Git files |
| `gs` | Git status |
| `gd` | Git diff |
| `gh` | Git hunks |
| `gc` | Git commits |
| `gl` | Git blame |
| `gb` | Git branches |
| `gt` | Git tags |
| `gk` | Git stash |
| `\` | LSP finder (definitions, refs, implementations) |
| `dd` | Document diagnostics |
| `dw` | Workspace diagnostics |
| `,` | Incoming calls |
| `.` | Outgoing calls |
| `a` | Code actions |
| `s` | Document symbols |
| `w` | Workspace symbols |
| `r` | References |
| `i` | Implementations |
| `o` | Type definitions |
| `j` | Go to definition |
| `v` | Go to declaration |

---

## Shell Aliases

Aliases work across **Bash, Zsh, and PowerShell** with auto-detection and graceful fallbacks.

### File Operations

| Alias | Command | Description |
|-------|---------|-------------|
| `n` | nvim / vim | Open editor |
| `b` | bat / cat | View file with syntax highlighting |
| `f` | fzf --preview bat | Fuzzy finder with live preview |
| `ls` | eza -la ... | Detailed directory listing |
| `e` | eza -a ... | Simple directory listing |
| `m` | mpv | Media player |
| `ff` | ffmpeg | FFmpeg |
| `df` | difft | Difftastic diff |
| `t` | tokei | Code statistics |

### Directory Navigation (Zoxide)

[Zoxide](https://github.com/ajeetdsouza/zoxide) is a smarter `cd` command that learns your directory navigation habits.

| Alias | Command | Description |
|-------|---------|-------------|
| `z <pattern>` | zoxide | Jump to directory matching pattern (fuzzy match) |
| `zi` | zoxide + fzf | Interactive directory selection with fzf |
| `zd <filter>` | zoxide + fzf filter | Jump with partial filter, shows interactive if no match |

**Examples:**
```bash
z dotfiles    # Jump to dotfiles directory
z src         # Jump to most frequently used "src" directory
zi            # Interactive fzf selection of all learned directories
zd dot        # Filter to "dot", shows interactive if multiple matches
```

**How Zoxide Learns:**
- Every time you use `z`, `zi`, or `zd`, zoxide remembers that directory
- Over time, it builds a priority/ranking based on frequency and recency
- Most-used directories appear first in `zi` selection

### Git Aliases

| Alias | Command |
|-------|---------|
| `gs` | git status |
| `gl` | git log |
| `glg` | git log --graph |
| `glf` | git log --follow |
| `gb` | git branch |
| `gbi` | git bisect |
| `gd` | git diff |
| `ga` | git add |
| `gaa` | git add . |
| `gcm` | git commit -m |
| `gp` | git push |
| `gf` | git fetch |
| `gm` | git merge |
| `gmt` | git mergetool |
| `gr` | git rebase |
| `gc` | git checkout |
| `gcb` | git checkout -b |
| `gcp` | git cherry-pick |
| `gt` | git tag |
| `gw` | git worktree |
| `gwa` | git worktree add |
| `gwd` | git worktree delete |
| `gws` | git worktree status |
| `gwc` | git worktree clean |
| `gsuir` | git submodule update --init --recursive |
| `gnuke` | Reset repo + submodules |

### Docker Aliases

| Alias | Command |
|-------|---------|
| `d` | docker |
| `ds` | docker start |
| `dx` | docker stop |
| `dp` | docker ps |
| `dpa` | docker ps -a |
| `di` | docker images |
| `dl` | docker logs |
| `dlf` | docker logs -f |
| `dc` | docker compose |
| `dcp` | docker compose ps |
| `dcpa` | docker compose ps -a |
| `dcu` | docker compose up |
| `dcub` | docker compose up --build |
| `dcd` | docker compose down |
| `dcl` | docker compose logs |
| `dclf` | docker compose logs -f |
| `de` | docker exec -it |

### Utility Aliases

| Alias | Description |
|-------|-------------|
| `up` / `update` | Update all packages |
| `ep` | Edit profile |
| `rprof` | Reload profile |
| `which` | Show command path (PowerShell) |

---

## Platform-Specific Setup

### Windows 11

**Recommended Package Manager:** [Scoop](https://scoop.sh)

```powershell
# Install Scoop
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestObject -Uri https://get.scoop.sh | Invoke-Expression

# Install development tools
scoop install git neovim python go rust nodejs-lts
scoop install lazygit fzf bat eza zoxide oh-my-posh
scoop install docker docker-compose
```

**Optional: winget**

```powershell
winget install -e --id Microsoft.PowerShell
winget install -e --id GitHub.cli
winget install -e --id Wez.Wezterm
```

**Terminal:** Wezterm or Windows Terminal with PowerShell 7+

### Linux (Ubuntu/Debian)

```bash
# System optimizations for developers
sudo mkdir -p /etc/NetworkManager/conf.d
sudo tee /etc/NetworkManager/conf.d/default-wifi-powersave-on.conf << EOF
[connection]
wifi.powersave = 2
EOF
sudo systemctl restart NetworkManager

# Increase file watcher limits (for IDEs)
sudo sysctl fs.inotify.max_user_watches=2097152
echo "fs.inotify.max_user_watches=2097152" | sudo tee -a /etc/sysctl.conf

# Install development tools
sudo apt update
sudo apt install -y git neovim python3 python3-pip python3-venv
sudo apt install -y golang rustc cargo nodejs npm
sudo apt install -y zsh zsh-autosuggestions fzf ripgrep eza
sudo apt install -y lazygit bat
```

**Optional: Homebrew on Linux**

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### macOS

```bash
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install development tools
brew install git neovim python go rust node
brew install lazygit fzf bat eza zoxide ripgrep
brew install --cask docker wezterm
```

**Install Oh My Zsh:**

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

---

## Directory Structure

```
dotfiles/
├── .bash_aliases              # Universal bash aliases (works in zsh too)
├── .zshrc                     # Zsh configuration with Oh My Zsh
├── Microsoft.PowerShell_profile.ps1  # PowerShell 7 profile
├── .gitconfig                 # Git configuration
├── init.lua                   # Neovim configuration
├── wezterm.lua                # Wezterm terminal config
├── deploy.sh                  # Deploy script (Linux/macOS)
├── deploy.ps1                 # Deploy script (Windows)
├── update-all.sh              # Universal update (Linux/macOS)
├── update-all.ps1             # Universal update (Windows)
├── git-clone-all.sh           # Bulk git clone helper (gh CLI)
├── git-update-repos.sh        # Update/clone all GitHub repos (Unix)
├── git-update-repos.ps1       # Update/clone all GitHub repos (Windows)
├── sync-system-instructions.sh  # Sync system instructions to all repos (Unix)
├── sync-system-instructions.ps1 # Sync system instructions to all repos (Windows)
├── CLAUDE.md                  # Claude Code project instructions (source of truth)
├── AGENTS.md                  # Agent-specific instructions
├── GEMINI.md                  # Gemini-specific instructions
├── RULES.md                   # Master system prompt
├── .aider.conf.yml.example    # Aider AI config template
├── .aider.model.settings.yml  # Aider model settings
├── typos.toml                 # Typos spell check config
├── hooks/
│   ├── README.md              # Hooks documentation
│   ├── git/
│   │   ├── pre-commit         # Bash pre-commit hook
│   │   ├── pre-commit.ps1     # PowerShell pre-commit hook
│   │   ├── commit-msg         # Bash commit-msg hook
│   │   └── commit-msg.ps1     # PowerShell commit-msg hook
│   └── claude/
│       └── quality-check.ps1  # Claude Code quality hook
├── .claude/
│   └── tdd-guard/
│       └── data/
│           └── instructions.md  # TDD guard instructions
├── assets/                    # Wallpapers and backgrounds
└── lua/                       # Neovim plugins (optional)
```

---

## Updating

```bash
# Pull latest changes
cd ~/dev/dotfiles  # or $HOME/dev/dotfiles on Windows
git pull

# Re-run bootstrap (idempotent - safe to run anytime)
./bootstrap/bootstrap.sh  # or .\bootstrap\bootstrap.ps1 on Windows

# Reload your shell
source ~/.zshrc  # or . $PROFILE on Windows
```

**Note:** The bootstrap script is idempotent - it skips tools that are already installed and only updates what's needed. Running it multiple times is completely safe.

---

## Troubleshooting

### Windows: PowerShell Execution Policy

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Git Hooks Not Running

```bash
# Check hooks path
git config --get core.hooksPath

# Verify hooks are executable (Linux/macOS)
ls -l ~/.config/git/hooks/

# Set verbose mode for debugging
VERBOSE=1 git commit -m "test"
```

### OneDrive Documents Folder on Windows

The deploy script auto-detects OneDrive-synced Documents folders. If you have issues:

```powershell
# Check detected path
[Environment]::GetFolderPath("MyDocuments")

# Manually set hooks path if needed
git config --global core.hooksPath "$env:USERPROFILE\.config\git\hooks"
```

### Neovim Plugins Not Installing

```bash
# In Neovim, run:
:Lazy sync  # or for native packages
:PackUpdate
```

---

## License

MIT

---

## Author

[lavantien](https://github.com/lavantien)

---

**Note:** This dotfiles repository is designed to be idempotent. The bootstrap script checks if tools are already installed before attempting installation, making it safe to run multiple times. For existing setups, running `bootstrap` will only install missing tools and deploy any new configuration changes.
