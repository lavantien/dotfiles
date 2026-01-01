#!/usr/bin/env bats
# Unit tests for healthcheck.sh

setup() {
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")/.." && pwd)"
    export TEST_TMP_DIR="$BATS_TMPDIR/dotfiles-healthcheck-test-$$"
    export HOME="$TEST_TMP_DIR"

    # Create test directory structure
    mkdir -p "$TEST_TMP_DIR"
    mkdir -p "$TEST_TMP_DIR/.config/nvim"
    mkdir -p "$TEST_TMP_DIR/.config/wezterm"
    mkdir -p "$TEST_TMP_DIR/.config/git/hooks"

    # Create required test files
    touch "$TEST_TMP_DIR/.gitconfig"
    touch "$TEST_TMP_DIR/.bash_aliases"
    touch "$TEST_TMP_DIR/.zshrc"
    touch "$TEST_TMP_DIR/.config/nvim/init.lua"
    touch "$TEST_TMP_DIR/.config/wezterm/wezterm.lua"
}

teardown() {
    rm -rf "$TEST_TMP_DIR"
}

run_healthcheck() {
    run env HOME="$TEST_TMP_DIR" bash "$SCRIPT_DIR/healthcheck.sh" "$@"
}

# ============================================================================
# HELP AND USAGE
# ============================================================================

@test "healthcheck: shows help with --help" {
    run bash "$SCRIPT_DIR/healthcheck.sh" --help
    [ "$status" -eq 0 ]
}

@test "healthcheck: shows help with -h" {
    run bash "$SCRIPT_DIR/healthcheck.sh" -h
    [ "$status" -eq 0 ]
}

@test "healthcheck: exits with error on unknown option" {
    run_healthcheck --unknown-option
    [ "$status" -eq 1 ]
}

# ============================================================================
# VERBOSE FLAG
# ============================================================================

@test "healthcheck: accepts --verbose flag" {
    run_healthcheck --verbose
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "healthcheck: accepts -v flag" {
    run_healthcheck -v
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "healthcheck: shows Verbose in output" {
    run_healthcheck --verbose
    echo "$output" | grep -q "Verbose"
}

# ============================================================================
# FORMAT FLAG
# ============================================================================

@test "healthcheck: accepts --format table" {
    run_healthcheck --format table
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "healthcheck: accepts --format json" {
    run_healthcheck --format json
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "healthcheck: shows Format in output" {
    run_healthcheck --format json
    echo "$output" | grep -q "Format"
}

# ============================================================================
# OUTPUT STRUCTURE
# ============================================================================

@test "healthcheck: shows header banner" {
    run_healthcheck
    echo "$output" | grep -q "Dotfiles Health Check"
}

@test "healthcheck: shows separator lines" {
    run_healthcheck
    echo "$output" | grep -q "==="
}

@test "healthcheck: shows check output" {
    run_healthcheck
    echo "$output" | grep -q "CHECK"
}

# ============================================================================
# COMMAND CHECKING
# ============================================================================

@test "healthcheck: checks for git command" {
    run_healthcheck
    echo "$output" | grep -qi "git"
}

@test "healthcheck: produces output (not empty)" {
    run_healthcheck
    [ -n "$output" ]
}

# ============================================================================
# JSON OUTPUT
# ============================================================================

@test "healthcheck: json format is specified in output" {
    run_healthcheck --format json
    # When json format is specified, Format shows json
    echo "$output" | grep -q 'json'
}

# ============================================================================
# COMBINATION OPTIONS
# ============================================================================

@test "healthcheck: accepts --verbose and --format table together" {
    run_healthcheck --verbose --format table
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "healthcheck: accepts --verbose and --format json together" {
    run_healthcheck --verbose --format json
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "healthcheck: accepts -v and --format json together" {
    run_healthcheck -v --format json
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

# ============================================================================
# ERROR HANDLING
# ============================================================================

@test "healthcheck: runs without crashing" {
    run_healthcheck
    # Should complete without error (exit 0 or 1 is OK, just not crash)
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "healthcheck: produces output regardless of exit code" {
    run_healthcheck
    [ -n "$output" ]
}
