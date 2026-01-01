#!/usr/bin/env bash
# Update/Clone All GitHub Repositories for a User
# Usage: ./git-update-repos.sh [-u username] [-d base_dir] [-s] [--no-sync]

set -euo pipefail

# Defaults
USERNAME="lavantien"
BASE_DIR="$HOME/dev/github"
USE_SSH=false
SYNC_INSTRUCTIONS=true

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
        *) echo "Usage: $0 [-u username] [-d base_dir] [-s] [--no-sync]" >&2; exit 1 ;;
    esac
done

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}   GitHub Repos Updater${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "${BLUE}User:${NC}      $USERNAME"
echo -e "${BLUE}Directory:${NC}  $BASE_DIR"
echo -e "${BLUE}SSH:${NC}       $USE_SSH"
echo -e "${BLUE}Sync:${NC}      $SYNC_INSTRUCTIONS"
echo -e "${CYAN}========================================${NC}"
echo

# Create base directory if it doesn't exist
if [[ ! -d "$BASE_DIR" ]]; then
    mkdir -p "$BASE_DIR"
    echo -e "${GREEN}Created directory:${NC} $BASE_DIR"
    echo
fi

echo -e "${CYAN}Fetching repositories for user: $USERNAME${NC}"
echo

# Fetch all repositories
API_URL="https://api.github.com/users/$USERNAME/repos?per_page=100&type=all"

if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    echo -e "${YELLOW}Error: Neither curl nor wget found${NC}" >&2
    exit 1
fi

# Fetch repos using curl or wget
if command -v curl >/dev/null 2>&1; then
    REPOS_JSON=$(curl -s "$API_URL")
else
    REPOS_JSON=$(wget -qO- "$API_URL")
fi

# Parse repos (simple jq-free parsing)
REPO_COUNT=0
CLONE_URLS=()
REPO_NAMES=()

while IFS= read -r line; do
    if [[ $line =~ \"clone_url\":\ \"([^\"]+)\" ]]; then
        CLONE_URLS+=("${BASH_REMATCH[1]}")
    fi
    if [[ $line =~ \"ssh_url\":\ \"([^\"]+)\" ]]; then
        SSH_URLS+=("${BASH_REMATCH[1]}")
    fi
    if [[ $line =~ \"name\":\ \"([^\"]+)\" ]]; then
        REPO_NAMES+=("${BASH_REMATCH[1]}")
    fi
done <<< "$REPOS_JSON"

REPO_COUNT=${#REPO_NAMES[@]}

# Handle pagination if more than 100 repos
PAGE=2
while [[ $REPO_COUNT -gt 0 ]] && [[ $((REPO_COUNT % 100)) -eq 0 ]]; do
    PAGE_URL="$API_URL&page=$PAGE"
    if command -v curl >/dev/null 2>&1; then
        MORE_JSON=$(curl -s "$PAGE_URL")
    else
        MORE_JSON=$(wget -qO- "$PAGE_URL")
    fi

    if [[ -z "$MORE_JSON" ]] || [[ "$MORE_JSON" == "[]" ]]; then
        break
    fi

    while IFS= read -r line; do
        if [[ $line =~ \"clone_url\":\ \"([^\"]+)\" ]]; then
            CLONE_URLS+=("${BASH_REMATCH[1]}")
        fi
        if [[ $line =~ \"ssh_url\":\ \"([^\"]+)\" ]]; then
            SSH_URLS+=("${BASH_REMATCH[1]}")
        fi
        if [[ $line =~ \"name\":\ \"([^\"]+)\" ]]; then
            REPO_NAMES+=("${BASH_REMATCH[1]}")
        fi
    done <<< "$MORE_JSON"

    REPO_COUNT=${#REPO_NAMES[@]}
    ((PAGE++))
done

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
                if git fetch origin --quiet 2>/dev/null && git pull --quiet 2>/dev/null; then
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

        if git clone --quiet "$CLONE_URL" "$REPO_PATH" 2>/dev/null; then
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
        bash "$SYNC_SCRIPT" -d "$BASE_DIR" -c
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
