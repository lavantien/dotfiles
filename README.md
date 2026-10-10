# dotfiles

[![Linux](https://img.shields.io/badge/Linux-FCC624?logo=linux&logoColor=black)](https://github.com/lavantien/dotfiles) [![Windows](https://img.shields.io/badge/Windows-0078D6?logo=windows&logoColor=white)](https://github.com/lavantien/dotfiles) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

The repo deploys an engineering environment for Linux and Windows: Neovim, WezTerm, zsh, and PowerShell configs, git hooks, Claude Code and OpenCode settings, the maintenance scripts, and a typst books corpus used for offline grounding. The supported platforms are Ubuntu 26.04 and newer plus Windows 11 with PowerShell 7. Bootstrap and deploy are idempotent, rerunning them converges the machine.

> what's the progress? what's in flight? what's remaining?
>
> the opening books corpus contain chapters that might be useful to our endeavor. now let fan out subagents and start the development loop according to the prime directives and principles

## Contents

- [Core features](#core-features)
- [Quick start](#quick-start)
- [Repo layout](#repo-layout)
- [Available commands](#available-commands)
- [Books corpus](#books-corpus)
- [Tools matrix](#tools-matrix)
- [Hooks and config merging](#hooks-and-config-merging)
- [Neovim](#neovim)
- [Release process](#release-process)
- [Changelog](#changelog)
- [License](#license)

## Core features

The editor stack pairs Neovim 0.13+ with WezTerm. Neovim uses the builtin vim.pack manager with a committed lockfile, LSP and Treesitter setup, native completion, and the builtin directory browser. Bootstrap installs Neovim through the snap edge channel, which delivers the 0.13 nightlies, with a brew or apt fallback on hosts without snap. WezTerm runs the IosevkaTerm Nerd Font, which bootstrap installs on both platforms. The Rose Pine theme colors nvim, WezTerm, and the bat previews inside nvim.

Language tooling covers the servers and parsers enabled in `.config/nvim/init.lua` plus a CLI toolset installed by the bootstrap scripts: fzf, yazi, zoxide, bat, eza, lazygit, gh, ripgrep, fd, sqlite, tokei, btop, repomix, docker-compose, helm, and kubectl.

AI-native development covers Claude Code and OpenCode. The MCP servers are context7, playwright, and repomix. One git pre-commit and commit-msg hook set serves both platforms and is described under hooks below. A statusline hook runs from one bash script on both platforms and is registered by the settings injection. Sessions ground offline on the books corpus described below.

Automation keeps safety: bootstrap and update-all are idempotent and safe to run multiple times, they auto-detect the environment and skip cleanly when a tool is unavailable, and timestamped backup and restore wrap major changes.

## Quick start

> Required clone location: this repository must be cloned to `~/dev/github/dotfiles`.
>
> For Docker/Kubernetes setup, see [DOCKER_K8S.md](DOCKER_K8S.md).

### Linux

```bash
git clone https://github.com/lavantien/dotfiles.git ~/dev/github/dotfiles
cd ~/dev/github/dotfiles
chmod +x scripts/allow.sh && ./scripts/allow.sh
./bootstrap/bootstrap.sh
chsh -s $(which zsh)
exec zsh
```

### macOS

```bash
git clone https://github.com/lavantien/dotfiles.git ~/dev/github/dotfiles
cd ~/dev/github/dotfiles
chmod +x scripts/allow.sh && ./scripts/allow.sh
./bootstrap/bootstrap.sh
exec zsh
```

### Windows (PowerShell 7+)

```powershell
git clone https://github.com/lavantien/dotfiles.git $HOME/dev/github/dotfiles
cd $HOME/dev/github/dotfiles
.\bootstrap\bootstrap.ps1
. $PROFILE
```

### Verify installation

```bash
which n  # Should point to nvim
which lg  # Should point to lazygit
up  # Runs update-all
```

## Repo layout

| Entry | Holds |
|-------|-------|
| `.claude/` | Claude Code config: CLAUDE.md, BOOKS.md, settings templates, statusline.sh, quality-check twins, tdd-guard, and books/ holding the typst corpus |
| `.config/` | Tool configs deployed to the XDG config dir: nvim (init.lua plus lockfile), wezterm, git hooks, opencode platform templates |
| `.vscode/` | VS Code settings |
| `assets/` | WezTerm background wallpapers, deployed to ~/assets |
| `bootstrap/` | bootstrap.sh and bootstrap.ps1, per-platform install scripts, and lib/ helpers |
| `books/` | The published corpus volumes as PDFs, numbered 01 through 14 plus 16 |
| `home/` | Home-level configs: .bash_aliases, .zshrc, .gitconfig, Microsoft.PowerShell_profile.ps1, .dotfiles.config.yaml.example |
| `lib/` | Shared script libraries: config parsing and JSON merge |
| `playground/` | Scratch space for one-off programs, committed with the work unless it holds secrets |
| `scripts/` | Every maintenance script: allow, deploy, update, update-all, git-update-repos, sync-book, books-index, healthcheck, backup, restore, uninstall, cleanup one-offs |

The root also carries README.md, CHANGELOG.md, DOCKER_K8S.md, LICENSE, the Makefile, the lint configs selene.toml, typos.toml, and vim.yml, and git-clone-all.sh, a vendored gh utility kept at the root.

## Available commands

`scripts/allow.sh` runs once after cloning and makes every tracked shell script executable. `bootstrap/bootstrap.sh` and `bootstrap/bootstrap.ps1` are the entry point for initial setup: they install package managers, SDKs, LSPs, and tools, then deploy configs. `scripts/deploy.sh` and `scripts/deploy.ps1` handle config and script deployment (Neovim, git hooks, gitconfig, shell, Claude Code settings, OpenCode MCPs, ~/dev scripts, books grounding), with their options listed under deploy options below. Deploy also migrates a legacy `~/.wezterm.lua` into `~/.config/wezterm/`.

Maintenance goes through `scripts/update-all.sh` and `scripts/update-all.ps1`, aliased `up`. They update the system package managers (apt, dnf, pacman, zypper, brew, snap, flatpak), the language managers (npm, yarn, pnpm, bun, gup, rustup, cargo, dotnet tools, pip, poetry, uv, composer, spin), and the AI CLIs (Neovim plugins and parsers, Claude Code, OpenCode). On Unix the npm step also removes invalid dot-prefixed global packages that npm cannot uninstall itself. `scripts/update.sh` pulls the live configs (bash aliases, zshrc, gitconfig, wezterm config) back into the repo. `scripts/git-update-repos.sh` and `scripts/git-update-repos.ps1` clone or update every GitHub repo through the gh CLI, with `-u` for the username, `-d` for the base dir, and `-s` for SSH. `git-clone-all.sh` clones every repo of a GitHub user or org and is re-runnable to collect new repos and pull updates. `scripts/healthcheck.sh` and `scripts/healthcheck.ps1` verify tools, configs, and git hooks, with `--format json` emitting machine-readable results on stdout. `scripts/backup.sh` and `scripts/backup.ps1` create a timestamped backup before major changes and `scripts/restore.sh` and `scripts/restore.ps1` roll one back. `scripts/uninstall.sh` and `scripts/uninstall.ps1` remove deployed configs and keep installed packages.

Two Windows one-offs clean up package manager damage: `scripts/cleanup-npm-trash.ps1` removes invalid dot-prefixed npm global packages that npm cannot uninstall itself, and `scripts/cleanup-scoop-path.ps1` strips redundant scoop app paths from the user PATH while keeping the shims and nodejs.

Windows uses `.ps1` scripts. Linux/macOS uses `.sh` scripts.

Development gates run through make: `make check` runs the lint gate plus the bats suite, `make e2e-linux` runs the docker lifecycle harness and skips with a message when the docker daemon is down, and `make e2e-windows` runs the bootstrap dry run, a deploy against an isolated HOME, and the PSScriptAnalyzer pass. `make deploy-windows` runs `scripts/deploy.ps1` against the live HOME and `make bootstrap-windows` runs `bootstrap/bootstrap.ps1 -Y` against the live machine, both idempotent. `KNOWN_SHELLCHECK_ERRORS` in the Makefile carves known shellcheck debt out of the lint gate, format `file:SC code`, and each entry must be deleted when its owning fix lands so the gate never hides new errors.

### Bootstrap options

| Option | Bash | PowerShell | Default |
|--------|------|------------|---------|
| Non-interactive | `-y`, `--yes` | `-Y` | Prompt for confirmation |
| Dry-run | `--dry-run` | `-DryRun` | Install everything |
| Categories | `--categories sdk` | `-Categories sdk` | full |
| Verbose | `--verbose` | `-VerboseMode` | Show detailed output |

### Update-all options

`--skip-pip` (bash) or `-SkipPip` (PowerShell) skips pip package updates to speed up the run. Use it through the alias as `up --skip-pip` or `up -SkipPip`.

### Deploy options

| Option | Bash | PowerShell | Purpose |
|--------|------|------------|---------|
| Skip config deployment | `--skip-config` | `-SkipConfig` | Deploy ~/dev scripts only, skip all config deployment |
| Verbose file logging | `--verbose` | (always on) | Log each copied file |
| Pre-deploy backup | `--backup` | `-Backup` | Force backup before deploy (also via `backup_before_deploy` config) |
| Help | `--help` | (Get-Help) | Show usage |

Both deploys write a `~/.dotfiles-installed` marker (timestamp, version, OS) read by uninstall. `-DotfilesDir` is a Windows-only parameter and `POWERSHELL_PROFILE_CONFIG` is a Windows-only environment variable. Bash derives the repo location from the script path and honors `XDG_CONFIG_HOME`.

### Installation categories

The categories are cumulative tiers. minimal covers package managers, git, and CLI tools only. sdk adds programming language SDKs. full adds all LSPs plus linters and formatters, and it is the default.

### Configuration (optional)

All scripts use hardcoded defaults by default (`categories: full`, interactive prompts).

```bash
cp home/.dotfiles.config.yaml.example ~/.dotfiles.config.yaml
vim ~/.dotfiles.config.yaml
./bootstrap/bootstrap.sh  # Auto-detects config
```

Configuration priority: command-line flags override the config file, and the config file overrides the hardcoded defaults.

| Setting | Values | Default |
|---------|--------|---------|
| categories | minimal, sdk, full | full |
| editor | nvim, vim, code, nano | (none) |
| terminal | wezterm, alacritty, kitty | (none) |
| theme | rose-pine, rose-pine-dawn, rose-pine-moon | (none) |
| github_username | your github username | git config user.name, else lavantien |
| base_dir | path to git repos | ~/dev/github |
| auto_commit_changes | true, false | false |
| auto_update_repos | true, false | false |
| backup_before_deploy | true, false | false |
| sign_commits | true, false | false |
| default_branch | branch name for new repos | main |
| skip_packages | comma or space separated package list | (empty) |
| linux.package_manager | auto, apt, dnf, pacman, zypper | auto |
| linux.display_server | x11, wayland | (none) |
| windows.package_manager | scoop, winget, choco | scoop |
| macos.package_manager | brew | brew |

### Health and troubleshooting

```bash
./scripts/healthcheck.sh

# JSON output (for CI/CD)
./scripts/healthcheck.sh --format json
```

If git hooks are not running, set `git config --global core.hooksPath ~/.config/git/hooks`. If the PowerShell execution policy blocks the scripts, run `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`. If Neovim plugins are not installing, run `:lua vim.pack.update()` in Neovim or press `<leader>u`. If zoxide is not jumping, use directories normally for a few days to let it learn.

## Books corpus

The corpus volumes are c-os-cloud, math, go, java, csharp-net, javascript, python, lua, dsa, icpc, patterns-concurrency-distributed, infrastructure, kdd, game-systems, and interview-repertoire. `.claude/books/` carries each volume's typst sources (manifest.typ, book.typ, chapters, coverage), and the typst files are the source of truth. `books/` holds each volume as a published PDF under the authoring repo's NN-name numbering, so the set runs 01 through 14 plus 16, with 15 held by defense-cookbook, an out-of-scope volume. The math volume's proof chapter grounds proofs as machine-checkable data against the lean 4 formalization share of published research results, and the infrastructure testing arc names where every expected value comes from.

`scripts/sync-book.sh` and `scripts/sync-book.ps1` refresh `.claude/books/` from the private authoring repo at `~/dev/github/resume` when it exists and skip otherwise. Deploy follows the same split: with `~/dev/github/resume` present, the deployed CLAUDE.md grounds directly on it, without it, deploy mirrors `.claude/books/` into `~/.claude/books` as is and CLAUDE.md grounds there. Implementation code behind the books (samples, capstones, api projects) falls back to the private repo.

`scripts/books-index.sh` and `scripts/books-index.ps1` regenerate `.claude/BOOKS.md`, the appendix table inside `.claude/CLAUDE.md`, and the reference table below from the corpus manifests plus `scripts/books-index.json`. Run them after corpus or annotation changes, then redeploy.

<!-- BEGIN books readme table -->

| book                                                                                     | scope                                                                            | capstone                                 | walkthroughs                                                                                                                                                                                                                                                  |
| ---------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- | ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| c23: the language, the machine, and the cloud (c-os-cloud)                               | llvm/clang 23, the operating system, terraform, aws, gcp, and a service          | particle kernel and row cruncher (ch 21) | cloud model through multi-cloud practice (ch 22 to 27), one service build: http kernel, auth, store, cache, limits, observability, ship, test suite (ch 28 to 40)                                                                                             |
| mathematics for programmers (math)                                                       | trigonometry to monads in c23, with a physics game capstone                      | the arena game in 3 parts                | sparse matrix systems, iterative solvers and conditioning (ch 23)                                                                                                                                                                                             |
| go 1.27 (go)                                                                             | a complete language manual                                                       | concurrent crawler, indexer, and web ui  | http kernel service build (ch 18 to 29) with its test suite (ch 30), numerical statistics, fitting, and the offline engine with its js twin (ch 31 to 33)                                                                                                     |
| java 27 (java)                                                                           | a complete language manual                                                       | the line clone                           | the version ladder from java 8 to java 27 (ch 2), http service build kernel to suite (ch 19 to 31), the line clone capstone (ch 32)                                                                                                                           |
| c# 15, f# 11, and .net 11 (csharp-net)                                                   | a complete c# manual with an f# tour                                             | a small language interpreter             | f# 11 tour (ch 19 to 21), api service build: kernel through ship it and test suite (ch 22 to 34)                                                                                                                                                              |
| javascript es2026 and typescript 7 (javascript)                                          | a complete manual for two layers                                                 | the query engine, microfrontend          | web service, kernel to test suite (ch 23 to 35), typed service layer and suite (ch 36 to 37)                                                                                                                                                                  |
| python 3.14 (python)                                                                     | a complete language manual                                                       | ingest and analysis pipeline in 2 parts  | data stack (ch 23 to 26), http service kernel to suite (ch 27 to 39)                                                                                                                                                                                          |
| lua 5.5 (lua)                                                                            | a complete language manual                                                       | auto chess, human versus bot             | stdlib tour (ch 11 to 13), c embedding with ffi and allegro (ch 17 to 18), http service kernel to suite (ch 19 to 31)                                                                                                                                         |
| practical data structures and algorithms (dsa)                                           | an engineering handbook in seven languages                                       | storage engine toolkit                   | geometry and lattices (ch 23 to 24), interpreter build (ch 26 to 27), big arithmetic (ch 28 to 29), fine-grained speedups via sparse matrix multiplication (ch 43)                                                                                            |
| the icpc world finals (icpc)                                                             | six finals, seven languages, first principles                                    | none: six world finals walkthroughs      | language toolboxes (ch 2 to 8), six world finals walkthroughs (ch 9 to 14)                                                                                                                                                                                    |
| design patterns, concurrency, and distributed systems (patterns-concurrency-distributed) | an engineering handbook                                                          | raft replicated configuration service    | go pattern catalog (ch 2 to 5), concurrency arc (ch 6 to 9), distributed arc (ch 10 to 15)                                                                                                                                                                    |
| infrastructure: docker, databases, and testing (infrastructure)                          | an engineering handbook                                                          | chat and notifications stack in 2 parts  | docker arc (ch 1 to 5), sqlite arc (ch 6 to 10), duckdb engine pair (ch 11 to 12), messaging arc (ch 14 to 15), testing arc (ch 16 to 18)                                                                                                                     |
| knowledge discovery (kdd)                                                                | from preprocessing to self-organizing maps in c23, with a go and duckdb capstone | go and duckdb kdd pipeline               | preprocessing arc (ch 2 to 10), classifier arc (ch 13 to 24), association rules arc (ch 25 to 30), clustering arc (ch 31 to 36), rough sets (ch 41 to 43), som (ch 44 to 46)                                                                                  |
| game systems and architecture (game-systems)                                             | an engineering handbook                                                          | the battle engine in 4 parts             | campaign content arc (ch 14 to 17), ecs theory into a c# implementation (ch 2 to 3)                                                                                                                                                                           |
| the interview repertoire (interview-repertoire)                                          | working answers for frequent questions                                           | none: worked interview builds            | react arc (ch 11 to 14), go build arc: rest apis, storefront, jetstream pipelines (ch 20 to 22), classics (ch 5 to 6), algorithms (ch 3 to 4 and 23 to 24), 1 billion row handling: the 1brc in 8 stdlib lanes from c to sqlite, 21 measured variants (ch 41) |

<!-- END books readme table -->

## Tools matrix

Cells list what the bootstrap scripts install, what the git hooks invoke, and what ships with the SDKs the bootstrap installs. A dash means nothing installs or invokes it.

| Language | LSP | Tester | Formatter | Linter | Type Check |
|----------|-----|--------|-----------|--------|------------|
| Bash | bashls | bats | shfmt | shellcheck | - |
| PowerShell | - | Pester | Invoke-Formatter | PSScriptAnalyzer | PSScriptAnalyzer |
| Go | gopls | go test | gofmt, goimports | golangci-lint | go vet |
| Rust | rust-analyzer | cargo test | rustfmt | clippy | cargo check |
| Python | pyright | pytest | ruff, black | ruff | mypy |
| JavaScript/TypeScript | ts_ls | - | prettier | eslint | tsc |
| HTML | html | - | prettier | - | - |
| CSS/SCSS/SASS | cssls | - | prettier | stylelint | - |
| Svelte | svelte | - | prettier | - | svelte-check |
| C/C++ | clangd | Catch2 (Linux/macOS) | clang-format | clang-tidy, cppcheck | compiler |
| C# | csharp_ls | dotnet test | dotnet format | Roslyn analyzers | dotnet build |
| Java | jdtls (Linux/macOS only) | - | - | checkstyle (Linux/macOS) | javac |
| PHP | intelephense | php | pint | - | - |
| Scala | metals | - | scalafmt | scalafix | - |
| Lua | lua_ls | busted (Linux/macOS) | stylua | selene | - |
| Typst | tinymist | built-in | tinymist | tinymist | - |
| Dockerfile | docker_language_server | - | - | hadolint | - |
| Docker Compose | docker_language_server | - | prettier | - | - |
| Helm | helm_ls | - | prettier | - | - |
| Kubernetes YAML | yamlls | kubectl | prettier | yamllint | - |
| YAML | yamlls | - | prettier | yamllint | - |
| TOML | tombi | - | - | - | - |

The enabled servers and parsers are listed in `.config/nvim/init.lua`, which is the source of truth for the Neovim side.

### CLI tools

The everyday CLI set is fzf, yazi, zoxide, bat, eza, lazygit, gh, ripgrep, fd, sqlite, tokei, btop, repomix, docker-compose, helm, and kubectl. The install set also covers difftastic, jq, bats, unzip, oh-my-posh, and mermaid-cli, with the per-platform install lists living in `bootstrap/bootstrap.sh`, `bootstrap/platforms/`, and `bootstrap/bootstrap.ps1`. docker-compose on Windows comes with Docker Desktop, see [DOCKER_K8S.md](DOCKER_K8S.md).

### MCP servers (Claude Code and OpenCode)

The MCP servers are context7, playwright, and repomix.

### Diagram generation

mermaid-cli ships the `mmdc` command to generate Mermaid diagrams from the command line.

### AI applications (Windows)

ComfyUI Desktop covers AI image generation and needs `comfy install` after bootstrap.

## Hooks and config merging

### Git hooks

One bash hook set serves both platforms: `.config/git/hooks/pre-commit` and `.config/git/hooks/commit-msg`. Deploy copies them to `~/.config/git/hooks`, sets `core.hooksPath` and `init.templatedir`, and prunes the retired `.ps1` twins from the deployed directory. Git for Windows runs the bash hooks through its bundled sh.

The pre-commit hook detects the project type from marker files (go.mod, Cargo.toml, package.json, and friends), formats, lints, and type checks the staged files, and re-stages what the formatters fixed. Extension-keyed checks run regardless of project type: shfmt and shellcheck on staged shell files, stylua and selene on lua, scalafmt on scala, pint on php, and a PSScriptAnalyzer pass through pwsh on Windows. Every check skips cleanly when its tool is missing.

The commit-msg hook enforces Conventional Commits (feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert, break, bump) with the subject capped at 100 characters, counted in codepoints so multibyte subjects measure correctly. The merge and revert skip reads the subject line only. The hook strips AI attribution trailers (Co-Authored-By and Generated with lines from Claude, Copilot, Cursor, and friends) before the merge skip, so merge commits get the strip too.

### Claude Code hooks

The statusline uses a unified bash script (`statusline.sh`) on both Linux and Windows (via Git Bash), registered in `~/.claude/settings.json` by the settings injection below.

Quality checks can be configured per-project using project-specific hooks or MCP servers.

### Claude Code settings injection

Deploy merges the committed `.claude/settings.template.json` into `~/.claude/settings.json` on every run, on both platforms:

The template is the source of truth: template values win for shared keys recursively at every level, live-only keys survive the merge, and a missing `settings.json` is created from the template. `env.ANTHROPIC_AUTH_TOKEN` is deliberately absent from the template so the live value survives. Linux/macOS uses jq with a python3 fallback and Windows uses native PowerShell JSON. Keys listed in `.claude/settings.retired.json` are deleted from the live file on every deploy. Each entry maps a dotted path to the reason and reference for its retirement, and entries should target leaf keys: retiring a parent path also removes live-only keys beneath it.

Injected top-level fields:

| Field | Template value | Purpose |
|-------|----------------|---------|
| `env` | the variables in the table below | API endpoint, models, limits, feature flags |
| `model` | `glm-5.3[1m]` | Default model |
| `statusLine` | `bash ~/.claude/statusline.sh` | Statusline command |
| `enabledPlugins` | the plugins listed in the template | Plugin enablement |
| `alwaysThinkingEnabled` | `true` | Extended thinking by default |
| `autoUpdatesChannel` | `latest` | Update channel |
| `tui` | `fullscreen` | Terminal UI mode |
| `skipDangerousModePermissionPrompt` | `true` | Skip dangerous-mode prompt |
| `teammateMode` | `auto` | Agent teams mode |
| `attribution` | `{commit: "", pr: ""}` | No attribution lines in commits and PRs |

Injected `env` variables:

| Variable | Value | Purpose |
|----------|-------|---------|
| `ANTHROPIC_BASE_URL` | `https://api.z.ai/api/anthropic` | API endpoint |
| `API_TIMEOUT_MS` | `3000000` | Request timeout |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | `1` | Disable telemetry traffic |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | `1` | Enable agent teams |
| `CLAUDE_CODE_ENABLE_AUTO_MODE` | `1` | Enable auto mode |
| `CLAUDE_CODE_MAX_OUTPUT_TOKENS` | `131072` | Max output tokens |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | `48.5` | Autocompact trigger percentage (48.5% of the 1M window = 485k tokens) |
| `CLAUDE_CODE_AUTO_COMPACT_WINDOW` | `1000000` | Autocompact context window |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | `glm-5.3-flash[1m]` | Haiku-class model override |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | `glm-5.3[1m]` | Sonnet-class model override |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | `glm-5.3[1m]` | Opus-class model override |
| `CLAUDE_CODE_EFFORT_LEVEL` | `max` | Reasoning effort |
| `CLAUDE_CODE_SUBAGENT_MODEL` | `glm-5.3[1m]` | Sub-agent model override |

`enabledPlugins` enables the plugins listed in `.claude/settings.template.json`: the repomix plugins, the official LSP plugins, and the workflow plugins such as feature-dev, code-review, superpowers, and claude-security.

Retired settings, deleted from the live file on deploy via `.claude/settings.retired.json`:

| Retired key | Reason | Reference |
|-------------|--------|-----------|
| `env.CLAUDE_CODE_MAX_OUTPUT_TOKEN` | Misspelling of the documented `CLAUDE_CODE_MAX_OUTPUT_TOKENS`, which the template now sets | [env vars reference](https://code.claude.com/docs/en/env-vars) |
| `enabledPlugins.remember@claude-plugins-official` | Unused plugin that only appeared in /plugin because a v5.28.1 template sync copied the live disable flag in | [plugins reference](https://code.claude.com/docs/en/plugins) |

### OpenCode config merging

`~/.config/opencode/opencode.json` is deep-merged, never overwritten, on both platforms. Deploy adds missing MCP servers from the platform template, updates template-managed values that changed (stale URLs, commands), repairs a malformed scalar `mcp` section, and preserves user-added servers and user-added keys.

### Winget location-pinned upgrades (Windows)

Packages whose winget manifest requires an install location (`InstallLocationRequired`, currently `Blizzard.BattleNet`) are upgraded by `update-all.ps1` before `winget upgrade --all`. Each entry in the `$WingetLocationUpgrades` table at the top of `update-all.ps1` is upgraded with `--location`, which winget passes to the installer verbatim (`C:\Program Files (x86)\Battle.net` for Battle.net). The package also gets a non-blocking pin, so `winget upgrade --all` skips it and never prompts interactively for an install root. `installBehavior.defaultInstallRoot` is deliberately not used: winget appends the package ID to that root (`C:\...\Battle.net\Blizzard.BattleNet`), so no value can produce the real product folder. Entries that are not installed are skipped.

### Claude Code Windows LSP patching

npm-installed LSPs (typescript-language-server, pyright-langserver, intelephense) need `cmd.exe /c` wrapper. Auto-patches marketplace.json to fix `spawn EINVAL` errors. On Linux/macOS, deploy strips the same `cmd.exe` wrappers if a marketplace.json was carried over from a Windows machine.

### MCP server manual patching (Windows)

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

### GUI applications post-installation

After bootstrap installs ComfyUI Desktop via winget on Windows, run `comfy install` to complete setup:

```powershell
comfy install
```

This installs required models and dependencies for AI image generation.

## Neovim

Leader key is Space.

Unmapped native keys stay live: `Q` toggles a multicursor (`[count]Q` places one per search match, `q=` follow mode, `gQ` restore, CTRL-L clears), `gc` and `gcc` comment, `v_an` and `v_in` grow or shrink the treesitter selection, `v_]N` and `v_[N` jump to sibling nodes, `v_al` and `v_il` select the buffer or line, and the LSP defaults `K`, `grn`, `gra`, `grr`, `gri`, `gO`, `grt`, `grx`, `[d`, `]d`, and `<C-W>d` work without any plugin.

<details>
<summary>Day-to-day usage guide</summary>

### Big picture

The config leans on the builtins. Neovim 0.13 itself does editing, completion, LSP, diagnostics, folding, commenting, multicursor, and file browsing. The small plugin set only fills gaps: fzf-lua for pickers, treesitter for parser installs, lspconfig for server definitions, rose-pine for color, the two preview plugins for documents, devicons for icons.

2 options change the daily rhythm more than any keybinding. Autosave is always on (`autowriteall` plus a `TextChanged` autocmd), files write themselves while you type, so you almost never run `:w` and `:q` is safe. Autoread with the 0.13 fs watcher reloads files changed underneath you by formatters, code generators, or another pane. Between the 2, buffer state and disk state stay in sync without manual saves.

### Getting around

`<leader>f` finds files, `<leader>z` live-greps the project as you type, `<leader>/` greps the current buffer. `<leader>e` and `<leader>n` are the catch-all pickers when you do not remember which specific one you need. Previews render through bat in the rose-pine theme. `-` opens the parent directory in the builtin dir browser, Enter edits, `-` again goes up. For heavier file management drop to yazi with `y` in the shell, which cd's on exit. `<leader>'` flips to the alternate file for the edit/test or header/impl ping-pong, `<leader>h` searches help tags, `<leader>k` lists every keymap.

### The edit loop

Completion is native and autotriggered: on an attached LSP buffer the menu pops as you type, nothing is preselected, typing fuzzy-filters in place. Walk entries with `C-n`/`C-p` and accept with `Enter`.

Renaming many spots is the 0.13 multicursor: `Q` adds a cursor on the word under the cursor, `Q` in visual mode cursors the selection, `[count]Q` drops a cursor on the next count matches, `CTRL-L` clears, `gQ` restores the last set. Edits on any cursor replicate everywhere. For a semantic rename prefer `grn`, which goes through LSP and catches references the parser understands.

Structural selection uses the treesitter text objects: `v_an` grows the selection to the next node up, `v_in` shrinks it, `v_]N`/`v_[N` jump between sibling nodes. `gc` comments lines or selections, `za`/`zR`/`zM` work folds since every filetype with a parser folds by syntax tree. `inccommand=split` gives live preview: type `:%s/old/new` and the split shows each match rewritten before you press Enter.

### The LSP loop

Enabled servers attach by filetype automatically, no `:LspStart`. Native keys handle the quick moves: `K` hover, `grn` rename, `gra` code action, `grr` references, `gri` implementations, `gO` symbol outline, `[d` and `]d` jump diagnostics, `<C-W>d` pops the diagnostic under the cursor. Leader pickers handle the rest with fzf previews: `<leader>j` definitions, `<leader>v` declarations, `<leader>r` references, `<leader>i` implementations, `<leader>s` document symbols, `<leader>w` live workspace symbols, `<leader>\` the all-in-one finder on the symbol under the cursor, `<leader>,` and `<leader>.` call hierarchy, `<leader>a` code actions, `<leader>b` format the buffer.

Diagnostics stay quiet: pause on a line for 1 second and its message expands underneath as virtual text, then collapses when you move. That is `updatetime` 1000 plus `virtual_lines.current_line`. For the backlog, `<leader>dd` lists document diagnostics, `<leader>dw` the workspace. YAML gets schema-aware completion and validation for kubernetes manifests, docker-compose files, and GitHub workflows. Values files under a `Chart.yaml` attach `helm_ls` on top of `yamlls`, and compose files attach `docker_language_server` the same way.

### The git loop

Read-only inspection lives in nvim: `<leader>gs` status, `<leader>gd` diff, `<leader>gl` blame, `<leader>gc` commits, `<leader>gh` hunks. Anything that mutates belongs to lazygit (`lg` in the shell). The split keeps nvim buffers from fighting the index state.

### Writing and documents

Typst: `<leader>pt` toggles the live preview, which re-renders in a browser pane on each keystroke. Markdown, HTML, and CSV use live-preview.nvim: `<leader>ps` starts, `<leader>pc` closes, `<leader>;` picks which preview to attach. Autosave writes, the preview re-renders, you never save manually.

### Upkeep

`<leader>u` updates all plugins and rewrites the deployed lockfile. After an intentional bump, copy the deployed `nvim-pack-lock.json` from nvim's config dir back to `.config/nvim/` in the repo and commit, the lockfile is the pin mechanism, there are no version pins in `init.lua`. `up` in the shell covers everything else including nvim itself and treesitter parsers. `<leader>x` after any config tweak re-sources in place.

</details>

| Keybinding | Action |
|------------|--------|
| `-` | Open parent directory (builtin) |
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

## Release process

Versioning is major.minor since v6.0, earlier releases carried SemVer patch levels. Work lands under an `## [Unreleased]` heading in CHANGELOG.md, one short line per change. At release the heading is renamed to `## [X.Y] - date`, committed as `chore: release vX.Y`, tagged `vX.Y`, and pushed. The release is then published with `gh release create vX.Y` using the changelog line as the note.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and changes.

## License

MIT
