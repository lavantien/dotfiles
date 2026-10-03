# Changelog

All notable changes to this project are documented in this file, newest first. One short line per release states what happened, with no detail enumeration, the commit history carries the detail. Versioning is major.minor. Unreleased work lands under an `## [Unreleased]` heading that is renamed to the version and date at release time.

## [5.34.0] - 2026-10-03

The books corpus grounding gained a chapter-level lookup layer with the books-index twins generating BOOKS.md and the CLAUDE.md appendix table.

## [5.33.0] - 2026-10-03

The remember plugin was removed entirely and retired through settings.retired.json so deploy deletes it, together with its data directory and README entries.

## [5.32.0] - 2026-10-03

CLAUDE.md gained 2 working principles: browser instances terminate after browser MCP work, and every crawl or sourcing action leaves a physical text artifact.

## [5.31.0] - 2026-10-03

CLAUDE.md gained the quota guard, books grounding, and subagent fan-out principles, and the workflow rule was aligned to the same 4 plus 1 slot model.

## [5.30.0] - 2026-10-01

The sync-release-notes twins push each changelog section to its GitHub release, the changelog became prose summaries, and the writing rules tightened around density, verification, and sentence case.

## [5.29.1] - 2026-10-01

CLAUDE.md gained a Principles section carrying the general development guidelines from TDD through concurrency to prose rules.

## [5.29.0] - 2026-10-01

Deploy honors settings.retired.json on both platforms, the settings merge became template-priority, and the misspelled CLAUDE_CODE_MAX_OUTPUT_TOKEN was retired for the documented name.

## [5.28.1] - 2026-09-30

The wording rules banned say the word, and a deploy.ps1 guard fix stopped non-object settings files aborting the merge.

## [5.28.0] - 2026-09-27

update-all.ps1 gained winget location upgrades for packages like Battle.net, the file size cap rose to 1000 SLOC, and non-object settings files no longer abort deploy.

## [5.27.2] - 2026-09-25

The CLAUDE.md redirects in AGENTS.md, GEMINI.md, and RULES.md now target the repo-relative path, fixing the broken home path links.

## [5.27.1] - 2026-09-24

The CLAUDE.md file size cap rose from 400 to 500 SLOC.

## [5.27.0] - 2026-09-24

CLAUDE.md now requires sub-agents to run on the primary model, never haiku or small models, closing the explicit spawn gap.

## [5.26.2] - 2026-09-24

CLAUDE.md rule 2 now centralizes every config, constant, and tunable into a single hub, with inline test tables the only exception.

## [5.26.0] - 2026-09-23

The settings template pins CLAUDE_CODE_SUBAGENT_MODEL so sub-agents run on the same model as the main session.

## [5.25.0] - 2026-09-23

The pre-commit twins gained a typos gate installed by bootstrap, adopted the universal rewrite, and fixed staging and ArgumentList bugs, while CLAUDE.md gained the Makefile-first rule.

## [5.24.3] - 2026-09-23

CLAUDE.md gained the plan execution workflow: conflict-free task lists, sub-agent fan-out, immediate disposal, and small atomic commits.

## [5.24.2] - 2026-09-22

The testing protocol now requires 2 independent adversarial agents to attack a change before it is declared done.

## [5.24.1] - 2026-09-19

README gained a foldable day-to-day Neovim usage guide above the keybinding table, and the changelog link refs were completed.

## [5.24.0] - 2026-09-19

init.lua adopted the nvim-treesitter main rewrite and 0.13 behaviors with a committed plugin lock, fixed treesitter, completeopt, and LSP root marker bugs, and replaced oil.nvim, fidget.nvim, and serena with builtins or removal.

## [5.23.0] - 2026-09-16

The commit-msg hooks strip harness-injected AI attribution trailers before validation, and CLAUDE.md rule 5 declares the injection hostile.

## [5.22.2] - 2026-09-14

CLAUDE.md rule 1 was rewritten as never assume, always double check and verify, against canonical sources and the physical codebase.

## [5.22.1] - 2026-09-03

CLAUDE.md gained a style rule for direct literal words and banned the buzzwords inventory and seams.

## [5.22.0] - 2026-09-03

This release contains cleanup chores only.

