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
	-y | --yes)
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
	-h | --help)
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

	# Fix any existing issues before starting
	fix_path_issues
	fix_package_states
	ensure_config_dir

	# Make sure bootstrap scripts are executable
	chmod +x "$SCRIPT_DIR/bootstrap.sh" 2>/dev/null || true
	chmod +x "$ROOT_DIR/bootstrap.sh" 2>/dev/null || true

	# Install prerequisites via apt BEFORE homebrew (for fresh Ubuntu)
	if [[ "$OS" == "linux" ]] && [[ -f /etc/debian_version ]]; then
		log_step "Installing prerequisites via apt: curl, git, vim..."
		for pkg in curl git vim; do
			if ! cmd_exists "$pkg"; then
				run_cmd "sudo apt update >/dev/null 2>&1" || true
				run_cmd "sudo apt install -y $pkg >/dev/null 2>&1" || true
			fi
		done
	fi

	# Install Homebrew automatically on Linux (no prompt)
	# macOS already has brew or we'll install it
	if [[ "$OS" == "linux" ]]; then
		if ! cmd_exists brew; then
			ensure_homebrew || return 1
		fi
	elif [[ "$OS" == "macos" ]]; then
		ensure_homebrew || return 1
	fi

	# Fix PATH again after brew installation
	fix_path_issues

	# Install WezTerm (Linux only via apt, macOS via brew cask later)
	if [[ "$OS" == "linux" ]] && [[ -f /etc/debian_version ]]; then
		install_wezterm_apt
	fi

	# Install Google Chrome (Linux via .deb, macOS via brew cask later)
	if [[ "$OS" == "linux" ]] && [[ -f /etc/debian_version ]]; then
		install_google_chrome
	fi

	# Install IosevkaTerm Nerd Font (needed for WezTerm config)
	if [[ "$OS" == "linux" ]]; then
		install_nerd_fonts "IosevkaTerm" "IosevkaTerm"
	fi

	# Install GitHub CLI via brew
	if ! cmd_exists gh; then
		log_step "Installing GitHub CLI via brew..."
		install_brew_package gh "" gh
	fi

	# Interactive gh auth login - pause and wait for user
	if cmd_exists gh && ! gh auth status >/dev/null 2>&1; then
		print_header "GitHub Authentication Required"
		echo -e "${YELLOW}You need to authenticate with GitHub to continue.${NC}"
		echo -e "${CYAN}A browser window will open for you to complete authentication.${NC}"
		echo ""
		if [[ "$INTERACTIVE" != "false" ]]; then
			if confirm "Authenticate with GitHub now?" "y"; then
				log_step "Running gh auth login..."
				if gh auth login; then
					log_success "GitHub authentication successful"
				else
					log_warning "GitHub authentication failed or was cancelled"
					log_info "You can run 'gh auth login' later to authenticate"
				fi
			else
				log_info "Skipping GitHub authentication. Run 'gh auth login' later."
			fi
		else
			log_info "Non-interactive mode: Skipping 'gh auth login'. Run it manually later."
		fi
	elif cmd_exists gh; then
		log_success "GitHub CLI already authenticated"
	fi

	# Self-correction: Replace any system packages with brew versions
	# This ensures git, gcc, node, go, and other key tools are from brew
	if [[ "$OS" == "linux" ]] && cmd_exists brew; then
		ensure_brew_packages
	fi

	# Ensure git is installed (final fallback)
	if ! cmd_exists git; then
		log_step "Installing git..."
		if cmd_exists brew; then
			install_brew_package git
		else
			install_linux_package git
		fi
	fi

	# Configure git and add GitHub to known_hosts (platform-specific function)
	configure_git_settings

	# Install zsh (shell)
	if [[ "$OS" == "linux" ]]; then
		install_zsh
	elif [[ "$OS" == "macos" ]]; then
		install_brew_package zsh "" zsh
	fi

	# Install oh-my-zsh (zsh framework)
	if [[ "$OS" == "linux" ]] || [[ "$OS" == "macos" ]]; then
		install_oh_my_zsh
	fi

	# Install zsh plugins
	if [[ "$OS" == "linux" ]] || [[ "$OS" == "macos" ]]; then
		install_zsh_plugins
	fi

	# Set zsh as default shell (only if zsh is installed and not already set)
	if cmd_exists zsh; then
		if [[ "$SHELL" != *"zsh"* ]]; then
			log_info "To set zsh as your default shell, run: chsh -s $(which zsh)"
			log_info "Then log out and back in for changes to take effect"
		else
			log_success "zsh is already the default shell"
		fi
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

	# dotnet SDK (via native system packages)
	# Ubuntu 26.04+ and modern distros have dotnet-sdk in their repos
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
		install_go_package "golang.org/x/tools/gopls" gopls ""
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
		install_npm_global "vscode-html-languageserver-bin" "" ""
	fi

	# CSS language server (via npm - always latest)
	if cmd_exists npm; then
		install_npm_global "vscode-css-languageserver-bin" "" ""
	fi

	# Svelte language server (via npm - always latest)
	if [[ "$CATEGORIES" == "full" ]] && cmd_exists npm; then
		install_npm_global "svelte-language-server" "svelteserver" ""
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
		install_brew_package jdtls "" jdtls || true
	fi

	# intelephense (PHP language server via npm)
	if [[ "$CATEGORIES" == "full" ]] && cmd_exists npm; then
		install_npm_global "intelephense" "intelephense" ""
	fi

	# Docker language servers (via npm - always latest)
	if cmd_exists npm; then
		# dockerfile-language-server (binary: docker-langserver)
		# Note: docker-language-server (formerly docker-compose-language-server) covers both Dockerfile and Docker Compose
		install_npm_global "dockerfile-language-server-nodejs" "docker-langserver" ""
	fi

	# helm-ls (Helm language server - prefer brew, fallback to go install)
	# Note: binary is named helm_ls (underscore) not helm-ls (hyphen)
	if [[ "$CATEGORIES" == "full" ]]; then
		if [[ "$OS" == "macos" ]] || [[ "$OS" == "linux" ]]; then
			install_brew_package "helm-ls" "" "helm_ls" ||
				install_go_package "github.com/mrjosh/helm-ls" "helm_ls" ""
		fi
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

	# yamllint (YAML linter for Docker Compose, Helm, Kubernetes)
	if [[ "$CATEGORIES" == "full" ]]; then
		if [[ "$OS" == "macos" ]]; then
			install_brew_package yamllint "" yamllint
		elif [[ "$OS" == "linux" ]]; then
			install_linux_package yamllint "" yamllint || install_pip_global "yamllint" yamllint "" || true
		fi
	fi

	# hadolint (Dockerfile linter)
	if [[ "$CATEGORIES" == "full" ]]; then
		if [[ "$OS" == "macos" ]]; then
			install_brew_package hadolint "" hadolint
		elif [[ "$OS" == "linux" ]]; then
			install_linux_package hadolint "" hadolint || true
		fi
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
		install_go_package "github.com/nao1215/gup" gup ""
	fi

	# goimports (via gup if available, otherwise go install - always latest)
	if cmd_exists go; then
		install_go_package "golang.org/x/tools/cmd/goimports" goimports ""
	fi

	# golangci-lint (always latest)
	if cmd_exists go; then
		if [[ "$OS" == "macos" ]]; then
			install_brew_package golangci-lint "" golangci-lint
		elif [[ "$OS" == "linux" ]]; then
			install_linux_package golangci-lint "" golangci-lint ||
				install_go_package "github.com/golangci/golangci-lint/cmd/golangci-lint" golangci-lint ""
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
					curl -sS https://getcomposer.org/installer | php >/dev/null 2>&1 &&
						sudo mv composer.phar /usr/local/bin/composer 2>/dev/null ||
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
				composer global require laravel/pint >/dev/null 2>&1 &&
					track_installed "pint" "PHP code style" ||
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
				composer global require phpstan/phpstan >/dev/null 2>&1 &&
					track_installed "phpstan" "PHP static analysis" ||
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
				composer global require vimeo/psalm >/dev/null 2>&1 &&
					track_installed "psalm" "PHP static analysis" ||
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
				coursier install scalafix >/dev/null 2>&1 &&
					track_installed "scalafix" "Scala linter" ||
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
				coursier install metals >/dev/null 2>&1 &&
					track_installed "metals" "Scala language server" ||
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
					cargo install stylua >/dev/null 2>&1 &&
						track_installed "stylua" "Lua formatter" ||
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
					cargo install selene >/dev/null 2>&1 &&
						track_installed "selene" "Lua linter" ||
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
		install_linux_package eza "" eza ||
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

	# Infrastructure tools (Docker Compose, Helm, kubectl)
	if [[ "$CATEGORIES" == "full" ]]; then
		# Priority: brew → official script → apt (last resort)

		# docker-compose
		if ! cmd_exists docker-compose; then
			if [[ "$OS" == "macos" ]]; then
				install_brew_package docker-compose "" docker-compose
			elif [[ "$OS" == "linux" ]]; then
				# Try brew first (if available), then apt as last resort
				install_linux_package docker-compose "" docker-compose || true
			fi
		fi

		# helm
		if ! cmd_exists helm; then
			if [[ "$OS" == "macos" ]]; then
				install_brew_package helm "" helm
			elif [[ "$OS" == "linux" ]]; then
				# Priority: brew → official script → apt
				if ! cmd_exists brew || ! install_brew_package helm "" helm 2>/dev/null; then
					# Brew not available or failed, try official script
					if ! run_cmd "curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && \
                        chmod +x get_helm.sh && ./get_helm.sh"; then
						# Official script failed, try apt as last resort
						install_linux_package helm "" helm || true
					else
						track_installed "helm" "Kubernetes package manager"
						rm -f get_helm.sh
					fi
				fi
			fi
		fi

		# kubectl
		if ! cmd_exists kubectl; then
			if [[ "$OS" == "macos" ]]; then
				install_brew_package kubectl "" kubectl
			elif [[ "$OS" == "linux" ]]; then
				# Priority: brew → official script → apt (with k8s repo setup)
				if ! cmd_exists brew || ! install_brew_package kubectl "" kubectl 2>/dev/null; then
					# Brew not available or failed, try official script
					if ! run_cmd "curl -LO 'https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl' && \
                        chmod +x kubectl && sudo mv kubectl /usr/local/bin/kubectl"; then
						# Official script failed, try apt as last resort
						install_linux_package kubectl "" kubectl || true
					else
						track_installed "kubectl" "Kubernetes CLI"
					fi
				fi
			fi
		fi
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
	track_skipped "repomix" "repository packer - uses npx -y repomix --mcp"

	log_success "MCP server installation complete"
	return 0
}

