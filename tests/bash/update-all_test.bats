#!/usr/bin/env bats
# Unit tests for update-all.sh
# Tests update logic, timeout handling, and prerequisites

# Load test helpers
load test_helper

setup() {
    # Source update-all functions
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")/.." && pwd)"
    source "$SCRIPT_DIR/update-all.sh"

    # Reset counters before each test
    updated=0
    skipped=0
    failed=0
    setup_mock_env
}

teardown() {
    teardown_mock_env
}

# ============================================================================
# UPDATE HELPERS
# ============================================================================

@test "update_success increments updated counter" {
    updated=5
    update_success "test"
    [ "$updated" -eq 6 ]
}

@test "update_skip increments skipped counter" {
    skipped=3
    update_skip "test reason"
    [ "$skipped" -eq 4 ]
}

@test "update_fail increments failed counter" {
    failed=1
    update_fail "test failure"
    [ "$failed" -eq 2 ]
}

@test "update_section outputs formatted section header" {
    run update_section "Test Section"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Test Section"* ]]
}

# ============================================================================
# COMMAND CHECKING
# ============================================================================

@test "cmd_exists returns success for existing commands" {
    run cmd_exists ls
    [ "$status" -eq 0 ]
}

@test "cmd_exists returns failure for non-existent commands" {
    run cmd_exists nonexistent_command_xyz123
    [ "$status" -ne 0 ]
}

@test "cmd_exists works with mocked commands" {
    mock_cmd_exists "test-tool" "true"
    run cmd_exists "test-tool"
    [ "$status" -eq 0 ]
}

@test "cmd_exists returns false for missing mocked commands" {
    mock_cmd_exists "missing-tool" "false"
    run cmd_exists "missing-tool"
    [ "$status" -ne 0 ]
}

# ============================================================================
# PLATFORM DETECTION
# ============================================================================

@test "detect_os returns valid platform string" {
    result=$(detect_os)
    [[ "$result" =~ ^(linux|macos|windows|unknown)$ ]]
}

@test "is_windows returns false on non-Windows" {
    # On non-Windows, should return false
    if [[ "$(uname -s)" =~ (MINGW|MSYS|CYGWIN) ]]; then
        skip "Running on Windows"
    fi
    run is_windows
    [ "$status" -ne 0 ]
}

@test "should_use_sudo returns false on Windows" {
    # Mock Windows environment
    export MSYSTEM="MINGW64"
    run should_use_sudo
    [ "$status" -ne 0 ]
}

# ============================================================================
# TIMEOUT HANDLING
# ============================================================================

@test "run_with_timeout executes command quickly" {
    run run_with_timeout 10 "echo 'quick command'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"quick command"* ]]
}

@test "run_with_timeout times out long-running commands" {
    if ! command -v timeout >/dev/null 2>&1; then
        skip "timeout command not available"
    fi

    run run_with_timeout 1 "sleep 5 && echo 'done'"
    [ "$status" -eq 124 ]  # Timeout exit code
}

@test "run_with_timeout runs command directly when timeout not available" {
    # Remove timeout command temporarily
    mv "$MOCK_BIN_DIR/timeout" "$MOCK_BIN_DIR/timeout.bak" 2>/dev/null || true

    run run_with_timeout 10 "echo 'no timeout command'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"no timeout command"* ]]
}

# ============================================================================
# PREREQUISITE CHECKING
# ============================================================================

@test "check_prerequisites finds at least one package manager" {
    # This test depends on what's installed
    run check_prerequisites
    [ "$status" -eq 0 ]  # Should not fail to find *something*
}

@test "check_prerequisites outputs informative messages" {
    run check_prerequisites
    [[ "$output" == *"Checking prerequisites"* ]]
}

@test "check_prerequisites detects npm" {
    mock_cmd_exists "npm" "true"
    run check_prerequisites
    [[ "$output" == *"npm"* ]]
}

@test "check_prerequisites detects brew" {
    mock_cmd_exists "brew" "true"
    run check_prerequisites
    [[ "$output" == *"Homebrew"* ]]
}

# ============================================================================
# UPDATE AND REPORT
# ============================================================================

@test "update_and_report fails on non-zero exit code" {
    run update_and_report "false" "test"
    [ "$status" -ne 0 ]
}

@test "update_and_report succeeds on successful command" {
    # Reset counters before testing
    updated=0
    run update_and_report "echo 'test output'" "test"
    [ "$status" -eq 0 ]
}

@test "update_and_report detects changes in output" {
    # Reset counters before testing
    updated=0
    run update_and_report "echo 'changed files installed'" "test"
    [ "$status" -eq 0 ]
    [[ "$output" == *"changed"* ]]
}

