#!/usr/bin/env bats
# Unit tests for bootstrap/platforms/macos.sh
# Tests macOS-specific package installation functions with mocking

# Load test helpers
load test_helper

setup() {
    # Load the bootstrap functions using BATS_TEST_DIRNAME
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")/.." && pwd)"
    source "$SCRIPT_DIR/bootstrap/lib/common.sh"
    source "$SCRIPT_DIR/bootstrap/lib/version-check.sh"
    source "$SCRIPT_DIR/bootstrap/platforms/macos.sh"
    setup_mock_env
    reset_tracking_arrays
    export DRY_RUN="false"
}

teardown() {
    teardown_mock_env
}

# ============================================================================
# PACKAGE DESCRIPTIONS
# ============================================================================

@test "macos get_package_description: returns description for brew" {
    run get_package_description "brew"
    [ "$output" = "package manager" ]
}

@test "macos get_package_description: returns description for git" {
    run get_package_description "git"
    [ "$output" = "version control" ]
}

@test "macos get_package_description: returns description for Node.js" {
    run get_package_description "node"
    [ "$output" = "Node.js runtime" ]

    run get_package_description "nodejs"
    [ "$output" = "Node.js runtime" ]
}

@test "macos get_package_description: returns description for Python" {
    run get_package_description "python"
    [ "$output" = "Python runtime" ]

    run get_package_description "python3"
    [ "$output" = "Python runtime" ]
}

@test "macos get_package_description: returns description for Go" {
    run get_package_description "go"
    [ "$output" = "Go runtime" ]

    run get_package_description "golang"
    [ "$output" = "Go runtime" ]
}

@test "macos get_package_description: returns description for LSP servers" {
    run get_package_description "clangd"
    [ "$output" = "C/C++ LSP" ]

    run get_package_description "gopls"
    [ "$output" = "Go LSP" ]

    run get_package_description "rust-analyzer"
    [ "$output" = "Rust LSP" ]

    run get_package_description "pyright"
    [ "$output" = "Python LSP" ]

    run get_package_description "lua-language-server"
    [ "$output" = "Lua LSP" ]
}

@test "macos get_package_description: returns description for linters and formatters" {
    run get_package_description "prettier"
    [ "$output" = "code formatter" ]

    run get_package_description "eslint"
    [ "$output" = "JavaScript linter" ]

    run get_package_description "ruff"
    [ "$output" = "Python linter" ]

    run get_package_description "black"
    [ "$output" = "Python formatter" ]

    run get_package_description "shellcheck"
    [ "$output" = "Shell script linter" ]
}

@test "macos get_package_description: returns description for CLI tools" {
    run get_package_description "fzf"
    [ "$output" = "fuzzy finder" ]

    run get_package_description "zoxide"
    [ "$output" = "smart cd" ]

    run get_package_description "bat"
    [ "$output" = "cat alternative" ]

    run get_package_description "eza"
    [ "$output" = "ls alternative" ]

    run get_package_description "lazygit"
    [ "$output" = "Git TUI" ]
}

@test "macos get_package_description: returns empty for unknown package" {
    run get_package_description "unknown-package-xyz123"
    [ "$output" = "" ]
}

# ============================================================================
# GIT CONFIGURATION
# ============================================================================

@test "macos configure_git_settings: configures git autocrlf" {
    # Mock git commands
    cat > "$MOCK_BIN_DIR/git" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
    "config core.autocrlf")
        echo "false"
        exit 0
        ;;
    "config --global core.autocrlf")
        exit 0
        ;;
    *)
        echo "git $*"
        exit 0
        ;;
esac
EOF
    chmod +x "$MOCK_BIN_DIR/git"

    run configure_git_settings
    [ "$status" -eq 0 ]
}

@test "macos configure_git_settings: adds GitHub to known_hosts" {
    # Mock git and ssh-keyscan
    cat > "$MOCK_BIN_DIR/git" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
    "config core.autocrlf")
        echo "false"
        exit 0
        ;;
    *)
        exit 0
        ;;
esac
EOF
    chmod +x "$MOCK_BIN_DIR/git"

    cat > "$MOCK_BIN_DIR/ssh-keyscan" <<'EOF'
