#!/usr/bin/env bash
# Sync CHANGELOG.md sections to GitHub release notes
# Usage: ./sync-release-notes.sh [-n]
#
# Options:
#   -n    Dry run: print the planned action per version and touch nothing

set -euo pipefail

DRY=false
[[ "${1:-}" == "-n" ]] && DRY=true

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHANGELOG="$SCRIPT_DIR/CHANGELOG.md"
REPO=$(git -C "$SCRIPT_DIR" remote get-url origin | sed -e 's/\.git$//' -e 's#.*github\.com[:/]##')

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Split the changelog per version with the same field-splitting deploy.sh uses
# for the version marker, so the two can never disagree about section starts.
# Non-numeric bracket names (an ## [Unreleased] heading) are skipped.
awk -F'[][]' -v dir="$TMP" '
	/^## \[/ {
		flush()
		ver = $2
		valid = (ver ~ /^[0-9]/)
		body = ""
		next
	}
	/^## / { flush(); ver = "" ; next }
	valid { body = body $0 "\n" }
	function flush() {
		if (ver != "" && valid) {
			sub(/^\n+/, "", body)
			sub(/\n+$/, "", body)
			printf "%s\n", body > (dir "/" ver ".md")
			print ver >> (dir "/versions.txt")
		}
	}
	END { flush() }
' "$CHANGELOG"

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}   Release Notes Sync${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "${BLUE}Repo:${NC}     $REPO"
echo -e "${BLUE}Dry run:${NC} $DRY"
echo -e "${CYAN}========================================${NC}"
echo

EDITED=0
CREATED=0
SKIPPED=0
FAILED=0

while IFS= read -r ver; do
	tag="v$ver"
	notes="$TMP/$ver.md"
	if gh release view "$tag" -R "$REPO" >/dev/null 2>&1; then
		action="edit"
	elif [[ -n "$(git -C "$SCRIPT_DIR" tag -l "$tag")" ]]; then
		action="create"
	else
		echo -e "${YELLOW}skip${NC}     $tag (no git tag)"
		SKIPPED=$((SKIPPED + 1))
		continue
	fi
	if $DRY; then
		echo -e "${BLUE}$action${NC}  $tag"
		continue
	fi
	if [[ "$action" == "edit" ]]; then
		if gh release edit "$tag" -R "$REPO" --notes-file "$notes" >/dev/null; then
			echo -e "${GREEN}edited${NC}   $tag"
			EDITED=$((EDITED + 1))
		else
			echo -e "${RED}failed${NC}   $tag (gh release edit)"
			FAILED=$((FAILED + 1))
		fi
	else
		if gh release create "$tag" -R "$REPO" --title "$tag" --notes-file "$notes" --verify-tag >/dev/null; then
			echo -e "${GREEN}created${NC}  $tag"
			CREATED=$((CREATED + 1))
		else
			echo -e "${RED}failed${NC}   $tag (gh release create)"
			FAILED=$((FAILED + 1))
		fi
	fi
done < "$TMP/versions.txt"

echo
if $DRY; then
	echo "Dry run complete. Rerun without -n to apply."
else
	echo -e "Edited: $EDITED  Created: $CREATED  Skipped: $SKIPPED  Failed: $FAILED"
	[[ $FAILED -eq 0 ]] || exit 1
fi