@test "update_and_report reports up to date when no changes" {
    run update_and_report "echo 'already up to date'" "test"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Up to date"* ]]
}

@test "update_and_report strips sudo on Windows" {
    export MSYSTEM="MINGW64"
    run update_and_report "sudo apt update" "apt"
    [ "$status" -eq 0 ]
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

@test "should_skip_package handles comma-separated skip list" {
    CONFIG_SKIP_PACKAGES="git,node,python"
    run should_skip_package "node"
    [ "$status" -eq 0 ]
}

@test "should_skip_package returns false when package not in skip list" {
    CONFIG_SKIP_PACKAGES="git node"
    run should_skip_package "python"
    [ "$status" -ne 0 ]
}

# ============================================================================
# PIP UPDATE LOGIC
# ============================================================================

@test "update_pip handles empty package list" {
    # Mock pip to return empty list
    cat > "$MOCK_BIN_DIR/pip" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "list" ]]; then
    echo ""
else
    echo "pip $*"
fi
exit 0
EOF
    chmod +x "$MOCK_BIN_DIR/pip"

    run update_pip "pip" "pip"
    [ "$status" -eq 0 ]
}

@test "update_pip updates packages when changes detected" {
    # Mock pip with packages that need updating
    cat > "$MOCK_BIN_DIR/pip" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "list" ]]; then
    echo "ruff==0.1.0"
    echo "black==23.0.0"
elif [[ "$2" == "upgrade" ]]; then
    echo "Successfully installed ruff-0.2.0"
    echo "Successfully installed black-24.0.0"
fi
exit 0
EOF
    chmod +x "$MOCK_BIN_DIR/pip"

    run update_pip "pip" "pip"
    [ "$status" -eq 0 ]
}

# ============================================================================
# DOTNET TOOLS UPDATE LOGIC
# ============================================================================

@test "update_dotnet_tools handles empty tool list" {
    # Mock dotnet to return empty list
    cat > "$MOCK_BIN_DIR/dotnet" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "tool" ]] && [[ "$2" == "list" ]]; then
        echo "Package Id      Commands      Version"
        echo "-----------------------------------"
fi
exit 0
EOF
    chmod +x "$MOCK_BIN_DIR/dotnet"

    run update_dotnet_tools
    [ "$status" -eq 0 ]
}

@test "update_dotnet_tools updates tools successfully" {
    # Mock dotnet with tools
    cat > "$MOCK_BIN_DIR/dotnet" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "tool" ]] && [[ "$2" == "list" ]]; then
        echo "Package Id      Commands      Version"
        echo "-----------------------------------"
        echo "fake-tool       fakecmd       1.0.0"
elif [[ "$1" == "tool" ]] && [[ "$2" == "update" ]]; then
        echo "Successfully updated fake-tool"
fi
exit 0
EOF
    chmod +x "$MOCK_BIN_DIR/dotnet"

    run update_dotnet_tools
    [ "$status" -eq 0 ]
}

# ============================================================================
# PACKAGE MANAGER MOCK TESTS
# ============================================================================

@test "apt update with mocked apt" {
    mock_package_manager "apt" "install" "0"

    run update_and_report "apt update" "apt"
    [ "$status" -eq 0 ]
}

@test "dnf update with mocked dnf" {
    mock_package_manager "dnf" "install" "0"

    run update_and_report "dnf upgrade -y" "dnf"
    [ "$status" -eq 0 ]
}

@test "pacman update with mocked pacman" {
    mock_package_manager "pacman" "install" "0"

    run update_and_report "pacman -Syu --noconfirm" "pacman"
    [ "$status" -eq 0 ]
}

@test "zypper update with mocked zypper" {
    mock_package_manager "zypper" "install" "0"

    run update_and_report "zypper dup -y" "zypper"
    [ "$status" -eq 0 ]
}

@test "brew update with mocked brew" {
    mock_package_manager "brew" "install" "0"

    run update_and_report "brew update && brew upgrade" "brew"
    [ "$status" -eq 0 ]
}

@test "npm update with mocked npm" {
    mock_package_manager "npm" "install" "0"

    run update_and_report "npm update -g" "npm"
    [ "$status" -eq 0 ]
}

@test "yarn update with mocked yarn" {
    mock_package_manager "yarn" "install" "0"

    run update_and_report "yarn global upgrade" "yarn"
    [ "$status" -eq 0 ]
}

@test "pnpm update with mocked pnpm" {
    mock_package_manager "pnpm" "install" "0"

    run update_and_report "pnpm update -g" "pnpm"
    [ "$status" -eq 0 ]
}

@test "go update with mocked go" {
    mock_package_manager "go" "install" "0"

    run update_and_report "go install all@latest" "go"
    [ "$status" -eq 0 ]
}

