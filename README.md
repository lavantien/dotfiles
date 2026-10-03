# Universal dotfiles

[![Security](https://img.shields.io/badge/security-reviewed-brightgreen)](#security) [![Linux](https://img.shields.io/badge/Linux-FCC624?logo=linux&logoColor=black)](https://github.com/lavantien/dotfiles) [![Windows](https://img.shields.io/badge/Windows-0078D6?logo=windows&logoColor=white)](https://github.com/lavantien/dotfiles) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)


These portable, production-grade dotfiles set up a software engineering environment for Linux and Windows 11 in one click.

The toolchain auto-detects the platform and degrades gracefully when something is unavailable. Bootstrap and updates are idempotent and safe to rerun, and the setup covers the full terminal tooling.

## Core features

The editor stack pairs Neovim 0.13+ (beta), configured with the vim.pack manager plus lockfile, LSP and Treesitter setup, native completion, and the builtin dir browser, with the GPU-accelerated WezTerm terminal running the IosevkaTerm Nerd Font. The Rose Pine theme runs across every config.

Language tooling covers 21 LSP servers (jdtls excluded on Windows), 28 Treesitter parsers, and 40+ CLI tools for modern development workflows: fzf, yazi, zoxide, bat, eza, lazygit, gh, ripgrep, fd, sqlite, tokei, btop, repomix, docker-compose, helm, kubectl.

AI-native development supports Claude Code and OpenCode with 3 MCP servers (context7, playwright, repomix), Git pre-commit and commit-msg hooks that auto-detect and trigger format, lint, and check runs, a Claude Code statusline hook driven by one bash script and auto-registered in settings.json, and system instruction sync across all repos through AGENTS.md, GEMINI.md, and RULES.md stubs that redirect to .claude/CLAUDE.md.

Automation is built around safety: bootstrap and update-all are idempotent and safe to run multiple times, they auto-detect the environment and degrade gracefully when a tool is unavailable, Windows stays OneDrive-aware, and timestamped backup and restore wrap major changes. The tested platforms are Linux (Ubuntu 26.04+) and Windows 11 with PowerShell 7+.

## Quick start

> Required clone location: this repository must be cloned to `~/dev/github/dotfiles`.
>
> For Docker/Kubernetes setup, see [DOCKER_K8S.md](DOCKER_K8S.md).

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

### Verify installation

```bash
which n  # Should point to nvim
which lg  # Should point to lazygit
up  # Runs update-all
```

## Available commands

`bootstrap` is the entry point for initial setup: it installs package managers, SDKs, LSPs, and tools, then deploys configs. `deploy` handles config and script deployment (Neovim, git hooks, shell, Claude Code settings, OpenCode MCPs, ~/dev scripts), with its options listed under deploy options below.

Maintenance goes through `update-all`, aliased `up`, which updates all package managers and system packages (20+ managers). `git-update-repos` clones or updates every GitHub repo through the gh CLI and optionally syncs system instructions. `sync-system-instructions` syncs the AI system instructions (AGENTS.md, GEMINI.md, RULES.md) to all repos and removes stale CLAUDE.md copies. `sync-release-notes` pushes each CHANGELOG.md section to its GitHub release, editing published bodies and cutting releases for tagged versions that lack one (`-n` or `-DryRun` prints the plan). `books-index` regenerates `.claude/BOOKS.md` and the books index table inside `.claude/CLAUDE.md` from the books corpus manifests plus `books-index.json`, run it after corpus or annotation changes and redeploy. `healthcheck` verifies tools, configs, and git hooks. `backup` creates a timestamped backup before major changes and `restore` rolls one back. `uninstall` removes deployed configs and keeps installed packages.

Windows uses `.ps1` scripts. Linux/macOS uses `.sh` scripts.

### Bootstrap options

| Option | Bash | PowerShell | Default |
|--------|------|------------|---------|
| Non-interactive | `-y`, `--yes` | `-Y` | Prompt for confirmation |
| Dry-run | `--dry-run` | `-DryRun` | Install everything |
| Categories | `--categories sdk` | `-Categories sdk` | full |
| Verbose | `--verbose` | `-VerboseMode` | Show detailed output |

### Update-All options

`--skip-pip` (bash) or `-SkipPip` (PowerShell) skips pip package updates to speed up the run. Use it through the alias as `up --skip-pip` or `up -SkipPip`.

### Deploy options

| Option | Bash | PowerShell | Purpose |
|--------|------|------------|---------|
| Skip config deployment | `--skip-config` | `-SkipConfig` | Deploy ~/dev scripts only, skip all config deployment |
| Verbose file logging | `--verbose` | (always on) | Log each copied file |
| Pre-deploy backup | `--backup` | `-Backup` | Force backup before deploy (also via `backup_before_deploy` config) |
| Help | `--help` | (Get-Help) | Show usage |

Both deploys write a `~/.dotfiles-installed` marker (timestamp, version, OS) read by uninstall. `-DotfilesDir` and `POWERSHELL_PROFILE_CONFIG` are Windows-only parameters. Bash derives the repo location from the script path and honors `XDG_CONFIG_HOME`.

### Installation categories

The categories are cumulative tiers. minimal covers package managers, git, and CLI tools only. sdk adds programming language SDKs. full adds all LSPs plus linters and formatters, and it is the default.

### Configuration (optional)

All scripts use hardcoded defaults by default (`categories: full`, interactive prompts).

```bash
cp .dotfiles.config.yaml.example ~/.dotfiles.config.yaml
vim ~/.dotfiles.config.yaml
./bootstrap.sh  # Auto-detects config
```

Configuration priority: command-line flags override the config file, and the config file overrides the hardcoded defaults.

| Setting | Values | Default |
|---------|--------|---------|
| categories | minimal, sdk, full | full |
| editor | nvim, vim, code, nano | (none) |
| theme | rose-pine, rose-pine-dawn, rose-pine-moon | (none) |
| github_username | your github username | lavantien |
| base_dir | path to git repos | ~/dev/github |
| auto_commit_changes | true, false | false |
| auto_update_repos | true, false | false |
| backup_before_deploy | true, false | false |

### Health and troubleshooting

```bash
./healthcheck.sh

# JSON output (for CI/CD)
./healthcheck.sh --format json
```

If git hooks are not running, set `git config --global core.hooksPath ~/.config/git/hooks`. If the PowerShell execution policy blocks the scripts, run `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`. If Neovim plugins are not installing, run `:packupdate` in Neovim or press `<leader>u`. If zoxide is not jumping, use directories normally for a few days to let it learn.

## Complete tools/packages matrix

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

### CLI tools

The CLI tool set is fzf, yazi, zoxide, bat, eza, lazygit, gh, ripgrep, fd, sqlite, tokei, btop, repomix, docker-compose, helm, and kubectl.

### MCP servers (Claude Code and OpenCode)

The 3 MCP servers are context7, playwright, and repomix.

### Diagram generation

mermaid-cli ships the `mmdc` command to generate Mermaid diagrams from the command line.

### AI applications (Windows)

ComfyUI Desktop covers AI image generation and needs `comfy install` after bootstrap.

## Hooks and config merging

### Git hooks

The pre-commit hook auto-formats, lints, type-checks, and re-stages fixed files. The commit-msg hook enforces Conventional Commits (feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert). Both ship per platform: `.sh` for Linux/macOS, `.ps1` for Windows.

### Claude Code hooks

The statusline uses a unified bash script (`statusline.sh`) on both Linux and Windows (via Git Bash), registered in `~/.claude/settings.json` by the settings injection below.

Quality checks can be configured per-project using project-specific hooks or MCP servers.

### Claude Code settings injection

Deploy merges the committed `.claude/settings.template.json` into `~/.claude/settings.json` on every run, on both platforms:

The template is the source of truth: template values win for shared keys recursively at every level, live-only keys survive the merge, and a missing `settings.json` is created from the template. `env.ANTHROPIC_AUTH_TOKEN` is deliberately absent from the template so the live value survives. Linux/macOS uses jq with a python3 fallback and Windows uses native PowerShell JSON. Keys listed in `.claude/settings.retired.json` are deleted from the live file on every deploy. Each entry maps a dotted path to the reason and reference for its retirement, and entries should target leaf keys: retiring a parent path also removes live-only keys beneath it.

Injected top-level fields:

| Field | Template value | Purpose |
|-------|----------------|---------|
| `env` | 13 variables (table below) | API endpoint, models, limits, feature flags |
| `model` | `glm-5.3[1m]` | Default model |
| `statusLine` | `bash ~/.claude/statusline.sh` | Statusline command |
| `enabledPlugins` | 31 plugins, 30 enabled | Plugin enablement |
| `alwaysThinkingEnabled` | `true` | Extended thinking by default |
| `autoUpdatesChannel` | `latest` | Update channel |
| `tui` | `fullscreen` | Terminal UI mode |
| `skipDangerousModePermissionPrompt` | `true` | Skip dangerous-mode prompt |
| `teammateMode` | `auto` | Agent teams mode |

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

`enabledPlugins` entries: glm-plan-usage@zai-coding-plugins, repomix-commands@repomix, repomix-explorer@repomix, repomix-mcp@repomix, and @claude-plugins-official for frontend-design, context7, feature-dev, code-review, commit-commands, typescript-lsp, playwright, agent-sdk-dev, pr-review-toolkit, pyright-lsp, gopls-lsp, rust-analyzer-lsp, csharp-lsp, php-lsp, jdtls-lsp, clangd-lsp, lua-lsp, code-simplifier, superpowers, claude-code-setup, chrome-devtools-mcp, plugin-dev, microsoft-docs, postman, claude-security, math-olympiad.

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

The config is builtin-first. Neovim 0.13 itself does editing, completion, LSP, diagnostics, folding, commenting, multicursor, and file browsing. The 7 plugins only fill gaps: fzf-lua for pickers, treesitter for parser installs, lspconfig for server definitions, rose-pine for color, the two preview plugins for documents, devicons for icons.

2 options change the daily rhythm more than any keybinding. Autosave is always on (`autowriteall` plus a `TextChanged` autocmd), files write themselves while you type, so you almost never run `:w` and `:q` is safe. Autoread with the 0.13 fs watcher reloads files changed underneath you by formatters, code generators, or another pane. Between the 2, buffer state and disk state stay glued together with zero keystrokes.

### Getting around

`<leader>f` finds files, `<leader>z` live-greps the project as you type, `<leader>/` greps the current buffer. `<leader>e` and `<leader>n` are the kitchen-sink pickers when you do not remember which specific one you need. Previews render through bat in the rose-pine theme. `-` opens the parent directory in the builtin dir browser, Enter edits, `-` again goes up. For heavier file management drop to yazi with `y` in the shell, which cd's on exit. `<leader>'` flips to the alternate file for the edit/test or header/impl ping-pong, `<leader>h` searches help tags, `<leader>k` lists every keymap.

### The edit loop

Completion is native and autotriggered: on an attached LSP buffer the menu pops as you type, nothing is preselected, typing fuzzy-filters in place. Walk entries with `C-n`/`C-p` and accept with `Enter`.

Renaming many spots is the 0.13 multicursor: `Q` adds a cursor on the word under the cursor, `Q` in visual mode cursors the selection, `[count]Q` drops a cursor on the next count matches, `CTRL-L` clears, `gQ` restores the last set. Edits on any cursor replicate everywhere. For a semantic rename prefer `grn`, which goes through LSP and catches references the parser understands.

Structural selection uses the treesitter text objects: `v_an` grows the selection to the next node up, `v_in` shrinks it, `v_]N`/`v_[N` jump between sibling nodes. `gc` comments lines or selections, `za`/`zR`/`zM` work folds since every filetype with a parser folds by syntax tree. `inccommand=split` gives live preview: type `:%s/old/new` and the split shows each match rewritten before you press Enter.

### The LSP loop

Enabled servers attach by filetype automatically, no `:LspStart`. Native keys handle the quick moves: `K` hover, `grn` rename, `gra` code action, `grr` references, `gri` implementations, `gO` symbol outline, `[d` and `]d` jump diagnostics, `<C-W>d` pops the diagnostic under the cursor. Leader pickers handle the rest with fzf previews: `<leader>j` definitions, `<leader>v` declarations, `<leader>r` references, `<leader>i` implementations, `<leader>s` document symbols, `<leader>w` live workspace symbols, `<leader>\` the all-in-one finder on the symbol under the cursor, `<leader>,` and `<leader>.` call hierarchy, `<leader>a` code actions, `<leader>b` format the buffer.

Diagnostics stay quiet: pause on a line for 1 second and its message expands underneath as virtual text, then collapses when you move. That is `updatetime` 1000 plus `virtual_lines.current_line`. For the backlog, `<leader>dd` lists document diagnostics, `<leader>dw` the workspace. YAML gets schema-aware completion and validation for kubernetes manifests, docker-compose files, and GitHub workflows.

### The git loop

Read-only inspection lives in nvim: `<leader>gs` status, `<leader>gd` diff, `<leader>gl` blame, `<leader>gc` commits, `<leader>gh` hunks. Anything that mutates belongs to lazygit (`lg` in the shell). The split keeps nvim buffers from fighting the index state.

### Writing and documents

Typst: `<leader>pt` toggles the live preview, which re-renders in a browser pane on each keystroke. Markdown, HTML, and CSV use live-preview.nvim: `<leader>ps` starts, `<leader>pc` closes, `<leader>;` picks which preview to attach. Autosave writes, the preview re-renders, you never save manually.

### Upkeep

`<leader>u` updates all 7 plugins and rewrites the deployed lockfile. After an intentional bump, copy the deployed `nvim-pack-lock.json` from nvim's config dir back to `.config/nvim/` in the repo and commit, the lockfile is the pin mechanism, there are no version pins in `init.lua`. `up` in the shell covers everything else including nvim itself and treesitter parsers. `<leader>x` after any config tweak re-sources in place.

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

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and changes.

## License

MIT
