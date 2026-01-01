#!/usr/bin/env bats
# Unit tests for backup.sh

setup() {
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")/.." && pwd)"
    export TEST_TMP_DIR="$BATS_TMPDIR/dotfiles-backup-test-$$"
    export BACKUP_DIR="$TEST_TMP_DIR/.dotfiles-backup"
    mkdir -p "$TEST_TMP_DIR"
    touch "$TEST_TMP_DIR/.bashrc"
    touch "$TEST_TMP_DIR/.bash_aliases"
    touch "$TEST_TMP_DIR/.zshrc"
    touch "$TEST_TMP_DIR/.gitconfig"
    touch "$TEST_TMP_DIR/init.lua"
}

teardown() {
    rm -rf "$TEST_TMP_DIR"
}

run_backup() {
    run env HOME="$TEST_TMP_DIR" bash "$SCRIPT_DIR/backup.sh" "$@"
}

@test "backup: shows help with --help" {
    run bash "$SCRIPT_DIR/backup.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "backup: shows help with -h" {
    run bash "$SCRIPT_DIR/backup.sh" -h
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "backup: exits with error on unknown option" {
    run bash "$SCRIPT_DIR/backup.sh" --unknown-option
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unknown option" ]]
}

@test "backup: dry-run shows DRY-RUN in output" {
    run_backup --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "DRY-RUN" ]] || [[ "$output" =~ "Dry run" ]]
}

@test "backup: dry-run does not create backup directory" {
    run_backup --dry-run --backup-dir "$TEST_TMP_DIR/test-backup"
    [ "$status" -eq 0 ]
    local backup_count=$(find "$TEST_TMP_DIR/test-backup" -mindepth 1 -type d 2>/dev/null | wc -l)
    [ "$backup_count" -eq 0 ]
}

@test "backup: dry-run shows what would be backed up" {
    run_backup --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Shell Configs" ]] || [[ "$output" =~ "Git Configs" ]]
}

@test "backup: creates backup directory when not dry-run" {
    run_backup --backup-dir "$TEST_TMP_DIR/test-backup"
    [ "$status" -eq 0 ]
    local backup_count=$(find "$TEST_TMP_DIR/test-backup" -mindepth 1 -type d 2>/dev/null | wc -l)
    [ "$backup_count" -gt 0 ]
}

@test "backup: creates MANIFEST.txt in backup" {
    run_backup --backup-dir "$TEST_TMP_DIR/test-backup"
    [ "$status" -eq 0 ]
    local backup_path=$(find "$TEST_TMP_DIR/test-backup" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)
    [ -f "$backup_path/MANIFEST.txt" ]
}

@test "backup: MANIFEST contains timestamp" {
    run_backup --backup-dir "$TEST_TMP_DIR/test-backup"
    [ "$status" -eq 0 ]
    local backup_path=$(find "$TEST_TMP_DIR/test-backup" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)
    run cat "$backup_path/MANIFEST.txt"
    [[ "$output" =~ "Timestamp:" ]]
}

@test "backup: MANIFEST contains file count" {
    run_backup --backup-dir "$TEST_TMP_DIR/test-backup2"
    [ "$status" -eq 0 ]
    local backup_path=$(find "$TEST_TMP_DIR/test-backup2" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)
    run cat "$backup_path/MANIFEST.txt"
    [[ "$output" =~ "Files backed up:" ]]
}

@test "backup: completes without errors" {
    run_backup --backup-dir "$TEST_TMP_DIR/test-backup"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "complete" ]]
}

@test "backup: handles missing files gracefully" {
    rm -f "$TEST_TMP_DIR/.bashrc" "$TEST_TMP_DIR/.gitconfig"
    run_backup --backup-dir "$TEST_TMP_DIR/test-backup"
    [ "$status" -eq 0 ]
}

@test "backup: backs up shell config files" {
    run_backup --backup-dir "$TEST_TMP_DIR/test-backup"
    [ "$status" -eq 0 ]
    local backup_path=$(find "$TEST_TMP_DIR/test-backup" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)
    [ -f "$backup_path/bashrc" ] || [ -f "$backup_path/bash_aliases" ] || [ -f "$backup_path/zshrc" ]
}

@test "backup: backs up git config files" {
    run_backup --backup-dir "$TEST_TMP_DIR/test-backup"
    [ "$status" -eq 0 ]
    local backup_path=$(find "$TEST_TMP_DIR/test-backup" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)
    [ -f "$backup_path/gitconfig" ]
}

@test "backup: --keep flag controls backup retention" {
    mkdir -p "$BACKUP_DIR"
    for i in {1..7}; do
        timestamp=$(printf "202401%02d-120000" $i)
        mkdir -p "$BACKUP_DIR/$timestamp"
        touch "$BACKUP_DIR/$timestamp/test.txt"
    done
    run_backup --keep 3 --backup-dir "$BACKUP_DIR"
    [ "$status" -eq 0 ]
    local remaining=$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    # 7 old + 1 new = 8 total, keep 3 most recent, so 3 should remain
    [ "$remaining" -eq 3 ]
}

@test "backup: --backup-dir uses custom directory" {
    run_backup --backup-dir "$TEST_TMP_DIR/custom-backup"
    [ "$status" -eq 0 ]
    local backup_count=$(find "$TEST_TMP_DIR/custom-backup" -mindepth 1 -type d 2>/dev/null | wc -l)
    [ "$backup_count" -gt 0 ]
}

@test "backup: shows restore command in output" {
    run_backup --backup-dir "$TEST_TMP_DIR/test-backup"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "restore" ]] || [[ "$output" =~ "./restore.sh" ]]
}

@test "backup: accepts --dry-run and --keep together" {
    run_backup --dry-run --keep 3
    [ "$status" -eq 0 ]
    [[ "$output" =~ "DRY-RUN" ]]
}

@test "backup: accepts all options together" {
    run_backup --dry-run --keep 2 --backup-dir "$TEST_TMP_DIR/test"
    [ "$status" -eq 0 ]
}
