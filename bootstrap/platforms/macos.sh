#!/usr/bin/env bash
# macOS-specific installation functions for bootstrap script

# Source parent libraries if not already loaded
# shellcheck source=../lib/common.sh
# shellcheck source=../lib/version-check.sh

# ============================================================================
# PACKAGE DESCRIPTIONS
# ============================================================================
get_package_description() {
    local pkg="$1"
    case "$pkg" in
        brew) echo "package manager" ;;
        git) echo "version control" ;;
        node) echo "Node.js runtime" ;;
        nodejs) echo "Node.js runtime" ;;
        python|python3) echo "Python runtime" ;;
        go|golang) echo "Go runtime" ;;
        rust) echo "Rust toolchain" ;;
        rust-analyzer) echo "Rust LSP" ;;
        dotnet-sdk) echo ".NET SDK" ;;
        openjdk|default-jdk) echo "Java development" ;;
        lua-language-server) echo "Lua LSP" ;;
        llvm) echo "C/C++ toolchain" ;;
        clangd) echo "C/C++ LSP" ;;
        gopls) echo "Go LSP" ;;
        pyright) echo "Python LSP" ;;
        typescript-language-server) echo "TypeScript LSP" ;;
        yaml-language-server) echo "YAML LSP" ;;
        csharp-ls) echo "C# LSP" ;;
        eclipse-jdt) echo "Java LSP" ;;
        intelephense) echo "PHP LSP" ;;
        dockerfile-language-server-nodejs) echo "Dockerfile LSP" ;;
        tombi) echo "TOML LSP" ;;
        tinymist) echo "Typst LSP" ;;
        prettier) echo "code formatter" ;;
        eslint) echo "JavaScript linter" ;;
        ruff) echo "Python linter" ;;
        black) echo "Python formatter" ;;
        isort) echo "Python import sorter" ;;
        mypy) echo "Python type checker" ;;
        gup) echo "Go package updater" ;;
        goimports) echo "Go import formatter" ;;
        golangci-lint) echo "Go linter" ;;
        clang-format) echo "C/C++ formatter" ;;
        shellcheck) echo "Shell script linter" ;;
        shfmt) echo "Shell script formatter" ;;
        scalafmt) echo "Scala formatter" ;;
        fzf) echo "fuzzy finder" ;;
        zoxide) echo "smart cd" ;;
        bat) echo "cat alternative" ;;
        eza|exa) echo "ls alternative" ;;
        lazygit) echo "Git TUI" ;;
        gh) echo "GitHub CLI" ;;
        tokei) echo "code stats" ;;
        ripgrep) echo "text search" ;;
        fd-find|fd) echo "find alternative" ;;
        difft) echo "diff viewer" ;;
        bats) echo "bash testing" ;;
        ruby) echo "Ruby runtime" ;;
        kcov) echo "code coverage" ;;
        vscode) echo "code editor" ;;
        latex) echo "document preparation" ;;
        claude-code) echo "AI CLI" ;;
        opencode) echo "AI CLI" ;;
        *) echo "" ;;
    esac
}

