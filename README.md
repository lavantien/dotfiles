# Universal Dotfiles

[![Security](https://img.shields.io/badge/security-reviewed-brightgreen)](#security) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Linux-blue%20%7C%20platform-Windows)](https://github.com/lavantien/dotfiles)

Production-grade portable one-click dotfiles for Linux and Windows 11 software engineering environment.

Auto-detecting, auto-bootstraping, idempotent, gracefully degrading, full terminal tooling, fully vibecoding-enabled.

---

## Core Features

Editor & Terminal
- Neovim 0.12+ with built-in package manager, LSP/Treesitter config, and native completion
- WezTerm GPU-accelerated terminal (IosevkaTerm Nerd Font)
- Rose Pine theme across all configs

Development Tools
- 20 LSP servers for complete language intelligence
- 30 Treesitter parsers for advanced syntax highlighting
- 40+ CLI tools for modern development workflows (fzf, yazi, zoxide, bat, eza, lazygit, gh, ripgrep, fd, tokei, btop, repomix, docker-compose, helm, kubectl)

AI-Native Agentic Development
- Full support for Claude Code and OpenCode
- 4 MCP servers: context7, playwright, repomix, serena
- Auto-detect & trigger format/lint/type-check: Git pre-commit/commit-msg + Claude Code PostToolUse and Stop hooks
- System instruction sync across all repos (CLAUDE.md, AGENTS.md, GEMINI.md, RULES.md)

Automation & Safety
- Idempotent bootstrap and update-all (safe to run multiple times)
- Auto-detection with graceful degradation
- OneDrive-aware on Windows
- Timestamped backup/restore before major changes

Tested Platforms
- Linux (Ubuntu 26.04+)
- Windows 11 (PowerShell 7+)

---

## Quick Start

> **Required Clone Location**: This repository **MUST** be cloned to `~/dev/github/dotfiles`.
>
> **For Docker/Kubernetes setup**, see [DOCKER_K8S.md](DOCKER_K8S.md).

### Linux

```bash
git clone https://github.com/lavantien/dotfiles.git ~/dev/github/dotfiles
cd ~/dev/github/dotfiles
chmod +x allow.sh && ./allow.sh
./bootstrap.sh
chsh -s $(which zsh)
exec zsh
```

### macOS

```bash
git clone https://github.com/lavantien/dotfiles.git ~/dev/github/dotfiles
cd ~/dev/github/dotfiles
chmod +x allow.sh && ./allow.sh
./bootstrap.sh
exec zsh
```

### Windows (PowerShell 7+)

```powershell
git clone https://github.com/lavantien/dotfiles.git $HOME/dev/github/dotfiles
cd $HOME/dev/github/dotfiles
.\bootstrap.ps1
. $PROFILE
```

### Verify Installation

```bash
which n  # Should point to nvim
which lg  # Should point to lazygit
up  # or update - runs update-all
```

---

## Available Commands

| Script | Purpose |
|--------|---------|
| **bootstrap** | Initial setup - installs package managers, SDKs, LSPs, tools, deploys configs |
| **deploy** | Deploy configuration files (Neovim, git hooks, shell, Claude Code) |
| **update-all (up)** | Update all package managers and system packages (20+ managers) |
| **git-update-repos** | Clone/update ALL GitHub repos via gh CLI, optionally sync system instructions |
| **sync-system-instructions** | Sync AI system instructions (CLAUDE.md, AGENTS.md, etc.) to all repos |
| **healthcheck** | Check system health - verify tools, configs, git hooks |
| **backup** | Create timestamped backup before major changes |
| **restore** | Restore from a previous backup |
| **uninstall** | Remove deployed configs (keeps installed packages) |

Windows uses `.ps1` scripts, Linux/macOS uses `.sh` scripts.

### Bootstrap Options

| Option | Bash | PowerShell | Default |
|--------|------|------------|---------|
| Non-interactive | `-y`, `--yes` | `-Y` | Prompt for confirmation |
| Dry-run | `--dry-run` | `-DryRun` | Install everything |
| Categories | `--categories sdk` | `-Categories sdk` | full |
| Skip update | `--skip-update` | `-SkipUpdate` | Update package managers |
| Verbose | `--verbose` | `-VerboseMode` | Show detailed output |

### Installation Categories

| Category | Description |
|----------|-------------|
| minimal | Package managers + git + CLI tools only |
| sdk | Minimal + programming language SDKs |
| full | SDK + all LSPs + linters/formatters (default) |

### Configuration (Optional)

All scripts use hardcoded defaults by default (`categories: full`, interactive prompts).

```bash
cp .dotfiles.config.yaml.example ~/.dotfiles.config.yaml
vim ~/.dotfiles.config.yaml
./bootstrap.sh  # Auto-detects config
```

**Configuration Priority**: Command-line flags > Config file > Hardcoded defaults

| Setting | Values | Default |
|---------|--------|---------|
| categories | minimal, sdk, full | full |
| editor | nvim, vim, code, nano | (none) |
| theme | rose-pine, rose-pine-dawn, rose-pine-moon | (none) |
| github_username | your github username | lavantien |
| base_dir | path to git repos | ~/dev/github |
| auto_commit_repos | true, false | false |

### Health & Troubleshooting

```bash
./healthcheck.sh

# JSON output (for CI/CD)
./healthcheck.sh --format json
```

| Issue | Solution |
|-------|----------|
| Git hooks not running | `git config --global core.hooksPath ~/.config/git/hooks` |
| PowerShell execution policy | `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser` |
| Neovim plugins not installing | In Neovim run `:PackUpdate` |
| zoxide not jumping | Use directories normally for a few days to let zoxide learn |

---

## Complete Tools/Packages Matrix

| Language | LSP | Tester | Formatter | Linter | Type Check |
|----------|-----|--------|-----------|--------|------------|
| Bash | bashls | bats | shfmt | shellcheck | - |
| PowerShell | powershell_es | Pester | Invoke-Formatter | PSScriptAnalyzer | PSScriptAnalyzer |
| Go | gopls | go test | gofmt, goimports | golangci-lint | go vet |
| Rust | rust-analyzer | cargo test | rustfmt | clippy | cargo check |
| Python | pyright | pytest | ruff, black | ruff | mypy |
| JavaScript/TypeScript | ts_ls | jest | prettier | eslint | tsc |
| HTML | html | - | prettier | - | - |
| CSS/SCSS/SASS | cssls | - | prettier | stylelint | - |
| Svelte | svelte | - | prettier | - | svelte-check |
| C/C++ | clangd | Catch2 | clang-format | clang-tidy, cppcheck | compiler |
| C# | csharp_ls | dotnet test | dotnet format | Roslyn analyzers | dotnet build |
| Java | jdtls (Linux/macOS only) | JUnit | checkstyle | checkstyle | javac |
| PHP | intelephense | php, PHPUnit | pint | PHPStan, Psalm | - |
| Scala | metals | ScalaTest | scalafmt | scalafix | scalac |
| Lua | lua_ls | busted | stylua | selene | - |
| Typst | tinymist | built-in | tinymist | tinymist | - |
| Dockerfile | docker_ls | - | - | hadolint | - |
| Docker Compose | docker_ls | - | prettier | - | - |
| Helm | helm_ls | - | prettier | - | - |
| Kubernetes YAML | yamlls | kubectl | prettier | yamllint | - |
| YAML | yamlls | - | prettier | yamllint | - |
| TOML | tombi | - | taplo | - | - |

### CLI Tools

fzf, yazi, zoxide, bat, eza, lazygit, gh, ripgrep, fd, tokei, btop, repomix, docker-compose, helm, kubectl

### MCP Servers (Claude Code & OpenCode)

context7, playwright, repomix, serena

---

## Hooks & Config Merging

### Git Hooks

**Pre-commit**: auto-format, lint, type-check, re-stage fixed files

**Commit-msg**: enforce Conventional Commits (feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert)

Platform-specific: `.sh` for Linux/macOS, `.ps1` for Windows

### Claude Code Hooks

**PostToolUse** and **Stop** hooks run format/lint/type-check after file edits and at session end. Auto-registered in `~/.claude/settings.json`.

### OpenCode Config Merging

`~/.config/opencode/opencode.json` is merged (not overwritten):
- Adds missing MCP servers
- Updates existing ones
- Preserves any existing settings not managed by dotfiles

### Claude Code Windows LSP Patching

npm-installed LSPs (typescript-language-server, pyright-langserver, intelephense) need `cmd.exe /c` wrapper. Auto-patches marketplace.json to fix `spawn EINVAL` errors.

### MCP Server Manual Patching (Windows)

On Windows, MCP servers that use `npx` (like `zai-mcp-server`) also need the `cmd.exe /c` wrapper in `~/.claude.json`:

```json
"mcpServers": {
  "zai-mcp-server": {
    "command": "cmd.exe",
    "args": ["/c", "npx", "-y", "@z_ai/mcp-server"]
  }
}
```

This fixes the "Windows requires 'cmd /c' wrapper to execute npx" warning in MCP diagnostics.

---

## Neovim Keybindings

Leader key is Space.

| Keybinding | Action |
|------------|--------|
| `-` | Oil (file browser) |
| `<leader>q` | Quit |
| `<leader>x` | Write and source |
| `<leader>'` | Alternate file |
| `<leader>pt` | Toggle Typst preview |
| `<leader>ps` | Start live preview |
| `<leader>pc` | Close live preview |
| `<leader>;` | Pick live preview |
| `<leader>b` | LSP format |
| `<leader>u` | Pack update |
| `<leader>e` | FzfLua global |
| `<leader>n` | FzfLua combine |
| `<leader>/` | Grep current buffer |
| `<leader>z` | Live grep native |
| `<leader>f` | Files |
| `<leader>h` | Help tags |
| `<leader>k` | Keymaps |
| `<leader>l` | Loclist |
| `<leader>m` | Marks |
| `<leader>t` | Quickfix |
| `<leader>gf` | Git files |
| `<leader>gs` | Git status |
| `<leader>gd` | Git diff |
| `<leader>gh` | Git hunks |
| `<leader>gc` | Git commits |
| `<leader>gl` | Git blame |
| `<leader>gb` | Git branches |
| `<leader>gt` | Git tags |
| `<leader>gk` | Git stash |
| `<leader>\` | LSP finder |
| `<leader>dd` | LSP document diagnostics |
| `<leader>dw` | LSP workspace diagnostics |
| `<leader>,` | LSP incoming calls |
| `<leader>.` | LSP outgoing calls |
| `<leader>a` | LSP code actions |
| `<leader>s` | LSP document symbols |
| `<leader>w` | LSP workspace symbols |
| `<leader>r` | LSP references |
| `<leader>i` | LSP implementations |
| `<leader>o` | LSP type definitions |
| `<leader>j` | LSP definitions |
| `<leader>v` | LSP declarations |

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and changes.

---

## License

MIT