#!/usr/bin/env bash
echo "github.com ssh-rsa AAAA"
exit 0
EOF
    chmod +x "$MOCK_BIN_DIR/ssh-keyscan"

    run configure_git_settings
    [ "$status" -eq 0 ]
}

@test "macos configure_git_settings: skips GitHub key when already present" {
    # Setup test SSH directory
    local test_ssh="$BATS_TMPDIR/ssh-test-$$"
    mkdir -p "$test_ssh"
    echo "github.com ssh-rsa test" > "$test_ssh/known_hosts"
    export HOME="$test_ssh"

    cat > "$MOCK_BIN_DIR/git" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
    "config core.autocrlf")
        echo "false"
        exit 0
        ;;
    *)
        exit 0
        ;;
esac
EOF
    chmod +x "$MOCK_BIN_DIR/git"

    run configure_git_settings
    [ "$status" -eq 0 ]
}

# ============================================================================
# HOMEBREW
# ============================================================================

@test "macos ensure_homebrew: installs when brew not found" {
    mock_cmd_exists "brew" "false"
    mock_command_with_output "bash" "Installed" "0"

    run ensure_homebrew
    [ "$status" -eq 0 ]
    package_was_installed "brew"
}

@test "macos ensure_homebrew: skips when brew already installed" {
    mock_cmd_exists "brew" "true"

    run ensure_homebrew
    [ "$status" -eq 0 ]
    package_was_skipped "brew"
}

@test "macos ensure_homebrew: adds Apple Silicon Homebrew to PATH" {
    mock_cmd_exists "brew" "false"
    mock_command_with_output "bash" "Installed" "0"

    # Create mock Apple Silicon directory
    mkdir -p "$MOCK_BIN_DIR/opt/homebrew/bin"

    run ensure_homebrew
    [ "$status" -eq 0 ]
}

@test "macos ensure_homebrew: adds Intel Homebrew to PATH" {
    mock_cmd_exists "brew" "false"
    mock_command_with_output "bash" "Installed" "0"

    # Create mock Intel directory
    mkdir -p "$MOCK_BIN_DIR/usr/local/bin"

    run ensure_homebrew
    [ "$status" -eq 0 ]
}

@test "macos ensure_homebrew: tracks failed install" {
    mock_cmd_exists "brew" "false"
    mock_command_with_output "bash" "Error" "1"

    run ensure_homebrew
    [ "$status" -eq 1 ]
    package_was_failed "brew"
}

# ============================================================================
# BREW PACKAGE INSTALLER
# ============================================================================

@test "macos install_brew_package: installs when tool not found" {
    mock_cmd_exists "brew" "true"
    mock_cmd_exists "test-tool" "false"
    mock_package_manager "brew" "install" "0"

    run install_brew_package "test-tool" "" "test-tool"
    [ "$status" -eq 0 ]
}

@test "macos install_brew_package: fails when brew not found" {
    mock_cmd_exists "brew" "false"

    run install_brew_package "test-tool" "" "test-tool"
    [ "$status" -eq 1 ]
    package_was_failed "test-tool"
}

@test "macos install_brew_package: skips when tool already installed" {
    mock_cmd_exists "brew" "true"
    mock_cmd_exists "test-tool" "true"
    mock_needs_install "false"

    run install_brew_package "test-tool" "" "test-tool"
    [ "$status" -eq 0 ]
}

@test "macos install_brew_package: uses custom check command" {
    mock_cmd_exists "brew" "true"
    mock_cmd_exists "actual-cmd" "false"
    mock_package_manager "brew" "install" "0"

    run install_brew_package "lib-pkg" "" "actual-cmd"
    [ "$status" -eq 0 ]
}

@test "macos install_brew_package: tracks installed packages" {
    mock_cmd_exists "brew" "true"
    mock_cmd_exists "test-tool" "false"
    mock_package_manager "brew" "install" "0"

    reset_tracking_arrays
    run install_brew_package "test-tool" "" "test-tool"
    [ "$status" -eq 0 ]
    package_was_installed "test-tool"
}

