#!/usr/bin/env bash
# Version checking utilities for bootstrap scripts
# Extracts versions from tool output and compares against minimum requirements

# Source common.sh first for cmd_exists
# shellcheck source=./common.sh

# ============================================================================
# VERSION PATTERNS
# ============================================================================
# macOS still ships bash 3.2, which has no associative arrays, so the former
# declare -gA tables are case-based lookups. Patterns are ERE strings consumed
# by [[ =~ ]] in get_version. The go pattern's non-capturing group was invalid
# ERE and never matched; it is a nested capturing group now, same capture.

# Echo the version-extraction pattern for a tool, or nothing when unknown.
get_version_pattern() {
	local tool="$1"
	case "$tool" in
	# Programming Languages
	node | nodejs | npm) echo 'v?([0-9]+\.[0-9]+\.[0-9]+)' ;;
	python | python3 | python3.*) echo 'Python ([0-9]+\.[0-9]+\.[0-9]+)' ;;
	go) echo 'go version go([0-9]+\.[0-9]+(\.[0-9]+)?)' ;;
	rustc) echo 'rustc ([0-9]+\.[0-9]+\.[0-9]+)' ;;
	cargo) echo 'cargo ([0-9]+\.[0-9]+\.[0-9]+)' ;;
	php) echo 'PHP ([0-9]+\.[0-9]+\.[0-9]+)' ;;
	dotnet) echo '([0-9]+\.[0-9]+\.[0-9]+)' ;;

		# Package Managers
	brew) echo 'Homebrew ([0-9]+\.[0-9]+\.[0-9]+)' ;;
	scoop) echo 'Current scoop version:[[:space:]]*v?([0-9]+\.[0-9]+\.[0-9]+)' ;;
	winget) echo 'v([0-9]+\.[0-9]+\.[0-9]+)' ;;
	apt | dnf) echo '([0-9]+\.[0-9]+\.[0-9]+)' ;;
	pacman) echo 'pacman v([0-9]+\.[0-9]+\.[0-9]+)' ;;
	zypper) echo 'zypper ([0-9]+\.[0-9]+\.[0-9]+)' ;;

		# CLI Tools
	fzf) echo '([0-9]+\.[0-9]+\.[0-9]+)' ;;
	bat) echo 'bat ([0-9]+\.[0-9]+\.[0-9]+)' ;;
	eza) echo 'eza ([0-9]+\.[0-9]+\.[0-9]+)' ;;
	exa) echo 'exa v?([0-9]+\.[0-9]+\.[0-9]+)' ;;
	lazygit) echo 'version,? ([0-9]+\.[0-9]+\.[0-9]+)' ;;
	lazygit.exe) echo 'version=([0-9]+\.[0-9]+\.[0-9]+)' ;;
	gh | gh.exe) echo 'gh version ([0-9]+\.[0-9]+\.[0-9]+)' ;;
	tokei) echo 'tokei ([0-9]+\.[0-9]+\.[0-9]+)' ;;
	zoxide) echo 'zoxide v([0-9]+\.[0-9]+\.[0-9]+)' ;;
	ripgrep | rg) echo 'ripgrep ([0-9]+\.[0-9]+\.[0-9]+)' ;;
	fd) echo 'fd ([0-9]+\.[0-9]+\.[0-9]+)' ;;
	difft | difftastic) echo 'difft ([0-9]+\.[0-9]+\.[0-9]+)' ;;

		# Language Servers
	gopls | gopls.exe) echo 'golang.org/x/tools/gopls v([0-9]+\.[0-9]+\.[0-9]+)' ;;
	rust-analyzer | rust_analyzer | rust-analyzer.exe) echo 'rust-analyzer ([0-9]+\.[0-9]+\.[0-9]+)' ;;
	pyright | pyright.exe) echo 'Pyright ([0-9]+\.[0-9]+\.[0-9]+)' ;;
	typescript-language-server | ts_ls) echo 'typescript-language-server version ([0-9]+\.[0-9]+\.[0-9]+)' ;;
	clangd) echo 'clangd version ([0-9]+\.[0-9]+\.[0-9]+)' ;;
	lua-language-server) echo 'Lua Language Server v?([0-9]+\.[0-9]+\.[0-9]+)' ;;
	lua_ls) echo '([0-9]+\.[0-9]+\.[0-9]+)' ;;
	jdtls) echo 'jdtls ([0-9]+\.[0-9]+)' ;;
	csharp-ls | csharp_ls) echo '([0-9]+\.[0-9]+\.[0-9]+)' ;;
	yaml-language-server) echo 'yaml-language-server version ([0-9]+\.[0-9]+\.[0-9]+)' ;;
	yamlls) echo '([0-9]+\.[0-9]+\.[0-9]+)' ;;
	docker-langserver) echo 'docker-langserver ([0-9]+\.[0-9]+\.[0-9]+)' ;;
	docker_ls) echo '([0-9]+\.[0-9]+\.[0-9]+)' ;;

		# Linters & Formatters
	scalafmt | scalafmt.exe) echo 'scalafmt ([0-9]+\.[0-9]+\.[0-9]+)' ;;
	prettier) echo '([0-9]+\.[0-9]+\.[0-9]+)' ;;
	eslint) echo 'v([0-9]+\.[0-9]+\.[0-9]+)' ;;
	ruff) echo 'ruff ([0-9]+\.[0-9]+\.[0-9]+)' ;;
	black) echo 'black, ([0-9]+\.[0-9]+\.[0-9]+)' ;;
	mypy | mypy.exe) echo 'mypy ([0-9]+\.[0-9]+\.[0-9]+)' ;;
	goimports) echo 'v?([0-9]+\.[0-9]+\.[0-9]+)' ;;
	golangci-lint) echo 'golangci-lint ([0-9]+\.[0-9]+\.[0-9]+)' ;;
	clang-format) echo 'clang-format version ([0-9]+\.[0-9]+\.[0-9]+)' ;;
	esac
}