# ============================================================================
# PHASE 5.5: DEVELOPMENT TOOLS (Editors, LaTeX, AI Coding Assistants)
# ============================================================================
install_development_tools() {
	print_header "Phase 5.5: Development Tools"

	# Neovim 0.12 (via snap edge channel - prerelease)
	if ! cmd_exists nvim; then
		log_step "Installing Neovim 0.12 (prerelease via snap)..."
		if [[ "$DRY_RUN" == "true" ]]; then
			log_info "[DRY-RUN] Would install Neovim 0.12"
			track_installed "neovim" "editor"
		else
			if [[ "$OS" == "linux" ]]; then
				# Check if snap is available
				if command -v snap >/dev/null 2>&1; then
					if run_cmd "sudo snap install --edge nvim --classic"; then
						log_success "Neovim 0.12 installed via snap"
						track_installed "neovim" "editor"
					else
						log_error "Failed to install Neovim via snap"
						track_failed "neovim" "editor"
					fi
				else
					log_warning "snap not found - install snapd first: sudo apt install -y snapd"
					track_failed "neovim" "editor - snap not available"
				fi
			elif [[ "$OS" == "macos" ]]; then
				# macOS: use brew for neovim
				if install_brew_package neovim "" nvim; then
					log_success "Neovim installed via brew"
					track_installed "neovim" "editor"
				fi
			fi
		fi
	else
		log_info "Neovim already installed"
		track_skipped "neovim" "editor"
	fi

	# VS Code (system-wide installation via official apt repository)
	if ! cmd_exists code; then
		log_step "Installing VS Code..."
		if [[ "$DRY_RUN" == "true" ]]; then
			log_info "[DRY-RUN] Would install VS Code"
			track_installed "vscode" "code editor"
		else
			if [[ "$OS" == "macos" ]] && declare -f install_brew_cask >/dev/null; then
				# macOS: use brew cask (installs in /Applications)
				if install_brew_cask "visual-studio-code" "code"; then
					log_success "VS Code installed"
				fi
			elif [[ "$OS" == "linux" ]] && [[ -f /etc/debian_version ]]; then
				# Debian/Ubuntu: Use official Microsoft apt repository
				log_info "Installing VS Code via Microsoft apt repository..."

				# Import Microsoft GPG key
				if run_cmd "wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/microsoft.gpg"; then
					# Add VS Code repository
					if run_cmd "echo \"deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main\" | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null"; then
						# Install
						if run_cmd "sudo apt update >/dev/null 2>&1 && sudo apt install -y code >/dev/null 2>&1"; then
							log_success "VS Code installed via apt repository"
							track_installed "vscode" "code editor"
						else
							log_error "Failed to install VS Code"
							track_failed "vscode" "code editor"
						fi
					else
						log_error "Failed to add VS Code repository"
						track_failed "vscode" "code editor"
					fi
				else
					log_error "Failed to add Microsoft GPG key"
					track_failed "vscode" "code editor"
				fi
			elif [[ "$OS" == "linux" ]] && [[ -f /etc/redhat-release ]] || [[ -f /etc/fedora-release ]]; then
				# Fedora/RHEL: Use Microsoft yum repository
				log_info "Installing VS Code via Microsoft yum repository..."
				if run_cmd "sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc >/dev/null 2>&1"; then
					if run_cmd "sudo sh -c 'echo -e \"[code]\\nname=Visual Studio Code\\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\\nenabled=1\\ngpgcheck=1\\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc\" > /etc/yum.repos.d/vscode.repo'"; then
						if run_cmd "sudo dnf install -y code >/dev/null 2>&1 || sudo yum install -y code >/dev/null 2>&1"; then
							log_success "VS Code installed via yum repository"
							track_installed "vscode" "code editor"
						else
							log_error "Failed to install VS Code"
							track_failed "vscode" "code editor"
						fi
					fi
				fi
			elif [[ "$OS" == "linux" ]] && [[ -f /etc/arch-release ]]; then
				# Arch: use yay from AUR
				if cmd_exists yay; then
					if run_cmd "yay -S --noconfirm visual-studio-code-bin >/dev/null 2>&1"; then
						log_success "VS Code installed via yay"
						track_installed "vscode" "code editor"
					else
						log_error "Failed to install VS Code via yay"
						track_failed "vscode" "code editor"
					fi
				else
					log_warning "Install VS Code from AUR: yay -S visual-studio-code-bin"
					track_failed "vscode" "code editor"
				fi
			fi
		fi
	else
		log_info "VS Code already installed"
		track_skipped "vscode" "code editor"
	fi

	# LaTeX TeX Live (via brew - works on both macOS and Linux)
	# Auto-correction: Remove any non-brew texlive installations
	if [[ "$OS" == "linux" ]] && [[ -f /etc/debian_version ]]; then
		# Remove apt texlive packages if present
		if dpkg -l | grep -q "texlive-base"; then
			log_warning "Found texlive from apt (removing for brew version)..."
			if [[ "$DRY_RUN" != "true" ]]; then
				sudo dpkg -r texlive-base texlive-binaries texlive-common texlive-extra-extra texlive-fonts-recommended texlive-latex-base texlive-latex-extra texlive-luatex texlive-xetex >/dev/null 2>&1 || true
				log_success "Removed apt texlive packages"
			fi
		fi
	fi

	if ! cmd_exists pdflatex; then
		log_step "Installing LaTeX TeX Live via brew..."
		if [[ "$DRY_RUN" == "true" ]]; then
			log_info "[DRY-RUN] Would install LaTeX"
			track_installed "latex" "document preparation"
		else
			if [[ "$OS" == "macos" ]]; then
				# macOS: use basictex cask for smaller installation
				if install_brew_cask "basictex" "pdflatex"; then
					log_success "LaTeX BasicTeX installed"
				fi
			elif [[ "$OS" == "linux" ]]; then
				# Linux: use brew texlive formula
				if install_brew_package "texlive" "" "pdflatex"; then
					log_success "LaTeX TeX Live installed via brew"
				fi
			fi
		fi
	else
		log_info "LaTeX already installed"
		track_skipped "latex" "document preparation"
	fi

	# Claude Code CLI (native install via official script)
	if ! cmd_exists claude; then
		log_step "Installing Claude Code CLI - native..."
		if [[ "$DRY_RUN" == "true" ]]; then
			log_info "[DRY-RUN] Would install Claude Code CLI"
		else
			# Install via official script
			if run_cmd "curl -fsSL https://claude.ai/install.sh | bash"; then
				# Add to PATH for current session
				ensure_path "$HOME/.local/bin"
				# Fix PATH to ensure claude is discoverable
				fix_path_issues
				if cmd_exists claude; then
					log_success "Claude Code CLI installed"
					track_installed "claude-code" "AI CLI"
				else
					log_warning "Claude Code CLI installed but not in PATH yet"
					track_installed "claude-code" "AI CLI - PATH update pending"
				fi
			else
				log_error "Failed to install Claude Code CLI"
				track_failed "claude-code" "AI CLI"
			fi
		fi
	else
		log_info "Claude Code CLI already installed"
		track_skipped "claude-code" "AI CLI"
	fi

	# OpenCode AI CLI (via npm)
	if cmd_exists npm; then
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
		log_warning "npm not found - skipping OpenCode AI CLI"
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
