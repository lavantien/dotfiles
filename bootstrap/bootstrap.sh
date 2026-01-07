#!/usr/bin/env bash
# Universal Bootstrap Script
# Installs and configures development environment on Linux/macOS
#
# VERSION POLICY:
#   All packages are installed or updated to their LATEST versions
#   No hardcoded version numbers - always gets the newest stable release
#   Run bootstrap again to update all tools to latest versions
#
# BRIDGE APPROACH:
#   - Works without config file (uses hardcoded defaults - backward compatible)
#   - Loads config file if present (~/.dotfiles.config.yaml) - forward compatible
#   - Config library is optional - scripts work even if it's missing
#   - Defaults: categories="full", interactive=true, no dry-run
#
# Usage:
#   ./bootstrap.sh [options]
#
# Options:
#   -y, --yes        Non-interactive mode (accept all prompts)
#   --dry-run        Show what would be installed without installing
#   --categories     minimal|sdk|full (default: full)
#   --skip-update    Skip updating package managers first
#   -h, --help       Show this help

set -e

# ============================================================================
# SCRIPT SETUP
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
PLATFORMS_DIR="$SCRIPT_DIR/platforms"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source library functions
# shellcheck source=lib/common.sh
source "$LIB_DIR/common.sh"
# shellcheck source=lib/version-check.sh
source "$LIB_DIR/version-check.sh"
# shellcheck source=lib/config.sh
# Config library is at root level, not in bootstrap/lib/
if [[ -f "$ROOT_DIR/lib/config.sh" ]]; then
    source "$ROOT_DIR/lib/config.sh"
fi

# Source platform-specific functions
OS="$(detect_os)"

if [[ "$OS" == "linux" ]]; then
    # shellcheck source=platforms/linux.sh
    source "$PLATFORMS_DIR/linux.sh"
elif [[ "$OS" == "macos" ]]; then
    # shellcheck source=platforms/macos.sh
    source "$PLATFORMS_DIR/macos.sh"
fi

# ============================================================================
# DEFAULTS
# ============================================================================
INTERACTIVE=true
DRY_RUN=false
CATEGORIES="full"
SKIP_UPDATE=false
AUTO_UPDATE_REPOS="false"
BACKUP_BEFORE_DEPLOY="false"

# ============================================================================
# LOAD USER CONFIGURATION (OPTIONAL)
# ============================================================================
CONFIG_FILE="$HOME/.dotfiles.config.yaml"

# Only try to load config if the config library was successfully sourced
if declare -f load_dotfiles_config >/dev/null 2>&1; then
    if [[ -f "$CONFIG_FILE" ]]; then
        load_dotfiles_config "$CONFIG_FILE" 2>/dev/null || {
            log_warning "Failed to load config file, using defaults"
        }
    fi

    # Override defaults with config values (if get_config function exists)
    if declare -f get_config >/dev/null 2>&1; then
        CATEGORIES=$(get_config "categories" "$CATEGORIES")
        AUTO_UPDATE_REPOS=$(get_config "auto_update_repos" "$AUTO_UPDATE_REPOS")
        BACKUP_BEFORE_DEPLOY=$(get_config "backup_before_deploy" "$BACKUP_BEFORE_DEPLOY")
    fi
else
    log_info "Config library not found, using hardcoded defaults"
fi

# ============================================================================
# HELP
# ============================================================================
show_help() {
    grep '^#' "$SCRIPT_DIR/bootstrap.sh" | grep -v '#!/usr/bin/env' | sed 's/^# //' | sed 's/^#//'
}

# ============================================================================
# PARSE ARGUMENTS
# ============================================================================
while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--yes)
            INTERACTIVE=false
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --categories)
            CATEGORIES="$2"
            shift 2
            ;;
        --skip-update)
            SKIP_UPDATE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# ============================================================================
# PHASE 1: FOUNDATION
# ============================================================================
install_foundation() {
    print_header "Phase 1: Foundation"

    # Ensure package manager is installed
    if [[ "$OS" == "macos" ]]; then
        ensure_homebrew || return 1
    elif [[ "$OS" == "linux" ]]; then
        # Optionally install Homebrew on Linux
        if confirm "Install Homebrew on Linux? (recommended for consistency)" "n"; then
            ensure_homebrew
        fi
    fi

    # Ensure git is installed
    if ! cmd_exists git; then
        log_step "Installing git..."
        if [[ "$OS" == "macos" ]]; then
            install_brew_package git
        elif [[ "$OS" == "linux" ]]; then
            install_linux_package git
        fi
    else
        log_info "git already installed"
    fi

    # Configure git and add GitHub to known_hosts (platform-specific function)
    configure_git_settings

    log_success "Foundation complete"
    return 0
}

