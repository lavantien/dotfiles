#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
PLATFORMS_DIR="$SCRIPT_DIR/platforms"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/common.sh disable=SC1091
source "$LIB_DIR/common.sh"
# shellcheck source=lib/version-check.sh disable=SC1091
source "$LIB_DIR/version-check.sh"
# shellcheck source=lib/config.sh disable=SC1091
if [[ -f "$ROOT_DIR/lib/config.sh" ]]; then
	source "$ROOT_DIR/lib/config.sh"
fi

OS="$(detect_os)"

if [[ "$OS" == "linux" ]]; then
	# shellcheck source=platforms/linux.sh disable=SC1091
	source "$PLATFORMS_DIR/linux.sh"
elif [[ "$OS" == "macos" ]]; then
	# shellcheck source=platforms/macos.sh disable=SC1091
	source "$PLATFORMS_DIR/macos.sh"
fi

INTERACTIVE=true
DRY_RUN=false
CATEGORIES="full"
VERBOSE=false
AUTO_UPDATE_REPOS="false"
BACKUP_BEFORE_DEPLOY="false"

CONFIG_FILE="$HOME/.dotfiles.config.yaml"

if declare -f load_dotfiles_config >/dev/null 2>&1; then
	if [[ -f "$CONFIG_FILE" ]]; then
		load_dotfiles_config "$CONFIG_FILE" 2>/dev/null || {
			log_warning "Failed to load config file, using defaults"
		}
	fi

	if declare -f get_config >/dev/null 2>&1; then
		CATEGORIES=$(get_config "categories" "$CATEGORIES")
		AUTO_UPDATE_REPOS=$(get_config "auto_update_repos" "$AUTO_UPDATE_REPOS")
		BACKUP_BEFORE_DEPLOY=$(get_config "backup_before_deploy" "$BACKUP_BEFORE_DEPLOY")
	fi
else
	log_info "Config library not found, using hardcoded defaults"
fi

show_help() {
	cat <<'EOF'
Universal Bootstrap Script
Installs and configures development environment on Linux/macOS

VERSION POLICY:
  All packages are installed or updated to their LATEST versions
  No hardcoded version numbers - always gets the newest stable release
  Run bootstrap again to update all tools to latest versions

BRIDGE APPROACH:
  - Works without config file (uses hardcoded defaults - backward compatible)
  - Loads config file if present (~/.dotfiles.config.yaml) - forward compatible
  - Config library is optional - scripts work even if it's missing
  - Defaults: categories="full", interactive=true, no dry-run

Usage:
  ./bootstrap.sh [options]

Options:
  -y, --yes        Non-interactive mode (accept all prompts)
  --dry-run        Show what would be installed without installing
  --categories     minimal|sdk|full (default: full)
  --verbose        Show detailed progress output
  -h, --help       Show this help
============================================================================
SCRIPT SETUP
============================================================================
Source library functions
shellcheck source=lib/common.sh disable=SC1091
shellcheck source=lib/version-check.sh disable=SC1091
shellcheck source=lib/config.sh disable=SC1091
Config library is at root level, not in bootstrap/lib/
Source platform-specific functions
============================================================================
DEFAULTS
============================================================================
============================================================================
LOAD USER CONFIGURATION (OPTIONAL)
============================================================================
Only try to load config if the config library was successfully sourced
============================================================================
HELP
============================================================================
============================================================================
PARSE ARGUMENTS
============================================================================
============================================================================
PHASE 1: FOUNDATION
============================================================================
============================================================================
PHASE 2: CORE SDKS
============================================================================
============================================================================
PHASE 3: LANGUAGE SERVERS
============================================================================
============================================================================
PHASE 4: LINTERS & FORMATTERS
============================================================================
============================================================================
PHASE 5: CLI TOOLS
============================================================================
============================================================================
PHASE 5.25: MCP SERVERS (Model Context Protocol servers for Claude Code)
============================================================================
Install or update a global npm package using the shared version check,
mirroring Install-NpmPackageWithCheck in bootstrap.ps1
============================================================================
PHASE 5.5: DEVELOPMENT TOOLS (Editors, LaTeX, AI Coding Assistants)
============================================================================
============================================================================
PHASE 6: DEPLOY CONFIGURATIONS
============================================================================
============================================================================
MAIN
============================================================================
EOF
}

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
	--verbose)
		VERBOSE=true
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

