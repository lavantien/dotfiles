#!/usr/bin/env bash
# Common functions for bootstrap scripts
# Cross-platform utilities for logging, platform detection, and command execution

# ============================================================================
# COLORS
# ============================================================================
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    BOLD=''
    NC=''
fi

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

print_header() {
    echo -e "\n${BOLD}${BLUE}==== $1 ====${NC}\n"
}

print_section() {
    echo -e "\n${CYAN}$1${NC}"
}

# ============================================================================
# PROGRESS TRACKING
# ============================================================================
declare -a INSTALLED_PACKAGES=()
declare -a SKIPPED_PACKAGES=()
declare -a FAILED_PACKAGES=()

track_installed() {
    local name="$1"
    local desc="${2:-}"
    if [[ -n "$desc" ]]; then
        INSTALLED_PACKAGES+=("$name ($desc)")
    else
        INSTALLED_PACKAGES+=("$name")
    fi
}

track_skipped() {
    local name="$1"
    local desc="${2:-}"
    if [[ -n "$desc" ]]; then
        SKIPPED_PACKAGES+=("$name ($desc)")
    else
        SKIPPED_PACKAGES+=("$name")
    fi
}

track_failed() {
    local name="$1"
    local desc="${2:-}"
    if [[ -n "$desc" ]]; then
        FAILED_PACKAGES+=("$name ($desc)")
    else
        FAILED_PACKAGES+=("$name")
    fi
}

print_summary() {
    print_header "Bootstrap Summary"

    echo -e "${GREEN}Installed: ${#INSTALLED_PACKAGES[@]}${NC}"
    for pkg in "${INSTALLED_PACKAGES[@]}"; do
        echo "  - $pkg"
    done

    echo -e "\n${YELLOW}Skipped: ${#SKIPPED_PACKAGES[@]}${NC}"
    for pkg in "${SKIPPED_PACKAGES[@]}"; do
        echo "  - $pkg"
    done

    if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
        echo -e "\n${RED}Failed: ${#FAILED_PACKAGES[@]}${NC}"
        for pkg in "${FAILED_PACKAGES[@]}"; do
            echo "  - $pkg"
        done
    fi

    echo ""
}

# ============================================================================
# COMMAND EXISTENCE CHECK
# ============================================================================
cmd_exists() {
    # Standard check
    command -v "$1" >/dev/null 2>&1 && return 0

    # Additional checks for Windows (Git Bash/MSYS)
    # Check common user bin directories that might not be in PATH yet
    if [[ -n "$MSYSTEM" ]] || [[ "$(uname -s)" =~ (MINGW|MSYS|CYGWIN) ]]; then
        local cmd="$1"
        local home_bin="$HOME"
        local local_bins=(
            "$HOME/.cargo/bin"
            "$HOME/.local/bin"
            "$HOME/.dotnet/tools"
        )

        # Add version-specific Python Scripts directories (Python313/Scripts, etc.)
        if [[ -d "$APPDATA/Python" ]]; then
            for python_dir in "$APPDATA"/Python/Python*/Scripts; do
                # Expand glob and check if directory exists (handles case where glob doesn't match)
                [[ -d "$python_dir" ]] && local_bins+=("$python_dir")
            done
            # Also check generic Scripts directory
            [[ -d "$APPDATA/Python/Scripts" ]] && local_bins+=("$APPDATA/Python/Scripts")
        fi

        for bin_dir in "${local_bins[@]}"; do
            # Convert Windows paths if needed
            if [[ -d "$bin_dir" ]]; then
                if [[ -f "$bin_dir/$cmd" ]] || [[ -f "$bin_dir/$cmd.exe" ]]; then
                    return 0
                fi
            fi
        done
    fi

    return 1
}

# ============================================================================
# PLATFORM DETECTION
# ============================================================================
detect_os() {
    case "$(uname -s)" in
        Linux*)     echo "linux" ;;
        Darwin*)    echo "macos" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *)          echo "unknown" ;;
    esac
}

# Check if running on Windows (Git Bash/MSYS/MINGW/CYGWIN)
# Multiple checks for robustness across different environments
is_windows() {
    [[ -n "$MSYSTEM" ]] || [[ "$(uname -s)" =~ (MINGW|MSYS|CYGWIN) ]] || [[ -d "/mnt/c/Windows" ]]
}

# Check if we should use sudo (false on Windows, true on Linux/macOS for system packages)
should_use_sudo() {
    # Never use sudo on Windows (even if Windows sudo exists)
    if [[ -n "$MSYSTEM" ]] || [[ "$(uname -s)" =~ (MINGW|MSYS|CYGWIN) ]] || [[ -d "/mnt/c/Windows" ]]; then
        return 1
    fi
    return 0
}

detect_distro() {
    if [[ ! -f /etc/os-release ]]; then
        echo "unknown"
        return
    fi

    . /etc/os-release
    echo "$ID"
}

# Get distro family (debian/ubuntu, fedora, arch, opensuse)
get_distro_family() {
    local distro
    distro="$(detect_distro)"

    case "$distro" in
        ubuntu|debian|pop|linuxmint|elementary|kali)
            echo "debian"
            ;;
        fedora|rhel|centos|rocky|almalinux)
            echo "fedora"
            ;;
        arch|manjaro|endeavouros|garuda)
            echo "arch"
            ;;
        opensuse|suse|sles)
            echo "opensuse"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# ============================================================================
