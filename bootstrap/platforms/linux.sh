#!/usr/bin/env bash
# Linux-specific installation functions for bootstrap script
# Supports: Debian/Ubuntu, Fedora/RHEL, Arch Linux, openSUSE

# Source parent libraries if not already loaded
# shellcheck source=../lib/common.sh
# shellcheck source=../lib/version-check.sh

# ============================================================================
# APT (Debian/Ubuntu)
# ============================================================================
install_apt_package() {
    local package="$1"
    local min_version="${2:-}"
    local check_cmd="${3:-$package}"

    if needs_install "$check_cmd" "$min_version"; then
        log_step "Installing $package via apt..."
        if [[ "$DRY_RUN" == "false" ]]; then
            sudo apt update >/dev/null 2>&1 || true
            if run_cmd "sudo apt install -y $package"; then
                track_installed "$package"
                return 0
            else
                track_failed "$package"
                return 1
            fi
        else
            track_installed "$package"
            return 0
        fi
    else
        track_skipped "$check_cmd"
        return 0
    fi
}

# ============================================================================
# DNF (Fedora/RHEL)
# ============================================================================
install_dnf_package() {
    local package="$1"
    local min_version="${2:-}"
    local check_cmd="${3:-$package}"

    if needs_install "$check_cmd" "$min_version"; then
        log_step "Installing $package via dnf..."
        if run_cmd "sudo dnf install -y $package"; then
            track_installed "$package"
            return 0
        else
            track_failed "$package"
            return 1
        fi
    else
        track_skipped "$check_cmd"
        return 0
    fi
}

# ============================================================================
# PACMAN (Arch Linux)
# ============================================================================
install_pacman_package() {
    local package="$1"
    local min_version="${2:-}"
    local check_cmd="${3:-$package}"

    if needs_install "$check_cmd" "$min_version"; then
        log_step "Installing $package via pacman..."
        if run_cmd "sudo pacman -S --noconfirm $package"; then
            track_installed "$package"
            return 0
        else
            track_failed "$package"
            return 1
        fi
    else
        track_skipped "$check_cmd"
        return 0
    fi
}

# ============================================================================
# ZYPPER (openSUSE)
# ============================================================================
install_zypper_package() {
    local package="$1"
    local min_version="${2:-}"
    local check_cmd="${3:-$package}"

    if needs_install "$check_cmd" "$min_version"; then
        log_step "Installing $package via zypper..."
        if run_cmd "sudo zypper install -y $package"; then
            track_installed "$package"
            return 0
        else
            track_failed "$package"
            return 1
        fi
    else
        track_skipped "$check_cmd"
        return 0
    fi
}

# ============================================================================
# DISTRO-Agnostic Package Installer
# ============================================================================
install_linux_package() {
    local package="$1"
    local min_version="${2:-}"
    local check_cmd="${3:-$package}"
    local distro_family
    distro_family="$(get_distro_family)"

    case "$distro_family" in
        debian)
            install_apt_package "$package" "$min_version" "$check_cmd"
            ;;
        fedora)
            install_dnf_package "$package" "$min_version" "$check_cmd"
            ;;
        arch)
            install_pacman_package "$package" "$min_version" "$check_cmd"
            ;;
        opensuse)
            install_zypper_package "$package" "$min_version" "$check_cmd"
            ;;
        *)
            log_warning "Unknown distro family: $distro_family"
            track_failed "$package"
            return 1
            ;;
    esac
}

# ============================================================================
# FLATPAK
# ============================================================================
install_flatpak_app() {
    local app_id="$1"
    local check_cmd="${2:-}"
    local display_name="${3:-$app_id}"

    if [[ -z "$check_cmd" ]]; then
        # Extract app name from app_id for checking
        check_cmd="${app_id##*.}"
    fi

    # Check if flatpak is available
    if ! cmd_exists flatpak; then
        log_info "flatpak not installed, skipping $display_name"
        return 1
    fi

    if needs_install "$check_cmd" ""; then
        log_step "Installing $display_name via flatpak..."
        if run_cmd "flatpak install -y --noninteractive flathub $app_id"; then
            track_installed "$display_name"
            return 0
        else
            track_failed "$display_name"
            return 1
        fi
    else
        track_skipped "$check_cmd"
        return 0
    fi
}

