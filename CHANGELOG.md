# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [4.4] - 2026-01-07

### Changed

**git-update-repos: GitHub CLI Integration**
- Migrated from public GitHub API to authenticated `gh repo list` command
- Now fetches ALL repositories (public **and private**) via authenticated API
- Added GitHub CLI (`gh`) requirement check with helpful error messages
- Removed curl/wget-based API fetching and pagination logic
- Simplified JSON parsing using `jq` when available, falls back to grep/sed

**Documentation**
- Updated README Section 11 with comprehensive git-update-repos documentation
- Added parameters table with Bash and PowerShell equivalents
- Documented gh CLI requirement and authentication flow
- Updated script entry point description to mention private repo support

### Fixed

**git-update-repos**
- Fixed issue where only public repositories were being cloned/updated
- Script now correctly handles all repos for authenticated user via `gh` CLI

---

## [4.3] - 2026-01-07

### Fixed

**Go Package Installation**
- Fixed `goimports` reinstall issue by normalizing GOPATH paths before comparison
- Changed from wildcard pattern matching to exact array matching for registry PATH checks
- Always add `$GOPATH/bin` to current session PATH unconditionally for immediate tool availability

### Removed

**Ruby Runtime & bashcov**
- Removed Ruby runtime from bootstrap (no longer needed)
- Removed bashcov gem installation
- Removed ruby from version-check patterns (both PowerShell and Bash)
- Removed ruby from packages.yaml configuration
- Updated coverage strategy: kcov is now used exclusively
  - Linux/macOS: native kcov
  - Windows: kcov via Docker

### Changed

- Updated README to reflect kcov-only coverage strategy
- Removed gem from supported language package managers list
- Updated coverage tools table to show "kcov (via Docker)" for Windows

---

## [4.2] - 2026-01-03

### Fixed

**Bootstrap Idempotency & PATH Detection**
- Fixed PATH detection for npm, Python, and winget-installed packages
- Enhanced Initialize-UserPath to add all Scoop app current directories (not just current/bin)
- Fixed Add-ToPath to use exact matching instead of substring matching
- Added WinGet Links directory to Refresh-Path preservation list
- Moved PATH initialization to beginning of Main function for early tool detection

**Test Infrastructure**
- Fixed test bugs that were wiping User PATH registry entries
- Removed dangerous registry PATH cleanup from AfterEach blocks
- Added safety checks to prevent empty PATH conditions

### Changed

- Updated test counts from 2221 to 3221 (2181 PowerShell + 1040 Bash)
- Updated idempotence documentation with latest bootstrap output (57 skipped items)
- Enhanced PATH preservation to include WinGet Links for winget-installed tools
- Improved coverage reporting to 31.4% combined (42.1% PowerShell + 31.2% Bash)

---

## [4.1] - 2026-01-02

### Fixed
- Script entry point mermaid diagram alignment

### Changed
- Updated coverage reporting with real coverage measurements (43.9% combined: 41.9% PowerShell + 46.9% Bash)
- Enhanced documentation with sequence diagram in Architecture section
- Improved documentation structure: removed inline navigation links, kept only footer Back to Top
- Refined subsection formatting: removed separators within subsections

---

## [4.0] - 2026-01-02

### Major Architecture Changes

**Shell-First Architecture (.sh as Source of Truth)**
- Converted .ps1 scripts to thin compatibility wrappers that call .sh scripts via Git Bash
- All core logic now lives in bash scripts for single implementation
- Windows-native bootstrap.ps1 for better platform integration, with fallback to bash
- Benefits: Single implementation to maintain, cross-platform parity, automatic Windows support

**Git Bash Integration**
- Git is now automatically installed on Windows via winget during bootstrap
- Wrapper scripts convert Windows paths to Git Bash format for cross-platform compatibility
- Line endings handled via .gitattributes (LF for .sh, CRLF for .ps1)
- Universal bashcov for bash coverage reports across all platforms

### Added

**Testing & Coverage**
- Comprehensive bash test suite with 11 BATS test files covering all .sh scripts
- 5 PowerShell test files focused on wrapper validation
- Coverage tracking: 46.2% bash coverage, 15% PowerShell coverage, 27.5% combined
- Test categories: unit tests, integration tests, E2E tests
- Automated coverage reporting with badges

**Configuration System**
- Optional `.dotfiles.config.yaml` for user preferences
- Bridge approach config library (`lib/config.sh` and `lib/config.ps1`)
- Configurable: editor preference, theme, installation categories, auto-update options
- Graceful fallback to defaults when config not present

**Bootstrap Enhancements**
- Installation categories: minimal, sdk, full (default)
- Tool descriptions in summary output for better UX
- Git installation during bootstrap on Windows
- bashcov installation for coverage testing
- Idempotent operations with detailed skip tracking
- Phase-based installation (Foundation, SDKs, LSPs, Linters, CLI Tools, MCP Servers, Deploy, Update)