# Echo the version flag for a tool; --version is the universal default.
get_version_flag() {
	case "$1" in
	go) echo "version" ;;
	*) echo "--version" ;;
	esac
}

# ============================================================================
# VERSION EXTRACTION
# ============================================================================

# Get installed version of a tool
# Returns: version string or empty if not found
get_version() {
	local tool="$1"
	local version_flag="${2:-}"

	# Check if tool exists
	if ! cmd_exists "$tool"; then
		return 1
	fi

	# Determine version flag
	if [[ -z "$version_flag" ]]; then
		version_flag="$(get_version_flag "$tool")"
	fi

	# Try to get version output
	local version_output
	version_output=$($tool "$version_flag" 2>&1) || return 1

	# Get version pattern for this tool
	local version_pattern
	version_pattern="$(get_version_pattern "$tool")"

	# Extract version using pattern if available
	if [[ -n "$version_pattern" ]]; then
		if [[ "$version_output" =~ $version_pattern ]]; then
			echo "${BASH_REMATCH[1]}"
			return 0
		fi
	fi

	# Fallback: try to extract first version-like string
	# Matches: 1.2.3, v1.2.3, 1.2, etc.
	if [[ "$version_output" =~ ([0-9]+\.[0-9]+\.?[0-9]*) ]]; then
		echo "${BASH_REMATCH[1]}"
		return 0
	fi

	return 1
}

# ============================================================================
# VERSION COMPARISON
# ============================================================================

