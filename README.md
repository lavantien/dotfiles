# Universal Dotfiles

![Coverage](coverage-badge.svg) [![Security](https://img.shields.io/badge/security-reviewed-brightgreen)](#security) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-blue)](https://github.com/lavantien/dotfiles)

Production-grade dotfiles for Windows 11, Linux (Ubuntu/Fedora/Arch), and macOS. Auto-detecting, gracefully degrading, fully vibecoding-enabled with **19 LSP servers**, **32 Treesitter parsers**, **40+ tools**, TDD enforcement, comprehensive Git hooks, and Claude Code integration.

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

> **Required Clone Location**: This repository **MUST** be cloned to `~/dev/github/dotfiles`. Several scripts (including `sync-system-instructions` and `git-update-repos`) depend on this exact path to function correctly.

### Dotfiles Installation

**For Docker/Kubernetes setup**, see [DOCKER_K8S.md](DOCKER_K8S.md).

**Fresh Ubuntu Machine (includes git installation)**

```bash
# Install git first (if not already installed)
sudo apt update && sudo apt install -y git

# Clone this repository
git clone https://github.com/lavantien/dotfiles.git ~/dev/github/dotfiles

# Change to the directory and make scripts executable (one-time setup)
cd ~/dev/github/dotfiles
chmod +x allow.sh && ./allow.sh

# Run bootstrap
./bootstrap.sh

# Set zsh as default shell and restart
chsh -s $(which zsh)
exec zsh  # or source ~/.zshrc
```

**Existing Setup (git already installed)**

**Linux**

```bash
git clone https://github.com/lavantien/dotfiles.git ~/dev/github/dotfiles
cd ~/dev/github/dotfiles
chmod +x allow.sh && ./allow.sh
./bootstrap.sh
chsh -s $(which zsh)  # Set zsh as default shell
exec zsh  # or source ~/.zshrc
```

**macOS**

```bash
git clone https://github.com/lavantien/dotfiles.git ~/dev/github/dotfiles
cd ~/dev/github/dotfiles
chmod +x allow.sh && ./allow.sh
./bootstrap.sh
exec zsh  # or source ~/.zshrc
```

**Windows (PowerShell 7+)**

```powershell
git clone https://github.com/lavantien/dotfiles.git $HOME/dev/github/dotfiles
cd $HOME/dev/github/dotfiles
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

| Script                       | Platform | Purpose                                                                                |
| ---------------------------- | -------- | -------------------------------------------------------------------------------------- |
| **bootstrap**                | Both    | Initial setup - installs package managers, SDKs, LSPs, linters, tools, deploys configs |
| **deploy**                   | Both    | Deploy configuration files (Neovim, git hooks, shell aliases, Claude Code hooks)       |
| **update-all**               | Both    | Update all package managers and system packages (20+ managers supported)               |
| **git-update-repos**         | Both    | Clone/update ALL GitHub repos via gh CLI, optionally sync system instructions          |
| **sync-system-instructions** | Both    | Sync AI system instructions (CLAUDE.md, AGENTS.md, GEMINI.md, RULES.md) to all repos   |
| **healthcheck**              | Both    | Check system health - verify tools installed, configs in place, git hooks working      |
| **backup**                   | Both    | Create timestamped backup before major changes                                         |
| **restore**                  | Both    | Restore from a previous backup (`--list-backups` to see available)                     |
| **uninstall**                | Both    | Remove deployed configs (keeps installed packages)                                     |

Windows uses `.ps1` scripts (pure PowerShell 7), Linux/macOS uses `.sh` scripts (bash). Both platforms have functionally equivalent scripts with appropriate syntax for their shell.

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

| Category               | Tools                                                                                                |
| ---------------------- | ---------------------------------------------------------------------------------------------------- |
| **Package Managers**   | Homebrew (Linux/macOS), Scoop (Windows), apt/dnf/pacman (Linux)                                      |
| **SDKs**               | Node.js, Python, Go, Rust (rustup), dotnet, OpenJDK                                                  |
| **Language Servers**   | 19 servers - see [TOOLS.md](TOOLS.md)                                                                |
| **Linters/Formatters** | prettier, eslint, ruff, black, golangci-lint, clippy, shellcheck, yamllint, hadolint, etc.           |
| **CLI Tools**          | fzf, zoxide, bat, eza, lazygit, gh, ripgrep, fd, tokei, btop, repomix, docker-compose, helm, kubectl |
| **Shell**              | zsh, oh-my-zsh (half-life theme, plugins: autosuggestions, syntax-highlighting, interactive-cd)      |
| **Terminal**           | WezTerm (GPU-accelerated, IosevkaTerm Nerd Font)                                                     |
| **Testing**            | bats, busted, pytest, Pester, kcov                                                                   |

**Installation Categories**

| Category | Description                                   |
| -------- | --------------------------------------------- |
| minimal  | Package managers + git + CLI tools only       |
| sdk      | Minimal + programming language SDKs           |
| full     | SDK + all LSPs + linters/formatters (default) |

**Quality Assurance**

- Conventional commits enforcement via git commit-msg hook
- Pre-commit hooks that auto-format and lint for 19+ languages
- Claude Code quality hooks for real-time format/lint/type-check after file writes
- 2,200+ automated tests (PowerShell + Bash)
- Hook integrity tests prevent regression

**Idempotency & Safe Re-runs**

The bootstrap script is fully idempotent - running it multiple times is safe and recommended. Each run:

- **Detects existing installations** - skips tools already present
- **Auto-corrects package sources** - migrates apt/npm/cargo packages to brew when available
- **Fixes broken states** - repairs dpkg interrupts and broken dependencies
- **Updates existing tools** - runs update-all.sh at the end

Example output from a fully bootstrapped Windows system (72 tools skipped, 0 new installs):

```
 lavantien@savaka-station ~\..\dotfiles  main   .\bootstrap.ps1 -y
[INFO] Config loaded from C:\Users\lavantien\.dotfiles.config.yaml

==== Bootstrap Windows Development Environment ====

Options:
  Interactive: False
  Dry Run: False
  Categories: full
  Skip Update: False

[STEP] Ensuring development directories are in PATH...

==== Phase 1: Foundation ====

[INFO] Repo .gitattributes will enforce line endings
[OK] Foundation complete

==== Phase 2: Core SDKs ====

[OK] SDKs installation complete

==== Phase 3: Language Servers ====

[OK] Language servers installation complete

==== Phase 4: Linters & Formatters ====

[OK] Linters & formatters installation complete

==== Phase 5: CLI Tools ====

[OK] CLI tools installation complete

==== Phase 5.25: MCP Servers ====

[OK] MCP server installation complete

==== Phase 5.5: Development Tools ====

[INFO] Claude Code CLI already at latest version (2.1.9)
[INFO] OpenCode AI CLI already at latest version (1.1.23)
[OK] Development tools installation complete

==== Phase 6: Deploying Configurations ====

[STEP] Running deploy script...
[OK] Configurations deployed

==== Phase 7: Updating All Repositories and Packages ====

[INFO] Running update-all script (this may take several minutes)...

========================================
   Native Windows Update All
========================================

[10:54:57] Checking package managers...
  Scoop
  winget
  Skipped: Chocolatey not found

[10:54:57] SCOOP
Updating Scoop...
Updating Buckets...
Scoop was updated successfully!
  error: cannot pull with rebase: You have unstaged changes.
  error: Please commit or stash them.
  System.Management.Automation.RemoteException
  Another git process seems to be running in this repository, e.g.
  an editor opened by 'git commit'. Please make sure all processes
Latest versions for all apps are installed! For more information try 'scoop status'
  Up to date
True

[10:54:59] WINGET
  Updating all winget packages...
  Installing dependencies:
  Downloading https://dl.pstmn.io/download/version/11.80.4/windows_64
  Successfully installed
  Downloading https://curl.se/windows/dl-8.18.0_1/curl-8.18.0_1-win64-mingw.zip
  Successfully installed
  Downloading https://download.kde.org/stable/kdenlive/25.12/windows/kdenlive-25.12.1.exe
  Successfully installed
  Downloading https://td.telegram.org/tx64/tsetup-x64.6.4.2.exe
  Successfully installed
  Downloading https://vscode.download.prss.microsoft.com/dbazure/download/stable/94e8ae2b28cb5cc932b86e1070569c4463565c37/VSCodeUserSetup-x64-1.108.0.exe
  winget

[10:58:10] CHOCOLATEY
  Skipped: Chocolatey not found

[10:58:10] NPM (Node.js global packages)
  Updating npm itself...
  changed 950 packages in 47s
  npm

[10:59:09] PNPM
  Skipped: pnpm not found

[10:59:09] YARN
  Up to date
True

[10:59:10] GUP (Go global packages)
  Up to date
True

[10:59:10] GO (update all)
  Skipped: go (using gup instead)

[10:59:10] CARGO (Rust packages)
      Polling registry 'https://index.crates.io/'...
  Package       Installed  Latest   Needs update
  cargo-update  v18.0.0    v18.0.0  No
  codebook-lsp  v0.3.28    v0.3.28  No
  tokei         v14.0.0    v14.0.0  No
  No packages need updating.
  Overall updated 0 packages.
  cargo
True

[10:59:11] RUSTUP
    stable-x86_64-pc-windows-msvc unchanged - rustc 1.92.0 (ded5c06cf 2025-12-08)
  rustup
True

[10:59:12] DOTNET TOOLS
  Skipped: No dotnet tools installed

[10:59:12] PIP (Python packages)
  Up to date

[10:59:17] POETRY
  Skipped: poetry not found

========================================
           Summary
========================================
 Completed:   8
 Skipped:     Skipped: 5
 Duration:    260s
========================================
[OK] Update complete

==== Bootstrap Summary ====

Installed: 0

Skipped: 72
  - git (version control)
  - scoop (package manager)
  - git autocrlf already configured
  - GitHub SSH key already in known_hosts
  - node (Node.js runtime)
  - python (Python runtime)
  - go (Go runtime)
  - rust (Rust toolchain)
  - dotnet (.NET SDK)
  - OpenJDK (Java development)
  - clangd (C/C++ LSP)
  - gopls (Go LSP)
  - rust-analyzer (Rust LSP)
  - pyright (Python LSP)
  - typescript-language-server (TypeScript LSP)
  - vscode-html-language-server (vscode-html-language-server)
  - vscode-css-language-server (vscode-css-language-server)
  - svelte-language-server (svelte-language-server)
  - bash-language-server (bash-language-server)
  - yaml-language-server (YAML LSP)
  - lua-language-server (Lua LSP)
  - csharp-ls (C# LSP)
  - jdtls (Java LSP)
  - docker-langserver (Docker LSP)
  - tombi (TOML LSP)
  - tinymist (Nim LSP)
  - prettier (code formatter)
  - eslint (JavaScript linter)
  - stylelint (stylelint)
  - svelte-check (svelte-check)
  - repomix (repomix)
  - ruff (Python linter)
  - black (Python formatter)
  - isort (Python import sorter)
  - mypy (Python type checker)
  - pytest (pytest)
  - goimports (Go import organizer)
  - golangci-lint (Go linter)
  - shellcheck (Shell script analyzer)
  - shfmt (Shell script formatter)
  - cppcheck (cppcheck)
  - coursier (JVM dependency manager)
  - scalafmt (Scala formatter)
  - coursier (JVM dependency manager)
  - scalafix (scalafix)
  - coursier (JVM dependency manager)
  - metals (metals)
  - stylua (stylua)
  - selene (selene)
  - fzf (fuzzy finder)
  - zoxide (smart directory navigation)
  - bat (enhanced cat)
  - eza (enhanced ls)
  - lazygit (Git TUI)
  - gh (GitHub CLI)
  - rg (text search)
  - fd (file finder)
  - tokei (code stats)
  - difft (diff viewer)
  - btop (btop)
  - bats (Bash testing)
  - Pester (PowerShell testing)
  - tree-sitter-cli (Treesitter parser compiler)
  - context7-mcp (documentation lookup)
  - playwright-mcp (browser automation)
  - repomix (repository packer (uses npx -y repomix --mcp))
  - vscode (code editor)
  - visual-studio (full IDE)
  - llvm (C/C++ toolchain)
  - latex (document preparation)
  - claude-code (AI CLI)
  - opencode (AI CLI)

=== Bootstrap Complete ===
All tools are available in the current session.
For new shells, PATH has been updated automatically.
```

Key idempotency features shown above:

- `[INFO] Claude Code CLI already at latest version (2.1.9)` - version-aware detection
- `[INFO] OpenCode AI CLI already at latest version (1.1.23)` - version-aware detection
- `Installed: 0, Skipped: 72` - summary shows all tools already present
- Update phase skips packages that are current: `Skipped: claude-code already at latest version`

---

## Bootstrap & Options

**Command-Line Options**

| Option          | Bash               | PowerShell        | Default                 |
| --------------- | ------------------ | ----------------- | ----------------------- |
| Non-interactive | `-y`, `--yes`      | `-Y`              | Prompt for confirmation |
| Dry-run         | `--dry-run`        | `-DryRun`         | Install everything      |
| Categories      | `--categories sdk` | `-Categories sdk` | full                    |
| Skip update     | `--skip-update`    | `-SkipUpdate`     | Update package managers |
| Verbose         | `--verbose`        | `-VerboseMode`    | Show detailed output    |
| Help            | `-h`, `--help`     | `-Help`           | Show help               |

**Bootstrap Script Structure**

The repository contains bootstrap scripts at both locations:

- **Root level** (`./bootstrap.sh`, `./bootstrap.ps1`) - Lightweight wrappers
- **`bootstrap/` directory** (`bootstrap/bootstrap.sh`, `bootstrap/bootstrap.ps1`) - Full implementation

Both work identically. The root-level scripts provide convenience, while the `bootstrap/` directory contains the actual implementation logic.

**Bootstrap Phases**

| Phase                   | Tools                                                                                         |
| ----------------------- | --------------------------------------------------------------------------------------------- |
| 1: Foundation           | Package managers, git, WezTerm (Linux), IosevkaTerm Nerd Font                                 |
| 2: Core SDKs            | Node.js, Python, Go, Rust, dotnet, OpenJDK                                                    |
| 3: Language Servers     | 19 LSPs (clangd, gopls, rust-analyzer, pyright, ts_ls, helm_ls, docker-language-server, etc.) |
| 4: Linters & Formatters | prettier, eslint, ruff, golangci-lint, shellcheck, yamllint, hadolint, etc.                   |
| 5: CLI Tools            | fzf, zoxide, bat, eza, lazygit, gh, ripgrep, fd, tokei, docker-compose, helm, kubectl         |
| 5.25: MCP Servers       | context7-mcp, playwright-mcp (via npm)                                                        |
| 5.5: Dev Tools          | Neovim 0.12, VSCode, LaTeX, Claude Code CLI                                                   |
| 6: Deploy               | Runs deploy.sh to copy configs (git hooks, Claude Code hooks, Neovim, WezTerm)                |
| 7: Update               | Runs update-all.sh to update packages and repos                                               |

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

| Setting           | Values                                    | Default      | Description              |
| ----------------- | ----------------------------------------- | ------------ | ------------------------ |
| categories        | minimal, sdk, full                        | full         | Installation size        |
| editor            | nvim, vim, code, nano                     | (none)       | Preferred editor         |
| theme             | rose-pine, rose-pine-dawn, rose-pine-moon | (none)       | Default theme            |
| github_username   | your username                             | lavantien    | Git repo management      |
| base_dir          | path to repos                             | ~/dev/github | Repository location      |
| auto_commit_repos | true, false                               | false        | Auto-commit synced files |

---

## Tools Reference

This repository installs comprehensive tooling for modern development. For complete details, see [TOOLS.md](TOOLS.md).

**Quick Summary**

| Category         | Count | Examples                                                                              |
| ---------------- | ----- | ------------------------------------------------------------------------------------- |
| Language Servers | 19    | pyright, gopls, rust-analyzer, clangd, ts_ls, helm_ls, docker-compose-language-server |
| Linters          | 20+   | eslint, ruff, golangci-lint, clippy, shellcheck, yamllint, hadolint, mypy             |
| Formatters       | 17+   | prettier, ruff, black, rustfmt, gofmt, shfmt, scalafmt                                |
| Testers          | 9+    | pytest, bats, busted, Pester, jest, catch2, cargo test                                |
| CLI Tools        | 15+   | fzf, zoxide, bat, eza, lazygit, gh, docker-compose, helm, kubectl, repomix            |

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

| Language                | Format           | Lint             | Type Check       |
| ----------------------- | ---------------- | ---------------- | ---------------- |
| Go                      | gofmt, goimports | golangci-lint    | go vet           |
| Python                  | ruff, black      | ruff             | mypy             |
| JS/TS                   | Prettier         | ESLint           | tsc              |
| Rust                    | cargo fmt        | clippy           | cargo check      |
| C/C++                   | clang-format     | clang-tidy       | compiler         |
| C#                      | dotnet format    | Roslyn           | dotnet build     |
| Java                    | checkstyle       | checkstyle       | javac            |
| PHP                     | Laravel Pint     | PHPStan, Psalm   | php, PHPUnit     |
| Bash                    | shfmt            | shellcheck       | -                |
| PowerShell              | Invoke-Formatter | PSScriptAnalyzer | PSScriptAnalyzer |
| Scala                   | scalafmt         | scalafix         | scalac           |
| Lua                     | stylua           | selene           | -                |
| HTML/CSS                | prettier         | stylelint        | -                |
| Docker Compose/Helm/K8s | prettier         | yamllint         | -                |
| YAML/JSON               | prettier         | yamllint         | -                |
| Dockerfile              | -                | hadolint         | -                |

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

| MCP        | Purpose                                            |
| ---------- | -------------------------------------------------- |
| context7   | Up-to-date library documentation and code examples |
| playwright | Browser automation and E2E testing                 |
| repomix    | Pack repositories for full-context AI exploration  |

**Note:** After first use of playwright, run `npx playwright install` to install browser binaries.

**Claude Code Plugins**

Use `/plugins` in Claude Code to install plugins. Add marketplaces:

- `anthropics/claude-plugins-official`
- `yamadashy/repomix`

Key plugins: `repomix`, `feature-dev`, `frontend-design`, `code-review`, `commit-commands`, `context7`, `playwright`.

**Quality Check Hooks (Auto-Registered)**

The deploy script registers a PostToolUse hook in `~/.claude/settings.json` that runs formatters, linters, and unit tests after file edits.

| Step          | Description                                                      |
| ------------- | ---------------------------------------------------------------- |
| 1. Format     | Auto-format the edited file (gofmt, ruff, prettier, shfmt, etc.) |
| 2. Lint       | Run linters (golangci-lint, eslint, shellcheck, etc.)            |
| 3. Type Check | Run type checkers (tsc, mypy, go vet)                            |
| 4. Unit Tests | Run project tests based on detected project type                 |

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

| Platform | Script | Usage |
|----------| ------- | ----- |
| Linux/macOS | `git-update-repos.sh` | `./git-update-repos.sh -d ~/dev/github --no-sync` |
| Windows | `git-update-repos.ps1` | `.\git-update-repos.ps1 -BaseDir ~/dev/github -NoSync` |

**Parameter differences:**

| Bash | PowerShell | Description |
| ---- | ----------- | ----------- |
| `-d path` | `-BaseDir path` | Set base directory |
| `-u user` | `-Username user` | GitHub username |
| `-s` | `-UseSSH` | Use SSH URLs |
| `--no-sync` | `-NoSync` | Skip syncing system instructions |
| `-c` | `-Commit` | Auto-commit synced files |

**sync-system-instructions**

Sync AI system instructions to all repos. Reads from dotfiles (source of truth) and copies to target repos.

> **Note**: This script requires the dotfiles repository to be at `~/dev/github/dotfiles` (as per the Quick Start instructions) to locate the source instruction files.

| Platform | Script | Usage |
|----------| ------- | ----- |
| Linux/macOS | `sync-system-instructions.sh` | `./sync-system-instructions.sh -d ~/dev/git -c -p` |
| Windows | `sync-system-instructions.ps1` | `.\sync-system-instructions.ps1 -BaseDir ~/dev/git -Commit -Push` |

**Parameter differences:**

| Bash | PowerShell | Description |
| ---- | ----------- | ----------- |
| `-d path` | `-BaseDir path` | Set base directory |
| `-c` | `-Commit` | Commit changes |
| `-p` | `-Push` | Push changes after committing |

Files synced:

- `.claude/CLAUDE.md` → `CLAUDE.md` (project-specific AI instructions)
- `AGENTS.md` (agent definitions)
- `GEMINI.md` (Gemini-specific instructions)
- `RULES.md` (coding rules and standards)

---

## Health & Troubleshooting

**Health Check**

```bash
./healthcheck.sh

# JSON output (for CI/CD)
./healthcheck.sh --format json
```

**Quick Troubleshooting**

| Issue                         | Solution                                                               |
| ----------------------------- | ---------------------------------------------------------------------- |
| Git hooks not running         | `git config --global core.hooksPath ~/.config/git/hooks`               |
| PowerShell execution policy   | `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser` |
| Neovim plugins not installing | In Neovim run `:PackUpdate`                                            |
| zoxide not jumping            | Use directories normally for a few days to let zoxide learn            |

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

| Alias         | Command                    |
| ------------- | -------------------------- |
| up / update   | Update all packages        |
| z \<pattern\> | Jump to directory (zoxide) |
| gs            | git status                 |
| gl            | git log                    |
| lg            | lazygit                    |

See [ARCHITECTURE.md](ARCHITECTURE.md) for system architecture details.

---

## Additional Documentation

| Document                           | Purpose                                     |
| ---------------------------------- | ------------------------------------------- |
| [TOOLS.md](TOOLS.md)               | Complete tool breakdown and language matrix |
| [TESTING.md](TESTING.md)           | Test suite and coverage details             |
| [ARCHITECTURE.md](ARCHITECTURE.md) | System architecture and diagrams            |
| [DOCKER_K8S.md](DOCKER_K8S.md)     | Docker Desktop and minikube setup           |
| [HOOKS.md](HOOKS.md)               | Git and Claude Code hooks configuration     |
| [HISTORY.md](HISTORY.md)           | Legacy file museum                          |
| [QUICKREF.md](QUICKREF.md)         | Quick reference card and common tasks       |
| [BRIDGE.md](BRIDGE.md)             | Bridge approach and configuration system    |

## Updating

```bash
# Linux/macOS
cd ~/dev/github/dotfiles
git pull
./bootstrap.sh
source ~/.zshrc

# Windows
cd ~/dev/github/dotfiles
git pull
.\bootstrap.ps1
. $PROFILE
```

## License

MIT
