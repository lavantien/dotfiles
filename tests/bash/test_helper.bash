# Test helper functions for BATS tests
# Provides common utilities for setting up test environments

# Get the script directory (parent of tests/)
export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Create a temporary git repository for testing
create_test_repo() {
    local test_dir="$1"
    mkdir -p "$test_dir"
    cd "$test_dir"

    # Initialize git repo
    git init --quiet 2>/dev/null
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Create initial commit
    touch README.md
    git add README.md 2>/dev/null || true
    git commit -m "Initial commit" --quiet 2>/dev/null || true
}

# Clean up a test repository
cleanup_test_repo() {
    local test_dir="$1"
    rm -rf "$test_dir"
}

# Create a minimal dotfiles structure
create_minimal_dotfiles() {
    local target_dir="$1"

    mkdir -p "$target_dir"/{bootstrap,hooks/git,lib}

    # Create minimal bootstrap script
    cat > "$target_dir/bootstrap/bootstrap.sh" <<'EOF'
#!/usr/bin/env bash
# Minimal bootstrap for testing

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

log_info "Bootstrap test script loaded"
EOF
    chmod +x "$target_dir/bootstrap/bootstrap.sh"
}

# Mock a command for testing
mock_command() {
    local cmd="$1"
    local output="$2"
    local exit_code="${3:-0}"

    # Create a mock function
    eval "$cmd() { echo '$output'; return $exit_code; }"
    export -f "$cmd"
}

# ============================================================================
# ENHANCED MOCKING FRAMEWORK
# ============================================================================

# Mock environment directory for isolated tests
export MOCK_BIN_DIR=""

# Setup mock environment with temporary bin directory
setup_mock_env() {
    # Save original PATH
    export ORIGINAL_PATH="$PATH"

    # Create temporary mock bin directory
    export MOCK_BIN_DIR="$BATS_TMPDIR/mock-bin-$$"
    mkdir -p "$MOCK_BIN_DIR"

    # Add mock bin to front of PATH
    export PATH="$MOCK_BIN_DIR:$PATH"

    # Create mock versions of common commands
    for cmd in curl wget git brew apt dnf pacman zypper snap flatpak npm pip go cargo dotnet gem bats; do
        cat > "$MOCK_BIN_DIR/$cmd" <<'EOF'
#!/usr/bin/env bash
# Mock command - outputs info about invocation
echo "Mock $0 called with: $*" >&2
exit 0
EOF
        chmod +x "$MOCK_BIN_DIR/$cmd"
    done
}

# Teardown mock environment
teardown_mock_env() {
    # Restore original PATH
    if [[ -n "${ORIGINAL_PATH:-}" ]]; then
        export PATH="$ORIGINAL_PATH"
        unset ORIGINAL_PATH
    fi

    # Clean up mock bin directory
    if [[ -n "$MOCK_BIN_DIR" && -d "$MOCK_BIN_DIR" ]]; then
        rm -rf "$MOCK_BIN_DIR"
    fi
    export MOCK_BIN_DIR=""
}

# Mock a command that outputs specific version
# Usage: mock_version_output "node" "v20.1.0"
mock_version_output() {
    local cmd="$1"
    local version="$2"

    # Ensure MOCK_BIN_DIR exists
    if [[ ! -d "$MOCK_BIN_DIR" ]]; then
        export MOCK_BIN_DIR="$BATS_TMPDIR/mock-bin-$$"
        mkdir -p "$MOCK_BIN_DIR"
        export PATH="$MOCK_BIN_DIR:$PATH"
    fi

    cat > "$MOCK_BIN_DIR/$cmd" <<EOF
#!/usr/bin/env bash
case "\$1" in
    *version*|--version*|-v) echo "$version" ;;
    *) echo "$cmd \$*" ;;
esac
exit 0
EOF
    chmod +x "$MOCK_BIN_DIR/$cmd"
}

# Mock a command with specific output and exit code
# Usage: mock_command_with_output "apt" "Reading package lists... Done" "0"
mock_command_with_output() {
    local cmd="$1"
    local stdout="$2"
    local exit_code="${3:-0}"

    # Ensure MOCK_BIN_DIR exists
    if [[ ! -d "$MOCK_BIN_DIR" ]]; then
        export MOCK_BIN_DIR="$BATS_TMPDIR/mock-bin-$$"
        mkdir -p "$MOCK_BIN_DIR"
        export PATH="$MOCK_BIN_DIR:$PATH"
    fi

    cat > "$MOCK_BIN_DIR/$cmd" <<EOF
#!/usr/bin/env bash
echo "$stdout"
exit $exit_code
EOF
    chmod +x "$MOCK_BIN_DIR/$cmd"
}

# Mock a package manager install command
# Usage: mock_package_manager "apt" "install" "0" (success)
#        mock_package_manager "apt" "install" "1" (failure)
mock_package_manager() {
    local pm="$1"
    local action="${2:-install}"
    local exit_code="${3:-0}"

    # Ensure MOCK_BIN_DIR exists
    if [[ ! -d "$MOCK_BIN_DIR" ]]; then
        export MOCK_BIN_DIR="$BATS_TMPDIR/mock-bin-$$"
        mkdir -p "$MOCK_BIN_DIR"
        export PATH="$MOCK_BIN_DIR:$PATH"
    fi

    case "$pm" in
        apt)
            cat > "$MOCK_BIN_DIR/$pm" <<EOF
#!/usr/bin/env bash
case "\$1" in
    update) echo "Reading package lists... Done" ;;
    install) echo "Selecting \$2"; [ $exit_code -eq 0 ] || exit 1 ;;
    *) echo "$pm \$*" ;;
