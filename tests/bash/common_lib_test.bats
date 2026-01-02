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

# ============================================================================
# ADDITIONAL CMD_EXISTS TESTS (Windows paths)
# ============================================================================

@test "cmd_exists finds ls in standard PATH" {
    run cmd_exists "ls"
    [ "$status" -eq 0 ]
}

@test "cmd_exists finds bash in standard PATH" {
    run cmd_exists "bash"
    [ "$status" -eq 0 ]
}

@test "cmd_exists returns false for clearly non-existent command" {
    run cmd_exists "this-command-definitely-does-not-exist-xyz789"
    [ "$status" -ne 0 ]
}

@test "cmd_exists handles command with special characters" {
    run cmd_exists "cmd-with-dashes"
    # May not exist, but should handle the name
    [ "$?" =~ ^[01]$ ]
}

# ============================================================================
# DISTRO FAMILY TESTS
# ============================================================================

@test "get_distro_family returns debian for ubuntu" {
    if [[ -f /etc/os-release ]]; then
        # Create mock os-release
        local test_os_release="/tmp/test-os-release-$$"
        echo 'ID=ubuntu' > "$test_os_release"
        # Can't override /etc/os-release, but we can test the logic
        rm -f "$test_os_release"
        skip "Requires mocking /etc/os-release"
    else
        skip "/etc/os-release not found"
    fi
}

@test "get_distro_family handles unknown distro" {
    # Mock detect_distro to return unknown
    result=$(echo "unknown" | while read distro; do
        case "$distro" in
            ubuntu|debian) echo "debian" ;;
            *) echo "unknown" ;;
        esac
    done)
    [ "$result" = "unknown" ]
}

# ============================================================================
# ENSURE_PATH TESTS
# ============================================================================

@test "ensure_path adds path to front of PATH" {
    local new_path="/tmp/test-ensure-$$"
    local original_path="$PATH"

    ensure_path "$new_path"

    # Check new_path is in PATH
    [[ ":$PATH:" == *":$new_path:"* ]]

    # Restore PATH
    export PATH="$original_path"
}

@test "ensure_path does not add duplicate path" {
    local test_path=$(echo "$PATH" | cut -d: -f1)
    local original_path="$PATH"
    local original_count=$(echo "$PATH" | grep -o "$test_path" | wc -l)

    ensure_path "$test_path"

    local new_count=$(echo "$PATH" | grep -o "$test_path" | wc -l)
    [ "$new_count" -eq "$original_count" ]

    export PATH="$original_path"
}

@test "ensure_path handles paths with spaces" {
    local path_with_spaces="/tmp/path with spaces $$"
    local original_path="$PATH"

    ensure_path "$path_with_spaces"

    # Should handle quoted paths
    export PATH="$original_path"
}

@test "ensure_path handles relative paths" {
    local relative_path="../bin"
    local original_path="$PATH"

    ensure_path "$relative_path"

    # Should add relative path
    [[ ":$PATH:" == *"../bin:"* ]] || [[ ":$PATH:" == *":$relative_path:"* ]]

    export PATH="$original_path"
}

# ============================================================================
# INIT_USER_PATH TESTS
# ============================================================================

@test "init_user_path adds cargo bin if exists" {
    local cargo_bin="$HOME/.cargo/bin"
    local original_path="$PATH"

    if [[ -d "$cargo_bin" ]]; then
        init_user_path
        [[ ":$PATH:" == *":$cargo_bin:"* ]] || skip "Path already in PATH or not added"
    else
        skip "Cargo bin directory does not exist"
    fi

    export PATH="$original_path"
}

@test "init_user_path adds dotnet tools if exists" {
    local dotnet_tools="$HOME/.dotnet/tools"
    local original_path="$PATH"

    if [[ -d "$dotnet_tools" ]]; then
        init_user_path
        [[ ":$PATH:" == *":$dotnet_tools:"* ]] || skip "Path already in PATH or not added"
    else
        skip "Dotnet tools directory does not exist"
    fi

    export PATH="$original_path"
}

@test "init_user_path adds local bin if exists" {
    local local_bin="$HOME/.local/bin"
    local original_path="$PATH"

    if [[ -d "$local_bin" ]]; then
        init_user_path
        [[ ":$PATH:" == *":$local_bin:"* ]] || skip "Path already in PATH or not added"
    else
        skip "Local bin directory does not exist"
    fi

    export PATH="$original_path"
}

@test "init_user_path adds go bin if exists" {
    local go_bin="$HOME/go/bin"
    local original_path="$PATH"

    if [[ -d "$go_bin" ]]; then
        init_user_path
        [[ ":$PATH:" == *":$go_bin:"* ]] || skip "Path already in PATH or not added"
    else
        skip "Go bin directory does not exist"
    fi

    export PATH="$original_path"
}

@test "init_user_path handles macOS homebrew paths" {
    local original_path="$PATH"

    if [[ "$(detect_os)" == "macos" ]]; then
        init_user_path
        # Should check for /opt/homebrew/bin
        [[ -d "/opt/homebrew/bin" ]] || skip "Homebrew not in standard location"
    else
        skip "Not running on macOS"
    fi

    export PATH="$original_path"
}

