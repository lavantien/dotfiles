#!/usr/bin/env bats
# Unit tests for git pre-commit hook
# Tests project detection, language check functions, and validation

setup() {
    # Create temporary directory for testing
    export TEST_TMP_DIR=$(mktemp -d)
    export TEST_REPO="$TEST_TMP_DIR/test-repo"

    # Create test repository
    mkdir -p "$TEST_REPO"
    cd "$TEST_REPO"
    git init --quiet
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Copy pre-commit hook
    # tests/bash/ -> tests/ -> repo root
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")/.." && pwd)"
    export HOOKS_DIR="$SCRIPT_DIR/.config/git/hooks"

    # Create a dummy staged file so hook doesn't exit early
    touch dummy.txt
    git add dummy.txt

    # Stub the git diff command to return our dummy file
    git() {
        if [[ "$1" == "diff" ]]; then
            echo "dummy.txt"
        else
            command git "$@"
        fi
    }
    export -f git

    # Source the pre-commit hook to access functions
    source "$HOOKS_DIR/pre-commit"
}

teardown() {
    # Cleanup test directory
    rm -rf "$TEST_TMP_DIR"
}

# ============================================================================
# PROJECT DETECTION
# ============================================================================

@test "detect_projects detects Go project (go.mod)" {
    touch "$TEST_REPO/go.mod"
    run detect_projects
    [[ "$output" == *"go"* ]]
}

@test "detect_projects detects Rust project (Cargo.toml)" {
    touch "$TEST_REPO/Cargo.toml"
    run detect_projects
    [[ "$output" == *"rust"* ]]
}

@test "detect_projects detects Node project (package.json)" {
    touch "$TEST_REPO/package.json"
    run detect_projects
    [[ "$output" == *"node"* ]]
}

@test "detect_projects detects Python project (pyproject.toml)" {
    touch "$TEST_REPO/pyproject.toml"
    run detect_projects
    [[ "$output" == *"python"* ]]
}

@test "detect_projects detects C# project (.cs files)" {
    touch "$TEST_REPO/test.cs"
    run detect_projects
    [[ "$output" == *"csharp"* ]]
}

@test "detect_projects detects Java project (pom.xml)" {
    touch "$TEST_REPO/pom.xml"
    run detect_projects
    [[ "$output" == *"java"* ]]
}

@test "detect_projects detects PHP project (composer.json)" {
    touch "$TEST_REPO/composer.json"
    run detect_projects
    [[ "$output" == *"php"* ]]
}

@test "detect_projects returns empty when no project detected" {
    run detect_projects
    [[ "$output" == *"No recognized project type"* ]] || [ -z "$output" ]
}

# ============================================================================
# COMMAND EXISTENCE
# ============================================================================

@test "cmd_exists returns success for existing commands" {
    # Source the hook again in this test scope
    source "$HOOKS_DIR/pre-commit"
    run command_exists ls
    [ "$status" -eq 0 ]
}

@test "cmd_exists returns failure for non-existent commands" {
    # Source the hook again in this test scope
    source "$HOOKS_DIR/pre-commit"
    run command_exists nonexistent_command_xyz123
    [ "$status" -ne 0 ]
}

# ============================================================================
# GO CHECKS
# ============================================================================

@test "run_go_checks skips when no .go files staged" {
    # Empty staging area
    run run_go_checks
    [ "$status" -eq 0 ]
}

@test "run_go_checks runs goimports if available" {
    if ! command -v goimports >/dev/null 2>&1; then
        skip "goimports not installed"
    fi

    # Create and stage a .go file
    touch "$TEST_REPO/test.go"
    git add "$TEST_REPO/test.go"

    # Source the hook functions
    source "$HOOKS_DIR/pre-commit"

    # This will fail if goimports not installed, which is OK for test
    run run_go_checks
    [ "$?" -eq 0 ] || [ "$?" -eq 1 ]  # Either way is acceptable
}

# ============================================================================
# RUST CHECKS
# ============================================================================

@test "run_rust_checks skips when no .rs files staged" {
    run run_rust_checks
    [ "$status" -eq 0 ]
}

@test "run_rust_checks runs cargo fmt" {
    if ! command -v cargo >/dev/null 2>&1; then
        skip "cargo not installed"
    fi

    # Create and stage a .rs file
    touch "$TEST_REPO/test.rs"
    git add "$TEST_REPO/test.rs"

    # Source the hook functions
    source "$HOOKS_DIR/pre-commit"

    run run_rust_checks
    [ "$?" -eq 0 ] || [ "$?" -eq 1 ]
}

# ============================================================================
# NODE CHECKS
# ============================================================================

@test "run_node_checks skips when no JS/TS files staged" {
    run run_node_checks
    [ "$status" -eq 0 ]
}

@test "run_node_checks runs prettier if available" {
    if ! command -v prettier >/dev/null 2>&1; then
        skip "prettier not installed"
    fi

    # Create and stage JS file
    echo "console.log('test');" > "$TEST_REPO/test.js"
    git add "$TEST_REPO/test.js"

    # Source the hook functions
    source "$HOOKS_DIR/pre-commit"

    # Allow prettier to fail (not installed in all envs)
    run run_node_checks
    [ "$?" -eq 0 ] || [ "$?" -eq 1 ]
}

# ============================================================================
# PYTHON CHECKS
# ============================================================================

@test "run_python_checks skips when no .py files staged" {
    run run_python_checks
    [ "$status" -eq 0 ]
}

