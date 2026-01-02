#!/usr/bin/env bats
# Unit tests for lib/config.sh
# Tests configuration parsing and retrieval

setup() {
    # Load the config library
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")/.." && pwd)"
    source "$SCRIPT_DIR/lib/config.sh"

    # Reset config variables before each test
    CONFIG_EDITOR=""
    CONFIG_TERMINAL=""
    CONFIG_THEME=""
    CONFIG_CATEGORIES="full"
    CONFIG_AUTO_UPDATE_REPOS="false"
    CONFIG_BACKUP_BEFORE_DEPLOY="false"
    CONFIG_SIGN_COMMITS="false"
    CONFIG_DEFAULT_BRANCH="main"
    CONFIG_GITHUB_USERNAME=""
    CONFIG_BASE_DIR=""
    CONFIG_AUTO_COMMIT="false"
    CONFIG_SKIP_PACKAGES=""

    CONFIG_LINUX_PACKAGE_MANAGER=""
    CONFIG_LINUX_DISPLAY_SERVER=""
    CONFIG_WINDOWS_PACKAGE_MANAGER=""
    CONFIG_MACOS_PACKAGE_MANAGER=""
}

teardown() {
    # Cleanup test files
    rm -f /tmp/test-config-*.yaml
}

# ============================================================================
# LOAD CONFIG FILE
# ============================================================================

@test "load_dotfiles_config returns success when file doesn't exist" {
    run load_dotfiles_config "/tmp/nonexistent-config-xyz.yaml"
    [ "$status" -eq 0 ]
}

@test "load_dotfiles_config returns success for empty config" {
    echo "" > /tmp/test-config-empty.yaml
    run load_dotfiles_config /tmp/test-config-empty.yaml
    [ "$status" -eq 0 ]
}

@test "load_dotfiles_config uses defaults when config is empty" {
    echo "" > /tmp/test-config-empty2.yaml
    load_dotfiles_config /tmp/test-config-empty2.yaml

    [ "$CONFIG_CATEGORIES" = "full" ]
    [ "$CONFIG_AUTO_UPDATE_REPOS" = "false" ]
}

@test "_parse_config_simple parses key-value pairs" {
    cat > /tmp/test-config-simple.yaml <<EOF
editor: vim
categories: minimal
github_username: testuser
EOF
    _parse_config_simple /tmp/test-config-simple.yaml

    [ "$CONFIG_EDITOR" = "vim" ]
    [ "$CONFIG_CATEGORIES" = "minimal" ]
    [ "$CONFIG_GITHUB_USERNAME" = "testuser" ]
}

@test "_parse_config_simple handles quoted values" {
    cat > /tmp/test-config-quotes.yaml <<EOF
editor: "nvim"
base_dir: "~/dev/repos"
EOF
    _parse_config_simple /tmp/test-config-quotes.yaml

    [ "$CONFIG_EDITOR" = "nvim" ]
    [ "$CONFIG_BASE_DIR" = "~/dev/repos" ]
}

@test "_parse_config_simple handles comments" {
    cat > /tmp/test-config-comments.yaml <<EOF
# This is a comment
editor: vim  # inline comment
# Another comment
categories: full
EOF
    _parse_config_simple /tmp/test-config-comments.yaml

    [ "$CONFIG_EDITOR" = "vim" ]
    [ "$CONFIG_CATEGORIES" = "full" ]
}

@test "_parse_config_simple handles boolean values" {
    cat > /tmp/test-config-bool.yaml <<EOF
auto_update_repos: true
sign_commits: false
EOF
    _parse_config_simple /tmp/test-config-bool.yaml

    [ "$CONFIG_AUTO_UPDATE_REPOS" = "true" ]
    [ "$CONFIG_SIGN_COMMITS" = "false" ]
}

@test "_parse_config_simple handles platform-specific settings" {
    cat > /tmp/test-config-platform.yaml <<EOF
linux:
  package_manager: apt

windows:
  package_manager: scoop

macos:
  package_manager: brew
EOF
    _parse_config_simple /tmp/test-config-platform.yaml

    [ "$CONFIG_LINUX_PACKAGE_MANAGER" = "apt" ]
    [ "$CONFIG_WINDOWS_PACKAGE_MANAGER" = "scoop" ]
    [ "$CONFIG_MACOS_PACKAGE_MANAGER" = "brew" ]
}

