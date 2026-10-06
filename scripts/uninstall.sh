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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults
DRY_RUN=false
KEEP_BACKUPS=false
VERIFY_ONLY=false
DELETED_COUNT=0
SKIPPED_COUNT=0
SKIP_REMAINING=false

# Dotfiles marker file (created during deploy)
DOTFILES_MARKER="$HOME/.dotfiles-installed"

# Files and directories the deploy scripts actually write (deploy.sh on
# Linux/macOS, deploy.ps1 on Windows). Legacy deployments also carried
# ~/.bashrc ~/.bash_profile ~/.gitignore ~/.gitattributes ~/.editorconfig
# ~/init.lua ~/wezterm.lua and ~/.config/powershell, but deploy stopped
# writing those, so they are left to the user and only mentioned here as
# migration context.
DOTFILES_FILES=(
	"$HOME/.bash_aliases"
	"$HOME/.zshrc"
	"$HOME/.gitconfig"
	"$HOME/.config/nvim"
	"$HOME/.config/wezterm"
	"$HOME/.config/git/hooks"
	"$HOME/.config/opencode/opencode.json"
	"$HOME/assets"
	"$HOME/dev/git-clone-all.sh"
	"$HOME/dev/git-update-repos.sh"
	"$HOME/dev/update-all.sh"
	"$HOME/.claude/CLAUDE.md"
	"$HOME/.claude/BOOKS.md"
	"$HOME/.claude/quality-check.sh"
	"$HOME/.claude/quality-check.ps1"
	"$HOME/.claude/statusline.sh"
	"$HOME/.claude/books"
	"$HOME/.claude/settings.json"
)

# ============================================================================
# UNINSTALL FUNCTIONS
# ============================================================================

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

parse_args() {
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
		-h | --help)
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
}

# ============================================================================
# PROMPT CONTRACT (single-char y/n/a answers)
# ============================================================================

# Classify one reply line under the single-char contract.
# Prints yes, no, or all. EOF, an empty line, and any input that is not
# exactly one y, n, or a byte (longer words, padding, multibyte) prints no.
classify_reply() {
	local reply="$1" allow_all="$2"
	if [[ "$reply" =~ ^[Yy]$ ]]; then
		echo yes
	elif [[ "$allow_all" == "true" ]] && [[ "$reply" =~ ^[Aa]$ ]]; then
		echo all
	else
		echo no
	fi
}

# Ask a (y/n) question. Returns 0 for yes, 1 for no or unreadable input.
ask_yn() {
	local reply=""
	IFS= read -r -p "$1 (y/n) " reply || true
	[[ "$(classify_reply "$reply" false)" == "yes" ]]
}

# Ask a (y/n/a) question. Returns 0 for yes, 1 for no, 2 for a (skip the rest).
ask_yna() {
	local reply="" answer
	IFS= read -r -p "$1 (y/n/a) " reply || true
	answer="$(classify_reply "$reply" true)"
	case "$answer" in
	yes) return 0 ;;
	all) return 2 ;;
	*) return 1 ;;
	esac
}

# ============================================================================
# UNINSTALL FUNCTIONS
# ============================================================================

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
	local dir
	dir="$(dirname "$path")"
	if [[ -f "$dir/.dotfiles-backup" ]] || [[ -d "$dir/.dotfiles-backup" ]]; then
		return 0
	fi

	# Check for backup file with .dotfiles-backup- prefix
	local backup_path
	for backup_path in "${path}.dotfiles-backup-"*; do
		if [[ -e "$backup_path" ]]; then
			return 0
		fi
	done

	return 1
}