# ============================================================================
# GIT CONFIGURATION
# ============================================================================
# Configure git for proper line ending handling on macOS
configure_git_settings() {
    # On macOS, set core.autocrlf=false to prevent any line ending conversion
    # The .gitattributes file will handle enforcing LF for shell scripts
    local current_autocrlf
    current_autocrlf="$(git config --global core.autocrlf 2>/dev/null || echo "")"
    if [[ "$current_autocrlf" != "false" ]]; then
        log_step "Configuring git line endings (core.autocrlf=false)..."
        if [[ "$DRY_RUN" == "false" ]]; then
            git config --global core.autocrlf false
            log_info "Set core.autocrlf=false (no conversion on macOS)"
        else
            log_info "[DRY-RUN] Would run: git config --global core.autocrlf false"
        fi
    else
        track_skipped "git autocrlf already configured"
    fi

    # Add GitHub SSH key to known_hosts to prevent host key verification prompts
    local ssh_dir="$HOME/.ssh"
    local known_hosts="$ssh_dir/known_hosts"
    local needs_github_key=true

    if [[ -f "$known_hosts" ]]; then
        if grep -q "github\.com" "$known_hosts" 2>/dev/null; then
            needs_github_key=false
        fi
    fi

    if [[ "$needs_github_key" == "true" ]]; then
        log_step "Adding GitHub SSH key to known_hosts..."
        if [[ "$DRY_RUN" == "false" ]]; then
            mkdir -p "$ssh_dir"
            if command -v ssh-keyscan >/dev/null 2>&1; then
                ssh-keyscan github.com >> "$known_hosts" 2>/dev/null
                log_info "GitHub SSH key added to known_hosts"
            else
                log_info "ssh-keyscan not available, skipping known_hosts setup"
            fi
        else
            log_info "[DRY-RUN] Would add GitHub SSH key to $known_hosts"
        fi
    else
        track_skipped "GitHub SSH key already in known_hosts"
    fi
}

# ============================================================================
# HOMEBREW
# ============================================================================
ensure_homebrew() {
    if cmd_exists brew; then
        track_skipped "brew" "$(get_package_description brew)"
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
        track_installed "brew" "$(get_package_description brew)"
        return 0
    else
        track_failed "brew" "$(get_package_description brew)"
        return 1
    fi
}

