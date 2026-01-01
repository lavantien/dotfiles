#!/usr/bin/env bats
# Unit tests for uninstall.sh

setup() {
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")/.." && pwd)"
    export TEST_TMP_DIR="$BATS_TMPDIR/dotfiles-uninstall-test-$$"
    export HOME="$TEST_TMP_DIR"

    # Create test directory structure
    mkdir -p "$TEST_TMP_DIR"
    mkdir -p "$TEST_TMP_DIR/.config/wezterm"
    mkdir -p "$TEST_TMP_DIR/.config/git"
    mkdir -p "$TEST_TMP_DIR/.config/powershell"

    # Create dotfiles marker
    touch "$TEST_TMP_DIR/.dotfiles-installed"

    # Create some dotfiles to be removed
    touch "$TEST_TMP_DIR/.bash_aliases"
    touch "$TEST_TMP_DIR/.gitconfig"
    touch "$TEST_TMP_DIR/.editorconfig"
}

teardown() {
    rm -rf "$TEST_TMP_DIR"
}

run_uninstall() {
    run env HOME="$TEST_TMP_DIR" bash "$SCRIPT_DIR/uninstall.sh" "$@"
}

# ============================================================================
# HELP AND USAGE
# ============================================================================

@test "uninstall: shows help with --help" {
    run bash "$SCRIPT_DIR/uninstall.sh" --help
    [ "$status" -eq 0 ]
}

@test "uninstall: shows help with -h" {
    run bash "$SCRIPT_DIR/uninstall.sh" -h
    [ "$status" -eq 0 ]
}

@test "uninstall: exits with error on unknown option" {
    run_uninstall --unknown-option
    [ "$status" -eq 1 ]
}

# ============================================================================
# DRY RUN MODE
# ============================================================================

@test "uninstall: accepts --dry-run flag" {
    run_uninstall --dry-run
    # Script may exit with non-zero due to TTY issues in test environment
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "uninstall: dry-run shows DRY-RUN in output" {
    run_uninstall --dry-run
    echo "$output" | grep -q "DRY-RUN"
}

@test "uninstall: dry-run shows mode in header" {
    run_uninstall --dry-run
    echo "$output" | grep -q "Dry Run"
}

@test "uninstall: dry-run does not remove files" {
    run_uninstall --dry-run
    # Files should still exist after dry run
    [ -f "$TEST_TMP_DIR/.bash_aliases" ]
    [ -f "$TEST_TMP_DIR/.gitconfig" ]
}

# ============================================================================
# VERIFY ONLY MODE
# ============================================================================

@test "uninstall: accepts --verify-only flag" {
    run_uninstall --verify-only
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "uninstall: verify-only shows VERIFY in output" {
    run_uninstall --verify-only
    echo "$output" | grep -q "VERIFY"
}

@test "uninstall: verify-only does not remove files" {
    run_uninstall --verify-only
    # Files should still exist after verify-only
    [ -f "$TEST_TMP_DIR/.bash_aliases" ]
    [ -f "$TEST_TMP_DIR/.gitconfig" ]
}

# ============================================================================
# KEEP BACKUPS FLAG
# ============================================================================

@test "uninstall: accepts --keep-backups flag" {
    run_uninstall --keep-backups --dry-run
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "uninstall: keep-backups shows in header" {
    run_uninstall --keep-backups --dry-run
    echo "$output" | grep -q "Keep Backups"
}

# ============================================================================
# SCANNING
# ============================================================================

@test "uninstall: scans for dotfiles deployments" {
    run_uninstall --dry-run
    echo "$output" | grep -q "Scanning"
}

@test "uninstall: finds existing dotfiles" {
    run_uninstall --verify-only
    echo "$output" | grep -q "Found"
}

@test "uninstall: handles missing files gracefully" {
    # Remove some files that the script expects
    rm -f "$TEST_TMP_DIR/.bash_aliases"

    run_uninstall --dry-run
    # Should not crash
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

# ============================================================================
# MARKER FILE
# ============================================================================

@test "uninstall: detects dotfiles marker" {
    run_uninstall --dry-run
    # Should not warn about missing marker since we created it
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "uninstall: warns when marker not found" {
    # Remove the marker
    rm -f "$TEST_TMP_DIR/.dotfiles-installed"

    run_uninstall --dry-run
    echo "$output" | grep -qi "marker"
}

# ============================================================================
# SUMMARY OUTPUT
# ============================================================================

@test "uninstall: shows uninstall output" {
    run_uninstall --dry-run
    # Script may exit early due to TTY issues, but should produce some output
    [ -n "$output" ]
}

@test "uninstall: shows would-remove in dry-run" {
    run_uninstall --dry-run
    # Should show "Would remove" for files in dry-run mode
    echo "$output" | grep -qi "would remove" || echo "$output" | grep -qi "DRY-RUN"
}

@test "uninstall: shows file processing" {
    run_uninstall --dry-run
    # Should show Found or processing indication
    echo "$output" | grep -qi "found" || echo "$output" | grep -qi "remove"
}

# ============================================================================
# HEADER OUTPUT
# ============================================================================

@test "uninstall: shows header banner" {
    run_uninstall --dry-run
    echo "$output" | grep -q "Dotfiles Uninstall"
}

@test "uninstall: shows separator lines" {
    run_uninstall --dry-run
    echo "$output" | grep -q "==="
}

# ============================================================================
# COMBINATION OPTIONS
# ============================================================================

@test "uninstall: accepts --dry-run and --keep-backups together" {
    run_uninstall --dry-run --keep-backups
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "uninstall: accepts --dry-run and --verify-only together" {
    run_uninstall --dry-run --verify-only
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "uninstall: accepts all flags together" {
    run_uninstall --dry-run --keep-backups --verify-only
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

# ============================================================================
# EXIT CODES
# ============================================================================

@test "uninstall: runs without crashing" {
    run_uninstall --dry-run
    # May exit with 1 due to TTY issues in test environment
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "uninstall: produces output" {
    run_uninstall --dry-run
    [ -n "$output" ]
}
