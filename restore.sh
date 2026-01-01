#!/usr/bin/env bash
# Restore Script - Restores dotfiles from backup
# Usage: ./restore.sh [--backup-dir path] [--list] [--dry-run] [--force]

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
BACKUP_DIR="$HOME/.dotfiles-backup"
LIST_ONLY=false
DRY_RUN=false
FORCE=false
SELECTED_BACKUP=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --backup-dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        --list)
            LIST_ONLY=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--backup-dir path] [--list] [--dry-run] [--force]"
            echo "  --backup-dir    Path to backup directory (default: ~/.dotfiles-backup)"
            echo "  --list          List available backups and exit"
            echo "  --dry-run       Show what would be restored without doing it"
            echo "  --force         Restore without confirmation prompts"
            exit 0
            ;;
        *)
            if [[ -z "$SELECTED_BACKUP" ]] && [[ -d "$BACKUP_DIR/$1" ]]; then
                SELECTED_BACKUP="$1"
            else
                echo "Unknown option or invalid backup: $1"
                echo "Use --help for usage"
                exit 1
            fi
            shift
            ;;
    esac
done

# ============================================================================
# RESTORE FUNCTIONS
# ============================================================================

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

list_backups() {
    echo -e "${CYAN}Available Backups:${NC}"
    echo -e "${CYAN}========================================${NC}"

    if [[ ! -d "$BACKUP_DIR" ]]; then
        log_warning "Backup directory not found: $BACKUP_DIR"
        return 1
    fi

    local found=false
    for backup in $(ls -1t "$BACKUP_DIR" 2>/dev/null); do
        local backup_path="$BACKUP_DIR/$backup"
        local manifest="$backup_path/MANIFEST.txt"

        if [[ -d "$backup_path" ]] && [[ -f "$manifest" ]]; then
            found=true
            echo ""
            echo -e "${BLUE}Backup:${NC}   $backup"
            echo -e "${BLUE}Path:${NC}     $backup_path"

            # Show manifest info
            if [[ -f "$manifest" ]]; then
                echo -e "${BLUE}Details:${NC}"
                cat "$manifest" | sed 's/^/    /'
            fi
        fi
    done

    if [[ "$found" == "false" ]]; then
        log_warning "No backups found in $BACKUP_DIR"
        return 1
    fi

    return 0
}

confirm_restore() {
    local target="$1"

    if [[ "$FORCE" == "true" ]]; then
        return 0
    fi

    echo -e "${YELLOW}WARNING: This will overwrite your current configurations!${NC}"
    echo -e "${YELLOW}Target: $target${NC}"
    echo ""
    read -p "Continue? (yes/no): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]es$ ]]; then
        return 0
    else
        log_info "Restore cancelled"
        exit 0
    fi
}

restore_file() {
    local src="$1"
    local dst="$2"

    if [[ ! -e "$src" ]]; then
        log_warning "Source not found (skipping): $src"
        return 1
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${CYAN}[DRY-RUN]${NC} Would restore: $src → $dst"
        return 0
    fi

    # Create destination directory if needed
    local dest_dir
    dest_dir="$(dirname "$dst")"
    if ! mkdir -p "$dest_dir" 2>/dev/null; then
        log_error "Failed to create directory: $dest_dir"
        return 1
    fi

    # Backup existing file first
    if [[ -e "$dst" ]]; then
        local timestamp
        timestamp=$(date +%Y%m%d-%H%M%S)
        local backup_existing="$dst.dotfiles-backup-$timestamp"
        if ! cp -r "$dst" "$backup_existing" 2>/dev/null; then
            log_warning "Failed to backup existing: $dst (continuing anyway)"
        else
            log_info "Backed up existing: $dst → $backup_existing"
        fi
    fi

    # Restore file with better error handling
    local error_output
    if ! error_output=$(cp -r "$src" "$dst" 2>&1); then
        log_error "Failed to restore: $src → $dst"
        log_error "Error: $error_output"
        return 1
    fi

    log_success "Restored: $src → $dst"
    return 0
}

# ============================================================================
# MAIN RESTORE PROCESS
# ============================================================================

# List backups and exit if --list
if [[ "$LIST_ONLY" == "true" ]]; then
    list_backups
    exit $?
fi

# If no backup specified, prompt user
if [[ -z "$SELECTED_BACKUP" ]]; then
    echo -e "${CYAN}Select a backup to restore:${NC}"
    list_backups
    echo ""
    read -p "Enter backup name (or 'cancel'): " SELECTED_BACKUP

    if [[ "$SELECTED_BACKUP" == "cancel" ]]; then
        log_info "Restore cancelled"
        exit 0
    fi
fi

# Validate backup exists
RESTORE_PATH="$BACKUP_DIR/$SELECTED_BACKUP"
if [[ ! -d "$RESTORE_PATH" ]]; then
    log_error "Backup not found: $RESTORE_PATH"
    exit 1
