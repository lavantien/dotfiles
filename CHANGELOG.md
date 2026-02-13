# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [5.9.0] - 2026-02-13

### Changed

**OpenCode AI CLI Installation - Bun on Windows**

- Switched Windows opencode installation from official bash installer to bun
- `update-all.ps1`: Uses `bun install -g opencode-ai` instead of curl|bash
- `bootstrap.ps1`: Uses `bun install -g opencode-ai` instead of curl|bash
- Linux/macOS continue using the official bash installer (curl|bash)
- Simplified code: removed complex HOME environment variable handling
- Bun handles cross-platform path issues automatically

### Added

**PowerShell Profile - Argument Pass-through**

- Added `@args` to Update-AllPackages function in profile
- Allows passing flags like `-SkipPip` through the `up` alias
- Example: `up -SkipPip` now correctly passes the skip flag

**deploy.ps1 - Profile Functions Reload**

- Added automatic reload of profile functions into Global scope after deploy
- PowerShell's scope model prevents child scripts from modifying parent scope
- Redefines `Update-AllPackages` function and `up` alias in Global scope
- Changes to update-all.ps1 take effect immediately without restarting shell

**update-all.sh - Skip PIP Summary**

- Added `--skip-pip` status to summary output when flag is used
- Shows "PIP (skipped by --skip-pip flag)" in completion summary

### Rationale

The official opencode bash installer has Windows path handling issues when called from PowerShell (HOME variable confusion). Bun provides a cleaner cross-platform installation method that avoids these issues entirely. The Windows scripts now use bun while Linux/macOS continue using the proven official installer.

---

## [5.8.0] - 2026-02-12

### Fixed

**update-all - OpenCode AI CLI Update Reliability (Windows)**