## [5.21.2] - 2026-09-03

The banned buzzwords list expanded with heavy lifting, load-bearing, footgun, provenance, spine, and ground truth.

## [5.21.1] - 2026-09-01

The settings template points ANTHROPIC_DEFAULT_HAIKU_MODEL at the flash model so haiku-class calls stop hitting the primary.

## [5.21.0] - 2026-08-31

Deploy injects the settings template fill-missing-only with backup support and the installed marker, deploy.sh gained the deep OpenCode MCP merge, and dead code and shellcheck warnings were cleared.

## [5.20.0] - 2026-08-23

CLAUDE.md restructured Voice and Format into 5 numbered rules and expanded the banned words list.

## [5.19.0] - 2026-08-09

CLAUDE.md gained the Voice and Format section, leaving rule 4 on code simplicity only.

## [5.18.0] - 2026-07-07

The keep it plain rule now forbids em dashes, writing tropes, and cliches, and the file was cleaned to follow it.

## [5.17.0] - 2026-06-20

The keep it plain rule now demands the simplest solution, code, and architecture, with comments only where non-obvious.

## [5.16.0] - 2026-05-13

CLAUDE.md banned manual bash file editing because built-in tools prevent corruption and side effects, and required a baseline run before TDD work.

## [5.15.0] - 2026-04-22

Two updater commands were fixed: bun remove -g replaced the nonexistent bun pm rm, and uv updates rerun the standalone installer.

## [5.14.0] - 2026-04-18

Claude Code on Windows moved from bun to the native installer across bootstrap and the update scripts, dropping the bun dependency.

## [5.13.1] - 2026-04-08

The sync-system-instructions twins remove stale per-repo CLAUDE.md copies during the copy phase, closing the stale window before commit.

## [5.13.0] - 2026-04-08

CLAUDE.md left the sync file list and now deploys globally only, while AGENTS.md, GEMINI.md, and RULES.md became minimal redirects to the global file.

## [5.12.0] - 2026-04-08

Deploy stopped shipping the .claude.json template, which only wrote an empty mcpServers object and risked overwriting user config.

## [5.11.0] - 2026-04-08

CLAUDE.md was restructured from 6 sections into 4 by removing duplicated instructions, and the redirect files went back to repo-relative links.

## [5.10.0] - 2026-02-28

CLAUDE.md gained 5 protocol additions including baseline first and no skipped tests, and the statusline unified on one bash script for every platform.

## [5.9.0] - 2026-02-13

Windows opencode installs moved to bun because the official installer mishandles Windows paths, and the PowerShell profile gained flag passthrough and global function reload.

## [5.8.0] - 2026-02-12

Silent opencode update failures were fixed by stopping running processes, clearing npm shims, and probing the full binary path for version checks.

## [5.7.0] - 2026-02-11

Bootstrap and update scripts verify commands execute before counting tools as installed, so broken shims trigger reinstallation.

## [5.6.0] - 2026-02-08

The Windows gcc check now verifies gcc --version executes, so a broken Scoop shim triggers reinstallation.

## [5.5.0] - 2026-02-07

The update scripts gained a pip skip flag, Windows pip updates switched to python -m pip, and opencode version checks take the npm registry as truth.

## [5.4.0] - 2026-02-05

The hookify integration was removed entirely because its hook fired on every tool invocation and degraded performance.

## [5.3.14] - 2026-02-03

A Test-Command false positive that treated error output as truth was fixed by dropping the where.exe fallback, unblocking skipped installs like SQLite.

## [5.3.13] - 2026-02-03

The sqlite CLI joined bootstrap on all platforms, and the README dropped the deprecated skip update row.

## [5.3.12] - 2026-02-03

Windows bootstrap gained the GCC toolchain, winget upgrades pass --include-unknown, and the SkipUpdate parameter left both bootstrap scripts.

## [5.3.11] - 2026-02-01

CLAUDE.md dropped its XML tags for plain markdown sections, and the PostToolUse hooks were deprecated and replaced by per-language hookify rules.

## [5.3.10] - 2026-01-29

CLAUDE.md gained tool usage guidance preferring native built-in tools over plugin tools.

## [5.3.9] - 2026-01-28