# Safe removal with prompt
safe_remove() {
	local path="$1"

	if [[ "$SKIP_REMAINING" == "true" ]]; then
		SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
		return 0
	fi

	if [[ ! -e "$path" ]]; then
		log_warning "Not found: $path"
		SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
		return 0
	fi

	if ! is_dotfile_deployment "$path"; then
		log_warning "Skipping (not a verified dotfile): $path"
		SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
		return 0
	fi

	if [[ "$VERIFY_ONLY" == "true" ]]; then
		echo -e "${GREEN}[VERIFY]${NC} Would remove: $path"
		DELETED_COUNT=$((DELETED_COUNT + 1))
		return 0
	fi

	if [[ "$DRY_RUN" == "true" ]]; then
		echo -e "${CYAN}[DRY-RUN]${NC} Would remove: $path"
		DELETED_COUNT=$((DELETED_COUNT + 1))
		return 0
	fi

	local answer=0
	ask_yna "Remove $path?" || answer=$?
	if [[ "$answer" -eq 0 ]]; then
		if rm -rf "$path" 2>/dev/null; then
			log_success "Removed: $path"
			DELETED_COUNT=$((DELETED_COUNT + 1))
		else
			log_error "Failed to remove: $path"
		fi
	elif [[ "$answer" -eq 2 ]]; then
		SKIP_REMAINING=true
		SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
		log_info "Skipping all remaining files"
	else
		log_info "Skipped: $path"
		SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
	fi
	return 0
}

remove_backup_dir() {
	if [[ "$KEEP_BACKUPS" == "true" ]] || [[ ! -d "$HOME/.dotfiles-backup" ]]; then
		return 0
	fi

	echo ""
	echo -e "${YELLOW}=== Backup Directory ===${NC}"
	if [[ "$VERIFY_ONLY" == "true" ]]; then
		echo -e "${GREEN}[VERIFY]${NC} Would remove: $HOME/.dotfiles-backup"
		DELETED_COUNT=$((DELETED_COUNT + 1))
	elif [[ "$DRY_RUN" == "true" ]]; then
		echo -e "${CYAN}[DRY-RUN]${NC} Would remove: $HOME/.dotfiles-backup"
		DELETED_COUNT=$((DELETED_COUNT + 1))
	elif ask_yn "Remove backup directory $HOME/.dotfiles-backup?"; then
		if rm -rf "$HOME/.dotfiles-backup" 2>/dev/null; then
			log_success "Removed: $HOME/.dotfiles-backup"
			DELETED_COUNT=$((DELETED_COUNT + 1))
		else
			log_error "Failed to remove: $HOME/.dotfiles-backup"
		fi
	else
		log_info "Kept backup directory"
	fi
}

remove_marker() {
	if [[ -f "$DOTFILES_MARKER" ]] && [[ "$VERIFY_ONLY" == "false" ]] && [[ "$DRY_RUN" == "false" ]]; then
		echo ""
		echo -e "${YELLOW}=== Cleanup ===${NC}"
		if rm -f "$DOTFILES_MARKER" 2>/dev/null; then
			log_success "Removed dotfiles marker: $DOTFILES_MARKER"
		fi
	fi
}

# Undo the git hook wiring deploy set; when the whole .gitconfig was removed
# the keys went with it, so only a surviving file needs the unset.
undo_git_wiring() {
	if [[ "$VERIFY_ONLY" == "true" ]] || [[ "$DRY_RUN" == "true" ]]; then
		return 0
	fi
	if [[ ! -f "$HOME/.gitconfig" ]]; then
		return 0
	fi
	git config --global --unset core.hooksPath >/dev/null 2>&1 || true
	git config --global --unset init.templatedir >/dev/null 2>&1 || true
}

# ============================================================================
# MAIN UNINSTALL PROCESS
# ============================================================================

main() {
	parse_args "$@"

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

	local file
	for file in "${DOTFILES_FILES[@]}"; do
		if [[ -e "$file" ]]; then
			echo -e "${BLUE}Found:${NC} $file"
			safe_remove "$file"
		fi
	done

	remove_backup_dir
	remove_marker
	undo_git_wiring

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
		echo -e "${YELLOW}Run $SCRIPT_DIR/restore.sh to restore from a backup if needed${NC}"
	else
		echo ""
		log_info "Dry run/verify complete - no files were actually removed"
		echo -e "${YELLOW}Run without --dry-run and --verify-only to perform actual uninstall${NC}"
	fi

	return 0
}

# Sourced runs (bats) define the functions only; direct runs uninstall.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	main "$@"
fi
