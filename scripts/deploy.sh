#!/usr/bin/env bash
# Universal Deploy Script - Works on Linux and macOS
# Auto-detects platform and deploys appropriate configurations
# Handles various edge cases: XDG dirs, OneDrive sync, multiple shells

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Detect OS
detect_os() {
	case "$(uname -s)" in
	Linux*) echo "linux" ;;
	Darwin*) echo "macos" ;;
	MINGW* | MSYS* | CYGWIN*) echo "windows" ;;
	*) echo "unknown" ;;
	esac
}

OS=$(detect_os)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Support XDG_CONFIG_HOME
XDG_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"

# ============================================================================
# GIT CONFIG MERGE - Preserves user identity
# ============================================================================

# Rewrite legacy absolute gh credential helper paths (linuxbrew installs,
# gh.exe on Windows, quoted forms included) to the PATH-resolved form. Git
# runs credential helpers through sh, so !gh auth git-credential finds gh
# wherever it is installed. Indentation is preserved and already canonical
# files are left byte-identical.
normalize_gh_helpers() {
	local file="$1" tmp="$1.dotfiles-norm"
	awk '
		function fold(line, indent) {
			if (line ~ /^[[:space:]]*helper[[:space:]]*=[[:space:]]*!?"?[^"]*gh(\.exe)?"?[[:space:]]+auth[[:space:]]+git-credential"?[[:space:]]*$/) {
				match(line, /^[[:space:]]*/)
				return substr(line, RSTART, RLENGTH) "helper = !gh auth git-credential"
			}
			return line
		}
		{ print fold($0) }
	' "$file" >"$tmp" || {
		rm -f "$tmp"
		return 1
	}
	if cmp -s "$file" "$tmp"; then
		rm -f "$tmp"
	else
		mv "$tmp" "$file"
	fi
}

