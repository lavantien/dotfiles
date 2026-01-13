# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [5.2.9] - 2026-01-13

### Fixed

**Documentation**

- Corrected LSP server count from 23/25 to 19 (verified against bootstrap/bootstrap.sh)
- Updated tool counts: Linters 16+ → 20+, Formatters 13+ → 17+, Testers 5+ → 9+, CLI Tools 13+ → 15+
- Corrected automated test count from 150+ to 2,200+ (verified against test files)
- Standardized clone directory path to ~/dev/github/dotfiles across all documentation
- Fixed config setting name inconsistency: auto_commit_changes/auto_update_repos → auto_commit_repos
- Fixed rust-analyzer naming (hyphen vs underscore inconsistency)
- Added bootstrap script structure documentation (wrapper vs implementation)
- Added HOOKS.md to Additional Documentation table
- Removed broken CONTRIBUTING.md link from tests/README.md
- Enhanced AGENTS.md and GEMINI.md with explanatory comments

**Files Changed**

- README.md
- TOOLS.md
- TESTING.md
- QUICKREF.md
- BRIDGE.md
- tests/README.md
- AGENTS.md
- GEMINI.md

---

## [5.2.8] - 2026-01-13

### Fixed

**sync-system-instructions.sh**

- commit_changes() now prints status message (already up to date vs committed)
- push_changes() checks ahead count before attempting push, prints status
- Added `|| true` to prevent set -e exits in commit/push loop
- No more false "pushed" messages when nothing was pushed

---

## [5.2.7] - 2026-01-13

### Fixed

**sync-system-instructions.sh**

- Fixed `set -e` arithmetic bug that caused script to exit after first repository
- Added `|| true` to counter increments to handle zero values correctly
- Script now processes all repositories in base directory

### Removed

**sync-system-instructions.sh**

- Removed Claude CLI dependency for commit/push operations
- Now uses pure git commands (deterministic, no AI agent needed)
- Deleted `commit_with_claude()` function

---

## [5.2.6] - 2026-01-12

### Added

**Bootstrap Scripts**

- Comprehensive AUTO-CORRECTION system for all packages
- Distro-agnostic `remove_system_package()` helper (apt/dnf/pacman/zypper)
- CLI tools auto-correction: fzf, zoxide, bat, eza, lazygit, gh, tokei, ripgrep, fd, bats
- SDKs auto-correction: nodejs (including snap), golang, php, dotnet
- Language servers: clangd, lua-language-server, jdtls, rust-analyzer
- Linters/formatters: prettier, eslint, ruff, black, mypy, yamllint, shellcheck, shfmt, stylua, selene, golangci-lint
- Cargo packages: difftastic
- Catch-all handler for unknown sources (snap/flatpak/AppImage/manual installs)
- Handles package name variations (fd/fd-find, gh/github-cli, eza/exa)

### Changed

**Bootstrap Scripts**

- AUTO-CORRECTION now covers 30+ packages across multiple sources
- Python kept as system fallback (not removed, always safe)
- Unknown package sources logged for manual cleanup instead of failing

---

## [5.2.5] - 2026-01-12

### Added

**Bootstrap Scripts**

- PHP installation with curl extension (required by Composer)
- Linux: `install_php()` function, prefers brew PHP (curl included), falls back to apt/dnf/pacman/zypper
- macOS: `install_php()` function via brew (curl included by default)
- Windows: `Install-PHP()` function via scoop or winget
- Composer now runs at full speed without the slow fallback HTTP handler

### Fixed

**Bootstrap Scripts**

- Auto-remove apt-installed PHP before installing brew version
- Add php to brew package mapping and AUTO-CORRECTION section

---

## [5.2.4] - 2026-01-12

### Fixed

**Bootstrap Scripts**

- build dependencies now install even when rustup is already present
- Moved `install_build_dependencies()` call before early-return check in `install_rustup()`
- This ensures pkg-config and OpenSSL headers are available for future cargo package compilation

---

## [5.2.3] - 2026-01-12

### Added

**Build Dependencies**

