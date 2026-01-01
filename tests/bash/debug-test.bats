#!/usr/bin/env bats

setup() {
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")/.." && pwd)"
    export TEST_TMP_DIR="$BATS_TMPDIR/debug-$$"
    mkdir -p "$TEST_TMP_DIR"
    touch "$TEST_TMP_DIR/.bashrc"
    touch "$TEST_TMP_DIR/.gitconfig"
}

teardown() {
    rm -rf "$TEST_TMP_DIR"
}

@test "debug: check backup creation" {
    local backup_dir="$TEST_TMP_DIR/debug-backup"
    
    echo "TEST_TMP_DIR: $TEST_TMP_DIR"
    echo "backup_dir: $backup_dir"
    
    run env HOME="$TEST_TMP_DIR" bash "$SCRIPT_DIR/backup.sh" --backup-dir "$backup_dir"
    echo "Exit status: $status"
    
    echo "=== Looking for backup in $backup_dir ==="
    find "$backup_dir" -type d
    
    local backup_path=$(find "$backup_dir" -type d -name "*-*" 2>/dev/null | head -1)
    echo "backup_path: $backup_path"
    
    if [ -n "$backup_path" ]; then
        echo "=== Files in $backup_path ==="
        ls -la "$backup_path"
    fi
    
    [ -f "$backup_path/MANIFEST.txt" ] || echo "MANIFEST.txt not found!"
}