# ============================================================================
# PHASE 2: CORE SDKS
# ============================================================================
install_sdks() {
    print_header "Phase 2: Core SDKs"

    # Node.js (always latest LTS)
    if [[ "$CATEGORIES" != "minimal" ]]; then
        if [[ "$OS" == "macos" ]]; then
            install_brew_package node "" ""
        elif [[ "$OS" == "linux" ]]; then
            install_linux_package nodejs "" node
        fi
    fi

    # Python (always latest)
    if [[ "$OS" == "macos" ]]; then
        install_brew_package python "" python3
    elif [[ "$OS" == "linux" ]]; then
        install_linux_package python3 "" python3
    fi

    # Go (always latest)
    if [[ "$CATEGORIES" != "minimal" ]]; then
        if [[ "$OS" == "macos" ]]; then
            install_brew_package go "" ""
        elif [[ "$OS" == "linux" ]]; then
            install_linux_package golang "" go
        fi
    fi

    # Rust
    if [[ "$CATEGORIES" == "full" ]]; then
        install_rustup
    fi

    # dotnet SDK
    if [[ "$CATEGORIES" == "full" ]]; then
        if [[ "$OS" == "macos" ]]; then
            install_brew_package dotnet-sdk "" dotnet
        elif [[ "$OS" == "linux" ]]; then
            install_linux_package dotnet-sdk "" dotnet || true
        fi
    fi

    # OpenJDK
    if [[ "$CATEGORIES" == "full" ]]; then
        if [[ "$OS" == "macos" ]]; then
            install_brew_package openjdk "" javac
        elif [[ "$OS" == "linux" ]]; then
            install_linux_package default-jdk "" javac || true
        fi
    fi

    log_success "SDKs installation complete"
    return 0
}

# ============================================================================
# PHASE 3: LANGUAGE SERVERS
# ============================================================================
install_language_servers() {
    if [[ "$CATEGORIES" == "minimal" ]]; then
        return 0
    fi

    print_header "Phase 3: Language Servers"

    # lua_ls (via system package - always latest)
    if [[ "$OS" == "macos" ]]; then
        install_brew_package lua-language-server "" lua-language-server
    elif [[ "$OS" == "linux" ]]; then
        install_linux_package lua-language-server "" lua-language-server || true
    fi

    # clangd (via system package - always latest)
    if [[ "$OS" == "macos" ]]; then
        install_brew_package llvm "" clangd
    elif [[ "$OS" == "linux" ]]; then
        install_linux_package clangd "" clangd
    fi

    # gopls (via go install - always latest)
    if [[ "$CATEGORIES" == "full" ]] && cmd_exists go; then
        install_go_package "golang.org/x/tools/gopls@latest" gopls ""
    fi

    # rust-analyzer (via rustup)
    if [[ "$CATEGORIES" == "full" ]]; then
        install_rust_analyzer_component
    fi

    # pyright (via npm - always latest)
    if cmd_exists npm; then
        install_npm_global pyright pyright ""
    fi

    # TypeScript language server (via npm - always latest)
    if cmd_exists npm; then
        install_npm_global typescript-language-server typescript-language-server ""
    fi

    # HTML language server (via npm - always latest)
    if cmd_exists npm; then
        install_npm_global "vscode-html-languageserver-bin" "vscode-html-language-server" ""
    fi

    # CSS language server (via npm - always latest)
    if cmd_exists npm; then
        install_npm_global "vscode-css-languageserver-bin" "vscode-css-language-server" ""
    fi

    # Svelte language server (via npm - always latest)
    if [[ "$CATEGORIES" == "full" ]] && cmd_exists npm; then
        install_npm_global "svelte-language-server" "svelte-language-server" ""
    fi

    # bash-language-server (via npm - always latest)
    if cmd_exists npm; then
        install_npm_global "bash-language-server" "bash-language-server" ""
    fi

    # YAML language server (via npm - always latest)
    if cmd_exists npm; then
        install_npm_global yaml-language-server yaml-language-server ""
    fi

    # csharp-ls (via dotnet tool)
    if [[ "$CATEGORIES" == "full" ]] && cmd_exists dotnet; then
        install_dotnet_tool "csharp-ls" "csharp-ls" ""
    fi

    # jdtls (Java Language Server)
    if [[ "$CATEGORIES" == "full" ]]; then
        if [[ "$OS" == "macos" ]]; then
            install_brew_package eclipse-jdt "" jdtls || true
        elif [[ "$OS" == "linux" ]]; then
            install_linux_package eclipse-jdt "" jdtls || true
        fi
    fi

    # intelephense (PHP language server via npm)
    if [[ "$CATEGORIES" == "full" ]] && cmd_exists npm; then
        install_npm_global "intelephense" "intelephense" ""
    fi

    # Docker language servers (via npm - always latest)
    if cmd_exists npm; then
        # dockerfile-language-server (binary: docker-langserver)
        install_npm_global "dockerfile-language-server-nodejs" "docker-langserver" ""
        # Note: @microsoft/compose-language-service has no binary, skip
    fi

    # tombi (TOML language server via npm - always latest)
    if cmd_exists npm; then
        install_npm_global "tombi" "tombi" ""
    fi

    # dartls (Dart language server - requires Dart SDK)
    # Note: Dart SDK must be installed separately from https://dart.dev/get-dart
    # This is optional and not installed by default

    # tinymist (Typst language server via npm - always latest)
    if [[ "$CATEGORIES" == "full" ]] && cmd_exists npm; then
        install_npm_global "tinymist" "tinymist" ""
    fi

    log_success "Language servers installation complete"
    return 0
}