# Deep merge for git config files: the template is the source of truth for
# every key it manages, live-only keys (signingkey, gpgsign, includes,
# aliases, extra sections) survive in reopened sections at the end, and
# user.name plus user.email are never template-managed so git
# last-value-wins keeps the live identity even under placeholder templates.
merge_gitconfig_files() {
	local template="$1" live="$2"
	awk '
		function section_id(inner) {
			sub(/^[[:space:]]+/, "", inner)
			sub(/[[:space:]]+$/, "", inner)
			if (match(inner, /"[^"]*"$/)) {
				head = substr(inner, 1, RSTART - 1)
				sub(/[[:space:]]+$/, "", head)
				return tolower(head) "\t" substr(inner, RSTART)
			}
			return tolower(inner) "\t"
		}
		function key_of(line) {
			sub(/^[[:space:]]+/, "", line)
			sub(/[[:space:]=].*$/, "", line)
			return tolower(line)
		}
		function flush_live(i) {
			# Trailing blanks are block separators, not content; dropping
			# them keeps repeated deploys from accumulating blank lines
			while (n > 0 && buf[n] ~ /^[[:space:]]*$/) n--
			if (n > 0) {
				print ""
				print live_hdr
				for (i = 1; i <= n; i++) print buf[i]
			}
			n = 0
		}
		NR == FNR {
			if ($0 ~ /^[[:space:]]*\[/) {
				tpl_sec = ""
				if (match($0, /\[[^]]*\]/)) {
					tpl_sec = section_id(substr($0, RSTART + 1, RLENGTH - 2))
					tpl_secs[tpl_sec] = 1
				}
				print
				next
			}
			k = key_of($0)
			if (k != "" && tpl_sec != "" && !(tpl_sec == "user\t" && (k == "name" || k == "email"))) {
				managed[tpl_sec, k] = 1
			}
			print
			next
		}
		{
			if ($0 ~ /^[[:space:]]*\[/) {
				flush_live()
				live_sec = ""
				if (match($0, /\[[^]]*\]/)) {
					live_sec = section_id(substr($0, RSTART + 1, RLENGTH - 2))
					live_hdr = $0
				}
				next
			}
			if (live_sec == "") next
			if ($0 ~ /^[[:space:]]*$|^[[:space:]]*[#;]/) {
				if (!(live_sec in tpl_secs)) buf[++n] = $0
				next
			}
			k = key_of($0)
			if (!((live_sec, k) in managed)) buf[++n] = $0
		}
		END { flush_live() }
	' "$template" "$live"
}

merge_gitconfig() {
	local source="$1"
	local target="$2"
	local temp_file="$target.dotfiles-new"

	# If target doesn't exist, just copy
	if [[ ! -f "$target" ]]; then
		cp "$source" "$target"
		echo -e "${CYAN}Created $target${NC}"
		return 0
	fi

	# A live file git itself cannot parse is never merged through: keep it
	# and keep a timestamped backup, and warn loudly so the user fixes it
	# before identity data is lost
	if ! git config --file "$target" --list >/dev/null 2>&1; then
		local backup
		backup="$target.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
		cp "$target" "$backup"
		echo -e "${YELLOW}Warning: $target is not parseable by git, left unchanged${NC}"
		echo -e "${YELLOW}Backup saved to $backup, fix the file then redeploy${NC}"
		return 0
	fi

	if ! merge_gitconfig_files "$source" "$target" >"$temp_file"; then
		rm -f "$temp_file"
		echo -e "${YELLOW}Warning: gitconfig merge failed, $target left unchanged${NC}"
		return 0
	fi

	# Fold any legacy absolute gh helper paths into the portable form
	normalize_gh_helpers "$temp_file"

	# Atomically replace the target
	mv "$temp_file" "$target"
	echo -e "${CYAN}Updated $target (template applied, live-only keys preserved)${NC}"
}

# ============================================================================
# CONFIG MIGRATION (Self-correction for old config locations)
# ============================================================================
migrate_configs_to_xdg() {
	echo -e "${GREEN}Checking for configs in old locations...${NC}"

	local moved=0

	# Migrate wezterm.lua from ~ to ~/.config/wezterm/
	if [[ -f "$HOME/.wezterm.lua" ]] && [[ ! -f "$XDG_CONFIG/wezterm/wezterm.lua" ]]; then
		mkdir -p "$XDG_CONFIG/wezterm"
		mv "$HOME/.wezterm.lua" "$XDG_CONFIG/wezterm/wezterm.lua"
		echo -e "${CYAN}Moved ~/.wezterm.lua to ~/.config/wezterm/${NC}"
		moved=$((moved + 1))
	fi

	# Migrate git config from old location if XDG was set
	if [[ -n "$XDG_CONFIG_HOME" ]] && [[ -f "$HOME/.gitconfig" ]]; then
		# Keep the .gitconfig but also set up includes for XDG structure
		if ! grep -q "include.*gitconfig" "$HOME/.gitconfig" 2>/dev/null; then
			# Backup original
			cp "$HOME/.gitconfig" "$HOME/.gitconfig.backup" 2>/dev/null || true
		fi
	fi

	if [[ $moved -gt 0 ]]; then
		echo -e "${GREEN}Migrated $moved config(s) to XDG structure${NC}"
	else
		echo -e "${BLUE}All configs already in correct locations${NC}"
	fi
}

# ============================================================================
# CLI
# ============================================================================

usage() {
	echo "Usage: deploy.sh [--skip-config] [--verbose] [--backup] [-h|--help]"
	echo "  --skip-config  Deploy scripts to ~/dev only, skip all config deployment"
	echo "  --verbose      Log every copied file (src -> dst)"
	echo "  --backup       Run backup.sh before deploying (overrides config)"
	echo "  -h, --help     Show this help"
}

# Copy with optional verbose logging (mirrors Copy-File -Verbose in deploy.ps1)
copy_file() {
	local src="$1"
	local dst="$2"
	if [[ "$VERBOSE_MODE" == "true" ]]; then
		echo -e "${CYAN}  $(basename "$src") -> $dst${NC}"
	fi
	cp "$src" "$dst"
}

# Pre-deploy backup when --backup is passed or backup_before_deploy is configured
run_pre_deploy_backup() {
	if [[ "$FORCE_BACKUP" != "true" && "$CONFIG_BACKUP_BEFORE_DEPLOY" != "true" ]]; then
		return 0
	fi
	local backup_script="$SCRIPT_DIR/backup.sh"
	if [[ ! -f "$backup_script" ]]; then
		echo -e "${YELLOW}backup.sh not found, skipping pre-deploy backup${NC}"
		return 0
	fi
	echo -e "${GREEN}Running pre-deploy backup (backup_before_deploy)${NC}"
	bash "$backup_script" || echo -e "${YELLOW}Backup reported failure, continuing${NC}"
}

# Marker read by uninstall.sh; version comes from the CHANGELOG top entry
write_deploy_marker() {
	local version
	version=$(awk -F'[][]' '/^## \[/{print $2; exit}' "$ROOT_DIR/CHANGELOG.md" 2>/dev/null)
	{
		echo "deployed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
		echo "version=${version:-unknown}"
		echo "os=$OS"
	} >"$HOME/.dotfiles-installed"
}

# ============================================================================
# COMMON DEPLOYMENT
# ============================================================================
# Scripts to ~/dev: always deployed, even with --skip-config
deploy_scripts() {
	echo -e "${GREEN}Deploying scripts to ~/dev...${NC}"

	mkdir -p "$HOME/dev"

	if [[ -f "$ROOT_DIR/git-clone-all.sh" ]]; then
		copy_file "$ROOT_DIR/git-clone-all.sh" "$HOME/dev/git-clone-all.sh"
		chmod +x "$HOME/dev/git-clone-all.sh" 2>/dev/null || true
	fi
	copy_file "$SCRIPT_DIR/git-update-repos.sh" "$HOME/dev/"
	chmod +x "$HOME/dev/git-update-repos.sh" 2>/dev/null || true

	if [ -f "$SCRIPT_DIR/update-all.sh" ]; then
		copy_file "$SCRIPT_DIR/update-all.sh" "$HOME/dev/"
		chmod +x "$HOME/dev/update-all.sh"
	fi

	echo -e "${GREEN}Scripts deployed.${NC}"
}

deploy_configs() {
	echo -e "${GREEN}Deploying common files...${NC}"

	# Create directories
	mkdir -p "$XDG_CONFIG"

	# Copy bash aliases (works on all platforms)
	copy_file "$ROOT_DIR/home/.bash_aliases" "$HOME/"

	# Merge git config (preserves user.name and user.email)
	merge_gitconfig "$ROOT_DIR/home/.gitconfig" "$HOME/.gitconfig"

	# Copy Neovim config (from .config/nvim/ to match repo structure)
	if [ -f "$ROOT_DIR/.config/nvim/init.lua" ]; then
		mkdir -p "$XDG_CONFIG/nvim"
		copy_file "$ROOT_DIR/.config/nvim/init.lua" "$XDG_CONFIG/nvim/"
	fi

	# Copy Neovim plugin lockfile so vim.pack resolves pinned revisions
	if [ -f "$ROOT_DIR/.config/nvim/nvim-pack-lock.json" ]; then
		copy_file "$ROOT_DIR/.config/nvim/nvim-pack-lock.json" "$XDG_CONFIG/nvim/"
	fi

	# Copy Wezterm config (from .config/wezterm/ to match repo structure)
	if [ -f "$ROOT_DIR/.config/wezterm/wezterm.lua" ]; then
		mkdir -p "$XDG_CONFIG/wezterm"
		copy_file "$ROOT_DIR/.config/wezterm/wezterm.lua" "$XDG_CONFIG/wezterm/"
	fi

	# Copy WezTerm background assets
	if [ -d "$ROOT_DIR/assets" ]; then
		mkdir -p "$HOME/assets"
		cp "$ROOT_DIR/assets"/* "$HOME/assets/" 2>/dev/null || true
		echo -e "${GREEN}WezTerm background assets copied to: $HOME/assets/${NC}"
	fi

	echo -e "${GREEN}Common files deployed.${NC}"
}

# ============================================================================
# GIT HOOKS
# ============================================================================
deploy_git_hooks() {
	echo -e "${GREEN}Deploying git hooks...${NC}"

	local hooks_dir="$XDG_CONFIG/git/hooks"
	mkdir -p "$hooks_dir"

	# Copy hooks from .config/git/hooks/ (matches repo structure)
	cp "$ROOT_DIR/.config/git/hooks/pre-commit" "$hooks_dir/" 2>/dev/null || true
	cp "$ROOT_DIR/.config/git/hooks/commit-msg" "$hooks_dir/" 2>/dev/null || true
	chmod +x "$hooks_dir/pre-commit" 2>/dev/null || true
	chmod +x "$hooks_dir/commit-msg" 2>/dev/null || true

	# Retired .ps1 twins linger in deployed dirs and init.templatedir keeps
	# copying them into new repos; prune so only the bash pair remains
	rm -f "$hooks_dir/pre-commit.ps1" "$hooks_dir/commit-msg.ps1"

	# Configure git to use the hooks
	git config --global init.templatedir "$hooks_dir"
	git config --global core.hooksPath "$hooks_dir"

	echo -e "${GREEN}Git hooks deployed to: $hooks_dir${NC}"
	echo -e "${BLUE}Neovim editor preference: ${CONFIG_EDITOR:-nvim}${NC}"
}

# ============================================================================
# UPDATE GIT CONFIG FOR PLATFORM-SPECIFIC FIXES
# ============================================================================
update_git_config() {
	echo -e "${GREEN}Checking .gitconfig for platform-specific fixes...${NC}"

	local gitconfig="$HOME/.gitconfig"
	if [[ ! -f "$gitconfig" ]]; then
		return
	fi

	# The template ships an intentional empty helper = reset (gh-only
	# credentials for github.com and gist.github.com), so empty helper lines
	# must survive: only legacy absolute gh paths are folded here.
	normalize_gh_helpers "$gitconfig"

	echo -e "${GREEN}  .gitconfig checked${NC}"
}

# ============================================================================
# BOOKS CORPUS
# ============================================================================
resume_corpus_present() {
	[[ -d "$HOME/dev/github/resume/books" ]]
}

# Deploy CLAUDE.md with the corpus root sentence spliced between the markers
# for this machine; everything else in the file stays byte-identical
deploy_claude_md() {
	local src="$1" dst="$2"
	local begin='<!-- BEGIN books corpus root -->'
	local end='<!-- END books corpus root -->'
	local sentence
	if resume_corpus_present; then
		sentence='The corpus root is ~/dev/github/resume/books.'
	else
		sentence='The corpus root is ~/.claude/books.'
	fi

	local begin_n end_n
	begin_n=$(grep -oF "$begin" "$src" | wc -l)
	end_n=$(grep -oF "$end" "$src" | wc -l)
	if [[ "$begin_n" -ne 1 || "$end_n" -ne 1 ]]; then
		echo "Error: corpus root marker pair must appear exactly once in $src" >&2
		exit 1
	fi

	local tmp="$dst.dotfiles-new"
	if ! awk -v b="$begin" -v e="$end" -v s="$sentence" '
		{
			line = $0
			bi = index(line, b)
			ei = index(line, e)
			if (bi > 0 && ei > bi) {
				line = substr(line, 1, bi + length(b) - 1) " " s " " substr(line, ei)
				replaced++
			}
			print line
		}
		END { if (replaced != 1) exit 3 }
	' "$src" >"$tmp"; then
		rm -f "$tmp"
		echo "Error: malformed corpus root marker pair in $src" >&2
		exit 1
	fi
	mv "$tmp" "$dst"
}

# Mirror the shipped typst corpus into ~/.claude/books when the private
# corpus is absent; the shipped corpus is curated, so it mirrors as is
deploy_claude_books() {
	local src_root="$ROOT_DIR/.claude/books" dst_root="$HOME/.claude/books"
	local volumes=() copied=0 deleted=0
	local path f rel out

	if resume_corpus_present; then
		echo -e "${CYAN}books: private corpus present, skipping $dst_root${NC}"
		return 0
	fi
	if [[ ! -d "$src_root" ]]; then
		echo -e "${YELLOW}books: no shipped corpus at $src_root${NC}"
		return 0
	fi

	for path in "$src_root"/*/; do
		[[ -d "$path" ]] || continue
		volumes+=("$(basename "$path")")
	done
	if [[ ${#volumes[@]} -eq 0 ]]; then
		echo -e "${YELLOW}books: no volumes under $src_root, leaving $dst_root untouched${NC}"
		return 0
	fi

	while IFS= read -r -d '' f; do
		rel="${f#"$src_root"/}"
		out="$dst_root/$rel"
		mkdir -p "$(dirname "$out")"
		if [[ ! -f "$out" ]] || ! cmp -s "$f" "$out"; then
			# mv over a read-only target needs directory write only, cp needs more
			cp "$f" "$out.dotfiles-new"
			mv -f "$out.dotfiles-new" "$out"
			copied=$((copied + 1))
		fi
	done < <(find "$src_root" -type f -print0)

	# Stale target files outside the shipped corpus go away, empty dirs too
	if [[ -d "$dst_root" ]]; then
		while IFS= read -r -d '' f; do
			rel="${f#"$dst_root"/}"
			if [[ ! -f "$src_root/$rel" ]]; then
				rm "$f"
				deleted=$((deleted + 1))
			fi
		done < <(find "$dst_root" -type f -print0)
		find "$dst_root" -mindepth 1 -type d -empty -delete 2>/dev/null || true
	fi

	echo -e "${CYAN}books deploy: ${#volumes[@]} volumes, $copied files copied, $deleted files deleted${NC}"
}

# ============================================================================
# CLAUDE CODE HOOKS
# ============================================================================
deploy_claude_hooks() {
	echo -e "${GREEN}Deploying Claude Code hooks...${NC}"

	mkdir -p "$HOME/.claude"

	# Refresh the repo books front from the private corpus; failure is non-fatal
	if ! bash "$SCRIPT_DIR/sync-book.sh"; then
		echo -e "${YELLOW}sync-book.sh failed, continuing${NC}"
	fi

	# Regenerate the books index from the refreshed front; failure is non-fatal
	if ! bash "$SCRIPT_DIR/books-index.sh"; then
		echo -e "${YELLOW}books-index.sh failed, continuing${NC}"
	fi

	# CLAUDE.md carries a corpus root spliced for this machine between markers
	# Repo structure: .claude/CLAUDE.md (matches deployment location)
	if [ -f "$ROOT_DIR/.claude/CLAUDE.md" ]; then
		deploy_claude_md "$ROOT_DIR/.claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
		echo -e "${GREEN}CLAUDE.md deployed to: $HOME/.claude/${NC}"
	fi

	# Copy the generated books corpus index referenced by CLAUDE.md principle 13
	if [ -f "$ROOT_DIR/.claude/BOOKS.md" ]; then
		copy_file "$ROOT_DIR/.claude/BOOKS.md" "$HOME/.claude/"
		echo -e "${GREEN}BOOKS.md deployed to: $HOME/.claude/${NC}"
	fi

	# Deploy quality check script
	if [ -f "$ROOT_DIR/.claude/quality-check.sh" ]; then
		copy_file "$ROOT_DIR/.claude/quality-check.sh" "$HOME/.claude/"
		chmod +x "$HOME/.claude/quality-check.sh"
	fi

	# Deploy Claude Code statusline script
	if [ -f "$ROOT_DIR/.claude/statusline.sh" ]; then
		copy_file "$ROOT_DIR/.claude/statusline.sh" "$HOME/.claude/"
		chmod +x "$HOME/.claude/statusline.sh"
	fi

	# Deploy PowerShell quality check (cross-platform payload, used from Windows)
	if [ -f "$ROOT_DIR/.claude/quality-check.ps1" ]; then
		copy_file "$ROOT_DIR/.claude/quality-check.ps1" "$HOME/.claude/"
	fi

	deploy_claude_books

	# Merge settings template into ~/.claude/settings.json (template values
	# win for shared keys, live-only keys and ANTHROPIC_AUTH_TOKEN survive,
	# retired keys are deleted)
	inject_claude_settings

	echo -e "${GREEN}Claude Code config deployed${NC}"
}

# ============================================================================
# MCP CONFIGS (Model Context Protocol for OpenCode and Claude Code)
# ============================================================================
deploy_mcp_configs() {
	echo -e "${GREEN}Deploying MCP configs...${NC}"

	# -------------------------------------------------------------------------
	# OpenCode Configuration (platform-specific)
	# -------------------------------------------------------------------------
	local opencode_config_dir="$XDG_CONFIG/opencode"
	local opencode_config="$opencode_config_dir/opencode.json"

	# Use platform-specific template
	local platform_template=""
	case $OS in
	linux)
		platform_template="$ROOT_DIR/.config/opencode/opencode.linux.json"
		;;
	macos)
		platform_template="$ROOT_DIR/.config/opencode/opencode.macos.json"
		;;
	windows)
		platform_template="$ROOT_DIR/.config/opencode/opencode.windows.json"
		;;
	*)
		# Fallback to generic if no platform match
		platform_template="$ROOT_DIR/.config/opencode/opencode.windows.json"
		;;
	esac

	if [[ -f "$platform_template" ]]; then
		mkdir -p "$opencode_config_dir"

		if [[ ! -f "$opencode_config" ]]; then
			# Config doesn't exist, create from platform-specific template
			cp "$platform_template" "$opencode_config"
			echo -e "${GREEN}OpenCode config created: $opencode_config (using $OS template)${NC}"
		else
			# Config exists - deep merge template MCPs into it
			merge_opencode_config "$opencode_config" "$platform_template"
		fi
	else
		echo -e "${YELLOW}OpenCode template not found at $platform_template${NC}"
	fi

	echo -e "${GREEN}MCP configs deployment complete${NC}"
}

