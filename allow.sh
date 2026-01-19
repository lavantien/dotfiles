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

# Claude hooks
chmod +x .claude/hooks/post-tool-use.sh
chmod +x .claude/quality-check.sh
chmod +x .claude/statusline.sh

echo "Done! You can now run ./bootstrap.sh"
