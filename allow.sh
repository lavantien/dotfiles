#!/bin/bash
# Make all main shell scripts executable
# Run this once after cloning the repository

set -euo pipefail

echo "Making main shell scripts executable..."

# Main entry points
chmod +x bootstrap.sh
chmod +x bootstrap/bootstrap.sh
chmod +x deploy.sh
chmod +x update-all.sh
chmod +x healthcheck.sh
chmod +x backup.sh
chmod +x restore.sh
chmod +x uninstall.sh

# Git utilities
chmod +x git-update-repos.sh
chmod +x sync-system-instructions.sh

# Claude hooks (statusline only - PostToolUse deprecated, use hookify)
chmod +x .claude/statusline.sh

# Hookify rules (no execute needed)
ls .claude/hookify.*.local.md >/dev/null 2>&1 && echo "Hookify rules found ($(ls .claude/hookify.*.local.md 2>/dev/null | wc -l) rules)" || true

echo "Done! You can now run ./bootstrap.sh"