# Compare semantic versions
# Returns: 0 = installed >= required, 1 = installed < required
compare_versions() {
	local installed="$1"
	local required="$2"

	# Clean version strings - remove 'v' prefix and prerelease suffixes
	installed="${installed#v}"
	installed="${installed%-*}"
	installed="${installed%+*}"
	required="${required#v}"
	required="${required%-*}"
	required="${required%+*}"

	# Handle date-based versions (e.g., 2023-01-01)
	if [[ "$installed" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
		if [[ "$required" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
			[[ "$installed" > "$required" ]] && return 0 || return 1
		fi
		# Date version vs semantic version - assume date is newer if recent
		return 0
	fi

	# Split into arrays
	IFS='.' read -ra INSTALLED_PARTS <<<"$installed"
	IFS='.' read -ra REQUIRED_PARTS <<<"$required"

	# Determine max length
	local max_parts=${#REQUIRED_PARTS[@]}
	if [[ ${#INSTALLED_PARTS[@]} -gt $max_parts ]]; then
		max_parts=${#INSTALLED_PARTS[@]}
	fi

	# Compare each part
	for ((i = 0; i < max_parts; i++)); do
		local inst_part="${INSTALLED_PARTS[$i]:-0}"
		local req_part="${REQUIRED_PARTS[$i]:-0}"

		# Handle non-numeric parts (like beta, alpha, rc)
		inst_part="${inst_part//[^0-9]/}"
		req_part="${req_part//[^0-9]/}"

		# Handle empty parts
		[[ -z "$inst_part" ]] && inst_part=0
		[[ -z "$req_part" ]] && req_part=0

		if ((inst_part < req_part)); then
			return 1 # Installed < Required
		elif ((inst_part > req_part)); then
			return 0 # Installed > Required
		fi
	done

	return 0 # Versions are equal
}

# ============================================================================
# INSTALLATION CHECKING
# ============================================================================

# Check if tool needs installation or update
# Returns: 0 = needs install, 1 = already satisfied
needs_install() {
	local tool="$1"
	local min_version="$2" # Unused - we just check existence

	# Check if tool exists
	# We don't check versions - just existence
	# This ensures we always get the latest installed version
	if ! cmd_exists "$tool"; then
		return 0 # Needs install
	fi

	# Tool exists, no need to reinstall
	return 1
}

# Check and report version status
# Returns: 0 = needs install, 1 = satisfied
check_and_report_version() {
	local tool="$1"
	local min_version="$2"
	local display_name="${3:-$tool}"

	if ! cmd_exists "$tool"; then
		log_info "$display_name: not installed"
		return 0
	fi

	local installed_version
	installed_version=$(get_version "$tool" 2>/dev/null) || {
		log_info "$display_name: installed"
		return 1
	}

	# Simplified: just report installed status without version comparison
	log_info "$display_name: installed (version $installed_version)"
	return 1
}

# ============================================================================
# BATCH CHECKING
# ============================================================================

# Check all tools in a category and return list of those needing install
get_missing_tools() {
	local -n tools_array=$1
	local min_versions_map="$2"
	local missing=()

	for tool in "${tools_array[@]}"; do
		local min_version="${!min_versions_map[$tool]:-}"
		if needs_install "$tool" "$min_version"; then
			missing+=("$tool")
		fi
	done

	echo "${missing[@]}"
}

# ============================================================================
# NPM PACKAGE VERSION CHECKING
# ============================================================================

# Check if an npm package needs install or update
# Returns: 0 = needs install/update, 1 = already at latest
npm_package_needs_update() {
	local package="$1"

	# Check if package is installed globally (top-level only)
	local installed
	installed=$(npm list -g --json --depth=0 "$package" 2>/dev/null)

	# If package not in dependencies, it's not installed
	if ! echo "$installed" | grep -q "\"$package\""; then
		return 0 # Not installed, needs install
	fi

	# Get current installed version (top-level only)
	local current_version
	current_version=$(echo "$installed" | grep -oE "\"$package\":\"[0-9]+\.[0-9]+\.[0-9]+" | cut -d'"' -f2 | cut -d':' -f2)

	# Get latest version from npm registry
	local latest_version
	latest_version=$(npm view "$package" version 2>/dev/null)

	# If we can't determine versions, assume current is fine
	if [[ -z "$current_version" ]] || [[ -z "$latest_version" ]]; then
		return 1 # Can't determine, assume up to date
	fi

	# Compare versions
	if [[ "$current_version" == "$latest_version" ]]; then
		return 1 # Up to date
	fi

	return 0 # Needs update
}