# ============================================================================
# SNAP
# ============================================================================
install_snap_app() {
    local app_name="$1"
    local check_cmd="${2:-$app_name}"

    # Check if snap is available
    if ! cmd_exists snap; then
        log_info "snap not installed, skipping $app_name"
        return 1
    fi

    if needs_install "$check_cmd" ""; then
        log_step "Installing $app_name via snap..."
        if run_cmd "sudo snap install $app_name --classic"; then
            track_installed "$app_name"
            return 0
        else
            track_failed "$app_name"
            return 1
        fi
    else
        track_skipped "$check_cmd"
        return 0
    fi
}

# ============================================================================
# Language Package Managers
# ============================================================================

# Install via npm global
install_npm_global() {
    local package="$1"
    local cmd_name="${2:-}"
    local min_version="${3:-}"

    if [[ -z "$cmd_name" ]]; then
        # Extract command name from package
        cmd_name="${package##*/}"
        cmd_name="${cmd_name#@}"
    fi

    if ! cmd_exists npm; then
        log_warning "npm not found, skipping $package"
        track_failed "$package"
        return 1
    fi

    if needs_install "$cmd_name" "$min_version"; then
        log_step "Installing $package via npm..."
        if run_cmd "npm install -g $package"; then
            track_installed "$package"
            return 0
        else
            track_failed "$package"
            return 1
        fi
    else
        track_skipped "$cmd_name"
        return 0
    fi
}

# Install via go install
install_go_package() {
    local package="$1"
    local cmd_name="${2:-}"
    local min_version="${3:-}"

    if [[ -z "$cmd_name" ]]; then
        cmd_name="${package##*/}"
    fi

    if ! cmd_exists go; then
        log_warning "go not found, skipping $package"
        track_failed "$package"
        return 1
    fi

    # Get GOPATH and ensure it's in PATH (for current shell + persist)
    local gopath
    gopath="$(go env GOPATH)"
    if [[ -n "$gopath" ]]; then
        # Persist to shell profile for future sessions
        ensure_path "$gopath/bin"
        # Also add to current PATH so we can find commands immediately
        if [[ ":$PATH:" != *":$gopath/bin:"* ]]; then
            export PATH="$gopath/bin:$PATH"
        fi
    fi

    # Check if already installed (after ensuring GOPATH/bin in PATH)
    if cmd_exists "$cmd_name"; then
        track_skipped "$cmd_name (already installed)"
        return 0
    fi

    # Try using gup if available
    if cmd_exists gup; then
        log_step "Installing $package via gup..."
        if run_cmd "gup install $package"; then
            track_installed "$package"
            return 0
        else
            log_warning "gup install failed, falling back to go install..."
        fi
    fi

    # Fallback to go install
    log_step "Installing $package via go..."
    if run_cmd "go install $package@latest"; then
        track_installed "$package"
        return 0
    else
        track_failed "$package"
        return 1
    fi
}

# Install via cargo
install_cargo_package() {
    local package="$1"
    local cmd_name="${2:-$package}"
    local min_version="${3:-}"

    if ! cmd_exists cargo; then
        log_warning "cargo not found, skipping $package"
        track_failed "$package"
        return 1
    fi

    if needs_install "$cmd_name" "$min_version"; then
        log_step "Installing $package via cargo..."
        if run_cmd "cargo install $package"; then
            # Add cargo bin to PATH if needed
            ensure_path "$HOME/.cargo/bin"
            track_installed "$package"
            return 0
        else
            track_failed "$package"
            return 1
        fi
    else
        track_skipped "$cmd_name"
        return 0
    fi
}