deploy.ps1 skips the Scoop cygwin chmod that failed with Win32 error 487, and the PowerShell profile dropped the update alias that clashed with Scoop.

## [5.3.8] - 2026-01-25

Bootstrap gained mermaid-cli on all platforms and the Windows-only ComfyUI app through winget, with a gui_apps category in packages.yaml.

## [5.3.7] - 2026-01-24

The README core features were corrected against the implementation, from LSP counts to the platform badge and tested platforms.

## [5.3.6] - 2026-01-24

The README core features section moved to the top and was rebuilt with counts verified from the code.

## [5.3.5] - 2026-01-24

The README was reorganized with merged command sections, a dropped redundant Updating section, and manual zai-mcp-server patching instructions for Windows.

## [5.3.4] - 2026-01-24

The README was condensed from 950 to 286 lines by consolidating scattered docs, and 8 deprecated documentation files were removed.

## [5.3.3] - 2026-01-24

The yazi file manager joined bootstrap on all platforms with cd-on-exit shell wrappers and Windows file preview detection.

## [5.3.2] - 2026-01-24

Deploy automatically wraps npm LSP servers with cmd.exe on Windows, fixing the LSP spawn EINVAL issue idempotently.

## [5.3.1] - 2026-01-23

A scope shadowing bug in git-update-repos.ps1 was fixed with explicit script scope access.

## [5.3.0] - 2026-01-23

The Serena MCP server joined the OpenCode configs with uv installed by bootstrap, and deploy.ps1 gained a deep mcp merge with malformed section repair.

## [5.2.27] - 2026-01-23

CLAUDE.md cleanup closed all 17 unclosed XML sections and fixed a batch of misspellings and wording errors.

## [5.2.26] - 2026-01-22

CLAUDE.md converted its headers to XML tag format and gained a file handling section for documents, slides, spreadsheets, and PDFs.

## [5.2.25] - 2026-01-21

The update scripts stream all package manager output by default, and jdtls left Windows because Eclipse JDT.LS is unusable there.

## [5.2.24] - 2026-01-20

statusline.ps1 gained debug logging for context window troubleshooting, and update-all.ps1 returns from Main so dot-sourced terminals stay open.

## [5.2.23] - 2026-01-19

The Scoop Node.js package moved from nodejs-lts to nodejs, and the test infrastructure was removed as low value for a personal repo.

## [5.2.22] - 2026-01-18

update-all.ps1 upgrades every global pip package and gained registry-checked update sections for the Claude Code and OpenCode CLIs.

## [5.2.21] - 2026-01-17

Bootstrap phases print checking and up to date status for real-time visibility across every install category.

## [5.2.20] - 2026-01-17

A PowerShell statusline tracks the context window, git status counts, and session cost with color-coded warnings, registered automatically at deploy.

## [5.2.19] - 2026-01-17

Context7 moved to its remote HTTP endpoint, deploy.ps1 merges the OpenCode config while preserving user settings, and Claude config deployment became full directory recursion.

## [5.2.18] - 2026-01-17

WezTerm launches PowerShell 7 on Windows through platform detection, and deploy.ps1 ships the background image assets.

## [5.2.17] - 2026-01-17

Windows bootstrap installs WezTerm through winget, matching the other platforms, and CLAUDE.md documented the pwsh requirement.

## [5.2.16] - 2026-01-17

deploy.ps1 fixed the missing Windows Neovim and WezTerm config paths, and update-all.sh stopped reporting false CLI updates through registry version comparison.

## [5.2.15] - 2026-01-17

update-all.ps1 became a pure PowerShell 7 script absorbing the Windows variant, with winget and Scoop detection fixes.

## [5.2.14] - 2026-01-17

The Windows utility scripts became pure PowerShell 7 implementations, deploy.sh went Linux and macOS only, and both twins report already up to date accurately.

## [5.2.13] - 2026-01-17

Bootstrap configures PATH for the AI CLIs even when the install is skipped, so the binaries are findable in new terminals.

## [5.2.12] - 2026-01-17

OpenCode moved to its official installer with registry-aware skipping, npm version checks stopped reporting transitive versions, and 2 cleanup scripts arrived.

## [5.2.11] - 2026-01-13

sync-system-instructions hardcodes the required clone path, and the README now states the location requirement prominently.