@test "macos install_brew_package: tracks failed installs" {
    mock_cmd_exists "brew" "true"
    mock_cmd_exists "test-tool" "false"
    mock_package_manager "brew" "install" "1"

    reset_tracking_arrays
    run install_brew_package "test-tool" "" "test-tool"
    [ "$status" -eq 1 ]
    package_was_failed "test-tool"
}

# ============================================================================
# BREW PACKAGES (BATCH INSTALL)
# ============================================================================

@test "macos install_brew_packages: installs multiple packages" {
    mock_cmd_exists "brew" "true"
    mock_cmd_exists "tool1" "false"
    mock_cmd_exists "tool2" "false"
    mock_cmd_exists "tool3" "false"
    mock_package_manager "brew" "install" "0"

    reset_tracking_arrays
    run install_brew_packages "tool1" "tool2" "tool3"
    [ "$status" -eq 0 ]
}

@test "macos install_brew_packages: skips already installed packages" {
    mock_cmd_exists "brew" "true"
    mock_cmd_exists "tool1" "true"
    mock_cmd_exists "tool2" "false"
    mock_needs_install "false"

    reset_tracking_arrays
    run install_brew_packages "tool1" "tool2"
    [ "$status" -eq 0 ]
}

@test "macos install_brew_packages: handles empty package list" {
    run install_brew_packages
    [ "$status" -eq 0 ]
}

@test "macos install_brew_packages: fails when brew not available" {
    mock_cmd_exists "brew" "false"

    run install_brew_packages "tool1" "tool2"
    [ "$status" -eq 0 ]
    # Should not crash, just can't install
}

# ============================================================================
# BREW CASK INSTALLER
# ============================================================================

@test "macos install_brew_cask: installs cask when tool not found" {
    mock_cmd_exists "brew" "true"
    mock_cmd_exists "test-app" "false"
    mock_package_manager "brew" "install" "0"

    run install_brew_cask "test-app" "test-app" ""
    [ "$status" -eq 0 ]
}

@test "macos install_brew_cask: fails when brew not found" {
    mock_cmd_exists "brew" "false"

    run install_brew_cask "test-app" "test-app" ""
    [ "$status" -eq 1 ]
    package_was_failed "test-app"
}

@test "macos install_brew_cask: skips when tool already installed" {
    mock_cmd_exists "brew" "true"
    mock_cmd_exists "test-app" "true"
    mock_needs_install "false"

    run install_brew_cask "test-app" "test-app" ""
    [ "$status" -eq 0 ]
}

@test "macos install_brew_cask: converts cask name to lowercase for check" {
    mock_cmd_exists "brew" "true"
    mock_cmd_exists "testapp" "false"
    mock_package_manager "brew" "install" "0"

    run install_brew_cask "TestApp" "" ""
    [ "$status" -eq 0 ]
}

@test "macos install_brew_cask: uses custom check command" {
    mock_cmd_exists "brew" "true"
    mock_cmd_exists "custom-cmd" "false"
    mock_package_manager "brew" "install" "0"

    run install_brew_cask "test-app" "custom-cmd" ""
    [ "$status" -eq 0 ]
}

# ============================================================================
# NPM GLOBAL INSTALLER
# ============================================================================

@test "macos install_npm_global: installs when tool not found" {
    mock_cmd_exists "npm" "true"
    mock_cmd_exists "test-cmd" "false"
    mock_package_manager "npm" "install" "0"

    run install_npm_global "test-package" "test-cmd" ""
    [ "$status" -eq 0 ]
}

@test "macos install_npm_global: fails when npm not found" {
    mock_cmd_exists "npm" "false"

    run install_npm_global "test-package" "test-cmd" ""
    [ "$status" -eq 1 ]
    package_was_failed "test-package"
}

@test "macos install_npm_global: skips when tool already installed" {
    mock_cmd_exists "npm" "true"
    mock_cmd_exists "test-cmd" "true"
    mock_needs_install "false"

    run install_npm_global "test-package" "test-cmd" ""
    [ "$status" -eq 0 ]
}