# Install via pip
install_pip_global() {
    local package="$1"
    local cmd_name="${2:-$package}"
    local min_version="${3:-}"

    # Find python3 or python
    local python_cmd=""
    if cmd_exists python3; then
        python_cmd="python3"
    elif cmd_exists python; then
        python_cmd="python"
    else
        log_warning "Python not found, skipping $package"
        track_failed "$package"
        return 1
    fi

    if needs_install "$cmd_name" "$min_version"; then
        log_step "Installing $package via pip..."
        if run_cmd "$python_cmd -m pip install --user --upgrade $package"; then
            track_installed "$package"
            return 0
        else
            track_failed "$package"
            return 1
        fi
    else
        track_skipped "$cmd_name"
        return 0
    fi
}

# Install via dotnet tool
install_dotnet_tool() {
    local package="$1"
    local cmd_name="${2:-$package}"
    local min_version="${3:-}"

    if ! cmd_exists dotnet; then
        log_warning "dotnet not found, skipping $package"
        track_failed "$package"
        return 1
    fi

    if needs_install "$cmd_name" "$min_version"; then
        log_step "Installing $package via dotnet..."
        if run_cmd "dotnet tool install --global $package"; then
            # Add dotnet tools path to PATH
            ensure_path "$HOME/.dotnet/tools"
            track_installed "$package"
            return 0
        else
            # Try update if install failed (might already be installed)
            if run_cmd "dotnet tool update --global $package"; then
                track_installed "$package"
                return 0
            else
                track_failed "$package"
                return 1
            fi
        fi
    else
        track_skipped "$cmd_name"
        return 0
    fi
}

# ============================================================================
# RUSTUP
# ============================================================================
install_rustup() {
    if cmd_exists rustup; then
        track_skipped "rust"
        return 0
    fi

    log_step "Installing Rust via rustup..."
    if run_cmd "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"; then
        # Source cargo environment
        # shellcheck disable=SC1091
        [[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
        ensure_path "$HOME/.cargo/bin"
        track_installed "rust"
        return 0
    else
        track_failed "rust"
        return 1
    fi
}

# Add rust-analyzer via rustup
install_rust_analyzer_component() {
    if ! cmd_exists rustup; then
        log_warning "rustup not found, skipping rust-analyzer"
        track_failed "rust-analyzer"
        return 1
    fi

    if needs_install rust-analyzer ""; then
        log_step "Adding rust-analyzer component..."
        if run_cmd "rustup component add rust-analyzer"; then
            track_installed "rust-analyzer"
            return 0
        else
            track_failed "rust-analyzer"
            return 1
        fi
    else
        track_skipped "rust-analyzer"
        return 0
    fi
}

# ============================================================================
# HOMEWORK (Linux Homebrew)
# ============================================================================
ensure_homebrew() {
    if cmd_exists brew; then
        track_skipped "brew"
        return 0
    fi

    log_step "Installing Homebrew for Linux..."
    if run_cmd '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'; then
        # Add Homebrew to PATH for Linux
        if [[ -d "/home/linuxbrew/.linuxbrew/bin" ]]; then
            ensure_path "/home/linuxbrew/.linuxbrew/bin"
        elif [[ -d "$HOME/.linuxbrew/bin" ]]; then
            ensure_path "$HOME/.linuxbrew/bin"
        fi
        track_installed "brew"
        return 0
    else
        track_failed "brew"
        return 1
    fi
}

# Install via brew (available on Linux)
install_brew_package() {
    local package="$1"
    local min_version="${2:-}"
    local check_cmd="${3:-$package}"

    if ! cmd_exists brew; then
        log_warning "Homebrew not installed, skipping $package"
        return 1
    fi

    if needs_install "$check_cmd" "$min_version"; then
        log_step "Installing $package via brew..."
        if run_cmd "brew install $package"; then
            track_installed "$package"
            return 0
        else
            track_failed "$package"
            return 1
        fi
    else
        track_skipped "$check_cmd"
        return 0
    fi
}
