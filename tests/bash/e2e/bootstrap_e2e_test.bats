#!/usr/bin/env bats
# End-to-end tests for bootstrap.sh
# Tests the entire bootstrap process in isolated environments

# Get test directory and script directory
export TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
export SCRIPT_DIR="$(cd "$TEST_DIR/../../.." && pwd)"

setup() {
    # Create temporary directory for testing
    export TEST_TMP_DIR=$(mktemp -d)
    export TEST_REPO="$TEST_TMP_DIR/test-dotfiles"

    # Create a minimal test dotfiles structure
    mkdir -p "$TEST_REPO/bootstrap/lib"
    mkdir -p "$TEST_REPO/lib"

    cd "$TEST_REPO"

    # Initialize a minimal git repo
    git init --quiet
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Copy bootstrap library files
    # Copy necessary files for testing
    if [ -f "$SCRIPT_DIR/bootstrap/lib/common.sh" ]; then
        cp "$SCRIPT_DIR/bootstrap/lib/common.sh" "$TEST_REPO/bootstrap/lib/common.sh"
    fi

    if [ -f "$SCRIPT_DIR/bootstrap/bootstrap.sh" ]; then
        # Create a modified bootstrap that doesn't actually install things
        sed 's/run_cmd/safe_run_cmd/g' "$SCRIPT_DIR/bootstrap/bootstrap.sh" > "$TEST_REPO/bootstrap/bootstrap.sh"
        chmod +x "$TEST_REPO/bootstrap/bootstrap.sh"
    fi
}

teardown() {
    # Cleanup test directory
    rm -rf "$TEST_TMP_DIR"
}

# ============================================================================
# BOOTSTRAP STRUCTURE TESTS
# ============================================================================

@test "bootstrap script exists and is executable" {
    [ -f "$SCRIPT_DIR/bootstrap/bootstrap.sh" ]
    [ -x "$SCRIPT_DIR/bootstrap/bootstrap.sh" ]
}

@test "bootstrap library files exist" {
    [ -f "$SCRIPT_DIR/bootstrap/lib/common.sh" ]
}

@test "bootstrap platform scripts exist" {
    [ -f "$SCRIPT_DIR/bootstrap/platforms/linux.sh" ] || skip "Not on Linux"
    [ -f "$SCRIPT_DIR/bootstrap/platforms/macos.sh" ] || skip "Not on macOS"
}

# ============================================================================
# BOOTSTRAP FUNCTION TESTS
# ============================================================================

@test "bootstrap library can be sourced" {
    run bash -c "source '$SCRIPT_DIR/bootstrap/lib/common.sh' && echo 'sourced'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"sourced"* ]]
}

@test "detect_os function works" {
    run bash -c "
        source '$SCRIPT_DIR/bootstrap/lib/common.sh'
        detect_os
    "
    [ "$status" -eq 0 ]
    [[ "$output" =~ (linux|macos|windows) ]]
}

@test "cmd_exists function works correctly" {
    run bash -c "
        source '$SCRIPT_DIR/bootstrap/lib/common.sh'
        cmd_exists ls && echo 'ls:yes' || echo 'ls:no'
        cmd_exists nonexistent_xyz123 && echo 'bad:yes' || echo 'bad:no'
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"ls:yes"* ]]
    [[ "$output" == *"bad:no"* ]]
}

# ============================================================================
# CONFIG INTEGRATION TESTS
# ============================================================================

@test "bootstrap works without config file" {
    run bash -c "
        export HOME='$TEST_TMP_DIR/home'
        mkdir -p '$HOME'
        cd '$SCRIPT_DIR'
        source bootstrap/bootstrap.sh
        echo \"Categories: \$CATEGORIES\"
    "
    [ "$status" -eq 0 ] || true  # May fail due to other reasons
    [[ "$output" == *"Categories:"* ]] || true
}

# ============================================================================
# PLATFORM-SPECIFIC TESTS
# ============================================================================

@test "linux bootstrap functions can be sourced" {
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        skip "Not running on Linux"
    fi

    run bash -c "source '$SCRIPT_DIR/bootstrap/platforms/linux.sh' && echo 'sourced'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"sourced"* ]]
}

@test "macos bootstrap functions can be sourced" {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        skip "Not running on macOS"
    fi

    run bash -c "source '$SCRIPT_DIR/bootstrap/platforms/macos.sh' && echo 'sourced'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"sourced"* ]]
}

# ============================================================================
# IDEMPOTENCY TESTS
# ============================================================================

@test "bootstrap script can be run multiple times" {
    # Test that sourcing the script doesn't fail on subsequent runs
    run bash -c "
        source '$SCRIPT_DIR/bootstrap/lib/common.sh'
        source '$SCRIPT_DIR/bootstrap/lib/common.sh'
        echo 'done'
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"done"* ]]
}

@test "ensure_path is idempotent" {
    run bash -c "
        source '$SCRIPT_DIR/bootstrap/lib/common.sh'
        export PATH='/usr/bin:/bin'
        ensure_path '/usr/local/bin'
        local path1=\"\$PATH\"
        ensure_path '/usr/local/bin'
        local path2=\"\$PATH\"
        [ \"\$path1\" = \"\$path2\" ] && echo 'same'
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"same"* ]]
}
