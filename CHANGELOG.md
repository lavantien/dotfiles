# Changelog

All notable changes to this project are documented in this file, newest first. Each release is a prose summary of what happened and why, written under the repo writing rules. Versioning follows Semantic Versioning. Unreleased work lands under an `## [Unreleased]` heading that is renamed to the version and date at release time.

## [5.33.0] - 2026-10-03

The remember plugin is gone from the repo entirely. `enabledPlugins.remember@claude-plugins-official` was removed from `.claude/settings.template.json` and added to `.claude/settings.retired.json`, so deploy deletes it from `~/.claude/settings.json` instead of preserving it as a live-only key. A v5.28.1 template sync had copied the live disable flag into the template, and any `enabledPlugins` entry, even a false one, makes the plugin show up in `/plugin`, which is why it kept appearing without ever being installed. The plugin's `.remember/` data directory at the repo root and its `.gitignore` entry were deleted, and the README plugin list and retired-keys table were updated to match.

## [5.32.0] - 2026-10-03

`.claude/CLAUDE.md` gained 2 working principles. Browser hygiene terminates unused browser instances after playwright or direct browser MCP work, or uses the built-in defer cleanup when the MCP provides one, so no orphaned browser process holds resources. Every crawl, sourcing, or transcribing action must leave a physical artifact in a text format, commonly typst, markdown, or code, so the result survives the session and no work reruns, no effort duplicated.

## [5.31.0] - 2026-10-03

`.claude/CLAUDE.md` gained 3 working principles and a matching workflow fix. The quota guard fires a throwaway subagent every 10 minutes to query the glm-plan-usage 5-hour window quota, and pauses all development and fan-out at 95% until the window resets. Books grounding consults `~/dev/github/resume/books` lazily as the canonical reference for languages, math, DSA, ICPC, patterns and concurrency, infrastructure, KDD, game systems, and interview repertoire: locate the matching volume, read only the relevant section, never bulk-load. Subagent fan-out is the default execution mode with 4 concurrent development slots plus 1 temporary slot for auxiliary checks like the quota guard, task lists planned ahead so freed slots roll onto queued work immediately, and finished or failed agents disposed at once. The workflow plan execution rule now states the same 4 plus 1 slot model instead of the old plain max 4, so the two sections cannot disagree.

## [5.30.0] - 2026-10-01

`sync-release-notes` (`sync-release-notes.sh` and `sync-release-notes.ps1`) pushes each CHANGELOG.md section to its GitHub release: it edits already published bodies and cuts releases for tagged versions that lack one, splitting sections with the same bracket-field logic deploy.sh uses for the version marker so the two can never disagree about section starts. It supports a dry run and skips versions without a git tag. CHANGELOG.md itself was rewritten as prose: every release entry is now a summary of what happened and why under the repo writing rules, newest first, with unreleased work landing under an `[Unreleased]` heading that is renamed to the version and date at release time. The stale `.github/RELEASE_NOTES_v4.0.md` artifact was deleted.

`.claude/CLAUDE.md` principles open with a plain `working principles` statement, the constants hub centralizes enums too, the writing principle requires the highest information density and simplicity at the lowest verbosity and noise, zero bluff or unnecessary comments with the prose and code speaking for themselves, and a new principle bans assuming, guessing, or relying on memory in favor of the latest verified data double checked through edge case attacks, e2e, screenshots, profiling, benchmarking, and blind adversarial review. All CLAUDE.md, README.md, and DOCKER_K8S.md headings are sentence case, and README.md and DOCKER_K8S.md were retouched for voice and format compliance, replacing bullet feature lists with prose.

## [5.29.1] - 2026-10-01

`.claude/CLAUDE.md` gained a Principles section with the general development guidelines: TDD, zero hardcode, centralized constants and configs hub, KISS, first principles, bottom-up, no abstraction or complex patterns unless absolutely necessary, concurrency and parallel as native, decisions explainable in the order what, why, how, where, when, and prose following the writing rules.

## [5.29.0] - 2026-10-01

