#!/usr/bin/env bash
# Sync System Instructions to All Repositories
# Usage: ./sync-system-instructions.sh [-d base_dir] [-c] [-p]
#
# Options:
#   -d base_dir    Base directory containing repos (default: ~/dev/github)
#   -c             Commit changes
#   -p             Push changes after committing

set -euo pipefail

# Defaults
BASE_DIR="$HOME/dev/github"
COMMIT=false
PUSH=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Markdown files to sync to all repos
# Format: "source_path:target_name" - source is relative to dotfiles root, target is the filename in destination repos
MARKDOWN_FILES=(
	".claude/CLAUDE.md:CLAUDE.md"
	"AGENTS.md:AGENTS.md"
	"GEMINI.md:GEMINI.md"
	"RULES.md:RULES.md"
)

# Auto-detect dotfiles directory from script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$SCRIPT_DIR"

# Parse arguments
while getopts "d:cp" opt; do
	case $opt in
	d) BASE_DIR="$OPTARG" ;;
	c) COMMIT=true ;;
	p) PUSH=true ;;
	*)
		echo "Usage: $0 [-d base_dir] [-c] [-p]" >&2
		exit 1
		;;
	esac
done

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}   System Instructions Sync${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "${BLUE}Base Directory:${NC} $BASE_DIR"
echo -e "${BLUE}Commit:${NC}      $COMMIT"
echo -e "${BLUE}Push:${NC}        $PUSH"
echo -e "${CYAN}========================================${NC}"
echo

# Validate base directory exists
if [[ ! -d "$BASE_DIR" ]]; then
	echo -e "${RED}Error: Directory not found: $BASE_DIR${NC}" >&2
	exit 1
fi

# Validate dotfiles directory exists
if [[ ! -d "$DOTFILES_DIR" ]]; then
	echo -e "${RED}Error: Dotfiles directory not found: $DOTFILES_DIR${NC}" >&2
	exit 1
fi

# Copy system instruction markdown files to a repository
# Usage: copy_markdown_files <repo_path>
copy_markdown_files() {
	local repo_path="$1"

	# Skip if dotfiles dir (don't copy to self)
	if [[ "$(cd "$repo_path" 2>/dev/null && pwd)" == "$(cd "$DOTFILES_DIR" 2>/dev/null && pwd)" ]]; then
		return 0
	fi

	# Check if it's a git repository
	if ! cd "$repo_path" 2>/dev/null || ! git rev-parse --git-dir >/dev/null 2>&1; then
		return 0
	fi

	local copied_count=0
	local has_changes=false

	for md_mapping in "${MARKDOWN_FILES[@]}"; do
		# Parse "source_path:target_name" format
		local source_path="${md_mapping%%:*}"
		local target_name="${md_mapping##*:}"
		local source_file="$DOTFILES_DIR/$source_path"
		local target_file="$repo_path/$target_name"

		if [[ -f "$source_file" ]]; then
			# Check if file is different
			if [[ ! -f "$target_file" ]] || ! cmp -s "$source_file" "$target_file"; then
				if cp -f "$source_file" "$target_file" 2>/dev/null; then
					echo -e "    ${GREEN}synced${NC} $target_name"
					((copied_count++))
					has_changes=true
				fi
			fi
		fi
	done

	if [[ $copied_count -gt 0 ]]; then
		echo -e "    ${BLUE}system instructions updated ($copied_count files)${NC}"
		return 0
	elif [[ "$has_changes" == false ]]; then
		echo -e "    ${YELLOW}already up to date${NC}"
		return 1
	fi
}

# Commit changes using git directly
commit_changes() {
	local repo_path="$1"
	local repo_name
	repo_name=$(basename "$repo_path")

	cd "$repo_path" 2>/dev/null || return 0

	# Check if there are changes to commit
	if git diff --quiet CLAUDE.md AGENTS.md GEMINI.md RULES.md 2>/dev/null; then
		cd - >/dev/null
		return 0
	fi

	# Add and commit
	git add CLAUDE.md AGENTS.md GEMINI.md RULES.md 2>/dev/null || true
	if git commit -m "chore: sync system instructions" >/dev/null 2>&1; then
		echo -e "    ${GREEN}committed${NC} $repo_name"
	fi

	cd - >/dev/null
}

# Push changes using git
push_changes() {
	local repo_path="$1"
	local repo_name
	repo_name=$(basename "$repo_path")

	cd "$repo_path" 2>/dev/null || return 0

	if git push origin >/dev/null 2>&1; then
		echo -e "    ${GREEN}pushed${NC} $repo_name"
	else
		echo -e "    ${YELLOW}push failed${NC} $repo_name"
	fi

	cd - >/dev/null
}

# Main processing
REPO_COUNT=0
SYNCED_COUNT=0
SKIPPED_COUNT=0

echo -e "${CYAN}Scanning for repositories in: $BASE_DIR${NC}"
echo

for dir in "$BASE_DIR"/*; do
	if [[ -d "$dir" ]]; then
		REPO_NAME=$(basename "$dir")
		echo -n "[$REPO_NAME] "

		if copy_markdown_files "$dir"; then
			((SYNCED_COUNT++)) || true
		else
			((SKIPPED_COUNT++)) || true
		fi
		((REPO_COUNT++)) || true
	fi
done

# Commit and push if requested
if [[ "$COMMIT" == true ]]; then
	echo
	echo -e "${CYAN}Committing changes...${NC}"

	for dir in "$BASE_DIR"/*; do
		if [[ -d "$dir" ]]; then
			commit_changes "$dir"
			if [[ "$PUSH" == true ]]; then
				push_changes "$dir"
			fi
		fi
	done
fi

# Summary
echo
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}           Summary${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e " ${GREEN}Synced:${NC}   $SYNCED_COUNT"
echo -e " ${YELLOW}Skipped:${NC}  $SKIPPED_COUNT"
echo -e " ${CYAN}Total:${NC}     $REPO_COUNT repositories"
echo -e "${CYAN}========================================${NC}"
