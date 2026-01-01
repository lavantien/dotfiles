#!/usr/bin/env bats
# Unit tests for bootstrap.sh
# Tests parameter parsing, platform detection, and core functions

setup() {
    # Load the bootstrap functions
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")/.." && pwd)"
    export BOOTSTRAP_DIR="$SCRIPT_DIR/bootstrap"
    source "$BOOTSTRAP_DIR/lib/common.sh"
}

teardown() {
    # Cleanup
    true
}

# ============================================================================
# PLATFORM DETECTION
# ============================================================================

@test "detect_os returns linux on Linux" {
    if [[ "$OSTYPE" == "linux-gnu" ]]; then
        result=$(detect_os)
        [ "$result" = "linux" ]
    else
        skip "Not running on Linux"
    fi
}

@test "detect_os returns macos on macOS" {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        result=$(detect_os)
        [ "$result" = "macos" ]
    else
        skip "Not running on macOS"
    fi
}

@test "detect_os returns windows on Git Bash" {
    if [[ "$OSTYPE" == "msys" ]]; then
        result=$(detect_os)
        [ "$result" = "windows" ]
    else
        skip "Not running on Git Bash/MSYS"
    fi
}

# ============================================================================
# COMMAND EXISTENCE CHECK
# ============================================================================

@test "cmd_exists returns success for existing commands" {
    run cmd_exists ls
    [ "$status" -eq 0 ]
}

@test "cmd_exists returns failure for non-existent commands" {
    run cmd_exists nonexistent_command_xyz123
    [ "$status" -eq 1 ]
}

# ============================================================================
# CONFIRMATION PROMPT
# ============================================================================

@test "confirm accepts y/yes" {
    # This test is hard to automate without input mocking
    skip "Requires interactive input testing"
}

# ============================================================================
# PATH MANAGEMENT
# ============================================================================

@test "ensure_path adds new path to PATH" {
    local new_path="/tmp/test-path-$RANDOM"
    local original_path="$PATH"

    ensure_path "$new_path"

    [[ ":$PATH:" == *":$new_path:"* ]]

    # Restore PATH
    export PATH="$original_path"
}

@test "ensure_path does not duplicate existing paths" {
    local existing_path=$(echo "$PATH" | cut -d: -f1)
    local original_path="$PATH"

    ensure_path "$existing_path"

    # Count occurrences of the path
    count=$(echo ":$PATH:" | grep -o ":$existing_path:" | wc -l)

    [ "$count" -eq 1 ]

    # Restore PATH
    export PATH="$original_path"
}

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

@test "log_info outputs info message" {
    run log_info "test message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[INFO] test message"* ]]
}

@test "log_success outputs success message" {
    run log_success "test message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[OK] test message"* ]]
}

@test "log_warning outputs warning message" {
    run log_warning "test message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[WARN] test message"* ]]
}

@test "log_error outputs error message" {
    run log_error "test message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[ERROR] test message"* ]]
}

# ============================================================================
# HELPERS
# ============================================================================

@test "capitalize first letter" {
    run capitalize "hello"
    [ "$output" = "Hello" ]
}

@test "join_by joins strings with delimiter" {
    run join_by "," "a" "b" "c"
    [ "$output" = "a,b,c" ]
}
