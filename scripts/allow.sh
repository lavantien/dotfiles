#!/bin/bash
# Make every tracked shell script executable
# Run this once after cloning the repository

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Making tracked shell scripts executable..."

while IFS= read -r -d '' script; do
	chmod +x "$ROOT_DIR/$script"
done < <(git -C "$ROOT_DIR" ls-files -z -- '*.sh')

echo "Done! You can now run ./bootstrap/bootstrap.sh"
