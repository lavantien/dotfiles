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
