#!/usr/bin/env bats
# Unit tests for restore.sh

setup() {
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")/.." && pwd)"
    export TEST_TMP_DIR="$BATS_TMPDIR/dotfiles-restore-test-$$"
    export BACKUP_DIR="$TEST_TMP_DIR/test-backup"
    export HOME="$TEST_TMP_DIR"

    mkdir -p "$TEST_TMP_DIR"
    mkdir -p "$BACKUP_DIR"

    # Create a test backup directory structure
    mkdir -p "$BACKUP_DIR/20240101-120000"

    # Create test files in backup
    echo "test bashrc" > "$BACKUP_DIR/20240101-120000/bashrc"
    echo "test bash_aliases" > "$BACKUP_DIR/20240101-120000/bash_aliases"
    echo "test gitconfig" > "$BACKUP_DIR/20240101-120000/gitconfig"
    echo "test zshrc" > "$BACKUP_DIR/20240101-120000/zshrc"
    echo "test vimrc" > "$BACKUP_DIR/20240101-120000/vimrc"

    # Create manifest
    cat > "$BACKUP_DIR/20240101-120000/MANIFEST.txt" << 'EOF'
Timestamp: 2024-01-01T12:00:00Z
Hostname: testhost
User: testuser
Files backed up: 5
EOF
}

teardown() {
    rm -rf "$TEST_TMP_DIR"
}

run_restore() {
    run env HOME="$TEST_TMP_DIR" bash "$SCRIPT_DIR/restore.sh" "$@"
}

# ============================================================================
# HELP AND USAGE
# ============================================================================

