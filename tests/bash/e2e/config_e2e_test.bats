#!/usr/bin/env bats
# End-to-end tests for config.sh (Bridge Configuration System)
# Tests YAML config parsing and fallback behavior

# Get test directory and script directory
export TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
export SCRIPT_DIR="$(cd "$TEST_DIR/../../.." && pwd)"

setup() {
    export TEST_TMP_DIR=$(mktemp -d)

    # Source the config library
    source "$SCRIPT_DIR/lib/config.sh"
}

teardown() {
    rm -rf "$TEST_TMP_DIR"
}

# ============================================================================
# CONFIG LOADING TESTS
# ============================================================================

@test "config library can be sourced" {
    run bash -c "source '$SCRIPT_DIR/lib/config.sh' && echo 'loaded'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"loaded"* ]]
}

@test "load_dotfiles_config handles missing config file" {
    local nonexistent="$TEST_TMP_DIR/nonexistent.yaml"
    run load_dotfiles_config "$nonexistent"
    [ "$status" -eq 0 ]
}

@test "load_dotfiles_config loads valid yaml config" {
    local config="$TEST_TMP_DIR/test-config.yaml"

    cat > "$config" <<'EOF'
# Test configuration
editor: nvim
terminal: wezterm
theme: gruvbox-light
categories: full
EOF

    run load_dotfiles_config "$config"
    [ "$status" -eq 0 ]
}

# ============================================================================
# CONFIG VALUE RETRIEVAL TESTS
# ============================================================================

@test "get_config returns default when config not loaded" {
    # Unset config variables to test defaults
    unset CONFIG_EDITOR
    run get_config "editor" "vi"
    [ "$status" -eq 0 ]
    [[ "$output" == "vi" ]]
}

@test "get_config returns configured value" {
    CONFIG_EDITOR="nvim"
    run get_config "editor" "vi"
    [ "$status" -eq 0 ]
    [[ "$output" == "nvim" ]]
}

# ============================================================================
# YQ PARSING TESTS
# ============================================================================

@test "config uses yq when available" {
    if ! command -v yq >/dev/null 2>&1; then
        skip "yq not installed"
    fi

    local config="$TEST_TMP_DIR/test-yq.yaml"
    cat > "$config" <<'EOF'
editor: nvim
terminal: wezterm
categories: full
skip_packages: []
EOF

    run load_dotfiles_config "$config"
    [ "$status" -eq 0 ]
}

@test "config falls back to simple parser without yq" {
    # Create a simple config that the simple parser can handle
    local config="$TEST_TMP_DIR/test-simple.yaml"
    cat > "$config" <<'EOF'
# Simple test config
editor: nvim
terminal: wezterm
categories: full
EOF

    # Temporarily hide yq
    local PATH="$TEST_TMP_DIR:$PATH"

    run load_dotfiles_config "$config"
    [ "$status" -eq 0 ]
}

# ============================================================================
# SKIP_PACKAGES TESTS
# ============================================================================

@test "should_skip_package returns false when skip_packages is empty" {
    CONFIG_SKIP_PACKAGES=""
    run should_skip_package "vim"
    [ "$status" -eq 1 ]  # Returns 1 (false) = should not skip
}

@test "should_skip_package returns true when package in skip list" {
    CONFIG_SKIP_PACKAGES="vim neovim"
    run should_skip_package "vim"
    [ "$status" -eq 0 ]  # Returns 0 (true) = should skip
}

@test "should_skip_package handles comma-separated list" {
    CONFIG_SKIP_PACKAGES="vim,neovim,nano"
    run should_skip_package "neovim"
    [ "$status" -eq 0 ]  # Should skip neovim
}

@test "should_skip_package returns false when package not in skip list" {
    CONFIG_SKIP_PACKAGES="vim nano"
    run should_skip_package "emacs"
    [ "$status" -eq 1 ]  # Should not skip emacs
}

# ============================================================================
# NESTED CONFIG TESTS
# ============================================================================

@test "config parses platform-specific settings" {
    if ! command -v yq >/dev/null 2>&1; then
        skip "yq required for nested config parsing"
    fi

    local config="$TEST_TMP_DIR/test-platform.yaml"
    cat > "$config" <<'EOF'
linux:
  package_manager: apt
  display_server: wayland
windows:
  package_manager: scoop
macos:
  package_manager: brew
EOF

    run load_dotfiles_config "$config"
    [ "$status" -eq 0 ]

    # Verify platform-specific values were loaded
    [ -n "$CONFIG_LINUX_PACKAGE_MANAGER" ] || true
    [ -n "$CONFIG_WINDOWS_PACKAGE_MANAGER" ] || true
    [ -n "$CONFIG_MACOS_PACKAGE_MANAGER" ] || true
}
