#!/bin/bash
# Claude Code StopToolUse Hook
# Runs after tool execution completes to perform quality checks
# This hook is non-blocking - it won't prevent tool execution

set -euo pipefail

# Relevant tools that modify files
RELEVANT_TOOLS=("Write" "Edit" "MultiEdit")

# Get parameters
TOOL_NAME="${1:-}"
CHANGED_FILE="${2:-}"

# Only run for file modification tools
is_relevant=false
for tool in "${RELEVANT_TOOLS[@]}"; do
	[[ "$TOOL_NAME" == "$tool" ]] && is_relevant=true && break
done
if [[ -n "$TOOL_NAME" ]] && [[ "$is_relevant" == "false" ]]; then
	exit 0
fi

# Get the quality check script
QUALITY_CHECK_SCRIPT="$HOME/.claude/quality-check.sh"

if [[ ! -f "$QUALITY_CHECK_SCRIPT" ]]; then
	exit 0
fi

# Run quality checks
bash "$QUALITY_CHECK_SCRIPT" "$CHANGED_FILE" || true

exit 0
