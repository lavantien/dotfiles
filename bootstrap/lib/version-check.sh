#!/usr/bin/env bash
# Version checking utilities for bootstrap scripts
# Extracts versions from tool output and compares against minimum requirements

# Source common.sh first for cmd_exists
# shellcheck source=./common.sh

# ============================================================================
# VERSION PATTERNS
# ============================================================================
# Regex patterns to extract version numbers from tool output
declare -gA VERSION_PATTERNS=(
    # Programming Languages
    ["node"]="v?([0-9]+\.[0-9]+\.[0-9]+)"
    ["nodejs"]="v?([0-9]+\.[0-9]+\.[0-9]+)"
    ["npm"]="v?([0-9]+\.[0-9]+\.[0-9]+)"
    ["python"]="Python ([0-9]+\.[0-9]+\.[0-9]+)"
    ["python3"]="Python ([0-9]+\.[0-9]+\.[0-9]+)"
    ["python3\\.?[0-9]*"]="Python ([0-9]+\.[0-9]+\.[0-9]+)"
    ["go"]="go version go([0-9]+\.[0-9]+(?:\.[0-9]+)?)"
    ["rustc"]="rustc ([0-9]+\.[0-9]+\.[0-9]+)"
    ["cargo"]="cargo ([0-9]+\.[0-9]+\.[0-9]+)"
    ["ruby"]="ruby ([0-9]+\.[0-9]+\.[0-9]+)"
    ["php"]="PHP ([0-9]+\.[0-9]+\.[0-9]+)"
    ["dotnet"]="([0-9]+\.[0-9]+\.[0-9]+)"

    # Package Managers
    ["brew"]="Homebrew ([0-9]+\.[0-9]+\.[0-9]+)"
    ["scoop"]="Current scoop version:[[:space:]]*v?([0-9]+\.[0-9]+\.[0-9]+)"
    ["winget"]="v([0-9]+\.[0-9]+\.[0-9]+)"
    ["apt"]="([0-9]+\.[0-9]+\.[0-9]+)"
    ["dnf"]="([0-9]+\.[0-9]+\.[0-9]+)"
    ["pacman"]="pacman v([0-9]+\.[0-9]+\.[0-9]+)"
    ["zypper"]="zypper ([0-9]+\.[0-9]+\.[0-9]+)"

    # CLI Tools
    ["fzf"]="([0-9]+\.[0-9]+\.[0-9]+)"
    ["bat"]="bat ([0-9]+\.[0-9]+\.[0-9]+)"
    ["eza"]="eza ([0-9]+\.[0-9]+\.[0-9]+)"
    ["exa"]="exa v?([0-9]+\.[0-9]+\.[0-9]+)"
    ["lazygit"]="version,? ([0-9]+\.[0-9]+\.[0-9]+)"
    ["lazygit\\.exe"]="version=([0-9]+\.[0-9]+\.[0-9]+)"
    ["gh"]="gh version ([0-9]+\.[0-9]+\.[0-9]+)"
    ["gh\\.exe"]="gh version ([0-9]+\.[0-9]+\.[0-9]+)"
    ["tokei"]="tokei ([0-9]+\.[0-9]+\.[0-9]+)"
    ["zoxide"]="zoxide v([0-9]+\.[0-9]+\.[0-9]+)"
    ["ripgrep"]="ripgrep ([0-9]+\.[0-9]+\.[0-9]+)"
    ["rg"]="ripgrep ([0-9]+\.[0-9]+\.[0-9]+)"
    ["fd"]="fd ([0-9]+\.[0-9]+\.[0-9]+)"
    ["difft"]="difft ([0-9]+\.[0-9]+\.[0-9]+)"
    ["difftastic"]="difft ([0-9]+\.[0-9]+\.[0-9]+)"

    # Language Servers
    ["gopls"]="golang.org/x/tools/gopls v([0-9]+\.[0-9]+\.[0-9]+)"
    ["gopls\\.exe"]="golang.org/x/tools/gopls v([0-9]+\.[0-9]+\.[0-9]+)"
    ["rust-analyzer"]="rust-analyzer ([0-9]+\.[0-9]+\.[0-9]+)"
    ["rust_analyzer"]="rust-analyzer ([0-9]+\.[0-9]+\.[0-9]+)"
    ["rust-analyzer\\.exe"]="rust-analyzer ([0-9]+\.[0-9]+\.[0-9]+)"
    ["pyright"]="Pyright ([0-9]+\.[0-9]+\.[0-9]+)"
    ["pyright\\.exe"]="Pyright ([0-9]+\.[0-9]+\.[0-9]+)"
    ["typescript-language-server"]="typescript-language-server version ([0-9]+\.[0-9]+\.[0-9]+)"
    ["ts_ls"]="typescript-language-server version ([0-9]+\.[0-9]+\.[0-9]+)"
    ["clangd"]="clangd version ([0-9]+\.[0-9]+\.[0-9]+)"
    ["lua-language-server"]="Lua Language Server v?([0-9]+\.[0-9]+\.[0-9]+)"
    ["lua_ls"]="([0-9]+\.[0-9]+\.[0-9]+)"
    ["jdtls"]="jdtls ([0-9]+\.[0-9]+)"
    ["csharp-ls"]="([0-9]+\.[0-9]+\.[0-9]+)"
    ["csharp_ls"]="([0-9]+\.[0-9]+\.[0-9]+)"
    ["yaml-language-server"]="yaml-language-server version ([0-9]+\.[0-9]+\.[0-9]+)"
    ["yamlls"]="([0-9]+\.[0-9]+\.[0-9]+)"
    ["docker-langserver"]="docker-langserver ([0-9]+\.[0-9]+\.[0-9]+)"
    ["docker_ls"]="([0-9]+\.[0-9]+\.[0-9]+)"

    # Linters & Formatters
    ["scalafmt"]="scalafmt ([0-9]+\.[0-9]+\.[0-9]+)"
    ["scalafmt.exe"]="scalafmt ([0-9]+\.[0-9]+\.[0-9]+)"
    ["prettier"]="([0-9]+\.[0-9]+\.[0-9]+)"
    ["eslint"]="v([0-9]+\.[0-9]+\.[0-9]+)"
    ["ruff"]="ruff ([0-9]+\.[0-9]+\.[0-9]+)"
    ["black"]="black, ([0-9]+\.[0-9]+\.[0-9]+)"
    ["mypy"]="mypy ([0-9]+\.[0-9]+\.[0-9]+)"
    ["mypy.exe"]="mypy ([0-9]+\.[0-9]+\.[0-9]+)"
    ["goimports"]="v?([0-9]+\.[0-9]+\.[0-9]+)"
    ["golangci-lint"]="golangci-lint ([0-9]+\.[0-9]+\.[0-9]+)"
    ["clang-format"]="clang-format version ([0-9]+\.[0-9]+\.[0-9]+)"
)

