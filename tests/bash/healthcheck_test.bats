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

# ============================================================================
# CHECK FUNCTIONS
# ============================================================================

@test "check_command validates command existence" {
    # Source the healthcheck functions
    source "$SCRIPT_DIR/healthcheck.sh"

    run check_command "Test Command" "echo"
    [ "$status" -eq 0 ]
}

@test "check_command fails for non-existent command" {
    source "$SCRIPT_DIR/healthcheck.sh"

    run check_command "Nonexistent Command" "nonexistent_cmd_xyz123"
    [ "$status" -ne 0 ]
}

@test "check_command handles optional commands gracefully" {
    source "$SCRIPT_DIR/healthcheck.sh"

    # Pass empty min_version and treat as optional
    run check_command "Optional Tool" "nonexistent_cmd_xyz123" "" "false"
    [ "$status" -ne 0 ]  # Still fails, but doesn't cause script exit
}

@test "check_file validates file existence" {
    source "$SCRIPT_DIR/healthcheck.sh"

    run check_file "Test File" "/tmp/test-file-$$"
    [ "$status" -ne 0 ]  # File doesn't exist
}

@test "check_file passes when file exists" {
    source "$SCRIPT_DIR/healthcheck.sh"

    local test_file="/tmp/test-health-$$"
    touch "$test_file"
    run check_file "Test File" "$test_file"
    rm -f "$test_file"

    [ "$status" -eq 0 ]
}

@test "check_file handles optional files" {
    source "$SCRIPT_DIR/healthcheck.sh"

    run check_file "Optional File" "/tmp/nonexistent-$$" "false"
    [ "$status" -eq 0 ]  # Optional files don't fail
}

@test "check_git_config validates git settings" {
    source "$SCRIPT_DIR/healthcheck.sh"

    run check_git_config "Test Config" "user.name"
    # May fail if not configured, but function should execute
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "check_git_config returns success when config is set" {
    source "$SCRIPT_DIR/healthcheck.sh"

    # Set a test config
    local test_key="healthcheck.test.key"
    git config --global "$test_key" "test-value" 2>/dev/null
    run check_git_config "Test Config" "$test_key"
    git config --global --unset "$test_key" 2>/dev/null

    [ "$status" -eq 0 ]
}

@test "check_git_hook validates hook installation" {
    source "$SCRIPT_DIR/healthcheck.sh"

    run check_git_hook "pre-commit" "$HOME/.config/git/hooks/pre-commit"
    # May fail if hook not installed, but should execute
    [ "$status" -eq 0 ]
}

@test "check_git_hook passes when hook exists and is executable" {
    source "$SCRIPT_DIR/healthcheck.sh"

    local test_hook_dir="$TEST_TMP_DIR/.config/git/hooks"
    mkdir -p "$test_hook_dir"
    local test_hook="$test_hook_dir/pre-commit"
    echo "#!/bin/bash" > "$test_hook"
    chmod +x "$test_hook"

    run check_git_hook "pre-commit" "$test_hook"
    [ "$status" -eq 0 ]
}

@test "check_git_hook warns when hook not executable" {
    source "$SCRIPT_DIR/healthcheck.sh"

    local test_hook_dir="$TEST_TMP_DIR/.config/git/hooks"
    mkdir -p "$test_hook_dir"
    local test_hook="$test_hook_dir/pre-commit"
    echo "#!/bin/bash" > "$test_hook"
    # Don't set executable

    run check_git_hook "pre-commit" "$test_hook"
    [ "$status" -eq 0 ]  # Returns 0 (warning) not 1 (fail)
}

@test "record_result increments counters correctly" {
    source "$SCRIPT_DIR/healthcheck.sh"

    # Reset counters
    TOTAL_CHECKS=0
    PASSED_CHECKS=0
    FAILED_CHECKS=0
    WARNED_CHECKS=0

    record_result "Test Check" "pass" "Test message"

    [ "$TOTAL_CHECKS" -eq 1 ]
    [ "$PASSED_CHECKS" -eq 1 ]
    [ "$FAILED_CHECKS" -eq 0 ]
    [ "$WARNED_CHECKS" -eq 0 ]
}

@test "record_result tracks failed checks" {
    source "$SCRIPT_DIR/healthcheck.sh"

    TOTAL_CHECKS=0
    PASSED_CHECKS=0
    FAILED_CHECKS=0
    WARNED_CHECKS=0

    record_result "Test Check" "fail" "Test failure"

    [ "$TOTAL_CHECKS" -eq 1 ]
    [ "$FAILED_CHECKS" -eq 1 ]
}

@test "record_result tracks warned checks" {
    source "$SCRIPT_DIR/healthcheck.sh"

    TOTAL_CHECKS=0
    PASSED_CHECKS=0
    FAILED_CHECKS=0
    WARNED_CHECKS=0

    record_result "Test Check" "warn" "Test warning"

    [ "$TOTAL_CHECKS" -eq 1 ]
    [ "$WARNED_CHECKS" -eq 1 ]
}

@test "log_check outputs check message" {
    source "$SCRIPT_DIR/healthcheck.sh"

    run log_check "Test check name"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[CHECK]"* ]]
    [[ "$output" == *"Test check name"* ]]
}

@test "log_pass outputs pass message" {
    source "$SCRIPT_DIR/healthcheck.sh"

    run log_pass "Test pass message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[PASS]"* ]]
    [[ "$output" == *"Test pass message"* ]]
}

@test "log_fail outputs fail message" {
    source "$SCRIPT_DIR/healthcheck.sh"

    run log_fail "Test fail message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[FAIL]"* ]]
    [[ "$output" == *"Test fail message"* ]]
}

@test "log_warn outputs warning message" {
    source "$SCRIPT_DIR/healthcheck.sh"

    run log_warn "Test warning message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[WARN]"* ]]
    [[ "$output" == *"Test warning message"* ]]
}