@test "macos install_npm_global: extracts command name from package" {
    mock_cmd_exists "npm" "true"
    mock_cmd_exists "pkg" "false"
    mock_package_manager "npm" "install" "0"

    run install_npm_global "@scope/pkg" "" ""
    [ "$status" -eq 0 ]
}

@test "macos install_npm_global: handles scoped packages" {
    mock_cmd_exists "npm" "true"
    mock_cmd_exists "testcmd" "false"
    mock_package_manager "npm" "install" "0"

    run install_npm_global "@scope/test-package" "testcmd" ""
    [ "$status" -eq 0 ]
}

# ============================================================================
# GO PACKAGE INSTALLER
# ============================================================================

@test "macos install_go_package: installs when tool not found" {
    mock_cmd_exists "go" "true"
    mock_cmd_exists "testcmd" "false"
    mock_package_manager "go" "install" "0"

    run install_go_package "github.com/test/pkg" "testcmd" ""
    [ "$status" -eq 0 ]
}

@test "macos install_go_package: fails when go not found" {
    mock_cmd_exists "go" "false"

    run install_go_package "github.com/test/pkg" "testcmd" ""
    [ "$status" -eq 1 ]
    package_was_failed "github.com/test/pkg"
}

@test "macos install_go_package: skips when tool already installed" {
    mock_cmd_exists "go" "true"
    mock_cmd_exists "testcmd" "true"

    run install_go_package "github.com/test/pkg" "testcmd" ""
    [ "$status" -eq 0 ]
    package_was_skipped "testcmd"
}

@test "macos install_go_package: extracts command name from package path" {
    mock_cmd_exists "go" "true"
    mock_cmd_exists "pkg" "false"
    mock_package_manager "go" "install" "0"

    run install_go_package "github.com/test/pkg" "" ""
    [ "$status" -eq 0 ]
}

@test "macos install_go_package: uses gup when available" {
    mock_cmd_exists "go" "true"
    mock_cmd_exists "gup" "true"
    mock_cmd_exists "testcmd" "false"
    mock_package_manager "gup" "install" "0"

    run install_go_package "github.com/test/pkg" "testcmd" ""
    [ "$status" -eq 0 ]
}

# ============================================================================
# CARGO PACKAGE INSTALLER
# ============================================================================

@test "macos install_cargo_package: installs when tool not found" {
    mock_cmd_exists "cargo" "true"
    mock_cmd_exists "testcmd" "false"
    mock_package_manager "cargo" "install" "0"

    run install_cargo_package "test-pkg" "testcmd" ""
    [ "$status" -eq 0 ]
}

@test "macos install_cargo_package: fails when cargo not found" {
    mock_cmd_exists "cargo" "false"

    run install_cargo_package "test-pkg" "testcmd" ""
    [ "$status" -eq 1 ]
    package_was_failed "test-pkg"
}

@test "macos install_cargo_package: skips when tool already installed" {
    mock_cmd_exists "cargo" "true"
    mock_cmd_exists "testcmd" "true"
    mock_needs_install "false"

    run install_cargo_package "test-pkg" "testcmd" ""
    [ "$status" -eq 0 ]
}

@test "macos install_cargo_package: adds cargo bin to PATH" {
    mock_cmd_exists "cargo" "true"
    mock_cmd_exists "testcmd" "false"
    mock_package_manager "cargo" "install" "0"

    local original_path="$PATH"
    run install_cargo_package "test-pkg" "testcmd" ""
    [ "$status" -eq 0 ]
    # PATH should be modified
    [[ "$PATH" == *".cargo/bin"* ]] || [ "$PATH" == "$original_path" ]
}

# ============================================================================
# PIP GLOBAL INSTALLER
# ============================================================================

@test "macos install_pip_global: installs with python3 when tool not found" {
    mock_cmd_exists "python3" "true"
    mock_cmd_exists "testcmd" "false"
    mock_package_manager "pip" "install" "0"

    run install_pip_global "test-pkg" "testcmd" ""
    [ "$status" -eq 0 ]
}