- Added process termination before opencode update (Windows can't replace running executables)
- Stops any running `opencode.exe` processes before running the official installer
- Prevents silent update failures when opencode is running during update

**update-all - OpenCode Version Detection (Bash)**

- Aligned bash script with bootstrap: now cleans up npm shims BEFORE version checks
- Uses full binary path `$HOME/.opencode/bin/opencode` for version checks instead of PATH
- Removes old npm shims from `$NPM_CONFIG_PREFIX/bin` and `$APPDATA/npm` (Windows Git Bash)
- Prevents false version detection from npm shim shadowing official binary

**deploy.ps1 - Verbose Script Deployment Logging**

- Added detailed logging showing source and destination timestamps for script files
- Shows src time, dst time (before), and dst time (after) for each copied script
- Helps diagnose deployment issues by making it clear which files were updated
- Verbose output enabled by default for script deployments

### Changed

**update-all.sh - OpenCode Update Section Refactored**

- Clean up npm/bun shims first, then check if binary exists at official installer location
- Only proceed with update if binary exists at `$HOME/.opencode/bin/opencode`
- Consistent with bootstrap script's approach to opencode installation management

**Rationale:**

The opencode update was failing silently in some cases due to:
1. Old npm shims shadowing the official binary in PATH, causing version checks to return stale versions
2. Running opencode processes preventing the installer from replacing the executable on Windows

The fix aligns update-all.sh with bootstrap's proven approach: clean up shims first, use full binary paths for version checks, and terminate running processes before updating. The deploy script now provides verbose logging to help diagnose any future deployment issues.

---

## [5.7.0] - 2026-02-11

### Fixed

**Bootstrap - GCC Installation Verification (Windows)**

- Fixed gcc installation check to verify the command actually works via `gcc --version`
- Added command execution verification before skipping installation as "up to date"
- Added `--version` verification in `Install-ScoopPackage` function
- Fixes issue where gcc was skipped as "up to date" even though shim was broken
- Now properly reinstalls gcc when command exists but doesn't execute correctly

**update-all - Claude Code and OpenCode Update Verification (Windows)**

- Fixed Claude Code CLI update to verify command actually works before attempting update
- Fixed OpenCode AI CLI update to verify binary exists AND works before updating
- Added robust version parsing using regex match instead of fragile `.Matches.Value`
- Added execution verification after updates to confirm tools work
- Added shim cleanup for old npm/bun installations that could shadow official binaries
- Added handling for inconclusive version checks with fallback update attempts
- Ensures PATH is properly set during skips, not just installs

**Rationale:**

The update-all script was trusting file existence checks and version string parsing without verifying tools actually work. This was the same class of issue as the gcc fix in bootstrap.ps1 - tools could be detected as "installed" but have broken shims or fail to execute. The fix adds actual execution verification (`--version` checks with exit code validation) to ensure tools are functional before and after updates. Version parsing now uses PowerShell regex match groups instead of `.Matches.Value` which can fail on unexpected output formats.

---

## [5.6.0] - 2026-02-08

### Fixed

**Bootstrap - GCC Installation Verification (Windows)**

- Fixed gcc installation check to verify the command actually works via `gcc --version`
- Added command execution verification before skipping installation as "up to date"
- Added `--version` verification in `Install-ScoopPackage` function
- Fixes issue where gcc was skipped as "up to date" even though shim was broken
- Now properly reinstalls gcc when command exists but doesn't execute correctly

**Rationale:**

The bootstrap was trusting Scoop's package state and file existence checks without verifying the command actually works. This caused broken shims to be detected as "installed", skipping the reinstallation. The fix adds actual execution verification (`gcc --version`) to ensure the tool is functional before considering it "up to date".

---

## [5.5.0] - 2026-02-07

### Added

**update-all - Skip Pip Flag**

- Added `--skip-pip` flag to bash update-all.sh script
- Added `-SkipPip` parameter to PowerShell update-all.ps1 script
- Allows skipping pip package updates to speed up update cycles
- Useful when pip packages are stable and you want faster updates

**Documentation**

- Updated README Bootstrap Options table with new Update-All Options section
- Documents `--skip-pip` / `-SkipPip` flag usage

### Fixed

**update-all - pip Update Method (Windows)**

- Changed from `pip install --upgrade pip` to `python -m pip install --upgrade pip`
- Using `python -m pip` is the recommended method on Windows
- Avoids issues with pip launcher and multiple Python installations
- Applies to both pip self-upgrade and package updates

**update-all - OpenCode CLI Update**

- Fixed version comparison to use npm registry as source of truth
- Fixed opencode update to remove npm/bun-installed versions before running bash installer
- Fixed version detection after update - now uses installed binary path directly
- This prevents issues where npm/bun versions in PATH shadow the bash-installed binary
- Corrected GitHub repo reference from `opencode-ai/opencode` to `anomalyco/opencode`
- The opencode project migrated: `sst/opencode` -> `anomalyco/opencode`

**Rationale:**

OpenCode can be installed via npm (`opencode-ai` package) or via the official bash installer. Having both installed causes conflicts - the npm version in PATH would shadow the bash-installed binary. The fix removes npm/bun versions first, then runs the official installer which installs to `~/.opencode/bin/opencode`. Version checking now consistently uses npm registry to compare against the bash-installed version.

---

## [5.4.0] - 2026-02-05

### Removed

**Hookify Plugin Integration**

- Removed all hookify quality check rules from dotfiles (15 rule files deleted)
- Removed hookify deployment logic from `deploy.sh` and `deploy.ps1`
- Removed hookify references from `README.md` and `allow.sh`
- Hookify was causing PreToolUse hooks to fire on every tool call (including read-only tools like `find_symbol`)
- Quality checks now handled by individual project configurations instead

**Rationale:**

Hookify's PreToolUse hook was registered without tool matchers, causing it to run on every single tool invocation. This included read-only tools like `find_symbol`, `Read`, and even the `Bash` tool. The plugin's event filtering logic had a bug where unmapped tools (event=None) would skip event filtering entirely, potentially loading all rules regardless of their event type. This caused significant performance degradation and unnecessary test runs.

### Changed

**Documentation Updates**

- Updated README.md AI-Native Agentic Development section to remove hookify references
- Updated Claude Code Hooks section to reflect current hook architecture
- Clarified that quality checks are now project-specific configurations

---

## [5.3.14] - 2026-02-03

### Fixed

**Bootstrap - Test-Command False Positive (Windows)**

- Removed all hookify quality check rules from dotfiles
- Removed hookify deployment logic from `deploy.sh` and `deploy.ps1`
- Removed hookify references from `README.md` and `allow.sh`
- Hookify was causing PreToolUse hooks to fire on every tool call (including read-only tools like `find_symbol`)
- Quality checks now handled by individual project configurations instead

### Fixed

**Bootstrap - Test-Command False Positive (Windows)**

- Fixed bug in `bootstrap/lib/common.ps1` where `Test-Command` returned true for non-existent commands
- Removed `where.exe` fallback that was causing false positives
- `where.exe` returns error output (treated as truthy) when command not found
- `Get-Command` alone is sufficient and handles PATH resolution correctly
- This fixes SQLite installation on Windows (and any other tools that may have been skipped)

**Rationale:**

The `where.exe` fallback was intended as redundancy but introduced a bug: PowerShell treats any non-empty output (including error messages) as truthy. This caused the bootstrap to incorrectly detect tools as "already installed" when they weren't, skipping their installation.

---

## [5.3.13] - 2026-02-03

### Added

**Bootstrap - SQLite CLI (All Platforms)**

- Added sqlite installation to bootstrap scripts for all platforms
- Windows: installs via Scoop (`sqlite` package)
- Linux/macOS: installs via Homebrew (`sqlite` package)
- Installed in Phase 5 (CLI Tools) alongside fzf, zoxide, bat, eza, lazygit, gh, ripgrep, fd
- Command: `sqlite3` for SQL database operations
- Added package descriptions to platform-specific files

**Documentation**

- Updated README Core Features to include sqlite in CLI tools list
- Updated CLI Tools section with sqlite entry

### Changed

**Bootstrap Options Table (README)**

- Removed `-SkipUpdate` / `--skip-update` parameter row (deprecated in v5.3.12)

**Rationale:**

SQLite is a ubiquitous SQL database engine useful for development, testing, and local data processing. Having sqlite3 available by default enables quick database operations without additional setup.

---

## [5.3.12] - 2026-02-03

### Added

**Bootstrap - GCC C/C++ Toolchain (Windows)**

- Added gcc installation via Scoop to Windows bootstrap (bootstrap.ps1)
- Installed in Phase 3 (Language Servers) alongside llvm/clangd
- Provides native GCC toolchain for C/C++ development on Windows
- Added package description to Get-PackageDescription function

**update-all - Winget Unknown Package Support**

- Added `--include-unknown` flag to winget upgrade command
- Enables updating packages even when winget doesn't recognize the source
- Improves coverage for manually installed applications

### Removed

**Bootstrap - Skip Update Parameter**

- Removed `-SkipUpdate` / `--skip-update` parameter from bootstrap scripts
- Removed Phase 7 (Update All) function from both bootstrap.ps1 and bootstrap.sh
- Bootstrap now focuses solely on installation, not updates
- Users can run `up` (update-all) separately after bootstrap

**Documentation Cleanup**

- Removed "Skip update" row from Bootstrap Options table in README

**Rationale:**

Bootstrap should focus on installation, not running updates. The update-all step added significant time to bootstrap and wasn't always necessary. Users can now run `up` explicitly when they want to update all packages. GCC was added to provide an alternative C/C++ toolchain on Windows for developers who prefer GCC over Clang/LLVM.

---

## [5.3.11] - 2026-02-01

### Changed

**CLAUDE.md - Simplified Development Protocol**

- Restructured from XML-tag format to plain markdown "Development Protocol"
- Removed verbose XML tags like `<non-negotiables>`, `<core-principles>`, `<verification-loop>`
- Consolidated to clear sections: Prime Directives, Tool Hierarchy, Code Standards, Testing Strategy, Workflow
- More concise and readable while maintaining all essential guidance
- Improved AI parsing with cleaner structure

**Claude Code Hooks - PostToolUse Deprecation**

- Deprecated PostToolUse hooks in favor of Hookify rules
- PostToolUse hooks replaced by per-language Hookify quality check reminders
- Statusline hook remains active and auto-registered
- Legacy hooks preserved as `.disabled` files for reference

**Deploy Scripts**

- deploy.sh: Removed PostToolUse hook deployment and registration
- deploy.sh: Added hookify rules deployment with count display
- deploy.ps1: Added hookify rules count display in deployment output
- Both scripts now only register statusline in Claude Code settings.json

**allow.sh**

- Removed chmod for PostToolUse hooks
- Added hookify rules detection and count display
- Updated comments to reflect PostToolUse deprecation

### Added

**Hookify Rules Documentation**

- README: Added comprehensive Hookify rules section with 16 language-specific rules
- Documents rule names, enabled/disabled management, creation workflow
- Lists all 16 supported languages: Go, Rust, Python, TypeScript, C#, PHP, Shell, Lua, C/C++, Markdown, YAML, JSON, Svelte, Typst, TOML

### Removed

**PostToolUse Hooks**

- Deleted `.claude/hooks/post-tool-use.sh`
- Deleted `.claude/hooks/post-tool-use.ps1`
- Kept as `.disabled` files for reference

**Rationale:**

Hookify rules provide a better developer experience than PostToolUse hooks. They are rule-based, don't require script execution, work immediately after deployment without restart, and provide per-language quality check reminders that trigger automatically when editing files. The CLAUDE.md simplification makes the development protocol more approachable while maintaining all essential guidance.

---

## [5.3.10] - 2026-01-29

### Changed

**CLAUDE.md - Tool Usage Guidance**

- Added guidance to prefer native built-in tools before plugin-provided tools
- Native tools (Read, Write, Edit, Glob, Grep, Bash, LSP, Task) are faster and more reliable
- Plugin tools should only be used when native tools lack the required capability

---

## [5.3.9] - 2026-01-28

### Fixed

**deploy.ps1 - Cygwin chmod Conflict**

- Fixed "Couldn't reserve space for cygwin's heap, Win32 error 0" error on Windows
- The chmod.exe from Scoop's coreutils fails with Win32 error 487
- Now skips chmod call if the command is from Scoop (Cygwin binary)
- Executable bit is not needed on Windows anyway

### Changed

**PowerShell Profile - Alias Conflict**

- Removed `update` alias to avoid conflict with Scoop's internal update function
- Use `up` alias instead to run update-all script

**Documentation - CLAUDE.md**

- Refactored system instructions for clarity

---

## [5.3.8] - 2026-01-25

### Added

**mermaid-cli - Diagram Generation Tool**

- Added mermaid-cli installation to all platforms (Windows, Linux, macOS)
- Package: `@mermaid-js/mermaid-cli` installed via npm global
- Command: `mmdc` for generating Mermaid diagrams from CLI
- Cross-platform support: works on all tested platforms
- Installation in Phase 4 (Linters & Formatters) of bootstrap

**ComfyUI Desktop - AI Image Generation (Windows)**

- Added ComfyUI Desktop installation via winget for Windows 11
- Package ID: `Comfy.ComfyUI-Desktop` installed via winget
- Installation in Phase 5.5 (Development Tools) of bootstrap
- New `gui_apps` category in packages.yaml for GUI applications
- Requires `comfy install` post-installation to complete setup

**Documentation**

- Added mermaid-cli to README CLI tools section
- Added ComfyUI Desktop to README AI Applications section
- Added GUI Applications Post-Installation subsection with comfy install instructions
- Updated packages.yaml header to document gui_apps category
- Updated CLI tools count with mermaid-cli

### Changed

**packages.yaml**

- Added `gui_apps` category for platform-specific GUI applications
- Added mermaid_cli entry to cli_tools section
- Documentation header updated to reflect new category

**bootstrap.ps1 (Windows)**

- Added mermaid-cli installation in Phase 4 (Linters & Formatters)
- Added ComfyUI Desktop installation in Phase 5.5 (Development Tools)
- Both tools respect -DryRun parameter

**bootstrap.sh (Linux/macOS)**

- Added mermaid-cli installation for Unix-like systems
- Added documentation note about ComfyUI requiring manual installation on Linux

**windows.ps1**

- Added package descriptions for `mmdc` and `ComfyUI`

**Rationale:**

mermaid-cli is a cross-platform CLI tool for generating Mermaid diagrams (flowcharts, sequence diagrams, etc.). ComfyUI Desktop is a Windows-only GUI application for AI image generation. The bootstrap script handles the initial installation, but ComfyUI requires running `comfy install` afterward to download models and complete setup.

---

## [5.3.7] - 2026-01-24

### Changed

**README - Core Features Corrections**

- Corrected LSP count from 19 to 20
- Changed "Cross-Platform Support" to "Tested Platforms"
- Removed macOS from tested platforms list
- Updated Claude Code hooks to mention PostToolUse and Stop hooks
- Updated Neovim description to 0.12+ with native built-in features
- Changed Core Features to use plain lists without bold headers
- Updated platform badge to Windows/Linux only

**Rationale:**

The README now accurately reflects the actual implementation. Neovim 0.12+ uses built-in package manager and LSP/Treesitter configuration, not lazy.nvim. macOS support exists in the codebase but is not part of the actively tested platforms.

---

## [5.3.6] - 2026-01-24

### Changed

**README - Core Features Enhancement**

- Moved Core Features section to top of README
- Corrected counts: 19 LSP servers, 30 Treesitter parsers (verified from code)
- Added Neovim 0.12 with lazy.nvim plugin manager
- Added WezTerm GPU-accelerated terminal with IosevkaTerm Nerd Font
- Added tested platforms: Ubuntu 26.04 LTS, Windows 11 with PowerShell 7+
- Added full vibecoding support with Claude Code and OpenCode
- Added quality hooks: Git pre-commit/commit-msg + Claude Code PostToolUse
- Added system instruction sync across repos
- Added Rose Pine theme mention
- Added MCP servers count (4)

**Rationale:**

The Core Features section now appears first and contains accurate, verified information from the actual codebase. Users can immediately see what platforms are tested, what tools are included, and what AI capabilities are supported.

---

## [5.3.5] - 2026-01-24

### Changed

**README Structure and Content**

- Renamed "Core Features & Selling Points" to "Core Features"
- Clarified MCP servers work for both Claude Code and OpenCode
- Merged bootstrap options, configuration, and health/troubleshooting into "Available Commands"
- Removed redundant "Updating" section

### Added

- Manual zai-mcp-server patching instructions for Windows

**Rationale:**

The README structure is now more cohesive with all command-related information grouped together. The updating section was redundant since running bootstrap again accomplishes the same thing.

---

## [5.3.4] - 2026-01-24

### Changed

**Documentation - README Optimization**

- Condensed README.md from 950 lines to 286 lines (~70% reduction)
- Consolidated multi-file documentation into single focused README
- Added Quick Start links to DOCKER_K8S.md and CHANGELOG.md
- Migrated all essential content from deleted docs into README
- Improved readability with clearer section organization

**README Structure**

- Header with badges
- Quick Start (Linux/macOS/Windows) with external references
- Available Commands table
- Core Features & Selling Points
- Complete Tools/Packages Matrix (from TOOLS.md)
- Hooks & Config Merging (from HOOKS.md)
- Neovim Keybindings table (40+ keybindings from init.lua)
- Bootstrap Options
- Configuration (Optional)
- Updating instructions
- Health & Troubleshooting
- Changelog reference

### Removed

**Deprecated Documentation Files**

- TOOLS.md - content migrated to README Tools/Packages Matrix section
- HOOKS.md - content migrated to README Hooks & Config Merging section
- ARCHITECTURE.md - system architecture details no longer needed
- BRIDGE.md - bridge approach documentation consolidated
- QUICKREF.md - quick reference content integrated into README
- HISTORY.md - legacy file museum no longer required
- COMPLETION_SUMMARY.md - temporary summary file
- FIX_SUMMARY.md - temporary fix tracking file

### Fixed

- Restored AGENTS.md, GEMINI.md, RULES.md for deployment via sync-system-instructions
- All system instruction files redirect to CLAUDE.md for unified AI guidance

**Rationale:**

The documentation was scattered across 10+ markdown files, making maintenance difficult and causing information duplication. Consolidating essential information into a single, focused README reduces maintenance burden while preserving all important content. External references (DOCKER_K8S.md, CHANGELOG.md) remain for specialized content.

---

## [5.3.3] - 2026-01-24

### Added

**Yazi Terminal File Manager**

- Added yazi package installation to bootstrap/config/packages.yaml for all platforms
- Linux Debian/Ubuntu: installs via cargo (yazi-cli)
- Linux Arch: installs via pacman
- macOS: installs via Homebrew
- Windows: installs via Scoop
- Minimum version requirement: 0.3.0

**Shell Integration**

- Added `y()` wrapper function to .bash_aliases for bash/Git Bash
- Added `y()` wrapper function to .zshrc for zsh
- Added `y()` function to Microsoft.PowerShell_profile.ps1 for PowerShell 7+
- All wrappers implement cd-on-exit pattern: changes to the last directory visited in yazi
- Uses temp file to capture yazi's exit directory for seamless navigation

**PowerShell Yazi Configuration**

- Added YAZI_FILE_ONE environment variable setup for file previews
- Detects Git's file.exe from both Program Files and Scoop installations
- Enables proper file type detection in yazi previews on Windows

### Changed

**Documentation**

- Added MCP Server Fix for Windows (Manual) section to README.md
- Documents cmd.exe /c wrapper pattern for npx-based MCP servers
- Example configuration for zai-mcp-server
- Updated TOOLS.md to include yazi in CLI tools list

**Rationale:**

Yazi is a modern, blazing-fast terminal file manager written in Rust. It offers asynchronous file operations, thumbnail rendering, and extensive customization. The cd-on-exit wrapper makes it a drop-in replacement for `ranger` with better performance.

---

## [5.3.2] - 2026-01-24

### Added

**Windows LSP Marketplace Auto-Patching**

- Added `Patch-ClaudeLspMarketplace` function to deploy.ps1 for automatic Windows LSP fix
- Added LSP marketplace patching to bootstrap.ps1 Phase 6 (Deploy)
- Automatically wraps npm-installed LSP servers with cmd.exe on Windows:
  - typescript-language-server
  - pyright-langserver
  - intelephense
- Patching is idempotent: checks if already patched before modifying
- Survives marketplace updates when scripts are re-run
- Uses regex-based string replacement to handle PowerShell JSON parsing limitations

### Changed

**README Documentation**

- Updated LSP Fix for Windows section to reflect automatic patching
- Removed manual patching instructions
- Added note about idempotent patching behavior

### Fixed

- PowerShell's ConvertFrom-Json cannot handle case-sensitive duplicate keys (`.c` vs `.C` in marketplace.json)
- Bypassed by using direct string replacement instead of JSON parsing

**Rationale:**

The Windows LSP spawn EINVAL issue was previously documented as a manual fix. This automation eliminates the manual step while being safe to run multiple times. The regex approach avoids PowerShell's JSON parsing limitations with case-sensitive keys.

---

## [5.3.1] - 2026-01-23

### Fixed

- git-update-repos.ps1: Fixed scope shadowing bug in Wc function where parameter $c shadowed script-scoped $C hashtable, now uses $script:C.N for explicit script scope access

## [5.3.0] - 2026-01-23

### Added

**Serena MCP Integration**

- Added Serena MCP server to OpenCode configurations across all platforms (Windows, Linux, macOS)
- Serena provides semantic code navigation, symbol-level editing, and LSP-powered code analysis
- Configured to run via uvx from GitHub (git+https://github.com/oraios/serena)
- Eliminates local Python package management for Serena - always runs latest version

**uv Python Package Manager**

- Added uv installation to bootstrap scripts (both PowerShell and bash)
- uv is now installed in Phase 2 (Core SDKs) alongside Python and Node.js
- Required for running Serena via uvx and recommended for modern Python projects
- Windows: installed via official PowerShell script (astral.sh/uv/install.ps1)
- Linux/macOS: installed via official bash script (astral.sh/uv/install.sh)

**uv Self-Update**

- Added uv self-update to update-all.ps1 and update-all.sh scripts
- uv updates automatically when running update-all alongside other package managers

**CLAUDE.md Documentation**

- Restructured CLAUDE.md with XML-style tags for better AI parsing
- Added Serena MCP to tool usage documentation
- Enhanced requirements contract with task planning step

### Changed

**OpenCode Configuration**

- deploy.ps1: Enhanced OpenCode config merge with robust scalar handling
- deploy.sh: Added serena to universal MCPs list
- MCP config now merges across all platforms with conflict detection

**Bootstrap Phases**

- Phase 2 (Core SDKs) now includes uv installation
- Phase 5.25 (MCP Servers) includes serena configuration

### Fixed

**deploy.ps1 - Scalar MCP Section Handling**

- Fixed issue where bad merges could leave mcp section as a scalar instead of object
- Added type checking to detect and repair malformed mcp sections
- Prevents deploy failures from previous manual config edits

**Rationale:**

Using uvx to run Serena directly from GitHub is the recommended approach for MCP servers. This eliminates local package management complexity, ensures the latest version is always used, and simplifies updates. The uv package manager itself is a modern Python tooling replacement that significantly speeds up package operations.

---

## [5.2.27] - 2026-01-23

### Fixed

**CLAUDE.md - XML Tags and Spelling**

- Fixed all missing closing XML tags (17 sections were unclosed)
- Fixed spelling errors: persspective→perspective, offical→official, oudated→outdated
- Fixed triple-S typo: ADDRESSS→ADDRESS
- Fixed grammar: "implement any thing"→"implementing anything"
- Fixed word choice: "bolting"→"bolding"
- Fixed pluralization: "documentations"→"documentation"
- Fixed capitalization: "pdfs"→"PDFs"
- Fixed terminology: "equivalences"→"equivalents"
- Removed standalone period that created awkward formatting
- Cleaned up migration example phrasing

---

## [5.2.26] - 2026-01-22

### Changed

**CLAUDE.md - Plain Text Format**

- Converted all markdown headers to XML tag format (e.g., ## Non-Negotiables → <non-negotiables>)
- Removed all bold (**text**) and italic (*text*) markdown formatting
- Headers now use descriptive tag names for better AI parsing
- Content remains plain unordered and numbered lists

### Added

**CLAUDE.md - File Handling Section**

- Added new <file-handling> section after <tool-usage>
- Documents how to work with diverse file types (documents, slideshows, spreadsheets, PDFs)
- Includes guidance on transpilation, pandoc, python-docx, python-pptx, CSV handling

**Rationale:**

Plain text formatting with XML-style headers improves Claude Code's parsing of system instructions while maintaining readability for humans.

---

## [5.2.25] - 2026-01-21

### Changed

**update-all Scripts - Verbose Mode as Default**

- Changed output behavior to show all package manager output by default
- Removed output capture and filtering from update-all.ps1 and update-all.sh
- Removed `Invoke-Update` function in favor of direct command execution
- Removed `head -20` output limits from bash script
- All package manager output now streams directly to console

**Package Manager Updates - Full Output Visibility:**

- Scoop: Shows full bucket and app update output
- Winget: Shows installation/download progress without filtering
- Chocolatey: Shows package upgrade details
- NPM/PNPM/BUN/YARN: Shows all package update output
- Go/GUP/Cargo/Rustup: Shows full tool update output
- DOTNET: Shows individual tool update results
- PIP: Shows all package upgrade operations
- Poetry: Shows self update output

### Removed

**jdtls Windows Support**

- Removed jdtls installation from Windows bootstrap (bootstrap.ps1)
- Removed jdtls from Windows platform display name mapping
- Removed Windows from jdtls platform support in packages.yaml
- Neovim config excludes jdtls from LSP list on Windows platforms
- jdtls remains available on Linux and macOS via Homebrew

**Rationale:**

jdtls (Eclipse JDT.LS) is unusable on Windows due to path handling issues and lack of proper Scoop integration. Users requiring Java development on Windows should use WSL or a full IDE.

### Fixed

- README example output now correctly reflects jdtls exclusion on Windows
- TOOLS.md documents jdtls as Linux/macOS only with Windows limitation note

---

## [5.2.24] - 2026-01-20

### Changed

**Claude Code StatusLine - Enhanced Diagnostics**

- Added debug logging to statusline.ps1 for context window troubleshooting
- Logs raw JSON input, context window data, and calculated values to `%TEMP%\claude-statusline-debug.log`
- Added visible debug indicator `[r:X% u:Y%]` when context percentages are both zero
- Debug output helps diagnose `used_percentage`/`remaining_percentage` issues reported in Claude Code 2.1.12

**update-all.ps1 - Sourced Script Compatibility**

- Changed `exit 1` and `exit 0` to `return` in Main function
- Prevents terminal from closing when script is sourced (dot-sourced) instead of executed directly
- Improves compatibility when calling update-all from other scripts or interactive sessions

---

## [5.2.23] - 2026-01-19

### Changed

**Node.js Package Name Standardization**

- Changed Scoop package from `nodejs-lts` to `nodejs` across all Windows scripts
- Updated `bootstrap/bootstrap.ps1` to use `nodejs` package
- Updated `bootstrap/lib/common.ps1` path handling for `nodejs` directory
- Updated `cleanup-scoop-path.ps1` regex pattern to exclude `nodejs` from cleanup
- Updated `cleanup-npm-trash.ps1` npm module paths for `nodejs`
- Updated `update-all.sh` npm global module paths for `nodejs`
- Updated `bootstrap/config/packages.yaml` to use `nodejs` package

### Removed

**Test Infrastructure**

- Removed all test files and test infrastructure (`tests/` directory)
- Removed `coverage.json` and test artifacts
- Removed all PowerShell test files (`.Tests.ps1`)
- Removed all BATS test files (`.bats`)
- Removed test helper scripts and coverage tools

**Rationale:**
Tests were polluting User PATH registry with temporary test directories. Environment-specific testing adds minimal value for a personal dotfiles repository.

---

## [5.2.22] - 2026-01-18

### Changed

**update-all.ps1 - Enhanced Package Management**

- Simplified PIP update to use `pip freeze` one-liner for updating all globally installed Python packages
- Previously only updated `--user` packages, now updates all packages in the environment
- Added CLAUDE CODE CLI update section with version verification against npm registry
- Added OPENCODE AI CLI update section with version verification against npm registry
- Both CLI sections skip updates if already at latest version, showing current version

**Package Update Behavior:**

- PIP: Now runs `pip freeze | %{$_.Split('==')[0]} | % { pip install --upgrade $_ }` to update all packages
- Claude Code CLI: Checks `@anthropic-ai/claude-code` on npm, runs official installer if outdated
- OpenCode CLI: Checks `opencode-ai` on npm, runs official installer via bash if outdated

### Fixed

- PowerShell update-all script now matches bash script functionality for AI CLI tool updates
- All three sections (PIP, Claude Code, OpenCode) now properly increment counters

---

## [5.2.21] - 2026-01-17

### Added

**Bootstrap - Enhanced Progress Notifications**

- Added "Checking..." messages to all bootstrap phases for real-time visibility
- Shows "(up to date)" status for tools already installed
- Affects: Core SDKs, Language Servers, Linters & Formatters, CLI Tools, MCP Servers, Development Tools
- Changed hidden verbose output to visible status messages

**Phase-by-Phase Notifications:**

- Phase 2 (Core SDKs): Go, Rust, dotnet, Bun, OpenJDK now show "Checking..." messages
- Phase 3 (Language Servers): All 16 language servers show individual "Checking..." messages
- Phase 4 (Linters & Formatters): All 26 linters/formatters show individual "Checking..." messages
- Phase 5 (CLI Tools): All 11 CLI tools show individual "Checking..." messages
- Phase 5.25 (MCP Servers): tree-sitter-cli, context7-mcp, playwright-mcp, repomix show "Checking..." messages
- Phase 5.5 (Development Tools): VS Code, Visual Studio, LLVM, LaTeX show "Checking..." messages

### Changed

- `Install-Bun` function now shows "Checking Bun..." instead of "Upgrading Bun..."
- README SDKs table now includes Bun alongside Node.js, Python, Go, Rust, dotnet, OpenJDK
- README idempotency example output updated with new "Checking..." pattern

### Fixed

- Fixed typo in `Install-Rustup`: `GetPackageDescription` → `Get-PackageDescription`

---

## [5.2.20] - 2026-01-17

### Added

**Claude Code StatusLine Configuration**

- Added comprehensive statusline script for PowerShell 7+ (statusline.ps1) with Windows-compatible stdin reading
- Added context window tracking with real-time token usage display
- Added git status indicators showing staged (S#), modified (M#), and untracked (U#) file counts
- Added automatic statusline registration in settings.json during deployment
- Supports Claude Code 2.1.6+ context_window percentage fields with fallback to current_usage calculation

**StatusLine Features:**
- Displays: directory, git branch, git status, model name, tokens/max (percentage remaining), session cost
- Color-coded context warnings: green (>50%), yellow (20-50%), red (<20% remaining)
- Compatible with both Windows (PowerShell 7+) and Linux/macOS (bash)

### Changed

- Updated bash statusline script with enhanced git status and context window calculation
- Updated deploy.ps1 to automatically register statusline in Claude Code settings.json
- Updated README.md deployment documentation to reflect statusline registration

---

## [5.2.19] - 2026-01-17

### Changed

**OpenCode Config - Context7 MCP Remote Endpoint**

- Migrated Context7 MCP from local npx command to remote HTTP endpoint
- Updated all platform configs (Linux, macOS, Windows) to use `https://mcp.context7.com/mcp`
- Requires `CONTEXT7_API_KEY` environment variable to be set
- Enables remote execution without local Node.js dependency

**deploy.ps1 - OpenCode Config Merge Behavior**

- Changed from overwrite to merge for OpenCode config deployment
- Preserves existing user settings while adding/updating MCP servers from dotfiles
- Added deep comparison to detect actual changes before updating
- New output messages: `(created)`, `(merged N server(s))`, `(up to date)`

**deploy.ps1 - Claude Config Deployment**

- Changed from selective file copy to full directory recursion
- Now deploys entire `.claude/` directory including hooks, tdd-guard, and all scripts
- Simplified maintenance - new files are automatically included

**README - Deployment Documentation**

- Updated deployment example output to reflect current deploy.ps1 behavior
- Added "Claude configs" and "OpenCode config" to deployment output
- Added "Deploy Script Behavior" section documenting merge vs. overwrite behavior
- Documented OpenCode merge behavior and output messages

---

## [5.2.18] - 2026-01-17

### Changed

**wezterm.lua - PowerShell 7 as Default Shell on Windows**

- Added platform detection to set `pwsh.exe` as default shell on Windows
- WezTerm now launches PowerShell 7 instead of cmd.exe on Windows
- Linux behavior unchanged (continues to auto-detect zsh)

**deploy.ps1 - WezTerm Background Assets**

- Added assets directory deployment for WezTerm background images
- Copies `assets/*` to `$HOME/assets/` on Windows
- Enables WezTerm background image (tokyo-sunset.jpeg) to load correctly
- Aligns Windows deployment with Linux/macOS behavior

---

## [5.2.17] - 2026-01-17

### Added

**bootstrap.ps1 - WezTerm Installation on Windows**

- Added WezTerm terminal emulator installation to Windows Phase 1 (Foundation)
- Installs via winget using `wez.wezterm` package ID
- Respects `-DryRun` parameter for testing
- Idempotent: skips if already installed
- Aligns Windows bootstrap with Linux/macOS (already install WezTerm)
- README already documented winget installation; bootstrap now implements it

**CLAUDE.md - Windows-Specific Notes**

- Documented PowerShell 7+ requirement for Windows (`pwsh.exe`)
- Clarified to avoid outdated `powershell.exe` (Windows PowerShell 5.1)

---

## [5.2.16] - 2026-01-17

### Fixed

**deploy.ps1 - Neovim and WezTerm Config Deployment**

- Fixed missing Neovim config deployment on Windows (was only deployed on Linux/macOS)
- Neovim config now copied to `%LOCALAPPDATA%\nvim\` (Windows stdpath('config'))
- `lua/` directory recursively copied for modular Neovim configs
- Fixed WezTerm config path to use correct XDG location: `$HOME/.config/wezterm/wezterm.lua`
- Previous incorrect path `%LOCALAPPDATA%\wezterm` has been corrected
- Both configs now properly deployed and verified in bootstrap output

**update-all.sh - AI CLI Update Detection**

- Fixed false positive update detection for Claude Code and OpenCode AI CLIs
- Added `install_and_verify_version` helper function that compares versions before and after install
- Installer now verified against npm registry as external source of truth
- Reports warning if installed version differs from npm version (possible silent failure)
- Prevents misleading "updated" messages when installer re-installs same version

---

## [5.2.15] - 2026-01-17

### Changed

**update-all.ps1 - Native PowerShell 7 Implementation**

- Replaced wrapper script with native PowerShell 7 implementation (no bash dependency)
- `update-all.ps1` is now a pure PowerShell 7 script that directly updates Windows package managers
- Removed `update-all-windows.ps1` (consolidated into single `update-all.ps1`)
- Supports: Scoop, winget, Chocolatey, npm, pnpm, yarn, gup, go, cargo, rustup, dotnet, pip, poetry

**.bash_aliases - Git Bash Compatibility**

- Fixed `up` alias on Windows Git Bash to use `pwsh.exe` instead of `powershell.exe`
- Added platform detection for MINGW/MSYS environments to call correct update script
- Git Bash on Windows now invokes `update-all.ps1` via pwsh7

### Fixed

**Package Manager Detection**

- Fixed winget detection using full path to WindowsApps wrapper executable
- Fixed `$ErrorActionPreference` causing false failures from native command stderr
- Set `$PSNativeCommandUseErrorActionPreference = $false` for proper exit code handling
- Scoop update now handles git bucket warnings gracefully (filters git lock errors)

**Test Coverage**

- Renamed `update-all-windows.Tests.ps1` to `update-all.Tests.ps1`
- Updated all coverage report scripts to reference consolidated `update-all.ps1`

---

## [5.2.14] - 2026-01-17

### Changed

**Windows Sync Scripts - Pure PowerShell 7 Implementation**

- Converted `sync-system-instructions.ps1` to pure PowerShell 7 (no longer a bash wrapper)
- Converted `git-update-repos.ps1` to pure PowerShell 7 (no longer a bash wrapper)
- Converted `deploy.ps1` to pure PowerShell 7 (no longer a bash wrapper)
- Made `deploy.sh` Linux/macOS only (directs Windows users to deploy.ps1)
- All Windows scripts now use PowerShell 7 idioms: `param()`, hashtables, proper error handling
- Removed Windows-specific code paths from bash scripts for cleaner separation

**Script Parity**

- `git-update-repos`: Both bash and PowerShell now detect "already up to date" before pull
- `sync-system-instructions`: Both bash and PowerShell show "already up to date" for commit/push phases
- Platform-specific parameter syntax documented in README

### Fixed

**git-update-repos**

- Bash version now compares LOCAL vs REMOTE HEAD before attempting pull
- Shows "Skipped (already up to date)" instead of "Updated" when no changes
- PowerShell version has equivalent "already up to date" detection
- Prevents misleading "mass updated" output when repos are already current

**sync-system-instructions**

- Bash version shows "already up to date (no changes to commit)" in commit phase
- Bash version shows "already up to date (nothing to push)" in push phase
- PowerShell version has equivalent status messages
- Fixed arithmetic expansion for Git Bash compatibility (`|| true`)

**Documentation**

- README Quick Start now correctly uses `.\bootstrap.ps1` on Windows (not `.\deploy.ps1`)
- README Updating section uses `.\bootstrap.ps1` on Windows
- Added platform-specific parameter comparison tables
- Added Entry Point Scripts table with Platform column
- Windows uses `.ps1` (pure PowerShell 7), Linux/macOS use `.sh` (bash)

---

## [5.2.13] - 2026-01-17

### Fixed

**PATH Persistence for Already-Installed Tools**

- Claude Code CLI: Now ensures ~/.local/bin is added to User PATH even when already at latest version
- OpenCode AI CLI: Now ensures ~/.opencode/bin is added to User PATH even when already at latest version
- Previously, if a tool was already installed at the correct version, PATH was never configured
- This caused tools to not be found in new terminal sessions even though the binary existed

### Changed

- bootstrap.ps1: Added Add-ToPath call for Claude Code and OpenCode when skipping install
- bootstrap.sh: Added ensure_path call for Claude Code and OpenCode when skipping install

---

## [5.2.12] - 2026-01-17

### Changed

**OpenCode AI CLI Installation**

- Switched from npm-based installation to official installer (curl -fsSL https://opencode.ai/install | bash)
- Official installer installs to ~/.opencode/bin on all platforms
- Old npm version is automatically uninstalled during migration
- Added version-aware checking to prevent unnecessary reinstalls

**Version Detection**

- Claude Code CLI now displays version in skip message: "already at latest version (2.1.9)"
- OpenCode AI CLI displays version: "already at latest version (1.1.23)"
- Both tools now check versions against npm registry before installing

**Bootstrap Idempotency**

- npm package version checking fixed to only check top-level packages (not transitive dependencies)
- Prettier and other npm packages no longer show as outdated due to dependency version mismatches
- Added PATH shadowing prevention: old npm shims are removed before version checks

### Fixed

**npm Package Version Checking**

- Fixed false positives from `npm outdated -g` reporting transitive dependency versions
- Changed to use `npm list -g --json --depth=0` for accurate top-level version detection
- Affected both PowerShell (Test-NpmPackageNeedsUpdate) and Bash (npm_package_needs_update)

**Invalid npm Package Cleanup**

- cleanup-npm-trash.ps1 now checks scoop-persisted nodejs-lts location
- update-all.sh now checks multiple npm locations on Windows
- Fixes blocks from invalid packages like .intelephense-* that npm cannot uninstall itself

### Added

**Cleanup Scripts**

- cleanup-npm-trash.ps1: Removes invalid npm packages (names starting with dot)
- cleanup-scoop-path.ps1: Removes individual scoop app paths from User PATH

**Documentation**

- README idempotency section updated with full Windows bootstrap output
- Shows version-aware detection for Claude Code and OpenCode AI CLI

---

## [5.2.11] - 2026-01-13

### Fixed

**sync-system-instructions.sh**

- Hardcoded DOTFILES_DIR to ~/dev/github/dotfiles as per README Quick Start
- Removed complex symlink resolution logic in favor of explicit path
- Script now works correctly whether run from dotfiles dir or ~/dev

**Documentation**

- Added prominent notice in Quick Start that repo MUST be cloned to ~/dev/github/dotfiles
- Added note in Git Repository Management section about sync-system-instructions path requirement
- Clarified that several scripts depend on this exact location to function correctly

---

## [5.2.10] - 2026-01-13

### Added

**Documentation**

- RULES.md now redirects to CLAUDE.md for unified development guidelines
- Centralizes all AI assistant instructions across AGENTS.md, GEMINI.md, and RULES.md

### Fixed

**deploy.sh**

- Added merge_gitconfig() function to preserve user.name and user.email
- Git config merge instead of overwrite when deploying ~/.gitconfig
- Keeps user identity from existing config when updating dotfiles settings

**sync-system-instructions.sh**

- commit_changes() now uses config override from dotfiles repo as fallback
- Shows helpful message when git identity is missing with setup instructions
- Improved error visibility for commit/push failures

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
| 5.9.0   | 2026-02-13 | OpenCode via bun on Windows, PowerShell profile @args pass-through, deploy profile reload               |
| 5.8.0   | 2026-02-12 | OpenCode update reliability fix, deploy verbose logging, shim cleanup alignment                          |
| 5.7.0   | 2026-02-11 | Bootstrap GCC verification, update-all AI CLI verification (claude-code, opencode)                        |
| 5.6.0   | 2026-02-08 | GCC installation verification via --version, Install-ScoopPackage execution check                       |
| 5.5.0   | 2026-02-07 | Skip pip flag, pip update method fix, OpenCode CLI update fix                                            |
| 5.3.13  | 2026-02-03 | SQLite CLI added to all platforms, removed -SkipUpdate from README table                                  |
| 5.3.12  | 2026-02-03 | GCC added to Windows bootstrap, winget --include-unknown, removed update-all from bootstrap               |
| 5.3.11  | 2026-02-01 | CLAUDE.md simplified, PostToolUse hooks deprecated, Hookify rules integration                             |
| 5.3.10  | 2026-01-29 | CLAUDE.md tool usage guidance: prefer native built-in tools before plugin tools                           |
| 5.3.9   | 2026-01-28 | Cygwin chmod fix, PowerShell update alias removal                                                         |
| 5.3.8   | 2026-01-25 | mermaid-cli diagram generation, ComfyUI Desktop AI image gen, gui_apps category, comfy install note          |
| 5.3.7   | 2026-01-24 | README corrections: LSP count 20, tested platforms, Neovim 0.12+ native, Stop hooks                    |
| 5.3.6   | 2026-01-24 | Core Features enhancement, corrected counts, added Neovim/WezTerm details                                 |
| 5.3.5   | 2026-01-24 | README refinements, merged sections, added zai MCP patching                                             |
| 5.3.4   | 2026-01-24 | Documentation consolidation, README 70% reduction, single-file focus                                    |
| 5.3.3   | 2026-01-24 | Yazi terminal file manager with cd-on-exit, MCP fix documentation                                      |
| 5.3.2   | 2026-01-24 | Windows LSP marketplace auto-patching, automated cmd.exe wrapper for npm-installed LSPs           |
| 5.3.1   | 2026-01-23 | git-update-repos.ps1 scope shadowing fix                                                          |
| 5.3.0   | 2026-01-23 | Serena MCP integration via uvx, uv package manager, scalar handling fix, CLAUDE.md XML tags              |
| 5.2.17  | 2026-01-17 | Added WezTerm installation to Windows bootstrap, documented PowerShell 7+ requirement                   |
| 5.2.16  | 2026-01-17 | Fixed Neovim/WezTerm config deployment on Windows, AI CLI update detection fix                           |
| 5.2.15  | 2026-01-17 | Native PowerShell 7 update-all.ps1, fixed winget/scoop detection, Git Bash pwsh.exe alias               |
| 5.2.14  | 2026-01-17 | Pure PowerShell 7 scripts for Windows, script parity, "already up to date" detection                     |
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

[Unreleased]: https://github.com/lavantien/dotfiles/compare/v5.9.0...HEAD
[5.9.0]: https://github.com/lavantien/dotfiles/compare/v5.8.0...v5.9.0
[5.8.0]: https://github.com/lavantien/dotfiles/compare/v5.7.0...v5.8.0
[5.7.0]: https://github.com/lavantien/dotfiles/compare/v5.6.0...v5.7.0
[5.6.0]: https://github.com/lavantien/dotfiles/compare/v5.5.0...v5.6.0
[5.5.0]: https://github.com/lavantien/dotfiles/compare/v5.3.14...v5.5.0
[5.3.14]: https://github.com/lavantien/dotfiles/compare/v5.3.13...v5.3.15
[5.3.13]: https://github.com/lavantien/dotfiles/compare/v5.3.12...v5.3.13
[5.3.12]: https://github.com/lavantien/dotfiles/compare/v5.3.11...v5.3.12
[5.3.11]: https://github.com/lavantien/dotfiles/compare/v5.3.10...v5.3.11
[5.3.10]: https://github.com/lavantien/dotfiles/compare/v5.3.9...v5.3.10
[5.3.9]: https://github.com/lavantien/dotfiles/compare/v5.3.8...v5.3.9
[5.3.8]: https://github.com/lavantien/dotfiles/compare/v5.3.7...v5.3.8
[5.3.7]: https://github.com/lavantien/dotfiles/compare/v5.3.6...v5.3.7
[5.3.6]: https://github.com/lavantien/dotfiles/compare/v5.3.5...v5.3.6
[5.3.5]: https://github.com/lavantien/dotfiles/compare/v5.3.4...v5.3.5
[5.3.4]: https://github.com/lavantien/dotfiles/compare/v5.3.3...v5.3.4
[5.3.3]: https://github.com/lavantien/dotfiles/compare/v5.3.2...v5.3.3
[5.3.2]: https://github.com/lavantien/dotfiles/compare/v5.3.1...v5.3.2
[5.3.1]: https://github.com/lavantien/dotfiles/compare/v5.3.0...v5.3.1
[5.3.0]: https://github.com/lavantien/dotfiles/compare/v5.2.27...v5.3.0
[5.2.27]: https://github.com/lavantien/dotfiles/compare/v5.2.26...v5.2.27
[5.2.26]: https://github.com/lavantien/dotfiles/compare/v5.2.25...v5.2.26
[5.2.25]: https://github.com/lavantien/dotfiles/compare/v5.2.24...v5.2.25
[5.2.16]: https://github.com/lavantien/dotfiles/compare/v5.2.15...v5.2.16
[5.2.15]: https://github.com/lavantien/dotfiles/compare/v5.2.14...v5.2.15
[5.2.14]: https://github.com/lavantien/dotfiles/compare/v5.2.13...v5.2.14
[5.2.13]: https://github.com/lavantien/dotfiles/compare/v5.2.12...v5.2.13
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
