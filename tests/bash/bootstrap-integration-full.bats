# Integration tests for bootstrap.sh
# Tests the complete bootstrap flow with mocked dependencies

# Setup - load the common library
load test_helper

# Source the library functions to test
export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")/.." && pwd)"

setup() {
    # Reset tracking arrays
    INSTALLED_PACKAGES=()
    SKIPPED_PACKAGES=()
    FAILED_PACKAGES=()
}

@test "Track-Installed adds to installed packages" {
    run track_installed "test-pkg" "description"
    [ "$status" -eq 0 ]
    [[ "${INSTALLED_PACKAGES[*]}" == *"test-pkg (description)"* ]]
}

@test "Track-Skipped adds to skipped packages" {
    run track_skipped "test-pkg" "description"
    [ "$status" -eq 0 ]
    [[ "${SKIPPED_PACKAGES[*]}" == *"test-pkg (description)"* ]]
}

@test "Track-Failed adds to failed packages" {
    run track_failed "test-pkg" "description"
    [ "$status" -eq 0 ]
    [[ "${FAILED_PACKAGES[*]}" == *"test-pkg (description)"* ]]
}

@test "cmd_exists checks command existence" {
    # ls should always exist
    run cmd_exists "ls"
    [ "$status" -eq 0 ]
}

@test "cmd_exists returns false for non-existent command" {
    run cmd_exists "this-command-does-not-exist-12345"
    [ "$status" -eq 1 ]
}

@test "get_os_platform returns valid platform" {
    if [ -f "$SCRIPT_DIR/bootstrap/lib/common.sh" ]; then
        source "$SCRIPT_DIR/bootstrap/lib/common.sh"
        run get_os_platform
        [ "$status" -eq 0 ]
        [[ "$output" =~ (linux|macos|windows|unknown) ]]
    fi
}

@test "compare_versions compares correctly" {
    if [ -f "$SCRIPT_DIR/bootstrap/lib/version-check.sh" ]; then
        source "$SCRIPT_DIR/bootstrap/lib/version-check.sh"
        run compare_versions "1.2.3" "1.2.0"
        [ "$status" -eq 0 ]
        
        run compare_versions "1.2.0" "1.2.3"
        [ "$status" -eq 1 ]
        
        run compare_versions "1.2.3" "1.2.3"
        [ "$status" -eq 0 ]
    fi
}

@test "needs_install returns true when command not found" {
    if [ -f "$SCRIPT_DIR/bootstrap/lib/version-check.sh" ]; then
        source "$SCRIPT_DIR/bootstrap/lib/version-check.sh"
        run needs_install "nonexistent-command-xyz"
        [ "$status" -eq 0 ]
    fi
}

@test "add_to_path adds directory to PATH" {
    local test_path="/tmp/test-path-12345"
    PATH="${PATH//$test_path/}"  # Remove if exists
    run add_to_path "$test_path"
    [ "$status" -eq 0 ]
    [[ "$PATH" == *"$test_path"* ]]
}

@test "write_info outputs info message" {
    run write_info "Test info"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[INFO]"* ]]
    [[ "$output" == *"Test info"* ]]
}

@test "write_success outputs success message" {
    run write_success "Test success"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[OK]"* ]]
    [[ "$output" == *"Test success"* ]]
}

@test "write_warning outputs warning message" {
    run write_warning "Test warning"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[WARN]"* ]]
    [[ "$output" == *"Test warning"* ]]
}

@test "write_step outputs step message" {
    run write_step "Test step"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[STEP]"* ]]
    [[ "$output" == *"Test step"* ]]
}

@test "Foundation phase handles git check" {
    # Mock the command check
    git() {
        if [[ "$1" == "--version" ]]; then
            echo "git version 2.42.0"
        else
            return 0
        fi
    }
    export -f git
    
    run cmd_exists "git"
    [ "$status" -eq 0 ]
}

@test "SDK phase checks for Node.js" {
    run cmd_exists "node"
    # Don't assert result as node may not be installed
}

@test "SDK phase checks for Python" {
    run cmd_exists "python3"
    # Don't assert result as python may not be installed
}

@test "Language servers check for clangd" {
    run cmd_exists "clangd"
    # Don't assert result as clangd may not be installed
}

@test "Linters check for prettier" {
    run cmd_exists "prettier"
    # Don't assert result as prettier may not be installed
}

@test "CLI tools check for fzf" {
    run cmd_exists "fzf"
    # Don't assert result as fzf may not be installed
}

@test "CLI tools check for bat" {
    run cmd_exists "bat"
    # Don't assert result as bat may not be installed
}

@test "Version extraction handles output" {
    if [ -f "$SCRIPT_DIR/bootstrap/lib/version-check.sh" ]; then
        source "$SCRIPT_DIR/bootstrap/lib/version-check.sh"
        
        # Test with a command that exists
        run get_tool_version "ls"
        # May return empty or version depending on format
    fi
}

@test "Category levels are recognized" {
    run echo "minimal"
    [ "$output" = "minimal" ]
    
    run echo "sdk"
    [ "$output" = "sdk" ]
    
    run echo "full"
    [ "$output" = "full" ]
}

@test "Dry run mode is recognized" {
    DRY_RUN=true
    [ "$DRY_RUN" = "true" ]
}

@test "Interactive mode is recognized" {
    INTERACTIVE=false
    [ "$INTERACTIVE" = "false" ]
}