## [5.2.10] - 2026-01-13

RULES.md redirects to CLAUDE.md, deploy.sh merges the user gitconfig, and the sync script handles a missing git identity.

## [5.2.9] - 2026-01-13

A documentation sweep corrected tool and test counts against the code and standardized the clone path and config names.

## [5.2.8] - 2026-01-13

sync-system-instructions stopped reporting success for pushes that did nothing, printing true commit and push status per repository.

## [5.2.7] - 2026-01-13

A set -e arithmetic bug that exited sync-system-instructions after the first repository was fixed, and the Claude CLI commit dependency became pure git.

## [5.2.6] - 2026-01-12

Bootstrap gained a distro-agnostic auto-correction system that removes and reinstalls 30+ packages from unknown sources, keeping system Python safe.

## [5.2.5] - 2026-01-12

PHP now installs with the curl extension Composer needs on every platform, so Composer stops falling back to slow HTTP.

## [5.2.4] - 2026-01-12

Rust build dependencies install even when rustup is already present, keeping pkg-config and OpenSSL headers available for cargo.

## [5.2.3] - 2026-01-12

Bootstrap installs pkg-config and the OpenSSL development headers before Rust so cargo packages with native dependencies compile.

## [5.2.2] - 2026-01-12

The update script runs rustup before cargo and auto-installs cargo-update so cargo package updates have their manager.

## [5.2.1] - 2026-01-12

Bootstrap installs cargo-update on every platform, and CLAUDE.md gained research and testing strategy sections.

## [5.2] - 2026-01-10

tree-sitter-cli joined bootstrap and Neovim auto-installs 32 parsers under the nvim-treesitter v2 API, fixing silent install failures.

## [5.1] - 2026-01-10

The default theme switched from gruvbox to rose-pine across all configs, treesitter highlighting was fixed for Neovim 0.11+, and deploy ships the WezTerm background assets.

## [5.0] - 2026-01-10

The Linux bootstrap was rewritten Homebrew-first for Ubuntu 26.04 LTS, with git hooks and Claude tooling moved to .config paths, per-platform opencode configs, new tests, and bashcov coverage.

## [4.4] - 2026-01-07

git-update-repos moved to the authenticated gh repo list so private repositories are included, replacing the public API curl logic.

## [4.3] - 2026-01-07

goimports stopped reinstalling through GOPATH normalization and exact PATH matching, and Ruby left the bootstrap as coverage moved to kcov only.

## [4.2] - 2026-01-03

PATH detection was fixed for Scoop, winget, and npm packages, and the test infrastructure stopped wiping User PATH registry entries.

## [4.1] - 2026-01-02

The README took real coverage measurements, gained a sequence diagram, and dropped the inline navigation links.

## [4.0] - 2026-01-02

The PowerShell scripts became thin wrappers over shared bash logic with paired entry points, a YAML config bridge, phase-based idempotent bootstrap, and expanded cross-platform testing.

## [3.3.3] - 2026-01-01

PowerShell syntax errors and alias conflicts in the bootstrap scripts were fixed, and the README was clarified.

## [3.3] - 2026-01-01

PowerShell syntax errors were fixed throughout the codebase, and the README was updated for clarity.

## [3.2] - 2026-01-01

The README sections were reorganized with numbering and section navigation.

## [3.1] - 2026-01-01

The Neovim keybindings docs were fixed, and Claude Code, hidden hotkey, and WezTerm sections joined the README.

## [3.0] - 2026-01-01

Version 3.0 brought the YAML config system, BATS and Pester testing, Conventional Commits hooks, Claude Code hooks, system instruction sync, and installation categories.

## [2.2] - 2025-12-31

The README documentation and the verbose output of the scripts were improved.

## [2.1] - 2025-12-31

update-all was refactored for modularity and maintainability, with better package manager detection.

## [2.0] - 2025-12-31

System prompts auto-distribute across all repositories for multiple AI assistants, with stronger commit validation and bootstrap improvements.

## [1.0] - 2025-12-30

Initial release with cross-platform deploy and bootstrap covering package managers, SDKs, LSP servers, linters, CLI tools, Neovim, git hooks, shell profiles, and utility scripts.
