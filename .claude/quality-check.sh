#!/bin/bash
# Claude Code Quality Check Script
# Runs formatters, linters, and unit tests after file edits
# Usage: quality-check.sh [changed_file]

set -euo pipefail

# If no specific file provided, check recent git changes
if [[ -z "${1:-}" ]]; then
	CHANGED_FILE=$(git diff --name-only HEAD~1 HEAD 2>/dev/null | head -1 || echo "")
else
	CHANGED_FILE="$1"
fi

if [[ -z "$CHANGED_FILE" ]] || [[ ! -f "$CHANGED_FILE" ]]; then
	echo "No file to check or file not found: $CHANGED_FILE"
	exit 0
fi

extension="${CHANGED_FILE##*.}"
filename=$(basename "$CHANGED_FILE")

echo "Running quality check for: $CHANGED_FILE"

# Helper: check if command exists
cmd_exists() {
	command -v "$1" &>/dev/null
}

# Helper: run a tool
# usage: run_tool <cmd> <display> <args...>
run_tool() {
	local cmd="$1"
	local name="$2"
	shift 2
	local args=("$@")

	if ! cmd_exists "$cmd"; then
		return 0
	fi

	echo "  Running $name..." >&2

	if "$cmd" "${args[@]}" &>/dev/null; then
		echo "  $name passed" >&2
	else
		echo "  $name found issues" >&2
	fi
}

# Helper function to find project root
find_project_root() {
	local file_path="$1"

	if [[ -z "$file_path" ]]; then
		return 1
	fi

	local current_dir
	if [[ -d "$file_path" ]]; then
		current_dir="$file_path"
	else
		current_dir=$(dirname "$file_path")
	fi

	# Walk up the directory tree looking for project markers
	while [[ -n "$current_dir" ]] && [[ "$current_dir" != "/" ]]; do
		# Check for common project markers
		for marker in "go.mod" "Cargo.toml" "package.json" "pyproject.toml" \
			"setup.py" "pytest.ini" "composer.json" "pom.xml" \
			"build.gradle" "Gemfile" ".git"; do
			if [[ "$marker" == ".git" ]]; then
				if [[ -d "$current_dir/.git" ]]; then
					echo "$current_dir"
					return 0
				fi
			elif [[ -f "$current_dir/$marker" ]] || [[ -d "$current_dir/$marker" ]]; then
				echo "$current_dir"
				return 0
			fi
		done

		# Check for *.csproj
		if find "$current_dir" -maxdepth 1 -name "*.csproj" -print -quit | grep -q .; then
			echo "$current_dir"
			return 0
		fi

		# Go up one directory
		local parent_dir
		parent_dir=$(dirname "$current_dir")
		if [[ "$parent_dir" == "$current_dir" ]]; then
			break # Reached root
		fi
		current_dir="$parent_dir"
	done

	return 1
}

# --- Go files (*.go) ---
if [[ "$extension" == "go" ]]; then
	run_tool gofmt "gofmt" -w "$CHANGED_FILE"
	if cmd_exists goimports; then
		run_tool goimports "goimports" -w "$CHANGED_FILE"
	fi
	if cmd_exists golangci-lint; then
		run_tool golangci-lint "golangci-lint" run "$CHANGED_FILE"
	fi
	if cmd_exists go; then
		run_tool go "go vet" vet "$CHANGED_FILE"
	fi

# --- Rust files (*.rs) ---
elif [[ "$extension" == "rs" ]]; then
	run_tool rustfmt "rustfmt" "$CHANGED_FILE"
	if cmd_exists cargo; then
		(cd "$(dirname "$CHANGED_FILE")" && run_tool cargo "cargo check" check)
		(cd "$(dirname "$CHANGED_FILE")" && run_tool cargo "clippy" clippy --all-targets)
	fi

# --- Python files (*.py) ---
elif [[ "$extension" == "py" ]]; then
	if cmd_exists ruff; then
		run_tool ruff "ruff format" format "$CHANGED_FILE"
		run_tool ruff "ruff check" check --fix "$CHANGED_FILE"
	fi
	if cmd_exists mypy; then
		run_tool mypy "mypy" "$CHANGED_FILE"
	fi