# CONFIRMATION PROMPT
# ============================================================================
# Usage: confirm "Prompt message" [default:y|n]
confirm() {
    if [[ "$INTERACTIVE" == "false" ]]; then
        return 0
    fi

    local prompt="$1"
    local default="${2:-n}"
    local options

    if [[ "$default" == "y" ]]; then
        options="Y/n"
    else
        options="y/N"
    fi

    while true; do
        read -p "$(echo -e ${YELLOW}?${NC} $prompt [$options]) " -n 1 -r reply
        echo
        reply=${reply:-$default}

        case $reply in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo "Please answer y or n." ;;
        esac
    done
}

# ============================================================================
# COMMAND EXECUTION WRAPPERS
# ============================================================================
run_cmd() {
    local cmd="$1"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would execute: $cmd"
        return 0
    fi

    eval "$cmd"
}

# Safe install wrapper - continues on failure
safe_install() {
    local install_func="$1"
    shift
    local args=("$@")
    local pkg_name="${args[0]}"

    if $install_func "${args[@]}"; then
        return 0
    else
        local exit_code=$?
        log_warning "Installation failed: $pkg_name (exit code $exit_code)"
        track_failed "$pkg_name"
        return 1
    fi
}

# ============================================================================
# PATH MANAGEMENT
# ============================================================================
# Add to PATH if not already present
ensure_path() {
    local new_path="$1"

    if [[ ":$PATH:" != *":$new_path:"* ]]; then
        export PATH="$new_path:$PATH"

        # Add to shell profile for persistence
        local profile=""
        if [[ -n "$SHELL" ]]; then
            case "$SHELL" in
                *zsh*) profile="$HOME/.zshrc" ;;
                *bash*) profile="$HOME/.bashrc" ;;
            esac
        fi

        if [[ -n "$profile" && -w "$profile" ]]; then
            echo "export PATH=\"$new_path:\$PATH\"" >> "$profile"
        fi
    fi
}

# Initialize user PATH with all common development tool directories
# This ensures tools installed via package managers are discoverable
init_user_path() {
    local paths_added=0
    local os
    os="$(detect_os)"

    log_step "Ensuring development directories are in PATH..."

    # Common user bin directories for development tools
    local cargo_bin="$HOME/.cargo/bin"
    local dotnet_tools="$HOME/.dotnet/tools"
    local local_bin="$HOME/.local/bin"
    local go_bin="$HOME/go/bin"

    # Platform-specific paths
    local platform_paths=()

    if [[ "$os" == "macos" ]]; then
        platform_paths+=("/opt/homebrew/bin")
        platform_paths+=("/usr/local/bin")
    elif [[ "$os" == "linux" ]]; then
        platform_paths+=("/home/linuxbrew/.linuxbrew/bin")
        platform_paths+=("$HOME/.linuxbrew/bin")
    elif [[ "$os" == "windows" ]]; then
        # Windows (Git Bash/MSYS) paths
        local localappdata_pnpm="$LOCALAPPDATA/pnpm"
        local appdata_npm="$APPDATA/npm"
        local scoop_shims="$HOME/scoop/shims"

        # Python Scripts - check version-specific directories first
        if [[ -d "$APPDATA/Python" ]]; then
            # Add all version-specific Python Scripts directories (Python313/Scripts, etc.)
            for python_dir in "$APPDATA"/Python/Python*/Scripts; do
                [[ -d "$python_dir" ]] && platform_paths+=("$python_dir")
            done
            # Also check generic Scripts directory
            [[ -d "$APPDATA/Python/Scripts" ]] && platform_paths+=("$APPDATA/Python/Scripts")
        fi

        [[ -d "$localappdata_pnpm" ]] && platform_paths+=("$localappdata_pnpm")
        [[ -d "$appdata_npm" ]] && platform_paths+=("$appdata_npm")
        [[ -d "$scoop_shims" ]] && platform_paths+=("$scoop_shims")
    fi

    # Add all paths that exist
    for path in "$cargo_bin" "$dotnet_tools" "$local_bin" "$go_bin" "${platform_paths[@]}"; do
        if [[ -d "$path" ]]; then
            ensure_path "$path"
            ((paths_added++)) || true
        fi
    done

    if [[ $paths_added -gt 0 ]]; then
        log_success "Added $paths_added director(y/ies) to PATH"
    else
        log_info "All development directories already in PATH"
    fi
}

# ============================================================================
# STATE MANAGEMENT
# ============================================================================
STATE_FILE="$HOME/.dotfiles-bootstrap-state"

save_state() {
    local tool="$1"
    local version="$2"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    echo "$tool|$version|$timestamp" >> "$STATE_FILE"
}

get_installed_state() {
    local tool="$1"

    if [[ -f "$STATE_FILE" ]]; then
        grep "^$tool|" "$STATE_FILE" | tail -1 | cut -d'|' -f2
    fi
}

# ============================================================================
# HELPERS
# ============================================================================
capitalize() {
    echo "$1" | sed 's/./\U&/'
}

join_by() {
    local d=$1
    shift
    echo -n "$1"
    shift
    printf "%s" "${@/#/$d}"
}