# Version flags for tools that don't use --version
declare -gA VERSION_FLAGS=(
    ["go"]="version"
    ["cargo"]="--version"
    ["scoop"]="--version"
)

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
        version_flag="${VERSION_FLAGS[$tool]:---version}"
    fi

    # Try to get version output
    local version_output
    version_output=$($tool "$version_flag" 2>&1) || return 1

    # Get version pattern for this tool
    local version_pattern="${VERSION_PATTERNS[$tool]}"

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
    IFS='.' read -ra INSTALLED_PARTS <<< "$installed"
    IFS='.' read -ra REQUIRED_PARTS <<< "$required"

    # Determine max length
    local max_parts=${#REQUIRED_PARTS[@]}
    if [[ ${#INSTALLED_PARTS[@]} -gt $max_parts ]]; then
        max_parts=${#INSTALLED_PARTS[@]}
    fi

    # Compare each part
    for ((i=0; i<max_parts; i++)); do
        local inst_part="${INSTALLED_PARTS[$i]:-0}"
        local req_part="${REQUIRED_PARTS[$i]:-0}"

        # Handle non-numeric parts (like beta, alpha, rc)
        inst_part="${inst_part//[^0-9]/}"
        req_part="${req_part//[^0-9]/}"

        # Handle empty parts
        [[ -z "$inst_part" ]] && inst_part=0
        [[ -z "$req_part" ]] && req_part=0

        if ((inst_part < req_part)); then
            return 1  # Installed < Required
        elif ((inst_part > req_part)); then
            return 0  # Installed > Required
        fi
    done

    return 0  # Versions are equal
}

# ============================================================================
# INSTALLATION CHECKING
# ============================================================================

# Check if tool needs installation or update
# Returns: 0 = needs install, 1 = already satisfied
needs_install() {
    local tool="$1"
    local min_version="$2"  # Unused - we just check existence

    # Check if tool exists
    # We don't check versions - just existence
    # This ensures we always get the latest installed version
    if ! cmd_exists "$tool"; then
        return 0  # Needs install
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
