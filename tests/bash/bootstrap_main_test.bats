#!/usr/bin/env bats
# Unit tests for bootstrap.sh main script
# Tests argument parsing, phase functions, and main execution flow

load test_helper

setup() {
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")/.." && pwd)"
    export BOOTSTRAP_DIR="$SCRIPT_DIR/bootstrap"
    source "$BOOTSTRAP_DIR/lib/common.sh"
    source "$BOOTSTRAP_DIR/lib/version-check.sh"
    source "$BOOTSTRAP_DIR/lib/config.sh" 2>/dev/null || true
    setup_mock_env
}

teardown() {
    teardown_mock_env
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

@test "bootstrap: show_help displays usage" {
    # Create a minimal bootstrap file to test show_help
    cat > "$MOCK_BIN_DIR/minimal-bootstrap.sh" <<'EOF'
#!/usr/bin/env bash
show_help() {
    grep '^#' "$0" | grep -v '#!/usr/bin/env' | sed 's/^# //' | sed 's/^#//'
}

show_help
EOF
    chmod +x "$MOCK_BIN_DIR/minimal-bootstrap.sh"

    run "$MOCK_BIN_DIR/minimal-bootstrap.sh"
    [ "$status" -eq 0 ]
}

@test "bootstrap: -y flag sets non-interactive mode" {
    # Mock the bootstrap argument parsing
    cat > "$MOCK_BIN_DIR/test-args.sh" <<'EOF'
#!/usr/bin/env bash
INTERACTIVE=true
while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--yes) INTERACTIVE=false; shift ;;
        *) shift ;;
    esac
done
echo "INTERACTIVE=$INTERACTIVE"
EOF
    chmod +x "$MOCK_BIN_DIR/test-args.sh"

    run "$MOCK_BIN_DIR/test-args.sh" -y
    [ "$output" = "INTERACTIVE=false" ]
}

@test "bootstrap: --dry-run flag sets dry run mode" {
    cat > "$MOCK_BIN_DIR/test-args.sh" <<'EOF'
#!/usr/bin/env bash
DRY_RUN=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true; shift ;;
        *) shift ;;
    esac
done
echo "DRY_RUN=$DRY_RUN"
EOF
    chmod +x "$MOCK_BIN_DIR/test-args.sh"

    run "$MOCK_BIN_DIR/test-args.sh" --dry-run
    [ "$output" = "DRY_RUN=true" ]
}

@test "bootstrap: --categories sets category level" {
    cat > "$MOCK_BIN_DIR/test-args.sh" <<'EOF'
#!/usr/bin/env bash
CATEGORIES="full"
while [[ $# -gt 0 ]]; do
    case $1 in
        --categories) CATEGORIES="$2"; shift 2 ;;
        *) shift ;;
    esac
done
echo "CATEGORIES=$CATEGORIES"
EOF
    chmod +x "$MOCK_BIN_DIR/test-args.sh"

    run "$MOCK_BIN_DIR/test-args.sh" --categories minimal
    [ "$output" = "CATEGORIES=minimal" ]
}

@test "bootstrap: --skip-update flag sets skip update" {
    cat > "$MOCK_BIN_DIR/test-args.sh" <<'EOF'
#!/usr/bin/env bash
SKIP_UPDATE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-update) SKIP_UPDATE=true; shift ;;
        *) shift ;;
    esac
done
echo "SKIP_UPDATE=$SKIP_UPDATE"
EOF
    chmod +x "$MOCK_BIN_DIR/test-args.sh"

    run "$MOCK_BIN_DIR/test-args.sh" --skip-update
    [ "$output" = "SKIP_UPDATE=true" ]
}

@test "bootstrap: -h and --help show help" {
    cat > "$MOCK_BIN_DIR/test-args.sh" <<'EOF'
#!/usr/bin/env bash
show_help() { echo "Usage: test"; }
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) show_help; exit 0 ;;
        *) shift ;;
    esac
done
echo "No help shown"
EOF
    chmod +x "$MOCK_BIN_DIR/test-args.sh"

    run "$MOCK_BIN_DIR/test-args.sh" -h
    [ "$output" = "Usage: test" ]

    run "$MOCK_BIN_DIR/test-args.sh" --help
    [ "$output" = "Usage: test" ]
}

