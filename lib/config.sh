#!/usr/bin/env bash
# Configuration parser for dotfiles
# Supports simple YAML key-value pairs
# For complex YAML, install yq: https://github.com/mikefarah/yq

# ============================================================================
# LOAD CONFIG FILE
# ============================================================================

# Global config variables (will be populated from config file)
CONFIG_EDITOR=""
CONFIG_TERMINAL=""
CONFIG_THEME=""
CONFIG_CATEGORIES="full"
CONFIG_AUTO_UPDATE_REPOS="false"
CONFIG_BACKUP_BEFORE_DEPLOY="false"
CONFIG_SIGN_COMMITS="false"
CONFIG_DEFAULT_BRANCH="main"
CONFIG_GITHUB_USERNAME=""
CONFIG_BASE_DIR=""
CONFIG_AUTO_COMMIT="false"
CONFIG_SKIP_PACKAGES=""

# Platform-specific
CONFIG_LINUX_PACKAGE_MANAGER=""
CONFIG_LINUX_DISPLAY_SERVER=""
CONFIG_WINDOWS_PACKAGE_MANAGER=""
CONFIG_MACOS_PACKAGE_MANAGER=""

# Load config from file if it exists
# Usage: load_dotfiles_config [config_file_path]
load_dotfiles_config() {
    local config_file="${1:-$HOME/.dotfiles.config.yaml}"

    # If config file doesn't exist, use defaults
    if [[ ! -f "$config_file" ]]; then
        return 0
    fi

    # Try to use yq if available (best parsing)
    if command -v yq >/dev/null 2>&1; then
        _parse_config_with_yq "$config_file"
    else
        # Fallback to simple parsing
        _parse_config_simple "$config_file"
    fi
}

# Parse config using yq (recommended)
_parse_config_with_yq() {
    local config_file="$1"

    CONFIG_EDITOR=$(yq eval '.editor // ""' "$config_file")
    CONFIG_TERMINAL=$(yq eval '.terminal // ""' "$config_file")
    CONFIG_THEME=$(yq eval '.theme // ""' "$config_file")
    CONFIG_CATEGORIES=$(yq eval '.categories // "full"' "$config_file")
    CONFIG_AUTO_UPDATE_REPOS=$(yq eval '.auto_update_repos // "false"' "$config_file")
    CONFIG_BACKUP_BEFORE_DEPLOY=$(yq eval '.backup_before_deploy // "false"' "$config_file")
    CONFIG_SIGN_COMMITS=$(yq eval '.sign_commits // "false"' "$config_file")
    CONFIG_DEFAULT_BRANCH=$(yq eval '.default_branch // "main"' "$config_file")
    CONFIG_GITHUB_USERNAME=$(yq eval '.github_username // ""' "$config_file")
    CONFIG_BASE_DIR=$(yq eval '.base_dir // ""' "$config_file")
    CONFIG_AUTO_COMMIT=$(yq eval '.auto_commit_changes // "false"' "$config_file")

    # Parse skip_packages as space-separated string
    local skip_list=$(yq eval '.skip_packages // []' "$config_file")
    CONFIG_SKIP_PACKAGES=$(echo "$skip_list" | grep -oP '"\K[^"]+' | tr '\n' ' ' | sed 's/ $//')

    # Platform-specific settings
    CONFIG_LINUX_PACKAGE_MANAGER=$(yq eval '.linux.package_manager // "auto"' "$config_file")
    CONFIG_LINUX_DISPLAY_SERVER=$(yq eval '.linux.display_server // ""' "$config_file")
    CONFIG_WINDOWS_PACKAGE_MANAGER=$(yq eval '.windows.package_manager // "scoop"' "$config_file")
    CONFIG_MACOS_PACKAGE_MANAGER=$(yq eval '.macos.package_manager // "brew"' "$config_file")
}