@test "_parse_config_simple handles display_server setting" {
    cat > /tmp/test-config-display.yaml <<EOF
linux:
  display_server: wayland
EOF
    _parse_config_simple /tmp/test-config-display.yaml

    [ "$CONFIG_LINUX_DISPLAY_SERVER" = "wayland" ]
}

@test "_parse_config_simple skips empty lines" {
    cat > /tmp/test-config-blanks.yaml <<EOF

editor: vim

categories: minimal

EOF
    _parse_config_simple /tmp/test-config-blanks.yaml

    [ "$CONFIG_EDITOR" = "vim" ]
    [ "$CONFIG_CATEGORIES" = "minimal" ]
}

# ============================================================================
# CONFIG GETTERS
# ============================================================================

@test "get_config returns editor value" {
    CONFIG_EDITOR="nvim"
    result=$(get_config "editor")
    [ "$result" = "nvim" ]
}

@test "get_config returns terminal value" {
    CONFIG_TERMINAL="alacritty"
    result=$(get_config "terminal")
    [ "$result" = "alacritty" ]
}

@test "get_config returns theme value" {
    CONFIG_THEME="gruvbox-dark"
    result=$(get_config "theme")
    [ "$result" = "gruvbox-dark" ]
}

@test "get_config returns categories value" {
    CONFIG_CATEGORIES="minimal"
    result=$(get_config "categories")
    [ "$result" = "minimal" ]
}

@test "get_config returns default value when config is empty" {
    CONFIG_EDITOR=""
    result=$(get_config "editor" "vim")
    [ "$result" = "vim" ]
}

@test "get_config returns github_username value" {
    CONFIG_GITHUB_USERNAME="testuser"
    result=$(get_config "github_username")
    [ "$result" = "testuser" ]
}

@test "get_config returns base_dir value" {
    CONFIG_BASE_DIR="~/dev/github"
    result=$(get_config "base_dir")
    [ "$result" = "~/dev/github" ]
}

@test "get_config returns auto_update_repos value" {
    CONFIG_AUTO_UPDATE_REPOS="true"
    result=$(get_config "auto_update_repos")
    [ "$result" = "true" ]
}

@test "get_config returns backup_before_deploy value" {
    CONFIG_BACKUP_BEFORE_DEPLOY="true"
    result=$(get_config "backup_before_deploy")
    [ "$result" = "true" ]
}

@test "get_config returns sign_commits value" {
    CONFIG_SIGN_COMMITS="true"
    result=$(get_config "sign_commits")
    [ "$result" = "true" ]
}

@test "get_config returns default_branch value" {
    CONFIG_DEFAULT_BRANCH="develop"
    result=$(get_config "default_branch")
    [ "$result" = "develop" ]
}

@test "get_config returns auto_commit_changes value" {
    CONFIG_AUTO_COMMIT="true"
    result=$(get_config "auto_commit_changes")
    [ "$result" = "true" ]
}

@test "get_config returns linux_package_manager value" {
    CONFIG_LINUX_PACKAGE_MANAGER="dnf"
    result=$(get_config "linux_package_manager")
    [ "$result" = "dnf" ]
}

@test "get_config returns windows_package_manager value" {
    CONFIG_WINDOWS_PACKAGE_MANAGER="winget"
    result=$(get_config "windows_package_manager")
    [ "$result" = "winget" ]
}

@test "get_config returns macos_package_manager value" {
    CONFIG_MACOS_PACKAGE_MANAGER="port"
    result=$(get_config "macos_package_manager")
    [ "$result" = "port" ]
}

@test "get_config returns default for unknown key" {
    result=$(get_config "unknown_key" "default_value")
    [ "$result" = "default_value" ]
}

@test "get_config returns empty default for unknown key when no default provided" {
    result=$(get_config "unknown_key")
    [ "$result" = "" ]
}

# ============================================================================
# SKIP PACKAGE LOGIC
# ============================================================================

@test "should_skip_package returns false when skip list is empty" {
    CONFIG_SKIP_PACKAGES=""
    run should_skip_package "git"
    [ "$status" -ne 0 ]
}

@test "should_skip_package returns true when package is in skip list" {
    CONFIG_SKIP_PACKAGES="git node"
    run should_skip_package "git"
    [ "$status" -eq 0 ]
}

@test "should_skip_package returns false when package not in skip list" {
    CONFIG_SKIP_PACKAGES="node python"
    run should_skip_package "git"
    [ "$status" -ne 0 ]
}

