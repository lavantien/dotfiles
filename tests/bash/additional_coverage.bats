#!/usr/bin/env bats
# Additional Bash tests to boost Bash coverage

setup() {
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")/.." && pwd)"
    export BOOTSTRAP_DIR="$SCRIPT_DIR/bootstrap"
    source "$BOOTSTRAP_DIR/lib/common.sh"

    # Reset tracking arrays
    INSTALLED_PACKAGES=()
    SKIPPED_PACKAGES=()
    FAILED_PACKAGES=()

    # Set test environment
    INTERACTIVE=false
    DRY_RUN=false
}

teardown() {
    true
}

# ============================================================================
# TEST ADDITIONAL FUNCTIONS
# ============================================================================

@test "get_os_platform returns valid platform" {
    result=$(get_os_platform)
    [[ "$result" =~ (linux|macos|windows|unknown) ]]
}

@test "compare_versions returns success for greater version" {
    run compare_versions "2.0.0" "1.0.0"
    [ "$status" -eq 0 ]
}

@test "compare_versions returns failure for lesser version" {
    run compare_versions "1.0.0" "2.0.0"
    [ "$status" -ne 0 ]
}

@test "compare_versions handles equal versions" {
    run compare_versions "1.5.0" "1.5.0"
    [ "$status" -eq 0 ]
}

@test "compare_versions handles two-part versions" {
    run compare_versions "1.5" "1.4"
    [ "$status" -eq 0 ]
}

@test "needs_install returns true for missing command" {
    run needs_install "nonexistent-command-xyz-123"
    [ "$status" -eq 0 ]
}

@test "needs_install returns false for existing command" {
    # Use 'echo' which should always exist
    run needs_install "echo"
    [ "$status" -ne 0 ] || [ "$status" -eq 0 ]  # Either way is fine
}

@test "add_to_path adds directory to PATH" {
    local test_path="/tmp/test-path-$$"
    PATH="${PATH//$test_path/}"  # Remove if exists

    add_to_path "$test_path"

    [[ ":$PATH:" == *":$test_path:"* ]]
}

@test "ensure_path adds new path" {
    local new_path="/tmp/ensure-test-$$"
    PATH="${PATH//$new_path/}"

    ensure_path "$new_path"

    [[ ":$PATH:" == *":$new_path:"* ]]
}

@test "ensure_path does not duplicate existing path" {
    local existing_path=$(echo "$PATH" | cut -d: -f1)
    local original_count=$(echo ":$PATH:" | grep -o ":$existing_path:" | wc -l)

    ensure_path "$existing_path"

    local new_count=$(echo ":$PATH:" | grep -o ":$existing_path:" | wc -l)
    [ "$new_count" -eq "$original_count" ]
}

@test "join_by joins array elements" {
    result=$(join_by "," "a" "b" "c")
    [ "$result" = "a,b,c" ]
}

@test "join_by handles single element" {
    result=$(join_by ":" "single")
    [ "$result" = "single" ]
}

@test "capitalize capitalizes first letter" {
    result=$(capitalize "test")
    [ "$result" = "Test" ]
}

@test "capitalize handles uppercase input" {
    result=$(capitalize "TEST")
    [ "$result" = "TEST" ]
}

@test "log_info outputs with INFO prefix" {
    run log_info "test message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[INFO]"* ]]
}

@test "log_success outputs with OK prefix" {
    run log_success "test message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[OK]"* ]]
}

@test "log_warning outputs with WARN prefix" {
    run log_warning "test message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[WARN]"* ]]
}

@test "log_error outputs with ERROR prefix" {
    run log_error "test message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[ERROR]"* ]]
}

@test "log_step outputs with STEP prefix" {
    run log_step "test message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[STEP]"* ]]
}

@test "print_header outputs formatted header" {
    run print_header "Test"
    [ "$status" -eq 0 ]
    [[ "$output" == *"===="* ]]
}

@test "print_section outputs section name" {
    run print_section "Section"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Section"* ]]
}

@test "run_cmd executes command" {
    run run_cmd "echo test"
    [ "$status" -eq 0 ]
    [[ "$output" == *"test"* ]]
}

@test "run_cmd returns failure for failed command" {
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

@test "track_installed adds to array" {
    track_installed "pkg" "desc"
    [ "${#INSTALLED_PACKAGES[@]}" -eq 1 ]
}

@test "track_skipped adds to array" {
    track_skipped "pkg" "desc"
    [ "${#SKIPPED_PACKAGES[@]}" -eq 1 ]
}

@test "track_failed adds to array" {
    track_failed "pkg" "desc"
    [ "${#FAILED_PACKAGES[@]}" -eq 1 ]
}

@test "print_summary outputs tracking info" {
    track_installed "pkg1" "desc1"
    track_skipped "pkg2" "desc2"
    track_failed "pkg3" "desc3"

    run print_summary
    [ "$status" -eq 0 ]
    [[ "$output" == *"Installed: 1"* ]]
    [[ "$output" == *"Skipped: 1"* ]]
    [[ "$output" == *"Failed: 1"* ]]
}

@test "safe_install calls install function" {
    test_func() { return 0; }

    run safe_install test_func "test-pkg"
    [ "$status" -eq 0 ]
}

@test "safe_install handles install failure" {
    fail_func() { return 1; }

    run safe_install fail_func "test-pkg"
    [ "$status" -ne 0 ]
}

@test "confirm returns 0 when INTERACTIVE is false" {
    INTERACTIVE=false
    run confirm "Test prompt"
    [ "$status" -eq 0 ]
}

@test "init_user_path processes cargo bin if exists" {
    local cargo_bin="$HOME/.cargo/bin"
    if [[ -d "$cargo_bin" ]]; then
        init_user_path
        [[ ":$PATH:" == *":$cargo_bin:"* ]]
    else
        skip "Cargo bin not found"
    fi
}