# ============================================================================
# PHASE 4: LINTERS & FORMATTERS
# ============================================================================
install_linters_formatters() {
    if [[ "$CATEGORIES" == "minimal" ]]; then
        return 0
    fi

    print_header "Phase 4: Linters & Formatters"

    # Prettier (via npm - always latest)
    if cmd_exists npm; then
        install_npm_global prettier prettier ""
    fi

    # ESLint (via npm - always latest)
    if cmd_exists npm; then
        install_npm_global eslint eslint ""
    fi

    # Stylelint (CSS/SCSS linter via npm - always latest)
    if cmd_exists npm; then
        install_npm_global stylelint stylelint ""
    fi

    # svelte-check (Svelte type checker via npm - always latest)
    if [[ "$CATEGORIES" == "full" ]] && cmd_exists npm; then
        install_npm_global "svelte-check" "svelte-check" ""
    fi

    # repomix (Pack repositories for AI exploration via npm - always latest)
    if [[ "$CATEGORIES" == "full" ]] && cmd_exists npm; then
        install_npm_global "repomix" "repomix" ""
    fi

    # Ruff (via pip - always latest)
    if cmd_exists python3 || cmd_exists python; then
        install_pip_global "ruff" ruff ""
    fi

    # Additional Python tools (for full compatibility with git hooks - always latest)
    if [[ "$CATEGORIES" == "full" ]]; then
        if cmd_exists python3 || cmd_exists python; then
            install_pip_global "black" black "" || true
            install_pip_global "isort" isort "" || true
            install_pip_global "mypy" mypy "" || true
            install_pip_global "pytest" pytest "" || true
        fi
    fi

    # gup (Go package manager - always latest)
    if cmd_exists go && ! cmd_exists gup; then
        install_go_package "nao.vi/gup@latest" gup ""
    fi

    # goimports (via gup if available, otherwise go install - always latest)
    if cmd_exists go; then
        install_go_package "golang.org/x/tools/cmd/goimports@latest" goimports ""
    fi

    # golangci-lint (always latest)
    if cmd_exists go; then
        if [[ "$OS" == "macos" ]]; then
            install_brew_package golangci-lint "" golangci-lint
        elif [[ "$OS" == "linux" ]]; then
            install_linux_package golangci-lint "" golangci-lint || \
                install_go_package "github.com/golangci/golangci-lint/cmd/golangci-lint@latest" golangci-lint ""
        fi
    fi

    # clang-format (usually comes with clangd - always latest)
    if ! cmd_exists clang-format; then
        if [[ "$OS" == "macos" ]]; then
            install_brew_package llvm "" clang-format
        elif [[ "$OS" == "linux" ]]; then
            install_linux_package clang-format "" clang-format
        fi
    fi

    # cppcheck (C++ static analysis - always latest)
    if [[ "$CATEGORIES" == "full" ]]; then
        if [[ "$OS" == "macos" ]]; then
            install_brew_package cppcheck "" cppcheck
        elif [[ "$OS" == "linux" ]]; then
            install_linux_package cppcheck "" cppcheck || true
        fi
    fi

    # catch2 (C++ testing framework)
    if [[ "$CATEGORIES" == "full" ]]; then
        if [[ "$OS" == "macos" ]]; then
            install_brew_package catch2 "" catch2
        elif [[ "$OS" == "linux" ]]; then
            install_linux_package catch2 "" catch2 || true
        fi
    fi

    # php (PHP runtime - prerequisite for composer)
    if [[ "$CATEGORIES" == "full" ]]; then
        if [[ "$OS" == "macos" ]]; then
            install_brew_package php "" php
        elif [[ "$OS" == "linux" ]]; then
            install_linux_package php "" php || true
        fi
    fi

    # composer (PHP package manager - prerequisite for PHP tools)
    if [[ "$CATEGORIES" == "full" ]]; then
        if [[ "$OS" == "macos" ]]; then
            install_brew_package composer "" composer
        elif [[ "$OS" == "linux" ]]; then
            if ! cmd_exists composer; then
                log_step "Installing composer..."
                if [[ "$DRY_RUN" == "true" ]]; then
                    log_info "[DRY-RUN] Would install composer"
                else
                    curl -sS https://getcomposer.org/installer | php >/dev/null 2>&1 && \
                        sudo mv composer.phar /usr/local/bin/composer 2>/dev/null || \
                        mv composer.phar "$HOME/.local/bin/composer" 2>/dev/null || true
                fi
            else
                log_info "composer already installed"
                track_skipped "composer" "PHP package manager"
            fi
        fi
    fi

    # Laravel Pint (PHP code style via composer global)
    if [[ "$CATEGORIES" == "full" ]] && cmd_exists composer; then
        if ! composer global show laravel/pint >/dev/null 2>&1; then
            log_step "Installing Laravel Pint..."
            if [[ "$DRY_RUN" == "true" ]]; then
                log_info "[DRY-RUN] Would composer global require laravel/pint"
            else
                composer global require laravel/pint >/dev/null 2>&1 && \
                    track_installed "pint" "PHP code style" || \
                    track_failed "pint" "PHP code style"
            fi
        else
            log_info "Laravel Pint already installed"
            track_skipped "pint" "PHP code style"
        fi
    fi

    # PHPStan (PHP static analysis via composer global)
    if [[ "$CATEGORIES" == "full" ]] && cmd_exists composer; then
        if ! composer global show phpstan/phpstan >/dev/null 2>&1; then
            log_step "Installing PHPStan..."
            if [[ "$DRY_RUN" == "true" ]]; then
                log_info "[DRY-RUN] Would composer global require phpstan/phpstan"
            else
                composer global require phpstan/phpstan >/dev/null 2>&1 && \
                    track_installed "phpstan" "PHP static analysis" || \
                    track_failed "phpstan" "PHP static analysis"
            fi
        else
            log_info "PHPStan already installed"
            track_skipped "phpstan" "PHP static analysis"
        fi
    fi

    # Psalm (PHP static analysis via composer global)
    if [[ "$CATEGORIES" == "full" ]] && cmd_exists composer; then
        if ! composer global show vimeo/psalm >/dev/null 2>&1; then
            log_step "Installing Psalm..."
            if [[ "$DRY_RUN" == "true" ]]; then
                log_info "[DRY-RUN] Would composer global require vimeo/psalm"
            else
                composer global require vimeo/psalm >/dev/null 2>&1 && \
                    track_installed "psalm" "PHP static analysis" || \
                    track_failed "psalm" "PHP static analysis"
            fi
        else
            log_info "Psalm already installed"
            track_skipped "psalm" "PHP static analysis"
        fi
    fi

    # Shell tools
    if [[ "$CATEGORIES" == "full" ]]; then
        if [[ "$OS" == "macos" ]]; then
            install_brew_package shellcheck "" shellcheck
            install_brew_package shfmt "" shfmt
        elif [[ "$OS" == "linux" ]]; then
            install_linux_package shellcheck "" shellcheck || true
            install_linux_package shfmt "" shfmt || true
        fi
    fi

    # scalafmt (via brew on macOS - Scala tool, NOT available via cargo)
    if [[ "$CATEGORIES" == "full" ]]; then
        if [[ "$OS" == "macos" ]]; then
            install_brew_package scalafmt "" scalafmt
        fi
    fi

    # scalafix (Scala linter via coursier)
    if [[ "$CATEGORIES" == "full" ]]; then
        if cmd_exists coursier; then
            if ! cmd_exists scalafix; then
                coursier install scalafix >/dev/null 2>&1 && \
                    track_installed "scalafix" "Scala linter" || \
                    track_failed "scalafix" "Scala linter"
            else
                log_info "scalafix already installed"
                track_skipped "scalafix" "Scala linter"
            fi
        fi
    fi

    # Metals (Scala language server via coursier)
    if [[ "$CATEGORIES" == "full" ]]; then
        if cmd_exists coursier; then
            if ! cmd_exists metals; then
                coursier install metals >/dev/null 2>&1 && \
                    track_installed "metals" "Scala language server" || \
                    track_failed "metals" "Scala language server"
            else
                log_info "metals already installed"
                track_skipped "metals" "Scala language server"
            fi
        fi
    fi

    # checkstyle (Java linter)
    if [[ "$CATEGORIES" == "full" ]]; then
        if [[ "$OS" == "macos" ]]; then
            install_brew_package checkstyle "" checkstyle
        elif [[ "$OS" == "linux" ]]; then
            install_linux_package checkstyle "" checkstyle || true
        fi
    fi

    # stylua (Lua formatter)
    if [[ "$CATEGORIES" == "full" ]]; then
        if [[ "$OS" == "macos" ]]; then
            install_brew_package stylua "" stylua
        elif [[ "$OS" == "linux" ]]; then
            if ! cmd_exists stylua; then
                if cmd_exists cargo; then
                    cargo install stylua >/dev/null 2>&1 && \
                        track_installed "stylua" "Lua formatter" || \
                        track_failed "stylua" "Lua formatter"
                fi
            else
                log_info "stylua already installed"
                track_skipped "stylua" "Lua formatter"
            fi
        fi
    fi

    # selene (Lua linter)
    if [[ "$CATEGORIES" == "full" ]]; then
        if [[ "$OS" == "macos" ]]; then
            install_brew_package selene "" selene
        elif [[ "$OS" == "linux" ]]; then
            if ! cmd_exists selene; then
                if cmd_exists cargo; then
                    cargo install selene >/dev/null 2>&1 && \
                        track_installed "selene" "Lua linter" || \
                        track_failed "selene" "Lua linter"
                fi
            else
                log_info "selene already installed"
                track_skipped "selene" "Lua linter"
            fi
        fi
    fi

    # busted (Lua testing framework)
    if [[ "$CATEGORIES" == "full" ]]; then
        if [[ "$OS" == "macos" ]]; then
            install_brew_package busted "" busted
        elif [[ "$OS" == "linux" ]]; then
            install_linux_package busted "" busted || true
        fi
    fi

    # Initialize user PATH with all common development directories
    # This runs AFTER tool installations so directories exist and can be added
    init_user_path

    log_success "Linters & formatters installation complete"
    return 0
}