# Simple YAML parser fallback (handles basic key: value pairs)
_parse_config_simple() {
    local config_file="$1"
    local current_section=""

    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$line" ]] && continue

        # Detect sections (indented keys under a parent)
        if [[ "$line" =~ ^[[:space:]]*[a-z_]+:[[:space:]]*$ ]]; then
            current_section=$(echo "$line" | sed 's/[[:space:]]*//; s/://')
            continue
        fi

        # Parse key: value pairs (only non-nested)
        if [[ "$line" =~ ^[[:space:]]*([a-z_]+):[[:space:]]*(.+)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"

            # Remove quotes and comments from value
            value=$(echo "$value" | sed 's/["'"'"']//g; s/[[:space:]]*#.*$//')

            # Assign to appropriate config variable
            case "$key" in
                editor) CONFIG_EDITOR="$value" ;;
                terminal) CONFIG_TERMINAL="$value" ;;
                theme) CONFIG_THEME="$value" ;;
                categories) CONFIG_CATEGORIES="$value" ;;
                auto_update_repos) CONFIG_AUTO_UPDATE_REPOS="$value" ;;
                backup_before_deploy) CONFIG_BACKUP_BEFORE_DEPLOY="$value" ;;
                sign_commits) CONFIG_SIGN_COMMITS="$value" ;;
                default_branch) CONFIG_DEFAULT_BRANCH="$value" ;;
                github_username) CONFIG_GITHUB_USERNAME="$value" ;;
                base_dir) CONFIG_BASE_DIR="$value" ;;
                auto_commit_changes) CONFIG_AUTO_COMMIT="$value" ;;
                package_manager)
                    case "$current_section" in
                        linux) CONFIG_LINUX_PACKAGE_MANAGER="$value" ;;
                        windows) CONFIG_WINDOWS_PACKAGE_MANAGER="$value" ;;
                        macos) CONFIG_MACOS_PACKAGE_MANAGER="$value" ;;
                    esac
                    ;;
                display_server) CONFIG_LINUX_DISPLAY_SERVER="$value" ;;
            esac
        fi
    done < "$config_file"
}

# ============================================================================
# CONFIG GETTERS
# ============================================================================

get_config() {
    local key="$1"
    local default="${2:-}"

    case "$key" in
        editor) echo "${CONFIG_EDITOR:-$default}" ;;
        terminal) echo "${CONFIG_TERMINAL:-$default}" ;;
        theme) echo "${CONFIG_THEME:-$default}" ;;
        categories) echo "${CONFIG_CATEGORIES:-$default}" ;;
        auto_update_repos) echo "${CONFIG_AUTO_UPDATE_REPOS:-$default}" ;;
        backup_before_deploy) echo "${CONFIG_BACKUP_BEFORE_DEPLOY:-$default}" ;;
        sign_commits) echo "${CONFIG_SIGN_COMMITS:-$default}" ;;
        default_branch) echo "${CONFIG_DEFAULT_BRANCH:-$default}" ;;
        github_username) echo "${CONFIG_GITHUB_USERNAME:-$default}" ;;
        base_dir) echo "${CONFIG_BASE_DIR:-$default}" ;;
        auto_commit_changes) echo "${CONFIG_AUTO_COMMIT:-$default}" ;;
        linux_package_manager) echo "${CONFIG_LINUX_PACKAGE_MANAGER:-$default}" ;;
        windows_package_manager) echo "${CONFIG_WINDOWS_PACKAGE_MANAGER:-$default}" ;;
        macos_package_manager) echo "${CONFIG_MACOS_PACKAGE_MANAGER:-$default}" ;;
        *) echo "$default" ;;
    esac
}

# Check if a package should be skipped
# Usage: should_skip_package <package_name>
should_skip_package() {
    local package="$1"

    if [[ -z "$CONFIG_SKIP_PACKAGES" ]]; then
        return 1
    fi

    for skip in $CONFIG_SKIP_PACKAGES; do
        if [[ "$skip" == "$package" ]]; then
            return 0
        fi
    done

    return 1
}