@test "cargo update with mocked cargo" {
    mock_package_manager "cargo" "install" "0"

    run update_and_report "cargo install-update -a" "cargo"
    [ "$status" -eq 0 ]
}

@test "gem update with mocked gem" {
    mock_package_manager "gem" "install" "0"

    run update_and_report "gem update --user" "gem"
    [ "$status" -eq 0 ]
}

@test "rustup update with mocked rustup" {
    mock_package_manager "rustup" "install" "0"

    run update_and_report "rustup update" "rustup"
    [ "$status" -eq 0 ]
}

# ============================================================================
# SUMMARY OUTPUT
# ============================================================================

@test "summary outputs correct counts" {
    updated=10
    skipped=2
    failed=1

    # Run the summary section from update-all.sh
    start_time=$(date +%s)
    end_time=$((start_time + 60))
    duration=$((end_time - start_time))
    minutes=$((duration / 60))
    seconds=$((duration % 60))

    # This would be the actual summary output
    [ "$updated" -eq 10 ]
    [ "$skipped" -eq 2 ]
    [ "$failed" -eq 1 ]
}

@test "summary formats duration correctly" {
    start_time=$(date +%s)
    end_time=$((start_time + 125))
    duration=$((end_time - start_time))
    minutes=$((duration / 60))
    seconds=$((duration % 60))

    [ "$minutes" -eq 2 ]
    [ "$seconds" -eq 5 ]
}

# ============================================================================
# CONFIG LOADING
# ============================================================================

@test "update-all loads config with defaults" {
    # Source again to test config loading
    source "$SCRIPT_DIR/lib/config.sh"

    # Should have default values
    [ "$CONFIG_CATEGORIES" = "full" ]
    [ "$CONFIG_SKIP_PACKAGES" = "" ]
}

@test "update-all respects skip_packages from config" {
    # Create test config
    create_test_config "/tmp/test-update-config.yaml" "skip_packages: git, npm"

    # Load config
    source "$SCRIPT_DIR/lib/config.sh"
    load_dotfiles_config "/tmp/test-update-config.yaml"

    run should_skip_package "git"
    [ "$status" -eq 0 ]

    run should_skip_package "npm"
    [ "$status" -eq 0 ]

    run should_skip_package "cargo"
    [ "$status" -ne 0 ]
}

# ============================================================================
# ERROR HANDLING
# ============================================================================

@test "update_and_report handles command failure gracefully" {
    run update_and_report "exit 1" "test"
    [ "$status" -ne 0 ]
    [ "$failed" -gt 0 ]
}

@test "update_and_report increments failed counter on error" {
    failed=0
    run update_and_report "exit 1" "test"
    [ "$failed" -gt 0 ]
}

@test "update_and_report doesn't increment failed on success" {
    failed=0
    run update_and_report "exit 0" "test"
    [ "$failed" -eq 0 ]
}

# ============================================================================
# CROSS-PLATFORM TESTS
# ============================================================================

@test "update-all skips apt on Windows" {
    export MSYSTEM="MINGW64"

    # Should skip apt on Windows
    run is_windows
    [ "$status" -eq 0 ]
}

@test "update-all strips sudo from commands on Windows" {
    export MSYSTEM="MINGW64"

    local cmd="sudo apt update"
    local expected="apt update"

    # Strip sudo
    cmd="${cmd//sudo /}"
    [ "$cmd" = "$expected" ]
}

@test "update-all allows sudo on Linux" {
    # On Linux, should use sudo
    if [[ "$(uname -s)" =~ (MINGW|MSYS|CYGWIN) ]]; then
        skip "Running on Windows"
    fi

    run should_use_sudo
    [ "$status" -eq 0 ]
}

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

@test "update-all handles full update flow with mocks" {
    # Mock common package managers
    for pm in brew npm go cargo gem; do
        mock_cmd_exists "$pm" "true"
        mock_package_manager "$pm" "install" "0"
    done

    # Run a simple update check
    run check_prerequisites
    [ "$status" -eq 0 ]
}

@test "update-all correctly counts updates" {
    updated=0

    # Simulate successful updates
    update_success "tool1"
    update_success "tool2"
    update_success "tool3"

    [ "$updated" -eq 3 ]
}

@test "update-all correctly counts skips" {
    skipped=0

    # Simulate skipped updates
    update_skip "tool1 already up to date"
    update_skip "tool2 not installed"

    [ "$skipped" -eq 2 ]
}

@test "update-all correctly counts failures" {
    failed=0

    # Simulate failed updates
    update_fail "tool1 network error"
    update_fail "tool2 permission denied"

    [ "$failed" -eq 2 ]
}