# --- JavaScript/TypeScript files (*.js, *.ts, *.tsx, *.jsx) ---
elif [[ "$extension" =~ ^(js|ts|tsx|jsx)$ ]]; then
	if cmd_exists prettier; then
		run_tool prettier "prettier" --write "$CHANGED_FILE"
	fi
	if cmd_exists eslint; then
		run_tool eslint "eslint" --fix "$CHANGED_FILE"
	fi
	if [[ "$extension" =~ ^(ts|tsx)$ ]] && cmd_exists tsc; then
		run_tool tsc "tsc" --noEmit
	fi

# --- C/C++ files (*.c, *.cpp, *.h, *.hpp) ---
elif [[ "$extension" =~ ^(c|cpp|h|hpp)$ ]]; then
	if cmd_exists clang-format; then
		run_tool clang-format "clang-format" -i "$CHANGED_FILE"
	fi
	if cmd_exists clang-tidy; then
		run_tool clang-tidy "clang-tidy" "$CHANGED_FILE"
	fi
	if cmd_exists cppcheck; then
		run_tool cppcheck "cppcheck" "$CHANGED_FILE"
	fi

# --- C# files (*.cs) ---
elif [[ "$extension" == "cs" ]]; then
	if cmd_exists dotnet; then
		run_tool dotnet "dotnet format" format
	fi

# --- PHP files (*.php) ---
elif [[ "$extension" == "php" ]]; then
	if cmd_exists pint; then
		run_tool pint "Laravel Pint" "$CHANGED_FILE"
	fi
	if cmd_exists phpstan; then
		run_tool phpstan "PHPStan" analyse "$CHANGED_FILE"
	fi
	if cmd_exists psalm; then
		run_tool psalm "Psalm" "$CHANGED_FILE"
	fi

# --- Bash/Shell files (*.sh, *.bash) ---
elif [[ "$extension" =~ ^(sh|bash)$ ]]; then
	if cmd_exists shfmt; then
		run_tool shfmt "shfmt" -w "$CHANGED_FILE"
	fi
	if cmd_exists shellcheck; then
		run_tool shellcheck "shellcheck" "$CHANGED_FILE"
	fi

# --- Lua files (*.lua) ---
elif [[ "$extension" == "lua" ]]; then
	if cmd_exists stylua; then
		run_tool stylua "stylua" "$CHANGED_FILE"
	fi
	if cmd_exists selene; then
		run_tool selene "selene" "$CHANGED_FILE"
	fi

# --- HTML files (*.html, *.htm) ---
elif [[ "$extension" =~ ^(html|htm)$ ]]; then
	if cmd_exists prettier; then
		run_tool prettier "prettier (HTML)" --write "$CHANGED_FILE"
	fi

# --- CSS/SCSS/SASS files (*.css, *.scss, *.sass) ---
elif [[ "$extension" =~ ^(css|scss|sass)$ ]]; then
	if cmd_exists prettier; then
		run_tool prettier "prettier (CSS)" --write "$CHANGED_FILE"
	fi
	if cmd_exists stylelint; then
		run_tool stylelint "stylelint" --fix "$CHANGED_FILE"
	fi

# --- Svelte files (*.svelte) ---
elif [[ "$extension" == "svelte" ]]; then
	if cmd_exists prettier; then
		run_tool prettier "prettier (Svelte)" --write "$CHANGED_FILE"
	fi
	if cmd_exists svelte-check; then
		run_tool svelte-check "svelte-check" "$CHANGED_FILE"
	fi

# --- YAML files (*.yml, *.yaml) ---
elif [[ "$extension" =~ ^(yml|yaml)$ ]]; then
	if cmd_exists prettier; then
		run_tool prettier "prettier" --write "$CHANGED_FILE"
	fi
	if cmd_exists yamllint; then
		run_tool yamllint "yamllint" "$CHANGED_FILE"
	fi

# --- JSON files (*.json) ---
elif [[ "$extension" == "json" ]]; then
	if cmd_exists prettier; then
		run_tool prettier "prettier" --write "$CHANGED_FILE"
	fi
	if cmd_exists jq; then
		if jq empty "$CHANGED_FILE" 2>/dev/null; then
			echo "  jq validation passed" >&2
		else
			echo "  jq validation failed" >&2
		fi
	fi

