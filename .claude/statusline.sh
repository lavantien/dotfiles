#!/bin/bash
# Claude Code StatusLine
# Displays: dir branch git-status model tokens/max (pct%) cost style vim-mode

# ANSI color codes
readonly GREEN="\033[32m"
readonly BLUE="\033[34m"
readonly YELLOW="\033[33m"
readonly CYAN="\033[36m"
readonly MAGENTA="\033[35m"
readonly RED="\033[31m"
readonly WHITE="\033[37m"
readonly GRAY="\033[90m"
readonly BOLD="\033[1m"
readonly DIM="\033[2m"
readonly RESET="\033[0m"

# Read JSON input from stdin
input=$(cat)

# Extract fields using jq
model_display=$(echo "$input" | jq -r '.model.display_name // "Claude"')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // "."')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // ""')
output_style=$(echo "$input" | jq -r '.output_style.name // ""')
vim_mode=$(echo "$input" | jq -r '.vim.mode // ""')

# Get git branch and status
git_branch=""
git_status=""
if git --no-optional-locks -C "$current_dir" rev-parse --git-dir >/dev/null 2>&1; then
	branch=$(git --no-optional-locks -C "$current_dir" branch --show-current 2>/dev/null)
	if [ -n "$branch" ]; then
		git_branch=" ${CYAN}${branch}${RESET}"
	fi

	# Get git status
	status=$(git --no-optional-locks -C "$current_dir" status --porcelain 2>/dev/null)
	if [ -n "$status" ]; then
		# Count staged, unstaged, untracked
		staged=$(echo "$status" | grep -cE '^[MADRC]' 2>/dev/null || true)
		unstaged=$(echo "$status" | grep -cE '^.M|^.D' 2>/dev/null || true)
		untracked=$(echo "$status" | grep -cE '^\?\?' 2>/dev/null || true)
		staged=${staged:-0}
		unstaged=${unstaged:-0}
		untracked=${untracked:-0}

		status_parts=""
		if [ "$staged" -gt 0 ]; then
			status_parts="${status_parts}${GREEN}S${staged}${RESET} "
		fi
		if [ "$unstaged" -gt 0 ]; then
			status_parts="${status_parts}${YELLOW}M${unstaged}${RESET} "
		fi
		if [ "$untracked" -gt 0 ]; then
			status_parts="${status_parts}${GRAY}U${untracked}${RESET} "
		fi

		if [ -n "$status_parts" ]; then
			# Trim trailing space and wrap in brackets
			git_status=" [${status_parts% }]"
		fi
	fi
fi

# Context window info - use remaining_percentage from 2.1.6+ or calculate from current_usage
context_info=""
context_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')

if [ -n "$context_size" ] && [ "$context_size" != "null" ] && [ "$context_size" != "empty" ]; then
	# Try 2.1.6+ percentage fields first
	remaining_pct=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
	used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

	max_k=$((context_size / 1000))

	if [ -n "$remaining_pct" ] && [ "$remaining_pct" != "null" ] && [ "$remaining_pct" != "empty" ]; then
		# Use 2.1.6+ percentage field
		pct_int=${remaining_pct%.*}
		used_k=$(( (context_size * (100 - pct_int)) / 100000 ))
	else
		# Fall back to calculating from current_usage
		current_usage=$(echo "$input" | jq -r '.context_window.current_usage // empty')
		if [ -n "$current_usage" ] && [ "$current_usage" != "null" ]; then
			input_tokens=$(echo "$current_usage" | jq -r '.input_tokens // 0')
			output_tokens=$(echo "$current_usage" | jq -r '.output_tokens // 0')
			cache_creation=$(echo "$current_usage" | jq -r '.cache_creation_input_tokens // 0')
			cache_read=$(echo "$current_usage" | jq -r '.cache_read_input_tokens // 0')

			total_used=$((input_tokens + output_tokens + cache_creation + cache_read))
			used_k=$((total_used / 1000))
			used_pct=$((total_used * 100 / context_size))
			pct_int=$((100 - used_pct))
		else
			used_k=0
			pct_int=100
		fi
	fi

	# Determine color based on remaining percentage
	pct_color=$GREEN
	if [ "$pct_int" -le 20 ]; then
		pct_color=$RED
	elif [ "$pct_int" -le 50 ]; then
		pct_color=$YELLOW
	fi

	context_info=" ${pct_color}${used_k}K/${max_k}K${RESET} ${DIM}(${pct_int}% remaining)${RESET}"
fi

# Cost info
cost_info=""
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
if [ -n "$cost" ] && [ "$cost" != "null" ]; then
	# Use awk for float comparison
	cost_check=$(echo "$cost >= 0.01" | awk '{print ($1 >= 0.01) ? "1" : "0"}')
	if [ "$cost_check" = "1" ]; then
		cost_info=" ${GRAY}\$${cost}${RESET}"
	fi
fi

# Directory display
dir_display=$(basename "$current_dir")
if [ "$current_dir" != "$project_dir" ] && [ -n "$project_dir" ]; then
	rel_path="${current_dir#$project_dir/}"
	if [ "$rel_path" != "$current_dir" ]; then
		dir_display="$(basename "$project_dir")/${rel_path}"
	fi
fi

# Build the prompt line
prompt=""

# Directory
prompt+="${BLUE}${dir_display}${RESET}"

# Git branch
if [ -n "$git_branch" ]; then
	prompt+="${git_branch}"
fi

# Git status
if [ -n "$git_status" ]; then
	prompt+="${git_status}"
fi

# Model name
model_short=$(echo "$model_display" | sed 's/Claude //g')
prompt+=" ${BOLD}${MAGENTA}${model_short}${RESET}"

# Context window usage
if [ -n "$context_info" ]; then
	prompt+="${context_info}"
fi

# Cost
if [ -n "$cost_info" ]; then
	prompt+="${cost_info}"
fi

# Output style (if not default)
if [ -n "$output_style" ] && [ "$output_style" != "default" ]; then
	prompt+=" ${YELLOW}${output_style}${RESET}"
fi

# Vim mode (if active)
if [ -n "$vim_mode" ]; then
	prompt+=" ${RED}[${vim_mode}]${RESET}"
fi

# Print the prompt
printf "%b" "$prompt"