**Deployment Improvements**
- Automatic .gitconfig cleanup for platform-specific credential helper fixes
- Removes Linuxbrew gh paths on Windows
- Removes absolute Windows gh.exe paths on Linux/macOS
- Removes empty helper lines from gitconfig
- XDG_CONFIG_HOME support for all configs
- OneDrive-aware PowerShell profile deployment on Windows

**Platform Support**
- Windows: Git Bash path conversion, lowercase drive letters
- Linux: Enhanced package detection and installation
- macOS: Apple Silicon and Intel support

**New Entry Points**
- `uninstall.sh` / `uninstall.ps1` - Remove deployed configs
- `healthcheck.sh` / `healthcheck.ps1` - System health verification
- `backup.sh` / `backup.ps1` - Timestamped backup before changes
- `restore.sh` / `restore.ps1` - Restore from backups
- `sync-system-instructions.sh` / `sync-system-instructions.ps1` - Sync AI prompts

**Documentation**
- `CHANGELOG.md` - Comprehensive version history from v1.0 to v4.0
- `Legacy Museum` section in README - Documents historical files with commit hashes
  - git-clone-all.sh: 2.5 years old (June 2023)
  - assets/: 1.5 years old (June 2023 - July 2024)
  - typos.toml, update.sh, .aider*, .env.gpt-researcher: 2025 era

### Changed

- **update-all**: Modularized into platform-specific functions
- **git hooks**: Enhanced with PowerShell versions for Windows
- **README**: Reorganized with numbered sections, security documentation, entry points table
- **Neovim**: Removed null-ls, migrated to built-in formatting
- **Wezterm**: Rose-pine theme, window mode support

### Fixed

- PowerShell alias syntax errors
- WSL gh credential helper broken paths on Windows
- Path conversion between Windows and Git Bash formats
- Duplicate PowerShell test code removed (wrapper pattern)
- .gitconfig credential helper cross-platform compatibility

### Removed

- GLM MCP servers from bootstrap (web-search-mcp, web-reader-mcp, zread-mcp)
- Duplicate PowerShell implementations (converted to wrappers)

### Security

- Comprehensive security review completed (January 2026)
- 0 HIGH/MEDIUM vulnerabilities found
- Documented threat model and security design principles
- Wrapper script string interpolation documented (not exploitable for personal dotfiles)

---

## [3.3.3] - 2026-01-01

### Fixed
- PowerShell syntax errors in bootstrap scripts
- PowerShell alias conflicts

### Changed
- Enhanced README with clearer documentation

---

## [3.3] - 2026-01-01

### Fixed
- PowerShell syntax errors throughout the codebase

### Changed
- Updated README for clarity

---

## [3.2] - 2026-01-01

### Changed
- Reorganized README sections with numbering
- Added section navigation

---

## [3.1] - 2026-01-01

### Changed
- Fixed Neovim keybindings documentation
- Added Claude Code integration section
- Added hidden hotkeys and Wezterm hotkeys to README
- Fixed key notation in documentation

---

## [3.0] - 2026-01-01

### Added
- **Bridge Approach Config System**: Optional YAML configuration with graceful fallbacks
- **Testing Framework**: Comprehensive test suite with BATS (bash) and Pester (PowerShell)
- **Code Coverage**: bashcov for bash coverage, Pester coverage for PowerShell
- **Conventional Commits**: Git hooks enforce conventional commit format
- **Claude Code Hooks**: Quality checks and TDD guard for AI-assisted development
- **System Instructions Sync**: Auto-distribute CLAUDE.md, AGENTS.md, GEMINI.md to all repos

### Changed
- Modularized update-all for better maintainability
- Enhanced CLAUDE.md with comprehensive AI coding practices
- Bootstrap now supports installation categories (minimal, sdk, full)

---

## [2.2] - 2025-12-31

### Changed
- Enhanced README documentation
- Improved verbose output in scripts

---

## [2.1] - 2025-12-31

### Changed
- **update-all**: Refactored for modularity and better maintainability
- Improved package manager detection and handling

---

## [2.0] - 2025-12-31

### Added
- **Auto-distribution of System Prompts**: Automatically sync AI system instructions across all repositories
- CLAUDE.md, AGENTS.md, GEMINI.md support for multiple AI assistants

### Changed
- Enhanced git hooks for better commit message validation
- Improved bootstrap process

---

## [1.0] - 2025-12-30

### Initial Release

**Core Features**
- Cross-platform support: Windows 11, Linux (Ubuntu/Fedora/Arch), macOS
- Universal deployment script for configs (Neovim, git, shell profiles)
- Bootstrap script for automated development environment setup
- Package manager installation (scoop, winget, brew, apt, dnf, pacman)
- SDK installation (Node.js, Python, Go, Rust, dotnet, OpenJDK)
- LSP server installation (15+ language servers)
- Linter and formatter installation (10+ tools)
- CLI tools installation (fzf, zoxide, bat, eza, lazygit, gh, ripgrep, fd)