# --- Markdown files (*.md) ---
elif [[ "$extension" == "md" ]]; then
	if cmd_exists prettier; then
		run_tool prettier "prettier" --write "$CHANGED_FILE"
	fi
	if cmd_exists markdownlint; then
		run_tool markdownlint "markdownlint" "$CHANGED_FILE"
	fi

# --- Typst files (*.typ) ---
elif [[ "$extension" == "typ" ]]; then
	if cmd_exists typst; then
		run_tool typst "typst check" check "$CHANGED_FILE"
	fi

# --- TOML files (*.toml) ---
elif [[ "$extension" == "toml" ]]; then
	if cmd_exists taplo; then
		run_tool taplo "taplo" format "$CHANGED_FILE"
	fi

else
	echo "  No quality checker configured for extension: $extension" >&2
fi

# --- Run Unit Tests based on project type ---
# find_project_root returns 1 outside any project, tolerable under set -e
project_root="$(find_project_root "$CHANGED_FILE")" || project_root=""

if [[ -n "$project_root" ]]; then
	echo ""
	echo "  Running project tests..." >&2

	# Go project
	if [[ -f "$project_root/go.mod" ]]; then
		if cmd_exists go; then
			echo "  Running go test..." >&2
			(cd "$project_root" && if go test -race -cover -short &>/dev/null; then
				echo "  go test passed" >&2
			else
				echo "  go test failed" >&2
			fi)
		fi

	# Python project
	elif [[ -f "$project_root/pyproject.toml" ]] ||
		[[ -f "$project_root/setup.py" ]] ||
		[[ -f "$project_root/pytest.ini" ]]; then
		if cmd_exists pytest; then
			echo "  Running pytest..." >&2
			(cd "$project_root" && if pytest -x -v &>/dev/null; then
				echo "  pytest passed" >&2
			else
				echo "  pytest failed" >&2
			fi)
		fi

	# JavaScript/TypeScript project
	elif [[ -f "$project_root/package.json" ]]; then
		if grep -qE '"test"|"jest"|"vitest"' "$project_root/package.json" 2>/dev/null; then
			if cmd_exists npm; then
				echo "  Running npm test..." >&2
				(cd "$project_root" && if npm test &>/dev/null; then
					echo "  npm test passed" >&2
				else
					echo "  npm test failed" >&2
				fi)
			fi
		fi

	# Rust project
	elif [[ -f "$project_root/Cargo.toml" ]]; then
		if cmd_exists cargo; then
			echo "  Running cargo test..." >&2
			(cd "$project_root" && if cargo test &>/dev/null; then
				echo "  cargo test passed" >&2
			else
				echo "  cargo test failed" >&2
			fi)
		fi

	# C# project
	elif find "$project_root" -maxdepth 2 -name "*.csproj" -print -quit | grep -q .; then
		if cmd_exists dotnet; then
			echo "  Running dotnet test..." >&2
			(cd "$project_root" && if dotnet test --no-build &>/dev/null; then
				echo "  dotnet test passed" >&2
			elif dotnet test &>/dev/null; then
				echo "  dotnet test passed" >&2
			else
				echo "  dotnet test failed" >&2
			fi)
		fi

	# PHP project
	elif [[ -f "$project_root/composer.json" ]]; then
		if grep -qE '"phpunit"|"pest"' "$project_root/composer.json" 2>/dev/null; then
			if cmd_exists php; then
				echo "  Running PHP tests..." >&2
				(
					cd "$project_root" && if [[ -x vendor/bin/phpunit ]]; then
						vendor/bin/phpunit &>/dev/null
					elif [[ -x vendor/bin/pest ]]; then
						vendor/bin/pest &>/dev/null
					elif command -v artisan &>/dev/null; then
						php artisan test &>/dev/null
					fi

					if [[ $? -eq 0 ]]; then
						echo "  PHP tests passed" >&2
					else
						echo "  PHP tests failed" >&2
					fi
				)
			fi
		fi
	fi
fi

echo ""
echo "Quality check complete for: $CHANGED_FILE"
