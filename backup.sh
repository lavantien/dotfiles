#!/usr/bin/env bash
# Backup Script - Creates timestamped backups of dotfiles
# Usage: ./backup.sh [--dry-run] [--keep N] [--backup-dir path]

set -e

# ============================================================================
# SETUP
# ============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Defaults
DRY_RUN=false
KEEP_BACKUPS=5
BACKUP_DIR="$HOME/.dotfiles-backup"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
CURRENT_BACKUP="$BACKUP_DIR/$TIMESTAMP"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --keep)
            KEEP_BACKUPS="$2"
            shift 2
            ;;
        --backup-dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--dry-run] [--keep N] [--backup-dir path]"
            echo "  --dry-run     Show what would be backed up without doing it"
            echo "  --keep N       Keep N most recent backups (default: 5)"
            echo "  --backup-dir    Custom backup directory (default: ~/.dotfiles-backup)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage"
            exit 1
            ;;
    esac
done

# ============================================================================
# BACKUP FUNCTIONS
# ============================================================================

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

backup_file() {
    local src="$1"
    local dst="$2"

    if [[ ! -e "$src" ]]; then
        log_warning "File not found (skipping): $src"
        return 1
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${CYAN}[DRY-RUN]${NC} Would backup: $src"
        return 0
    fi

    # Create destination directory if needed
    if ! mkdir -p "$(dirname "$dst")" 2>/dev/null; then
        log_error "Failed to create directory: $(dirname "$dst")"
        return 1
    fi

    # Copy file/directory with better error handling
    local error_output
    if ! error_output=$(cp -r "$src" "$dst" 2>&1); then
        log_error "Failed to backup: $src"
        log_error "Error: $error_output"
        return 1
    fi

    log_success "Backed up: $src"
    return 0
}