- Added automatic installation of pkg-config and OpenSSL development headers
- Linux: Installs distro-specific packages (libssl-dev, openssl-devel, openssl, libopenssl-devel)
- macOS: Installs via Homebrew (openssl, pkg-config)
- These are required for compiling Rust packages with native dependencies like cargo-update

### Changed

**Bootstrap Scripts**

- Linux: Added `install_build_dependencies()` function, called before Rust installation
- macOS: Added `install_build_dependencies()` function, called before Rust installation
- Both platforms now ensure build deps are present before installing cargo-update

---

## [5.2.2] - 2026-01-12

### Fixed

**Update Script**

- Reordered RUSTUP before CARGO section (cargo comes from rustup)
- Added CARGO-UPDATE section to auto-install cargo-update if missing
- This ensures `cargo-install-update` is available before running cargo package updates

---

## [5.2.1] - 2026-01-12

### Added

**Package Management**

- Added cargo-update installation during bootstrap for all platforms (Linux/macOS/Windows)
- Added Claude Code CLI update to update-all.sh script
- cargo-update provides cargo-install-update command to manage all cargo-installed packages

**Documentation**

- Enhanced CLAUDE.md with "Research Before Implementation" section
- Added guidance on using Context7, Web Search, Web Reader, ZRead, and GitHub CLI
- Added "Testing Strategy" section comparing property-based testing vs unit tests

### Changed

**Bootstrap Scripts**

- Linux: Added install_cargo_update() function and cargo-update package handling
- macOS: Added install_cargo_update() function and cargo-update package handling
- Windows: Added Install-CargoUpdate function and cargo-update package handling
- packages.yaml: Added cargo_update to linters_formatters category

**Update Script**

- update-all.sh: Added CLAUDE CODE CLI section for updating Claude via official install script

---

## [5.2] - 2026-01-10

### Added

**Neovim Treesitter Support**

- Added tree-sitter-cli installation to bootstrap scripts (Linux/macOS/Windows)
- Implemented auto-install of 32 Treesitter parsers on Neovim startup
- Parsers: lua, vim, vimdoc, query, c, cpp, rust, go, python, java, c_sharp, php, scala, javascript, typescript, tsx, jsx, html, css, scss, svelte, yaml, json, toml, markdown, markdown_inline, bash, powershell, dockerfile, typst
- Cross-platform parser installation with automatic dependency checking

### Changed

**Neovim 0.12 Compatibility**

- Updated nvim-treesitter configuration for v2.0 API (complete rewrite)
- Replaced deprecated `nvim-treesitter.configs` with new `nvim-treesitter.config`
- Removed `ensure_installed`, `auto_install`, `sync_install` options (no longer supported)
- Implemented manual parser installation via Lua API with startup auto-install
- Added conditional Treesitter language loading for installed parsers

**Linux Platform**

- Removed powershell_es LSP from Neovim configuration (requires pwsh on Linux)
- Treesitter PowerShell parser remains available for syntax highlighting

### Fixed

- Neovim LSP error when opening PowerShell files on Linux (pwsh not found)
- Treesitter parsers not installing automatically with new nvim-treesitter v2.0

---

## [5.1] - 2026-01-10

### Changed

**Theme Update - Rose Pine**

- Switched default theme from gruvbox to rose-pine across all configs
- Neovim: Using rose-pine colorscheme with dark background
- WezTerm: Using rose-pine color scheme
- Updated bat previewer theme to rose-pine

**Neovim Improvements**

- Fixed nvim-treesitter configuration using manual FileType autocmd
- Replaced `nvim-treesitter.configs.setup()` with direct `vim.treesitter.start()` call
- Properly configured foldexpr, foldmethod, and indentexpr for treesitter
- Removed deprecated treesitter config pattern for Neovim 0.11+ compatibility
- Standardized quote style from double to single quotes
- Fixed indentation consistency (4 spaces)

**Deploy Script Enhancement**

- Added WezTerm background asset deployment to `~/assets/`
- Copies all files from `assets/` directory during deployment
- Ensures terminal backgrounds are available after running deploy.sh

**Configuration Defaults**

