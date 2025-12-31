#!/usr/bin/env bash
# Universal Bootstrap Script
# Installs and configures development environment on Linux/macOS
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
CONFIG_DIR="$SCRIPT_DIR/config"

# Source library functions
# shellcheck source=lib/common.sh
source "$LIB_DIR/common.sh"
# shellcheck source=lib/version-check.sh
source "$LIB_DIR/version-check.sh"

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

    # Node.js
    if [[ "$CATEGORIES" != "minimal" ]]; then
        if [[ "$OS" == "macos" ]]; then
            install_brew_package node "18.0.0"
        elif [[ "$OS" == "linux" ]]; then
            install_linux_package nodejs "18.0.0" node
        fi
    fi

    # Python
    if [[ "$OS" == "macos" ]]; then
        install_brew_package python "3.9.0" python3
    elif [[ "$OS" == "linux" ]]; then
        install_linux_package python3 "3.9.0" python3
    fi

    # Go
    if [[ "$CATEGORIES" != "minimal" ]]; then
        if [[ "$OS" == "macos" ]]; then
            install_brew_package go "1.20.0"
        elif [[ "$OS" == "linux" ]]; then
            install_linux_package golang "1.20.0" go
        fi
    fi

    # Rust
    if [[ "$CATEGORIES" == "full" ]]; then
        install_rustup
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

    # lua_ls (via system package)
    if [[ "$OS" == "macos" ]]; then
        install_brew_package lua-language-server "3.9.0" lua-language-server
    elif [[ "$OS" == "linux" ]]; then
        install_linux_package lua-language-server "3.9.0" lua-language-server || true
    fi

    # clangd (via system package)
    if [[ "$OS" == "macos" ]]; then
        install_brew_package llvm "15.0.0" clangd
    elif [[ "$OS" == "linux" ]]; then
        install_linux_package clangd "15.0.0" clangd
    fi

    # gopls (via go install)
    if [[ "$CATEGORIES" == "full" ]] && cmd_exists go; then
        install_go_package "golang.org/x/tools/gopls@latest" gopls "0.14.0"
    fi

    # rust-analyzer (via rustup)
    if [[ "$CATEGORIES" == "full" ]]; then
        install_rust_analyzer_component
    fi

    # pyright (via npm)
    if cmd_exists npm; then
        install_npm_global pyright pyright "1.1.300"
    fi

    # TypeScript language server (via npm)
    if cmd_exists npm; then
        install_npm_global typescript-language-server typescript-language-server "3.0.0"
    fi

    # YAML language server (via npm)
    if cmd_exists npm; then
        install_npm_global yaml-language-server yaml-language-server "1.0.0"
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

    # Prettier (via npm)
    if cmd_exists npm; then
        install_npm_global prettier prettier "3.0.0"
    fi

    # ESLint (via npm)
    if cmd_exists npm; then
        install_npm_global eslint eslint "8.50.0"
    fi

    # Ruff (via pip)
    if cmd_exists python3 || cmd_exists python; then
        install_pip_global "ruff" ruff "0.1.0"
    fi

    # gup (Go package manager - install first, then use it for other Go tools)
    if cmd_exists go && ! cmd_exists gup; then
        install_go_package "nao.vi/gup@latest" gup "0.12.0"
    fi

    # goimports (via gup if available, otherwise go install)
    if cmd_exists go; then
        install_go_package "golang.org/x/tools/cmd/goimports@latest" goimports "0.10.0"
    fi

    # golangci-lint
    if cmd_exists go; then
        if [[ "$OS" == "macos" ]]; then
            install_brew_package golangci-lint "1.55.0" golangci-lint
        elif [[ "$OS" == "linux" ]]; then
            install_linux_package golangci-lint "1.55.0" golangci-lint || \
                install_go_package "github.com/golangci/golangci-lint/cmd/golangci-lint@latest" golangci-lint "1.55.0"
        fi
    fi

    # clang-format (usually comes with clangd)
    if ! cmd_exists clang-format; then
        if [[ "$OS" == "macos" ]]; then
            install_brew_package llvm "15.0.0" clang-format
        elif [[ "$OS" == "linux" ]]; then
            install_linux_package clang-format "15.0.0" clang-format
        fi
    fi

    log_success "Linters & formatters installation complete"
    return 0
}

# ============================================================================
# PHASE 5: CLI TOOLS
# ============================================================================
install_cli_tools() {
    print_header "Phase 5: CLI Tools"

    # fzf
    if [[ "$OS" == "macos" ]]; then
        install_brew_package fzf "0.40.0"
    elif [[ "$OS" == "linux" ]]; then
        install_linux_package fzf "0.40.0" fzf
    fi

    # zoxide
    if [[ "$OS" == "macos" ]]; then
        install_brew_package zoxide "0.9.0"
    elif [[ "$OS" == "linux" ]]; then
        install_linux_package zoxide "0.9.0" zoxide
    fi

    # bat
    if [[ "$OS" == "macos" ]]; then
        install_brew_package bat "0.24.0"
    elif [[ "$OS" == "linux" ]]; then
        install_linux_package bat "0.24.0" bat
    fi

    # eza (modern ls)
    if [[ "$OS" == "macos" ]]; then
        install_brew_package eza "0.18.0"
    elif [[ "$OS" == "linux" ]]; then
        install_linux_package eza "0.18.0" eza || \
        install_linux_package exa "0.18.0" eza || true
    fi

    # lazygit
    if [[ "$OS" == "macos" ]]; then
        install_brew_package lazygit "0.40.0"
    elif [[ "$OS" == "linux" ]]; then
        install_linux_package lazygit "0.40.0" lazygit
    fi

    # gh (GitHub CLI)
    if [[ "$OS" == "macos" ]]; then
        install_brew_package gh "2.40.0"
    elif [[ "$OS" == "linux" ]]; then
        install_linux_package gh "2.40.0" gh
    fi

    # tokei (code stats)
    if [[ "$CATEGORIES" == "full" ]]; then
        if [[ "$OS" == "macos" ]]; then
            install_brew_package tokei "12.0.0"
        elif [[ "$OS" == "linux" ]]; then
            install_linux_package tokei "12.0.0" tokei
        fi
    fi

    # ripgrep
    if [[ "$CATEGORIES" != "minimal" ]]; then
        if [[ "$OS" == "macos" ]]; then
            install_brew_package ripgrep "13.0.0" rg
        elif [[ "$OS" == "linux" ]]; then
            install_linux_package ripgrep "13.0.0" rg
        fi
    fi

    # fd
    if [[ "$CATEGORIES" == "full" ]]; then
        if [[ "$OS" == "macos" ]]; then
            install_brew_package fd "9.0.0" fd
        elif [[ "$OS" == "linux" ]]; then
            install_linux_package fd-find "9.0.0" fd || true
        fi
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