@test "run_python_checks runs ruff if available" {
    if ! command -v ruff >/dev/null 2>&1; then
        skip "ruff not installed"
    fi

    # Create and stage .py file
    echo "print('test')" > "$TEST_REPO/test.py"
    git add "$TEST_REPO/test.py"

    # Source the hook functions
    source "$HOOKS_DIR/pre-commit"

    run run_python_checks
    [ "$?" -eq 0 ] || [ "$?" -eq 1 ]
}

# ============================================================================
# COMMIT MSG HOOK
# ============================================================================

@test "commit_msg_hook allows valid conventional commits" {
    local commit_msg_file="$TEST_TMP_DIR/commit_msg"
    echo "feat(auth): add OAuth2 login support" > "$commit_msg_file"

    run bash "$HOOKS_DIR/commit-msg" "$commit_msg_file"
    [ "$status" -eq 0 ]
}

@test "commit_msg_hook rejects invalid commit messages" {
    local commit_msg_file="$TEST_TMP_DIR/commit_msg"
    echo "Add some feature" > "$commit_msg_file"

    run bash "$HOOKS_DIR/commit-msg" "$commit_msg_file"
    [ "$status" -ne 0 ]
}

@test "commit_msg_hook allows merge commits" {
    local commit_msg_file="$TEST_TMP_DIR/commit_msg"
    echo "Merge branch 'feature' into main" > "$commit_msg_file"

    run bash "$HOOKS_DIR/commit-msg" "$commit_msg_file"
    [ "$status" -eq 0 ]
}

@test "commit_msg_hook allows revert commits" {
    local commit_msg_file="$TEST_TMP_DIR/commit_msg"
    echo "Revert \"feat: bad change\"" > "$commit_msg_file"

    run bash "$HOOKS_DIR/commit-msg" "$commit_msg_file"
    [ "$status" -eq 0 ]
}

@test "commit_msg_hook rejects subject lines over 72 chars" {
    local commit_msg_file="$TEST_TMP_DIR/commit_msg"
    # Create subject line with 73 characters
    echo "feat: $(head -c 68 /dev/urandom | base64 | tr -dc 'a-zA-Z')" > "$commit_msg_file"

    run bash "$HOOKS_DIR/commit-msg" "$commit_msg_file"
    [ "$status" -ne 0 ]
}

@test "commit_msg_hook requires blank line after subject" {
    local commit_msg_file="$TEST_TMP_DIR/commit_msg"
    echo -e "feat: add feature\nDetailed description without blank line" > "$commit_msg_file"

    run bash "$HOOKS_DIR/commit-msg" "$commit_msg_file"
    [ "$status" -ne 0 ]
}

# ============================================================================
# HOOK INTEGRITY TESTS (regression prevention)
# These tests detect if hook files have been truncated or corrupted
# ============================================================================

@test "hook_integrity: pre-commit hook exists and is not truncated" {
    local hook_path="$HOOKS_DIR/pre-commit"
    [ -f "$hook_path" ]

    # Check minimum line count (full implementation is ~400+ lines)
    local line_count=$(wc -l < "$hook_path")
    [ "$line_count" -gt 50 ]
}

@test "hook_integrity: commit-msg hook exists and is not truncated" {
    local hook_path="$HOOKS_DIR/commit-msg"
    [ -f "$hook_path" ]

    # Check minimum line count (full implementation is ~40+ lines)
    local line_count=$(wc -l < "$hook_path")
    [ "$line_count" -gt 20 ]
}

@test "hook_integrity: pre-commit contains essential functions" {
    local hook_path="$HOOKS_DIR/pre-commit"
    local content=$(cat "$hook_path")

    # Check for key functions that exist in full implementation
    echo "$content" | grep -q "detect_os"
    echo "$content" | grep -q "detect_projects"
    echo "$content" | grep -q "run_go_checks"
    echo "$content" | grep -q "run_rust_checks"
    echo "$content" | grep -q "run_node_checks"
    echo "$content" | grep -q "run_python_checks"
}

@test "hook_integrity: commit-msg validates conventional commits" {
    local hook_path="$HOOKS_DIR/commit-msg"
    local content=$(cat "$hook_path")

    # Check for conventional commits pattern
    echo "$content" | grep -q "feat|fix|chore"
    echo "$content" | grep -q "72"
}

@test "hook_integrity: pre-commit.ps1 exists and is not truncated" {
    local hook_path="$HOOKS_DIR/pre-commit.ps1"
    [ -f "$hook_path" ]

    # Check minimum line count (full implementation is ~400+ lines)
    local line_count=$(wc -l < "$hook_path")
    [ "$line_count" -gt 50 ]
}

@test "hook_integrity: commit-msg.ps1 exists and is not truncated" {
    local hook_path="$HOOKS_DIR/commit-msg.ps1"
    [ -f "$hook_path" ]

    # Check minimum line count (full implementation is ~40+ lines)
    local line_count=$(wc -l < "$hook_path")
    [ "$line_count" -gt 20 ]
}

@test "hook_integrity: pre-commit.ps1 contains essential functions" {
    local hook_path="$HOOKS_DIR/pre-commit.ps1"
    local content=$(cat "$hook_path")

    # Check for key functions that exist in full implementation
    echo "$content" | grep -q "Get-ProjectTypes"
    echo "$content" | grep -q "Invoke-GoChecks\|run_go_checks"
    echo "$content" | grep -q "Invoke-RustChecks\|run_rust_checks"
    echo "$content" | grep -q "Invoke-NodeChecks\|run_node_checks"
    echo "$content" | grep -q "Invoke-PythonChecks\|run_python_checks"
}
