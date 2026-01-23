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

# On Windows, direct users to the PowerShell deploy script
if [[ "$OS" == "windows" ]]; then
	echo -e "${YELLOW}Detected Windows environment${NC}"
	echo -e "${CYAN}Please run: pwsh -File deploy.ps1${NC}"
	echo -e "${CYAN}Or from PowerShell: .\deploy.ps1${NC}"
	exit 0
fi

# Support XDG_CONFIG_HOME
XDG_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"

# ============================================================================
# GIT CONFIG MERGE - Preserves user identity
# ============================================================================
merge_gitconfig() {
	local source="$1"
	local target="$2"
	local temp_file="$target.dotfiles-new"

	# If target doesn't exist, just copy
	if [[ ! -f "$target" ]]; then
		cp "$source" "$target"
		echo -e "${CYAN}Created ~/.gitconfig${NC}"
		return 0
	fi

	# Preserve user identity from existing config
	local user_name user_email
	user_name=$(git config --file "$target" user.name 2>/dev/null)
	user_email=$(git config --file "$target" user.email 2>/dev/null)

	# Copy new config
	cp "$source" "$temp_file"

	# Restore user identity if it existed
	if [[ -n "$user_name" ]]; then
		git config --file "$temp_file" user.name "$user_name"
	fi
	if [[ -n "$user_email" ]]; then
		git config --file "$temp_file" user.email "$user_email"
	fi

	# Atomically replace the target
	mv "$temp_file" "$target"
	echo -e "${CYAN}Updated ~/.gitconfig (preserved user identity)${NC}"
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
		((moved++)) || true
	fi

	# Migrate old nvim config location
	if [[ -f "$HOME/init.lua" ]] && [[ -d "$XDG_CONFIG/nvim" ]] && [[ ! -f "$XDG_CONFIG/nvim/init.lua" ]]; then
		mkdir -p "$XDG_CONFIG/nvim"
		cp "$HOME/init.lua" "$XDG_CONFIG/nvim/init.lua"
		echo -e "${CYAN}Copied ~/init.lua to ~/.config/nvim/${NC}"
		((moved++)) || true
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
# LOAD USER CONFIGURATION
# ============================================================================
# Source config library if available
if [[ -f "$SCRIPT_DIR/lib/config.sh" ]]; then
	source "$SCRIPT_DIR/lib/config.sh"
fi

# Load user config
CONFIG_FILE="$HOME/.dotfiles.config.yaml"
load_dotfiles_config "$CONFIG_FILE"

# Get config values (with defaults)
CONFIG_EDITOR=$(get_config "editor" "nvim")
CONFIG_THEME=$(get_config "theme" "rose-pine")
CONFIG_CATEGORIES=$(get_config "categories" "full")
CONFIG_AUTO_UPDATE_REPOS=$(get_config "auto_update_repos" "false")
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
echo -e "${BLUE}Categories: $CONFIG_CATEGORIES${NC}"

# ============================================================================
# COMMON DEPLOYMENT
# ============================================================================
deploy_common() {
	echo -e "${GREEN}Deploying common files...${NC}"

	# Create directories
	mkdir -p "$XDG_CONFIG"
	mkdir -p "$HOME/dev"

	# Copy bash aliases (works on all platforms)
	cp "$SCRIPT_DIR/.bash_aliases" "$HOME/"

	# Merge git config (preserves user.name and user.email)
	merge_gitconfig "$SCRIPT_DIR/.gitconfig" "$HOME/.gitconfig"

	# Copy Neovim config (from .config/nvim/ to match repo structure)
	if [ -f "$SCRIPT_DIR/.config/nvim/init.lua" ]; then
		# Copy to root (user preference)
		cp "$SCRIPT_DIR/.config/nvim/init.lua" "$HOME/"
		# Also copy to XDG config location
		mkdir -p "$XDG_CONFIG/nvim"
		cp "$SCRIPT_DIR/.config/nvim/init.lua" "$XDG_CONFIG/nvim/"
	fi

	# Copy Neovim lua directory if exists
	if [ -d "$SCRIPT_DIR/.config/nvim/lua" ]; then
		mkdir -p "$XDG_CONFIG/nvim/lua"
		cp -r "$SCRIPT_DIR/.config/nvim/lua/"* "$XDG_CONFIG/nvim/lua/" 2>/dev/null || true
	fi

	# Copy Wezterm config (from .config/wezterm/ to match repo structure)
	if [ -f "$SCRIPT_DIR/.config/wezterm/wezterm.lua" ]; then
		mkdir -p "$XDG_CONFIG/wezterm"
		cp "$SCRIPT_DIR/.config/wezterm/wezterm.lua" "$XDG_CONFIG/wezterm/"
	fi

	# Copy git scripts
	cp "$SCRIPT_DIR/git-clone-all.sh" "$HOME/dev/" 2>/dev/null || true
	cp "$SCRIPT_DIR/git-update-repos.sh" "$HOME/dev/"
	cp "$SCRIPT_DIR/sync-system-instructions.sh" "$HOME/dev/"
	chmod +x "$HOME/dev/git-update-repos.sh" 2>/dev/null || true
	chmod +x "$HOME/dev/sync-system-instructions.sh" 2>/dev/null || true

	# Copy update-all script
	if [ -f "$SCRIPT_DIR/update-all.sh" ]; then
		cp "$SCRIPT_DIR/update-all.sh" "$HOME/dev/"
		chmod +x "$HOME/dev/update-all.sh"
	fi

	# Copy Aider configs
	cp "$SCRIPT_DIR/.aider.conf.yml.example" "$HOME/.aider.conf.yml" 2>/dev/null || true

	# Copy WezTerm background assets
	if [ -d "$SCRIPT_DIR/assets" ]; then
		mkdir -p "$HOME/assets"
		cp "$SCRIPT_DIR/assets"/* "$HOME/assets/" 2>/dev/null || true
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
	cp "$SCRIPT_DIR/.config/git/hooks/pre-commit" "$hooks_dir/" 2>/dev/null || true
	cp "$SCRIPT_DIR/.config/git/hooks/commit-msg" "$hooks_dir/" 2>/dev/null || true
	chmod +x "$hooks_dir/pre-commit" 2>/dev/null || true
	chmod +x "$hooks_dir/commit-msg" 2>/dev/null || true

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

	local modified=false
	local fixes=()

	# Detect platform and apply appropriate fixes
	case "$OS" in
	linux | macos)
		# Remove absolute Windows paths to gh.exe (may have been copied from Windows)
		if grep -qE 'gh\.exe' "$gitconfig" 2>/dev/null; then
			fixes+=("absolute Windows path to gh.exe")
			if command -v perl >/dev/null 2>&1; then
				perl -i -ne 'print unless /^\s*helper\s*=\s*!".*?[A-Z]:\\/.*?gh\.exe"/' "$gitconfig" 2>/dev/null || true
			else
				sed -i '/gh\.exe.*auth/d' "$gitconfig" 2>/dev/null ||
					sed -i '' '/gh\.exe.*auth/d' "$gitconfig" 2>/dev/null || true
			fi
			modified=true
		fi
		;;
	esac

	# Universal cleanup: remove duplicate/empty helper lines
	if grep -qE '^\s*helper\s*=\s*$' "$gitconfig" 2>/dev/null; then
		fixes+=("empty helper lines")
		# Remove empty helper lines (backup first for safety)
		cp "$gitconfig" "$gitconfig.bak"
		grep -vE '^\s*helper\s*=\s*$' "$gitconfig.bak" >"$gitconfig" 2>/dev/null || true
		rm -f "$gitconfig.bak"
		modified=true
	fi

	# Remove empty credential sections
	if grep -E '\[credential "[^"]+"\]' "$gitconfig" 2>/dev/null | head -1 | grep -q .; then
		# This is complex, skip for now or use perl
		:
	fi

	if $modified; then
		echo -e "${YELLOW}  Fixes applied: ${fixes[*]}${NC}"
		echo -e "${GREEN}  .gitconfig updated${NC}"
	else
		echo -e "${GREEN}  .gitconfig is clean${NC}"
	fi
}

# ============================================================================
# CLAUDE CODE HOOKS
# ============================================================================
deploy_claude_hooks() {
	echo -e "${GREEN}Deploying Claude Code hooks...${NC}"

	mkdir -p "$HOME/.claude"

	# Copy CLAUDE.md to global .claude folder for project-agnostic instructions
	# Repo structure: .claude/CLAUDE.md (matches deployment location)
	if [ -f "$SCRIPT_DIR/.claude/CLAUDE.md" ]; then
		cp "$SCRIPT_DIR/.claude/CLAUDE.md" "$HOME/.claude/"
		echo -e "${GREEN}CLAUDE.md deployed to: $HOME/.claude/${NC}"
	fi

	# Deploy quality check script
	if [ -f "$SCRIPT_DIR/.claude/quality-check.sh" ]; then
		cp "$SCRIPT_DIR/.claude/quality-check.sh" "$HOME/.claude/"
		chmod +x "$HOME/.claude/quality-check.sh"
	fi

	# Deploy Claude Code statusline script
	if [ -f "$SCRIPT_DIR/.claude/statusline.sh" ]; then
		cp "$SCRIPT_DIR/.claude/statusline.sh" "$HOME/.claude/"
		chmod +x "$HOME/.claude/statusline.sh"
	fi

	# Deploy Claude Code hooks (PostToolUse for quality checks)
	mkdir -p "$HOME/.claude/hooks"
	if [ -f "$SCRIPT_DIR/.claude/hooks/post-tool-use.sh" ]; then
		cp "$SCRIPT_DIR/.claude/hooks/post-tool-use.sh" "$HOME/.claude/hooks/"
		chmod +x "$HOME/.claude/hooks/post-tool-use.sh"
	fi

	# Auto-register PostToolUse hook and statusline in Claude Code settings.json
	register_claude_code_hooks

	echo -e "${GREEN}Claude Code hooks deployed to: $HOME/.claude/hooks/${NC}"
	echo -e "${GREEN}PostToolUse hook and statusline auto-registered in settings.json${NC}"
}

# Register Claude Code hooks and statusline in settings.json without overwriting existing config
register_claude_code_hooks() {
	local settings_file="$HOME/.claude/settings.json"

	# Create settings.json if it doesn't exist
	if [ ! -f "$settings_file" ]; then
		echo "{}" >"$settings_file"
	fi

	# Detect OS to use appropriate hook command
	local hook_command
	if [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "darwin"* ]]; then
		hook_command="bash ~/.claude/hooks/post-tool-use.sh"
	else
		hook_command="pwsh -File ~/.claude/hooks/post-tool-use.ps1"
	fi

	# Use jq to add hooks if available, otherwise skip
	if ! command -v jq &>/dev/null; then
		echo -e "${YELLOW}jq not found, skipping auto-registration of hooks and statusline${NC}"
		echo -e "${YELLOW}Install jq to enable automatic hook registration${NC}"
		return 0
	fi

	# Check if PostToolUse hook already exists
	local existing_hooks
	existing_hooks=$(jq -r '.hooks.PostToolUse // empty' "$settings_file" 2>/dev/null)

	# Check if our hook is already registered
	if echo "$existing_hooks" | jq -e '.[] | select(.hooks[]?.command == "'"$hook_command"'")' &>/dev/null; then
		echo -e "${BLUE}PostToolUse hook already registered${NC}"
	else
		# Add the PostToolUse hook using jq
		local tmp_file="${settings_file}.tmp"

		# Build the jq command to add hooks
		jq --arg cmd "$hook_command" '
            if .hooks == null then
                .hooks = {}
            end |
            if .hooks.PostToolUse == null then
                .hooks.PostToolUse = []
            end |
            .hooks.PostToolUse += [
                {
                    "matcher": "Write|Edit|MultiEdit",
                    "hooks": [{"type": "command", "command": $cmd}]
                }
            ]
        ' "$settings_file" >"$tmp_file"

		if [ $? -eq 0 ]; then
			mv "$tmp_file" "$settings_file"
			echo -e "${GREEN}Registered PostToolUse hook in settings.json${NC}"
		else
			rm -f "$tmp_file"
			echo -e "${YELLOW}Failed to register hook in settings.json${NC}"
		fi
	fi

	# Register statusline (always ensure it's set)
	local tmp_file="${settings_file}.tmp"
	jq '
        .statusLine = {
            "type": "command",
            "command": "bash ~/.claude/statusline.sh"
        }
    ' "$settings_file" >"$tmp_file"

	if [ $? -eq 0 ]; then
		mv "$tmp_file" "$settings_file"
		echo -e "${GREEN}Registered statusline in settings.json${NC}"
	else
		rm -f "$tmp_file"
		echo -e "${YELLOW}Failed to register statusline in settings.json${NC}"
	fi
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
		platform_template="$SCRIPT_DIR/.config/opencode/opencode.linux.json"
		;;
	macos)
		platform_template="$SCRIPT_DIR/.config/opencode/opencode.macos.json"
		;;
	windows)
		platform_template="$SCRIPT_DIR/.config/opencode/opencode.windows.json"
		;;
	*)
		# Fallback to generic if no platform match
		platform_template="$SCRIPT_DIR/.config/opencode/opencode.windows.json"
		;;
	esac

	if [[ -f "$platform_template" ]]; then
		mkdir -p "$opencode_config_dir"

		if [[ ! -f "$opencode_config" ]]; then
			# Config doesn't exist, create from platform-specific template
			cp "$platform_template" "$opencode_config"
			echo -e "${GREEN}OpenCode config created: $opencode_config (using $OS template)${NC}"
		else
			# Config exists - perform smart merge to add missing universal MCPs
			if command -v jq >/dev/null 2>&1; then
				# Check if any universal MCP is missing and add it from platform template
				local universal_mcps=("context7" "playwright" "repomix" "serena")
				local merged=false

				for mcp in "${universal_mcps[@]}"; do
					if ! jq -e ".mcp.\"$mcp\"" "$opencode_config" >/dev/null 2>&1; then
						# MCP is missing, add it from platform-specific template
						local mcp_config=$(jq ".mcp.\"$mcp\"" "$platform_template")
						jq --arg mcp "$mcp" --argjson config "$mcp_config" '.mcp[$mcp] = $config' "$opencode_config" >"${opencode_config}.tmp"
						mv "${opencode_config}.tmp" "$opencode_config"
						merged=true
						echo -e "${GREEN}Added missing MCP to OpenCode config: $mcp${NC}"
					fi
				done

				if [[ "$merged" == "false" ]]; then
					echo -e "${BLUE}OpenCode config exists with all universal MCPs, preserving user configuration${NC}"
				fi
			else
				echo -e "${YELLOW}jq not found, skipping smart merge of OpenCode MCPs${NC}"
				echo -e "${BLUE}OpenCode config exists, preserving user configuration${NC}"
			fi
		fi
	else
		echo -e "${YELLOW}OpenCode template not found at $platform_template${NC}"
	fi

	# -------------------------------------------------------------------------
	# Claude Code Configuration
	# Note: MCP servers are managed via plugins, not this config
	# -------------------------------------------------------------------------
	local claude_config="$HOME/.claude.json"
	local claude_template="$SCRIPT_DIR/.claude.json.template"

	if [[ -f "$claude_template" ]]; then
		if [[ ! -f "$claude_config" ]]; then
			# Config doesn't exist, create from template
			cp "$claude_template" "$claude_config"
			echo -e "${GREEN}Claude Code config created: $claude_config${NC}"
		else
			echo -e "${BLUE}Claude Code config exists, preserving user configuration${NC}"
			echo -e "${BLUE}MCP servers are managed via plugins${NC}"
		fi
	else
		echo -e "${YELLOW}Claude Code template not found at $claude_template${NC}"
	fi

	echo -e "${GREEN}MCP configs deployment complete${NC}"
}

# ============================================================================
# PLATFORM-SPECIFIC
# ============================================================================
deploy_linux() {
	echo -e "${GREEN}Deploying Linux-specific configs...${NC}"

	# Copy zshrc
	if [ -f "$SCRIPT_DIR/.zshrc" ]; then
		cp "$SCRIPT_DIR/.zshrc" "$HOME/"
	fi

	deploy_git_hooks
}

deploy_macos() {
	echo -e "${GREEN}Deploying macOS-specific configs...${NC}"

	# Copy zshrc (macOS default shell)
	if [ -f "$SCRIPT_DIR/.zshrc" ]; then
		cp "$SCRIPT_DIR/.zshrc" "$HOME/"
	fi

	deploy_git_hooks
}

# ============================================================================
# MAIN
# ============================================================================
main() {
	# Ensure .config directory exists before deploying anything
	mkdir -p "$XDG_CONFIG"

	# Migrate configs from old locations to XDG structure
	migrate_configs_to_xdg

	deploy_common
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

	echo -e "${GREEN}=== Deployment Complete ===${NC}"
	echo -e "${YELLOW}Reload your shell to apply changes${NC}"
}

main
