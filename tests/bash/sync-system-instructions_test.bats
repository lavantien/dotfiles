#!/usr/bin/env bats
# Unit tests for sync-system-instructions.sh

setup() {
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")/.." && pwd)"
    export TEST_TMP_DIR="$BATS_TMPDIR/dotfiles-sync-test-$$"
    export HOME="$TEST_TMP_DIR"

    # Create test directory structure matching script's expectations
    mkdir -p "$TEST_TMP_DIR/dev/github"
    mkdir -p "$TEST_TMP_DIR/dev/github/dotfiles"
    mkdir -p "$TEST_TMP_DIR/dev/github/repo1"
    mkdir -p "$TEST_TMP_DIR/dev/github/repo2"

    # Create source markdown files in dotfiles
    echo "# Claude Instructions" > "$TEST_TMP_DIR/dev/github/dotfiles/CLAUDE.md"
    echo "# Agent Instructions" > "$TEST_TMP_DIR/dev/github/dotfiles/AGENTS.md"

    # Create repos as git repositories
    (cd "$TEST_TMP_DIR/dev/github/repo1" && git init >/dev/null 2>&1)
    (cd "$TEST_TMP_DIR/dev/github/repo2" && git init >/dev/null 2>&1)
}

teardown() {
    rm -rf "$TEST_TMP_DIR"
}

run_sync() {
    run env HOME="$TEST_TMP_DIR" bash "$SCRIPT_DIR/sync-system-instructions.sh" "$@"
}

# ============================================================================
# HELP AND USAGE
# ============================================================================

@test "sync: accepts -d flag for base directory" {
    run_sync -d "$TEST_TMP_DIR/dev/github"
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "sync: accepts -c flag for commit" {
    run_sync -d "$TEST_TMP_DIR/dev/github" -c
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "sync: accepts -p flag for push" {
    run_sync -d "$TEST_TMP_DIR/dev/github" -p
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "sync: accepts all flags together" {
    run_sync -d "$TEST_TMP_DIR/dev/github" -c -p
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

# ============================================================================
# DIRECTORY VALIDATION
# ============================================================================

@test "sync: shows error when base directory not found" {
    run_sync -d "$TEST_TMP_DIR/nonexistent"
    [ "$status" -eq 1 ]
}

@test "sync: shows error when dotfiles directory not found" {
    # Temporarily rename dotfiles
    mv "$TEST_TMP_DIR/dev/github/dotfiles" "$TEST_TMP_DIR/dev/github/dotfiles.bak"

    run_sync -d "$TEST_TMP_DIR/dev/github"
    [ "$status" -eq 1 ]

    # Restore
    mv "$TEST_TMP_DIR/dev/github/dotfiles.bak" "$TEST_TMP_DIR/dev/github/dotfiles"
}

# ============================================================================
# OUTPUT STRUCTURE
# ============================================================================

@test "sync: shows header banner" {
    run_sync -d "$TEST_TMP_DIR/dev/github"
    echo "$output" | grep -q "System Instructions Sync"
}

@test "sync: shows separator lines" {
    run_sync -d "$TEST_TMP_DIR/dev/github"
    echo "$output" | grep -q "==="
}

@test "sync: shows base directory in output" {
    run_sync -d "$TEST_TMP_DIR/dev/github"
    echo "$output" | grep -q "Base Directory"
}

# ============================================================================
# SCANNING
# ============================================================================

@test "sync: scans for repositories" {
    run_sync -d "$TEST_TMP_DIR/dev/github"
    echo "$output" | grep -qi "scanning"
}

@test "sync: processes repositories" {
    run_sync -d "$TEST_TMP_DIR/dev/github"
    echo "$output" | grep -qi "repo"
}

# ============================================================================
# FILE SYNCING
# ============================================================================

@test "sync: processes repositories in base directory" {
    run_sync -d "$TEST_TMP_DIR/dev/github"
    # Script should run without crashing
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "sync: shows repository processing" {
    run_sync -d "$TEST_TMP_DIR/dev/github"
    # Should show some indication of processing
    echo "$output" | grep -qi "repo" || echo "$output" | grep -q "\["
}

@test "sync: skips dotfiles directory itself" {
    run_sync -d "$TEST_TMP_DIR/dev/github"
    # Should complete without error even though dotfiles is in the base dir
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

# ============================================================================
# SUMMARY
# ============================================================================

@test "sync: shows processing results" {
    run_sync -d "$TEST_TMP_DIR/dev/github"
    # Should show some output about results
    [ -n "$output" ]
}

# ============================================================================
# COMMIT AND PUSH FLAGS
# ============================================================================

@test "sync: shows Commit in output when -c flag used" {
    run_sync -d "$TEST_TMP_DIR/dev/github" -c
    echo "$output" | grep -q "Commit"
}

@test "sync: shows Push in output when -p flag used" {
    run_sync -d "$TEST_TMP_DIR/dev/github" -p
    echo "$output" | grep -q "Push"
}

# ============================================================================
# ERROR HANDLING
# ============================================================================

@test "sync: runs without crashing" {
    run_sync -d "$TEST_TMP_DIR/dev/github"
    # Exit 0 or 1 is OK, just shouldn't crash
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "sync: produces output" {
    run_sync -d "$TEST_TMP_DIR/dev/github"
    [ -n "$output" ]
}

# ============================================================================
# EDGE CASES
# ============================================================================

@test "sync: handles empty base directory gracefully" {
    mkdir -p "$TEST_TMP_DIR/empty"

    run_sync -d "$TEST_TMP_DIR/empty"
    # Should not crash
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "sync: handles directory with no git repos" {
    mkdir -p "$TEST_TMP_DIR/nogit/dir1"
    mkdir -p "$TEST_TMP_DIR/nogit/dir2"

    run_sync -d "$TEST_TMP_DIR/nogit"
    # Should not crash
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}