esac
exit $exit_code
EOF
            ;;
        dnf)
            cat > "$MOCK_BIN_DIR/$pm" <<EOF
#!/usr/bin/env bash
case "\$1" in
    install) echo "Installing \$2"; [ $exit_code -eq 0 ] || exit 1 ;;
    *) echo "$pm \$*" ;;
esac
exit $exit_code
EOF
            ;;
        pacman)
            cat > "$MOCK_BIN_DIR/$pm" <<EOF
#!/usr/bin/env bash
case "\$1" in
    -S|--sync) echo "Installing \$2"; [ $exit_code -eq 0 ] || exit 1 ;;
    *) echo "$pm \$*" ;;
esac
exit $exit_code
EOF
            ;;
        brew)
            cat > "$MOCK_BIN_DIR/$pm" <<EOF
#!/usr/bin/env bash
case "\$1" in
    install) echo "Installing \$2"; [ $exit_code -eq 0 ] || exit 1 ;;
    update) echo "Updated Homebrew" ;;
    upgrade) echo "Upgrading \$2"; [ $exit_code -eq 0 ] || exit 1 ;;
    *) echo "$pm \$*" ;;
esac
exit $exit_code
EOF
            ;;
        *)
            # Generic mock
            cat > "$MOCK_BIN_DIR/$pm" <<EOF
#!/usr/bin/env bash
echo "$pm \$1 \$2"
exit $exit_code
EOF
            ;;
    esac
    chmod +x "$MOCK_BIN_DIR/$pm"
}

# Mock command existence checker
# Usage: mock_cmd_exists "npm" "true"  (command exists)
#        mock_cmd_exists "npm" "false" (command doesn't exist)
mock_cmd_exists() {
    local cmd="$1"
    local exists="$2"

    if [[ "$exists" == "true" ]]; then
        # Ensure the mock command exists
        if [[ ! -f "$MOCK_BIN_DIR/$cmd" ]]; then
            cat > "$MOCK_BIN_DIR/$cmd" <<EOF
#!/usr/bin/env bash
echo "$cmd called with: \$*"
exit 0
EOF
            chmod +x "$MOCK_BIN_DIR/$cmd"
        fi
    else
        # Remove the mock command if it exists
        rm -f "$MOCK_BIN_DIR/$cmd"
    fi
}

# Mock the needs_install function result
# Usage: mock_needs_install "true"  (tool needs install)
#        mock_needs_install "false" (tool already installed)
mock_needs_install() {
    local result="$1"

    # Override the function in the current shell
    if [[ "$result" == "true" ]]; then
        eval 'needs_install() { return 0; }'
    else
        eval 'needs_install() { return 1; }'
    fi
    export -f needs_install
}

# Create a temporary config file for testing
# Usage: create_test_config "/tmp/test-config.yaml" "editor: nvim"
create_test_config() {
    local file="$1"
    local content="$2"
    mkdir -p "$(dirname "$file")"
    echo "$content" > "$file"
}

# Mock file system operations for deploy tests
setup_deploy_test_env() {
    export TEST_DEPLOY_DIR="$BATS_TMPDIR/deploy-test-$$"
    export TEST_HOME="$TEST_DEPLOY_DIR/home"
    export TEST_XDG_CONFIG="$TEST_DEPLOY_DIR/home/.config"

    mkdir -p "$TEST_HOME"
    mkdir -p "$TEST_XDG_CONFIG"
    mkdir -p "$TEST_DEPLOY_DIR/dotfiles"

    # Set HOME to test directory
    export HOME="$TEST_HOME"
    export XDG_CONFIG_HOME="$TEST_XDG_CONFIG"
}

cleanup_deploy_test_env() {
    rm -rf "$TEST_DEPLOY_DIR:-}"
    unset TEST_DEPLOY_DIR TEST_HOME TEST_XDG_CONFIG
}

# Assert helpers
assert_output_contains() {
    local expected="$1"
    [[ "$output" == *"$expected"* ]]
}

assert_output_not_contains() {
    local expected="$1"
    [[ "$output" != *"$expected"* ]]
}

assert_file_exists() {
    local file="$1"
    [[ -f "$file" ]]
}

assert_file_not_exists() {
    local file="$1"
    [[ ! -f "$file" ]]
}

assert_dir_exists() {
    local dir="$1"
    [[ -d "$dir" ]]
}

assert_dir_not_exists() {
    local dir="$1"
    [[ ! -d "$dir" ]]
}

# ============================================================================
# TRACKING ARRAY MOCKS
# ============================================================================

# Reset tracking arrays for tests
reset_tracking_arrays() {
    INSTALLED_PACKAGES=()
    SKIPPED_PACKAGES=()
    FAILED_PACKAGES=()
    export INSTALLED_PACKAGES SKIPPED_PACKAGES FAILED_PACKAGES
}

# Check if package is in tracking array
package_was_installed() {
    local pkg="$1"
    for installed_pkg in "${INSTALLED_PACKAGES[@]}"; do
        if [[ "$installed_pkg" == "$pkg"* ]]; then
            return 0
        fi
    done
    return 1
}

package_was_skipped() {
    local pkg="$1"
    for skipped_pkg in "${SKIPPED_PACKAGES[@]}"; do
        if [[ "$skipped_pkg" == "$pkg"* ]]; then
            return 0
        fi
    done
    return 1
}

package_was_failed() {
    local pkg="$1"
    for failed_pkg in "${FAILED_PACKAGES[@]}"; do
        if [[ "$failed_pkg" == "$pkg"* ]]; then
            return 0
        fi
    done
    return 1
}
