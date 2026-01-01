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
        install_npm_global "dockerfile-language-server-nodejs" "docker-language-server" ""
        install_npm_global "docker-compose-language-service" "docker-compose-language-server" ""
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

    # scalafmt (via cargo)
    if [[ "$CATEGORIES" == "full" ]] && cmd_exists cargo; then
        install_cargo_package "scalafmt" "scalafmt" ""
    fi

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

    # kcov (code coverage for bash - Linux/macOS only - always latest)
    if [[ "$OS" == "macos" ]]; then
        install_brew_package kcov "" kcov
    elif [[ "$OS" == "linux" ]]; then
        install_linux_package kcov "" kcov
    fi

    log_success "CLI tools installation complete"
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

    deploy_configs
    update_all_repos

    print_summary

    if [[ "$DRY_RUN" == "false" ]]; then
        echo -e "${GREEN}=== Bootstrap Complete ===${NC}"
        echo -e "${YELLOW}Reload your shell to apply changes${NC}"
    else
        echo -e "${YELLOW}=== Dry Run Complete ===${NC}"
        echo -e "${YELLOW}Run without --dry-run to actually install${NC}"
    fi
}

main
