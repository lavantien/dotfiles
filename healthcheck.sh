#!/usr/bin/env bash
# Health Check Script - Verifies dotfiles setup
# Usage: ./healthcheck.sh [--verbose] [--format table|json]

set -e

# ============================================================================
# SETUP
# ============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Defaults
VERBOSE=false
FORMAT="table"
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNED_CHECKS=0

# Store results
declare -a CHECK_RESULTS=()

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --format)
            FORMAT="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--verbose] [--format table|json]"
            echo "  --verbose   Show detailed output for each check"
            echo "  --format    Output format: table (default) or json"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage"
            exit 1
            ;;
    esac
done

# ============================================================================
# CHECK FUNCTIONS
# ============================================================================

log_check() { echo -e "${BLUE}[CHECK]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Record check result
# Usage: record_result <name> <status> <message>
record_result() {
    local name="$1"
    local status="$2"
    local message="$3"

    CHECK_RESULTS+=("$name|$status|$message")
    ((TOTAL_CHECKS++))

    case "$status" in
        pass) ((PASSED_CHECKS++)) ;;
        fail) ((FAILED_CHECKS++)) ;;
        warn) ((WARNED_CHECKS++)) ;;
    esac
}

# Check if command exists and optionally verify version
check_command() {
    local name="$1"
    local cmd="$2"
    local min_version="${3:-}"

    if command -v "$cmd" >/dev/null 2>&1; then
        if [[ -n "$min_version" ]]; then
            local version=$($cmd --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            if [[ "$version" < "$min_version" ]]; then
                log_check "$name"
                log_fail "Version $version < $min_version"
                record_result "$name" "fail" "Version $version (min: $min_version)"
                return 1
            fi
        fi
        log_check "$name"
        log_pass "Found: $cmd"
        record_result "$name" "pass" "Found $cmd"
        return 0
    else
        log_check "$name"
        log_fail "Not found: $cmd"
        record_result "$name" "fail" "Not found"
        return 1
    fi
}

# Check if file exists
check_file() {
    local name="$1"
    local path="$2"
    local required="${3:-true}"

    if [[ -e "$path" ]]; then
        log_check "$name"
        log_pass "Found: $path"
        record_result "$name" "pass" "Found at $path"
        return 0
    else
        if [[ "$required" == "true" ]]; then
            log_check "$name"
            log_fail "Not found: $path"
            record_result "$name" "fail" "Required file not found"
            return 1
        else
            log_check "$name"
            log_warn "Optional file not found: $path"
            record_result "$name" "warn" "Optional file not found"
            return 0
        fi
    fi
}

# Check git configuration
check_git_config() {
    local name="$1"
    local key="$2"

    local value=$(git config --global "$key" 2>/dev/null)
    if [[ -n "$value" ]]; then
        log_check "$name"
        log_pass "Set: $key = $value"
        record_result "$name" "pass" "$key = $value"
        return 0
    else
        log_check "$name"
        log_fail "Not set: $key"
        record_result "$name" "fail" "Not configured"
        return 1
    fi
}

# Check if git hook is installed
check_git_hook() {
    local hook_name="$1"
    local hook_path="$2"

    if [[ -x "$hook_path" ]]; then
        log_check "$hook_name hook"
        log_pass "Installed at: $hook_path"
        record_result "$hook_name hook" "pass" "Installed at $hook_path"
        return 0
    else
        log_check "$hook_name hook"
        log_warn "Not found or not executable: $hook_path"
        record_result "$hook_name hook" "warn" "Not installed"
        return 0
    fi
}

# ============================================================================
# HEALTH CHECKS
# ============================================================================

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}   Dotfiles Health Check${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "${BLUE}Verbose:${NC}   $VERBOSE"
echo -e "${BLUE}Format:${NC}    $FORMAT"
echo -e "${CYAN}========================================${NC}"
echo ""

# Check required tools
echo -e "${YELLOW}=== Required Tools ===${NC}"
check_command "Git" "git"
check_command "Editor (nvim/vim)" "nvim" || check_command "Editor (nvim/vim)" "vim"

# Check package managers
echo -e "${YELLOW}=== Package Managers ===${NC}"
check_command "Homebrew" "brew" "" "false"
check_command "npm" "npm" "" "false"
check_command "pip" "pip" "" "false"
check_command "Go" "go" "" "false"
check_command "Cargo" "cargo" "" "false"

# Check CLI tools
echo -e "${YELLOW}=== CLI Tools ===${NC}"
check_command "fzf" "fzf" "" "false"
check_command "bat" "bat" "" "false"
check_command "eza/exa" "eza" "" "false" || check_command "eza/exa" "exa" "" "false"
check_command "ripgrep" "rg" "" "false"

# Check configuration files
echo -e "${YELLOW}=== Configuration Files ===${NC}"
check_file "Bash aliases" "$HOME/.bash_aliases" "false"
check_file "Zsh config" "$HOME/.zshrc" "false"
check_file "Git config" "$HOME/.gitconfig" "true"
check_file "Neovim config" "$HOME/.config/nvim/init.lua" "false"
check_file "Wezterm config" "$HOME/.config/wezterm/wezterm.lua" "false"

# Check git configuration
echo -e "${YELLOW}=== Git Configuration ===${NC}"
check_git_config "Git user.name" "user.name"
check_git_config "Git user.email" "user.email"
check_git_config "Git core.editor" "core.editor"
check_git_config "Git init.defaultBranch" "init.defaultBranch" "false"

# Check git hooks
echo -e "${YELLOW}=== Git Hooks ===${NC}"
HOOKS_DIR="$HOME/.config/git/hooks"
check_git_hook "pre-commit" "$HOOKS_DIR/pre-commit"
check_git_hook "commit-msg" "$HOOKS_DIR/commit-msg"

# Check language servers
echo -e "${YELLOW}=== Language Servers ===${NC}"
check_command "LSP: lua_ls" "lua-language-server" "" "false"
check_command "LSP: clangd" "clangd" "" "false"
check_command "LSP: gopls" "gopls" "" "false"
check_command "LSP: rust_analyzer" "rust-analyzer" "" "false"
check_command "LSP: pyright" "pyright" "" "false"
check_command "LSP: tsserver" "typescript-language-server" "" "false"

# Check linters/formatters
echo -e "${YELLOW}=== Linters & Formatters ===${NC}"
check_command "Prettier" "prettier" "" "false"
check_command "ESLint" "eslint" "" "false"
check_command "Ruff" "ruff" "" "false"
check_command "golangci-lint" "golangci-lint" "" "false"

# ============================================================================
# OUTPUT FORMATS
# ============================================================================

print_table() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}       Health Check Results${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""

    printf "${BLUE}%-30s${NC} ${GREEN}%-10s${NC} %s\n" "CHECK" "STATUS" "MESSAGE"
    echo -e "${CYAN}----------------------------------------------------------------${NC}"

    for result in "${CHECK_RESULTS[@]}"; do
        IFS='|' read -r name status message <<< "$result"

        case "$status" in
            pass) status_color="$GREEN"; status_text="PASS" ;;
            fail) status_color="$RED"; status_text="FAIL" ;;
            warn) status_color="$YELLOW"; status_text="WARN" ;;
        esac

        printf "%-30s ${status_color}%-10s${NC} %s\n" "$name" "$status_text" "$message"
    done

    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}           Summary${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -e "${BLUE}Total Checks:${NC}   $TOTAL_CHECKS"
    echo -e "${GREEN}Passed:${NC}        $PASSED_CHECKS"
    echo -e "${RED}Failed:${NC}        $FAILED_CHECKS"
    echo -e "${YELLOW}Warnings:${NC}      $WARNED_CHECKS"
    echo -e "${CYAN}========================================${NC}"
}

print_json() {
    echo "{"
    echo "  \"total\": $TOTAL_CHECKS,"
    echo "  \"passed\": $PASSED_CHECKS,"
    echo "  \"failed\": $FAILED_CHECKS,"
    echo "  \"warnings\": $WARNED_CHECKS,"
    echo "  \"checks\": ["

    local first=true
    for result in "${CHECK_RESULTS[@]}"; do
        IFS='|' read -r name status message <<< "$result"

        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo ","
        fi

        echo -n "    {"
        echo -n "\"name\": \"$name\", "
        echo -n "\"status\": \"$status\", "
        echo -n "\"message\": \"$message\""
        echo -n "}"
    done

    echo ""
    echo "  ]"
    echo "}"
}

# Print results
if [[ "$FORMAT" == "json" ]]; then
    print_json
else
    print_table
fi

# Exit with appropriate code
if [[ $FAILED_CHECKS -gt 0 ]]; then
    exit 1
fi

exit 0
