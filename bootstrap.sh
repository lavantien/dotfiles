#!/usr/bin/env bash
# Root-level bootstrap wrapper
# Delegates to bootstrap/bootstrap.sh for actual implementation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="$SCRIPT_DIR/bootstrap"

# Check if bootstrap directory exists
if [ ! -d "$BOOTSTRAP_DIR" ]; then
	echo "Error: Bootstrap directory not found at $BOOTSTRAP_DIR"
	exit 1
fi

# Delegate to actual bootstrap script
exec "$BOOTSTRAP_DIR/bootstrap.sh" "$@"