cleanup_old_backups() {
    if [[ "$KEEP_BACKUPS" -le 0 ]]; then
        return 0
    fi

    log_info "Cleaning up old backups (keeping $KEEP_BACKUPS most recent)..."

    # Check backup directory exists
    if [[ ! -d "$BACKUP_DIR" ]]; then
        return 0
    fi

    # Get list of backup directories, sorted by name (which is timestamp)
    local backups=()
    while IFS= read -r -d '' backup; do
        backups+=("$(basename "$backup")")
    done < <(find "$BACKUP_DIR" -maxdepth 1 -type d -regex '.*/[0-9]\{8\}-[0-9]\{6\}$' -print0 2>/dev/null | sort -rz)

    if [[ ${#backups[@]} -le $KEEP_BACKUPS ]]; then
        log_info "No old backups to remove (have ${#backups[@]}, keeping $KEEP_BACKUPS)"
        return 0
    fi

    # Remove old backups
    local to_remove=("${backups[@]:$KEEP_BACKUPS}")
    for old_backup in "${to_remove[@]}"; do
        local backup_path="$BACKUP_DIR/$old_backup"
        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "  ${CYAN}[DRY-RUN]${NC} Would remove old backup: $backup_path"
        else
            local error_output
            if ! error_output=$(rm -rf "$backup_path" 2>&1); then
                log_error "Failed to remove: $backup_path"
                log_error "Error: $error_output"
            else
                log_success "Removed old backup: $backup_path"
            fi
        fi
    done
}

print_backup_summary() {
    local backup_path="$1"
    local count="$2"

    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}       Backup Summary${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -e "${BLUE}Location:${NC}  $backup_path"
    echo -e "${BLUE}Files:${NC}     $count"
    echo -e "${BLUE}Date:${NC}      $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${BLUE}Size:${NC}      $(du -sh "$backup_path" 2>/dev/null | cut -f1)"
    echo -e "${CYAN}========================================${NC}"
}

# ============================================================================
# MAIN BACKUP PROCESS
# ============================================================================

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}   Dotfiles Backup${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "${BLUE}Backup Dir:${NC} $CURRENT_BACKUP"
echo -e "${BLUE}Dry Run:${NC}    $DRY_RUN"
echo -e "${BLUE}Keep:${NC}       $KEEP_BACKUPS backups"
echo -e "${CYAN}========================================${NC}"
echo ""

# Create backup directory
if [[ "$DRY_RUN" == "false" ]]; then
    mkdir -p "$CURRENT_BACKUP"
    log_success "Created backup directory: $CURRENT_BACKUP"
else
    echo -e "${CYAN}[DRY-RUN]${NC} Would create backup directory: $CURRENT_BACKUP"
fi
echo ""

backuped_count=0

# Backup shell configs
echo -e "${YELLOW}=== Shell Configs ===${NC}"
backup_file "$HOME/.bashrc" "$CURRENT_BACKUP/bashrc" && ((backuped_count++)) || true
backup_file "$HOME/.bash_aliases" "$CURRENT_BACKUP/bash_aliases" && ((backuped_count++)) || true
backup_file "$HOME/.zshrc" "$CURRENT_BACKUP/zshrc" && ((backuped_count++)) || true
backup_file "$HOME/.bash_profile" "$CURRENT_BACKUP/bash_profile" && ((backuped_count++)) || true

# Backup git configs
echo -e "${YELLOW}=== Git Configs ===${NC}"
backup_file "$HOME/.gitconfig" "$CURRENT_BACKUP/gitconfig" && ((backuped_count++)) || true
backup_file "$HOME/.gitignore" "$CURRENT_BACKUP/gitignore" && ((backuped_count++)) || true
backup_file "$HOME/.gitattributes" "$CURRENT_BACKUP/gitattributes" && ((backuped_count++)) || true

# Backup Neovim configs
echo -e "${YELLOW}=== Neovim Configs ===${NC}"
backup_file "$HOME/.config/nvim" "$CURRENT_BACKUP/nvim-config" && ((backuped_count++)) || true
backup_file "$HOME/.config/nvim/init.lua" "$CURRENT_BACKUP/init.lua" && ((backuped_count++)) || true
backup_file "$HOME/init.lua" "$CURRENT_BACKUP/init.lua-root" && ((backuped_count++)) || true

# Backup other editor configs
echo -e "${YELLOW}=== Editor Configs ===${NC}"
backup_file "$HOME/.vimrc" "$CURRENT_BACKUP/vimrc" && ((backuped_count++)) || true
backup_file "$HOME/.vim" "$CURRENT_BACKUP/vim" && ((backuped_count++)) || true

# Backup terminal configs
echo -e "${YELLOW}=== Terminal Configs ===${NC}"
backup_file "$HOME/.config/wezterm/wezterm.lua" "$CURRENT_BACKUP/wezterm.lua" && ((backuped_count++)) || true
backup_file "$HOME/wezterm.lua" "$CURRENT_BACKUP/wezterm.lua-root" && ((backuped_count++)) || true

# Backup PowerShell (on Windows or if present)
echo -e "${YELLOW}=== PowerShell Configs ===${NC}"
if [[ -d "$HOME/.config/powershell" ]]; then
    backup_file "$HOME/.config/powershell" "$CURRENT_BACKUP/powershell" && ((backuped_count++)) || true
fi

# Backup tool configs
echo -e "${YELLOW}=== Tool Configs ===${NC}"
backup_file "$HOME/.aider.conf.yml" "$CURRENT_BACKUP/aider.conf.yml" && ((backuped_count++)) || true
backup_file "$HOME/.editorconfig" "$CURRENT_BACKUP/editorconfig" && ((backuped_count++)) || true

# Backup ssh config
echo -e "${YELLOW}=== SSH Configs ===${NC}"
backup_file "$HOME/.ssh/config" "$CURRENT_BACKUP/ssh-config" && ((backuped_count++)) || true

# Backup Claude configs
echo -e "${YELLOW}=== Claude Configs ===${NC}"
backup_file "$HOME/.claude" "$CURRENT_BACKUP/claude-config" && ((backuped_count++)) || true

# Create backup manifest
if [[ "$DRY_RUN" == "false" ]]; then
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$CURRENT_BACKUP/MANIFEST.txt"
    echo "Hostname: $(hostname)" >> "$CURRENT_BACKUP/MANIFEST.txt"
    echo "User: $(whoami)" >> "$CURRENT_BACKUP/MANIFEST.txt"
    echo "Files backed up: $backuped_count" >> "$CURRENT_BACKUP/MANIFEST.txt"
    log_success "Created backup manifest"
fi

# Clean up old backups
cleanup_old_backups

# Print summary
if [[ "$DRY_RUN" == "false" ]]; then
    print_backup_summary "$CURRENT_BACKUP" "$backuped_count"
    echo ""
    log_success "Backup complete!"
    echo -e "${YELLOW}To restore, run: ./restore.sh --backup-dir $CURRENT_BACKUP${NC}"
else
    echo ""
    log_info "Dry run complete - no files were actually backed up"
    echo -e "${YELLOW}Run without --dry-run to create actual backup${NC}"
fi

exit 0
