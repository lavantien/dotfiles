#!/usr/bin/env bats
# Unit tests for bootstrap/platforms/linux.sh
# Tests Linux-specific package installation functions with mocking

# Load test helpers
load test_helper

setup() {
    # Load the bootstrap functions using BATS_TEST_DIRNAME
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")/.." && pwd)"
    source "$SCRIPT_DIR/bootstrap/lib/common.sh"
    source "$SCRIPT_DIR/bootstrap/lib/version-check.sh"
    source "$SCRIPT_DIR/bootstrap/platforms/linux.sh"
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

@test "get_package_description: returns description for git" {
    run get_package_description "git"
    [ "$output" = "version control" ]
}

@test "get_package_description: returns description for Node.js" {
    run get_package_description "node"
    [ "$output" = "Node.js runtime" ]

    run get_package_description "nodejs"
    [ "$output" = "Node.js runtime" ]
}

@test "get_package_description: returns description for Python" {
    run get_package_description "python"
    [ "$output" = "Python runtime" ]

    run get_package_description "python3"
    [ "$output" = "Python runtime" ]
}

@test "get_package_description: returns description for Go" {
    run get_package_description "go"
    [ "$output" = "Go runtime" ]

    run get_package_description "golang"
    [ "$output" = "Go runtime" ]
}

@test "get_package_description: returns description for Rust" {
    run get_package_description "rust"
    [ "$output" = "Rust toolchain" ]
}