# ============================================================================
# PHASE 5: CLI TOOLS
# ============================================================================
install_cli_tools() {
    print_header "Phase 5: CLI Tools"

    # fzf (always latest)
    if [[ "$OS" == "macos" ]]; then
        install_brew_package fzf "" ""
    elif [[ "$OS" == "linux" ]]; then
        install_linux_package fzf "" fzf
    fi

    # zoxide (always latest)
    if [[ "$OS" == "macos" ]]; then
        install_brew_package zoxide "" ""
    elif [[ "$OS" == "linux" ]]; then
        install_linux_package zoxide "" zoxide
    fi

    # bat (always latest)
    if [[ "$OS" == "macos" ]]; then
        install_brew_package bat "" ""
    elif [[ "$OS" == "linux" ]]; then
        install_linux_package bat "" bat
    fi

    # eza (modern ls - always latest)
    if [[ "$OS" == "macos" ]]; then
        install_brew_package eza "" ""
    elif [[ "$OS" == "linux" ]]; then
        install_linux_package eza "" eza || \
        install_linux_package exa "" eza || true
    fi

    # lazygit (always latest)
    if [[ "$OS" == "macos" ]]; then
        install_brew_package lazygit "" ""
    elif [[ "$OS" == "linux" ]]; then
        install_linux_package lazygit "" lazygit
    fi

    # gh (GitHub CLI - always latest)
    if [[ "$OS" == "macos" ]]; then
        install_brew_package gh "" ""
    elif [[ "$OS" == "linux" ]]; then
        install_linux_package gh "" gh
    fi

    # tokei (code stats - always latest)
    if [[ "$CATEGORIES" == "full" ]]; then
        if [[ "$OS" == "macos" ]]; then
            install_brew_package tokei "" ""
        elif [[ "$OS" == "linux" ]]; then
            install_linux_package tokei "" tokei
        fi
    fi

    # ripgrep (always latest)
    if [[ "$CATEGORIES" != "minimal" ]]; then
        if [[ "$OS" == "macos" ]]; then
            install_brew_package ripgrep "" rg
        elif [[ "$OS" == "linux" ]]; then
            install_linux_package ripgrep "" rg
        fi
    fi

    # fd (always latest)
    if [[ "$CATEGORIES" == "full" ]]; then
        if [[ "$OS" == "macos" ]]; then
            install_brew_package fd "" fd
        elif [[ "$OS" == "linux" ]]; then
            install_linux_package fd-find "" fd || true
        fi
    fi

    # bats (testing framework - always latest)
    if cmd_exists npm; then
        install_npm_global bats bats ""
    elif [[ "$OS" == "macos" ]]; then
        install_brew_package bats ""
    elif [[ "$OS" == "linux" ]]; then
        install_linux_package bats "" bats
    fi

    # kcov (code coverage for bash - Linux/macOS only)
    if [[ "$OS" == "macos" ]]; then
        install_brew_package kcov "" kcov
    elif [[ "$OS" == "linux" ]]; then
        install_linux_package kcov "" kcov
    fi

    log_success "CLI tools installation complete"
    return 0
}