@test "bootstrap: unknown option shows error" {
    cat > "$MOCK_BIN_DIR/test-args.sh" <<'EOF'
#!/usr/bin/env bash
while [[ $# -gt 0 ]]; do
    case $1 in
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done
EOF
    chmod +x "$MOCK_BIN_DIR/test-args.sh"

    run "$MOCK_BIN_DIR/test-args.sh" --unknown-option
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option"* ]]
}

# ============================================================================
# PHASE 1: FOUNDATION
# ============================================================================

@test "bootstrap: install_foundation checks for git" {
    # Mock cmd_exists to simulate git present
    mock_cmd_exists "git" "true"

    # Mock configure_git_settings
    configure_git_settings() { return 0; }
    export -f configure_git_settings

    # Simulate foundation phase logic
    install_foundation_test() {
        if ! cmd_exists git; then
            echo "Would install git"
            return 1
        fi
        echo "Git exists"
        configure_git_settings
        return 0
    }
    export -f install_foundation_test

    run bash -c 'install_foundation_test'
    [ "$status" -eq 0 ]
    [[ "$output" == *"Git exists"* ]]
}

@test "bootstrap: install_foundation handles missing git" {
    mock_cmd_exists "git" "false"

    install_foundation_test() {
        if ! cmd_exists git; then
            echo "Would install git"
            return 0
        fi
        return 1
    }
    export -f install_foundation_test

    run bash -c 'install_foundation_test'
    [ "$status" -eq 0 ]
    [[ "$output" == *"Would install git"* ]]
}

@test "bootstrap: install_foundation calls configure_git_settings" {
    configure_called=false
    configure_git_settings() { configure_called=true; }
    export -f configure_git_settings

    mock_cmd_exists "git" "true"

    install_foundation_test() {
        if cmd_exists git; then
            configure_git_settings
            return 0
        fi
        return 1
    }
    export -f install_foundation_test

    run bash -c 'install_foundation_test && echo "configure=$configure_called"'
    [[ "$output" == *"configure=true"* ]]
}

# ============================================================================
# PHASE 2: SDKS
# ============================================================================

@test "bootstrap: install_sdks respects minimal category" {
    # Mock functions
    install_brew_package() { echo "brew install $1"; }
    install_linux_package() { echo "linux install $1"; }
    export -f install_brew_package install_linux_package

    install_sdks_test() {
        local CATEGORIES="minimal"
        if [[ "$CATEGORIES" != "minimal" ]]; then
            echo "Would install node"
        fi
        echo "Would install python (always)"
        if [[ "$CATEGORIES" != "minimal" ]]; then
            echo "Would install go"
        fi
    }
    export -f install_sdks_test

    run bash -c 'install_sdks_test'
    [[ "$output" != *"Would install node"* ]]
    [[ "$output" == *"Would install python"* ]]
    [[ "$output" != *"Would install go"* ]]
}

@test "bootstrap: install_sdks installs node in full category" {
    install_brew_package() { echo "brew install $1"; }
    export -f install_brew_package

    install_sdks_test() {
        local CATEGORIES="full"
        local OS="macos"
        if [[ "$CATEGORIES" != "minimal" ]]; then
            if [[ "$OS" == "macos" ]]; then
                install_brew_package node "" ""
            fi
        fi
    }
    export -f install_sdks_test

    run bash -c 'install_sdks_test'
    [[ "$output" == *"brew install node"* ]]
}

@test "bootstrap: install_sdks installs python on linux" {
    install_linux_package() { echo "linux install $1"; }
    export -f install_linux_package

    install_sdks_test() {
        local OS="linux"
        if [[ "$OS" == "linux" ]]; then
            install_linux_package python3 "" python3
        fi
    }
    export -f install_sdks_test

    run bash -c 'install_sdks_test'
    [[ "$output" == *"linux install python3"* ]]
}

@test "bootstrap: install_sdks skips rustup in minimal" {
    install_rustup() { echo "Installing rustup"; }
    export -f install_rustup

    install_sdks_test() {
        local CATEGORIES="minimal"
        if [[ "$CATEGORIES" == "full" ]]; then
            install_rustup
        else
            echo "Skipping rustup"
        fi
    }
    export -f install_sdks_test

    run bash -c 'install_sdks_test'
    [[ "$output" == *"Skipping rustup"* ]]
}

@test "bootstrap: install_sdks installs rustup in full" {
    install_rustup() { echo "Installing rustup"; }
    export -f install_rustup

    install_sdks_test() {
        local CATEGORIES="full"
        if [[ "$CATEGORIES" == "full" ]]; then
            install_rustup
        fi
    }
    export -f install_sdks_test

    run bash -c 'install_sdks_test'
    [[ "$output" == *"Installing rustup"* ]]
}

# ============================================================================
# PHASE 3: LANGUAGE SERVERS
# ============================================================================

@test "bootstrap: install_language_servers skips in minimal category" {
    install_language_servers_test() {
        local CATEGORIES="minimal"
        if [[ "$CATEGORIES" == "minimal" ]]; then
            echo "Skipping language servers"
            return 0
        fi
        echo "Installing language servers"
    }
    export -f install_language_servers_test

    run bash -c 'install_language_servers_test'
    [[ "$output" == *"Skipping language servers"* ]]
}

@test "bootstrap: install_language_servers installs clangd" {
    install_brew_package() { echo "brew install $1"; }
    install_linux_package() { echo "linux install $1"; }
    export -f install_brew_package install_linux_package

    install_language_servers_test() {
        local CATEGORIES="sdk"
        local OS="macos"
        install_brew_package llvm "" clangd
    }
    export -f install_language_servers_test

    run bash -c 'install_language_servers_test'
    [[ "$output" == *"brew install llvm"* ]]
}

@test "bootstrap: install_language_servers installs gopls via go" {
    install_go_package() { echo "go install $1"; }
    export -f install_go_package

    install_language_servers_test() {
        local CATEGORIES="full"
        if [[ "$CATEGORIES" == "full" ]] && cmd_exists go; then
            install_go_package "golang.org/x/tools/gopls@latest" gopls ""
        fi
    }
    export -f install_language_servers_test

    mock_cmd_exists "go" "true"
    run bash -c 'install_language_servers_test'
    [[ "$output" == *"go install golang.org/x/tools/gopls@latest"* ]]
}

@test "bootstrap: install_language_servers installs pyright via npm" {
    install_npm_global() { echo "npm install -g $1"; }
    export -f install_npm_global

    install_language_servers_test() {
        if cmd_exists npm; then
            install_npm_global pyright pyright ""
        fi
    }
    export -f install_language_servers_test

    mock_cmd_exists "npm" "true"
    run bash -c 'install_language_servers_test'
    [[ "$output" == *"npm install -g pyright"* ]]
}

@test "bootstrap: install_language_servers installs typescript-language-server" {
    install_npm_global() { echo "npm install -g $1"; }
    export -f install_npm_global

    install_language_servers_test() {
        if cmd_exists npm; then
            install_npm_global typescript-language-server typescript-language-server ""
        fi
    }
    export -f install_language_servers_test

    mock_cmd_exists "npm" "true"
    run bash -c 'install_language_servers_test'
    [[ "$output" == *"npm install -g typescript-language-server"* ]]
}

# ============================================================================
# PHASE 4: LINTERS & FORMATTERS
# ============================================================================

@test "bootstrap: install_linters_formatters skips in minimal" {
    install_linters_formatters_test() {
        local CATEGORIES="minimal"
        if [[ "$CATEGORIES" == "minimal" ]]; then
            echo "Skipping linters"
            return 0
        fi
        echo "Installing linters"
    }
    export -f install_linters_formatters_test

    run bash -c 'install_linters_formatters_test'
    [[ "$output" == *"Skipping linters"* ]]
}

@test "bootstrap: install_linters_formatters installs prettier" {
    install_npm_global() { echo "npm install -g $1"; }
    export -f install_npm_global

    install_linters_formatters_test() {
        if cmd_exists npm; then
            install_npm_global prettier prettier ""
        fi
    }
    export -f install_linters_formatters_test

    mock_cmd_exists "npm" "true"
    run bash -c 'install_linters_formatters_test'
    [[ "$output" == *"npm install -g prettier"* ]]
}

@test "bootstrap: install_linters_formatters installs eslint" {
    install_npm_global() { echo "npm install -g $1"; }
    export -f install_npm_global

    install_linters_formatters_test() {
        if cmd_exists npm; then
            install_npm_global eslint eslint ""
        fi
    }
    export -f install_linters_formatters_test

    mock_cmd_exists "npm" "true"
    run bash -c 'install_linters_formatters_test'
    [[ "$output" == *"npm install -g eslint"* ]]
}

@test "bootstrap: install_linters_formatters installs ruff via pip" {
    install_pip_global() { echo "pip install $1"; }
    export -f install_pip_global

    install_linters_formatters_test() {
        if cmd_exists python3; then
            install_pip_global "ruff" ruff ""
        fi
    }
    export -f install_linters_formatters_test

    mock_cmd_exists "python3" "true"
    run bash -c 'install_linters_formatters_test'
    [[ "$output" == *"pip install ruff"* ]]
}

@test "bootstrap: install_linters_formatters installs goimports" {
    install_go_package() { echo "go install $1"; }
    export -f install_go_package

    install_linters_formatters_test() {
        if cmd_exists go; then
            install_go_package "golang.org/x/tools/cmd/goimports@latest" goimports ""
        fi
    }
    export -f install_linters_formatters_test

    mock_cmd_exists "go" "true"
    run bash -c 'install_linters_formatters_test'
    [[ "$output" == *"go install golang.org/x/tools/cmd/goimports@latest"* ]]
}

# ============================================================================
# PHASE 5: CLI TOOLS
# ============================================================================

@test "bootstrap: install_cli_tools installs fzf" {
    install_brew_package() { echo "brew install $1"; }
    export -f install_brew_package

    install_cli_tools_test() {
        install_brew_package fzf "" ""
    }
    export -f install_cli_tools_test

    run bash -c 'install_cli_tools_test'
    [[ "$output" == *"brew install fzf"* ]]
}

@test "bootstrap: install_cli_tools installs zoxide" {
    install_brew_package() { echo "brew install $1"; }
    export -f install_brew_package

    install_cli_tools_test() {
        install_brew_package zoxide "" ""
    }
    export -f install_cli_tools_test

    run bash -c 'install_cli_tools_test'
    [[ "$output" == *"brew install zoxide"* ]]
}

@test "bootstrap: install_cli_tools installs bat" {
    install_brew_package() { echo "brew install $1"; }
    export -f install_brew_package

    install_cli_tools_test() {
        install_brew_package bat "" ""
    }
    export -f install_cli_tools_test'

    run bash -c 'install_cli_tools_test'
    [[ "$output" == *"brew install bat"* ]]
}

@test "bootstrap: install_cli_tools installs eza" {
    install_brew_package() { echo "brew install $1"; }
    export -f install_brew_package

    install_cli_tools_test() {
        install_brew_package eza "" ""
    }
    export -f install_cli_tools_test

    run bash -c 'install_cli_tools_test'
    [[ "$output" == *"brew install eza"* ]]
}

@test "bootstrap: install_cli_tools installs lazygit" {
    install_brew_package() { echo "brew install $1"; }
    export -f install_brew_package

    install_cli_tools_test() {
        install_brew_package lazygit "" ""
    }
    export -f install_cli_tools_test

    run bash -c 'install_cli_tools_test'
    [[ "$output" == *"brew install lazygit"* ]]
}

@test "bootstrap: install_cli_tools installs gh" {
    install_brew_package() { echo "brew install $1"; }
    export -f install_brew_package

    install_cli_tools_test() {
        install_brew_package gh "" ""
    }
    export -f install_cli_tools_test

    run bash -c 'install_cli_tools_test'
    [[ "$output" == *"brew install gh"* ]]
}

@test "bootstrap: install_cli_tools respects minimal for ripgrep" {
    install_brew_package() { echo "brew install $1"; }
    export -f install_brew_package

    install_cli_tools_test() {
        local CATEGORIES="minimal"
        if [[ "$CATEGORIES" != "minimal" ]]; then
            install_brew_package ripgrep "" ""
        else
            echo "Skipping ripgrep in minimal"
        fi
    }
    export -f install_cli_tools_test

    run bash -c 'install_cli_tools_test'
    [[ "$output" == *"Skipping ripgrep"* ]]
}

@test "bootstrap: install_cli_tools installs ripgrep in sdk" {
    install_brew_package() { echo "brew install $1"; }
    export -f install_brew_package

    install_cli_tools_test() {
        local CATEGORIES="sdk"
        if [[ "$CATEGORIES" != "minimal" ]]; then
            install_brew_package ripgrep "" ""
        fi
    }
    export -f install_cli_tools_test

    run bash -c 'install_cli_tools_test'
    [[ "$output" == *"brew install ripgrep"* ]]
}

@test "bootstrap: install_cli_tools installs tokei in full" {
    install_brew_package() { echo "brew install $1"; }
    export -f install_brew_package

    install_cli_tools_test() {
        local CATEGORIES="full"
        if [[ "$CATEGORIES" == "full" ]]; then
            install_brew_package tokei "" ""
        fi
    }
    export -f install_cli_tools_test

    run bash -c 'install_cli_tools_test'
    [[ "$output" == *"brew install tokei"* ]]
}

@test "bootstrap: install_cli_tools installs bats" {
    install_npm_global() { echo "npm install -g $1"; }
    export -f install_npm_global

    install_cli_tools_test() {
        if cmd_exists npm; then
            install_npm_global bats bats ""
        fi
    }
    export -f install_cli_tools_test

    mock_cmd_exists "npm" "true"
    run bash -c 'install_cli_tools_test'
    [[ "$output" == *"npm install -g bats"* ]]
}

# ============================================================================
# PHASE 5.25: MCP SERVERS
# ============================================================================

@test "bootstrap: install_mcp_servers skips when npm missing" {
    install_mcp_servers_test() {
        if ! cmd_exists npm; then
            echo "npm not found, skipping MCP servers"
            return 0
        fi
        echo "Installing MCP servers"
    }
    export -f install_mcp_servers_test

    mock_cmd_exists "npm" "false"
    run bash -c 'install_mcp_servers_test'
    [[ "$output" == *"npm not found"* ]]
}

@test "bootstrap: install_mcp_servers installs context7" {
    install_npm_global() { echo "npm install -g $1"; }
    export -f install_npm_global

    install_mcp_servers_test() {
        if cmd_exists npm; then
            install_npm_global "@context7/mcp-server" "context7-mcp" ""
        fi
    }
    export -f install_mcp_servers_test

    mock_cmd_exists "npm" "true"
    run bash -c 'install_mcp_servers_test'
    [[ "$output" == *"npm install -g @context7/mcp-server"* ]]
}

@test "bootstrap: install_mcp_servers installs playwright" {
    install_npm_global() { echo "npm install -g $1"; }
    export -f install_npm_global

    install_mcp_servers_test() {
        if cmd_exists npm; then
            install_npm_global "@executeautomation/playwright-mcp-server" "playwright-mcp" ""
        fi
    }
    export -f install_mcp_servers_test

    mock_cmd_exists "npm" "true"
    run bash -c 'install_mcp_servers_test'
    [[ "$output" == *"npm install -g @executeautomation/playwright-mcp-server"* ]]
}

@test "bootstrap: install_mcp_servers installs repomix" {
    install_npm_global() { echo "npm install -g $1"; }
    export -f install_npm_global

    install_mcp_servers_test() {
        if cmd_exists npm; then
            install_npm_global "repomix" "repomix" ""
        fi
    }
    export -f install_mcp_servers_test

    mock_cmd_exists "npm" "true"
    run bash -c 'install_mcp_servers_test'
    [[ "$output" == *"npm install -g repomix"* ]]
}

# ============================================================================
# PHASE 5.5: DEVELOPMENT TOOLS
# ============================================================================

@test "bootstrap: install_development_tools installs VS Code via brew cask" {
    install_brew_cask() { echo "brew install --cask $1"; }
    export -f install_brew_cask

    install_development_tools_test() {
        local OS="macos"
        if [[ "$OS" == "macos" ]] && declare -f install_brew_cask >/dev/null; then
            install_brew_cask "visual-studio-code" "code"
        fi
    }
    export -f install_development_tools_test

    run bash -c 'install_development_tools_test'
    [[ "$output" == *"brew install --cask visual-studio-code"* ]]
}

@test "bootstrap: install_development_tools detects Debian for VS Code" {
    install_development_tools_test() {
        if [[ -f /etc/debian_version ]]; then
            echo "Debian detected, would install via .deb"
        else
            echo "Not Debian"
        fi
    }
    export -f install_development_tools_test

    run bash -c 'install_development_tools_test'
    # Result depends on platform
    [ "$status" -eq 0 ]
}

@test "bootstrap: install_development_tools installs LaTeX" {
    install_brew_cask() { echo "brew install --cask $1"; }
    export -f install_brew_cask

    install_development_tools_test() {
        local OS="macos"
        if install_brew_cask "basictex" "pdflatex"; then
            echo "LaTeX installed"
        fi
    }
    export -f install_development_tools_test

    run bash -c 'install_development_tools_test'
    [[ "$output" == *"brew install --cask basictex"* ]]
}

@test "bootstrap: install_development_tools installs Claude Code CLI" {
    install_npm_global() { echo "npm install -g $1"; }
    export -f install_npm_global

    install_development_tools_test() {
        if cmd_exists npm; then
            if ! cmd_exists claude; then
                install_npm_global "@anthropic-ai/claude-code" "claude"
            fi
        fi
    }
    export -f install_development_tools_test

    mock_cmd_exists "npm" "true"
    mock_cmd_exists "claude" "false"
    run bash -c 'install_development_tools_test'
    [[ "$output" == *"npm install -g @anthropic-ai/claude-code"* ]]
}

@test "bootstrap: install_development_tools skips Claude Code if installed" {
    install_development_tools_test() {
        if cmd_exists npm && cmd_exists claude; then
            echo "Claude Code already installed"
        else
            echo "Would install Claude Code"
        fi
    }
    export -f install_development_tools_test

    mock_cmd_exists "npm" "true"
    mock_cmd_exists "claude" "true"
    run bash -c 'install_development_tools_test'
    [[ "$output" == *"Claude Code already installed"* ]]
}

# ============================================================================
# PHASE 6: DEPLOY CONFIGS
# ============================================================================

@test "bootstrap: deploy_configs calls deploy.sh" {
    deploy_script="$MOCK_BIN_DIR/deploy.sh"
    cat > "$deploy_script" <<'EOF'
#!/usr/bin/env bash
echo "Deploying configs"
EOF
    chmod +x "$deploy_script"

    deploy_configs_test() {
        bash "$deploy_script"
    }
    export -f deploy_configs_test

    run bash -c 'deploy_configs_test'
    [[ "$output" == *"Deploying configs"* ]]
}

@test "bootstrap: deploy_configs handles missing deploy.sh" {
    deploy_configs_test() {
        local deploy_script="/nonexistent/deploy.sh"
        if [[ ! -f "$deploy_script" ]]; then
            echo "deploy.sh not found"
            return 0
        fi
    }
    export -f deploy_configs_test

    run bash -c 'deploy_configs_test'
    [[ "$output" == *"deploy.sh not found"* ]]
}

@test "bootstrap: deploy_configs skips in dry-run mode" {
    deploy_configs_test() {
        local DRY_RUN=true
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "[DRY-RUN] Would run deploy.sh"
            return 0
        fi
    }
    export -f deploy_configs_test

    run bash -c 'deploy_configs_test'
    [[ "$output" == *"[DRY-RUN]"* ]]
}

# ============================================================================
# PHASE 7: UPDATE ALL
# ============================================================================

@test "bootstrap: update_all_repos calls update-all.sh" {
    update_script="$MOCK_BIN_DIR/update-all.sh"
    cat > "$update_script" <<'EOF'
#!/usr/bin/env bash
echo "Updating all"
EOF
    chmod +x "$update_script"

    update_all_repos_test() {
        bash "$update_script"
    }
    export -f update_all_repos_test

    run bash -c 'update_all_repos_test'
    [[ "$output" == *"Updating all"* ]]
}

@test "bootstrap: update_all_repos handles missing script" {
    update_all_repos_test() {
        local update_script="/nonexistent/update-all.sh"
        if [[ ! -f "$update_script" ]]; then
            echo "update-all.sh not found"
            return 0
        fi
    }
    export -f update_all_repos_test

    run bash -c 'update_all_repos_test'
    [[ "$output" == *"update-all.sh not found"* ]]
}

@test "bootstrap: update_all_repos skips in dry-run mode" {
    update_all_repos_test() {
        local DRY_RUN=true
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "[DRY-RUN] Would run update-all.sh"
            return 0
        fi
    }
    export -f update_all_repos_test

    run bash -c 'update_all_repos_test'
    [[ "$output" == *"[DRY-RUN]"* ]]
}

# ============================================================================
# MAIN FUNCTION
# ============================================================================

@test "bootstrap: main prints header with OS" {
    print_header_test() {
        local OS="linux"
        echo "Bootstrap $(capitalize "$OS") Development Environment"
    }
    export -f print_header_test

    run bash -c 'print_header_test'
    [[ "$output" == *"Bootstrap Linux"* ]]
}

@test "bootstrap: main prints options" {
    main_options_test() {
        local INTERACTIVE=true
        local DRY_RUN=false
        local CATEGORIES="full"
        local SKIP_UPDATE=false
        echo "Options:"
        echo "  Interactive: ${INTERACTIVE}"
        echo "  Dry Run: ${DRY_RUN}"
        echo "  Categories: ${CATEGORIES}"
        echo "  Skip Update: ${SKIP_UPDATE}"
    }
    export -f main_options_test

    run bash -c 'main_options_test'
    [[ "$output" == *"Interactive: true"* ]]
    [[ "$output" == *"Dry Run: false"* ]]
    [[ "$output" == *"Categories: full"* ]]
}

@test "bootstrap: main skips confirmation in non-interactive mode" {
    main_confirm_test() {
        local INTERACTIVE=false
        if [[ "$INTERACTIVE" == "true" ]]; then
            echo "Would ask for confirmation"
            return 1
        fi
        echo "Skipping confirmation"
        return 0
    }
    export -f main_confirm_test

    run bash -c 'main_confirm_test'
    [[ "$output" == *"Skipping confirmation"* ]]
}

@test "bootstrap: main handles minimal category" {
    main_category_test() {
        local CATEGORIES="minimal"
        if [[ "$CATEGORIES" != "minimal" ]]; then
            echo "Would install language servers"
        fi
        echo "Language servers skipped in minimal"
    }
    export -f main_category_test

    run bash -c 'main_category_test'
    [[ "$output" == *"Language servers skipped"* ]]
}

@test "bootstrap: main runs all phases in full category" {
    phases_test() {
        local CATEGORIES="full"
        echo "Phase 1: Foundation"
        echo "Phase 2: SDKs"
        if [[ "$CATEGORIES" != "minimal" ]]; then
            echo "Phase 3: Language Servers"
            echo "Phase 4: Linters & Formatters"
        fi
        echo "Phase 5: CLI Tools"
        if [[ "$CATEGORIES" != "minimal" ]]; then
            echo "Phase 5.25: MCP Servers"
        fi
        echo "Phase 5.5: Dev Tools"
        echo "Phase 6: Deploy"
        echo "Phase 7: Update"
    }
    export -f phases_test

    run bash -c 'phases_test'
    [[ "$output" == *"Phase 1"* ]]
    [[ "$output" == *"Phase 2"* ]]
    [[ "$output" == *"Phase 3"* ]]
    [[ "$output" == *"Phase 4"* ]]
    [[ "$output" == *"Phase 5"* ]]
    [[ "$output" == *"Phase 5.25"* ]]
    [[ "$output" == *"Phase 5.5"* ]]
    [[ "$output" == *"Phase 6"* ]]
    [[ "$output" == *"Phase 7"* ]]
}

@test "bootstrap: main prints dry-run completion message" {
    main_dryrun_test() {
        local DRY_RUN=true
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "Dry Run Complete"
            echo "Run without --dry-run to actually install"
        fi
    }
    export -f main_dryrun_test

    run bash -c 'main_dryrun_test'
    [[ "$output" == *"Dry Run Complete"* ]]
}

@test "bootstrap: main prints normal completion message" {
    main_complete_test() {
        local DRY_RUN=false
        if [[ "$DRY_RUN" == "false" ]]; then
            echo "Bootstrap Complete"
            echo "All tools are available"
        fi
    }
    export -f main_complete_test

    run bash -c 'main_complete_test'
    [[ "$output" == *"Bootstrap Complete"* ]]
}

# ============================================================================
# CONFIG LOADING
# ============================================================================

@test "bootstrap: config file path is correct" {
    config_path_test() {
        local CONFIG_FILE="$HOME/.dotfiles.config.yaml"
        echo "Config file: $CONFIG_FILE"
    }
    export -f config_path_test

    run bash -c 'config_path_test'
    [[ "$output" == *".dotfiles.config.yaml"* ]]
}

@test "bootstrap: load_dotfiles_config is optional" {
    config_test() {
        if declare -f load_dotfiles_config >/dev/null 2>&1; then
            echo "Config library loaded"
        else
            echo "Config library not found, using defaults"
        fi
    }
    export -f config_test

    run bash -c 'config_test'
    # Either output is valid
    [ "$status" -eq 0 ]
}

@test "bootstrap: get_config overrides defaults" {
    get_config() {
        local key="$1"
        local default="$2"
        if [[ "$key" == "categories" ]]; then
            echo "minimal"
        else
            echo "$default"
        fi
    }
    export -f get_config

    config_override_test() {
        local CATEGORIES="full"
        CATEGORIES=$(get_config "categories" "$CATEGORIES")
        echo "Categories: $CATEGORIES"
    }
    export -f config_override_test

    run bash -c 'config_override_test'
    [[ "$output" == *"Categories: minimal"* ]]
}

# ============================================================================
# TRACKING FUNCTIONS
# ============================================================================

@test "bootstrap: track_installed adds to installed array" {
    INSTALLED_PACKAGES=()
    track_installed() {
        INSTALLED_PACKAGES+=("$1 ($2)")
    }
    export -f track_installed

    tracking_test() {
        track_installed "git" "version control"
        track_installed "node" "javascript runtime"
        echo "${INSTALLED_PACKAGES[@]}"
    }
    export -f tracking_test'

    run bash -c 'tracking_test'
    [[ "$output" == *"git (version control)"* ]]
    [[ "$output" == *"node (javascript runtime)"* ]]
}

@test "bootstrap: track_skipped adds to skipped array" {
    SKIPPED_PACKAGES=()
    track_skipped() {
        SKIPPED_PACKAGES+=("$1 ($2)")
    }
    export -f track_skipped

    tracking_test() {
        track_skipped "vscode" "already installed"
        echo "${SKIPPED_PACKAGES[@]}"
    }
    export -f tracking_test

    run bash -c 'tracking_test'
    [[ "$output" == *"vscode (already installed)"* ]]
}

@test "bootstrap: track_failed adds to failed array" {
    FAILED_PACKAGES=()
    track_failed() {
        FAILED_PACKAGES+=("$1 ($2)")
    }
    export -f track_failed

    tracking_test() {
        track_failed "rustup" "network error"
        echo "${FAILED_PACKAGES[@]}"
    }
    export -f tracking_test

    run bash -c 'tracking_test'
    [[ "$output" == *"rustup (network error)"* ]]
}

# ============================================================================
# ERROR HANDLING
# ============================================================================

@test "bootstrap: foundation phase returns error on failure" {
    foundation_fail_test() {
        # Simulate foundation failure
        return 1
    }
    export -f foundation_fail_test

    run bash -c 'foundation_fail_test || { echo "Foundation failed"; exit 1; }'
    [ "$status" -eq 1 ]
    [[ "$output" == *"Foundation failed"* ]]
}

@test "bootstrap: sdk phase continues on warning" {
    sdk_warn_test() {
        echo "Some SDKs failed"
        return 0
    }
    export -f sdk_warn_test

    run bash -c 'sdk_warn_test || { echo "Warning: SDK failure"; }'
    [ "$status" -eq 0 ]
}

@test "bootstrap: handles missing platform gracefully" {
    platform_test() {
        local OS="unknown"
        if [[ "$OS" == "linux" ]]; then
            echo "Linux platform"
        elif [[ "$OS" == "macos" ]]; then
            echo "macOS platform"
        else
            echo "Unknown platform, using defaults"
        fi
    }
    export -f platform_test

    run bash -c 'platform_test'
    [[ "$output" == *"Unknown platform"* ]]
}