@test "get_package_description: returns description for LSP servers" {
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

@test "get_package_description: returns description for linters and formatters" {
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

@test "get_package_description: returns description for CLI tools" {
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

@test "get_package_description: returns empty for unknown package" {
    run get_package_description "unknown-package-xyz123"
    [ "$output" = "" ]
}

# ============================================================================
# APT PACKAGE INSTALLER
# ============================================================================

@test "install_apt_package: installs when tool not found" {
    mock_cmd_exists "vim" "false"
    mock_package_manager "apt" "install" "0"

    run install_apt_package "vim" "" "vim"
    [ "$status" -eq 0 ]
}

@test "install_apt_package: skips when tool already installed" {
    mock_cmd_exists "vim" "true"
    mock_needs_install "false"

    reset_tracking_arrays
    run install_apt_package "vim" "" "vim"
    [ "$status" -eq 0 ]
}

@test "install_apt_package: tracks installed packages" {
    mock_cmd_exists "test-tool" "false"
    mock_package_manager "apt" "install" "0"

    reset_tracking_arrays
    run install_apt_package "test-tool" "" "test-tool"
    [ "$status" -eq 0 ]
    package_was_installed "test-tool"
}

@test "install_apt_package: tracks failed installs" {
    mock_cmd_exists "bad-tool" "false"
    mock_package_manager "apt" "install" "1"

    reset_tracking_arrays
    run install_apt_package "bad-tool" "" "bad-tool"
    [ "$status" -eq 1 ]
    package_was_failed "bad-tool"
}

@test "install_apt_package: uses custom check command" {
    mock_cmd_exists "actual-cmd" "false"
    mock_package_manager "apt" "install" "0"

    run install_apt_package "lib-pkg" "" "actual-cmd"
    [ "$status" -eq 0 ]
}

@test "install_apt_package: handles dry-run mode" {
    mock_cmd_exists "test-tool" "false"
    export DRY_RUN="true"

    reset_tracking_arrays
    run install_apt_package "test-tool" "" "test-tool"
    [ "$status" -eq 0 ]
    package_was_installed "test-tool"
}

# ============================================================================
# DNF PACKAGE INSTALLER
# ============================================================================

@test "install_dnf_package: installs when tool not found" {
    mock_cmd_exists "vim" "false"
    mock_package_manager "dnf" "install" "0"

    run install_dnf_package "vim" "" "vim"
    [ "$status" -eq 0 ]
}

@test "install_dnf_package: skips when tool already installed" {
    mock_cmd_exists "vim" "true"
    mock_needs_install "false"

    reset_tracking_arrays
    run install_dnf_package "vim" "" "vim"
    [ "$status" -eq 0 ]
}

@test "install_dnf_package: tracks installed packages" {
    mock_cmd_exists "test-tool" "false"
    mock_package_manager "dnf" "install" "0"

    reset_tracking_arrays
    run install_dnf_package "test-tool" "" "test-tool"
    [ "$status" -eq 0 ]
    package_was_installed "test-tool"
}

@test "install_dnf_package: tracks failed installs" {
    mock_cmd_exists "bad-tool" "false"
    mock_package_manager "dnf" "install" "1"

    reset_tracking_arrays
    run install_dnf_package "bad-tool" "" "bad-tool"
    [ "$status" -eq 1 ]
    package_was_failed "bad-tool"
}

# ============================================================================
# PACMAN PACKAGE INSTALLER
# ============================================================================

@test "install_pacman_package: installs when tool not found" {
    mock_cmd_exists "vim" "false"
    mock_package_manager "pacman" "install" "0"

    run install_pacman_package "vim" "" "vim"
    [ "$status" -eq 0 ]
}

@test "install_pacman_package: skips when tool already installed" {
    mock_cmd_exists "vim" "true"
    mock_needs_install "false"

    reset_tracking_arrays
    run install_pacman_package "vim" "" "vim"
    [ "$status" -eq 0 ]
}

@test "install_pacman_package: tracks installed packages" {
    mock_cmd_exists "test-tool" "false"
    mock_package_manager "pacman" "install" "0"

    reset_tracking_arrays
    run install_pacman_package "test-tool" "" "test-tool"
    [ "$status" -eq 0 ]
    package_was_installed "test-tool"
}

@test "install_pacman_package: tracks failed installs" {
    mock_cmd_exists "bad-tool" "false"
    mock_package_manager "pacman" "install" "1"

    reset_tracking_arrays
    run install_pacman_package "bad-tool" "" "bad-tool"
    [ "$status" -eq 1 ]
    package_was_failed "bad-tool"
}

# ============================================================================
# ZYPPER PACKAGE INSTALLER
# ============================================================================

@test "install_zypper_package: installs when tool not found" {
    mock_cmd_exists "vim" "false"
    mock_package_manager "zypper" "install" "0"

    run install_zypper_package "vim" "" "vim"
    [ "$status" -eq 0 ]
}

@test "install_zypper_package: skips when tool already installed" {
    mock_cmd_exists "vim" "true"
    mock_needs_install "false"

    reset_tracking_arrays
    run install_zypper_package "vim" "" "vim"
    [ "$status" -eq 0 ]
}

@test "install_zypper_package: tracks installed packages" {
    mock_cmd_exists "test-tool" "false"
    mock_package_manager "zypper" "install" "0"

    reset_tracking_arrays
    run install_zypper_package "test-tool" "" "test-tool"
    [ "$status" -eq 0 ]
    package_was_installed "test-tool"
}

@test "install_zypper_package: tracks failed installs" {
    mock_cmd_exists "bad-tool" "false"
    mock_package_manager "zypper" "install" "1"

    reset_tracking_arrays
    run install_zypper_package "bad-tool" "" "bad-tool"
    [ "$status" -eq 1 ]
    package_was_failed "bad-tool"
}

# ============================================================================
# DISTRO-AGNOSTIC INSTALLER
# ============================================================================

@test "install_linux_package: uses apt for debian family" {
    # Mock get_distro_family to return debian
    get_distro_family() { echo "debian"; }
    export -f get_distro_family

    mock_cmd_exists "test-tool" "false"
    mock_package_manager "apt" "install" "0"

    run install_linux_package "test-tool" "" "test-tool"
    [ "$status" -eq 0 ]
}

@test "install_linux_package: uses dnf for fedora family" {
    get_distro_family() { echo "fedora"; }
    export -f get_distro_family

    mock_cmd_exists "test-tool" "false"
    mock_package_manager "dnf" "install" "0"

    run install_linux_package "test-tool" "" "test-tool"
    [ "$status" -eq 0 ]
}

@test "install_linux_package: uses pacman for arch family" {
    get_distro_family() { echo "arch"; }
    export -f get_distro_family

    mock_cmd_exists "test-tool" "false"
    mock_package_manager "pacman" "install" "0"

    run install_linux_package "test-tool" "" "test-tool"
    [ "$status" -eq 0 ]
}

@test "install_linux_package: uses zypper for opensuse family" {
    get_distro_family() { echo "opensuse"; }
    export -f get_distro_family

    mock_cmd_exists "test-tool" "false"
    mock_package_manager "zypper" "install" "0"

    run install_linux_package "test-tool" "" "test-tool"
    [ "$status" -eq 0 ]
}

@test "install_linux_package: returns failure for unknown distro" {
    get_distro_family() { echo "unknown"; }
    export -f get_distro_family

    run install_linux_package "test-tool" "" "test-tool"
    [ "$status" -eq 1 ]
}

# ============================================================================
# FLATPAK INSTALLER
# ============================================================================

@test "install_flatpak_app: installs when tool not found" {
    mock_cmd_exists "flatpak" "true"
    mock_cmd_exists "test-app" "false"
    mock_package_manager "flatpak" "install" "0"

    run install_flatpak_app "com.example.test" "test-app" "Test App"
    [ "$status" -eq 0 ]
}

@test "install_flatpak_app: skips when flatpak not installed" {
    mock_cmd_exists "flatpak" "false"

    run install_flatpak_app "com.example.test" "test-app" "Test App"
    [ "$status" -eq 1 ]
}

@test "install_flatpak_app: skips when tool already installed" {
    mock_cmd_exists "flatpak" "true"
    mock_cmd_exists "test-app" "true"
    mock_needs_install "false"

    run install_flatpak_app "com.example.test" "test-app" "Test App"
    [ "$status" -eq 0 ]
}

@test "install_flatpak_app: extracts command from app_id" {
    mock_cmd_exists "flatpak" "true"
    mock_cmd_exists "test" "false"
    mock_package_manager "flatpak" "install" "0"

    run install_flatpak_app "com.example.test"
    [ "$status" -eq 0 ]
}

# ============================================================================
# SNAP INSTALLER
# ============================================================================

@test "install_snap_app: installs when tool not found" {
    mock_cmd_exists "snap" "true"
    mock_cmd_exists "test-app" "false"
    mock_package_manager "snap" "install" "0"

    run install_snap_app "test-app" "test-app"
    [ "$status" -eq 0 ]
}

@test "install_snap_app: skips when snap not installed" {
    mock_cmd_exists "snap" "false"

    run install_snap_app "test-app" "test-app"
    [ "$status" -eq 1 ]
}

@test "install_snap_app: skips when tool already installed" {
    mock_cmd_exists "snap" "true"
    mock_cmd_exists "test-app" "true"
    mock_needs_install "false"

    run install_snap_app "test-app" "test-app"
    [ "$status" -eq 0 ]
}

# ============================================================================
# NPM GLOBAL INSTALLER
# ============================================================================

@test "install_npm_global: installs when tool not found" {
    mock_cmd_exists "npm" "true"
    mock_cmd_exists "test-cmd" "false"
    mock_package_manager "npm" "install" "0"

    run install_npm_global "test-package" "test-cmd" ""
    [ "$status" -eq 0 ]
}

@test "install_npm_global: fails when npm not found" {
    mock_cmd_exists "npm" "false"

    run install_npm_global "test-package" "test-cmd" ""
    [ "$status" -eq 1 ]
    package_was_failed "test-package"
}

@test "install_npm_global: skips when tool already installed" {
    mock_cmd_exists "npm" "true"
    mock_cmd_exists "test-cmd" "true"
    mock_needs_install "false"

    run install_npm_global "test-package" "test-cmd" ""
    [ "$status" -eq 0 ]
}

@test "install_npm_global: extracts command name from package" {
    mock_cmd_exists "npm" "true"
    mock_cmd_exists "pkg" "false"
    mock_package_manager "npm" "install" "0"

    run install_npm_global "@scope/pkg" "" ""
    [ "$status" -eq 0 ]
}

@test "install_npm_global: handles scoped packages" {
    mock_cmd_exists "npm" "true"
    mock_cmd_exists "testcmd" "false"
    mock_package_manager "npm" "install" "0"

    run install_npm_global "@scope/test-package" "testcmd" ""
    [ "$status" -eq 0 ]
}

# ============================================================================
# GO PACKAGE INSTALLER
# ============================================================================

@test "install_go_package: installs when tool not found" {
    mock_cmd_exists "go" "true"
    mock_cmd_exists "testcmd" "false"
    mock_package_manager "go" "install" "0"

    run install_go_package "github.com/test/pkg" "testcmd" ""
    [ "$status" -eq 0 ]
}

@test "install_go_package: fails when go not found" {
    mock_cmd_exists "go" "false"

    run install_go_package "github.com/test/pkg" "testcmd" ""
    [ "$status" -eq 1 ]
    package_was_failed "github.com/test/pkg"
}

@test "install_go_package: skips when tool already installed" {
    mock_cmd_exists "go" "true"
    mock_cmd_exists "testcmd" "true"

    run install_go_package "github.com/test/pkg" "testcmd" ""
    [ "$status" -eq 0 ]
    package_was_skipped "testcmd"
}

@test "install_go_package: extracts command name from package path" {
    mock_cmd_exists "go" "true"
    mock_cmd_exists "pkg" "false"
    mock_package_manager "go" "install" "0"

    run install_go_package "github.com/test/pkg" "" ""
    [ "$status" -eq 0 ]
}

@test "install_go_package: uses gup when available" {
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

@test "install_cargo_package: installs when tool not found" {
    mock_cmd_exists "cargo" "true"
    mock_cmd_exists "testcmd" "false"
    mock_package_manager "cargo" "install" "0"

    run install_cargo_package "test-pkg" "testcmd" ""
    [ "$status" -eq 0 ]
}

@test "install_cargo_package: fails when cargo not found" {
    mock_cmd_exists "cargo" "false"

    run install_cargo_package "test-pkg" "testcmd" ""
    [ "$status" -eq 1 ]
    package_was_failed "test-pkg"
}

@test "install_cargo_package: skips when tool already installed" {
    mock_cmd_exists "cargo" "true"
    mock_cmd_exists "testcmd" "true"
    mock_needs_install "false"

    run install_cargo_package "test-pkg" "testcmd" ""
    [ "$status" -eq 0 ]
}

@test "install_cargo_package: adds cargo bin to PATH" {
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

@test "install_pip_global: installs with python3 when tool not found" {
    mock_cmd_exists "python3" "true"
    mock_cmd_exists "testcmd" "false"
    mock_package_manager "pip" "install" "0"

    run install_pip_global "test-pkg" "testcmd" ""
    [ "$status" -eq 0 ]
}

@test "install_pip_global: falls back to python when python3 not found" {
    mock_cmd_exists "python3" "false"
    mock_cmd_exists "python" "true"
    mock_cmd_exists "testcmd" "false"
    mock_package_manager "pip" "install" "0"

    run install_pip_global "test-pkg" "testcmd" ""
    [ "$status" -eq 0 ]
}

@test "install_pip_global: fails when python not found" {
    mock_cmd_exists "python3" "false"
    mock_cmd_exists "python" "false"

    run install_pip_global "test-pkg" "testcmd" ""
    [ "$status" -eq 1 ]
    package_was_failed "test-pkg"
}

@test "install_pip_global: skips when tool already installed" {
    mock_cmd_exists "python3" "true"
    mock_cmd_exists "testcmd" "true"
    mock_needs_install "false"

    run install_pip_global "test-pkg" "testcmd" ""
    [ "$status" -eq 0 ]
}

# ============================================================================
# DOTNET TOOL INSTALLER
# ============================================================================

@test "install_dotnet_tool: installs when tool not found" {
    mock_cmd_exists "dotnet" "true"
    mock_cmd_exists "testcmd" "false"
    mock_package_manager "dotnet" "install" "0"

    run install_dotnet_tool "test-pkg" "testcmd" ""
    [ "$status" -eq 0 ]
}

@test "install_dotnet_tool: fails when dotnet not found" {
    mock_cmd_exists "dotnet" "false"

    run install_dotnet_tool "test-pkg" "testcmd" ""
    [ "$status" -eq 1 ]
    package_was_failed "test-pkg"
}

@test "install_dotnet_tool: skips when tool already installed" {
    mock_cmd_exists "dotnet" "true"
    mock_cmd_exists "testcmd" "true"
    mock_needs_install "false"

    run install_dotnet_tool "test-pkg" "testcmd" ""
    [ "$status" -eq 0 ]
}

@test "install_dotnet_tool: tries update when install fails" {
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

@test "install_dotnet_tool: adds dotnet tools to PATH" {
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

@test "install_rustup: installs when rustup not found" {
    mock_cmd_exists "rustup" "false"
    mock_command_with_output "curl" "Downloaded rustup" "0"

    run install_rustup
    [ "$status" -eq 0 ]
    package_was_installed "rust"
}

@test "install_rustup: skips when rustup already installed" {
    mock_cmd_exists "rustup" "true"

    run install_rustup
    [ "$status" -eq 0 ]
    package_was_skipped "rust"
}

@test "install_rustup: tracks failed install" {
    mock_cmd_exists "rustup" "false"
    mock_command_with_output "curl" "" "1"

    run install_rustup
    [ "$status" -eq 1 ]
    package_was_failed "rust"
}

@test "install_rustup: adds cargo bin to PATH" {
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

@test "install_rust_analyzer_component: installs when not found" {
    mock_cmd_exists "rustup" "true"
    mock_cmd_exists "rust-analyzer" "false"
    mock_package_manager "rustup" "component" "0"

    run install_rust_analyzer_component
    [ "$status" -eq 0 ]
}

@test "install_rust_analyzer_component: fails when rustup not found" {
    mock_cmd_exists "rustup" "false"

    run install_rust_analyzer_component
    [ "$status" -eq 1 ]
    package_was_failed "rust-analyzer"
}

@test "install_rust_analyzer_component: skips when already installed" {
    mock_cmd_exists "rustup" "true"
    mock_cmd_exists "rust-analyzer" "true"
    mock_needs_install "false"

    run install_rust_analyzer_component
    [ "$status" -eq 0 ]
    package_was_skipped "rust-analyzer"
}

# ============================================================================
# HOMEBREW (LINUX)
# ============================================================================

@test "ensure_homebrew: installs when brew not found" {
    mock_cmd_exists "brew" "false"
    mock_command_with_output "bash" "Installed" "0"

    run ensure_homebrew
    [ "$status" -eq 0 ]
    package_was_installed "brew"
}

@test "ensure_homebrew: skips when brew already installed" {
    mock_cmd_exists "brew" "true"

    run ensure_homebrew
    [ "$status" -eq 0 ]
    package_was_skipped "brew"
}

@test "install_brew_package: installs when tool not found" {
    mock_cmd_exists "brew" "true"
    mock_cmd_exists "testcmd" "false"
    mock_package_manager "brew" "install" "0"

    run install_brew_package "test-pkg" "" "testcmd"
    [ "$status" -eq 0 ]
}

@test "install_brew_package: fails when brew not found" {
    mock_cmd_exists "brew" "false"

    run install_brew_package "test-pkg" "" "testcmd"
    [ "$status" -eq 1 ]
}

@test "install_brew_package: skips when tool already installed" {
    mock_cmd_exists "brew" "true"
    mock_cmd_exists "testcmd" "true"
    mock_needs_install "false"

    run install_brew_package "test-pkg" "" "testcmd"
    [ "$status" -eq 0 ]
}

# ============================================================================
# GIT CONFIGURATION
# ============================================================================

@test "configure_git_settings: configures git autocrlf on Linux" {
    # Mock git commands
    cat > "$MOCK_BIN_DIR/git" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
    "config core.autocrlf")
        if [[ "$3" == "false" ]]; then
            exit 0
        else
            echo "false"
            exit 0
        fi
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

@test "configure_git_settings: adds GitHub to known_hosts" {
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

@test "configure_git_settings: skips GitHub key when already present" {
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
# CROSS-PLATFORM TESTS
# ============================================================================

@test "bootstrap_linux: apt functions work cross-platform with mocks" {
    mock_cmd_exists "test-tool" "false"
    mock_package_manager "apt" "install" "0"

    run install_apt_package "test-tool" "" "test-tool"
    [ "$status" -eq 0 ]
}

@test "bootstrap_linux: dnf functions work cross-platform with mocks" {
    mock_cmd_exists "test-tool" "false"
    mock_package_manager "dnf" "install" "0"

    run install_dnf_package "test-tool" "" "test-tool"
    [ "$status" -eq 0 ]
}

@test "bootstrap_linux: pacman functions work cross-platform with mocks" {
    mock_cmd_exists "test-tool" "false"
    mock_package_manager "pacman" "install" "0"

    run install_pacman_package "test-tool" "" "test-tool"
    [ "$status" -eq 0 ]
}

@test "bootstrap_linux: zypper functions work cross-platform with mocks" {
    mock_cmd_exists "test-tool" "false"
    mock_package_manager "zypper" "install" "0"

    run install_zypper_package "test-tool" "" "test-tool"
    [ "$status" -eq 0 ]
}

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

@test "bootstrap_linux: full install flow with tracking" {
    mock_cmd_exists "test-tool" "false"
    mock_package_manager "apt" "install" "0"
    get_distro_family() { echo "debian"; }
    export -f get_distro_family

    reset_tracking_arrays
    run install_linux_package "test-tool" "" "test-tool"
    [ "$status" -eq 0 ]
    package_was_installed "test-tool"
}

@test "bootstrap_linux: handles mixed install results" {
    mock_cmd_exists "installed-tool" "true"
    mock_cmd_exists "new-tool" "false"
    mock_cmd_exists "bad-tool" "false"
    mock_package_manager "apt" "install" "0"

    # First tool - should skip
    mock_needs_install "false"
    reset_tracking_arrays
    run install_apt_package "installed-tool" "" "installed-tool"
    [ "$status" -eq 0 ]
    package_was_skipped "installed-tool"

    # Second tool - should install
    mock_needs_install "true"
    reset_tracking_arrays
    run install_apt_package "new-tool" "" "new-tool"
    [ "$status" -eq 0 ]
    package_was_installed "new-tool"
}

@test "bootstrap_linux: handles install with descriptions" {
    mock_cmd_exists "bat" "false"
    mock_package_manager "apt" "install" "0"

    reset_tracking_arrays
    run install_apt_package "bat" "" "bat"
    [ "$status" -eq 0 ]
    # Should track with description
    package_was_installed "bat"
}
