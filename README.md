# Universal Dotfiles

![Coverage](coverage-badge.svg) [![Security](https://img.shields.io/badge/security-reviewed-brightgreen)](#security) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-blue)](https://github.com/lavantien/dotfiles)

Production-grade dotfiles for Windows 11, Linux (Ubuntu/Fedora/Arch), and macOS. Auto-detecting, gracefully degrading, fully vibecoding-enabled with **24 LSP servers**, **40+ tools**, TDD enforcement, comprehensive Git hooks, and Claude Code integration.

## Table of Contents

- [Quick Start](#quick-start)
- [Features Overview](#features-overview)
- [Bootstrap & Options](#bootstrap--options)
- [Configuration](#configuration)
- [Tools Reference](#tools-reference)
- [Quality & Hooks](#quality--hooks)
- [Claude Code Integration](#claude-code-integration)
- [Package Management](#package-management)
- [Git Repository Management](#git-repository-management)
- [Health & Troubleshooting](#health--troubleshooting)
- [Shell & Terminal](#shell--terminal)
- [Additional Documentation](#additional-documentation)

---

## Quick Start

### Prerequisites (Optional - for Docker/Kubernetes development)

If you need Docker and Kubernetes support, install these first:

**Docker Engine (Ubuntu)**
```bash
# Add Docker's official GPG key and repository
sudo apt update
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add your user to docker group (optional, to avoid sudo)
sudo usermod -aG docker $USER
newgrp docker  # Log out and back in for this to take effect
```

**minikube (Local Kubernetes)**
```bash
# Download and install minikube
curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64

# Start minikube (requires Docker or a VM manager)
minikube start
```

**kubectl** (installed by bootstrap.sh, or manually):
```bash
# Via curl (latest stable release)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl
```

### Dotfiles Installation

**Linux**
```bash
git clone https://github.com/lavantien/dotfiles.git ~/dev/dotfiles
cd ~/dev/dotfiles
chmod +x bootstrap.sh
./bootstrap.sh
chsh -s $(which zsh)  # Set zsh as default shell
exec zsh  # or source ~/.zshrc
```

**macOS**
```bash
git clone https://github.com/lavantien/dotfiles.git ~/dev/dotfiles
cd ~/dev/dotfiles
chmod +x bootstrap.sh
./bootstrap.sh
exec zsh  # or source ~/.zshrc
```

**Windows (PowerShell 7+)**
```powershell
git clone https://github.com/lavantien/dotfiles.git $HOME/dev/dotfiles
cd $HOME/dev/dotfiles
.\bootstrap.ps1
. $PROFILE
```

**Verify Installation**
```bash
which n  # Should point to nvim
which lg  # Should point to lazygit
up  # or update - runs update-all
```

### Entry Point Scripts

| Script | Purpose |
|--------|---------|
| **bootstrap** | Initial setup - installs package managers, SDKs, LSPs, linters, tools, deploys configs |
| **deploy** | Deploy configuration files (Neovim, git hooks, shell aliases, Claude Code hooks) |
| **update-all** | Update all package managers and system packages (20+ managers supported) |
| **git-update-repos** | Clone/update ALL GitHub repos via gh CLI, optionally sync system instructions |
| **sync-system-instructions** | Sync AI system instructions (CLAUDE.md, AGENTS.md, GEMINI.md) to all repos |
| **healthcheck** | Check system health - verify tools installed, configs in place, git hooks working |
| **backup** | Create timestamped backup before major changes |
| **restore** | Restore from a previous backup (`--list-backups` to see available) |
| **uninstall** | Remove deployed configs (keeps installed packages) |

Use `.ps1` on Windows, `.sh` on Linux/macOS.

---

## Features Overview

**Cross-Platform Support**
- Windows 11: Native PowerShell 7+
- Linux: Ubuntu, Fedora, Arch, openSUSE
- macOS: Intel and Apple Silicon

Thoroughly tested on Ubuntu 26.04 LTS and Windows 11.

**Intelligent Automation**
- Auto-detection of platform, tools, and project types
- Graceful fallbacks when tools are missing
- OneDrive-aware on Windows
- **Idempotent**: safe to run multiple times - skips existing tools, auto-corrects package sources

**What Gets Installed**

| Category | Tools |
|----------|-------|
| **Package Managers** | Homebrew (Linux/macOS), Scoop (Windows), apt/dnf/pacman (Linux) |
| **SDKs** | Node.js, Python, Go, Rust (rustup), dotnet, OpenJDK |
| **Language Servers** | 25 servers - see [TOOLS.md](TOOLS.md) |
| **Linters/Formatters** | prettier, eslint, ruff, black, golangci-lint, clippy, shellcheck, yamllint, hadolint, etc. |
| **CLI Tools** | fzf, zoxide, bat, eza, lazygit, gh, ripgrep, fd, tokei, repomix, docker-compose, helm, kubectl |
| **Shell** | zsh, oh-my-zsh (half-life theme, plugins: autosuggestions, syntax-highlighting, interactive-cd) |
| **Terminal** | WezTerm (GPU-accelerated, IosevkaTerm Nerd Font) |
| **Testing** | bats, busted, pytest, Pester, kcov |

**Installation Categories**

| Category | Description |
|----------|-------------|
| minimal | Package managers + git + CLI tools only |
| sdk | Minimal + programming language SDKs |
| full | SDK + all LSPs + linters/formatters (default) |

**Quality Assurance**
- Conventional commits enforcement via git commit-msg hook
- Pre-commit hooks that auto-format and lint for 19+ languages
- Claude Code quality hooks for real-time format/lint/type-check after file writes
- 150+ automated tests (PowerShell + Bash)
- Hook integrity tests prevent regression

**Idempotency & Safe Re-runs**

The bootstrap script is fully idempotent - running it multiple times is safe and recommended. Each run:

- **Detects existing installations** - skips tools already present
- **Auto-corrects package sources** - migrates apt/npm/cargo packages to brew when available
- **Fixes broken states** - repairs dpkg interrupts and broken dependencies
- **Updates existing tools** - runs update-all.sh at the end

Example output from a fully bootstrapped system (95 tools skipped, 0 new installs):

```
lavantien in ~/dev/github/dotfiles on main ● ● ● λ ./bootstrap.sh -y

==== Bootstrap Linux Development Environment ====

Options:
  Interactive: false
  Dry Run: false
  Categories: full
  Skip Update: false


==== Phase 1: Foundation ====

[STEP] Checking for broken package states...
[INFO] Fixed dpkg interrupts
Summary:
  Upgrading: 0, Installing: 0, Removing: 0, Not Upgrading: 3
[INFO] Fixed broken packages
[STEP] Installing prerequisites via apt: curl, git, vim...
[OK] GitHub CLI already authenticated
[STEP] Ensuring key packages are from brew...
[INFO] git already from brew, skipping replacement
[INFO] node already from brew, skipping replacement
[INFO] go already from brew, skipping replacement
[INFO] lua-language-server already from brew, skipping replacement
[INFO] golangci-lint already from brew, skipping replacement
...
[OK] Package self-correction complete
...
==== Bootstrap Summary ====

Installed: 0

Skipped: 95
  - wezterm (terminal emulator)
  - IosevkaTerm (Nerd Font)
  - git (version control)
  - gcc
  - node (Node.js runtime)
  ...
  - latex (document preparation)
  - claude-code (AI CLI)
  - opencode (AI CLI)

=== Bootstrap Complete ===
All tools are available in the current session.
For new shells, PATH has been updated automatically.
```

Key idempotency features shown above:
- `[INFO] git already from brew, skipping replacement` - detects correct source
- `[WARN] Found texlive from apt (removing for brew version)...` - auto-corrects
- `Installed: 0, Skipped: 95` - summary shows what was already present

---

## Bootstrap & Options

**Command-Line Options**

| Option | Bash | PowerShell | Default |
|--------|-------|-----------|---------|
| Non-interactive | `-y`, `--yes` | `-Y` | Prompt for confirmation |
| Dry-run | `--dry-run` | `-DryRun` | Install everything |
| Categories | `--categories sdk` | `-Categories sdk` | full |
| Skip update | `--skip-update` | `-SkipUpdate` | Update package managers |
| Verbose | `--verbose` | `-VerboseMode` | Show detailed output |
| Help | `-h`, `--help` | `-Help` | Show help |

**Bootstrap Phases**

| Phase | Tools |
|-------|-------|
| 1: Foundation | Package managers, git, WezTerm (Linux), IosevkaTerm Nerd Font |
| 2: Core SDKs | Node.js, Python, Go, Rust, dotnet, OpenJDK |
| 3: Language Servers | 24 LSPs (clangd, gopls, rust-analyzer, pyright, ts_ls, helm_ls, docker-language-server, etc.) |
| 4: Linters & Formatters | prettier, eslint, ruff, golangci-lint, shellcheck, yamllint, hadolint, etc. |
| 5: CLI Tools | fzf, zoxide, bat, eza, lazygit, gh, ripgrep, fd, tokei, docker-compose, helm, kubectl |
| 5.25: MCP Servers | context7-mcp, playwright-mcp (via npm) |
| 5.5: Dev Tools | Neovim 0.12, VSCode, LaTeX, Claude Code CLI |
| 6: Deploy | Runs deploy.sh to copy configs (git hooks, Claude Code hooks, Neovim, WezTerm) |
| 7: Update | Runs update-all.sh to update packages and repos |

---

## Configuration

**Default Behavior (No Config Needed)**

All scripts use hardcoded defaults by default (`categories: full`, interactive prompts). Zero setup required.

**Optional Customization**

```bash
cp .dotfiles.config.yaml.example ~/.dotfiles.config.yaml
vim ~/.dotfiles.config.yaml
./bootstrap.sh  # Auto-detects config
```

**Configuration Priority**

1. Command-line flags (highest): `--categories minimal`
2. Config file (middle): `~/.dotfiles.config.yaml`
3. Hardcoded defaults (lowest): Script defaults

**Common Config Options**

| Setting | Values | Default | Description |
|----------|---------|---------|-------------|
| categories | minimal, sdk, full | full | Installation size |
| editor | nvim, vim, code, nano | (none) | Preferred editor |
| theme | gruvbox-light, etc. | (none) | Default theme |
| github_username | your username | lavantien | Git repo management |
| base_dir | path to repos | ~/dev/github | Repository location |
| auto_commit_changes | true, false | false | Auto-commit synced files |

---

## Tools Reference

This repository installs comprehensive tooling for modern development. For complete details, see [TOOLS.md](TOOLS.md).

**Quick Summary**

| Category | Count | Examples |
|----------|-------|----------|
| Language Servers | 25 | pyright, gopls, rust-analyzer, clangd, ts_ls, helm_ls, docker-compose-language-server |
| Linters | 16+ | eslint, ruff, golangci-lint, clippy, shellcheck, yamllint, hadolint |
| Formatters | 13+ | prettier, ruff, black, rustfmt, gofmt |
| Testers | 5+ | pytest, bats, busted, Pester, jest |
| CLI Tools | 13+ | fzf, zoxide, bat, eza, lazygit, gh, docker-compose, helm, kubectl |

**Supported Languages**

Bash, PowerShell, Go, Rust, Python, JavaScript/TypeScript, HTML, CSS/SCSS/SASS, Svelte, C/C++, C#, Java, PHP, Scala, Lua, Typst, Dockerfile, Docker Compose, Helm, Kubernetes YAML, YAML, TOML.

See [TOOLS.md](TOOLS.md) for the complete language tool matrix.

---

## Quality & Hooks

**Git Hooks**

Pre-commit (runs automatically before git commit):
1. Runs formatter on staged files
2. Runs linter
3. Runs type checker (if applicable)
4. Re-stages any auto-fixed files

Commit-msg (validates commit messages):
- Enforces Conventional Commits format
- Validates types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert

**Supported Languages**

| Language | Format | Lint | Type Check |
|----------|--------|------|------------|
| Go | gofmt, goimports | golangci-lint | go vet |
| Python | ruff, black | ruff | mypy |
| JS/TS | Prettier | ESLint | tsc |
| Rust | cargo fmt | clippy | cargo check |
| C/C++ | clang-format | clang-tidy | compiler |
| C# | dotnet format | Roslyn | dotnet build |
| Java | checkstyle | checkstyle | javac |
| PHP | Laravel Pint | PHPStan, Psalm | php, PHPUnit |
| Bash | shfmt | shellcheck | - |
| PowerShell | Invoke-Formatter | PSScriptAnalyzer | PSScriptAnalyzer |
| Scala | scalafmt | scalafix | scalac |
| Lua | stylua | selene | - |
| HTML/CSS | prettier | stylelint | - |
| Docker Compose/Helm/K8s | prettier | yamllint | - |
| YAML/JSON | prettier | yamllint | - |
| Dockerfile | - | hadolint | - |

**Valid Commit Messages**

```
feat(auth): add OAuth2 login support
fix(api): resolve null pointer in user service
docs(readme): update installation instructions
refactor(core): extract payment logic to separate module
test(user): add unit tests for registration flow
```

**Bypass Hooks (Emergency)**

```bash
git commit --no-verify -m "wip: emergency fix"
```

---

## Claude Code Integration

First-class support for Claude Code with quality checks, TDD enforcement, and MCP server integration.

**Global CLAUDE.md**

Deployed to `~/.claude/` for project-agnostic AI coding instructions:
- TDD workflow enforcement
- Tool usage guidelines (Repomix, Context7, Playwright)
- Context hygiene and compaction rules
- Language-specific pitfalls

**MCP Servers**

Auto-installed globally via npm during bootstrap:

| MCP | Purpose |
|-----|---------|
| context7 | Up-to-date library documentation and code examples |
| playwright | Browser automation and E2E testing |
| repomix | Pack repositories for full-context AI exploration |

**Note:** After first use of playwright, run `npx playwright install` to install browser binaries.

**Claude Code Plugins**

Use `/plugins` in Claude Code to install plugins. Add marketplaces:
- `anthropics/claude-plugins-official`
- `yamadashy/repomix`

Key plugins: `repomix`, `feature-dev`, `frontend-design`, `code-review`, `commit-commands`, `context7`, `playwright`.

**Quality Check Hooks (Auto-Registered)**

The deploy script registers a PostToolUse hook in `~/.claude/settings.json` that runs formatters, linters, and unit tests after file edits.

| Step | Description |
|------|-------------|
| 1. Format | Auto-format the edited file (gofmt, ruff, prettier, shfmt, etc.) |
| 2. Lint | Run linters (golangci-lint, eslint, shellcheck, etc.) |
| 3. Type Check | Run type checkers (tsc, mypy, go vet) |
| 4. Unit Tests | Run project tests based on detected project type |

**StatusLine (Auto-Registered)**

Custom statusline displaying: `user@hostname directory [branch] [context%] [style] [vim-mode] model`

Colors: Green (user@host), Blue (directory), Yellow (branch), Cyan (context%), Magenta (style), Red (vim-mode), White (model).

---

## Package Management

**Universal Update All**

One command to update everything:

```bash
up  # or: update
```

**Supported Package Managers (20+)**

System: APT, DNF, Pacman, Zypper, Homebrew, Snap, Flatpak, Scoop, winget, Chocolatey

Language: npm, yarn, pnpm, gup/go, cargo, rustup, pip/pip3, poetry, dotnet, composer

---

## Git Repository Management

**git-update-repos**

Fetches ALL your GitHub repositories (public and private) and keeps them synchronized.

```bash
# Update all repos in default directory (~/dev/github)
./git-update-repos.sh

# Custom base directory
./git-update-repos.sh -d ~/dev/github

# Skip syncing system instructions
./git-update-repos.sh --no-sync

# Use SSH URLs
./git-update-repos.sh -s
```

**sync-system-instructions**

Sync AI system instructions to all repos:

```bash
./sync-system-instructions.sh

# Sync + commit + push (for headless Claude Code)
./sync-system-instructions.sh -c -p
```

---

## Health & Troubleshooting

**Health Check**

```bash
./healthcheck.sh

# JSON output (for CI/CD)
./healthcheck.sh --format json
```

**Quick Troubleshooting**

| Issue | Solution |
|--------|----------|
| Git hooks not running | `git config --global core.hooksPath ~/.config/git/hooks` |
| PowerShell execution policy | `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser` |
| Neovim plugins not installing | In Neovim run `:PackUpdate` |
| zoxide not jumping | Use directories normally for a few days to let zoxide learn |

For detailed troubleshooting, see [QUICKREF.md](QUICKREF.md).

---

## Shell & Terminal

**Shell**

- zsh - Modern interactive shell with completion and correction
- oh-my-zsh - Framework for managing zsh configuration
  - Theme: half-life
  - Plugins: zsh-interactive-cd, zsh-autosuggestions, zsh-syntax-highlighting
- Configuration: `.zshrc` deployed to `~/.zshrc`

**Terminal (WezTerm)**

GPU-accelerated terminal with multipassing support.

- **Linux (Ubuntu/Debian)**: Installed via official apt repository
- **macOS**: `brew install --cask wezterm`
- **Windows**: `winget install wezterm.wezterm`

Includes IosevkaTerm Nerd Font for glyph support. Configuration deployed to `~/.config/wezterm/wezterm.lua`.

**Key Aliases**

| Alias | Command |
|-------|---------|
| up / update | Update all packages |
| z \<pattern\> | Jump to directory (zoxide) |
| gs | git status |
| gl | git log |
| lg | lazygit |

See [ARCHITECTURE.md](ARCHITECTURE.md) for system architecture details.

---

## Additional Documentation

| Document | Purpose |
|----------|---------|
| [TOOLS.md](TOOLS.md) | Complete tool breakdown and language matrix |
| [TESTING.md](TESTING.md) | Test suite and coverage details |
| [ARCHITECTURE.md](ARCHITECTURE.md) | System architecture and diagrams |
| [HISTORY.md](HISTORY.md) | Legacy file museum |
| [QUICKREF.md](QUICKREF.md) | Quick reference card and common tasks |
| [BRIDGE.md](BRIDGE.md) | Bridge approach and configuration system |

## Updating

```bash
cd ~/dev/dotfiles
git pull
./bootstrap.sh  # or .\bootstrap.ps1 on Windows
source ~/.zshrc  # or . $PROFILE on Windows
```

## License

MIT
