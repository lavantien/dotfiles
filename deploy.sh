#!/usr/bin/env bash
# Universal Deploy Script - Works on Linux, macOS, and Windows (Git Bash/WSL)
# Auto-detects platform and deploys appropriate configurations

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Linux*)     echo "linux" ;;
        Darwin*)    echo "macos" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *)          echo "unknown" ;;
    esac
}

OS=$(detect_os)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}Deploying dotfiles for: $OS${NC}"
echo -e "${BLUE}Script directory: $SCRIPT_DIR${NC}"

# ============================================================================
# COMMON DEPLOYMENT
# ============================================================================
deploy_common() {
    echo -e "${GREEN}Deploying common files...${NC}"

    # Create directories
    mkdir -p "$HOME/.config"

    # Copy bash aliases (works on all platforms)
    cp "$SCRIPT_DIR/.bash_aliases" "$HOME/"

    # Copy git config
    cp "$SCRIPT_DIR/.gitconfig" "$HOME/"

    # Copy Neovim config
    if [ -f "$SCRIPT_DIR/init.lua" ]; then
        mkdir -p "$HOME/.config/nvim"
        cp "$SCRIPT_DIR/init.lua" "$HOME/.config/nvim/"
    fi

    # Copy lua directory if exists
    if [ -d "$SCRIPT_DIR/lua" ]; then
        mkdir -p "$HOME/.config/nvim"
        cp -r "$SCRIPT_DIR/lua" "$HOME/.config/nvim/"
    fi

    # Copy Wezterm config
    if [ -f "$SCRIPT_DIR/wezterm.lua" ]; then
        mkdir -p "$HOME/.config/wezterm"
        cp "$SCRIPT_DIR/wezterm.lua" "$HOME/.config/wezterm/"
    fi

    # Copy git clone script
    mkdir -p "$HOME/dev"
    cp "$SCRIPT_DIR/git-clone-all.sh" "$HOME/dev/" 2>/dev/null || true

    # Copy Aider configs
    cp "$SCRIPT_DIR/.aider.conf.yml.example" "$HOME/.aider.conf.yml" 2>/dev/null || true

    echo -e "${GREEN}Common files deployed.${NC}"
}

# ============================================================================
# GIT HOOKS
# ============================================================================
deploy_git_hooks() {
    echo -e "${GREEN}Deploying git hooks...${NC}"

    local hooks_dir="$HOME/.config/git/hooks"
    mkdir -p "$hooks_dir"

    # Copy bash hooks
    cp "$SCRIPT_DIR/hooks/git/pre-commit" "$hooks_dir/"
    cp "$SCRIPT_DIR/hooks/git/commit-msg" "$hooks_dir/"
    chmod +x "$hooks_dir/pre-commit"
    chmod +x "$hooks_dir/commit-msg"

    # Configure git to use the hooks
    git config --global init.templatedir "$hooks_dir"
    git config --global core.hooksPath "$hooks_dir"

    echo -e "${GREEN}Git hooks deployed to: $hooks_dir${NC}"
}

# ============================================================================
# CLAUDE CODE HOOKS
# ============================================================================
deploy_claude_hooks() {
    echo -e "${GREEN}Deploying Claude Code hooks...${NC}"

    mkdir -p "$HOME/.claude"
    cp "$SCRIPT_DIR/hooks/claude/quality-check.ps1" "$HOME/.claude/"

    # Copy TDD guard if exists in repo
    if [ -d "$SCRIPT_DIR/.claude/tdd-guard" ]; then
        mkdir -p "$HOME/.claude/tdd-guard"
        cp -r "$SCRIPT_DIR/.claude/tdd-guard/"* "$HOME/.claude/tdd-guard/"
    fi

    echo -e "${GREEN}Claude Code hooks deployed to: $HOME/.claude${NC}"
    echo -e "${YELLOW}Add to Claude Code settings.json to enable hooks${NC}"
}

# ============================================================================
# PLATFORM-SPECIFIC
# ============================================================================
deploy_linux() {
    echo -e "${GREEN}Deploying Linux-specific configs...${NC}"

    # Copy zshrc
    if [ -f "$SCRIPT_DIR/.zshrc" ]; then
        cp "$SCRIPT_DIR/.zshrc" "$HOME/"
    fi

    # Copy environment files
    if [ -f "$SCRIPT_DIR/.env.gpt-researcher" ]; then
        mkdir -p "$HOME/dev/gpt-researcher"
        cp "$SCRIPT_DIR/.env.gpt-researcher" "$HOME/dev/gpt-researcher/.env"
    fi

    deploy_git_hooks
}

deploy_macos() {
    echo -e "${GREEN}Deploying macOS-specific configs...${NC}"

    # Copy zshrc (macOS default shell)
    if [ -f "$SCRIPT_DIR/.zshrc" ]; then
        cp "$SCRIPT_DIR/.zshrc" "$HOME/"
    fi

    deploy_git_hooks
}

deploy_windows() {
    echo -e "${GREEN}Deploying Windows-specific configs...${NC}"

    # Copy PowerShell profile
    if [ -f "$SCRIPT_DIR/Microsoft.PowerShell_profile.ps1" ]; then
        # Windows PowerShell profile path
        pwsh_dir="$HOME/Documents/PowerShell"
        legacy_dir="$HOME/Documents/WindowsPowerShell"

        if [ -d "$pwsh_dir" ] || command -v pwsh >/dev/null 2>&1; then
            mkdir -p "$pwsh_dir"
            cp "$SCRIPT_DIR/Microsoft.PowerShell_profile.ps1" "$pwsh_dir/Microsoft.PowerShell_profile.ps1"
            echo -e "${GREEN}PowerShell 7 profile deployed${NC}"
        fi

        if [ -d "$legacy_dir" ]; then
            mkdir -p "$legacy_dir"
            cp "$SCRIPT_DIR/Microsoft.PowerShell_profile.ps1" "$legacy_dir/Microsoft.PowerShell_profile.ps1"
            echo -e "${GREEN}Windows PowerShell (legacy) profile deployed${NC}"
        fi
    fi

    # Git hooks - use PowerShell versions
    local hooks_dir="$HOME/.config/git/hooks"
    mkdir -p "$hooks_dir"

    cp "$SCRIPT_DIR/hooks/git/pre-commit.ps1" "$hooks_dir/"
    cp "$SCRIPT_DIR/hooks/git/commit-msg.ps1" "$hooks_dir/"

    # Configure git
    git config --global init.templatedir "$hooks_dir"
    git config --global core.hooksPath "$hooks_dir"

    echo -e "${GREEN}Git hooks deployed (PowerShell versions)${NC}"
}

# ============================================================================
# MAIN
# ============================================================================
main() {
    deploy_common
    deploy_claude_hooks

    case $OS in
        linux)
            deploy_linux
            ;;
        macos)
            deploy_macos
            ;;
        windows)
            deploy_windows
            ;;
        *)
            echo -e "${YELLOW}Unknown OS, deploying common files only${NC}"
            deploy_linux  # Default to Linux
            ;;
    esac

    echo -e "${GREEN}=== Deployment Complete ===${NC}"
    echo -e "${YELLOW}Reload your shell to apply changes${NC}"
}

main