# ============================================================================
# PHASE 5.25: MCP SERVERS (Model Context Protocol servers for Claude Code)
# ============================================================================
install_mcp_servers() {
    print_header "Phase 5.25: MCP Servers"

    # Skip if npm is not available
    if ! cmd_exists npm; then
        log_warning "npm not found, skipping MCP server installation"
        return 0
    fi

    # Context7 - Up-to-date library documentation and code examples
    if ! npm list -g @upstash/context7-mcp >/dev/null 2>&1; then
        log_step "Installing context7 MCP server..."
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY-RUN] Would npm install -g @upstash/context7-mcp"
            track_installed "context7-mcp" "documentation lookup"
        else
            if npm install -g @upstash/context7-mcp >/dev/null 2>&1; then
                log_success "context7 MCP server installed"
                track_installed "context7-mcp" "documentation lookup"
            else
                log_warning "Failed to install context7 MCP server"
                track_failed "context7-mcp" "documentation lookup"
            fi
        fi
    else
        track_skipped "context7-mcp" "documentation lookup"
    fi

    # Playwright - Browser automation and E2E testing
    if ! npm list -g @playwright/mcp >/dev/null 2>&1; then
        log_step "Installing playwright MCP server..."
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY-RUN] Would npm install -g @playwright/mcp"
            track_installed "playwright-mcp" "browser automation"
        else
            if npm install -g @playwright/mcp >/dev/null 2>&1; then
                log_success "playwright MCP server installed"
                track_installed "playwright-mcp" "browser automation"
            else
                log_warning "Failed to install playwright MCP server"
                track_failed "playwright-mcp" "browser automation"
            fi
        fi
    else
        track_skipped "playwright-mcp" "browser automation"
    fi

    # Repomix - Pack repositories for full-context AI exploration
    # Note: repomix MCP mode is invoked via npx -y repomix --mcp
    # The repomix package itself has built-in MCP support via --mcp flag
    # No global installation needed - npx handles it on-demand
    track_skipped "repomix" "repository packer (uses npx -y repomix --mcp)"

    log_success "MCP server installation complete"
    return 0
}