# ============================================================================
# PLATFORM-SPECIFIC
# ============================================================================
deploy_linux() {
	echo -e "${GREEN}Deploying Linux-specific configs...${NC}"

	# Copy zshrc
	if [ -f "$ROOT_DIR/home/.zshrc" ]; then
		cp "$ROOT_DIR/home/.zshrc" "$HOME/"
	fi

	deploy_git_hooks
}

deploy_macos() {
	echo -e "${GREEN}Deploying macOS-specific configs...${NC}"

	# Copy zshrc (macOS default shell)
	if [ -f "$ROOT_DIR/home/.zshrc" ]; then
		cp "$ROOT_DIR/home/.zshrc" "$HOME/"
	fi

	deploy_git_hooks
}

# ============================================================================
# MAIN
# ============================================================================

print_final_message() {
	echo -e "${GREEN}=== Deployment Complete ===${NC}"
	echo -e "${YELLOW}Restart your shell (or source your rc file) to apply changes${NC}"
}

main() {
	# On Windows, direct users to the PowerShell deploy script
	if [[ "$OS" == "windows" ]]; then
		echo -e "${YELLOW}Detected Windows environment${NC}"
		echo -e "${CYAN}Please run: pwsh -File deploy.ps1${NC}"
		echo -e "${CYAN}Or from PowerShell: .\deploy.ps1${NC}"
		return 0
	fi

	# Source config library if available
	# shellcheck source=/dev/null
	if [[ -f "$ROOT_DIR/lib/config.sh" ]]; then
		source "$ROOT_DIR/lib/config.sh"
	fi

	# Source JSON merge helpers (Claude settings injection, OpenCode MCP merge)
	# shellcheck source=/dev/null
	if [[ -f "$ROOT_DIR/lib/json-merge.sh" ]]; then
		source "$ROOT_DIR/lib/json-merge.sh"
	fi

	# Load user config
	CONFIG_FILE="$HOME/.dotfiles.config.yaml"
	load_dotfiles_config "$CONFIG_FILE"

	# Get config values (with defaults)
	CONFIG_EDITOR=$(get_config "editor" "nvim")
	CONFIG_BACKUP_BEFORE_DEPLOY=$(get_config "backup_before_deploy" "false")

	# Show config status
	if [[ -f "$CONFIG_FILE" ]]; then
		echo -e "${GREEN}Using config: $CONFIG_FILE${NC}"
	else
		echo -e "${YELLOW}No config file found, using defaults${NC}"
	fi

	echo -e "${BLUE}Deploying dotfiles for: $OS${NC}"
	echo -e "${BLUE}Script directory: $SCRIPT_DIR${NC}"
	echo -e "${BLUE}Config directory: $XDG_CONFIG${NC}"

	# CLI flags
	SKIP_CONFIG=false
	VERBOSE_MODE=false
	FORCE_BACKUP=false

	while [[ $# -gt 0 ]]; do
		case $1 in
		--skip-config) SKIP_CONFIG=true && shift ;;
		--verbose) VERBOSE_MODE=true && shift ;;
		--backup) FORCE_BACKUP=true && shift ;;
		-h | --help) usage && return 0 ;;
		*)
			echo "Unknown option: $1"
			usage
			return 1
			;;
		esac
	done

	# Backup before any mutation when requested
	run_pre_deploy_backup

	# Ensure .config directory exists before deploying anything
	mkdir -p "$XDG_CONFIG"

	deploy_scripts

	if [[ "$SKIP_CONFIG" == "true" ]]; then
		echo -e "${YELLOW}Skipping config deployment (--skip-config)${NC}"
	else
		# Migrate configs from old locations to XDG structure
		migrate_configs_to_xdg

		deploy_configs
		deploy_claude_hooks
		deploy_mcp_configs

		case $OS in
		linux)
			deploy_linux
			;;
		macos)
			deploy_macos
			;;
		*)
			echo -e "${YELLOW}Unknown OS, deploying common files only${NC}"
			deploy_linux
			;;
		esac

		# Apply platform-specific .gitconfig fixes
		update_git_config

		# Remove cmd.exe LSP wrappers carried over from a Windows machine
		strip_windows_lsp_wrappers
	fi

	write_deploy_marker

	print_final_message
}

# Sourced runs (bats) define the functions only; direct runs deploy.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	main "$@"
fi