**Git Hooks**
- Pre-commit hook for auto-formatting and linting
- Commit-msg hook for conventional commits enforcement
- Support for 15+ languages in hooks

**Neovim Configuration**
- Lazy.nvim plugin manager
- 15+ LSP servers configured
- Treesitter for syntax highlighting
- Custom keybindings and themes
- Linting and formatting on save

**Shell Profiles**
- Bash aliases and functions
- Zsh support for macOS/Linux
- PowerShell 7 profile for Windows
- Zoxide integration for smart navigation

**Utility Scripts**
- `update-all.sh`: Update all package managers
- `git-update-repos.sh`: Update all git repositories in configured directory
- `healthcheck.sh`: Verify system health and configurations
- `backup.sh`: Create timestamped backups
- `restore.sh`: Restore from backups

**Platform-Specific**
- Windows: OneDrive-aware, PowerShell 7 support, Git Bash integration
- Linux: Multiple distribution support, systemd services
- macOS: Homebrew integration, Apple Silicon support

---

## Version Summary

| Version | Date | Major Changes |
|---------|------|---------------|
| 4.4 | 2026-01-07 | git-update-repos migrated to gh CLI for public+private repo support |
| 4.3 | 2026-01-07 | Fixed goimports reinstall, removed Ruby/bashcov, kcov-only coverage |
| 4.2 | 2026-01-03 | Bootstrap idempotency fixes, PATH detection improvements |
| 4.1 | 2026-01-02 | Documentation improvements, real coverage reporting |
| 4.0 | 2026-01-02 | Shell-first architecture, comprehensive testing, config system |
| 3.3.3 | 2026-01-01 | Bootstrap enhancements, PowerShell fixes |
| 3.3 | 2026-01-01 | PowerShell syntax fixes |
| 3.2 | 2026-01-01 | README reorganization |
| 3.1 | 2026-01-01 | Documentation improvements |
| 3.0 | 2026-01-01 | Bridge approach config, testing framework, Claude Code hooks |
| 2.2 | 2025-12-31 | Documentation enhancements |
| 2.1 | 2025-12-31 | Update-all modularization |
| 2.0 | 2025-12-31 | Auto-distribution of system prompts |
| 1.0 | 2025-12-30 | Initial release |

---

## Migration Guide

### From v3.x to v4.0

**Windows Users:**
- Git Bash is now required and will be auto-installed during bootstrap
- Run `bootstrap.ps1 -y` to update to the new architecture
- All existing functionality preserved with .sh as source of truth

**All Users:**
- Optional: Create `~/.dotfiles.config.yaml` for custom configuration
- Run `deploy.sh` / `deploy.ps1` to update configurations
- Review new security section in README

### From v2.x to v3.0

- Install testing dependencies: `bats` (bash) and `Pester` (PowerShell)
- Run `bootstrap.sh` / `bootstrap.ps1` to install new tools
- Create optional config file for customization
- Run `deploy.sh` / `deploy.ps1` to update Claude Code hooks

### From v1.0 to v2.0

- Run `sync-system-instructions.sh` to distribute AI prompts
- Update git hooks: `git config --global core.hooksPath ~/.config/git/hooks`

---

[Unreleased]: https://github.com/lavantien/dotfiles/compare/v4.4...HEAD
[4.4]: https://github.com/lavantien/dotfiles/compare/v4.3...v4.4
[4.3]: https://github.com/lavantien/dotfiles/compare/v4.2...v4.3
[4.2]: https://github.com/lavantien/dotfiles/compare/v4.1...v4.2
[4.1]: https://github.com/lavantien/dotfiles/compare/v4.0...v4.1
[4.0]: https://github.com/lavantien/dotfiles/compare/v3.3.3...v4.0
[3.3.3]: https://github.com/lavantien/dotfiles/compare/v3.3...v3.3.3
[3.3]: https://github.com/lavantien/dotfiles/compare/v3.2...v3.3
[3.2]: https://github.com/lavantien/dotfiles/compare/v3.1...v3.2
[3.1]: https://github.com/lavantien/dotfiles/compare/v3.0...v3.1
[3.0]: https://github.com/lavantien/dotfiles/compare/v2.2...v3.0
[2.2]: https://github.com/lavantien/dotfiles/compare/v2.1...v2.2
[2.1]: https://github.com/lavantien/dotfiles/compare/v2.0...v2.1
[2.0]: https://github.com/lavantien/dotfiles/compare/v1.0...v2.0
[1.0]: https://github.com/lavantien/dotfiles/releases/tag/v1.0
