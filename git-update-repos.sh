#!/usr/bin/env bash
# Update/Clone All GitHub Repositories for a User
# Usage: ./git-update-repos.sh [-u username] [-d base_dir] [-s] [--no-sync] [-c] [--commit]

set -euo pipefail

# Check for GitHub CLI
if ! command -v gh >/dev/null 2>&1; then
    echo -e "${RED}Error: GitHub CLI (gh) not found${NC}" >&2
    echo -e "${YELLOW}Install it from: https://cli.github.com/${NC}" >&2
    echo -e "${YELLOW}Or run your bootstrap script${NC}" >&2
    exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
    echo -e "${RED}Error: gh not authenticated. Run: gh auth login${NC}" >&2
    exit 1
fi

# Defaults (can be overridden by environment variables)
USERNAME="${GITHUB_USERNAME:-$(git config user.name 2>/dev/null || echo "lavantien")}"
BASE_DIR="${GIT_BASE_DIR:-$HOME/dev/github}"
USE_SSH=false
SYNC_INSTRUCTIONS=true
AUTO_COMMIT=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Path to sync script (relative to this script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_SCRIPT="$SCRIPT_DIR/sync-system-instructions.sh"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u) USERNAME="$2"; shift 2 ;;
        -d) BASE_DIR="$2"; shift 2 ;;
        -s) USE_SSH=true; shift ;;
        --no-sync) SYNC_INSTRUCTIONS=false; shift ;;
        -c|--commit) AUTO_COMMIT=true; shift ;;
        *) echo "Usage: $0 [-u username] [-d base_dir] [-s] [--no-sync] [-c|--commit]" >&2; exit 1 ;;
    esac
done

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}   GitHub Repos Updater${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "${BLUE}User:${NC}       $USERNAME"
echo -e "${BLUE}Directory:${NC}   $BASE_DIR"
echo -e "${BLUE}SSH:${NC}        $USE_SSH"
echo -e "${BLUE}Sync:${NC}       $SYNC_INSTRUCTIONS"
echo -e "${BLUE}Auto-commit:${NC} $AUTO_COMMIT"
echo -e "${CYAN}========================================${NC}"
echo

# Create base directory if it doesn't exist
if [[ ! -d "$BASE_DIR" ]]; then
    mkdir -p "$BASE_DIR"
    echo -e "${GREEN}Created directory:${NC} $BASE_DIR"
    echo
fi

echo -e "${CYAN}Fetching repositories via GitHub CLI...${NC}"

# Fetch repos using gh CLI
REPOS_JSON=$(gh repo list --json name,sshUrl,url --limit 1000)

# Initialize arrays
CLONE_URLS=()
SSH_URLS=()
REPO_NAMES=()

# Parse JSON into arrays
if command -v jq >/dev/null 2>&1; then
    while IFS='|' read -r name ssh_url web_url; do
        REPO_NAMES+=("$name")
        SSH_URLS+=("$ssh_url")
        CLONE_URLS+=("${web_url}.git")  # Construct HTTPS clone URL
    done < <(echo "$REPOS_JSON" | jq -r '.[] | "\(.name)|\(.sshUrl)|\(.url)"')
else
    # Fallback: simple grep/sed parsing if jq not available
    while IFS= read -r line; do
        name=$(echo "$line" | grep -oP '"name":\s*"\K[^"]+' || true)
        ssh_url=$(echo "$line" | grep -oP '"sshUrl":\s*"\K[^"]+' || true)
        web_url=$(echo "$line" | grep -oP '"url":\s*"\K[^"]+' || true)
        [[ -n "$name" ]] && REPO_NAMES+=("$name")
        [[ -n "$ssh_url" ]] && SSH_URLS+=("$ssh_url")
        [[ -n "$web_url" ]] && CLONE_URLS+=("${web_url}.git")
    done <<< "$REPOS_JSON"
fi

echo -e "${GREEN}Found ${#REPO_NAMES[@]} repositories${NC}"
echo

CLONED=0
UPDATED=0
SKIPPED=0
FAILED=0

# Process each repo
for i in "${!REPO_NAMES[@]}"; do
    REPO_NAME="${REPO_NAMES[$i]}"
    REPO_PATH="$BASE_DIR/$REPO_NAME"

    # Choose clone URL based on SSH flag
    if [[ "$USE_SSH" == "true" ]]; then
        CLONE_URL="${SSH_URLS[$i]}"
    else
        CLONE_URL="${CLONE_URLS[$i]}"
    fi

    if [[ -d "$REPO_PATH" ]]; then
        # Repo exists, update it
        echo -n "[$REPO_NAME] "

        if cd "$REPO_PATH" 2>/dev/null; then
            if git rev-parse --git-dir >/dev/null 2>&1; then
                if git fetch origin && git pull; then
                    echo -e "${YELLOW}Updated${NC}"
                    ((UPDATED++))
                else
                    echo -e "${YELLOW}Error updating${NC}"
                    ((FAILED++))
                fi
            else
                echo -e "${YELLOW}Skipped (not a git repo)${NC}"
                ((SKIPPED++))
            fi
            cd - >/dev/null
        else
            echo -e "${YELLOW}Error accessing${NC}"
            ((FAILED++))
        fi
    else
        # Repo doesn't exist, clone it
        echo -n "[$REPO_NAME] "

        if git clone "$CLONE_URL" "$REPO_PATH"; then
            echo -e "${GREEN}Cloned${NC}"
            ((CLONED++))
        else
            echo -e "${YELLOW}Error cloning${NC}"
            ((FAILED++))
        fi
    fi
done

# Sync system instructions to all repos
if [[ "$SYNC_INSTRUCTIONS" == true ]]; then
    echo
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   Syncing System Instructions${NC}"
    echo -e "${CYAN}========================================${NC}"

    if [[ -f "$SYNC_SCRIPT" ]]; then
        if [[ "$AUTO_COMMIT" == "true" ]]; then
            bash "$SYNC_SCRIPT" -d "$BASE_DIR" -c
        else
            bash "$SYNC_SCRIPT" -d "$BASE_DIR"
        fi
    else
        echo -e "${YELLOW}Warning: Sync script not found: $SYNC_SCRIPT${NC}"
    fi
fi

# Summary
echo
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}           Summary${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e " ${GREEN}Cloned:${NC}  $CLONED"
echo -e " ${YELLOW}Updated:${NC} $UPDATED"
echo -e " ${BLUE}Skipped:${NC} $SKIPPED"
if [[ $FAILED -gt 0 ]]; then
    echo -e " ${YELLOW}Failed:${NC}   $FAILED"
fi
echo -e " ${CYAN}Total:${NC}    ${#REPO_NAMES[@]} repositories"
echo -e "${CYAN}========================================${NC}"