# ============================================================================
# PHASE 5.5: DEVELOPMENT TOOLS (Editors, LaTeX, AI Coding Assistants)
# ============================================================================
install_development_tools() {
    print_header "Phase 5.5: Development Tools"

    # VS Code (system-wide installation - avoids plugin auth issues)
    if ! cmd_exists code; then
        log_step "Installing VS Code (system-wide)..."
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY-RUN] Would install VS Code"
            track_installed "vscode" "code editor"
        else
            if [[ "$OS" == "macos" ]] && declare -f install_brew_cask >/dev/null; then
                # macOS: use brew cask (installs in /Applications)
                # Note: brew cask is macOS-only, not available on Linux
                if install_brew_cask "visual-studio-code" "code"; then
                    log_success "VS Code installed"
                fi
            elif [[ "$OS" == "linux" ]]; then
                # Linux: install system-wide using official Microsoft package
                # Detect distro and use appropriate method
                if [[ -f /etc/debian_version ]]; then
                    # Debian/Ubuntu: download and install .deb
                    log_info "Installing VS Code via .deb package..."
                    if curl -fL https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64 -o /tmp/code_amd64.deb >/dev/null 2>&1; then
                        if sudo dpkg -i /tmp/code_amd64.deb >/dev/null 2>&1; then
                            sudo apt-get install -f -y >/dev/null 2>&1  # Fix dependencies
                            log_success "VS Code installed system-wide via .deb"
                            track_installed "vscode" "code editor"
                        else
                            log_error "Failed to install VS Code .deb"
                            track_failed "vscode" "code editor"
                        fi
                        rm -f /tmp/code_amd64.deb
                    else
                        log_error "Failed to download VS Code .deb"
                        track_failed "vscode" "code editor"
                    fi
                elif [[ -f /etc/redhat-release ]] || [[ -f /etc/fedora-release ]]; then
                    # Fedora/RHEL: download and install .rpm
                    log_info "Installing VS Code via .rpm package..."
                    if curl -fL https://code.visualstudio.com/sha/download?build=stable&os=linux-rpm-x64 -o /tmp/code_amd64.rpm >/dev/null 2>&1; then
                        if sudo dnf install -y /tmp/code_amd64.rpm >/dev/null 2>&1 || \
                           sudo rpm -i /tmp/code_amd64.rpm >/dev/null 2>&1; then
                            log_success "VS Code installed system-wide via .rpm"
                            track_installed "vscode" "code editor"
                        else
                            log_error "Failed to install VS Code .rpm"
                            track_failed "vscode" "code editor"
                        fi
                        rm -f /tmp/code_amd64.rpm
                    else
                        log_error "Failed to download VS Code .rpm"
                        track_failed "vscode" "code editor"
                    fi
                elif [[ -f /etc/arch-release ]]; then
                    # Arch: use yay or paravail from AUR, or fallback to manual
                    if cmd_exists yay; then
                        yay -S --noconfirm visual-studio-code-bin >/dev/null 2>&1 && \
                        log_success "VS Code installed via yay" && \
                        track_installed "vscode" "code editor"
                    else
                        log_warning "Install VS Code from AUR: yay -S visual-studio-code-bin"
                        track_failed "vscode" "code editor"
                    fi
                else
                    # Fallback: try Microsoft's repository script
                    if curl -fL https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64 -o /tmp/code_amd64.deb >/dev/null 2>&1; then
                        sudo dpkg -i /tmp/code_amd64.deb >/dev/null 2>&1 && \
                        log_success "VS Code installed system-wide" && \
                        track_installed "vscode" "code editor" && \
                        rm -f /tmp/code_amd64.deb
                    else
                        log_warning "Install VS Code from: https://code.visualstudio.com/"
                        track_failed "vscode" "code editor"
                    fi
                fi
            fi
        fi
    else
        log_info "VS Code already installed"
        track_skipped "vscode" "code editor"
    fi

    # LaTeX (TeX Live)
    if ! cmd_exists pdflatex; then
        log_step "Installing LaTeX (TeX Live)..."
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY-RUN] Would install LaTeX"
            track_installed "latex" "document preparation"
        else
            if [[ "$OS" == "macos" ]]; then
                # Use basictex for smaller installation, or mactex-no-gui for full
                if install_brew_cask "basictex" "pdflatex"; then
                    log_success "LaTeX (BasicTeX) installed"
                fi
            elif [[ "$OS" == "linux" ]]; then
                if install_linux_package "texlive" "" "pdflatex"; then
                    log_success "LaTeX (TeX Live) installed"
                fi
            fi
        fi
    else
        log_info "LaTeX already installed"
        track_skipped "latex" "document preparation"
    fi

    # Claude Code CLI (via npm)
    if cmd_exists npm; then
        if ! cmd_exists claude; then
            log_step "Installing Claude Code CLI..."
            if [[ "$DRY_RUN" == "true" ]]; then
                log_info "[DRY-RUN] Would install Claude Code CLI"
            else
                if install_npm_global "@anthropic-ai/claude-code" "claude"; then
                    log_success "Claude Code CLI installed"
                fi
            fi
        else
            log_info "Claude Code CLI already installed"
            track_skipped "claude-code" "AI CLI"
        fi

        # OpenCode AI CLI (via npm)
        if ! cmd_exists opencode; then
            log_step "Installing OpenCode AI CLI..."
            if [[ "$DRY_RUN" == "true" ]]; then
                log_info "[DRY-RUN] Would install OpenCode AI CLI"
            else
                if install_npm_global "opencode-ai" "opencode"; then
                    log_success "OpenCode AI CLI installed"
                fi
            fi
        else
            log_info "OpenCode AI CLI already installed"
            track_skipped "opencode" "AI CLI"
        fi
    else
        log_warning "npm not found - skipping Claude Code and OpenCode AI CLI"
    fi

    log_success "Development tools installation complete"
    return 0
}