- Updated default theme in `deploy.sh`: gruvbox-light → rose-pine
- Updated default theme in `update-all.sh`: gruvbox-light → rose-pine
- Updated example config in `.dotfiles.config.yaml.example`

**Documentation**

- Updated README.md theme values to reflect rose-pine variants
- Updated QUICKREF.md theme options
- Updated BRIDGE.md example config

**Test Fixes**

- Updated all test fixtures to use rose-pine theme
- Bash tests: `config_test.bats`, `config_e2e_test.bats`
- PowerShell tests: `config.Tests.ps1`

### Fixed

- Neovim treesitter highlighting not working properly with built-in wrapper
- WezTerm background images missing after deployment

---

## [5.0] - 2026-01-10

### Major Changes

**Linux Platform Overhaul - Ubuntu 26.04 LTS Ready**

- Complete rewrite of Linux platform installation in `bootstrap/platforms/linux.sh`
- Homebrew-first package priority on Linux (uses brew before apt when available)
- Automatic Homebrew installation on Linux without prompts
- Git reinstallation via brew after uninstalling apt git
- VSCode now installed via official Microsoft apt repository (not manual .deb)
- dotnet-sdk 10.0 installed via Microsoft apt repository
- WezTerm installation via official apt.fury.io wez repository
- Enhanced package detection with `command -v` fallbacks
- Removed gpt-researcher integration and references

**Testing & Coverage Improvements**

- Reintroduced bashcov for accurate bash coverage (47.51% bash, 25% combined)
- bashcov properly tracks sourced files (unlike kcov)
- Updated coverage strategy: bashcov (primary) with kcov fallback
- Coverage reporting enhanced with detailed notes per platform

**Git Hooks Enhancement**

- Rewrote pre-commit hooks with expanded language support
- Comprehensive conventional commits validation (type, scope, format)
- Pre-commit auto-format: prettier, shfmt, gofmt, rustfmt, dotnet format
- Pre-commit linting: eslint, golangci-lint, clippy, shellcheck, mypy
- Separated git hooks from `hooks/` to `.config/git/hooks/` for proper git integration

**Bootstrap Refactoring**

- Added PATH fix functions for robustness
- Enhanced error handling and recovery mechanisms
- Improved platform-specific package installation ordering
- Added WezTerm installation to bootstrap phases
- Package priority: brew > official repos > apt

### Added

**New Documentation Files**

- `ARCHITECTURE.md` - System architecture diagrams and design principles
- `TOOLS.md` - Complete language tool matrix (LSPs, linters, formatters)
- `TESTING.md` - Testing documentation and coverage procedures
- `HISTORY.md` - Legacy museum with 3-year project history
- `HOOKS.md` - Git hooks documentation (moved from hooks/README.md)

**New Configuration Files**

- `.config/opencode/opencode.linux.json` - Linux-specific OpenCode settings
- `.config/opencode/opencode.macos.json` - macOS-specific OpenCode settings
- `.config/opencode/opencode.windows.json` - Windows-specific OpenCode settings
- `.config/git/hooks/pre-commit` - Bash pre-commit hook
- `.config/git/hooks/commit-msg` - Bash commit-msg hook
- `.config/nvim/init.lua` - Neovim config in proper XDG location

**New Test Files**

- `tests/bash/git-hooks_test.bats` - Git hooks validation tests
- `tests/bash/bootstrap_new_tools_test.bats` - New tools installation tests
- `tests/powershell/bootstrap_new_tools.Tests.ps1` - PowerShell new tools tests
- `tests/powershell/windows-platform.Tests.ps1` - Windows platform tests

**Quality & Hooks Scripts**

- `.claude/hooks/` - Claude Code hooks directory
- `.claude/quality-check.sh` - Bash quality check script
- `.claude/quality-check.ps1` - PowerShell quality check script
- `.claude/statusline.sh` - Claude Code statusline configuration
- `.claude/CLAUDE.md` - Project-specific Claude instructions

### Changed

**Bootstrap Script**