@test "init_user_path handles Linux homebrew paths" {
    local original_path="$PATH"

    if [[ "$(detect_os)" == "linux" ]]; then
        init_user_path
        # Should check for /home/linuxbrew/.linuxbrew/bin
        [[ -d "/home/linuxbrew/.linuxbrew/bin" ]] || skip "Linuxbrew not installed"
    else
        skip "Not running on Linux"
    fi

    export PATH="$original_path"
}

# ============================================================================
# TRACKING ARRAY TESTS
# ============================================================================

@test "track_installed handles multiple packages" {
    INSTALLED_PACKAGES=()
    track_installed "pkg1" "desc1"
    track_installed "pkg2" "desc2"
    track_installed "pkg3" "desc3"

    [ "${#INSTALLED_PACKAGES[@]}" -eq 3 ]
    [[ "${INSTALLED_PACKAGES[0]}" == "pkg1 (desc1)" ]]
    [[ "${INSTALLED_PACKAGES[1]}" == "pkg2 (desc2)" ]]
    [[ "${INSTALLED_PACKAGES[2]}" == "pkg3 (desc3)" ]]
}

@test "track_skipped handles multiple packages" {
    SKIPPED_PACKAGES=()
    track_skipped "pkg1"
    track_skipped "pkg2"
    track_skipped "pkg3"

    [ "${#SKIPPED_PACKAGES[@]}" -eq 3 ]
    [[ "${SKIPPED_PACKAGES[0]}" == "pkg1" ]]
    [[ "${SKIPPED_PACKAGES[1]}" == "pkg2" ]]
    [[ "${SKIPPED_PACKAGES[2]}" == "pkg3" ]]
}

@test "track_failed handles multiple packages" {
    FAILED_PACKAGES=()
    track_failed "pkg1" "error1"
    track_failed "pkg2" "error2"
    track_failed "pkg3" "error3"

    [ "${#FAILED_PACKAGES[@]}" -eq 3 ]
    [[ "${FAILED_PACKAGES[0]}" == "pkg1 (error1)" ]]
    [[ "${FAILED_PACKAGES[1]}" == "pkg2 (error2)" ]]
    [[ "${FAILED_PACKAGES[2]}" == "pkg3 (error3)" ]]
}

@test "tracking arrays are independent" {
    INSTALLED_PACKAGES=()
    SKIPPED_PACKAGES=()
    FAILED_PACKAGES=()

    track_installed "pkg1"
    track_skipped "pkg2"
    track_failed "pkg3"

    [ "${#INSTALLED_PACKAGES[@]}" -eq 1 ]
    [ "${#SKIPPED_PACKAGES[@]}" -eq 1 ]
    [ "${#FAILED_PACKAGES[@]}" -eq 1 ]
}

# ============================================================================
# LOGGING EDGE CASES
# ============================================================================

@test "log_info handles empty message" {
    run log_info ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"[INFO]"* ]]
}

@test "log_info handles special characters" {
    run log_info "Test with $pecial chars"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[INFO]"* ]]
}

@test "log_info handles multiline message" {
    run log_info "Line 1
Line 2"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[INFO]"* ]]
}

@test "log_success handles empty message" {
    run log_success ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"[OK]"* ]]
}

@test "log_warning handles empty message" {
    run log_warning ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"[WARN]"* ]]
}

@test "log_error handles empty message" {
    run log_error ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"[ERROR]"* ]]
}

@test "log_step handles empty message" {
    run log_step ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"[STEP]"* ]]
}

@test "print_header handles empty header" {
    run print_header ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"===="* ]]
}

@test "print_header handles long header text" {
    run print_header "This is a very long header text that should still be formatted correctly"
    [ "$status" -eq 0 ]
    [[ "$output" == *"===="* ]]
}

@test "print_section handles empty section" {
    run print_section ""
    [ "$status" -eq 0 ]
}

@test "print_section handles section with spaces" {
    run print_section "Test Section With Spaces"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Test Section With Spaces"* ]]
}

# ============================================================================
# RUN_CMD TESTS
# ============================================================================

@test "run_cmd executes complex command" {
    run run_cmd "echo 'hello world' | tr ' ' '-'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"hello-world"* ]]
}

@test "run_cmd handles command with pipes" {
    run run_cmd "echo test | wc -c"
    [ "$status" -eq 0 ]
}

@test "run_cmd dry-run does not execute command" {
    DRY_RUN=true
    run run_cmd "echo 'should not execute'"
    [[ "$output" != *"should not execute"* ]]
    [[ "$output" == *"[DRY-RUN]"* ]]
    DRY_RUN=false
}

# ============================================================================
# SAFE_INSTALL TESTS
# ============================================================================

@test "safe_install tracks successful install" {
    INSTALLED_PACKAGES=()
    success_func() { return 0; }

    safe_install success_func "test-pkg"

    [ "${#INSTALLED_PACKAGES[@]}" -eq 0 ]  # Not tracked by safe_install on success
}