@test "restore: shows help with --help" {
    run bash "$SCRIPT_DIR/restore.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "restore: shows help with -h" {
    run bash "$SCRIPT_DIR/restore.sh" -h
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "restore: exits with error on unknown option" {
    run_restore --unknown-option
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unknown option" ]]
}

# ============================================================================
# LIST BACKUPS
# ============================================================================

@test "restore: --list shows available backups" {
    run_restore --backup-dir "$BACKUP_DIR" --list
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Available Backups" ]]
    [[ "$output" =~ "20240101-120000" ]]
}

@test "restore: --list shows backup details from manifest" {
    run_restore --backup-dir "$BACKUP_DIR" --list
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Timestamp:" ]]
    [[ "$output" =~ "Hostname:" ]]
    [[ "$output" =~ "Files backed up:" ]]
}

@test "restore: --list handles non-existent backup directory" {
    run_restore --backup-dir "$TEST_TMP_DIR/nonexistent" --list
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Backup directory not found" ]] || [[ "$output" =~ "No backups found" ]]
}

@test "restore: --list handles empty backup directory" {
    mkdir -p "$TEST_TMP_DIR/empty-backup"
    run_restore --backup-dir "$TEST_TMP_DIR/empty-backup" --list
    [ "$status" -eq 1 ]
    [[ "$output" =~ "No backups found" ]] || [[ "$output" =~ "not found" ]]
}

# ============================================================================
# DRY RUN MODE
# ============================================================================

@test "restore: dry-run shows DRY-RUN in output" {
    run_restore --backup-dir "$BACKUP_DIR" --dry-run --force 20240101-120000
    [ "$status" -eq 0 ]
    [[ "$output" =~ "DRY-RUN" ]]
}

@test "restore: dry-run does not modify files" {
    echo "original content" > "$TEST_TMP_DIR/.bashrc"

    run_restore --backup-dir "$BACKUP_DIR" --dry-run --force 20240101-120000
    [ "$status" -eq 0 ]

    # File should not be modified
    grep -q "original content" "$TEST_TMP_DIR/.bashrc"
}

@test "restore: dry-run shows what would be restored" {
    run_restore --backup-dir "$BACKUP_DIR" --dry-run --force 20240101-120000
    [ "$status" -eq 0 ]
    [[ "$output" =~ "bashrc" ]] || [[ "$output" =~ "gitconfig" ]]
}

# ============================================================================
# FILE RESTORATION
# ============================================================================

@test "restore: restores bashrc file" {
    run_restore --backup-dir "$BACKUP_DIR" --force 20240101-120000
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMP_DIR/.bashrc" ]
    grep -q "test bashrc" "$TEST_TMP_DIR/.bashrc"
}

@test "restore: restores bash_aliases file" {
    run_restore --backup-dir "$BACKUP_DIR" --force 20240101-120000
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMP_DIR/.bash_aliases" ]
    grep -q "test bash_aliases" "$TEST_TMP_DIR/.bash_aliases"
}

@test "restore: restores gitconfig file" {
    run_restore --backup-dir "$BACKUP_DIR" --force 20240101-120000
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMP_DIR/.gitconfig" ]
    grep -q "test gitconfig" "$TEST_TMP_DIR/.gitconfig"
}

@test "restore: restores zshrc file" {
    run_restore --backup-dir "$BACKUP_DIR" --force 20240101-120000
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMP_DIR/.zshrc" ]
    grep -q "test zshrc" "$TEST_TMP_DIR/.zshrc"
}

@test "restore: restores vimrc file" {
    run_restore --backup-dir "$BACKUP_DIR" --force 20240101-120000
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMP_DIR/.vimrc" ]
    grep -q "test vimrc" "$TEST_TMP_DIR/.vimrc"
}

# ============================================================================
# BACKUP EXISTING FILES
# ============================================================================

@test "restore: backs up existing files before restore" {
    echo "original bashrc" > "$TEST_TMP_DIR/.bashrc"

    run_restore --backup-dir "$BACKUP_DIR" --force 20240101-120000
    [ "$status" -eq 0 ]

    # Check that backup was created
    ls "$TEST_TMP_DIR/.bashrc.dotfiles-backup-"* 2>/dev/null
    local backup_count=$(ls "$TEST_TMP_DIR/.bashrc.dotfiles-backup-"* 2>/dev/null | wc -l | tr -d ' ')
    [ "$backup_count" -ge 1 ]
}

@test "restore: backup contains original content" {
    echo "original bashrc content" > "$TEST_TMP_DIR/.bashrc"

    run_restore --backup-dir "$BACKUP_DIR" --force 20240101-120000
    [ "$status" -eq 0 ]

    # Find the backup file and check its content
    local backup_file=$(ls "$TEST_TMP_DIR/.bashrc.dotfiles-backup-"* 2>/dev/null | head -1)
    grep -q "original bashrc content" "$backup_file"
}

# ============================================================================
# ERROR HANDLING
# ============================================================================

@test "restore: fails when backup not found" {
    run_restore --backup-dir "$BACKUP_DIR" --force nonexistent-backup
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unknown option or invalid backup" ]] || [[ "$output" =~ "not found" ]] || [[ "$output" =~ "Backup not found" ]]
}

@test "restore: handles missing source files gracefully" {
    # Create backup with only some files
    mkdir -p "$BACKUP_DIR/partial-backup"
    echo "test" > "$BACKUP_DIR/partial-backup/bashrc"
    echo "Timestamp: 2024-01-01T12:00:00Z" > "$BACKUP_DIR/partial-backup/MANIFEST.txt"

    run_restore --backup-dir "$BACKUP_DIR" --force partial-backup
    [ "$status" -eq 0 ]
    # Should complete without error even if some files don't exist in backup
}

@test "restore: completes with restore summary" {
    run_restore --backup-dir "$BACKUP_DIR" --force 20240101-120000
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Restore Summary" ]] || [[ "$output" =~ "summary" ]]
    [[ "$output" =~ "complete" ]]
}

# ============================================================================
# MANIFEST HANDLING
# ============================================================================

@test "restore: displays manifest when restoring" {
    run_restore --backup-dir "$BACKUP_DIR" --force 20240101-120000
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Backup Manifest" ]] || [[ "$output" =~ "Manifest" ]]
}

@test "restore: shows manifest details" {
    run_restore --backup-dir "$BACKUP_DIR" --force 20240101-120000
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Timestamp:" ]]
    [[ "$output" =~ "Hostname:" ]]
}

# ============================================================================
# CUSTOM BACKUP DIRECTORY
# ============================================================================

@test "restore: accepts custom backup directory" {
    local custom_dir="$TEST_TMP_DIR/custom-backup"
    mkdir -p "$custom_dir/20240101-120000"
    echo "test" > "$custom_dir/20240101-120000/bashrc"
    echo "Timestamp: 2024-01-01T12:00:00Z" > "$custom_dir/20240101-120000/MANIFEST.txt"

    run_restore --backup-dir "$custom_dir" --force 20240101-120000
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMP_DIR/.bashrc" ]
}

# ============================================================================
# COMBINATION OPTIONS
# ============================================================================

@test "restore: accepts --dry-run and --backup-dir together" {
    run_restore --dry-run --backup-dir "$BACKUP_DIR" --force 20240101-120000
    [ "$status" -eq 0 ]
    [[ "$output" =~ "DRY-RUN" ]]
}

@test "restore: accepts --force and --backup-dir together" {
    run_restore --force --backup-dir "$BACKUP_DIR" 20240101-120000
    [ "$status" -eq 0 ]
}

@test "restore: accepts all options together" {
    run_restore --dry-run --force --backup-dir "$BACKUP_DIR" 20240101-120000
    [ "$status" -eq 0 ]
}

# ============================================================================
# DIRECTORY RESTORATION
# ============================================================================

@test "restore: restores nvim-config directory" {
    mkdir -p "$BACKUP_DIR/20240101-120000/nvim-config"
    echo "test nvim" > "$BACKUP_DIR/20240101-120000/nvim-config/init.lua"

    run_restore --backup-dir "$BACKUP_DIR" --force 20240101-120000
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMP_DIR/.config/nvim/init.lua" ]
}

@test "restore: restores vim directory" {
    mkdir -p "$BACKUP_DIR/20240101-120000/vim"
    echo "test vim" > "$BACKUP_DIR/20240101-120000/vim/test.vim"

    run_restore --backup-dir "$BACKUP_DIR" --force 20240101-120000
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMP_DIR/.vim/test.vim" ]
}

@test "restore: creates destination directories as needed" {
    mkdir -p "$BACKUP_DIR/20240101-120000/nvim-config"
    echo "test" > "$BACKUP_DIR/20240101-120000/nvim-config/init.lua"

    # Remove .config directory if it exists
    rm -rf "$TEST_TMP_DIR/.config"

    run_restore --backup-dir "$BACKUP_DIR" --force 20240101-120000
    [ "$status" -eq 0 ]
    [ -d "$TEST_TMP_DIR/.config/nvim" ]
}

# ============================================================================
# RESTORE COUNT
# ============================================================================

@test "restore: reports restored file count" {
    run_restore --backup-dir "$BACKUP_DIR" --force 20240101-120000
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Restored:" ]] || [[ "$output" =~ "[0-9]+ files" ]]
}
