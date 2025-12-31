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

track_installed() { INSTALLED_PACKAGES+=("$1"); }
track_skipped() { SKIPPED_PACKAGES+=("$1"); }
track_failed() { FAILED_PACKAGES+=("$1"); }

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
    command -v "$1" >/dev/null 2>&1
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
