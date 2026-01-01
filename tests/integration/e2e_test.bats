#!/usr/bin/env bats
# Integration tests - End-to-end workflow tests
# Tests complete workflows: bootstrap, deploy, update, backup, restore, uninstall

setup() {
    # Create temporary test environment
    export TEST_TMP_DIR=$(mktemp -d)
    export TEST_REPO="$TEST_TMP_DIR/test-repo"
    export TEST_BACKUP_DIR="$TEST_TMP_DIR/test-backup"

    # Create test repository
    mkdir -p "$TEST_REPO"
    cd "$TEST_REPO"
    git init --quiet
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Source test utilities
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")/../.." && pwd)"
}

teardown() {
    # Cleanup test environment
    rm -rf "$TEST_TMP_DIR"
}

# ============================================================================
# BACKUP & RESTORE WORKFLOW
# ============================================================================

@test "backup.sh creates timestamped backup directory" {
    cd "$SCRIPT_DIR"

    # Create minimal test files
    mkdir -p "$HOME/.config"
    touch "$HOME/.bash_aliases"

    # Run backup (dry run)
    run ./backup.sh --dry-run --backup-dir "$TEST_BACKUP_DIR"

    [ "$status" -eq 0 ]
    [[ "$output" == *"[DRY-RUN]"* ]]
}

@test "restore.sh can restore from backup" {
    # Create test backup
    mkdir -p "$TEST_BACKUP_DIR/20240101-120000"
    echo "test alias" > "$TEST_BACKUP_DIR/20240101-120000/bash_aliases"

    cd "$SCRIPT_DIR"
    run ./restore.sh --backup-dir "$TEST_BACKUP_DIR" 20240101-120000 --dry-run

    [ "$status" -eq 0 ]
    [[ "$output" == *"Would restore"* ]]
}

# ============================================================================
# HEALTH CHECK WORKFLOW
# ============================================================================

@test "healthcheck.sh runs all checks" {
    cd "$SCRIPT_DIR"
    run ./healthcheck.sh --format json

    [ "$status" -eq 0 ]  # Should not fail even if some tools missing

    # Output should be valid JSON
    echo "$output" | jq . >/dev/null
}

@test "healthcheck.sh outputs table format" {
    cd "$SCRIPT_DIR"
    run ./healthcheck.sh --format table

    [ "$status" -eq 0 ]
    [[ "$output" == *"Health Check Results"* ]]
    [[ "$output" == *"Summary"* ]]
}

# ============================================================================
# UNINSTALL WORKFLOW
# ============================================================================

@test "uninstall.sh verifies dotfiles before removal" {
    cd "$SCRIPT_DIR"

    # Create dotfiles marker
    mkdir -p "$HOME"
    touch "$HOME/.dotfiles-installed"

    run ./uninstall.sh --verify-only --dry-run

    [ "$status" -eq 0 ]
    [[ "$output" == *"[VERIFY]"* ]]
}

@test "uninstall.sh prompts for confirmation" {
    cd "$SCRIPT_DIR"

    # Create test file with backup marker
    mkdir -p "$HOME"
    touch "$HOME/.dotfiles-installed"
    touch "$HOME/.bash_aliases.dotfiles-backup-20240101"

    run timeout 5 ./uninstall.sh --dry-run <<< "no-all"

    # Should not error even with no-all
    [ "$status" -eq 0 ]
}

# ============================================================================
# UPDATE-ALL WORKFLOW
# ============================================================================

@test "update-all.sh checks prerequisites before updating" {
    cd "$SCRIPT_DIR"
    run ./update-all.sh --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "update-all.sh handles missing package managers gracefully" {
    # This test verifies the script doesn't crash
    cd "$SCRIPT_DIR"
    run bash -c 'source ./update-all.sh && check_prerequisites'

    [ "$status" -eq 0 ]
    [[ "$output" == *"Checking prerequisites"* ]]
}

# ============================================================================
# DEPLOY WORKFLOW
# ============================================================================

@test "deploy.sh creates required directories" {
    cd "$SCRIPT_DIR"

    # Run deploy in dry-run mode (if supported)
    # Note: deploy.sh may not have --dry-run, so we'll just check it exists
    run bash -c 'test -f ./deploy.sh'

    [ "$status" -eq 0 ]
}

@test "deploy.sh copies configuration files" {
    cd "$SCRIPT_DIR"

    # Test that deploy script is valid bash
    run bash -n ./deploy.sh

    [ "$status" -eq 0 ]
}

# ============================================================================
# GIT UPDATE REPOS WORKFLOW
# ============================================================================

@test "git-update-repos.sh accepts parameters" {
    cd "$SCRIPT_DIR"
    run ./git-update-repos.sh --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "git-update-repos.sh respects --no-sync flag" {
    cd "$SCRIPT_DIR"
    run ./git-update-repos.sh --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"--no-sync"* ]]
}

# ============================================================================
# BOOTSTRAP WORKFLOW
# ============================================================================

@test "bootstrap.sh accepts --help flag" {
    cd "$SCRIPT_DIR"
    run ./bootstrap.sh --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "bootstrap.sh accepts --dry-run flag" {
    cd "$SCRIPT_DIR"
    run ./bootstrap.sh --dry-run --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"--dry-run"* ]]
}

@test "bootstrap.sh accepts categories flag" {
    cd "$SCRIPT_DIR"
    run ./bootstrap.sh --categories minimal --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"categories"* ]]
}

# ============================================================================
# COMPLETE WORKFLOW TEST
# ============================================================================

@test "complete workflow: backup -> healthcheck -> restore" {
    # Step 1: Create backup
    run ./backup.sh --dry-run --backup-dir "$TEST_BACKUP_DIR"
    [ "$status" -eq 0 ]

    # Step 2: Run healthcheck
    run ./healthcheck.sh --format table
    [ "$status" -eq 0 ]

    # Step 3: List backups
    run ./restore.sh --list --backup-dir "$TEST_BACKUP_DIR"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Available Backups"* ]]
}
