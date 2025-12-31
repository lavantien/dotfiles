#!/usr/bin/env bash
# macOS-specific installation functions for bootstrap script

# Source parent libraries if not already loaded
# shellcheck source=../lib/common.sh
# shellcheck source=../lib/version-check.sh

# ============================================================================
# HOMEBREW
# ============================================================================
ensure_homebrew() {
    if cmd_exists brew; then
        track_skipped "brew"
        return 0
    fi

    log_step "Installing Homebrew..."
    if run_cmd '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'; then
        # Add Homebrew to PATH (Apple Silicon vs Intel)
        if [[ -d "/opt/homebrew/bin" ]]; then
            ensure_path "/opt/homebrew/bin"
        elif [[ -d "/usr/local/bin" ]]; then
            ensure_path "/usr/local/bin"
        fi
        track_installed "brew"
        return 0
    else
        track_failed "brew"
        return 1
    fi
}

install_brew_package() {
    local package="$1"
    local min_version="${2:-}"
    local check_cmd="${3:-$package}"

    if ! cmd_exists brew; then
        log_warning "Homebrew not installed, skipping $package"
        track_failed "$package"
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

# Install multiple brew packages at once (faster)
install_brew_packages() {
    local packages=("$@")
    local to_install=()

    for pkg in "${packages[@]}"; do
        if needs_install "$pkg" ""; then
            to_install+=("$pkg")
        else
            track_skipped "$pkg"
        fi
    done

    if [[ ${#to_install[@]} -gt 0 ]]; then
        log_step "Installing ${#to_install[@]} packages via brew..."
        local pkg_list
        pkg_list="$(IFS=' '; echo "${to_install[*]}")"
        if run_cmd "brew install $pkg_list"; then
            for pkg in "${to_install[@]}"; do
                track_installed "$pkg"
            done
            return 0
        else
            for pkg in "${to_install[@]}"; do
                track_failed "$pkg"
            done
            return 1
        fi
    fi

    return 0
}

# ============================================================================
# CASK (Homebrew Cask for GUI apps)
# ============================================================================
install_brew_cask() {
    local cask="$1"
    local check_cmd="${2:-}"
    local min_version="${3:-}"

    if [[ -z "$check_cmd" ]]; then
        # Use cask name for checking, convert to lowercase
        check_cmd="${cask,,}"
    fi

    if ! cmd_exists brew; then
        log_warning "Homebrew not installed, skipping $cask"
        track_failed "$cask"
        return 1
    fi

    if needs_install "$check_cmd" "$min_version"; then
        log_step "Installing $cask via brew cask..."
        if run_cmd "brew install --cask $cask"; then
            track_installed "$cask"
            return 0
        else
            track_failed "$cask"
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

    if needs_install "$cmd_name" "$min_version"; then
        log_step "Installing $package via go..."
        if run_cmd "go install $package@latest"; then
            local gopath
            gopath="$(go env GOPATH)"
            if [[ -n "$gopath" && ":$PATH:" != *":$gopath/bin:"* ]]; then
                ensure_path "$gopath/bin"
            fi
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
            ensure_path "$HOME/.dotnet/tools"
            track_installed "$package"
            return 0
        else
            # Try update if install failed
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
# MACPORTS (Alternative to Homebrew)
# ============================================================================
install_macports_package() {
    local package="$1"
    local min_version="${2:-}"
    local check_cmd="${3:-$package}"

    if ! cmd_exists port; then
        log_warning "MacPorts not installed, skipping $package"
        return 1
    fi

    if needs_install "$check_cmd" "$min_version"; then
        log_step "Installing $package via MacPorts..."
        if run_cmd "sudo port install $package"; then
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