Deploy now honors `.claude/settings.retired.json` on both platforms and deletes the listed dotted paths from `~/.claude/settings.json`. Each entry maps a path to the reason and reference for its retirement. The first entry retires `env.CLAUDE_CODE_MAX_OUTPUT_TOKEN`, a misspelling of the documented `CLAUDE_CODE_MAX_OUTPUT_TOKENS` (https://code.claude.com/docs/en/env-vars), which the template now sets.

The Claude settings merge in `deploy.ps1` and `lib/json-merge.sh` is now template-priority: template values overwrite diverging live values for shared keys recursively while live-only keys, including `env.ANTHROPIC_AUTH_TOKEN`, are preserved. The previous merge only filled missing keys, so template value changes never propagated. In `.claude/settings.template.json`, `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=48.5` triggers autocompact at 485k of the 1M window, down from 93.75, which was possibly inert because the docs say percentages above the default are ignored and the default is not published. The percentage is the documented knob that lowers the trigger below `CLAUDE_CODE_AUTO_COMPACT_WINDOW` (https://code.claude.com/docs/en/env-vars). `CLAUDE_CODE_MAX_OUTPUT_TOKEN` was renamed to the documented `CLAUDE_CODE_MAX_OUTPUT_TOKENS`, and `remember@claude-plugins-official` was disabled to match the live setting.

## [5.28.1] - 2026-09-30

`CLAUDE.md` bans "say the word" under conversational and meta filler in the wording rules. A `deploy.ps1` bug was fixed alongside: the non-object Claude settings guard compares the concrete type name (`$Live.GetType().Name -ne 'PSCustomObject'`) instead of `-is [PSCustomObject]`, which scalars pass in pwsh, so empty, `null`, array, or scalar settings files now skip the merge with a warning instead of aborting the deploy.

## [5.28.0] - 2026-09-27

`update-all.ps1` now upgrades winget packages whose manifest requires an install location explicitly. `Blizzard.BattleNet` declares `InstallLocationRequired`, so it gets `--location C:\Program Files (x86)\Battle.net` and a non-blocking pin before `winget upgrade --all`, which would otherwise prompt interactively for an install root. Locations live in the `$WingetLocationUpgrades` table at the top of the script. `installBehavior.defaultInstallRoot` is deliberately unused because winget appends the package ID to that root, so no root value can produce the `Battle.net` folder.

`CLAUDE.md` rule 8 relaxed the max file size per file from 500 to 1000 SLOC. `deploy.ps1` also stopped aborting the whole deploy when `~/.claude/settings.json` parses to a non-object (empty, `null`, or top-level array): the Claude settings merge now skips with a warning.

## [5.27.2] - 2026-09-25

The CLAUDE.md redirect links in `AGENTS.md`, `GEMINI.md`, and `RULES.md` now target the repo-relative `.claude/CLAUDE.md` instead of the broken `~/.claude/CLAUDE.md`, and the `README.md` sync description was updated to match.

## [5.27.1] - 2026-09-24

`CLAUDE.md` rule 8 relaxed the max file size per file from 400 to 500 SLOC.

## [5.27.0] - 2026-09-24

`CLAUDE.md` now requires that sub-agents never spawn on haiku or small models because they thrash context, and always use the opus or primary model (i.e. GLM-5.3) for sub-agents and agent teams. This closes the gap where `CLAUDE_CODE_SUBAGENT_MODEL` only pins the default and an explicit haiku-class spawn still landed on `glm-5.3-flash[1m]`. The stale GLM-5.1 example is corrected.

## [5.26.2] - 2026-09-24

`CLAUDE.md` rule 2 now centralizes every config, constant, and tunable into a single config hub with no scoped globals and no stray constants. Inline test tables stay the only exception, and any value that keeps reappearing across them must be centralized too.

## [5.26.0] - 2026-09-23

`settings.template.json` sets `CLAUDE_CODE_SUBAGENT_MODEL=glm-5.3[1m]`, pinning sub-agents to the same model as the main session so they no longer fall back to the harness default. The value is injected fill-missing-only on the next deploy.

## [5.25.0] - 2026-09-23

`pre-commit` and `pre-commit.ps1` gained a typos spell check gate over all staged files in every repository. It runs before project-type detection, so dotfiles-only repos are covered too, and it honors `typos.toml` allowlists and excludes. Bootstrap installs typos on every platform in the linters phase: scoop `typos` on Windows, brew `typos-cli` on macOS, and cargo `typos-cli` on Linux. The existing update scripts already refresh it through `scoop update -a`, `brew upgrade --greedy`, and `cargo install-update -a`.

`CLAUDE.md` gained the Makefile-first rule: every development and testing activity goes through a `make` target, never ad hoc bash one-liners, and missing targets get added first. The verification chain runs through `make` targets, agents are disposed as soon as they finish or fail, and sub-agents keep a reading log (`read <path> <lines or grep> - <why>`) appended to their report and never full-read generated files. `pre-commit` also adopted the deployed universal rewrite back into the repo, with OS and project-type detection and per-language checks, closing the drift where the deployed hook had evolved past the repo source.

Two hook bugs were fixed. In `pre-commit`, staged paths with spaces or glob characters no longer word-split into bogus typos arguments and false-block clean commits, via a null-delimited `git diff -z` staging list. Typos exit codes are now reported accurately (2 typos found, 64 unreadable file, 1 usage or config error) and every nonzero code still fails closed. In `pre-commit.ps1`, the typos block now runs after the `Test-Command` definition. It previously sat above the definition and never executed, so every typo committed cleanly through the PowerShell hook. Every `Start-Process -ArgumentList` array concatenation is also parenthesized now. The bare `+` was a parameter binding error that left `$process` null and marked clean commits dirty, latent in the golangci-lint, go vet, ruff, eslint, stylelint, and phpstan blocks too.

## [5.24.3] - 2026-09-23

`CLAUDE.md` gained the plan execution workflow: derive a conflict-free task list from any plan so no 2 concurrent tasks touch the same files or shared state and dependent tasks stay sequenced, fan out sub-agents max 4 at a time with freed slots recycled until the list is empty, dispose finished agents or defer cleanup so none linger holding context, and require each agent to record progress and commit small atomic units often so an outage loses at most the last unit.

## [5.24.2] - 2026-09-22

The `CLAUDE.md` testing protocol now requires adversarial verification before declaring work done, dispatched as 2 independent agents that attack the change without seeing each other's work, with every confirmed finding fixed and the verification chain re-run. The verification chain gained step 8 for it.

## [5.24.1] - 2026-09-19

README gained a foldable day-to-day Neovim usage guide above the keybinding table in the Neovim section, which was renamed from "Neovim Keybindings", and the changelog link refs were completed for 5.22.0 through 5.24.0.

## [5.24.0] - 2026-09-19

`init.lua` pins `nvim-treesitter` to the `main` branch rewrite and adopts 0.13 behaviors: `autoread` with fs-watch reload, and `updatetime` 1000 so `virtual_lines` current-line diagnostics render on `CursorHold`. The unpinned clone had tracked legacy `master`, where the v2 modules do not exist and the parser install block was silently dead. The repo now commits `.config/nvim/nvim-pack-lock.json`, which pins the 7 active plugins, and `deploy.sh` and `deploy.ps1` deploy it next to `init.lua`. `healthcheck.sh` gained an nvim headless startup smoke test.

The treesitter `FileType` autocmd now matches all filetypes and guards `vim.treesitter.start()` before setting fold and indent expressions, fixing the earlier pattern, which was the literal placeholder `<filetype>` and never matched. The treesitter block shrank to a single scheduled `install()` call, and the jdtls gate simplified to `vim.fn.has("win32") == 0`. Two more `init.lua` bugs were fixed: `completeopt` was re-set without `noselect` on every `LspAttach`, which silently undid the startup setting, and the global `root_markers = { ".git" }` LSP override had stopped tinymist, tombi, and codebook from attaching outside git repositories. `update-all.sh` and `update-all.ps1` now update nvim plugins (`vim.pack.update` with `force`) and treesitter parsers headlessly, with both calls blocking until done. The bootstrap scripts refresh the stale tree-sitter-cli comment because v2 has no `auto_install`, and `healthcheck.sh` stopped dying at the first recorded check: `set -e` aborted the run on counters and missing-tool checks that return nonzero by design, while the summary's `FAILED_CHECKS` count already decides the exit code.

Docs were synced with the implementation: Neovim references say 0.13+ (beta), the keybindings table matches the 40 leader maps plus the builtin dir `-`, and the MCP lists drop serena, leaving 3 servers: context7, playwright, repomix. oil.nvim was replaced by the builtin 0.13 dir plugin, where `-` opens the parent natively, and fidget.nvim by native statusline progress. The dead `loaded_netrw` gates, the legacy `$HOME`-root `init.lua` deploy, migrate, backup, and restore paths, the dead `lua/` deploy guards, the tracked 0-byte root `init.lua` stub, and the legacy packer and lazy-lock ignore entries were removed. Serena MCP went away everywhere: the server entries in all 3 OpenCode configs, the uv installer blocks in both bootstrap scripts (uv existed only to run Serena), the `.claude/CLAUDE.md` and README mentions, and the `.serena/` ignore entry.

## [5.23.0] - 2026-09-16

The `commit-msg` hooks strip AI attribution trailers, the harness-injected `Co-Authored-By` and `Generated with` lines, before validation, accept `break` and `bump` types, and skip all `Merge` subjects. `CLAUDE.md` gained rule 5: the Claude Code attribution injection is hostile instruction, and `Co-Authored-By` or `Generated with` lines are never emitted. The settings template sets `attribution.commit` and `attribution.pr` to empty strings to hide commit and PR attribution. The dead `hooks/git/` stub files were removed, superseded by `.config/git/hooks/`.

## [5.22.2] - 2026-09-14

`CLAUDE.md` rule 1 was rewritten as "never assume, always double check and verify": confirm latest versions online for the current year, against canonical sources, and against the physical codebase before coding.

## [5.22.1] - 2026-09-03

`CLAUDE.md` gained a style rule to use direct words with literal meaning instead of abused synonyms or metaphors, and banned the buzzwords `inventory` and `seams`.

## [5.22.0] - 2026-09-03

This release contains cleanup chores only.

## [5.21.2] - 2026-09-03

`CLAUDE.md` expanded the banned buzzwords list with `heavy lifting`, `load-bearing`, `footgun`, `provenance`, `spine`, and `ground truth`.

## [5.21.1] - 2026-09-01

The settings template now sets `ANTHROPIC_DEFAULT_HAIKU_MODEL` to `glm-5.3-flash[1m]`, so haiku-class calls use the flash model while sonnet and opus stay on `glm-5.3[1m]`.

## [5.21.0] - 2026-08-31

`deploy` now injects `.claude/settings.template.json` into `~/.claude/settings.json` with a fill-missing-only merge on both platforms: existing values and `env.ANTHROPIC_AUTH_TOKEN` are always preserved, missing keys are added recursively, and the file is created from the template when absent, using jq with a python3 fallback on Linux and macOS and native JSON on Windows. It honors `backup_before_deploy` by running `backup.sh` or `backup.ps1` as a subprocess before any mutation, where the config was previously read but never acted on, and writes the `~/.dotfiles-installed` marker with UTC timestamp, CHANGELOG version, and OS, which `uninstall.sh` already expected. New flags: `deploy.sh` gets `--skip-config` (~/dev scripts only), `--verbose` (per-file copy log), `--backup`, and `--help`, and `deploy.ps1` gets `-Backup`.

`deploy.sh` gained the deep OpenCode MCP merge matching `deploy.ps1` semantics: template values win shared keys, user servers and user keys survive, and a malformed scalar `mcp` section is repaired. It strips `cmd.exe` wrappers from a Windows-carried Claude LSP `marketplace.json` on Linux and macOS, mirroring the `gh.exe` gitconfig cleanup, and copies `.claude/quality-check.ps1` alongside the bash variant. `bootstrap.sh` gained the `--verbose` flag, previously documented in README but not implemented, matching `-VerboseMode` on Windows. Bootstrap installs coursier on Linux and installs scalafmt, scalafix, and metals through it instead of silently skipping, and its `verify_installed` runs post-install checks for VS Code, coursier, and npm MCP packages.

`deploy.ps1` copies an explicit `.claude` file list instead of the whole tree, matching `deploy.sh`, so `hooks/*.disabled` and `tdd-guard/` no longer deploy. Statusline registration no longer force-overwrites a customized `statusLine` and is filled by the template only when missing. `bootstrap.sh` reuses `npm_package_needs_update` in `install_mcp_servers`, so outdated npm MCP packages update instead of being skipped forever, and `common.sh` `ensure_path` writes the PATH export to shell profiles only once and persists even when the directory is already in the session PATH. Dead code went out: the `bootstrap.ps1` `-SkipUpdate` and `--skip-update` mapping (bootstrap installs missing packages only, and both forwarded paths were broken), the unused `theme`, `categories`, and `auto_update_repos` config reads in `deploy.sh`, and the `linux.sh` `remove_system_package` helper that was defined but never invoked. The recursive `Fill-Missing` in `deploy.ps1` emitted its return value into the caller's pipeline and wrote `settings.json` as a top-level JSON array when nested objects were merged, so the recursion output is now discarded (verified in pwsh 7.6.5). Pre-existing shellcheck warnings were cleared across `bootstrap.sh`, `common.sh`, and `linux.sh` so the repo's own pre-commit hook passes: 7 `A && B || C` install and track patterns became if/else, plus unquoted expansions and a write-only `handled` variable. The `README.md` config table was corrected (`auto_commit_changes`, `auto_update_repos`, `backup_before_deploy`) and deploy flags and Claude Code settings injection are documented with the full parameter list.

## [5.20.0] - 2026-08-23

`CLAUDE.md` restructured Voice & Format into 5 numbered rules covering directness, punctuation and typography, sentence mechanics, banned words and phrases, and delivery consistency, and expanded the banned words list with conversational filler, framing tropes, promotional jargon, and attribution markers.

## [5.19.0] - 2026-08-09

`CLAUDE.md` added a Voice & Format section covering prose tone, banned words, punctuation whitelist, and formatting rules. Rule 4 was trimmed to code-simplicity only, with prose and format rules moved into the new section.

## [5.18.0] - 2026-07-07

`CLAUDE.md` tightened the "Keep it plain" rule to forbid em dashes, writing tropes, and cliches and to require minimal formatting. The existing em dash in rule 4 and the dash substitute in rule 1 were removed so the file follows the new rule.

## [5.17.0] - 2026-06-20

`CLAUDE.md` strengthened the "Keep it plain" rule to require the simplest solution, code, and architecture for the task, and to comment only where non-obvious instead of adding AI-style over-commenting.

## [5.16.0] - 2026-05-13

`CLAUDE.md` gained a rule prohibiting manual bash commands for file editing: the built-in Edit and Write tools prevent corruption and side effects. The baseline-first testing rule was expanded to require running all tests, coverage, and benchmarks before TDD implementation. That early run establishes the regression baseline.

## [5.15.0] - 2026-04-22

Two updater commands were fixed because they could never succeed. `bun pm rm -g` is invalid because `bun pm` has no `rm` subcommand and only printed usage help, so `update-all.ps1`, `update-all.sh`, and `bootstrap.ps1` now call `bun remove -g`. `uv self update` only works when uv came from the standalone installer and fails with a clear error for pip-installed uv, so the update now reruns the standalone installer (`irm https://astral.sh/uv/install.ps1 | iex` on Windows, `curl -LsSf https://astral.sh/uv/install.sh | sh` on Unix).

## [5.14.0] - 2026-04-18

Claude Code on Windows moved from bun to the native installer: `bootstrap.ps1` now installs the CLI with `irm https://claude.ai/install.ps1 | iex`, `update-all.ps1` updates through the same installer, and the Windows branch of `update-all.sh` calls `pwsh.exe -Command "irm https://claude.ai/install.ps1 | iex"`. The bun dependency for Claude Code on Windows is gone. The npm registry version lookup was dropped because the native installer is idempotent and self-versioning, and the bun-specific PATH manipulation (bun global bin, npm shims) went with it.

## [5.13.1] - 2026-04-08

`sync-system-instructions.sh` and `sync-system-instructions.ps1` now remove a stale per-repo `CLAUDE.md` during the copy phase rather than only the commit phase, so repositories no longer hold a stale copy in the window between sync and commit.

## [5.13.0] - 2026-04-08

`CLAUDE.md` left the sync file list in `sync-system-instructions.sh` and `sync-system-instructions.ps1`, so it is no longer copied into individual repos, and both scripts remove stale per-repo copies with `git rm` during the commit phase. `AGENTS.md`, `GEMINI.md`, and `RULES.md` shrank to a minimal `See [CLAUDE.md](~/.claude/CLAUDE.md)` redirect that points at the global `~/.claude/CLAUDE.md`. The per-repo copy was redundant and drifted: `deploy.sh` and `deploy.ps1` already deploy the file globally, so updating dotfiles once and deploying once leaves every repo reading the same file.

## [5.12.0] - 2026-04-08

`deploy.sh` no longer deploys the `.claude.json` template: Claude Code MCP servers are managed via plugins, the template only wrote an empty `{ "mcpServers": {} }`, and deploying it risked overwriting user config. The orphaned `.claude.json.template`, referenced by no script, was deleted.

## [5.11.0] - 2026-04-08

`CLAUDE.md` was restructured from 6 sections into 4 (Rules, Tool Hierarchy, Testing, Workflow) by eliminating redundancy: overlapping Prime Directives merged from 8 to 6 non-repeating rules, Code Standards consolidated into Rules and Testing, and the Verification Chain moved under Testing. Duplicate instructions were removed because testing rules appeared in 3 places, verify-everything in 2, and no-bypassing restated no-test-modification. `AGENTS.md`, `GEMINI.md`, and `RULES.md` reverted to `./CLAUDE.md` links, which are correct for deployed repos where `CLAUDE.md` is synced to the repo root.

## [5.10.0] - 2026-02-28

`CLAUDE.md` gained 5 protocol additions: Prime Directive #3 (never manually copy, everything must be programmatically coherent), Prime Directive #8 (simplest approach, never overcomplicate or add unnecessary comments), the Baseline First testing strategy (run all unit tests before implementing and fix existing failures), the No Skipped Tests strategy (detect and re-enable skipped tests, investigate root causes), and the When Stuck workflow (write one-off programs in `./playground` to isolate and test a hypothesis).

The statusline unified on bash for every platform: `statusline.ps1` was removed, Windows now runs `statusline.sh` through Git Bash or MSYS2, `deploy.ps1` registers `bash ~/.claude/statusline.sh` instead of `pwsh ... statusline.ps1`, and `deploy.sh` simplified its registration to a single command for all platforms. One script now carries the statusline logic for Linux, macOS, and Windows, which simplifies maintenance and keeps behavior consistent. Windows machines typically have Git Bash or MSYS2 available because many development tools require them, so bash is a viable cross-platform option.

## [5.9.0] - 2026-02-13

Windows opencode installation switched from the official bash installer to bun because that installer mishandles Windows paths when called from PowerShell (HOME variable confusion), while bun handles cross-platform path issues automatically. `update-all.ps1` and `bootstrap.ps1` now run `bun install -g opencode-ai` instead of `curl|bash`, and the complex HOME environment variable handling was simplified away. Linux and macOS keep the proven official installer.

The `Update-AllPackages` function in the PowerShell profile gained `@args`, so flags like `-SkipPip` pass through the `up` alias and `up -SkipPip` now works. `deploy.ps1` reloads profile functions into the Global scope after deploying: PowerShell's scope model stops child scripts from modifying the parent scope, so the script redefines `Update-AllPackages` and the `up` alias globally and `update-all.ps1` changes take effect without a shell restart. `update-all.sh` now reports `--skip-pip` in its completion summary, which shows "PIP (skipped by --skip-pip flag)" when the flag is used.

## [5.8.0] - 2026-02-12

Fixed silent opencode update failures, which had two causes: old npm shims shadowing the official binary in PATH so version checks returned stale versions, and running opencode processes preventing the installer from replacing the executable on Windows. `update-all.ps1` now stops any running `opencode.exe` before running the official installer, because Windows cannot replace running executables. `update-all.sh` now cleans up npm shims before its version checks, probes the full binary path `$HOME/.opencode/bin/opencode` instead of relying on PATH, and removes old npm shims from `$NPM_CONFIG_PREFIX/bin` and `$APPDATA/npm` on Windows Git Bash, so npm shims can no longer cause false version detection.

The opencode section of `update-all.sh` was refactored to match the bootstrap approach: clean npm and bun shims first, then update only if the binary exists at the official installer location `$HOME/.opencode/bin/opencode`. `deploy.ps1` gained verbose script deployment logging, on by default, that shows the source timestamp and the destination timestamp before and after each copied script, which makes deployment issues diagnosable.

## [5.7.0] - 2026-02-11

Fixed a class of false up-to-date detection where tools counted as installed because a file existed even though the command did not actually run. `bootstrap.ps1` now verifies `gcc --version` executes before skipping installation as up to date, through a `--version` check added to `Install-ScoopPackage`, so a broken shim triggers reinstallation instead of a skip.

`update-all.ps1` applies the same execution verification to the Claude Code and OpenCode CLIs: it verifies each command works before and after updating, parses versions with regex match groups instead of `.Matches.Value` because that call fails on unexpected output formats, cleans up old npm and bun installations that could shadow official binaries, falls back to an update attempt when a version check is inconclusive, and sets PATH during skips as well as installs.

## [5.6.0] - 2026-02-08

Fixed the gcc installation check in `bootstrap.ps1` to verify the command actually works via `gcc --version` before skipping installation as up to date, with the `--version` verification added to `Install-ScoopPackage`. The bootstrap had trusted Scoop package state and file existence checks, so a broken shim was detected as installed and reinstallation was skipped. Execution verification now confirms the tool is functional before it counts as up to date.

## [5.5.0] - 2026-02-07

Added a pip skip flag to the update scripts: `--skip-pip` in `update-all.sh` and `-SkipPip` in `update-all.ps1` skip pip package updates to speed up update cycles when pip packages are stable. The README Bootstrap Options table gained an Update-All Options section documenting the flag.

Fixed pip updates on Windows by switching from `pip install --upgrade pip` to `python -m pip install --upgrade pip` for both the self-upgrade and package updates, the recommended method on Windows because it avoids pip launcher issues with multiple Python installations. The opencode update now uses the npm registry as the source of truth for version comparison, removes npm and bun installed versions before running the bash installer, and reads the version back from the installed binary path directly, because npm or bun copies in PATH shadowed the binary the installer had just placed at `~/.opencode/bin/opencode`. The GitHub repo reference was corrected from `opencode-ai/opencode` to `anomalyco/opencode`, following the project's migration from `sst/opencode`.

## [5.4.0] - 2026-02-05

Removed the hookify plugin integration entirely: 15 rule files deleted, deployment logic dropped from `deploy.sh` and `deploy.ps1`, and references cleaned out of `README.md` and `allow.sh`. Hookify registered its PreToolUse hook without tool matchers, so it fired on every tool invocation, including read-only tools like `find_symbol`, `Read`, and `Bash`, and its event filtering had a bug where unmapped tools (event `None`) skipped filtering entirely and could load every rule regardless of event type. The result was heavy performance degradation and unnecessary test runs, and quality checks now live in individual project configurations. The README AI-Native Agentic Development and Claude Code Hooks sections were updated to match the new architecture.

## [5.3.14] - 2026-02-03

Fixed a false positive in `Test-Command` in `bootstrap/lib/common.ps1` that returned true for non-existent commands, which had skipped installation of tools such as SQLite on Windows. The `where.exe` fallback was removed: it returns error output when a command is not found, and PowerShell treats any non-empty output, including error messages, as truthy. `Get-Command` alone is sufficient and handles PATH resolution correctly.

## [5.3.13] - 2026-02-03

Added the sqlite CLI to bootstrap on all platforms, installed in Phase 5 (CLI Tools) alongside fzf, zoxide, bat, eza, lazygit, gh, ripgrep, and fd. Windows installs it via Scoop and Linux and macOS via Homebrew, both from the `sqlite` package, providing the `sqlite3` command for SQL database operations. Package descriptions were added to the platform-specific files, and the README Core Features and CLI Tools sections picked up the new entry. The README Bootstrap Options table dropped the deprecated `-SkipUpdate` / `--skip-update` row, deprecated in v5.3.12. Having `sqlite3` available by default enables quick database work for development, testing, and local data processing without extra setup.

## [5.3.12] - 2026-02-03

Added the GCC toolchain to the Windows bootstrap via Scoop in `bootstrap.ps1`, installed in Phase 3 (Language Servers) alongside llvm and clangd to give C and C++ development a native GCC option, with a package description added to `Get-PackageDescription`. `update-all` now passes `--include-unknown` to the winget upgrade command, so packages update even when winget does not recognize the source, which covers manually installed applications.

Removed the `-SkipUpdate` / `--skip-update` parameter and the Phase 7 (Update All) step from both `bootstrap.ps1` and `bootstrap.sh`, because bootstrap should install and the update pass added a lot of time without always being necessary. Users run `up` (update-all) separately when they want updates. The README Bootstrap Options table dropped its "Skip update" row.

## [5.3.11] - 2026-02-01

Restructured `CLAUDE.md` from an XML-tag format to plain markdown as a Development Protocol, dropping verbose tags like `<non-negotiables>`, `<core-principles>`, and `<verification-loop>` and consolidating the content into Prime Directives, Tool Hierarchy, Code Standards, Testing Strategy, and Workflow sections that are shorter and parse more cleanly.

Deprecated the PostToolUse hooks in favor of Hookify rules: `.claude/hooks/post-tool-use.sh` and `.claude/hooks/post-tool-use.ps1` were deleted and kept as `.disabled` files for reference, `deploy.sh` stopped deploying and registering them and instead deploys hookify rules with a count display, `deploy.ps1` shows the same count in its output, `allow.sh` dropped the PostToolUse chmod and gained hookify rule detection with a count display, and both deploy scripts now register only the statusline in Claude Code `settings.json`. The statusline hook stays active and auto-registered. The README gained a Hookify rules section with the 16 language-specific rules (Go, Rust, Python, TypeScript, C#, PHP, Shell, Lua, C/C++, Markdown, YAML, JSON, Svelte, Typst, TOML), their names, how to enable and disable them, and the creation workflow. Hookify rules are rule-based, need no script execution, work immediately after deployment without a restart, and give per-language quality check reminders that trigger automatically when editing files.

## [5.3.10] - 2026-01-29

Added tool usage guidance to `CLAUDE.md`: prefer native built-in tools (Read, Write, Edit, Glob, Grep, Bash, LSP, Task) over plugin-provided tools because they are faster and more reliable, and reach for plugin tools only when native tools lack the required capability.

## [5.3.9] - 2026-01-28

Fixed `deploy.ps1` failing with `Couldn't reserve space for cygwin's heap, Win32 error 0`: the `chmod.exe` from Scoop's coreutils is a Cygwin binary that fails with Win32 error 487, so the chmod call is now skipped when the command resolves to a Scoop source, and the executable bit is not needed on Windows anyway. The PowerShell profile dropped the `update` alias because it conflicted with Scoop's internal update function, and the `up` alias runs update-all instead. `CLAUDE.md` was refactored for clarity.

## [5.3.8] - 2026-01-25

Added mermaid-cli, a cross-platform CLI for generating Mermaid diagrams such as flowcharts and sequence diagrams, to bootstrap on all platforms. The `@mermaid-js/mermaid-cli` npm global package installs in Phase 4 (Linters and Formatters) of both `bootstrap.ps1` and `bootstrap.sh` and provides the `mmdc` command, and both installs respect `-DryRun`.

Added ComfyUI Desktop, a Windows-only GUI application for AI image generation, via winget on Windows 11 with package ID `Comfy.ComfyUI-Desktop`, installed in Phase 5.5 (Development Tools) of `bootstrap.ps1`. `packages.yaml` gained a `gui_apps` category for platform-specific GUI applications plus a `mermaid_cli` entry under `cli_tools`, with the header updated to document the new category. `windows.ps1` gained package descriptions for `mmdc` and `ComfyUI`, and `bootstrap.sh` notes that ComfyUI requires manual installation on Linux. ComfyUI needs `comfy install` run after installation to download models and complete setup, covered by a new GUI Applications Post-Installation subsection in the README alongside the mermaid-cli CLI tools entry and the updated CLI tools count.

## [5.3.7] - 2026-01-24

Corrected the README Core Features to match the implementation: the LSP count went from 19 to 20, the platform badge dropped macOS and shows Windows and Linux only, "Cross-Platform Support" was renamed "Tested Platforms", the Claude Code hooks text now mentions the PostToolUse and Stop hooks, and the Neovim description moved to 0.12+ with native built-in features, since 0.12 uses the built-in package manager and LSP and Treesitter configuration rather than lazy.nvim. Core Features switched to plain lists without bold headers. macOS support still exists in the codebase but is not an actively tested platform.

## [5.3.6] - 2026-01-24

Moved the Core Features section to the top of the README and rebuilt it with counts verified from the code: 19 LSP servers, 30 Treesitter parsers, and 4 MCP servers. The section now lists Neovim 0.12 with the lazy.nvim plugin manager, the GPU-accelerated WezTerm terminal with IosevkaTerm Nerd Font, tested platforms Ubuntu 26.04 LTS and Windows 11 with PowerShell 7+, full vibecoding support with Claude Code and OpenCode, the Git pre-commit and commit-msg quality hooks plus the Claude Code PostToolUse hook, system instruction sync across repos, and the Rose Pine theme. Users can now see the tested platforms, included tools, and AI capabilities at a glance.

## [5.3.5] - 2026-01-24

Reorganized the README: "Core Features & Selling Points" was renamed "Core Features", the MCP servers wording clarifies they serve both Claude Code and OpenCode, and the bootstrap options, configuration, and health and troubleshooting sections merged into "Available Commands". The "Updating" section was dropped as redundant, since running bootstrap again accomplishes the same thing. Added manual `zai-mcp-server` patching instructions for Windows.

## [5.3.4] - 2026-01-24

README.md was condensed from 950 lines to 286 lines, about a 70% reduction, by consolidating documentation that had been scattered across 10+ markdown files into one focused README, because the spread made maintenance difficult and duplicated information. The new README carries a header with badges, a quick start for Linux/macOS/Windows with external references, an available commands table, core features and selling points, a complete tools/packages matrix taken from TOOLS.md, hooks and config merging taken from HOOKS.md, a Neovim keybindings table with 40+ bindings from `init.lua`, bootstrap options, optional configuration, updating instructions, health and troubleshooting, and a changelog reference. The quick start also links to DOCKER_K8S.md and CHANGELOG.md, which remain as external references for specialized content.

Eight deprecated documentation files were removed: the content of TOOLS.md and HOOKS.md moved into the matching README sections, ARCHITECTURE.md's system architecture details were dropped as no longer needed, BRIDGE.md's bridge approach documentation was consolidated, QUICKREF.md's quick reference content was integrated into the README, the HISTORY.md legacy file museum and the temporary COMPLETION_SUMMARY.md and FIX_SUMMARY.md files were deleted. AGENTS.md, GEMINI.md, and RULES.md were restored so `sync-system-instructions` can deploy them, and all three redirect to CLAUDE.md for unified AI guidance.

## [5.3.3] - 2026-01-24

The yazi terminal file manager was added to `bootstrap/config/packages.yaml` for all platforms, with a minimum version requirement of 0.3.0. Debian and Ubuntu install it through cargo (`yazi-cli`), Arch through pacman, macOS through Homebrew, and Windows through Scoop. Shell integration came with a `y()` wrapper in `.bash_aliases` for bash and Git Bash, in `.zshrc` for zsh, and in `Microsoft.PowerShell_profile.ps1` for PowerShell 7+. Every wrapper implements the cd-on-exit pattern, it changes to the last directory visited in yazi by reading a temp file that captures yazi's exit directory, which makes yazi a drop-in replacement for `ranger` with better performance. Yazi is written in Rust and brings asynchronous file operations, thumbnail rendering, and extensive customization.

The PowerShell profile also sets up the `YAZI_FILE_ONE` environment variable for file previews, detecting Git's `file.exe` in both Program Files and Scoop installations so file type detection works in yazi previews on Windows. README.md gained an MCP Server Fix for Windows (Manual) section documenting the `cmd.exe /c` wrapper pattern for npx-based MCP servers with an example configuration for `zai-mcp-server`, and TOOLS.md listed yazi in its CLI tools.

## [5.3.2] - 2026-01-24

A `Patch-ClaudeLspMarketplace` function in `deploy.ps1`, also wired into `bootstrap.ps1` Phase 6 (Deploy), automatically wraps the npm-installed LSP servers `typescript-language-server`, `pyright-langserver`, and `intelephense` with `cmd.exe` on Windows, fixing the LSP spawn EINVAL issue that previously required a manual patch. The patching is idempotent, it checks whether a server is already wrapped before modifying it, and it survives marketplace updates because the scripts re-run it. It works through regex-based string replacement rather than JSON parsing, because PowerShell's `ConvertFrom-Json` cannot handle case-sensitive duplicate keys like `.c` versus `.C` in `marketplace.json`. The README's LSP fix for Windows section now describes the automatic patching, the manual patching instructions are gone, and a note documents the idempotent behavior.

## [5.3.1] - 2026-01-23

`git-update-repos.ps1` fixed a scope shadowing bug in its `Wc` function, where the parameter `$c` shadowed the script-scoped `$C` hashtable, which now uses `$script:C.N` for explicit script scope access.

## [5.3.0] - 2026-01-23

The Serena MCP server joined the OpenCode configurations on Windows, Linux, and macOS, providing semantic code navigation, symbol-level editing, and LSP-powered code analysis. It runs through `uvx` straight from GitHub (`git+https://github.com/oraios/serena`), the recommended pattern for MCP servers because it eliminates local Python package management complexity, always runs the latest version, and simplifies updates. The `uv` package manager, required for Serena's `uvx` invocation and recommended for modern Python projects, is now installed in Phase 2 (Core SDKs) alongside Python and Node.js by both bootstrap scripts, through `astral.sh/uv/install.ps1` on Windows and `astral.sh/uv/install.sh` on Linux and macOS, and `update-all.ps1` and `update-all.sh` self-update it alongside the other package managers. Phase 5.25 (MCP Servers) carries the serena configuration, `deploy.sh` lists serena among the universal MCPs, and `deploy.ps1` merges the MCP config across all platforms with conflict detection and hardened scalar handling.

`deploy.ps1` also gained type checking that detects and repairs malformed `mcp` sections left as scalars by earlier bad merges, preventing deploy failures caused by previous manual config edits. CLAUDE.md was restructured with XML-style tags for better AI parsing, documents Serena MCP in its tool usage section, and extends the requirements contract with a task planning step.

## [5.2.27] - 2026-01-23

CLAUDE.md cleanup closed all 17 unclosed XML sections and fixed a batch of wording errors: the misspellings "persspective" to "perspective", "offical" to "official", and "oudated" to "outdated", the triple-S typo "ADDRESSS" to "ADDRESS", the grammar fix "implement any thing" to "implementing anything", the word choice fix "bolting" to "bolding", the pluralization fix "documentations" to "documentation", the capitalization fix "pdfs" to "PDFs", and the terminology fix "equivalences" to "equivalents". A standalone period that created awkward formatting was removed and the migration example phrasing was cleaned up.

## [5.2.26] - 2026-01-22

CLAUDE.md converted its markdown headers to XML tag format, so `## Non-Negotiables` became `<non-negotiables>`, and dropped all bold and italic markup, because plain text with XML-style headers parses better as Claude Code system instructions while staying readable for humans. Headers now use descriptive tag names for better AI parsing and the content stays plain unordered and numbered lists. A new `<file-handling>` section after `<tool-usage>` documents how to work with documents, slideshows, spreadsheets, and PDFs, with guidance on transpilation, `pandoc`, `python-docx`, `python-pptx`, and CSV handling.

## [5.2.25] - 2026-01-21

The update-all scripts now show all package manager output by default. Output capture and filtering were removed from `update-all.ps1` and `update-all.sh`, the `Invoke-Update` function gave way to direct command execution, and the bash script's `head -20` output limits are gone, so Scoop bucket and app updates, winget installation and download progress, Chocolatey package upgrade details, npm, pnpm, bun, and yarn package updates, go, gup, cargo, and rustup tool updates, dotnet tool update results, pip package upgrade operations, and poetry self-update output all stream straight to the console.

jdtls lost its Windows support because Eclipse JDT.LS is unusable there, its path handling breaks and Scoop integration is missing, so anyone doing Java development on Windows should use WSL or a full IDE. `bootstrap.ps1` no longer installs it, the Windows platform display name mapping and the `packages.yaml` Windows support entry are gone, and the Neovim config excludes jdtls from its LSP list on Windows, while Linux and macOS keep it through Homebrew. The README example output reflects the exclusion and TOOLS.md documents jdtls as Linux/macOS only with a note on the Windows limitation.

## [5.2.24] - 2026-01-20

`statusline.ps1` gained debug logging for context window troubleshooting, writing raw JSON input, context window data, and calculated values to `%TEMP%\claude-statusline-debug.log`, plus a visible `[r:X% u:Y%]` debug indicator when both context percentages read zero, which helps diagnose the `used_percentage` and `remaining_percentage` issues reported in Claude Code 2.1.12. In `update-all.ps1`, `exit 1` and `exit 0` in the Main function became `return` so a terminal stays open when the script is dot-sourced instead of executed directly, which improves compatibility when it runs from other scripts or interactive sessions.

## [5.2.23] - 2026-01-19

The Scoop Node.js package changed from `nodejs-lts` to `nodejs` across the Windows scripts: `bootstrap/bootstrap.ps1` installs the new package, `bootstrap/lib/common.ps1` handles the `nodejs` directory path, `cleanup-scoop-path.ps1` excludes `nodejs` from its cleanup regex, `cleanup-npm-trash.ps1` and `update-all.sh` follow the new npm module paths, and `bootstrap/config/packages.yaml` lists `nodejs`.

All test infrastructure was removed: the `tests/` directory, `coverage.json` and other test artifacts, the `.Tests.ps1` and `.bats` files, and the test helper scripts with their coverage tools. The tests polluted the User PATH registry with temporary test directories, and environment-specific testing adds minimal value to a personal dotfiles repository.

## [5.2.22] - 2026-01-18

`update-all.ps1` simplified its pip update to a `pip freeze` one-liner, `pip freeze | %{$_.Split('==')[0]} | % { pip install --upgrade $_ }`, so every globally installed Python package gets updated where previously only `--user` packages did. It also gained update sections for the Claude Code and OpenCode AI CLIs that verify the installed version against the npm registry first, checking `@anthropic-ai/claude-code` and `opencode-ai` respectively and running the official installer only when outdated, otherwise skipping with the current version shown, and the OpenCode installer runs through bash. With this the PowerShell script matches the bash script's AI CLI update behavior, and all 3 sections, pip, Claude Code, and OpenCode, increment their counters correctly.

## [5.2.21] - 2026-01-17

Bootstrap phases now print "Checking..." messages for real-time visibility and show "(up to date)" for tools already installed, replacing hidden verbose output with visible status messages. Phase 2 (Core SDKs) covers Go, Rust, dotnet, Bun, and OpenJDK, Phase 3 (Language Servers) covers all 16 language servers, Phase 4 (Linters & Formatters) covers all 26 linters and formatters, Phase 5 (CLI Tools) covers all 11 CLI tools, Phase 5.25 (MCP Servers) covers `tree-sitter-cli`, `context7-mcp`, `playwright-mcp`, and `repomix`, and Phase 5.5 (Development Tools) covers VS Code, Visual Studio, LLVM, and LaTeX. `Install-Bun` prints "Checking Bun..." instead of "Upgrading Bun...", the README SDKs table lists Bun alongside Node.js, Python, Go, Rust, dotnet, and OpenJDK, and the README idempotency example output shows the new "Checking..." pattern. A typo in `Install-Rustup` was fixed, `GetPackageDescription` to `Get-PackageDescription`.

## [5.2.20] - 2026-01-17

A `statusline.ps1` script for PowerShell 7+ with Windows-compatible stdin reading now tracks the context window and displays real-time token usage, git status indicators for staged (S#), modified (M#), and untracked (U#) file counts, and automatic statusline registration in `settings.json` during deployment. It supports the `context_window` percentage fields of Claude Code 2.1.6+ with a fallback to `current_usage` calculation, and displays the directory, git branch, git status, model name, tokens over max with the percentage remaining, and session cost, with color-coded context warnings in green above 50%, yellow from 20% to 50%, and red below 20% remaining. The bash statusline script used on Linux and macOS received the same git status and context window calculation, `deploy.ps1` registers the statusline in Claude Code `settings.json` automatically, and the README deployment documentation reflects the registration.

## [5.2.19] - 2026-01-17

The Context7 MCP moved from a local npx command to the remote HTTP endpoint `https://mcp.context7.com/mcp` in the Linux, macOS, and Windows OpenCode configs, which requires the `CONTEXT7_API_KEY` environment variable and enables remote execution without a local Node.js dependency. `deploy.ps1` switched its OpenCode config deployment from overwrite to merge, preserving existing user settings while adding or updating MCP servers from the dotfiles, with a deep comparison that detects actual changes before updating and the new output messages `(created)`, `(merged N server(s))`, and `(up to date)`. Claude config deployment changed from selective file copy to full directory recursion, so the entire `.claude/` directory including hooks, tdd-guard, and all scripts deploys and new files are included automatically, which simplifies maintenance. The README deployment example output now shows "Claude configs" and "OpenCode config" lines, and a Deploy Script Behavior section documents the merge and overwrite behavior and the OpenCode merge output messages.

## [5.2.18] - 2026-01-17

`wezterm.lua` gained platform detection that sets `pwsh.exe` as the default shell on Windows, so WezTerm launches PowerShell 7 instead of cmd.exe, while Linux keeps auto-detecting zsh. `deploy.ps1` now deploys the assets directory for WezTerm background images, copying `assets/*` to `$HOME/assets/` on Windows so the tokyo-sunset.jpeg background image loads correctly, which brings Windows in line with the Linux and macOS deployment.

## [5.2.17] - 2026-01-17

Windows bootstrap installs the WezTerm terminal emulator in Phase 1 (Foundation) through winget with the `wez.wezterm` package ID, respecting `-DryRun` and skipping when already installed, which brings Windows in line with Linux and macOS where bootstrap already installed it. The README had documented the winget installation and bootstrap now implements it. CLAUDE.md documented the PowerShell 7+ requirement for Windows (`pwsh.exe`) and the advice to avoid the outdated `powershell.exe` (Windows PowerShell 5.1).

## [5.2.16] - 2026-01-17

`deploy.ps1` fixed the missing Neovim config deployment on Windows, which previously ran only on Linux and macOS: the config now copies to `%LOCALAPPDATA%\nvim\`, the Windows `stdpath('config')` location, with the `lua/` directory copied recursively for modular Neovim configs. `deploy.ps1` also corrected the WezTerm config path from the incorrect `%LOCALAPPDATA%\wezterm` to `$HOME/.config/wezterm/wezterm.lua`, and both configs are now properly deployed and verified in bootstrap output.

`update-all.sh` stopped reporting false positive updates for the Claude Code and OpenCode AI CLIs. An `install_and_verify_version` helper function compares versions before and after install against the npm registry as an external reference, warns when the installed version differs from the npm version, which points to a possible silent failure, and no longer prints misleading "updated" messages when the installer reinstalls the same version.

## [5.2.15] - 2026-01-17

`update-all.ps1` became a native PowerShell 7 implementation with no bash dependency, a pure PowerShell script that directly updates the Windows package managers Scoop, winget, Chocolatey, npm, pnpm, yarn, gup, go, cargo, rustup, dotnet, pip, and poetry, and the separate `update-all-windows.ps1` was consolidated into it. The `up` alias in `.bash_aliases` now calls `pwsh.exe` instead of `powershell.exe` on Windows Git Bash, with platform detection for MINGW and MSYS environments picking the correct update script, so Git Bash invokes `update-all.ps1` through PowerShell 7.

Package manager detection fixes: winget is detected through the full path to its WindowsApps wrapper executable, `$PSNativeCommandUseErrorActionPreference = $false` stops native command stderr from raising false failures from `$ErrorActionPreference` while exit codes still work, and the Scoop update filters git lock errors out of bucket warnings. `update-all-windows.Tests.ps1` was renamed to `update-all.Tests.ps1` and the coverage report scripts reference the consolidated `update-all.ps1`.

## [5.2.14] - 2026-01-17

`sync-system-instructions.ps1`, `git-update-repos.ps1`, and `deploy.ps1` were converted from bash wrappers to pure PowerShell 7 scripts using `param()`, hashtables, and proper error handling, `deploy.sh` became Linux and macOS only and directs Windows users to `deploy.ps1`, and the Windows-specific code paths left the bash scripts for a cleaner separation. Both platform twins of `git-update-repos` now detect "already up to date" before pulling, the bash version comparing local and remote HEAD and printing "Skipped (already up to date)" instead of "Updated", so runs over current repos no longer produce misleading "mass updated" output, and the PowerShell version has the equivalent detection. Both `sync-system-instructions` twins show "already up to date (no changes to commit)" in the commit phase and "already up to date (nothing to push)" in the push phase, and an arithmetic expansion bug for Git Bash compatibility was fixed with `|| true`.

The README quick start and updating sections now use `.\bootstrap.ps1` on Windows instead of `.\deploy.ps1`, with platform-specific parameter comparison tables and an entry point scripts table carrying a platform column: Windows runs the pure PowerShell 7 `.ps1` scripts, Linux and macOS run the bash `.sh` scripts.

## [5.2.13] - 2026-01-17

Already-installed tools now get their PATH configured. `bootstrap.ps1` calls `Add-ToPath` and `bootstrap.sh` calls `ensure_path` for the Claude Code and OpenCode CLIs when skipping the install, putting `~/.local/bin` and `~/.opencode/bin` on the User PATH. Previously a tool already installed at the correct version never had its PATH configured, which left the tools unfound in new terminal sessions even though the binary existed.

## [5.2.12] - 2026-01-17

The OpenCode AI CLI switched from npm to the official installer `curl -fsSL https://opencode.ai/install | bash`, which installs to `~/.opencode/bin` on all platforms, automatically uninstalls the old npm version during migration, and pairs with version-aware checking that prevents unnecessary reinstalls. Both AI CLIs now check versions against the npm registry before installing and show the version when skipping, "already at latest version (2.1.9)" for Claude Code and "already at latest version (1.1.23)" for OpenCode.

npm package version checking stopped producing false positives. `npm outdated -g` reported transitive dependency versions, so `Test-NpmPackageNeedsUpdate` in PowerShell and `npm_package_needs_update` in bash switched to `npm list -g --json --depth=0` for accurate top-level version detection, Prettier and other npm packages no longer show as outdated from dependency mismatches, and old npm shims are removed before version checks to prevent PATH shadowing. Two cleanup scripts arrived: `cleanup-npm-trash.ps1` removes invalid npm packages whose names start with a dot, such as `.intelephense-*`, which npm cannot uninstall itself, and `cleanup-scoop-path.ps1` removes individual scoop app paths from the User PATH. `cleanup-npm-trash.ps1` also checks the scoop-persisted `nodejs-lts` location and `update-all.sh` checks multiple npm locations on Windows. The README idempotency section shows the full Windows bootstrap output with the version-aware detection for both AI CLIs.

## [5.2.11] - 2026-01-13

`sync-system-instructions.sh` hardcodes `DOTFILES_DIR` to `~/dev/github/dotfiles` as the README quick start specifies, dropping the complex symlink resolution logic for an explicit path, so it now works correctly whether run from the dotfiles directory or from `~/`. The README quick start carries a prominent notice that the repo must be cloned to `~/dev/github/dotfiles`, the Git repository management section notes the path requirement of `sync-system-instructions`, and both clarify that several scripts depend on this exact location to function correctly.

## [5.2.10] - 2026-01-13

RULES.md now redirects to CLAUDE.md for unified development guidelines, centralizing the AI assistant instructions across AGENTS.md, GEMINI.md, and RULES.md. `deploy.sh` gained a `merge_gitconfig()` function that merges instead of overwrites when deploying `~/.gitconfig`, keeping `user.name` and `user.email` from the existing config while updating the dotfiles settings. In `sync-system-instructions.sh`, `commit_changes()` now uses the config override from the dotfiles repo as a fallback, shows a helpful message with setup instructions when the git identity is missing, and gives better error visibility for commit and push failures.

## [5.2.9] - 2026-01-13

A documentation sweep touched `README.md`, `TOOLS.md`, `TESTING.md`, `QUICKREF.md`, `BRIDGE.md`, `tests/README.md`, `AGENTS.md`, and `GEMINI.md`. The LSP server count was corrected from 23/25 to 19 after verification against `bootstrap/bootstrap.sh`, the tool counts moved to 20+ linters, 17+ formatters, 9+ testers, and 15+ CLI tools (from 16+, 13+, 5+, and 13+), and the automated test count moved from 150+ to 2,200+ after verification against the test files.

The clone directory path was standardized to `~/dev/github/dotfiles` across all documentation, the config setting name inconsistency (`auto_commit_changes`/`auto_update_repos`) was fixed to `auto_commit_repos`, and rust-analyzer naming was made consistent between hyphen and underscore. Bootstrap script structure documentation (wrapper versus implementation) was added, `HOOKS.md` joined the Additional Documentation table, the broken `CONTRIBUTING.md` link left `tests/README.md`, and `AGENTS.md` and `GEMINI.md` gained explanatory comments.

## [5.2.8] - 2026-01-13

`sync-system-instructions.sh` stopped misreporting pushes. `commit_changes()` now prints whether each repository was already up to date or committed, `push_changes()` checks the ahead count before pushing and prints its status, and `|| true` guards the commit and push loop so `set -e` cannot abort it mid-run. The false pushed messages are gone because a push that did nothing no longer reports success.

## [5.2.7] - 2026-01-13

A `set -e` arithmetic bug made `sync-system-instructions.sh` exit after the first repository because counter increments returned nonzero on zero values. The increments now carry `|| true` and the script processes every repository in the base directory. The Claude CLI dependency for commit and push operations was dropped together with the `commit_with_claude()` function, replaced by pure git commands that are deterministic and need no AI agent.

## [5.2.6] - 2026-01-12

Bootstrap gained an auto-correction system for packages, built on a distro-agnostic `remove_system_package()` helper that drives apt, dnf, pacman, and zypper. It removes and reinstalls the CLI tools `fzf`, `zoxide`, `bat`, `eza`, `lazygit`, `gh`, `tokei`, `ripgrep`, `fd`, and `bats`, the SDKs `nodejs` (including snap installs), `golang`, `php`, and `dotnet`, the language servers `clangd`, `lua-language-server`, `jdtls`, and `rust-analyzer`, the linters and formatters `prettier`, `eslint`, `ruff`, `black`, `mypy`, `yamllint`, `shellcheck`, `shfmt`, `stylua`, `selene`, and `golangci-lint`, and the cargo package `difftastic`. Package name variations such as `fd`/`fd-find`, `gh`/`github-cli`, and `eza`/`exa` are handled, and a catch-all handler covers unknown sources like snap, flatpak, AppImage, and manual installs.

The system spans 30+ packages across sources. Python stays as the system fallback and is never removed, so the host distribution stays safe, and unknown package sources are logged for manual cleanup instead of failing the run.

## [5.2.5] - 2026-01-12

PHP now installs with the curl extension Composer requires. Linux `install_php()` prefers brew PHP, which includes curl, and falls back to apt, dnf, pacman, or zypper, macOS `install_php()` uses brew (curl included by default), and Windows `Install-PHP()` uses scoop or winget. The apt-installed PHP is auto-removed before the brew version goes in, and `php` joined the brew package mapping and the auto-correction section. Composer now runs at full speed because the slow fallback HTTP handler is gone.

## [5.2.4] - 2026-01-12

Build dependencies now install even when rustup is already present, because the `install_build_dependencies()` call moved ahead of the early-return check inside `install_rustup()`. This keeps pkg-config and the OpenSSL headers available for future cargo package compilation.

## [5.2.3] - 2026-01-12

Bootstrap now installs pkg-config and the OpenSSL development headers automatically, which Rust packages with native dependencies such as `cargo-update` need for compilation. Linux installs the distro-specific package (`libssl-dev`, `openssl-devel`, `openssl`, or `libopenssl-devel`) and macOS installs `openssl` and `pkg-config` through Homebrew. Both platforms call the new `install_build_dependencies()` before Rust installation so the build dependencies are present before `cargo-update` installs.

## [5.2.2] - 2026-01-12

The update script's RUSTUP section moved ahead of CARGO because cargo comes from rustup, and a CARGO-UPDATE section now auto-installs `cargo-update` when it is missing, so `cargo-install-update` is available before the cargo package updates run.

## [5.2.1] - 2026-01-12

Bootstrap installs `cargo-update` on Linux, macOS, and Windows through `install_cargo_update()` and `Install-CargoUpdate()`, with `cargo_update` added to the `linters_formatters` category in `packages.yaml`. The package supplies the `cargo-install-update` command that manages all cargo-installed packages. `update-all.sh` gained a Claude Code CLI section that updates Claude through the official install script.

`CLAUDE.md` gained a Research Before Implementation section covering Context7, Web Search, Web Reader, ZRead, and the GitHub CLI, plus a Testing Strategy section comparing property-based testing with unit tests.

## [5.2] - 2026-01-10

`tree-sitter-cli` joined the bootstrap scripts on Linux, macOS, and Windows, and Neovim now auto-installs 32 Treesitter parsers on startup: `lua`, `vim`, `vimdoc`, `query`, `c`, `cpp`, `rust`, `go`, `python`, `java`, `c_sharp`, `php`, `scala`, `javascript`, `typescript`, `tsx`, `jsx`, `html`, `css`, `scss`, `svelte`, `yaml`, `json`, `toml`, `markdown`, `markdown_inline`, `bash`, `powershell`, `dockerfile`, and `typst`. Parser installation is cross-platform with automatic dependency checking.

The nvim-treesitter configuration was rewritten for the v2.0 API: the deprecated `nvim-treesitter.configs` module gave way to `nvim-treesitter.config`, the unsupported `ensure_installed`, `auto_install`, and `sync_install` options were removed, parsers install manually through the Lua API with startup auto-install, and language loading is conditional on the installed parsers. This fixed parsers failing to auto-install under v2.0. On Linux the `powershell_es` LSP left the Neovim configuration because it requires `pwsh`, which fixed the LSP error when opening PowerShell files, while the Treesitter PowerShell parser stays available for syntax highlighting.

## [5.1] - 2026-01-10

The default theme switched from gruvbox to rose-pine across all configs: Neovim uses the rose-pine colorscheme with a dark background, WezTerm uses the rose-pine color scheme, and the `bat` previewer theme follows. `deploy.sh` and `update-all.sh` moved their theme defaults from `gruvbox-light` to `rose-pine`, the example config `.dotfiles.config.yaml.example` was updated, and `README.md`, `QUICKREF.md`, and `BRIDGE.md` reflect the new values. The test fixtures in `config_test.bats`, `config_e2e_test.bats`, and `config.Tests.ps1` use rose-pine.

Neovim treesitter highlighting was fixed by replacing the `nvim-treesitter.configs.setup()` call with a manual FileType autocmd and a direct `vim.treesitter.start()` call, with `foldexpr`, `foldmethod`, and `indentexpr` configured for treesitter and the deprecated config pattern removed for Neovim 0.11+ compatibility. The quote style standardized from double to single and indentation settled at 4 spaces.

`deploy.sh` now deploys WezTerm background assets to `~/assets/` by copying all files from `assets/`, so terminal backgrounds are available after a deploy, which fixes the missing background images.

## [5.0] - 2026-01-10

The Linux platform install in `bootstrap/platforms/linux.sh` was rewritten (677 lines of changes) for Ubuntu 26.04 LTS with Homebrew-first package priority, so brew is used before apt when available and Homebrew installs itself on Linux without prompts. Git is reinstalled through brew after the apt version is uninstalled, VSCode comes from the official Microsoft apt repository instead of a manual .deb, `dotnet-sdk` 10.0 comes from the Microsoft apt repository, and WezTerm comes from the official `apt.fury.io` wez repository. Package detection gained `command -v` fallbacks, the gpt-researcher integration and references were removed together with `.env.gpt-researcher`, and the package priority became brew over official repos over apt. Bootstrap overall gained PATH fix functions (`fix_path_issues` and `fix_package_states` in `bootstrap/lib/common.sh`), better error handling and recovery, improved platform-specific installation ordering, and WezTerm in the bootstrap phases. `bootstrap/bootstrap.sh` took the new platform detection and package priority, `bootstrap/platforms/macos.sh` took 99 lines of additions, `deploy.sh` took 239 lines of deployment handling plus XDG_CONFIG_HOME support across configs, `git-update-repos.sh` took 111 lines of error handling and progress reporting, and `update-all.sh` took better package manager detection and updates.

New files arrived: the platform-specific OpenCode settings `opencode.linux.json`, `opencode.macos.json`, and `opencode.windows.json` (split from the old `opencode.json`), `.config/nvim/init.lua` in its proper XDG location, `wezterm.lua` moved to `.config/wezterm/wezterm.lua`, git hooks separated from `hooks/` into `.config/git/hooks/` (`pre-commit` and `commit-msg`), the documentation files `ARCHITECTURE.md`, `TOOLS.md`, `TESTING.md`, `HISTORY.md` with the legacy museum of 3 years of project history, and `HOOKS.md` moved from `hooks/README.md`, the tests `git-hooks_test.bats`, `bootstrap_new_tools_test.bats`, `bootstrap_new_tools.Tests.ps1`, and `windows-platform.Tests.ps1`, and the Claude tooling `.claude/hooks/`, `quality-check.sh`, `quality-check.ps1`, `statusline.sh`, and the project `CLAUDE.md`. The rewritten pre-commit hooks support more languages, validate conventional commits by type, scope, and format, auto-format with `prettier`, `shfmt`, `gofmt`, `rustfmt`, and `dotnet format`, and lint with `eslint`, `golangci-lint`, `clippy`, `shellcheck`, and `mypy`. `hooks/claude/quality-check.ps1` gained the expanded quality checks.

Coverage returned to bashcov because it tracks sourced files where kcov does not, making it primary with kcov as fallback, and the coverage badge now reflects the real numbers. The README shrank from 1925 to about 800 lines (roughly 60%) by removing duplicated content, consolidating sections, cutting the mermaid diagrams from 6 to 1, and linking to the new documentation files. Everything was tested on Ubuntu 26.04 LTS across all bootstrap phases, package installations, and git hooks, and on Windows 11 for PowerShell wrapper execution, Git Bash integration, and the platform-specific tools. Coverage landed at 47.51% bash (1529 of 3218 lines) via bashcov 3.2.0, 10.02% PowerShell (228 of 2276 commands) via Pester 5.7.1, and 25.0% combined weighted 60% PowerShell and 40% bash.

## [4.4] - 2026-01-07

`git-update-repos` migrated from the public GitHub API to the authenticated `gh repo list` command, so it now fetches and updates all repositories of the authenticated user, private ones included, fixing the old behavior where only public repositories were cloned or updated. The curl and wget based fetching with its pagination logic is gone, JSON parsing uses `jq` when available and falls back to grep and sed, and a requirement check fails with a helpful error message when `gh` is missing. README section 11 documents the command, the Bash and PowerShell parameter equivalents, the `gh` requirement and its authentication flow, and the private repo support now named in the entry point description.

## [4.3] - 2026-01-07

`goimports` stopped reinstalling on every run because GOPATH paths are normalized before comparison, the registry PATH checks moved from wildcard pattern matching to exact array matching, and `$GOPATH/bin` is now added to the current session PATH unconditionally for immediate tool availability. Ruby left the bootstrap entirely, taking the bashcov gem, the ruby entries in the PowerShell and Bash version checks, and the `ruby` entry in `packages.yaml`, because coverage moved to kcov exclusively: native kcov on Linux and macOS, kcov through Docker on Windows. The README reflects the kcov-only strategy, drops `gem` from the supported language package managers, and shows kcov through Docker for Windows in the coverage tools table.

## [4.2] - 2026-01-03

PATH detection for npm, Python, and winget-installed packages was fixed. `Initialize-UserPath` now adds all current directories of every Scoop app instead of only current/bin, `Add-ToPath` matches exactly instead of by substring, the WinGet Links directory joined the `Refresh-Path` preservation list, and PATH initialization moved to the beginning of `Main` so tools are detectable early.

Test infrastructure stopped wiping User PATH registry entries: the dangerous registry PATH cleanup left the AfterEach blocks and safety checks now prevent empty PATH conditions. Test counts rose from 2221 to 3221 (2181 PowerShell and 1040 bash), the idempotence documentation shows the latest bootstrap output with 57 skipped items, and combined coverage reached 31.4% (42.1% PowerShell and 31.2% bash).

## [4.1] - 2026-01-02

The script entry point mermaid diagram was aligned, and the documentation took real coverage measurements (43.9% combined, 41.9% PowerShell and 46.9% bash), gained a sequence diagram in the Architecture section, dropped the inline navigation links in favor of the footer Back to Top link, and lost the separators inside subsections.

## [4.0] - 2026-01-02

v4.0 converted the `.ps1` scripts into thin compatibility wrappers that call the `.sh` scripts through Git Bash, with all core logic in bash and a Windows-native `bootstrap.ps1` for tighter platform integration that falls back to bash, which buys one implementation to maintain, cross-platform parity, and automatic Windows support. Git now installs on Windows via winget during bootstrap, the wrappers convert Windows paths to Git Bash format with lowercase drive letters, `.gitattributes` keeps LF for `.sh` and CRLF for `.ps1`, and bashcov became the universal bash coverage tool across platforms. New paired entry points arrived: `uninstall.sh`/`uninstall.ps1`, `healthcheck.sh`/`healthcheck.ps1`, `backup.sh`/`backup.ps1`, `restore.sh`/`restore.ps1`, and `sync-system-instructions.sh`/`sync-system-instructions.ps1`.

The config system gained optional `.dotfiles.config.yaml` on a bridge library (`lib/config.sh` and `lib/config.ps1`) covering editor preference, theme, installation categories, and auto-update options, with graceful fallback to defaults when the config is absent. Bootstrap became phase-based (Foundation, SDKs, LSPs, Linters, CLI Tools, MCP Servers, Deploy, Update) with the minimal, sdk, and full categories (full is the default), idempotent operations with detailed skip tracking, tool descriptions in the summary output, git installation on Windows, and bashcov installation. Deployment cleans `.gitconfig` per platform by removing Linuxbrew gh paths on Windows, absolute Windows `gh.exe` paths on Linux and macOS, and empty helper lines, and it supports XDG_CONFIG_HOME across configs with OneDrive-aware PowerShell profile deployment on Windows. Linux gained the improved package detection and installation, and macOS supports both Apple Silicon and Intel. The GLM MCP servers (`web-search-mcp`, `web-reader-mcp`, `zread-mcp`) left the bootstrap and the duplicate PowerShell implementations died in the wrapper conversion.

Testing grew to 11 BATS files covering all `.sh` scripts and 5 PowerShell files validating the wrappers, spanning unit, integration, and E2E categories, at 46.2% bash, 15% PowerShell, and 27.5% combined coverage with automated reporting and badges. The README reorganized into numbered sections with security documentation and an entry points table, gained a Legacy Museum documenting historical files with commit hashes (`git-clone-all.sh` at 2.5 years old from June 2023, `assets/` at 1.5 years old spanning June 2023 to July 2024, and the 2025-era `typos.toml`, `update.sh`, and `.aider` files), and `CHANGELOG.md` was written covering v1.0 through v4.0. Neovim dropped null-ls and moved to built-in formatting, WezTerm took the rose-pine theme and window mode support, `update-all` modularized into platform-specific functions, and the git hooks gained PowerShell versions for Windows. Fixes covered PowerShell alias syntax errors, the broken WSL gh credential helper paths on Windows, path conversion between Windows and Git Bash formats, duplicate PowerShell test code removed through the wrapper pattern, and `.gitconfig` credential helper cross-platform compatibility. A security review completed in January 2026 found 0 high or medium vulnerabilities, documented the threat model and security design principles, and recorded that the wrapper script string interpolation is not exploitable for personal dotfiles.

## [3.3.3] - 2026-01-01

Fixed the PowerShell syntax errors in the bootstrap scripts and the PowerShell alias conflicts, and clarified the README documentation.

## [3.3] - 2026-01-01

Fixed the PowerShell syntax errors throughout the codebase and updated the README for clarity.

## [3.2] - 2026-01-01

The README sections were reorganized with numbering and gained section navigation.

## [3.1] - 2026-01-01

The Neovim keybindings documentation was fixed, a Claude Code integration section was added, the hidden hotkeys and Wezterm hotkeys joined the README, and the key notation in the documentation was corrected.

## [3.0] - 2026-01-01

Version 3.0 brought the bridge approach config system (optional YAML configuration with graceful fallbacks), a testing framework built on BATS for bash and Pester for PowerShell with bashcov and Pester coverage, git hooks enforcing Conventional Commits, Claude Code hooks running quality checks and a TDD guard for AI-assisted development, and system instructions sync that auto-distributes `CLAUDE.md`, `AGENTS.md`, and `GEMINI.md` to all repositories. `update-all` was modularized for maintainability, `CLAUDE.md` gained the AI coding practices, and bootstrap learned the minimal, sdk, and full installation categories.

## [2.2] - 2025-12-31

Improved the README documentation and the verbose output of the scripts.

## [2.1] - 2025-12-31

`update-all` was refactored for modularity and maintainability, with better package manager detection and handling.

## [2.0] - 2025-12-31

System prompts now auto-distribute across all repositories, with `CLAUDE.md`, `AGENTS.md`, and `GEMINI.md` support for multiple AI assistants. The git hooks gained better commit message validation and the bootstrap process improved.

## [1.0] - 2025-12-30

This is the initial release. It supports Windows 11, Linux (Ubuntu, Fedora, Arch), and macOS, built around a universal deployment script for the Neovim, git, and shell profile configs and a bootstrap script that sets up a development environment automatically. Bootstrap installs the package managers `scoop`, `winget`, `brew`, `apt`, `dnf`, and `pacman`, the SDKs Node.js, Python, Go, Rust, dotnet, and OpenJDK, 15+ LSP servers, 10+ linters and formatters, and the CLI tools `fzf`, `zoxide`, `bat`, `eza`, `lazygit`, `gh`, `ripgrep`, and `fd`.

The git hooks arrived from the start: a pre-commit hook that auto-formats and lints with support for 15+ languages, and a commit-msg hook that enforces conventional commits. The Neovim configuration runs on the lazy.nvim plugin manager with 15+ LSP servers configured, Treesitter for syntax highlighting, custom keybindings and themes, and linting and formatting on save. The shell profiles cover bash aliases and functions, zsh support on macOS and Linux, the PowerShell 7 profile on Windows, and zoxide integration for smart navigation.

The utility scripts cover every package manager through `update-all.sh`, the git repositories in the configured directory through `git-update-repos.sh`, system health and configuration checks through `healthcheck.sh`, timestamped backups through `backup.sh`, and restores from those backups through `restore.sh`. Windows is OneDrive-aware with PowerShell 7 support and Git Bash integration, Linux supports multiple distributions with systemd services, and macOS integrates Homebrew with Apple Silicon support.