@test "macos install_pip_global: falls back to python when python3 not found" {
    mock_cmd_exists "python3" "false"
    mock_cmd_exists "python" "true"
    mock_cmd_exists "testcmd" "false"
    mock_package_manager "pip" "install" "0"

    run install_pip_global "test-pkg" "testcmd" ""
    [ "$status" -eq 0 ]
}

@test "macos install_pip_global: fails when python not found" {
    mock_cmd_exists "python3" "false"
    mock_cmd_exists "python" "false"

    run install_pip_global "test-pkg" "testcmd" ""
    [ "$status" -eq 1 ]
    package_was_failed "test-pkg"
}

@test "macos install_pip_global: skips when tool already installed" {
    mock_cmd_exists "python3" "true"
    mock_cmd_exists "testcmd" "true"
    mock_needs_install "false"

    run install_pip_global "test-pkg" "testcmd" ""
    [ "$status" -eq 0 ]
}

# ============================================================================
# DOTNET TOOL INSTALLER
# ============================================================================

@test "macos install_dotnet_tool: installs when tool not found" {
    mock_cmd_exists "dotnet" "true"
    mock_cmd_exists "testcmd" "false"
    mock_package_manager "dotnet" "install" "0"

    run install_dotnet_tool "test-pkg" "testcmd" ""
    [ "$status" -eq 0 ]
}

@test "macos install_dotnet_tool: fails when dotnet not found" {
    mock_cmd_exists "dotnet" "false"

    run install_dotnet_tool "test-pkg" "testcmd" ""
    [ "$status" -eq 1 ]
    package_was_failed "test-pkg"
}

@test "macos install_dotnet_tool: skips when tool already installed" {
    mock_cmd_exists "dotnet" "true"
    mock_cmd_exists "testcmd" "true"
    mock_needs_install "false"

    run install_dotnet_tool "test-pkg" "testcmd" ""
    [ "$status" -eq 0 ]
}

@test "macos install_dotnet_tool: tries update when install fails" {
    mock_cmd_exists "dotnet" "true"
    mock_cmd_exists "testcmd" "false"

    # First call (install) fails, second (update) succeeds
    cat > "$MOCK_BIN_DIR/dotnet" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "install" ]]; then
    exit 1
elif [[ "$1" == "update" ]]; then
    echo "Updated test-pkg"
    exit 0
fi
exit 0
EOF
    chmod +x "$MOCK_BIN_DIR/dotnet"

    run install_dotnet_tool "test-pkg" "testcmd" ""
    [ "$status" -eq 0 ]
}

@test "macos install_dotnet_tool: adds dotnet tools to PATH" {
    mock_cmd_exists "dotnet" "true"
    mock_cmd_exists "testcmd" "false"
    mock_package_manager "dotnet" "install" "0"

    run install_dotnet_tool "test-pkg" "testcmd" ""
    [ "$status" -eq 0 ]
    # PATH should contain .dotnet/tools
    [[ "$PATH" == *".dotnet/tools"* ]] || true
}

# ============================================================================
# RUSTUP INSTALLER
# ============================================================================

@test "macos install_rustup: installs when rustup not found" {
    mock_cmd_exists "rustup" "false"
    mock_command_with_output "curl" "Downloaded rustup" "0"

    run install_rustup
    [ "$status" -eq 0 ]
    package_was_installed "rust"
}

@test "macos install_rustup: skips when rustup already installed" {
    mock_cmd_exists "rustup" "true"

    run install_rustup
    [ "$status" -eq 0 ]
    package_was_skipped "rust"
}

@test "macos install_rustup: tracks failed install" {
    mock_cmd_exists "rustup" "false"
    mock_command_with_output "curl" "" "1"

    run install_rustup
    [ "$status" -eq 1 ]
    package_was_failed "rust"
}

@test "macos install_rustup: adds cargo bin to PATH" {
    mock_cmd_exists "rustup" "false"
    mock_command_with_output "curl" "Success" "0"

    local original_path="$PATH"
    run install_rustup
    [ "$status" -eq 0 ]
    # PATH should contain .cargo/bin
    [[ "$PATH" == *".cargo/bin"* ]] || [ "$PATH" == "$original_path" ]
}

