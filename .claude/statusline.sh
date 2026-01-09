#!/bin/bash
# Claude Code StatusLine - Half-life inspired prompt
# Displays: user@hostname directory [branch] [context%] [style] [vim-mode] model

# ANSI color codes (work in all shells)
readonly GREEN="\033[32m"
readonly BLUE="\033[34m"
readonly YELLOW="\033[33m"
readonly CYAN="\033[36m"
readonly MAGENTA="\033[35m"
readonly RED="\033[31m"
readonly WHITE="\033[37m"
readonly RESET="\033[0m"

# Read JSON input from stdin
input=$(cat)

# Extract fields using jq
model_display=$(echo "$input" | jq -r '.model.display_name // "Claude"')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // "."')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // ""')
output_style=$(echo "$input" | jq -r '.output_style.name // ""')
vim_mode=$(echo "$input" | jq -r '.vim.mode // ""')

# Get git branch if in a git repository (skip optional locks)
git_branch=""
if git --no-optional-locks -C "$current_dir" rev-parse --git-dir >/dev/null 2>&1; then
	branch=$(git --no-optional-locks -C "$current_dir" branch --show-current 2>/dev/null)
	if [ -n "$branch" ]; then
		git_branch=" ${YELLOW}${branch}${RESET}"
	fi
fi

# Calculate context window percentage
context_info=""
usage=$(echo "$input" | jq '.context_window.current_usage')
if [ "$usage" != "null" ]; then
	current=$(echo "$usage" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
	size=$(echo "$input" | jq '.context_window.context_window_size')
	if [ "$size" -gt 0 ]; then
		pct=$((current * 100 / size))
		context_info=" [${CYAN}${pct}%${RESET}]"
	fi
fi

# Get current user and hostname
user=$(whoami)
hostname=$(hostname -s)

# Shorten directory path if it's too long
dir_display=$(basename "$current_dir")
if [ "$current_dir" != "$project_dir" ] && [ -n "$project_dir" ]; then
	# Show relative path from project root
	rel_path="${current_dir#$project_dir/}"
	if [ "$rel_path" != "$current_dir" ]; then
		dir_display=$(basename "$project_dir")/${rel_path}
	fi
fi

# Build the prompt line (half-life inspired style)
# Format: user@hostname directory [branch] [context] [style] [vim-mode]
prompt=""

# User and hostname
prompt+="${GREEN}${user}${RESET}@${GREEN}${hostname}${RESET}"

# Directory
prompt+=" ${BLUE}${dir_display}${RESET}"

# Git branch
if [ -n "$git_branch" ]; then
	prompt+="${git_branch}"
fi

# Context window usage
if [ -n "$context_info" ]; then
	prompt+="${context_info}"
fi

# Output style (if not default)
if [ -n "$output_style" ] && [ "$output_style" != "default" ]; then
	prompt+=" ${MAGENTA}${output_style}${RESET}"
fi

# Vim mode (if active)
if [ -n "$vim_mode" ]; then
	prompt+=" ${RED}[${vim_mode}]${RESET}"
fi

# Model name (shortened - keep version, remove "Claude " prefix)
model_short=$(echo "$model_display" | sed 's/Claude //g')
prompt+=" ${WHITE}${model_short}${RESET}"

# Print the prompt
printf "%b" "$prompt"
