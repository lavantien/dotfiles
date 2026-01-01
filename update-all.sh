#!/usr/bin/env bash
# Universal Update All Script - Linux/macOS
# Updates all package managers and tools

set -e

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
        Linux*)     echo "linux" ;;
        Darwin*)    echo "macos" ;;
        *)          echo "unknown" ;;
    esac
}

OS=$(detect_os)

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
    ((updated++))
}

update_skip() {
    echo -e "${YELLOW}⊘ Skipped: $1${NC}"
    ((skipped++))
}

update_fail() {
    echo -e "${YELLOW}✗ Failed: $1${NC}"
    ((failed++))
}

# Command exists checker
cmd_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Update helper: captures output, detects changes, reports appropriately
update_and_report() {
    local cmd="$1"
    local name="$2"
    local output
    local changes

    output=$(eval "$cmd" 2>&1)
    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        update_fail "$name"
        return
    fi

    # Detect actual changes by looking for indicators and filtering out "already up to date" messages
    changes=$(echo "$output" | grep -iE "changed|removed|added|upgraded|updating|installed" | grep -viE "already|up to date|nothing|no outdated|not in" || true)

    if [ -n "$changes" ]; then
        # Show relevant output lines (filter out noisy parts)
        echo "$output" | grep -vE "^$|npm warn" | head -20
        update_success "$name"
    else
        echo -e "${GREEN}✓ Up to date${NC}"
        ((updated++))
    fi
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
        echo -e "${GREEN}✓ Up to date${NC}"
        ((updated++))
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
        echo -e "${GREEN}✓ Up to date${NC}"
        ((updated++))
    fi
}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Universal Update All - $OS${NC}"
echo -e "${BLUE}========================================${NC}"

start_time=$(date +%s)

# ============================================================================
# APT (Debian/Ubuntu)
# ============================================================================
if cmd_exists apt; then
    update_section "APT (system packages)"
    update_and_report "sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y" "apt"
else
    update_skip "apt not found"
fi

# ============================================================================
# DNF (Fedora)
# ============================================================================
if cmd_exists dnf; then
    update_section "DNF (Fedora packages)"
    update_and_report "sudo dnf upgrade -y" "dnf"
else
    update_skip "dnf not found"
fi

# ============================================================================
# PACMAN (Arch Linux)
# ============================================================================
if cmd_exists pacman; then
    update_section "PACMAN (Arch packages)"
    update_and_report "sudo pacman -Syu --noconfirm" "pacman"
else
    update_skip "pacman not found"
fi

# ============================================================================
# ZYPPER (openSUSE)
# ============================================================================
if cmd_exists zypper; then
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
# SNAP
# ============================================================================
if cmd_exists snap; then
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
if cmd_exists npm; then
    update_section "NPM (Node.js global packages)"
    # Clean up invalid packages (names starting with dot from failed installs)
    if npm list -g --depth=0 2>/dev/null | grep -q '\.opencode-ai-'; then
        echo -e "${YELLOW}Cleaning up invalid npm packages...${NC}"
        # Extract and uninstall invalid packages
        npm list -g --depth=0 2>/dev/null | grep '\.opencode-ai-' | sed 's/^[+` ]*//' | while read -r pkg; do
            npm uninstall -g "$pkg" >/dev/null 2>&1 || true
        done
    fi
    update_and_report "npm update -g" "npm"
else
    update_skip "npm not found"
fi

# ============================================================================
# YARN (global packages)
# ============================================================================
if cmd_exists yarn; then
    update_section "YARN (global packages)"
    update_and_report "yarn global upgrade" "yarn"
else
    update_skip "yarn not found"
fi

# ============================================================================
# PNPM
# ============================================================================
if cmd_exists pnpm; then
    update_section "PNPM (global packages)"
    update_and_report "pnpm update -g" "pnpm"
else
    update_skip "pnpm not found"
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
# RUSTUP
# ============================================================================
if cmd_exists rustup; then
    update_section "RUSTUP (Rust toolchain)"
    update_and_report "rustup update" "rustup"
else
    update_skip "rustup not found"
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
# GEM (Ruby packages)
# ============================================================================
if cmd_exists gem; then
    update_section "RUBY GEM"
    update_and_report "gem update --user 2>&1 || gem update 2>&1" "gem"
else
    update_skip "gem not found"
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
# TLMGR (TeX Live)
# ============================================================================
if cmd_exists tlmgr; then
    update_section "TLmgr (TeX Live)"
    update_and_report "sudo tlmgr update --self && sudo tlmgr update --all" "tlmgr"
else
    update_skip "tlmgr not found"
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