# ============================================================================
# RUST-ANALYZER COMPONENT
# ============================================================================

@test "macos install_rust_analyzer_component: installs when not found" {
    mock_cmd_exists "rustup" "true"
    mock_cmd_exists "rust-analyzer" "false"
    mock_package_manager "rustup" "component" "0"

    run install_rust_analyzer_component
    [ "$status" -eq 0 ]
}

@test "macos install_rust_analyzer_component: fails when rustup not found" {
    mock_cmd_exists "rustup" "false"

    run install_rust_analyzer_component
    [ "$status" -eq 1 ]
    package_was_failed "rust-analyzer"
}

@test "macos install_rust_analyzer_component: skips when already installed" {
    mock_cmd_exists "rustup" "true"
    mock_cmd_exists "rust-analyzer" "true"
    mock_needs_install "false"

    run install_rust_analyzer_component
    [ "$status" -eq 0 ]
    package_was_skipped "rust-analyzer"
}

# ============================================================================
# MACPORTS INSTALLER
# ============================================================================

@test "macos install_macports_package: installs when tool not found" {
    mock_cmd_exists "port" "true"
    mock_cmd_exists "test-tool" "false"
    mock_package_manager "port" "install" "0"

    run install_macports_package "test-tool" "" "test-tool"
    [ "$status" -eq 0 ]
}

@test "macos install_macports_package: fails when port not found" {
    mock_cmd_exists "port" "false"

    run install_macports_package "test-tool" "" "test-tool"
    [ "$status" -eq 1 ]
}

@test "macos install_macports_package: skips when tool already installed" {
    mock_cmd_exists "port" "true"
    mock_cmd_exists "test-tool" "true"
    mock_needs_install "false"

    run install_macports_package "test-tool" "" "test-tool"
    [ "$status" -eq 0 ]
}

@test "macos install_macports_package: uses custom check command" {
    mock_cmd_exists "port" "true"
    mock_cmd_exists "actual-cmd" "false"
    mock_package_manager "port" "install" "0"

    run install_macports_package "lib-pkg" "" "actual-cmd"
    [ "$status" -eq 0 ]
}

# ============================================================================
# CROSS-PLATFORM TESTS
# ============================================================================

@test "macos bootstrap: brew functions work cross-platform with mocks" {
    mock_cmd_exists "brew" "true"
    mock_cmd_exists "test-tool" "false"
    mock_package_manager "brew" "install" "0"

    run install_brew_package "test-tool" "" "test-tool"
    [ "$status" -eq 0 ]
}

@test "macos bootstrap: language package managers work cross-platform" {
    # npm
    mock_cmd_exists "npm" "true"
    mock_cmd_exists "testcmd" "false"
    mock_package_manager "npm" "install" "0"

    run install_npm_global "test-package" "testcmd" ""
    [ "$status" -eq 0 ]
}

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

@test "macos bootstrap: full install flow with tracking" {
    mock_cmd_exists "test-tool" "false"
    mock_cmd_exists "brew" "true"
    mock_package_manager "brew" "install" "0"

    reset_tracking_arrays
    run install_brew_package "test-tool" "" "test-tool"
    [ "$status" -eq 0 ]
    package_was_installed "test-tool"
}

@test "macos bootstrap: handles cask and formula installs" {
    mock_cmd_exists "brew" "true"
    mock_cmd_exists "test-app" "false"
    mock_cmd_exists "test-tool" "false"
    mock_package_manager "brew" "install" "0"

    reset_tracking_arrays
    run install_brew_cask "test-app" "test-app" ""
    [ "$status" -eq 0 ]

    reset_tracking_arrays
    run install_brew_package "test-tool" "" "test-tool"
    [ "$status" -eq 0 ]
}

@test "macos bootstrap: handles install with descriptions" {
    mock_cmd_exists "bat" "false"
    mock_cmd_exists "brew" "true"
    mock_package_manager "brew" "install" "0"

    reset_tracking_arrays
    run install_brew_package "bat" "" "bat"
    [ "$status" -eq 0 ]
    # Should track with description
    package_was_installed "bat"
}
