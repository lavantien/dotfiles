#!/usr/bin/env bash
# Universal Update All Script - Linux/macOS/Windows (Git Bash)
# Updates all package managers and tools
# On Windows (Git Bash), skips Linux-only package managers that require sudo

# Note: set -e is intentionally NOT used because this script has its own
# error handling via update_fail() and the failed counter. With set -e,
# package manager failures would cause the entire script to exit instead
# of continuing to update other package managers.

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Detect OS
detect_os() {
	case "$(uname -s)" in
	Linux*) echo "linux" ;;
	Darwin*) echo "macos" ;;
	MINGW* | MSYS* | CYGWIN*)
		echo "windows"
		;;
	*) echo "unknown" ;;
	esac
}

# Check if running on Windows (Git Bash/MSYS/MINGW/CYGWIN)
is_windows() {
	# Note: Do NOT check for /mnt/c/Windows - that exists in WSL too
	[[ -n "$MSYSTEM" ]] || [[ "$(uname -s)" =~ (MINGW|MSYS|CYGWIN) ]]
}

# Check if we should use sudo (false on Windows, true on Linux/macOS for system packages)
should_use_sudo() {
	# Never use sudo on Windows (even if Windows sudo exists)
	if is_windows; then
		return 1
	fi
	return 0
}

# Command exists checker
cmd_exists() {
	command -v "$1" >/dev/null 2>&1
}

# Find PowerShell 7+ (pwsh.exe) on Windows, fall back to powershell.exe (5.1)
get_pwsh() {
	if ! is_windows; then
		echo "pwsh"
		return 0
	fi

	# Try pwsh.exe (PowerShell 7+) first
	if command -v pwsh.exe >/dev/null 2>&1; then
		echo "pwsh.exe"
		return 0
	fi

	# Fallback to powershell.exe (PowerShell 5.1) - may not work for all scripts
	echo "powershell.exe"
	return 0
}

# Check if a script-installed tool needs update by comparing with npm registry version
# Usage: script_tool_needs_update <npm_package_name> <installed_version>
# Returns: 0 = needs update, 1 = up to date
script_tool_needs_update() {
	local npm_package="$1"
	local current_version="$2"

	# Get latest version from npm registry
	local latest_version
	latest_version=$(npm view "$npm_package" version 2>/dev/null)

	if [[ -z "$latest_version" ]]; then
		# Couldn't determine latest version, assume update needed
		return 0
	fi

	# Compare versions (simple string comparison should work for semantic versioning)
	if [[ "$current_version" == "$latest_version" ]]; then
		return 1  # Up to date
	fi

	return 0  # Needs update
}

