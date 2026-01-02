#!/usr/bin/env bats
# Unit tests for bootstrap/lib/common.sh
# Tests core bootstrap library functions

setup() {
    # Load the bootstrap common library
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")/.." && pwd)"
    export BOOTSTRAP_DIR="$SCRIPT_DIR/bootstrap"
    source "$BOOTSTRAP_DIR/lib/common.sh"

    # Reset tracking arrays before each test
    INSTALLED_PACKAGES=()
    SKIPPED_PACKAGES=()
    FAILED_PACKAGES=()
}

teardown() {
    # Cleanup
    true
}

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

@test "log_info outputs info message" {
    run log_info "test message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[INFO]"* ]]
    [[ "$output" == *"test message"* ]]
}

@test "log_success outputs success message" {
    run log_success "test message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[OK]"* ]]
    [[ "$output" == *"test message"* ]]
}

@test "log_warning outputs warning message" {
    run log_warning "test message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[WARN]"* ]]
    [[ "$output" == *"test message"* ]]
}

@test "log_error outputs error message" {
    run log_error "test message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[ERROR]"* ]]
    [[ "$output" == *"test message"* ]]
}

@test "log_step outputs step message" {
    run log_step "test message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[STEP]"* ]]
    [[ "$output" == *"test message"* ]]
}

@test "print_header outputs formatted header" {
    run print_header "Test Section"
    [ "$status" -eq 0 ]
    [[ "$output" == *"==== Test Section ===="* ]]
}

@test "print_section outputs section name" {
    run print_section "Test Section"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Test Section"* ]]
}

# ============================================================================
# PROGRESS TRACKING
# ============================================================================

@test "track_installed adds package to installed array" {
    track_installed "test-package" "description"

    [ "${#INSTALLED_PACKAGES[@]}" -eq 1 ]
    [[ "${INSTALLED_PACKAGES[0]}" == "test-package (description)" ]]
}

@test "track_installed adds package without description" {
    track_installed "test-package"

    [ "${#INSTALLED_PACKAGES[@]}" -eq 1 ]
    [[ "${INSTALLED_PACKAGES[0]}" == "test-package" ]]
}

@test "track_skipped adds package to skipped array" {
    track_skipped "test-package" "description"

    [ "${#SKIPPED_PACKAGES[@]}" -eq 1 ]
    [[ "${SKIPPED_PACKAGES[0]}" == "test-package (description)" ]]
}

@test "track_failed adds package to failed array" {
    track_failed "test-package" "description"

    [ "${#FAILED_PACKAGES[@]}" -eq 1 ]
    [[ "${FAILED_PACKAGES[0]}" == "test-package (description)" ]]
}

@test "print_summary outputs all tracking arrays" {
    track_installed "pkg1" "installed package"
    track_skipped "pkg2" "skipped package"
    track_failed "pkg3" "failed package"

    run print_summary
    [ "$status" -eq 0 ]
    [[ "$output" == *"Installed: 1"* ]]
    [[ "$output" == *"Skipped: 1"* ]]
    [[ "$output" == *"Failed: 1"* ]]
    [[ "$output" == *"pkg1 (installed package)"* ]]
    [[ "$output" == *"pkg2 (skipped package)"* ]]
    [[ "$output" == *"pkg3 (failed package)"* ]]
}

@test "print_summary handles empty arrays" {
    run print_summary
    [ "$status" -eq 0 ]
    [[ "$output" == *"Installed: 0"* ]]
    [[ "$output" == *"Skipped: 0"* ]]
}

# ============================================================================
# COMMAND EXISTENCE CHECK
# ============================================================================

@test "cmd_exists returns success for existing commands" {
    run cmd_exists "ls"
    [ "$status" -eq 0 ]
}

@test "cmd_exists returns success for echo" {
    run cmd_exists "echo"
    [ "$status" -eq 0 ]
}

@test "cmd_exists returns failure for non-existent commands" {
    run cmd_exists "nonexistent_command_xyz123"
    [ "$status" -ne 0 ]
}