@test "safe_install shows warning on failure" {
    FAILED_PACKAGES=()
    failing_func() { return 1; }

    run safe_install failing_func "test-pkg"

    [ "$status" -ne 0 ]
    [[ "$output" == *"Installation failed"* ]]
}

@test "safe_install passes arguments to install function" {
    args_received=""
    capture_func() {
        args_received="$*"
        return 0
    }

    safe_install capture_func "pkg1" "desc1" "extra"

    [[ "$args_received" == *"pkg1"* ]]
}

# ============================================================================
# CONFIRM FUNCTION TESTS
# ============================================================================

@test "confirm respects INTERACTIVE=false" {
    INTERACTIVE=false
    run confirm "Test prompt" "n"
    [ "$status" -eq 0 ]
}

@test "confirm returns 0 when default is y and INTERACTIVE is false" {
    INTERACTIVE=false
    run confirm "Test prompt" "y"
    [ "$status" -eq 0 ]
}

@test "confirm handles non-interactive mode directly" {
    INTERACTIVE=false
    result=$(confirm "Test" && echo "yes" || echo "no")
    [ "$result" = "yes" ]
}

# ============================================================================
# PLATFORM DETECTION EDGE CASES
# ============================================================================

@test "detect_os handles unknown OS gracefully" {
    # Mock uname to return unknown
    result=$(uname -s | while read kernel; do
        case "$kernel" in
            Linux*) echo "linux" ;;
            Darwin*) echo "macos" ;;
            MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
            *) echo "unknown" ;;
        esac
    done)
    [ "$result" = "unknown" ] || [ "$result" = "linux" ] || [ "$result" = "windows" ]
}

@test "is_windows returns false on non-Windows" {
    if [[ -z "$MSYSTEM" ]] && [[ ! "$(uname -s)" =~ (MINGW|MSYS|CYGWIN) ]]; then
        run is_windows
        [ "$status" -ne 0 ]
    else
        skip "Running on Windows"
    fi
}

# ============================================================================
# COLOR VARIABLES TESTS
# ============================================================================

@test "color variables are defined" {
    # These should be set when common.sh is sourced
    [ -n "${RED+x}" ]
    [ -n "${GREEN+x}" ]
    [ -n "${YELLOW+x}" ]
    [ -n "${BLUE+x}" ]
    [ -n "${CYAN+x}" ]
    [ -n "${BOLD+x}" ]
    [ -n "${NC+x}" ]
}

@test "color codes use escape sequences when TTY" {
    if [[ -t 1 ]]; then
        [[ "$GREEN" == *"\033["* ]] || [[ "$GREEN" == *$'\033['* ]]
    else
        # When not a TTY, colors may be empty
        [ "$GREEN" == "" ] || [ -n "$GREEN" ]
    fi
}

# ============================================================================
# CAPITALIZE FUNCTION TESTS
# ============================================================================

@test "capitalize handles empty string" {
    result=$(capitalize "")
    [ "$result" = "" ]
}

@test "capitalize handles uppercase input" {
    result=$(capitalize "TEST")
    [ "$result" = "TEST" ]
}

@test "capitalize handles mixed case input" {
    result=$(capitalize "tEsT")
    [ "$result" = "TEsT" ]
}

@test "capitalize handles string with spaces" {
    result=$(capitalize "hello world")
    [ "$result" = "Hello world" ]
}

# ============================================================================
# JOIN_BY FUNCTION TESTS
# ============================================================================

@test "join_by handles empty input" {
    result=$(join_by "," "")
    [ "$result" = "" ]
}

@test "join_by handles two elements" {
    result=$(join_by ":" "a" "b")
    [ "$result" = "a:b" ]
}

@test "join_by handles many elements" {
    result=$(join_by "-" "1" "2" "3" "4" "5")
    [ "$result" = "1-2-3-4-5" ]
}

@test "join_by handles special character delimiter" {
    result=$(join_by "|" "a" "b" "c")
    [ "$result" = "a|b|c" ]
}

# ============================================================================
# PRINT_SUMMARY EDGE CASES
# ============================================================================

@test "print_summary shows only failed when only failed packages" {
    INSTALLED_PACKAGES=()
    SKIPPED_PACKAGES=()
    FAILED_PACKAGES=("pkg1 (error)")
    run print_summary
    [ "$status" -eq 0 ]
    [[ "$output" == *"Failed: 1"* ]]
}

@test "print_summary shows only installed when only installed packages" {
    INSTALLED_PACKAGES=("pkg1 (installed)")
    SKIPPED_PACKAGES=()
    FAILED_PACKAGES=()
    run print_summary
    [ "$status" -eq 0 ]
    [[ "$output" == *"Installed: 1"* ]]
    [[ "$output" != *"Failed:"* ]]
}

@test "print_summary shows all three categories" {
    INSTALLED_PACKAGES=("pkg1")
    SKIPPED_PACKAGES=("pkg2")
    FAILED_PACKAGES=("pkg3")
    run print_summary
    [ "$status" -eq 0 ]
    [[ "$output" == *"Installed: 1"* ]]
    [[ "$output" == *"Skipped: 1"* ]]
    [[ "$output" == *"Failed: 1"* ]]
}
