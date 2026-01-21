# Universal Dotfiles

[![Security](https://img.shields.io/badge/security-reviewed-brightgreen)](#security) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
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

Tested on Ubuntu 26.04 LTS, Fedora, Arch Linux, openSUSE, macOS, and Windows 11.

**Intelligent Automation**

- Auto-detection of platform, tools, and project types
- Graceful fallbacks when tools are missing
- OneDrive-aware on Windows
- **Idempotent**: safe to run multiple times - skips existing tools, auto-corrects package sources

**What Gets Installed**

| Category               | Tools                                                                                                |
| ---------------------- | ---------------------------------------------------------------------------------------------------- |
| **Package Managers**   | Homebrew (Linux/macOS), Scoop (Windows), apt/dnf/pacman (Linux)                                      |
| **SDKs**               | Node.js, Python, Go, Rust (rustup), Bun, dotnet, OpenJDK                                                  |
| **Language Servers**   | 19 servers - see [TOOLS.md](TOOLS.md)                                                                |
| **Linters/Formatters** | prettier, eslint, ruff, black, golangci-lint, clippy, shellcheck, yamllint, hadolint, etc.           |
| **CLI Tools**          | fzf, zoxide, bat, eza, lazygit, gh, ripgrep, fd, tokei, btop, repomix, docker-compose, helm, kubectl |
| **Shell**              | zsh, oh-my-zsh (half-life theme, plugins: autosuggestions, syntax-highlighting, interactive-cd)      |
| **Terminal**           | WezTerm (GPU-accelerated, IosevkaTerm Nerd Font)                                                     |

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

**Idempotency & Safe Re-runs**

The bootstrap script is fully idempotent - running it multiple times is safe and recommended. Each run:

- **Detects existing installations** - skips tools already present
- **Auto-corrects package sources** - migrates apt/npm/cargo packages to brew when available
- **Fixes broken states** - repairs dpkg interrupts and broken dependencies
- **Updates existing tools** - runs update-all.sh at the end

Example output from a fully bootstrapped Windows system (71 tools skipped, 1 new install):

<details>
<summary>Click to expand full bootstrap output</summary>

```
 lavantien@savaka-station ~\....\dotfiles  main  .\bootstrap.ps1 -y
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

[STEP] Checking Go...
[OK] go (up to date)
[STEP] Checking Rust...
[INFO] info: syncing channel updates for 'stable-x86_64-pc-windows-msvc'
[INFO] info: checking for self-update
[INFO]   stable-x86_64-pc-windows-msvc unchanged - rustc 1.92.0 (ded5c06cf 2025-12-08)
[INFO] info: cleaning up downloads & tmp directories
[OK] rust (updated)
[STEP] Checking dotnet SDK...
[OK] dotnet (up to date)
[STEP] Checking Bun...
[OK] bun (up to date)
[STEP] Checking OpenJDK...
[OK] OpenJDK (up to date)
[OK] SDKs installation complete

==== Phase 3: Language Servers ====

[STEP] Checking clangd...
[OK] clangd (up to date)
[STEP] Checking gopls...
[OK] gopls (up to date)
[STEP] Checking pyright...
[OK] pyright (up to date)
[STEP] Checking typescript-language-server...
[OK] typescript-language-server (up to date)
[STEP] Checking vscode-html-language-server...
[OK] vscode-html-language-server (up to date)
[STEP] Checking vscode-css-language-server...
[OK] vscode-css-language-server (up to date)
[STEP] Checking svelte-language-server...
[OK] svelte-language-server (up to date)
[STEP] Checking bash-language-server...
[OK] bash-language-server (up to date)
[STEP] Checking yaml-language-server...
[OK] yaml-language-server (up to date)
[STEP] Checking lua-language-server...
[OK] lua-language-server (up to date)
[STEP] Checking csharp-ls...
[OK] csharp-ls (up to date)
[STEP] Checking docker-langserver...
[OK] docker-langserver (up to date)
[STEP] Checking tombi...
[OK] tombi (up to date)
[STEP] Checking tinymist...
[OK] tinymist (up to date)
[OK] Language servers installation complete

==== Phase 4: Linters & Formatters ====

[STEP] Checking prettier...
[OK] prettier (up to date)
[STEP] Checking eslint...
[OK] eslint (up to date)
[STEP] Checking stylelint...
[OK] stylelint (up to date)
[STEP] Checking svelte-check...
[OK] svelte-check (up to date)
[STEP] Checking repomix...
[OK] repomix (up to date)
[STEP] Checking ruff...
[OK] ruff (up to date)
[STEP] Checking black...
[OK] black (up to date)
[STEP] Checking isort...
[OK] isort (up to date)
[STEP] Checking mypy...
[OK] mypy (up to date)
[STEP] Checking pytest...
[OK] pytest (up to date)
[STEP] Checking gup...
[OK] gup (up to date)
[STEP] Checking goimports...
[OK] goimports (up to date)
[STEP] Checking golangci-lint...
[OK] golangci-lint (up to date)
[STEP] Checking shellcheck...
[OK] shellcheck (up to date)
[STEP] Checking shfmt...
[OK] shfmt (up to date)
[STEP] Checking cppcheck...
[OK] cppcheck (up to date)
[STEP] Checking scalafmt...
[OK] scalafmt (up to date)
[STEP] Checking scalafix...
[OK] scalafix (up to date)
[STEP] Checking metals...
[OK] metals (up to date)
[STEP] Checking stylua...
[OK] stylua (up to date)
[STEP] Checking selene...
[OK] selene (up to date)
[OK] Linters & formatters installation complete

==== Phase 5: CLI Tools ====

[STEP] Checking fzf...
[OK] fzf (up to date)
[STEP] Checking zoxide...
[OK] zoxide (up to date)
[STEP] Checking bat...
[OK] bat (up to date)
[STEP] Checking eza...
[OK] eza (up to date)
[STEP] Checking lazygit...
[OK] lazygit (up to date)
[STEP] Checking gh...
[OK] gh (up to date)
[STEP] Checking ripgrep...
[OK] ripgrep (up to date)
[STEP] Checking fd...
[OK] fd (up to date)
[STEP] Checking tokei...
[OK] tokei (up to date)
[STEP] Checking difftastic...
[OK] difftastic (up to date)
[STEP] Checking btop-lhm...
[OK] btop-lhm (up to date)
[STEP] Checking bats...
[OK] bats (up to date)
[STEP] Checking Pester...
[OK] Pester (up to date)
[OK] CLI tools installation complete

==== Phase 5.25: MCP Servers ====

[STEP] Checking tree-sitter-cli...
[OK] tree-sitter-cli (up to date)
[STEP] Checking context7 MCP server...
[OK] context7 MCP server (up to date)
[STEP] Checking playwright MCP server...
[OK] playwright MCP server (up to date)
[STEP] Checking repomix...
[OK] repomix (up to date)
[OK] MCP server installation complete

==== Phase 5.5: Development Tools ====

[STEP] Checking VS Code...
[OK] vscode (up to date)
[STEP] Checking Visual Studio...
[OK] visual-studio (up to date)
[STEP] Checking LLVM...
[OK] llvm (up to date)
[STEP] Checking LaTeX...
[OK] latex (up to date)
[INFO] Claude Code CLI already at latest version (2.1.11)
[INFO] OpenCode AI CLI already at latest version (1.1.25)
[OK] Development tools installation complete

==== Phase 6: Deploying Configurations ====

[STEP] Running deploy script...
========================================
   Windows Dotfiles Deployment
========================================
Dotfiles: C:\Users\lavantien/dev/github/dotfiles

Deploying scripts to ~/dev...
  Scripts deployed

Deploying configs...
  PowerShell profile
  Neovim config
  WezTerm config
  WezTerm background assets
  Claude configs
  Statusline registered
  OpenCode config (up to date)
  Configs deployed

========================================
           Complete!
========================================

Run from ~/dev:
  .\sync-system-instructions.ps1
  .\git-update-repos.ps1

[OK] Configurations deployed

==== Phase 7: Updating All Repositories and Packages ====

[INFO] Running update-all script (this may take several minutes)...

========================================
   Native Windows Update All
========================================

[20:05:27] Checking package managers...
  Scoop
  winget
  Skipped: Chocolatey not found

[20:05:28] SCOOP
Latest versions for all apps are installed! For more information try 'scoop status'
  scoop

[20:05:28] WINGET
  Updating all winget packages...
  Installing dependencies:
  Successfully installed. Restart the application to complete the upgrade.
  Downloading https://aka.ms/windowsappsdk/1.8/1.8.251106002/windowsappruntimeinstall-x64.exe
  Successfully installed
  winget

[20:06:15] CHOCOLATEY
  Skipped: Chocolatey not found

[20:06:15] NPM (Node.js global packages)
  Updating npm itself...
  changed 1053 packages in 34s
  npm

[20:06:52] PNPM
  Skipped: pnpm not found

[20:06:52] BUN
  bun

[20:06:53] YARN
  yarn (up to date)
True

[20:06:55] GUP (Go global packages)
  gup (up to date)
True

[20:06:55] GO (update all)
  Skipped: go (using gup instead)

[20:06:55] CARGO (Rust packages)
      Polling registry 'https://index.crates.io/'...
  Package       Installed  Latest   Needs update
  cargo-update  v18.0.0    v18.0.0  No
  codebook-lsp  v0.3.28    v0.3.28  No
  tokei         v14.0.0    v14.0.0  No
  No packages need updating.
  Overall updated 0 packages.
  cargo
True

[20:06:55] RUSTUP
    stable-x86_64-pc-windows-msvc unchanged - rustc 1.92.0 (ded5c06cf 2025-12-08)
  rustup
True

[20:06:56] DOTNET TOOLS
  Skipped: No dotnet tools installed

[20:06:56] PIP (Python packages)
  pip (up to date)

[20:07:01] POETRY
  Skipped: poetry not found

========================================
           Summary
========================================
 Completed:   9
 Skipped:     Skipped: 5
 Duration:    94s
========================================
[OK] Update complete

==== Bootstrap Summary ====

Installed: 0

Skipped: 74
  - git (version control)
  - scoop (package manager)
  - git autocrlf already configured
  - GitHub SSH key already in known_hosts
  - wezterm (terminal emulator)
  - node (Node.js runtime)
  - python (Python runtime)
  - go (Go runtime)
  - dotnet (.NET SDK)
  - bun (JavaScript runtime)
  - OpenJDK (Java development)
  - clangd (C++ language server)
  - gopls (Go language server)
  - rust-analyzer (Rust LSP)
  - pyright (Python language server)
  - typescript-language-server (TypeScript language server)
  - vscode-html-language-server (HTML language server)
  - vscode-css-language-server (CSS language server)
  - svelte-language-server (Svelte language server)
  - bash-language-server (Bash language server)
  - yaml-language-server (YAML language server)
  - lua-language-server (Lua language server)
  - csharp-ls (C# language server)
  - docker-langserver (Dockerfile language server)
  - tombi (TOML language server)
  - tinymist (Typst language server)
  - prettier (Code formatter)
  - eslint (JavaScript linter)
  - stylelint (CSS linter)
  - svelte-check (Svelte type checker)
  - repomix (Repository packager)
  - ruff (Python linter/formatter)
  - black (Python formatter)
  - isort (Python import sorter)
  - mypy (Python type checker)
  - pytest (Python testing)
  - gup (Go package updater)
  - goimports (Go import formatter)
  - golangci-lint (Go linter)
  - shellcheck (Shell script linter)
  - shfmt (Shell formatter)
  - cppcheck (C++ static analyzer)
  - coursier (JVM dependency manager)
  - scalafmt (Scala formatter)
  - coursier (JVM dependency manager)
  - scalafix (Scala linter)
  - coursier (JVM dependency manager)
  - metals (Scala language server)
  - stylua (Lua formatter)
  - selene (Lua linter)
  - fzf (Fuzzy finder)
  - zoxide (Smart cd)
  - bat (Cat alternative)
  - eza (Ls alternative)
  - lazygit (Git TUI)
  - gh (GitHub CLI)
  - rg (Grep alternative)
  - fd (Find alternative)
  - tokei (Code stats)
  - difft (Diff tool)
  - btop (System monitor)
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
</details>

Key idempotency features shown above:

- `[INFO] Claude Code CLI already at latest version (2.1.11)` - version-aware detection skips up-to-date tools
- `[INFO] OpenCode AI CLI update available: 1.1.23 -> 1.1.25` - detects and installs only outdated tools
- `Installed: 1, Skipped: 71` - summary shows exactly what changed
- Deploy phase shows `Neovim config` and `WezTerm config` being deployed to their correct locations

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
chore(deps): bump dependencies for security patches
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

**Deploy Script Behavior**

The deploy script (`deploy.ps1` / `deploy.sh`) handles configurations as follows:

| Config | Behavior |
| ------ | -------- |
| PowerShell, Neovim, WezTerm | Overwrites existing config |
| Claude Code (`.claude/`) | Overwrites existing config |
| OpenCode (`~/.config/opencode/opencode.json`) | **Merges** MCP servers from dotfiles into existing config |

OpenCode merge behavior:
- If `opencode.json` doesn't exist, creates it from dotfiles
- If exists, adds missing MCP servers from dotfiles
- Updates existing MCP servers if dotfiles config differs
- Preserves any existing settings not managed by dotfiles

Output messages indicate the action taken:
- `OpenCode config (created)` - New config created
- `OpenCode config (merged N server(s))` - Servers added/updated
- `OpenCode config (up to date)` - No changes needed

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