# Run installer and verify version actually changed
# Usage: install_and_verify_version <install_command> <binary_name> <version_command> [npm_package_name]
# If npm_package_name is provided, verifies against npm registry as external source of truth
# This addresses installers that don't clearly indicate if an update occurred
install_and_verify_version() {
	local install_cmd="$1"
	local binary_name="$2"
	local version_cmd="$3"
	local npm_package="${4:-}"  # Optional

	# Get latest version from npm if package name provided (external source of truth)
	local npm_version=""
	if [[ -n "$npm_package" ]]; then
		npm_version=$(npm view "$npm_package" version 2>/dev/null)
	fi

	# Get version before install
	local version_before
	version_before=$(eval "$version_cmd" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

	# Skip if already at latest version (based on external npm check)
	if [[ -n "$npm_version" ]] && [[ "$version_before" == "$npm_version" ]]; then
		update_skip "$binary_name already at latest version ($version_before)"
		return 0
	fi

	# Run the installer
	local output
	output=$(eval "$install_cmd" 2>&1)
	local exit_code=$?

	if [ $exit_code -ne 0 ]; then
		update_fail "$binary_name" "$output"
		return 1
	fi

	# Get version after install
	local version_after
	version_after=$(eval "$version_cmd" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

	# Verify against npm version if available
	if [[ -n "$npm_version" ]] && [[ -n "$version_after" ]] && [[ "$version_after" != "$npm_version" ]]; then
		# Binary version doesn't match npm version - possible silent failure
		echo -e "${YELLOW}⚠ Warning: Binary version ($version_after) differs from npm version ($npm_version)${NC}"
		echo "$output" | grep -vE "^$|npm warn|\[?\[?" | head -20
		update_success "$binary_name ($version_before -> $version_after, but npm says $npm_version)"
		return 0
	fi

	# Compare versions
	if [[ "$version_before" != "$version_after" ]] && [[ -n "$version_after" ]]; then
		echo "$output" | grep -vE "^$|npm warn|\[?\[?" | head -20
		update_success "$binary_name ($version_before -> $version_after)"
	elif [[ -n "$version_before" ]]; then
		update_skip "$binary_name already at latest version ($version_before)"
	else
		# Couldn't determine versions, show output and mark as updated
		echo "$output" | grep -vE "^$|npm warn|\[?\[?" | head -20
		update_success "$binary_name"
	fi
}

# ============================================================================
# LOAD USER CONFIGURATION
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source config library if available
if [[ -f "$SCRIPT_DIR/lib/config.sh" ]]; then
	source "$SCRIPT_DIR/lib/config.sh"
	CONFIG_FILE="$HOME/.dotfiles.config.yaml"
	load_dotfiles_config "$CONFIG_FILE"
	# Get config values (only when library is available)
	CONFIG_CATEGORIES=$(get_config "categories" "$CONFIG_CATEGORIES")
	CONFIG_SKIP_PACKAGES=$(get_config "skip_packages" "$CONFIG_SKIP_PACKAGES")
else
	# Defaults if config library not available
	CONFIG_EDITOR="nvim"
	CONFIG_TERMINAL="wezterm"
	CONFIG_THEME="rose-pine"
	CONFIG_CATEGORIES="full"
	CONFIG_SKIP_PACKAGES=""
fi

# Check if a package should be skipped
should_skip_package() {
	local package="$1"
	# Parse skip_packages list (space or comma separated)
	local skip_list="$CONFIG_SKIP_PACKAGES"
	if [[ -n "$skip_list" ]]; then
		# Replace commas with spaces for consistency
		skip_list="${skip_list//, / }"
		for skip_pkg in $skip_list; do
			if [[ "$skip_pkg" == "$package" ]]; then
				return 0
			fi
		done
	fi
	return 1
}

# Counters
updated=0
skipped=0
failed=0

# Helpers
update_section() {
	echo -e "\n${CYAN}[$(date '+%H:%M:%S')]${NC} ${BLUE}$1${NC}"
}

update_success() {
	local msg="${1:-Done}"
	echo -e "${GREEN}✓ $msg${NC}"
	((updated++)) || true
}

update_skip() {
	echo -e "${YELLOW}⊘ Skipped: $1${NC}"
	((skipped++)) || true
}

update_fail() {
	local name="$1"
	local error_output="$2"
	echo -e "${YELLOW}✗ Failed: $name${NC}"
	if [[ -n "$error_output" ]]; then
		# Show last 10 lines of error output for debugging
		echo "$error_output" | tail -10 | sed 's/^/  /'
	fi
	((failed++)) || true
}

# ============================================================================
# ERROR HANDLING & TIMEOUTS
# ============================================================================

# Check if any package managers are available
check_prerequisites() {
	local has_manager=false

	echo -e "\n${CYAN}Checking prerequisites...${NC}"

	# Check for system package managers (skip on Windows even if WSL is available)
	if ! is_windows; then
		if cmd_exists apt || cmd_exists dnf || cmd_exists pacman || cmd_exists zypper; then
			has_manager=true
			echo -e "${GREEN}✓ System package manager found${NC}"
		fi
	fi

	# Check for language package managers
	if cmd_exists brew; then
		has_manager=true
		echo -e "${GREEN}✓ Homebrew found${NC}"
	fi

	if cmd_exists npm; then
		has_manager=true
		echo -e "${GREEN}✓ npm found${NC}"
	fi

	if cmd_exists pip || cmd_exists pip3; then
		has_manager=true
		echo -e "${GREEN}✓ pip found${NC}"
	fi

	if cmd_exists go; then
		has_manager=true
		echo -e "${GREEN}✓ Go found${NC}"
	fi

	if cmd_exists cargo; then
		has_manager=true
		echo -e "${GREEN}✓ Cargo found${NC}"
	fi

	if cmd_exists dotnet; then
		has_manager=true
		echo -e "${GREEN}✓ dotnet found${NC}"
	fi

	if [[ "$has_manager" == "false" ]]; then
		echo -e "\n${RED}Error: No package managers found!${NC}"
		echo -e "${YELLOW}Please install a package manager (apt, brew, npm, etc.)${NC}"
		return 1
	fi

	echo ""
}

# Run command with timeout
# Usage: run_with_timeout <timeout_seconds> <command>
run_with_timeout() {
	local timeout="${1:-300}" # Default 5 minutes
	local cmd="$2"
	local output

	if ! command -v timeout >/dev/null 2>&1; then
		# If timeout command not available, just run normally
		eval "$cmd"
		return $?
	fi

	output=$(timeout $timeout bash -c "$cmd" 2>&1)
	local exit_code=$?

	if [ $exit_code -eq 124 ]; then
		echo -e "${YELLOW}Command timed out after ${timeout}s${NC}"
		return 124
	fi

	echo "$output"
	return $exit_code
}

# Update helper: captures output, detects changes, reports appropriately
update_and_report() {
	local cmd="$1"
	local name="$2"
	local output
	local changes

	# Safety: On Windows, strip sudo from commands to prevent accidental elevation prompts
	# This is a defensive measure in case any Linux-only commands slip through guards
	if is_windows; then
		cmd="${cmd//sudo /}"
	fi

	output=$(eval "$cmd" 2>&1)
	local exit_code=$?

	if [ $exit_code -ne 0 ]; then
		update_fail "$name" "$output"
		return 1
	fi

	# Detect actual changes by looking for indicators and filtering out "already up to date" messages
	changes=$(echo "$output" | grep -iE "changed|removed|added|upgraded|updating|installed" | grep -viE "already|up to date|nothing|no outdated|not in" || true)

	if [ -n "$changes" ]; then
		# Show relevant output lines (filter out noisy parts)
		echo "$output" | grep -vE "^$|npm warn" | head -20
		update_success "$name"
	else
		update_success "$name (up to date)"
	fi

	return 0
}

# Update helper for pip (handles list and update loop)
update_pip() {
	local pip_cmd="$1"
	local name="$2"
	local output=""
	local changes=0

	# Upgrade pip first
	output+=$($pip_cmd install --upgrade pip 2>&1)
	output+=$'\n'

	# Update user packages only
	while IFS='=' read -r pkg _; do
		if [[ -n "$pkg" ]] && [[ ! "$pkg" =~ ^(pip|setuptools|wheel)$ ]]; then
			pkg_output=$($pip_cmd install --upgrade --user "$pkg" 2>&1)
			output+="$pkg_output"$'\n'
			# Check if package was actually upgraded
			if echo "$pkg_output" | grep -qiE "installed|upgraded"; then
				if ! echo "$pkg_output" | grep -qiE "already|up to date|not installed|not a satisfied|Requirement already"; then
					((changes++))
				fi
			fi
		fi
	done < <($pip_cmd list --user --format=freeze 2>/dev/null | grep -v '^(pip|setuptools|wheel)==')

	if [ $changes -gt 0 ]; then
		echo "$output" | grep -vE "^$|Requirement already" | head -20
		update_success "$name"
	else
		update_success "$name (up to date)"
	fi
}

# Update helper for dotnet tools (handles list and update loop)
update_dotnet_tools() {
	local output=""
	local changes=0

	while read -r tool; do
		if [ -n "$tool" ] && [ "$tool" != "Package" ]; then
			tool_output=$(dotnet tool update "$tool" 2>&1)
			output+="$tool_output"$'\n'
			# Check if tool was actually upgraded
			if echo "$tool_output" | grep -qiE "successfully|updated|installed"; then
				if ! echo "$tool_output" | grep -qiE "already|up to date"; then
					((changes++))
				fi
			fi
		fi
	done < <(dotnet tool list 2>/dev/null | tail -n +3 | awk '{print $1}')

	if [ $changes -gt 0 ]; then
		echo "$output" | grep -vE "^$|already up to date" | head -20
		update_success "dotnet"
	else
		update_success "dotnet (up to date)"
	fi
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================
_main() {
	OS=$(detect_os)

	# Check for available package managers
	echo ""
	echo -e "${CYAN}Checking package managers...${NC}"
	has_manager=false

	if [[ "$OS" == "linux" ]]; then
		if cmd_exists apt; then
			has_manager=true
			echo -e "${GREEN}✓ APT (Debian/Ubuntu)${NC}"
		else
			echo -e "${YELLOW}⊘ APT not found${NC}"
		fi

		if cmd_exists dnf; then
			has_manager=true
			echo -e "${GREEN}✓ DNF (Fedora)${NC}"
		else
			echo -e "${YELLOW}⊘ DNF not found${NC}"
		fi

		if cmd_exists pacman; then
			has_manager=true
			echo -e "${GREEN}✓ Pacman (Arch)${NC}"
		else
			echo -e "${YELLOW}⊘ Pacman not found${NC}"
		fi

		if cmd_exists zypper; then
			has_manager=true
			echo -e "${GREEN}✓ Zypper (openSUSE)${NC}"
		else
			echo -e "${YELLOW}⊘ Zypper not found${NC}"
		fi
	fi

	if cmd_exists brew; then
		has_manager=true
		echo -e "${GREEN}✓ Homebrew${NC}"
	else
		echo -e "${YELLOW}⊘ Homebrew not found${NC}"
	fi

	if cmd_exists snap; then
		has_manager=true
		echo -e "${GREEN}✓ Snap${NC}"
	else
		echo -e "${YELLOW}⊘ Snap not found${NC}"
	fi

	if cmd_exists flatpak; then
		has_manager=true
		echo -e "${GREEN}✓ Flatpak${NC}"
	else
		echo -e "${YELLOW}⊘ Flatpak not found${NC}"
	fi

	if cmd_exists npm; then
		has_manager=true
	else
		echo -e "${YELLOW}⊘ npm not found${NC}"
	fi

	if [[ "$has_manager" == "false" ]]; then
		echo -e "\n${RED}Error: No package managers found!${NC}"
		echo -e "${YELLOW}Please install a package manager (apt, brew, npm, etc.)${NC}"
		exit 1
	fi

	if cmd_exists pip || cmd_exists pip3; then
		has_manager=true
	else
		echo -e "${YELLOW}⊘ pip not found${NC}"
	fi

	if cmd_exists go; then
		has_manager=true
	else
		echo -e "${YELLOW}⊘ Go not found${NC}"
	fi

	if cmd_exists cargo; then
		has_manager=true
	else
		echo -e "${YELLOW}⊘ Cargo not found${NC}"
	fi

	if cmd_exists dotnet; then
		has_manager=true
	else
		echo -e "${YELLOW}⊘ dotnet not found${NC}"
	fi

	if cmd_exists spin; then
		has_manager=true
	else
		echo -e "${YELLOW}⊘ Spin not found${NC}"
	fi

	echo ""

	echo -e "${BLUE}========================================${NC}"
	echo -e "${BLUE}   Universal Update All - $OS${NC}"
	echo -e "${BLUE}========================================${NC}"

	start_time=$(date +%s)

	# Run prerequisite checks
	check_prerequisites

	# ============================================================================
	# APT (Debian/Ubuntu) - Skip on Windows (even if WSL is available)
	# ============================================================================
	if is_windows; then
		update_skip "apt (skipped on Windows)"
	elif cmd_exists apt; then
		update_section "APT (system packages)"
		update_and_report "sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y" "apt"
	else
		update_skip "apt not found"
	fi

	# ============================================================================
	# DNF (Fedora) - Skip on Windows
	# ============================================================================
	if is_windows; then
		update_skip "dnf (skipped on Windows)"
	elif cmd_exists dnf; then
		update_section "DNF (Fedora packages)"
		update_and_report "sudo dnf upgrade -y" "dnf"
	else
		update_skip "dnf not found"
	fi

	# ============================================================================
	# PACMAN (Arch Linux) - Skip on Windows
	# ============================================================================
	if is_windows; then
		update_skip "pacman (skipped on Windows)"
	elif cmd_exists pacman; then
		update_section "PACMAN (Arch packages)"
		update_and_report "sudo pacman -Syu --noconfirm" "pacman"
	else
		update_skip "pacman not found"
	fi

	# ============================================================================
	# ZYPPER (openSUSE) - Skip on Windows
	# ============================================================================
	if is_windows; then
		update_skip "zypper (skipped on Windows)"
	elif cmd_exists zypper; then
		update_section "ZYPPER (openSUSE packages)"
		update_and_report "sudo zypper dup -y" "zypper"
	else
		update_skip "zypper not found"
	fi

	# ============================================================================
	# HOMEBREW
	# ============================================================================
	if cmd_exists brew; then
		update_section "HOMEBREW"
		update_and_report "brew update && brew upgrade --greedy && brew cleanup --prune=all" "brew"
	else
		update_skip "brew not found"
	fi

	# ============================================================================
	# SNAP - Skip on Windows (requires sudo)
	# ============================================================================
	if is_windows; then
		update_skip "snap (skipped on Windows)"
	elif cmd_exists snap; then
		update_section "SNAP"
		update_and_report "sudo snap refresh" "snap"
	else
		update_skip "snap not found"
	fi

	# ============================================================================
	# FLATPAK
	# ============================================================================
	if cmd_exists flatpak; then
		update_section "FLATPAK"
		update_and_report "flatpak update -y && flatpak uninstall --unused -y" "flatpak"
	else
		update_skip "flatpak not found"
	fi

	# ============================================================================
	# NPM (Node.js global packages)
	# ============================================================================
	update_section "NPM (Node.js global packages)"

	# Skip if in skip list
	if should_skip_package "npm"; then
		update_skip "npm (in skip list)"
	else
	if cmd_exists npm; then
			# Clean up invalid npm packages (names starting with dot from failed installs)
			# These can't be removed via npm uninstall due to invalid names, must delete directly
			if is_windows; then
				# Multiple possible locations for npm global modules on Windows
				local npm_locations=(
					"$APPDATA/npm/node_modules"
					"$HOME/scoop/persist/nodejs-lts/bin/node_modules"
					"$HOME/scoop/apps/nodejs-lts/current/node_modules"
				)
				local total_invalid_count=0
				for npm_global_modules in "${npm_locations[@]}"; do
					if [[ -d "$npm_global_modules" ]]; then
						local invalid_count=0
						# Method 1: Use glob pattern (skip known valid dot dirs)
						for pkg_dir in "$npm_global_modules"/.*; do
							if [[ -d "$pkg_dir" ]]; then
								local pkg_name
								pkg_name=$(basename "$pkg_dir")
								# Skip valid dot directories
								[[ "$pkg_name" == "." || "$pkg_name" == ".." || "$pkg_name" == ".bin" || "$pkg_name" == ".github" || "$pkg_name" == ".modules.yaml" ]] && continue
								echo -e "  ${YELLOW}Removing invalid package: $pkg_name${NC}"
								rm -rf "$pkg_dir" 2>/dev/null || true
								((invalid_count++)) || true
							fi
						done
						# Method 2: Also try ls to catch any missed
						while IFS= read -r pkg_dir; do
							[[ -z "$pkg_dir" ]] && continue
							local pkg_name
							pkg_name=$(basename "$pkg_dir")
							[[ "$pkg_name" == .* ]]
							# Skip valid dot directories
							[[ "$pkg_name" == "." || "$pkg_name" == ".." || "$pkg_name" == ".bin" || "$pkg_name" == ".github" || "$pkg_name" == ".modules.yaml" ]] && continue
							echo -e "  ${YELLOW}Removing invalid package: $pkg_name${NC}"
							rm -rf "$pkg_dir" 2>/dev/null || true
							((invalid_count++)) || true
						done < <(ls -d "$npm_global_modules"/.* 2>/dev/null)
						((total_invalid_count += invalid_count)) || true
					fi
				done
				if [[ $total_invalid_count -gt 0 ]]; then
					echo -e "  ${GREEN}Removed $total_invalid_count invalid package(s)${NC}"
				fi
			else
				# Unix: try npm uninstall first, then manual cleanup
				local invalid_packages
				invalid_packages=$(npm list -g --depth=0 2>/dev/null | grep -oE '\.[a-zA-Z0-9_-]+' || true)
				if [[ -n "$invalid_packages" ]]; then
					echo -e "  ${YELLOW}Cleaning up invalid npm packages...${NC}"
					while IFS= read -r pkg; do
						[[ -z "$pkg" ]] && continue
						# Try npm uninstall first
						npm uninstall -g "$pkg" >/dev/null 2>&1 || true
						# If still exists, remove from filesystem
						local npm_global="${NPM_CONFIG_PREFIX:-$HOME/.npm-global}/lib/node_modules"
						if [[ -d "$npm_global/.$pkg" ]]; then
							rm -rf "$npm_global/.$pkg" 2>/dev/null || true
						fi
					done <<< "$invalid_packages"
				fi
			fi
			update_and_report "npm update -g" "npm"
		else
			update_skip "npm not found"
			((skipped++))
		fi
	fi

	# ============================================================================
	# YARN (global packages)
	# ============================================================================
	update_section "YARN (global packages)"

	if should_skip_package "yarn"; then
		update_skip "yarn (in skip list)"
		((skipped++))
	else
		if cmd_exists yarn; then
			update_and_report "yarn global upgrade" "yarn"
		else
			update_skip "yarn not found"
			((skipped++))
		fi
	fi

	# ============================================================================
	# PNPM
	# ============================================================================
	update_section "PNPM (global packages)"

	if should_skip_package "pnpm"; then
		update_skip "pnpm (in skip list)"
		((skipped++))
	else
		if cmd_exists pnpm; then
			update_and_report "pnpm update -g" "pnpm"
		else
			update_skip "pnpm not found"
			((skipped++))
		fi
	fi

	# ============================================================================
	# BUN (JavaScript runtime and package manager)
	# ============================================================================
	update_section "BUN"

	if should_skip_package "bun"; then
		update_skip "bun (in skip list)"
		((skipped++))
	else
		if cmd_exists bun; then
			# First upgrade bun itself
			bun_upgrade_output=$(bun upgrade 2>&1)
			bun_exit_code=$?

			# Check if there are global packages to update
			global_packages=$(bun pm ls -g 2>/dev/null | grep -cE "^\w" || true)

			if [[ $global_packages -gt 0 ]]; then
				# Only run bun update -g if there are global packages
				bun_update_output=$(bun update -g 2>&1)
				bun_update_exit_code=$?

				if [[ $bun_update_exit_code -eq 0 ]]; then
					update_success "bun"
				else
					# bun update -g can fail if no packages need updating
					if echo "$bun_update_output" | grep -qiE "No package.json|nothing to update|up to date"; then
						update_success "bun (up to date)"
					else
						update_fail "bun" "$bun_update_output"
					fi
				fi
			else
				# No global packages, just report bun upgrade status
				if [[ $bun_exit_code -eq 0 ]]; then
					update_success "bun"
				else
					update_fail "bun" "$bun_upgrade_output"
				fi
			fi
		else
			update_skip "bun not found"
			((skipped++))
		fi
	fi

	# ============================================================================
	# GUP (Go global packages)
	# ============================================================================
	if cmd_exists gup; then
		update_section "GUP (Go global packages)"
		update_and_report "gup update -a" "gup"
	else
		update_skip "gup not found"
	fi

	# ============================================================================
	# GO (direct update)
	# ============================================================================
	if cmd_exists go && ! cmd_exists gup; then
		update_section "GO (update all)"
		update_and_report "go install all@latest" "go"
	fi

	# ============================================================================
	# RUSTUP (Rust toolchain)
	# ============================================================================
	if cmd_exists rustup; then
		update_section "RUSTUP (Rust toolchain)"
		update_and_report "rustup update" "rustup"
	else
		update_skip "rustup not found"
	fi

	# ============================================================================
	# CARGO-UPDATE (install if missing)
	# ============================================================================
	if cmd_exists cargo && ! cmd_exists cargo-install-update; then
		update_section "CARGO-UPDATE (installing)"
		update_and_report "cargo install cargo-update" "cargo-update"
	fi

	# ============================================================================
	# CARGO (Rust packages)
	# ============================================================================
	if cmd_exists cargo; then
		update_section "CARGO (Rust packages)"
		if cmd_exists cargo-install-update; then
			update_and_report "cargo install-update -a" "cargo"
		else
			update_skip "cargo-install-update not found (install: cargo install cargo-update)"
		fi
	else
		update_skip "cargo not found"
	fi

	# ============================================================================
	# DOTNET TOOLS
	# ============================================================================
	if cmd_exists dotnet; then
		update_section "DOTNET TOOLS"
		update_dotnet_tools
	else
		update_skip "dotnet not found"
	fi

	# ============================================================================
	# PIP (Python packages)
	# ============================================================================
	if cmd_exists pip; then
		update_section "PIP (Python packages)"
		update_pip "pip" "pip"
	elif cmd_exists pip3; then
		update_section "PIP3 (Python packages)"
		update_pip "pip3" "pip3"
	else
		update_skip "pip/pip3 not found"
	fi

	# ============================================================================
	# POETRY (Python)
	# ============================================================================
	if cmd_exists poetry; then
		update_section "POETRY (Python packages)"
		update_and_report "poetry self update" "poetry"
	else
		update_skip "poetry not found"
	fi

	# ============================================================================
	# COMPOSER (PHP packages)
	# ============================================================================
	if cmd_exists composer; then
		update_section "COMPOSER (PHP global packages)"
		update_and_report "composer global update" "composer"
	else
		update_skip "composer not found"
	fi

	# ============================================================================
	# SPIN (Rust toolchain alternative)
	# ============================================================================
	if cmd_exists spin; then
		update_section "SPIN"
		update_and_report "spin upgrade" "spin"
	else
		update_skip "spin not found"
	fi

	# ============================================================================
	# CLAUDE CODE CLI
	# ============================================================================
	if cmd_exists claude; then
		update_section "CLAUDE CODE CLI"

		if is_windows; then
			# Use PowerShell installer on Windows (prefer pwsh/PowerShell 7+)
			local pwsh
			pwsh=$(get_pwsh)
			local install_cmd="$pwsh -NoProfile -Command \"irm https://claude.ai/install.ps1 | iex\""
			install_and_verify_version "$install_cmd" "claude-code" "claude --version" "@anthropic-ai/claude-code"
		else
			# Use bash script on Unix-like systems
			install_and_verify_version "curl -fsSL https://claude.ai/install.sh | bash" "claude-code" "claude --version" "@anthropic-ai/claude-code"
		fi
	else
		update_skip "claude-code not found"
	fi

	# ============================================================================
	# OPENCODE AI CLI
	# ============================================================================
	update_section "OPENCODE AI CLI"

	# Check binary directly (not via PATH) since it may not be in PATH yet
	local opencode_exe="$HOME/.opencode/bin/opencode"
	if [[ ! -f "$opencode_exe" ]]; then
		update_skip "opencode binary not found at $opencode_exe"
	else
		install_and_verify_version "curl -fsSL https://opencode.ai/install | bash" "opencode" "\"$opencode_exe\" --version" "opencode-ai"
	fi

	# ============================================================================
	# SUMMARY
	# ============================================================================
	end_time=$(date +%s)
	duration=$((end_time - start_time))
	minutes=$((duration / 60))
	seconds=$((duration % 60))

	echo -e "\n${BLUE}========================================${NC}"
	echo -e "${BLUE}           Summary${NC}"
	echo -e "${BLUE}========================================${NC}"
	echo -e " ${GREEN}Completed:${NC} $updated"
	echo -e " ${YELLOW}Skipped:${NC} $skipped"
	if [ $failed -gt 0 ]; then
		echo -e " ${YELLOW}Failed:${NC}   $failed"
	fi
	echo -e " ${CYAN}Duration:${NC} ${minutes}m ${seconds}s"
	echo -e "${BLUE}========================================${NC}"

	exit 0
}

# Only run main if script is executed (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	_main
fi
