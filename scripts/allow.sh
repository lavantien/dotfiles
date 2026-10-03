#!/bin/bash
# Make all main shell scripts executable
# Run this once after cloning the repository

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Making main shell scripts executable..."

chmod +x "$SCRIPT_DIR/deploy.sh"
chmod +x "$SCRIPT_DIR/update-all.sh"
chmod +x "$SCRIPT_DIR/healthcheck.sh"
chmod +x "$SCRIPT_DIR/backup.sh"
chmod +x "$SCRIPT_DIR/restore.sh"
chmod +x "$SCRIPT_DIR/uninstall.sh"
chmod +x "$SCRIPT_DIR/git-update-repos.sh"
chmod +x "$SCRIPT_DIR/books-index.sh"

chmod +x "$ROOT_DIR/bootstrap/bootstrap.sh"
chmod +x "$ROOT_DIR/.claude/statusline.sh"

echo "Done! You can now run ./bootstrap/bootstrap.sh"