install_brew_package() {
    local package="$1"
    local min_version="${2:-}"
    local check_cmd="${3:-$package}"

    if ! cmd_exists brew; then
        log_warning "Homebrew not installed, skipping $package"
        track_failed "$package" "$(get_package_description "$package")"
        return 1
    fi

    if needs_install "$check_cmd" "$min_version"; then
        log_step "Installing $package via brew..."
        if run_cmd "brew install $package"; then
            track_installed "$package" "$(get_package_description "$package")"
            return 0
        else
            track_failed "$package" "$(get_package_description "$package")"
            return 1
        fi
    else
        track_skipped "$check_cmd" "$(get_package_description "$check_cmd")"
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
            track_skipped "$pkg" "$(get_package_description "$pkg")"
        fi
    done

    if [[ ${#to_install[@]} -gt 0 ]]; then
        log_step "Installing ${#to_install[@]} packages via brew..."
        local pkg_list
        pkg_list="$(IFS=' '; echo "${to_install[*]}")"
        if run_cmd "brew install $pkg_list"; then
            for pkg in "${to_install[@]}"; do
                track_installed "$pkg" "$(get_package_description "$pkg")"
            done
            return 0
        else
            for pkg in "${to_install[@]}"; do
                track_failed "$pkg" "$(get_package_description "$pkg")"
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
        track_failed "$cask" "$(get_package_description "$cask")"
        return 1
    fi

    if needs_install "$check_cmd" "$min_version"; then
        log_step "Installing $cask via brew cask..."
        if run_cmd "brew install --cask $cask"; then
            track_installed "$cask" "$(get_package_description "$cask")"
            return 0
        else
            track_failed "$cask" "$(get_package_description "$cask")"
            return 1
        fi
    else
        track_skipped "$check_cmd" "$(get_package_description "$check_cmd")"
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
        track_failed "$package" "$(get_package_description "$cmd_name")"
        return 1
    fi

    if needs_install "$cmd_name" "$min_version"; then
        log_step "Installing $package via npm..."
        if run_cmd "npm install -g $package"; then
            track_installed "$package" "$(get_package_description "$cmd_name")"
            return 0
        else
            track_failed "$package" "$(get_package_description "$cmd_name")"
            return 1
        fi
    else
        track_skipped "$cmd_name" "$(get_package_description "$cmd_name")"
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
        track_failed "$package" "$(get_package_description "$cmd_name")"
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
        track_skipped "$cmd_name" "$(get_package_description "$cmd_name")"
        return 0
    fi

    # Try using gup if available
    if cmd_exists gup; then
        log_step "Installing $package via gup..."
        if run_cmd "gup install $package"; then
            track_installed "$package" "$(get_package_description "$cmd_name")"
            return 0
        else
            log_warning "gup install failed, falling back to go install..."
        fi
    fi

    # Fallback to go install
    log_step "Installing $package via go..."
    if run_cmd "go install $package@latest"; then
        track_installed "$package" "$(get_package_description "$cmd_name")"
        return 0
    else
        track_failed "$package" "$(get_package_description "$cmd_name")"
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
        track_failed "$package" "$(get_package_description "$cmd_name")"
        return 1
    fi

    if needs_install "$cmd_name" "$min_version"; then
        log_step "Installing $package via cargo..."
        if run_cmd "cargo install $package"; then
            ensure_path "$HOME/.cargo/bin"
            track_installed "$package" "$(get_package_description "$cmd_name")"
            return 0
        else
            track_failed "$package" "$(get_package_description "$cmd_name")"
            return 1
        fi
    else
        track_skipped "$cmd_name" "$(get_package_description "$cmd_name")"
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
        track_failed "$package" "$(get_package_description "$cmd_name")"
        return 1
    fi

    if needs_install "$cmd_name" "$min_version"; then
        log_step "Installing $package via pip..."
        if run_cmd "$python_cmd -m pip install --user --upgrade $package"; then
            track_installed "$package" "$(get_package_description "$cmd_name")"
            return 0
        else
            track_failed "$package" "$(get_package_description "$cmd_name")"
            return 1
        fi
    else
        track_skipped "$cmd_name" "$(get_package_description "$cmd_name")"
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
        track_failed "$package" "$(get_package_description "$cmd_name")"
        return 1
    fi

    if needs_install "$cmd_name" "$min_version"; then
        log_step "Installing $package via dotnet..."
        if run_cmd "dotnet tool install --global $package"; then
            ensure_path "$HOME/.dotnet/tools"
            track_installed "$package" "$(get_package_description "$cmd_name")"
            return 0
        else
            # Try update if install failed
            if run_cmd "dotnet tool update --global $package"; then
                track_installed "$package" "$(get_package_description "$cmd_name")"
                return 0
            else
                track_failed "$package" "$(get_package_description "$cmd_name")"
                return 1
            fi
        fi
    else
        track_skipped "$cmd_name" "$(get_package_description "$cmd_name")"
        return 0
    fi
}

# ============================================================================
# RUSTUP
# ============================================================================
install_rustup() {
    if cmd_exists rustup; then
        track_skipped "rust" "$(get_package_description rust)"
        return 0
    fi

    log_step "Installing Rust via rustup..."
    if run_cmd "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"; then
        # shellcheck disable=SC1091
        [[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
        ensure_path "$HOME/.cargo/bin"
        track_installed "rust" "$(get_package_description rust)"
        return 0
    else
        track_failed "rust" "$(get_package_description rust)"
        return 1
    fi
}

install_rust_analyzer_component() {
    if ! cmd_exists rustup; then
        log_warning "rustup not found, skipping rust-analyzer"
        track_failed "rust-analyzer" "$(get_package_description rust-analyzer)"
        return 1
    fi

    if needs_install rust-analyzer ""; then
        log_step "Adding rust-analyzer component..."
        if run_cmd "rustup component add rust-analyzer"; then
            track_installed "rust-analyzer" "$(get_package_description rust-analyzer)"
            return 0
        else
            track_failed "rust-analyzer" "$(get_package_description rust-analyzer)"
            return 1
        fi
    else
        track_skipped "rust-analyzer" "$(get_package_description rust-analyzer)"
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
            track_installed "$package" "$(get_package_description "$package")"
            return 0
        else
            track_failed "$package" "$(get_package_description "$package")"
            return 1
        fi
    else
        track_skipped "$check_cmd" "$(get_package_description "$check_cmd")"
        return 0
    fi
}