install_foundation() {
	print_header "Phase 1: Foundation"

	fix_path_issues
	fix_package_states
	ensure_config_dir

	chmod +x "$SCRIPT_DIR/bootstrap.sh" 2>/dev/null || true

	if [[ "$OS" == "linux" ]] && [[ -f /etc/debian_version ]]; then
		log_step "Installing prerequisites via apt: curl, git, vim..."
		for pkg in curl git vim; do
			if ! cmd_exists "$pkg"; then
				run_cmd "sudo apt update >/dev/null 2>&1" || true
				run_cmd "sudo apt install -y $pkg >/dev/null 2>&1" || true
			fi
		done
	fi

	if [[ "$OS" == "linux" ]]; then
		if ! cmd_exists brew; then
			ensure_homebrew || return 1
		fi
	elif [[ "$OS" == "macos" ]]; then
		ensure_homebrew || return 1
	fi

	fix_path_issues

	if [[ "$OS" == "linux" ]] && [[ -f /etc/debian_version ]]; then
		install_wezterm_apt
	fi

	if [[ "$OS" == "linux" ]] && [[ -f /etc/debian_version ]]; then
		install_google_chrome
	fi

	if [[ "$OS" == "linux" ]]; then
		install_nerd_fonts "IosevkaTerm" "IosevkaTerm"
	fi

	if ! cmd_exists gh; then
		log_step "Installing GitHub CLI via brew..."
		install_brew_package gh "" gh
	fi

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

	if [[ "$OS" == "linux" ]] && cmd_exists brew; then
		ensure_brew_packages
	fi

	if ! cmd_exists git; then
		log_step "Installing git..."
		if cmd_exists brew; then
			install_brew_package git
		else
			install_linux_package git
		fi
	fi

	configure_git_settings

	if [[ "$OS" == "linux" ]]; then
		install_zsh
	elif [[ "$OS" == "macos" ]]; then
		install_brew_package zsh "" zsh
	fi

	if [[ "$OS" == "linux" ]] || [[ "$OS" == "macos" ]]; then
		install_oh_my_zsh
	fi

	if [[ "$OS" == "linux" ]] || [[ "$OS" == "macos" ]]; then
		install_zsh_plugins
	fi

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

install_sdks() {
	print_header "Phase 2: Core SDKs"

	if [[ "$CATEGORIES" != "minimal" ]]; then
		if [[ "$OS" == "macos" ]]; then
			install_brew_package node "" ""
		elif [[ "$OS" == "linux" ]]; then
			install_linux_package nodejs "" node
		fi
	fi

	if [[ "$OS" == "macos" ]]; then
		install_brew_package python "" python3
	elif [[ "$OS" == "linux" ]]; then
		install_linux_package python3 "" python3
	fi

	if [[ "$CATEGORIES" != "minimal" ]]; then
		if [[ "$OS" == "macos" ]]; then
			install_brew_package go "" ""
		elif [[ "$OS" == "linux" ]]; then
			install_linux_package golang "" go
		fi
	fi

	if [[ "$CATEGORIES" == "full" ]]; then
		install_rustup
	fi

	if [[ "$CATEGORIES" == "full" ]]; then
		if [[ "$OS" == "macos" ]]; then
			install_brew_package dotnet-sdk "" dotnet
		elif [[ "$OS" == "linux" ]]; then
			install_linux_package dotnet-sdk "" dotnet || true
		fi
	fi

	if [[ "$CATEGORIES" == "full" ]]; then
		install_bun
	fi

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

install_language_servers() {
	if [[ "$CATEGORIES" == "minimal" ]]; then
		return 0
	fi

	print_header "Phase 3: Language Servers"

	if [[ "$OS" == "macos" ]]; then
		install_brew_package lua-language-server "" lua-language-server
	elif [[ "$OS" == "linux" ]]; then
		install_linux_package lua-language-server "" lua-language-server || true
	fi

	if [[ "$OS" == "macos" ]]; then
		install_brew_package llvm "" clangd
	elif [[ "$OS" == "linux" ]]; then
		install_linux_package clangd "" clangd
	fi

	if [[ "$CATEGORIES" == "full" ]] && cmd_exists go; then
		install_go_package "golang.org/x/tools/gopls" gopls ""
	fi

	if [[ "$CATEGORIES" == "full" ]]; then
		install_rust_analyzer_component
	fi

	if cmd_exists npm; then
		install_npm_global pyright pyright ""
	fi

	if cmd_exists npm; then
		install_npm_global typescript-language-server typescript-language-server ""
	fi

	if cmd_exists npm; then
		install_npm_global "vscode-html-languageserver-bin" "" ""
	fi

	if cmd_exists npm; then
		install_npm_global "vscode-css-languageserver-bin" "" ""
	fi

	if [[ "$CATEGORIES" == "full" ]] && cmd_exists npm; then
		install_npm_global "svelte-language-server" "svelteserver" ""
	fi

	if cmd_exists npm; then
		install_npm_global "bash-language-server" "bash-language-server" ""
	fi

	if cmd_exists npm; then
		install_npm_global yaml-language-server yaml-language-server ""
	fi

	if [[ "$CATEGORIES" == "full" ]] && cmd_exists dotnet; then
		install_dotnet_tool "csharp-ls" "csharp-ls" ""
	fi

	if [[ "$CATEGORIES" == "full" ]]; then
		install_brew_package jdtls "" jdtls || true
	fi

	if [[ "$CATEGORIES" == "full" ]] && cmd_exists npm; then
		install_npm_global "intelephense" "intelephense" ""
	fi

	if cmd_exists go; then
		install_go_package "github.com/docker/docker-language-server/cmd/docker-language-server@latest" "docker-language-server" ""
	fi

	if [[ "$CATEGORIES" == "full" ]]; then
		if [[ "$OS" == "macos" ]] || [[ "$OS" == "linux" ]]; then
			install_brew_package "helm-ls" "" "helm_ls" ||
				install_go_package "github.com/mrjosh/helm-ls" "helm_ls" ""
		fi
	fi

	if cmd_exists npm; then
		install_npm_global "tombi" "tombi" ""
	fi

	if [[ "$CATEGORIES" == "full" ]] && cmd_exists npm; then
		install_npm_global "tinymist" "tinymist" ""
	fi

	log_success "Language servers installation complete"
	return 0
}

install_linters_formatters() {
	if [[ "$CATEGORIES" == "minimal" ]]; then
		return 0
	fi

	print_header "Phase 4: Linters & Formatters"

	if cmd_exists npm; then
		install_npm_global prettier prettier ""
	fi

	if cmd_exists npm; then
		install_npm_global eslint eslint ""
	fi

	if cmd_exists npm; then
		install_npm_global stylelint stylelint ""
	fi

	if [[ "$CATEGORIES" == "full" ]]; then
		if [[ "$OS" == "macos" ]]; then
			install_brew_package yamllint "" yamllint
		elif [[ "$OS" == "linux" ]]; then
			install_linux_package yamllint "" yamllint || install_pip_global "yamllint" yamllint "" || true
		fi
	fi

	if [[ "$CATEGORIES" == "full" ]]; then
		if [[ "$OS" == "macos" ]]; then
			install_brew_package hadolint "" hadolint
		elif [[ "$OS" == "linux" ]]; then
			install_linux_package hadolint "" hadolint || true
		fi
	fi

	if [[ "$CATEGORIES" == "full" ]] && cmd_exists npm; then
		install_npm_global "svelte-check" "svelte-check" ""
	fi

	if [[ "$CATEGORIES" == "full" ]] && cmd_exists npm; then
		install_npm_global "repomix" "repomix" ""
	fi

	if cmd_exists npm; then
		install_npm_global "@mermaid-js/mermaid-cli" "mmdc" ""
	fi

	if cmd_exists python3 || cmd_exists python; then
		install_pip_global "ruff" ruff ""
	fi

	if [[ "$CATEGORIES" == "full" ]]; then
		if cmd_exists python3 || cmd_exists python; then
			install_pip_global "black" black "" || true
			install_pip_global "isort" isort "" || true
			install_pip_global "mypy" mypy "" || true
			install_pip_global "pytest" pytest "" || true
		fi
	fi

	if cmd_exists go && ! cmd_exists gup; then
		install_go_package "github.com/nao1215/gup" gup ""
	fi

	if cmd_exists go; then
		install_go_package "golang.org/x/tools/cmd/goimports" goimports ""
	fi

	if cmd_exists go; then
		if [[ "$OS" == "macos" ]]; then
			install_brew_package golangci-lint "" golangci-lint
		elif [[ "$OS" == "linux" ]]; then
			install_linux_package golangci-lint "" golangci-lint ||
				install_go_package "github.com/golangci/golangci-lint/cmd/golangci-lint" golangci-lint ""
		fi
	fi

	if ! cmd_exists clang-format; then
		if [[ "$OS" == "macos" ]]; then
			install_brew_package llvm "" clang-format
		elif [[ "$OS" == "linux" ]]; then
			install_linux_package clang-format "" clang-format
		fi
	fi

	if [[ "$CATEGORIES" == "full" ]]; then
		if [[ "$OS" == "macos" ]]; then
			install_brew_package cppcheck "" cppcheck
		elif [[ "$OS" == "linux" ]]; then
			install_linux_package cppcheck "" cppcheck || true
		fi
	fi

	if [[ "$CATEGORIES" == "full" ]]; then
		if [[ "$OS" == "macos" ]]; then
			install_brew_package catch2 "" catch2
		elif [[ "$OS" == "linux" ]]; then
			install_linux_package catch2 "" catch2 || true
		fi
	fi

	if [[ "$CATEGORIES" == "full" ]]; then
		if [[ "$OS" == "macos" ]]; then
			install_php || true
		elif [[ "$OS" == "linux" ]]; then
			install_php || true
		fi
	fi

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

	if [[ "$CATEGORIES" == "full" ]] && cmd_exists composer; then
		if ! composer global show laravel/pint >/dev/null 2>&1; then
			log_step "Installing Laravel Pint..."
			if [[ "$DRY_RUN" == "true" ]]; then
				log_info "[DRY-RUN] Would composer global require laravel/pint"
			else
				if composer global require laravel/pint >/dev/null 2>&1; then
					track_installed "pint" "PHP code style"
				else
					track_failed "pint" "PHP code style"
				fi
			fi
		else
			log_info "Laravel Pint already installed"
			track_skipped "pint" "PHP code style"
		fi
	fi

	if [[ "$CATEGORIES" == "full" ]] && cmd_exists composer; then
		if ! composer global show phpstan/phpstan >/dev/null 2>&1; then
			log_step "Installing PHPStan..."
			if [[ "$DRY_RUN" == "true" ]]; then
				log_info "[DRY-RUN] Would composer global require phpstan/phpstan"
			else
				if composer global require phpstan/phpstan >/dev/null 2>&1; then
					track_installed "phpstan" "PHP static analysis"
				else
					track_failed "phpstan" "PHP static analysis"
				fi
			fi
		else
			log_info "PHPStan already installed"
			track_skipped "phpstan" "PHP static analysis"
		fi
	fi

	if [[ "$CATEGORIES" == "full" ]] && cmd_exists composer; then
		if ! composer global show vimeo/psalm >/dev/null 2>&1; then
			log_step "Installing Psalm..."
			if [[ "$DRY_RUN" == "true" ]]; then
				log_info "[DRY-RUN] Would composer global require vimeo/psalm"
			else
				if composer global require vimeo/psalm >/dev/null 2>&1; then
					track_installed "psalm" "PHP static analysis"
				else
					track_failed "psalm" "PHP static analysis"
				fi
			fi
		else
			log_info "Psalm already installed"
			track_skipped "psalm" "PHP static analysis"
		fi
	fi

	if [[ "$CATEGORIES" == "full" ]]; then
		if [[ "$OS" == "macos" ]]; then
			install_brew_package shellcheck "" shellcheck
			install_brew_package shfmt "" shfmt
		elif [[ "$OS" == "linux" ]]; then
			install_linux_package shellcheck "" shellcheck || true
			install_linux_package shfmt "" shfmt || true
		fi
	fi

	if [[ "$CATEGORIES" == "full" ]]; then
		if [[ "$OS" == "macos" ]]; then
			install_brew_package scalafmt "" scalafmt
		elif [[ "$OS" == "linux" ]]; then
			install_coursier_package scalafmt "Scala formatter"
		fi
	fi

	if [[ "$CATEGORIES" == "full" ]]; then
		if [[ "$OS" == "linux" ]]; then
			install_coursier_package scalafix "Scala linter"
		elif [[ "$OS" == "macos" ]] && cmd_exists coursier; then
			if ! cmd_exists scalafix; then
				if coursier install scalafix >/dev/null 2>&1; then
					track_installed "scalafix" "Scala linter"
				else
					track_failed "scalafix" "Scala linter"
				fi
			else
				log_info "scalafix already installed"
				track_skipped "scalafix" "Scala linter"
			fi
		fi
	fi

	if [[ "$CATEGORIES" == "full" ]]; then
		if [[ "$OS" == "linux" ]]; then
			install_coursier_package metals "Scala language server"
		elif [[ "$OS" == "macos" ]] && cmd_exists coursier; then
			if ! cmd_exists metals; then
				if coursier install metals >/dev/null 2>&1; then
					track_installed "metals" "Scala language server"
				else
					track_failed "metals" "Scala language server"
				fi
			else
				log_info "metals already installed"
				track_skipped "metals" "Scala language server"
			fi
		fi
	fi

	if [[ "$CATEGORIES" == "full" ]]; then
		if [[ "$OS" == "macos" ]]; then
			install_brew_package checkstyle "" checkstyle
		elif [[ "$OS" == "linux" ]]; then
			install_linux_package checkstyle "" checkstyle || true
		fi
	fi

	if [[ "$CATEGORIES" == "full" ]]; then
		if [[ "$OS" == "macos" ]]; then
			install_brew_package stylua "" stylua
		elif [[ "$OS" == "linux" ]]; then
			if ! cmd_exists stylua; then
				if cmd_exists cargo; then
					if cargo install stylua >/dev/null 2>&1; then
						track_installed "stylua" "Lua formatter"
					else
						track_failed "stylua" "Lua formatter"
					fi
				fi
			else
				log_info "stylua already installed"
				track_skipped "stylua" "Lua formatter"
			fi
		fi
	fi

	if [[ "$CATEGORIES" == "full" ]]; then
		if [[ "$OS" == "macos" ]]; then
			install_brew_package selene "" selene
		elif [[ "$OS" == "linux" ]]; then
			if ! cmd_exists selene; then
				if cmd_exists cargo; then
					if cargo install selene >/dev/null 2>&1; then
						track_installed "selene" "Lua linter"
					else
						track_failed "selene" "Lua linter"
					fi
				fi
			else
				log_info "selene already installed"
				track_skipped "selene" "Lua linter"
			fi
		fi
	fi

	if [[ "$CATEGORIES" == "full" ]]; then
		if [[ "$OS" == "macos" ]]; then
			install_brew_package typos-cli "" typos
		elif [[ "$OS" == "linux" ]]; then
			if ! cmd_exists typos; then
				if cmd_exists cargo; then
					if cargo install typos-cli >/dev/null 2>&1; then
						track_installed "typos" "Spell checker"
					else
						track_failed "typos" "Spell checker"
					fi
				fi
			else
				log_info "typos already installed"
				track_skipped "typos" "Spell checker"
			fi
		fi
	fi

	if [[ "$CATEGORIES" == "full" ]]; then
		if [[ "$OS" == "macos" ]]; then
			install_brew_package busted "" busted
		elif [[ "$OS" == "linux" ]]; then
			install_linux_package busted "" busted || true
		fi
	fi

	init_user_path

	log_success "Linters & formatters installation complete"
	return 0
}

install_cli_tools() {
	print_header "Phase 5: CLI Tools"

	if [[ "$OS" == "macos" ]]; then
		install_brew_package jq "" jq
	elif [[ "$OS" == "linux" ]]; then
		install_linux_package jq "" jq
	fi

	if [[ "$OS" == "macos" ]]; then
		install_brew_package fzf "" ""
	elif [[ "$OS" == "linux" ]]; then
		install_linux_package fzf "" fzf
	fi

	if [[ "$OS" == "macos" ]]; then
		install_brew_package zoxide "" ""
	elif [[ "$OS" == "linux" ]]; then
		install_linux_package zoxide "" zoxide
	fi

	if [[ "$OS" == "macos" ]]; then
		install_brew_package bat "" ""
	elif [[ "$OS" == "linux" ]]; then
		install_linux_package bat "" bat
	fi

	if [[ "$OS" == "macos" ]]; then
		install_brew_package eza "" ""
	elif [[ "$OS" == "linux" ]]; then
		install_linux_package eza "" eza ||
			install_linux_package exa "" eza || true
	fi

	if [[ "$OS" == "macos" ]]; then
		install_brew_package yazi "" yazi
	elif [[ "$OS" == "linux" ]]; then
		install_linux_package yazi "" yazi
	fi

	if [[ "$CATEGORIES" == "full" ]]; then
		if [[ "$OS" == "macos" ]]; then
			install_brew_package difftastic "" difft
		elif [[ "$OS" == "linux" ]]; then
			install_linux_package difftastic "" difft
		fi
	fi

	if [[ "$OS" == "macos" ]]; then
		install_brew_package lazygit "" ""
	elif [[ "$OS" == "linux" ]]; then
		install_linux_package lazygit "" lazygit
	fi

	if [[ "$OS" == "macos" ]]; then
		install_brew_package gh "" ""
	elif [[ "$OS" == "linux" ]]; then
		install_linux_package gh "" gh
	fi

	if [[ "$CATEGORIES" == "full" ]]; then
		if [[ "$OS" == "macos" ]]; then
			install_brew_package tokei "" ""
		elif [[ "$OS" == "linux" ]]; then
			install_linux_package tokei "" tokei
		fi
	fi

	if [[ "$CATEGORIES" != "minimal" ]]; then
		if [[ "$OS" == "macos" ]]; then
			install_brew_package ripgrep "" rg
		elif [[ "$OS" == "linux" ]]; then
			install_linux_package ripgrep "" rg
		fi
	fi

	if [[ "$CATEGORIES" == "full" ]]; then
		if [[ "$OS" == "macos" ]]; then
			install_brew_package fd "" fd
		elif [[ "$OS" == "linux" ]]; then
			install_linux_package fd-find "" fd || true
		fi
	fi

	if [[ "$OS" == "macos" ]]; then
		install_brew_package sqlite "" sqlite3
	elif [[ "$OS" == "linux" ]]; then
		install_brew_package sqlite "" sqlite3
	fi

	if [[ "$CATEGORIES" == "full" ]]; then
		if [[ "$OS" == "macos" ]]; then
			install_brew_package btop "" btop
		elif [[ "$OS" == "linux" ]]; then
			install_linux_package btop "" btop
		fi
	fi

	if cmd_exists npm; then
		install_npm_global bats bats ""
	elif [[ "$OS" == "macos" ]]; then
		install_brew_package bats ""
	elif [[ "$OS" == "linux" ]]; then
		install_linux_package bats "" bats
	fi

	if [[ "$CATEGORIES" == "full" ]]; then

		if ! cmd_exists docker-compose; then
			if [[ "$OS" == "macos" ]]; then
				install_brew_package docker-compose "" docker-compose
			elif [[ "$OS" == "linux" ]]; then
				install_linux_package docker-compose "" docker-compose || true
			fi
		fi

		if ! cmd_exists helm; then
			if [[ "$OS" == "macos" ]]; then
				install_brew_package helm "" helm
			elif [[ "$OS" == "linux" ]]; then
				if ! cmd_exists brew || ! install_brew_package helm "" helm 2>/dev/null; then
					if ! run_cmd "curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && \
                        chmod +x get_helm.sh && ./get_helm.sh"; then
						install_linux_package helm "" helm || true
					else
						track_installed "helm" "Kubernetes package manager"
						rm -f get_helm.sh
					fi
				fi
			fi
		fi

		if ! cmd_exists kubectl; then
			if [[ "$OS" == "macos" ]]; then
				install_brew_package kubectl "" kubectl
			elif [[ "$OS" == "linux" ]]; then
				if ! cmd_exists brew || ! install_brew_package kubectl "" kubectl 2>/dev/null; then
					if ! run_cmd "curl -fsSL -o kubectl 'https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl' && \
                        chmod +x kubectl && sudo mv kubectl /usr/local/bin/kubectl"; then
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

install_npm_package_checked() {
	local pkg="$1"
	local display="$2"
	local track_name="$3"
	local desc="$4"

	if npm_package_needs_update "$pkg"; then
		log_step "Installing $display..."
		if [[ "$DRY_RUN" == "true" ]]; then
			log_info "[DRY-RUN] Would npm install -g $pkg"
			track_installed "$track_name" "$desc"
			return 0
		fi

		if npm install -g "$pkg" >/dev/null 2>&1; then
			log_success "$display installed"
			track_installed "$track_name" "$desc"
		else
			log_warning "Failed to install $display"
			track_failed "$track_name" "$desc"
		fi
	else
		log_verbose "$display (up to date)"
		track_skipped "$track_name" "$desc"
	fi
}

install_mcp_servers() {
	print_header "Phase 5.25: MCP Servers"

	if ! cmd_exists npm; then
		log_warning "npm not found, skipping MCP server installation"
		return 0
	fi

	install_npm_package_checked "tree-sitter-cli" "tree-sitter-cli" "tree-sitter-cli" "Treesitter parser compiler"

	install_npm_package_checked "@upstash/context7-mcp" "context7 MCP server" "context7-mcp" "documentation lookup"

	install_npm_package_checked "@playwright/mcp" "playwright MCP server" "playwright-mcp" "browser automation"

	track_skipped "repomix" "repository packer - uses npx -y repomix --mcp"

	log_success "MCP server installation complete"
	return 0
}

install_development_tools() {
	print_header "Phase 5.5: Development Tools"

	if ! cmd_exists nvim; then
		log_step "Installing Neovim 0.13 (prerelease via snap)..."
		if [[ "$DRY_RUN" == "true" ]]; then
			log_info "[DRY-RUN] Would install Neovim 0.13"
			track_installed "neovim" "editor"
		else
			if [[ "$OS" == "linux" ]]; then
				if command -v snap >/dev/null 2>&1; then
					if run_cmd "sudo snap install --edge nvim --classic"; then
						log_success "Neovim 0.13 nightly installed via snap"
						track_installed "neovim" "editor"
					else
						log_error "Failed to install Neovim via snap"
						track_failed "neovim" "editor"
					fi
				else
					log_info "snap not found, falling back to brew/apt for Neovim"
					if install_linux_package neovim "" nvim; then
						log_success "Neovim installed via package fallback"
					else
						log_error "Failed to install Neovim (no snap, package fallback failed)"
					fi
				fi
			elif [[ "$OS" == "macos" ]]; then
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

	if ! cmd_exists code; then
		log_step "Installing VS Code..."
		if [[ "$DRY_RUN" == "true" ]]; then
			log_info "[DRY-RUN] Would install VS Code"
			track_installed "vscode" "code editor"
		else
			if [[ "$OS" == "macos" ]] && declare -f install_brew_cask >/dev/null; then
				if install_brew_cask "visual-studio-code" "code"; then
					log_success "VS Code installed"
					verify_installed code vscode "code editor"
				fi
			elif [[ "$OS" == "linux" ]] && [[ -f /etc/debian_version ]]; then
				log_info "Installing VS Code via Microsoft apt repository..."

				if run_cmd "wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/microsoft.gpg"; then
					if run_cmd "echo \"deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main\" | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null"; then
						if run_cmd "sudo apt update >/dev/null 2>&1 && sudo apt install -y code >/dev/null 2>&1"; then
							log_success "VS Code installed via apt repository"
							track_installed "vscode" "code editor"
							verify_installed code vscode "code editor"
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
				log_info "Installing VS Code via Microsoft yum repository..."
				if run_cmd "sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc >/dev/null 2>&1"; then
					if run_cmd "sudo sh -c 'echo -e \"[code]\\nname=Visual Studio Code\\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\\nenabled=1\\ngpgcheck=1\\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc\" > /etc/yum.repos.d/vscode.repo'"; then
						if run_cmd "sudo dnf install -y code >/dev/null 2>&1 || sudo yum install -y code >/dev/null 2>&1"; then
							log_success "VS Code installed via yum repository"
							track_installed "vscode" "code editor"
							verify_installed code vscode "code editor"
						else
							log_error "Failed to install VS Code"
							track_failed "vscode" "code editor"
						fi
					fi
				fi
			elif [[ "$OS" == "linux" ]] && [[ -f /etc/arch-release ]]; then
				if cmd_exists yay; then
					if run_cmd "yay -S --noconfirm visual-studio-code-bin >/dev/null 2>&1"; then
						log_success "VS Code installed via yay"
						track_installed "vscode" "code editor"
						verify_installed code vscode "code editor"
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

	if [[ "$OS" == "linux" ]] && [[ -f /etc/debian_version ]]; then
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
				if install_brew_cask "basictex" "pdflatex"; then
					log_success "LaTeX BasicTeX installed"
				fi
			elif [[ "$OS" == "linux" ]]; then
				if install_brew_package "texlive" "" "pdflatex"; then
					log_success "LaTeX TeX Live installed via brew"
				fi
			fi
		fi
	else
		log_info "LaTeX already installed"
		track_skipped "latex" "document preparation"
	fi

	current_version=""
	if cmd_exists claude; then
		current_version=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
	fi

	latest_version=""
	if cmd_exists npm; then
		latest_version=$(npm view @anthropic-ai/claude-code version 2>/dev/null)
	fi

	needs_claude_install=false
	if ! cmd_exists claude; then
		needs_claude_install=true
	elif [[ -n "$current_version" && -n "$latest_version" && "$current_version" != "$latest_version" ]]; then
		log_info "Claude Code CLI update available: $current_version -> $latest_version"
		needs_claude_install=true
	fi

	if [[ "$needs_claude_install" == "true" ]]; then
		log_step "Installing Claude Code CLI - native..."
		if [[ "$DRY_RUN" == "true" ]]; then
			log_info "[DRY-RUN] Would install Claude Code CLI"
		else
			if run_cmd "curl -fsSL https://claude.ai/install.sh | bash"; then
				ensure_path "$HOME/.local/bin"
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
		version_info=""
		if [[ -n "$current_version" ]]; then
			version_info=" ($current_version)"
		fi
		log_info "Claude Code CLI already at latest version${version_info}"
		ensure_path "$HOME/.local/bin"
		track_skipped "claude-code" "AI CLI"
	fi

	if [[ "$OS" == "linux" ]] && [[ "$CATEGORIES" == "full" ]]; then
		log_info "ComfyUI Desktop on Linux requires manual installation"
		log_info "See: https://docs.comfy.org/getting_started/installing_comfyui/linux"
	fi

	if [[ -d "$NPM_CONFIG_PREFIX" ]]; then
		npm_bin="$NPM_CONFIG_PREFIX/bin"
	else
		npm_bin="$HOME/.npm-global/bin"
	fi
	if [[ -n "$APPDATA" ]]; then
		npm_bin_alt="$APPDATA/npm"
	fi

	for shim_loc in "$npm_bin" "$npm_bin_alt"; do
		[[ -d "$shim_loc" ]] || continue
		for shim in "$shim_loc"/opencode "$shim_loc"/opencode.cmd; do
			if [[ -f "$shim" ]]; then
				log_info "Removing old npm shim: $(basename "$shim")"
				rm -f "$shim" 2>/dev/null || true
			fi
		done
	done

	needs_opencode_install=false
	opencode_bin="$HOME/.opencode/bin"
	opencode_exe="$opencode_bin/opencode"

	if [[ ! -f "$opencode_exe" ]]; then
		needs_opencode_install=true
	else
		if current_version=$("$opencode_exe" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1); then
			latest_version=$(npm view opencode-ai version 2>/dev/null)
			if [[ -n "$latest_version" ]]; then
				if [[ "$current_version" == "$latest_version" ]]; then
					log_info "OpenCode AI CLI already at latest version ($current_version)"
					ensure_path "$HOME/.opencode/bin"
					track_skipped "opencode" "AI CLI"
					needs_opencode_install=false
				else
					log_info "OpenCode AI CLI update available: $current_version -> $latest_version"
					needs_opencode_install=true
				fi
			else
				needs_opencode_install=true
			fi
		else
			needs_opencode_install=true
		fi
	fi

	if [[ "$needs_opencode_install" == "true" ]]; then
		log_step "Installing OpenCode AI CLI..."
		if [[ "$DRY_RUN" == "true" ]]; then
			log_info "[DRY-RUN] Would install OpenCode AI CLI"
		else
			if run_cmd "curl -fsSL https://opencode.ai/install | bash"; then
				ensure_path "$HOME/.opencode/bin"
				fix_path_issues
				if cmd_exists opencode; then
					log_success "OpenCode AI CLI installed"
					track_installed "opencode" "AI CLI"
				else
					log_warning "OpenCode AI CLI installed but not in PATH yet"
					track_installed "opencode" "AI CLI - PATH update pending"
				fi
			else
				log_error "Failed to install OpenCode AI CLI"
				track_failed "opencode" "AI CLI"
			fi
		fi
	fi

	log_success "Development tools installation complete"
	return 0
}

deploy_configs() {
	print_header "Phase 6: Deploying Configurations"

	local deploy_script="$SCRIPT_DIR/../scripts/deploy.sh"

	if [[ ! -f "$deploy_script" ]]; then
		log_warning "deploy.sh not found at $deploy_script"
		return 0
	fi

	if [[ "$DRY_RUN" == "true" ]]; then
		log_info "[DRY-RUN] Would run: $deploy_script"
		return 0
	fi

	log_step "Running deploy script..."
	log_verbose "$deploy_script"
	bash "$deploy_script"
	log_success "Configurations deployed"
}

main() {
	print_header "Bootstrap $(capitalize "$OS") Development Environment"

	echo -e "Options:"
	echo -e "  Interactive: ${INTERACTIVE}"
	echo -e "  Dry Run: ${DRY_RUN}"
	echo -e "  Verbose: ${VERBOSE}"
	echo -e "  Categories: ${CATEGORIES}"
	echo ""

	if [[ "$INTERACTIVE" == "true" ]]; then
		if ! confirm "Proceed with bootstrap?" "n"; then
			echo "Aborted."
			exit 0
		fi
	fi

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