- `bootstrap/bootstrap.sh` - Enhanced with new platform detection and package priority
- `bootstrap/lib/common.sh` - Added fix_path_issues and fix_package_states functions
- `bootstrap/platforms/linux.sh` - Complete rewrite with 677 lines of improvements
- `bootstrap/platforms/macos.sh` - Enhanced with 99 lines of additions

**Deployment**

- `deploy.sh` - Added 239 lines of enhancements for better deployment handling
- Enhanced XDG_CONFIG_HOME support across all configs
- Better platform-specific config file handling

**Git Scripts**

- `git-update-repos.sh` - Enhanced with 111 lines of improvements
- Better error handling and progress reporting

**Update Script**

- `update-all.sh` - Enhanced package manager detection and updates

**README Optimization**

- Reduced from 1925 to ~800 lines (~60% reduction)
- Removed content duplications
- Consolidated sections for higher information density
- Reduced mermaid diagrams from 6 to 1
- Better organization with links to new documentation files

**Hooks**

- `hooks/claude/quality-check.ps1` - Enhanced with comprehensive quality checks
- Git hooks moved to proper `.config/git/hooks/` location

### Removed

**Deprecated Files**

- `.env.gpt-researcher` - gpt-researcher integration removed
- `.config/opencode/opencode.json` - Split into platform-specific files
- `wezterm.lua` - Moved to `.config/wezterm/wezterm.lua`

### Fixed

**Coverage Reporting**

- Fixed bash coverage to use bashcov for accurate sourced file tracking
- Fixed badge calculation to reflect real coverage numbers

**Platform-Specific Issues**

- Fixed package installation priority on Linux
- Fixed git installation to use brew version instead of apt
- Fixed VSCode installation to use official apt repo
- Fixed dotnet-sdk installation with correct package name

### Testing

**Thoroughly tested on:**

- Ubuntu 26.04 LTS - All bootstrap phases, package installations, git hooks
- Windows 11 - PowerShell wrapper execution, Git Bash integration, platform-specific tools

**Coverage Results:**

- Bash: 47.51% (1529/3218 lines) via bashcov 3.2.0
- PowerShell: 10.02% (228/2276 commands) via Pester 5.7.1
- Combined: 25.0% (weighted: 60% PS + 40% Bash)

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
  - typos.toml, update.sh, .aider\*: 2025 era

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

| Version | Date       | Major Changes                                                                                            |
| ------- | ---------- | -------------------------------------------------------------------------------------------------------- |
| 5.0     | 2026-01-10 | Linux platform overhaul, Ubuntu 26.04 LTS ready, Homebrew-first, git hooks enhancement, bashcov coverage |
| 4.4     | 2026-01-07 | git-update-repos migrated to gh CLI for public+private repo support                                      |
| 4.3     | 2026-01-07 | Fixed goimports reinstall, removed Ruby/bashcov, kcov-only coverage                                      |
| 4.2     | 2026-01-03 | Bootstrap idempotency fixes, PATH detection improvements                                                 |
| 4.1     | 2026-01-02 | Documentation improvements, real coverage reporting                                                      |
| 4.0     | 2026-01-02 | Shell-first architecture, comprehensive testing, config system                                           |
| 3.3.3   | 2026-01-01 | Bootstrap enhancements, PowerShell fixes                                                                 |
| 3.3     | 2026-01-01 | PowerShell syntax fixes                                                                                  |
| 3.2     | 2026-01-01 | README reorganization                                                                                    |
| 3.1     | 2026-01-01 | Documentation improvements                                                                               |
| 3.0     | 2026-01-01 | Bridge approach config, testing framework, Claude Code hooks                                             |
| 2.2     | 2025-12-31 | Documentation enhancements                                                                               |
| 2.1     | 2025-12-31 | Update-all modularization                                                                                |
| 2.0     | 2025-12-31 | Auto-distribution of system prompts                                                                      |
| 1.0     | 2025-12-30 | Initial release                                                                                          |

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

[Unreleased]: https://github.com/lavantien/dotfiles/compare/v5.0...HEAD
[5.0]: https://github.com/lavantien/dotfiles/compare/v4.4...v5.0
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
