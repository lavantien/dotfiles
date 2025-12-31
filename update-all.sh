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

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Universal Update All - $OS${NC}"
echo -e "${BLUE}========================================${NC}"

start_time=$(date +%s)

# ============================================================================
# APT (Debian/Ubuntu)
# ============================================================================
if cmd_exists apt; then
    update_section "APT (system packages)"
    if sudo apt update >/dev/null 2>&1; then
        sudo apt upgrade -y >/dev/null 2>&1
        sudo apt autoremove -y >/dev/null 2>&1
        update_success "apt"
    else
        update_fail "apt"
    fi
else
    update_skip "apt not found"
fi

# ============================================================================
# DNF (Fedora)
# ============================================================================
if cmd_exists dnf; then
    update_section "DNF (Fedora packages)"
    if sudo dnf upgrade -y >/dev/null 2>&1; then
        update_success "dnf"
    else
        update_fail "dnf"
    fi
else
    update_skip "dnf not found"
fi

# ============================================================================
# PACMAN (Arch Linux)
# ============================================================================
if cmd_exists pacman; then
    update_section "PACMAN (Arch packages)"
    if sudo pacman -Syu --noconfirm >/dev/null 2>&1; then
        update_success "pacman"
    else
        update_fail "pacman"
    fi
else
    update_skip "pacman not found"
fi

# ============================================================================
# ZYPPER (openSUSE)
# ============================================================================
if cmd_exists zypper; then
    update_section "ZYPPER (openSUSE packages)"
    if sudo zypper dup -y >/dev/null 2>&1; then
        update_success "zypper"
    else
        update_fail "zypper"
    fi
else
    update_skip "zypper not found"
fi

# ============================================================================
# HOMEBREW
# ============================================================================
if cmd_exists brew; then
    update_section "HOMEBREW"
    if brew update >/dev/null 2>&1 && brew upgrade --greedy >/dev/null 2>&1; then
        brew cleanup --prune=all >/dev/null 2>&1
        update_success "brew"
    else
        update_fail "brew"
    fi
else
    update_skip "brew not found"
fi

# ============================================================================
# SNAP
# ============================================================================
if cmd_exists snap; then
    update_section "SNAP"
    if sudo snap refresh >/dev/null 2>&1; then
        update_success "snap"
    else
        update_fail "snap"
    fi
else
    update_skip "snap not found"
fi

# ============================================================================
# FLATPAK
# ============================================================================
if cmd_exists flatpak; then
    update_section "FLATPAK"
    if flatpak update -y >/dev/null 2>&1; then
        flatpak uninstall --unused -y >/dev/null 2>&1
        update_success "flatpak"
    else
        update_fail "flatpak"
    fi
else
    update_skip "flatpak not found"
fi

# ============================================================================
# NPM (Node.js global packages)
# ============================================================================
if cmd_exists npm; then
    update_section "NPM (Node.js global packages)"
    if npm update -g >/dev/null 2>&1; then
        update_success "npm"
    else
        update_fail "npm"
    fi
else
    update_skip "npm not found"
fi

# ============================================================================
# YARN (global packages)
# ============================================================================
if cmd_exists yarn; then
    update_section "YARN (global packages)"
    if yarn global upgrade >/dev/null 2>&1; then
        update_success "yarn"
    else
        update_fail "yarn"
    fi
else
    update_skip "yarn not found"
fi

# ============================================================================
# PNPM
# ============================================================================
if cmd_exists pnpm; then
    update_section "PNPM (global packages)"
    if pnpm update -g >/dev/null 2>&1; then
        update_success "pnpm"
    else
        update_fail "pnpm"
    fi
else
    update_skip "pnpm not found"
fi

# ============================================================================
# GUP (Go global packages)
# ============================================================================
if cmd_exists gup; then
    update_section "GUP (Go global packages)"
    if gup update -a >/dev/null 2>&1; then
        update_success "gup"
    else
        update_fail "gup"
    fi
else
    update_skip "gup not found"
fi

