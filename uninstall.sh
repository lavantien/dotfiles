#!/usr/bin/env bash
# Uninstall Script - Safely removes dotfiles deployments
# Usage: ./uninstall.sh [--dry-run] [--keep-backups] [--verify-only]

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
KEEP_BACKUPS=false
VERIFY_ONLY=false
DELETED_COUNT=0
SKIPPED_COUNT=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --keep-backups)
            KEEP_BACKUPS=true
            shift
            ;;
        --verify-only)
            VERIFY_ONLY=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--dry-run] [--keep-backups] [--verify-only]"
            echo "  --dry-run       Show what would be removed without doing it"
            echo "  --keep-backups  Don't remove backup directory"
            echo "  --verify-only    Only verify dotfiles, don't remove anything"
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
# DOTFILES TRACKING
# ============================================================================

# Dotfiles marker file (created during deploy)
DOTFILES_MARKER="$HOME/.dotfiles-installed"

# Files deployed by dotfiles
DOTFILES_FILES=(
    "$HOME/.bash_aliases"
    "$HOME/.bashrc"
    "$HOME/.zshrc"
    "$HOME/.bash_profile"
    "$HOME/.gitconfig"
    "$HOME/.gitignore"
    "$HOME/.gitattributes"
    "$HOME/.config/wezterm"
    "$HOME/.config/git"
    "$HOME/.config/powershell"
    "$HOME/init.lua"
    "$HOME/wezterm.lua"
    "$HOME/.aider.conf.yml"
    "$HOME/.editorconfig"
    "$HOME/.claude"
)

# ============================================================================
# UNINSTALL FUNCTIONS
# ============================================================================

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if file is a dotfile deployment
# Safe verification: check for dotfiles marker or known backup
is_dotfile_deployment() {
    local path="$1"

    if [[ ! -e "$path" ]]; then
        return 1
    fi

    # Check for dotfiles marker
    if [[ -f "$DOTFILES_MARKER" ]]; then
        return 0
    fi

    # Check for .dotfiles-backup in same directory
    local dir=$(dirname "$path")
    if [[ -f "$dir/.dotfiles-backup" ]] || [[ -d "$dir/.dotfiles-backup" ]]; then
        return 0
    fi

    # Check for backup file with .dotfiles-backup- prefix
    local backup_path="${path}.dotfiles-backup-"*
    if ls $backup_path >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

# Safe removal with prompt
safe_remove() {
    local path="$1"

    if [[ ! -e "$path" ]]; then
        log_warning "Not found: $path"
        ((SKIPPED_COUNT++))
        return 1
    fi

    if ! is_dotfile_deployment "$path"; then
        log_warning "Skipping (not a verified dotfile): $path"
        ((SKIPPED_COUNT++))
        return 0
    fi

    if [[ "$VERIFY_ONLY" == "true" ]]; then
        echo -e "${GREEN}[VERIFY]${NC} Would remove: $path"
        ((DELETED_COUNT++))
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}[DRY-RUN]${NC} Would remove: $path"
        ((DELETED_COUNT++))
        return 0
    fi

    # Prompt before removal (unless in batch mode)
    if [[ "$DRY_RUN" == "false" ]] && [[ "$VERIFY_ONLY" == "false" ]]; then
        read -p "Remove $path? (yes/no/no-all) " -n 1 -r
        echo
        reply="${REPLY:-n}"

        if [[ $reply =~ ^[Yy]es$ ]]; then
            if rm -rf "$path" 2>/dev/null; then
                log_success "Removed: $path"
                ((DELETED_COUNT++))
                return 0
            else
                log_error "Failed to remove: $path"
                return 1
            fi
        elif [[ $reply == "no-all" ]]; then
            # Skip all remaining prompts
            log_info "Skipping all prompts for remaining files..."
            return 0
        else
            log_info "Skipped: $path"
            ((SKIPPED_COUNT++))
            return 0
        fi
    fi
}

# ============================================================================
# MAIN UNINSTALL PROCESS
# ============================================================================

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}   Dotfiles Uninstall${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "${BLUE}Dry Run:${NC}       $DRY_RUN"
echo -e "${BLUE}Keep Backups:${NC} $KEEP_BACKUPS"
echo -e "${BLUE}Verify Only:${NC}   $VERIFY_ONLY"
echo -e "${CYAN}========================================${NC}"
echo ""

# Verify dotfiles installation
if [[ ! -f "$DOTFILES_MARKER" ]]; then
    log_warning "Dotfiles marker not found: $DOTFILES_MARKER"
    log_warning "Cannot verify if files are dotfile deployments"
    log_warning "Proceeding with best-effort verification..."
fi

# Scan for dotfiles deployments
echo -e "${YELLOW}=== Scanning for Dotfile Deployments ===${NC}"
echo ""

for file in "${DOTFILES_FILES[@]}"; do
    if [[ -e "$file" ]]; then
        echo -e "${BLUE}Found:${NC} $file"
        safe_remove "$file"
    fi
done

# Remove backup directory (unless --keep-backups)
if [[ "$KEEP_BACKUPS" == "false" ]] && [[ -d "$HOME/.dotfiles-backup" ]]; then
    echo ""
    echo -e "${YELLOW}=== Backup Directory ===${NC}"
    if [[ "$VERIFY_ONLY" == "true" ]]; then
        echo -e "${GREEN}[VERIFY]${NC} Would remove: $HOME/.dotfiles-backup"
        ((DELETED_COUNT++))
    elif [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}[DRY-RUN]${NC} Would remove: $HOME/.dotfiles-backup"
        ((DELETED_COUNT++))
    else
        read -p "Remove backup directory $HOME/.dotfiles-backup? (yes/no) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]es$ ]]; then
            if rm -rf "$HOME/.dotfiles-backup" 2>/dev/null; then
                log_success "Removed: $HOME/.dotfiles-backup"
                ((DELETED_COUNT++))
            else
                log_error "Failed to remove: $HOME/.dotfiles-backup"
            fi
        else
            log_info "Kept backup directory"
        fi
    fi
fi

# Remove dotfiles marker if exists
if [[ -f "$DOTFILES_MARKER" ]] && [[ "$VERIFY_ONLY" == "false" ]] && [[ "$DRY_RUN" == "false" ]]; then
    echo ""
    echo -e "${YELLOW}=== Cleanup ===${NC}"
    if rm -f "$DOTFILES_MARKER" 2>/dev/null; then
        log_success "Removed dotfiles marker: $DOTFILES_MARKER"
    fi
fi

# Print summary
echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}       Uninstall Summary${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "${BLUE}Deleted:${NC}   $DELETED_COUNT"
echo -e "${YELLOW}Skipped:${NC}   $SKIPPED_COUNT"
echo -e "${BLUE}Date:${NC}      $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "${CYAN}========================================${NC}"

if [[ "$DRY_RUN" == "false" ]] && [[ "$VERIFY_ONLY" == "false" ]]; then
    echo ""
    log_success "Uninstall complete!"
    echo -e "${YELLOW}Please reload your shell to apply changes${NC}"
    echo -e "${YELLOW}Run ./restore.sh to restore from backup if needed${NC}"
else
    echo ""
    log_info "Dry run/verify complete - no files were actually removed"
    echo -e "${YELLOW}Run without --dry-run and --verify-only to perform actual uninstall${NC}"
fi

exit 0