# ============================================================================
# PHASE 6: DEPLOY CONFIGURATIONS
# ============================================================================
deploy_configs() {
    print_header "Phase 6: Deploying Configurations"

    local deploy_script="$SCRIPT_DIR/../deploy.sh"

    if [[ ! -f "$deploy_script" ]]; then
        log_warning "deploy.sh not found at $deploy_script"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would run: $deploy_script"
        return 0
    fi

    log_step "Running deploy script..."
    bash "$deploy_script"
    log_success "Configurations deployed"
}

# ============================================================================
# PHASE 7: UPDATE ALL
# ============================================================================
update_all_repos() {
    print_header "Phase 7: Updating All Repositories and Packages"

    local update_script="$SCRIPT_DIR/../update-all.sh"

    if [[ ! -f "$update_script" ]]; then
        log_warning "update-all.sh not found at $update_script"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would run: $update_script"
        return 0
    fi

    log_step "Running update-all script..."
    bash "$update_script"
    echo ""
    log_success "Update complete"
}

# ============================================================================
# MAIN
# ============================================================================
main() {
    print_header "Bootstrap $(capitalize "$OS") Development Environment"

    echo -e "Options:"
    echo -e "  Interactive: ${INTERACTIVE}"
    echo -e "  Dry Run: ${DRY_RUN}"
    echo -e "  Categories: ${CATEGORIES}"
    echo -e "  Skip Update: ${SKIP_UPDATE}"
    echo ""

    # Confirm if interactive
    if [[ "$INTERACTIVE" == "true" ]]; then
        if ! confirm "Proceed with bootstrap?" "n"; then
            echo "Aborted."
            exit 0
        fi
    fi

    # Run phases
    install_foundation || {
        log_error "Foundation installation failed"
        exit 1
    }

    install_sdks || {
        log_warning "Some SDKs failed to install"
    }

    if [[ "$CATEGORIES" != "minimal" ]]; then
        install_language_servers || {
            log_warning "Some language servers failed to install"
        }
    fi

    if [[ "$CATEGORIES" != "minimal" ]]; then
        install_linters_formatters || {
            log_warning "Some linters/formatters failed to install"
        }
    fi

    install_cli_tools || {
        log_warning "Some CLI tools failed to install"
    }

    if [[ "$CATEGORIES" != "minimal" ]]; then
        install_mcp_servers || {
            log_warning "Some MCP servers failed to install"
        }
    fi

    install_development_tools || {
        log_warning "Some development tools failed to install"
    }

    deploy_configs
    update_all_repos

    print_summary

    if [[ "$DRY_RUN" == "false" ]]; then
        echo -e "${GREEN}=== Bootstrap Complete ===${NC}"
        echo -e "${GREEN}All tools are available in the current session.${NC}"
        echo -e "${CYAN}For new shells, PATH has been updated automatically.${NC}"
    else
        echo -e "${YELLOW}=== Dry Run Complete ===${NC}"
        echo -e "${YELLOW}Run without --dry-run to actually install${NC}"
    fi
}

main