fi

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}   Dotfiles Restore${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "${BLUE}From:${NC}      $RESTORE_PATH"
echo -e "${BLUE}Dry Run:${NC}   $DRY_RUN"
echo -e "${BLUE}Force:${NC}     $FORCE"
echo -e "${CYAN}========================================${NC}"
echo ""

# Confirm restore
confirm_restore "$RESTORE_PATH"
echo ""

# Read manifest if available
MANIFEST="$RESTORE_PATH/MANIFEST.txt"
if [[ -f "$MANIFEST" ]]; then
    echo -e "${YELLOW}Backup Manifest:${NC}"
    cat "$MANIFEST"
    echo ""
fi

restored_count=0

# Restore shell configs
echo -e "${YELLOW}=== Restoring Shell Configs ===${NC}"
[[ -f "$RESTORE_PATH/bashrc" ]] && restore_file "$RESTORE_PATH/bashrc" "$HOME/.bashrc" && ((restored_count++)) || true
[[ -f "$RESTORE_PATH/bash_aliases" ]] && restore_file "$RESTORE_PATH/bash_aliases" "$HOME/.bash_aliases" && ((restored_count++)) || true
[[ -f "$RESTORE_PATH/zshrc" ]] && restore_file "$RESTORE_PATH/zshrc" "$HOME/.zshrc" && ((restored_count++)) || true
[[ -f "$RESTORE_PATH/bash_profile" ]] && restore_file "$RESTORE_PATH/bash_profile" "$HOME/.bash_profile" && ((restored_count++)) || true

# Restore git configs
echo -e "${YELLOW}=== Restoring Git Configs ===${NC}"
[[ -f "$RESTORE_PATH/gitconfig" ]] && restore_file "$RESTORE_PATH/gitconfig" "$HOME/.gitconfig" && ((restored_count++)) || true
[[ -f "$RESTORE_PATH/gitignore" ]] && restore_file "$RESTORE_PATH/gitignore" "$HOME/.gitignore" && ((restored_count++)) || true
[[ -f "$RESTORE_PATH/gitattributes" ]] && restore_file "$RESTORE_PATH/gitattributes" "$HOME/.gitattributes" && ((restored_count++)) || true

# Restore Neovim configs
echo -e "${YELLOW}=== Restoring Neovim Configs ===${NC}"
[[ -d "$RESTORE_PATH/nvim-config" ]] && restore_file "$RESTORE_PATH/nvim-config" "$HOME/.config/nvim" && ((restored_count++)) || true
[[ -f "$RESTORE_PATH/init.lua" ]] && restore_file "$RESTORE_PATH/init.lua" "$HOME/.config/nvim/init.lua" && ((restored_count++)) || true
[[ -f "$RESTORE_PATH/init.lua-root" ]] && restore_file "$RESTORE_PATH/init.lua-root" "$HOME/init.lua" && ((restored_count++)) || true

# Restore other editor configs
echo -e "${YELLOW}=== Restoring Editor Configs ===${NC}"
[[ -f "$RESTORE_PATH/vimrc" ]] && restore_file "$RESTORE_PATH/vimrc" "$HOME/.vimrc" && ((restored_count++)) || true
[[ -d "$RESTORE_PATH/vim" ]] && restore_file "$RESTORE_PATH/vim" "$HOME/.vim" && ((restored_count++)) || true

# Restore terminal configs
echo -e "${YELLOW}=== Restoring Terminal Configs ===${NC}"
[[ -f "$RESTORE_PATH/wezterm.lua" ]] && restore_file "$RESTORE_PATH/wezterm.lua" "$HOME/.config/wezterm/wezterm.lua" && ((restored_count++)) || true
[[ -f "$RESTORE_PATH/wezterm.lua-root" ]] && restore_file "$RESTORE_PATH/wezterm.lua-root" "$HOME/wezterm.lua" && ((restored_count++)) || true

# Restore PowerShell configs (if backup exists)
echo -e "${YELLOW}=== Restoring PowerShell Configs ===${NC}"
[[ -d "$RESTORE_PATH/powershell" ]] && restore_file "$RESTORE_PATH/powershell" "$HOME/.config/powershell" && ((restored_count++)) || true

# Restore tool configs
echo -e "${YELLOW}=== Restoring Tool Configs ===${NC}"
[[ -f "$RESTORE_PATH/aider.conf.yml" ]] && restore_file "$RESTORE_PATH/aider.conf.yml" "$HOME/.aider.conf.yml" && ((restored_count++)) || true
[[ -f "$RESTORE_PATH/editorconfig" ]] && restore_file "$RESTORE_PATH/editorconfig" "$HOME/.editorconfig" && ((restored_count++)) || true

# Restore SSH config
echo -e "${YELLOW}=== Restoring SSH Configs ===${NC}"
[[ -f "$RESTORE_PATH/ssh-config" ]] && restore_file "$RESTORE_PATH/ssh-config" "$HOME/.ssh/config" && ((restored_count++)) || true

# Restore Claude configs
echo -e "${YELLOW}=== Restoring Claude Configs ===${NC}"
[[ -d "$RESTORE_PATH/claude-config" ]] && restore_file "$RESTORE_PATH/claude-config" "$HOME/.claude" && ((restored_count++)) || true

# Print summary
echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}       Restore Summary${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "${BLUE}From:${NC}       $RESTORE_PATH"
echo -e "${BLUE}Restored:${NC}   $restored_count files"
echo -e "${BLUE}Date:${NC}       $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "${CYAN}========================================${NC}"

if [[ "$DRY_RUN" == "false" ]]; then
    echo ""
    log_success "Restore complete!"
    echo -e "${YELLOW}Please reload your shell to apply changes${NC}"
else
    echo ""
    log_info "Dry run complete - no files were actually restored"
    echo -e "${YELLOW}Run without --dry-run to perform actual restore${NC}"
fi

exit 0