@test "should_skip_package handles comma-separated skip list" {
    CONFIG_SKIP_PACKAGES="git,node,python"
    run should_skip_package "node"
    [ "$status" -eq 0 ]
}

@test "should_skip_package handles comma-space separated skip list" {
    CONFIG_SKIP_PACKAGES="git, node, python"
    run should_skip_package "python"
    [ "$status" -eq 0 ]
}

@test "should_skip_package handles mixed separators" {
    CONFIG_SKIP_PACKAGES="git, node python"
    run should_skip_package "node"
    [ "$status" -eq 0 ]
}

@test "should_skip_package is case sensitive" {
    CONFIG_SKIP_PACKAGES="Git"
    run should_skip_package "git"
    [ "$status" -ne 0 ]
}

@test "should_skip_package handles spaces in list" {
    CONFIG_SKIP_PACKAGES="git node   python"
    run should_skip_package "python"
    [ "$status" -eq 0 ]
}

@test "should_skip_package handles single item list" {
    CONFIG_SKIP_PACKAGES="git"
    run should_skip_package "git"
    [ "$status" -eq 0 ]
}

@test "should_skip_package returns false for different package" {
    CONFIG_SKIP_PACKAGES="git"
    run should_skip_package "node"
    [ "$status" -ne 0 ]
}

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

@test "load_dotfiles_config and get_config work together" {
    cat > /tmp/test-config-integration.yaml <<EOF
editor: nvim
categories: sdk
github_username: testuser
EOF
    load_dotfiles_config /tmp/test-config-integration.yaml

    result=$(get_config "editor")
    [ "$result" = "nvim" ]

    result=$(get_config "categories")
    [ "$result" = "sdk" ]

    result=$(get_config "github_username")
    [ "$result" = "testuser" ]
}

@test "load_dotfiles_config preserves defaults for unspecified values" {
    cat > /tmp/test-config-partial.yaml <<EOF
editor: vim
EOF
    load_dotfiles_config /tmp/test-config-partial.yaml

    result=$(get_config "editor")
    [ "$result" = "vim" ]

    result=$(get_config "categories")
    [ "$result" = "full" ]  # Default value
}

@test "load_dotfiles_config handles full config file" {
    cat > /tmp/test-config-full.yaml <<EOF
editor: nvim
terminal: alacritty
theme: gruvbox-dark
categories: minimal
auto_update_repos: true
backup_before_deploy: false
sign_commits: true
default_branch: develop
github_username: testuser
base_dir: ~/dev/github
auto_commit_changes: true
skip_packages: vim emacs
linux:
  package_manager: apt
  display_server: wayland
windows:
  package_manager: winget
macos:
  package_manager: port
EOF
    load_dotfiles_config /tmp/test-config-full.yaml

    [ "$CONFIG_EDITOR" = "nvim" ]
    [ "$CONFIG_TERMINAL" = "alacritty" ]
    [ "$CONFIG_THEME" = "gruvbox-dark" ]
    [ "$CONFIG_CATEGORIES" = "minimal" ]
    [ "$CONFIG_AUTO_UPDATE_REPOS" = "true" ]
    [ "$CONFIG_BACKUP_BEFORE_DEPLOY" = "false" ]
    [ "$CONFIG_SIGN_COMMITS" = "true" ]
    [ "$CONFIG_DEFAULT_BRANCH" = "develop" ]
    [ "$CONFIG_GITHUB_USERNAME" = "testuser" ]
    [ "$CONFIG_BASE_DIR" = "~/dev/github" ]
    [ "$CONFIG_AUTO_COMMIT" = "true" ]
    [ "$CONFIG_LINUX_PACKAGE_MANAGER" = "apt" ]
    [ "$CONFIG_LINUX_DISPLAY_SERVER" = "wayland" ]
    [ "$CONFIG_WINDOWS_PACKAGE_MANAGER" = "winget" ]
    [ "$CONFIG_MACOS_PACKAGE_MANAGER" = "port" ]
}

@test "should_skip_package works with loaded config" {
    cat > /tmp/test-config-skip.yaml <<EOF
skip_packages: git, node
EOF
    load_dotfiles_config /tmp/test-config-skip.yaml

    run should_skip_package "git"
    [ "$status" -eq 0 ]

    run should_skip_package "node"
    [ "$status" -eq 0 ]

    run should_skip_package "python"
    [ "$status" -ne 0 ]
}