# ============================================================================
# GO (direct update)
# ============================================================================
if cmd_exists go && ! cmd_exists gup; then
    update_section "GO (update all)"
    if go install all@latest >/dev/null 2>&1; then
        update_success "go"
    else
        update_fail "go"
    fi
fi

# ============================================================================
# CARGO (Rust packages)
# ============================================================================
if cmd_exists cargo; then
    update_section "CARGO (Rust packages)"
    if cmd_exists cargo-install-update; then
        if cargo install-update -a >/dev/null 2>&1; then
            update_success "cargo"
        else
            update_fail "cargo"
        fi
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
    if rustup update >/dev/null 2>&1; then
        update_success "rustup"
    else
        update_fail "rustup"
    fi
else
    update_skip "rustup not found"
fi

# ============================================================================
# DOTNET TOOLS
# ============================================================================
if cmd_exists dotnet; then
    update_section "DOTNET TOOLS"
    dotnet tool list 2>/dev/null | tail -n +3 | awk '{print $1}' | while read -r tool; do
        if [ -n "$tool" ] && [ "$tool" != "Package" ]; then
            dotnet tool update "$tool" >/dev/null 2>&1
        fi
    done
    update_success "dotnet"
else
    update_skip "dotnet not found"
fi

# ============================================================================
# PIP (Python packages)
# ============================================================================
if cmd_exists pip; then
    update_section "PIP (Python packages)"
    pip install --upgrade pip >/dev/null 2>&1
    # Update user packages only
    pip list --user --format=freeze 2>/dev/null | grep -v '^(pip|setuptools|wheel)==' | while read -r pkg; do
        if [[ "$pkg" == *"=="* ]]; then
            package_name="${pkg%%==*}"
            pip install --upgrade --user "$package_name" >/dev/null 2>&1
        fi
    done
    update_success "pip"
elif cmd_exists pip3; then
    update_section "PIP3 (Python packages)"
    pip3 install --upgrade pip >/dev/null 2>&1
    pip3 list --user --format=freeze 2>/dev/null | grep -v '^(pip|setuptools|wheel)==' | while read -r pkg; do
        if [[ "$pkg" == *"=="* ]]; then
            package_name="${pkg%%==*}"
            pip3 install --upgrade --user "$package_name" >/dev/null 2>&1
        fi
    done
    update_success "pip3"
else
    update_skip "pip/pip3 not found"
fi

# ============================================================================
# POETRY (Python)
# ============================================================================
if cmd_exists poetry; then
    update_section "POETRY (Python packages)"
    poetry self update >/dev/null 2>&1
    update_success "poetry"
else
    update_skip "poetry not found"
fi

# ============================================================================
# GEM (Ruby packages)
# ============================================================================
if cmd_exists gem; then
    update_section "RUBY GEM"
    gem update --user >/dev/null 2>&1 || gem update >/dev/null 2>&1
    update_success "gem"
else
    update_skip "gem not found"
fi

# ============================================================================
# COMPOSER (PHP packages)
# ============================================================================
if cmd_exists composer; then
    update_section "COMPOSER (PHP global packages)"
    composer global update >/dev/null 2>&1
    update_success "composer"
else
    update_skip "composer not found"
fi

# ============================================================================
# TLMGR (TeX Live)
# ============================================================================
if cmd_exists tlmgr; then
    update_section "TLmgr (TeX Live)"
    sudo tlmgr update --self >/dev/null 2>&1
    sudo tlmgr update --all >/dev/null 2>&1
    update_success "tlmgr"
else
    update_skip "tlmgr not found"
fi

# ============================================================================
# SPIN (Rust toolchain alternative)
# ============================================================================
if cmd_exists spin; then
    update_section "SPIN"
    spin upgrade >/dev/null 2>&1
    update_success "spin"
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
echo -e " ${GREEN}Updated:${NC} $updated"
echo -e " ${YELLOW}Skipped:${NC} $skipped"
if [ $failed -gt 0 ]; then
    echo -e " ${YELLOW}Failed:${NC}   $failed"
fi
echo -e " ${CYAN}Duration:${NC} ${minutes}m ${seconds}s"
echo -e "${BLUE}========================================${NC}"

exit 0