@test "cmd_exists returns failure for empty string" {
    run cmd_exists ""
    [ "$status" -ne 0 ]
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

@test "detect_os returns windows on Git Bash/MSYS" {
    if [[ "$OSTYPE" == "msys" ]] || [[ -n "$MSYSTEM" ]]; then
        result=$(detect_os)
        [ "$result" = "windows" ]
    else
        skip "Not running on Git Bash/MSYS"
    fi
}

@test "is_windows returns true on Git Bash/MSYS" {
    if [[ "$OSTYPE" == "msys" ]] || [[ -n "$MSYSTEM" ]]; then
        run is_windows
        [ "$status" -eq 0 ]
    else
        skip "Not running on Git Bash/MSYS"
    fi
}

@test "is_windows returns false on Linux/macOS" {
    if [[ "$OSTYPE" == "linux-gnu" ]] || [[ "$OSTYPE" == "darwin"* ]]; then
        run is_windows
        [ "$status" -ne 0 ]
    else
        skip "Running on Windows"
    fi
}

@test "should_use_sudo returns false on Windows" {
    if [[ "$OSTYPE" == "msys" ]] || [[ -n "$MSYSTEM" ]]; then
        run should_use_sudo
        [ "$status" -ne 0 ]
    else
        skip "Not running on Windows"
    fi
}

@test "should_use_sudo returns true on Linux/macOS" {
    if [[ "$OSTYPE" == "linux-gnu" ]] || [[ "$OSTYPE" == "darwin"* ]]; then
        run should_use_sudo
        [ "$status" -eq 0 ]
    else
        skip "Running on Windows"
    fi
}

@test "detect_distro returns distro name on Linux" {
    if [[ -f /etc/os-release ]]; then
        result=$(detect_distro)
        [[ "$result" != "unknown" ]]
    else
        skip "/etc/os-release not found"
    fi
}

@test "get_distro_family returns correct family" {
    if [[ -f /etc/os-release ]]; then
        result=$(get_distro_family)
        [[ "$result" =~ ^(debian|fedora|arch|opensuse|unknown)$ ]]
    else
        skip "/etc/os-release not found"
    fi
}

# ============================================================================
# CONFIRMATION PROMPT
# ============================================================================

@test "confirm returns 0 when INTERACTIVE is false" {
    INTERACTIVE=false
    run confirm "Test prompt"
    [ "$status" -eq 0 ]
}

@test "confirm returns 0 when default is y" {
    if [[ "$INTERACTIVE" != "false" ]]; then
        INTERACTIVE=false  # Force non-interactive for test
    fi
    run confirm "Test prompt" "y"
    [ "$status" -eq 0 ]
}

# ============================================================================
# COMMAND EXECUTION WRAPPERS
# ============================================================================

@test "run_cmd executes command successfully" {
    run run_cmd "echo test"
    [ "$status" -eq 0 ]
    [[ "$output" == *"test"* ]]
}

@test "run_cmd handles command failure" {
    run run_cmd "false"
    [ "$status" -ne 0 ]
}

@test "run_cmd shows dry-run message when DRY_RUN is true" {
    DRY_RUN=true
    run run_cmd "echo test"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[DRY-RUN]"* ]]
    DRY_RUN=false
}

@test "safe_install executes install function successfully" {
    test_install_func() {
        return 0
    }

    run safe_install test_install_func "test-package"
    [ "$status" -eq 0 ]
}

@test "safe_install handles install failure" {
    failing_install_func() {
        return 1
    }

    run safe_install failing_install_func "test-package"
    [ "$status" -ne 0 ]
}

@test "safe_install tracks failed package" {
    failing_install_func() {
        return 1
    }

    safe_install failing_install_func "test-package"
    [ "${#FAILED_PACKAGES[@]}" -eq 1 ]
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

@test "init_user_path adds cargo bin to PATH if exists" {
    local cargo_bin="$HOME/.cargo/bin"

    if [[ -d "$cargo_bin" ]]; then
        init_user_path
        [[ ":$PATH:" == *":$cargo_bin:"* ]]
    else
        skip "Cargo bin directory does not exist"
    fi
}

# ============================================================================
# STATE MANAGEMENT
# ============================================================================

@test "save_state writes to state file" {
    local test_state_file="/tmp/test-state-$RANDOM"
    STATE_FILE="$test_state_file"

    save_state "test-tool" "1.0.0"

    [ -f "$test_state_file" ]
    grep -q "test-tool|1.0.0" "$test_state_file"

    rm -f "$test_state_file"
}

@test "save_state includes timestamp" {
    local test_state_file="/tmp/test-state-$RANDOM"
    STATE_FILE="$test_state_file"

    save_state "test-tool" "1.0.0"

    # Check for pipe-delimited format with 3 fields
    line=$(cat "$test_state_file")
    field_count=$(echo "$line" | awk -F'|' '{print NF}')
    [ "$field_count" -eq 3 ]

    rm -f "$test_state_file"
}

@test "get_installed_state returns version for installed tool" {
    local test_state_file="/tmp/test-state-$RANDOM"
    STATE_FILE="$test_state_file"

    save_state "test-tool" "1.0.0"

    result=$(get_installed_state "test-tool")
    [ "$result" = "1.0.0" ]

    rm -f "$test_state_file"
}

@test "get_installed_state returns empty for non-existent tool" {
    local test_state_file="/tmp/test-state-$RANDOM"
    STATE_FILE="$test_state_file"

    result=$(get_installed_state "nonexistent-tool")
    [ -z "$result" ]

    rm -f "$test_state_file"
}

@test "get_installed_state returns empty when state file doesn't exist" {
    local test_state_file="/tmp/test-state-$RANDOM"
    STATE_FILE="$test_state_file"

    result=$(get_installed_state "test-tool")
    [ -z "$result" ]
}

@test "get_installed_state returns latest version for multiple entries" {
    local test_state_file="/tmp/test-state-$RANDOM"
    STATE_FILE="$test_state_file"

    save_state "test-tool" "1.0.0"
    save_state "test-tool" "2.0.0"

    result=$(get_installed_state "test-tool")
    [ "$result" = "2.0.0" ]

    rm -f "$test_state_file"
}

# ============================================================================
# HELPERS
# ============================================================================

@test "capitalize capitalizes first letter" {
    result=$(capitalize "test")
    [ "$result" = "Test" ]
}

@test "capitalize handles single character" {
    result=$(capitalize "a")
    [ "$result" = "A" ]
}

@test "capitalize handles already capitalized string" {
    result=$(capitalize "Test")
    [ "$result" = "Test" ]
}

@test "join_by joins array with delimiter" {
    result=$(join_by "," "a" "b" "c")
    [ "$result" = "a,b,c" ]
}

@test "join_by handles single element" {
    result=$(join_by "," "a")
    [ "$result" = "a" ]
}

@test "join_by handles space delimiter" {
    result=$(join_by " " "a" "b" "c")
    [ "$result" = "a b c" ]
}
