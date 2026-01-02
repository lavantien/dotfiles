# Universal Dotfiles v4.0 - Shell-First Architecture Release

![Coverage](https://img.shields.io/badge/coverage-27%25-red) [![Security](https://img.shields.io/badge/security-reviewed-brightgreen)](https://github.com/lavantien/dotfiles#security) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT) [![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-blue)](https://github.com/lavantien/dotfiles)

---

## What's New in v4.0

v4.0 is a **major architectural redesign** that establishes shell scripts as the single source of truth while maintaining full Windows compatibility through thin PowerShell wrappers.

### Major Architecture Changes

#### Shell-First Architecture (.sh as Source of Truth)
- **All core logic now lives in bash scripts** - Single implementation to maintain and test
- **PowerShell scripts are thin compatibility wrappers** - Call .sh via Git Bash on Windows
- **Windows-native bootstrap** - Better platform integration with automatic Git installation
- **Cross-platform parity** - Features develop in .sh first, automatically available on Windows

```
┌─────────────────────────────────────────────────────────────┐
│                    Windows (PowerShell)                     │
├─────────────────────────────────────────────────────────────┤
│  script.ps1  ──►  bash script.sh  ──►  Core Logic           │
│  (wrapper)        (Git Bash)          (source of truth)     │
└─────────────────────────────────────────────────────────────┘
```

#### Comprehensive Testing & Coverage
- **11 BATS test files** covering all .sh scripts (backup, bootstrap, deploy, git hooks, healthcheck, restore, sync, uninstall, update-all, git-update-repos)
- **5 PowerShell test files** for wrapper validation
- **Coverage metrics**: 46.2% bash coverage, 15% PowerShell coverage, 27.5% combined
- **Automated coverage reporting** with badges
- **E2E tests** for critical workflows

#### Configuration System (Optional)
- **YAML-based configuration** at `~/.dotfiles.config.yaml`
- **Bridge approach** config library for both bash and PowerShell
- **Graceful fallbacks** to sensible defaults
- **Configurable options**: editor preference, theme, installation categories, auto-update

---

## New Features

### Bootstrap Enhancements
- **Installation categories**: `minimal`, `sdk`, `full` (default)
- **Tool descriptions** in summary output for better UX
- **Automatic Git installation** on Windows via winget
- **bashcov integration** for coverage testing
- **Idempotent operations** with detailed skip tracking
- **Phase-based installation**: Foundation → SDKs → LSPs → Linters → CLI Tools → MCP Servers → Deploy → Update

### Deployment Improvements
- **Automatic .gitconfig cleanup** for platform-specific fixes
- Removes Linuxbrew gh paths on Windows
- Removes absolute Windows gh.exe paths on Linux/macOS
- Removes empty helper lines from gitconfig
- **XDG_CONFIG_HOME support** for all configs
- **OneDrive-aware** PowerShell profile deployment

### Platform Support
- **Windows**: Git Bash path conversion, lowercase drive letters, automatic Git installation
- **Linux**: Enhanced package detection and installation
- **macOS**: Apple Silicon and Intel support

### New Entry Point Scripts
| Script | Purpose |
|--------|---------|
| `uninstall.sh` / `uninstall.ps1` | Remove all deployed configs |
| `healthcheck.sh` / `healthcheck.ps1` | Verify system health |
| `backup.sh` / `backup.ps1` | Create timestamped backups |
| `restore.sh` / `restore.ps1` | Restore from backups |
| `sync-system-instructions.sh` / `sync-system-instructions.ps1` | Sync AI prompts to all repos |

---

## Installation

### Quick Start
```bash
# Clone the repository
git clone https://github.com/lavantien/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Run bootstrap (automatically detects your platform)
./bootstrap.sh           # Linux/macOS
.\bootstrap.ps1          # Windows

# Or with options
./bootstrap.sh -y        # Non-interactive
.\bootstrap.ps1 -y       # Windows non-interactive
```

### Installation Categories
```bash
./bootstrap.sh --category minimal    # Package managers, git, CLI tools only
./bootstrap.sh --category sdk        # minimal + Node.js, Python, Go, Rust, dotnet, JDK
./bootstrap.sh --category full       # sdk + all LSPs + linters/formatters + MCP servers (default)
```

### Optional Configuration
Create `~/.dotfiles.config.yaml`:
```yaml
editor: nvim          # Preferred editor (nvim, vim, code)
theme: gruvbox-light  # Theme preference
categories: full      # Installation category
auto_update_repos: false  # Auto-update git repos
backup_before_deploy: false  # Auto-backup before deploy
```

---

## What Gets Installed

### Package Managers
- **Windows**: Scoop (CLI tools), winget (heavy apps like Visual Studio, LLVM)
- **Linux**: System (apt/dnf/pacman/zypper), Homebrew (optional)
- **macOS**: Homebrew (primary)

### Core SDKs (always latest)
- Node.js LTS, Python 3.x, Go, Rust (via rustup), dotnet LTS, OpenJDK LTS

### Language Servers (15 total)
- clangd (C/C++), gopls (Go), rust-analyzer (Rust), pyright (Python)
- ts_ls (JavaScript/TypeScript), lua-language-server (Lua), csharp-ls (C#)
- jdtls (Java), intelephense (PHP), docker-language-server (Dockerfile)
- yaml-language-server (YAML), tombi (TOML), tinymist (Typst), dartls (Dart)

### Linters & Formatters (10+ tools)
- prettier, eslint, ruff, black, isort, mypy, goimports, golangci-lint
- shellcheck, shfmt, clang-format, clang-tidy, scalafmt, Laravel Pint

### Essential CLI Tools
- fzf, zoxide, bat, eza, lazygit, gh, ripgrep (rg), fd, tokei, difftastic

### Claude Code MCP Servers
- context7 (library documentation), playwright (browser automation), repomix (repo packing)

---

## Testing

```bash
# Run all tests
./tests/coverage.sh                    # Bash coverage
.\tests\coverage-report.ps1            # PowerShell coverage

# Run specific test suites
bats tests/bash/bootstrap_test.bats    # Bootstrap tests
bats tests/bash/deploy_test.bats       # Deploy tests
Invoke-Pester tests/powershell         # PowerShell tests
```

**Current Coverage**: 27.5% combined (46.2% bash, 15% PowerShell)

---

## Security

- **Comprehensive security review completed (January 2026)**
- **0 HIGH/MEDIUM vulnerabilities found**
- Documented threat model and security design principles
- See [Security section in README](https://github.com/lavantien/dotfiles#security)

---

## Migration from v3.x

### Windows Users
- Git Bash is now required and will be **auto-installed** during bootstrap
- Run `.\bootstrap.ps1 -y` to update
- All existing functionality preserved

### All Users
- Optional: Create `~/.dotfiles.config.yaml` for custom configuration
- Run `./deploy.sh` / `.\deploy.ps1` to update configurations

---

## Full Changelog

See [CHANGELOG.md](https://github.com/lavantien/dotfiles/blob/main/CHANGELOG.md) for complete version history including:
- v3.3.3 - Bootstrap enhancements, PowerShell fixes
- v3.3 - PowerShell syntax fixes
- v3.2 - README reorganization
- v3.1 - Documentation improvements
- v3.0 - Bridge approach config, testing framework, Claude Code hooks
- v2.2 - Documentation enhancements
- v2.1 - Update-all modularization
- v2.0 - Auto-distribution of system prompts
- v1.0 - Initial release

---

## Documentation

- [README](https://github.com/lavantien/dotfiles#readme) - Full documentation
- [CHANGELOG.md](https://github.com/lavantien/dotfiles/blob/main/CHANGELOG.md) - Version history
- [Coverage Report](https://github.com/lavantien/dotfiles#code-coverage) - Test coverage details

---

## Support

For issues, questions, or contributions, please visit:
- [Issues](https://github.com/lavantien/dotfiles/issues)
- [Pull Requests](https://github.com/lavantien/dotfiles/pulls)

---

**License**: [MIT](https://opensource.org/licenses/MIT)

**435+ automated tests** | **15+ LSP servers** | **20+ package managers** | **Cross-platform**
