#!/usr/bin/env bats
# Unit tests for bootstrap/lib/version-check.sh
# Tests version extraction, comparison, and installation checking

# Load test helpers
load test_helper

setup() {
    # Load the bootstrap functions using BATS_TEST_DIRNAME
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")/.." && pwd)"
    source "$SCRIPT_DIR/bootstrap/lib/common.sh"
    source "$SCRIPT_DIR/bootstrap/lib/version-check.sh"
    setup_mock_env
}

teardown() {
    teardown_mock_env
}

# ============================================================================
# VERSION PATTERN EXTRACTION
# ============================================================================

@test "version-check: VERSION_PATTERNS is declared and non-empty" {
    [ ${#VERSION_PATTERNS[@]} -gt 0 ]
}

@test "version-check: VERSION_PATTERNS contains node pattern" {
    [[ -n "${VERSION_PATTERNS[node]}" ]]
    [[ "${VERSION_PATTERNS[node]}" =~ v?\([0-9]+\.[0-9]+\.[0-9]+\) ]]
}

@test "version-check: VERSION_PATTERNS contains python pattern" {
    [[ -n "${VERSION_PATTERNS[python]}" ]]
    [[ "${VERSION_PATTERNS[python]}" =~ Python\ \([0-9]+\.[0-9]+\.[0-9]+\) ]]
}

@test "version-check: VERSION_PATTERNS contains gopls pattern" {
    [[ -n "${VERSION_PATTERNS[gopls]}" ]]
    [[ "${VERSION_PATTERNS[gopls]}" =~ golang\.org/x/tools/gopls ]]
}

@test "version-check: VERSION_PATTERNS contains clangd pattern" {
    [[ -n "${VERSION_PATTERNS[clangd]}" ]]
}

@test "version-check: VERSION_PATTERNS contains rust-analyzer pattern" {
    [[ -n "${VERSION_PATTERNS[rust-analyzer]}" ]]
}

@test "version-check: VERSION_FLAGS is declared" {
    [ ${#VERSION_FLAGS[@]} -gt 0 ]
}

@test "version-check: VERSION_FLAGS contains go version flag" {
    [[ "${VERSION_FLAGS[go]}" == "version" ]]
}

@test "version-check: VERSION_FLAGS contains cargo --version flag" {
    [[ "${VERSION_FLAGS[cargo]}" == "--version" ]]
}

# ============================================================================
# get_version() - Version Extraction
# ============================================================================

@test "get_version: returns 1 when tool does not exist" {
    mock_cmd_exists "nonexistent-tool" "false"

    run get_version "nonexistent-tool"
    [ "$status" -eq 1 ]
    [ "$output" = "" ]
}

@test "get_version: extracts node version with v prefix" {
    mock_version_output "node" "v20.1.0"

    run get_version "node"
    [ "$status" -eq 0 ]
    [ "$output" = "20.1.0" ]
}

@test "get_version: extracts npm version with v prefix" {
    mock_version_output "npm" "v10.2.3"

    run get_version "npm"
    [ "$status" -eq 0 ]
    [ "$output" = "10.2.3" ]
}

@test "get_version: extracts python version" {
    mock_version_output "python3" "Python 3.12.0"

    run get_version "python3"
    [ "$status" -eq 0 ]
    [ "$output" = "3.12.0" ]
}

@test "get_version: extracts go version" {
    mock_version_output "go" "go version go1.21.0 linux/amd64"

    run get_version "go"
    [ "$status" -eq 0 ]
    [ "$output" = "1.21.0" ]
}

@test "get_version: extracts rustc version" {
    mock_version_output "rustc" "rustc 1.75.0"

    run get_version "rustc"
    [ "$status" -eq 0 ]
    [ "$output" = "1.75.0" ]
}

@test "get_version: extracts cargo version" {
    mock_version_output "cargo" "cargo 1.75.0"

    run get_version "cargo"
    [ "$status" -eq 0 ]
    [ "$output" = "1.75.0" ]
}

@test "get_version: extracts gopls version" {
    mock_version_output "gopls" "golang.org/x/tools/gopls v0.15.0"

    run get_version "gopls"
    [ "$status" -eq 0 ]
    [ "$output" = "0.15.0" ]
}

@test "get_version: extracts rust-analyzer version" {
    mock_version_output "rust-analyzer" "rust-analyzer 2024-01-01"

    run get_version "rust-analyzer"
    [ "$status" -eq 0 ]
    [ "$output" = "2024-01-01" ]
}

@test "get_version: extracts pyright version" {
    mock_version_output "pyright" "Pyright 1.1.300"

    run get_version "pyright"
    [ "$status" -eq 0 ]
    [ "$output" = "1.1.300" ]
}

@test "get_version: extracts clangd version" {
    mock_version_output "clangd" "clangd version 18.1.0"

    run get_version "clangd"
    [ "$status" -eq 0 ]
    [ "$output" = "18.1.0" ]
}

@test "get_version: extracts typescript-language-server version" {
    mock_version_output "typescript-language-server" "typescript-language-server version 4.2.0"

    run get_version "typescript-language-server"
    [ "$status" -eq 0 ]
    [ "$output" = "4.2.0" ]
}

@test "get_version: uses custom version flag" {
    mock_command_with_output "custom-tool" "CustomTool v1.0.0" "0"

    run get_version "custom-tool" "--version"
    [ "$status" -eq 0 ]
}

@test "get_version: falls back to generic version pattern" {
    mock_command_with_output "unknown-tool" "Version 5.6.7 of unknown-tool" "0"

    run get_version "unknown-tool"
    [ "$status" -eq 0 ]
    [[ "$output" =~ [0-9]+\.[0-9]+\.?[0-9]* ]]
}

@test "get_version: handles version with build metadata" {
    mock_version_output "node" "v20.1.0+abc123"

    run get_version "node"
    [ "$status" -eq 0 ]
    [ "$output" = "20.1.0" ]
}

@test "get_version: handles pre-release version" {
    mock_version_output "node" "v20.1.0-beta.1"

    run get_version "node"
    [ "$status" -eq 0 ]
    # Returns full version with pre-release
    [[ "$output" =~ 20\.1\.0 ]]
}

@test "get_version: handles two-part version" {
    mock_version_output "tool" "v1.2"

    run get_version "tool"
    [ "$status" -eq 0 ]
    [ "$output" = "1.2" ]
}

# ============================================================================
# compare_versions() - Version Comparison
# ============================================================================

@test "compare_versions: returns 0 when installed equals required" {
    run compare_versions "1.0.0" "1.0.0"
    [ "$status" -eq 0 ]
}

@test "compare_versions: returns 0 when installed greater than required" {
    run compare_versions "2.0.0" "1.0.0"
    [ "$status" -eq 0 ]
}

@test "compare_versions: returns 1 when installed less than required" {
    run compare_versions "1.0.0" "2.0.0"
    [ "$status" -eq 1 ]
}

@test "compare_versions: handles v prefix" {
    run compare_versions "v2.0.0" "v1.0.0"
    [ "$status" -eq 0 ]
}

@test "compare_versions: handles different length versions (2 vs 3 parts)" {
    run compare_versions "1.0" "1.0.0"
    [ "$status" -eq 0 ]
}

@test "compare_versions: 1.0.0 greater than 1.0" {
    run compare_versions "1.0.0" "1.0"
    [ "$status" -eq 0 ]
}

@test "compare_versions: 1.0 less than 1.0.1" {
    run compare_versions "1.0" "1.0.1"
    [ "$status" -eq 1 ]
}

@test "compare_versions: handles pre-release suffix stripping" {
    run compare_versions "1.0.0" "1.0.0-alpha"
    [ "$status" -eq 0 ]
}

@test "compare_versions: handles build metadata stripping" {
    run compare_versions "1.0.0+build" "1.0.0"
    [ "$status" -eq 0 ]
}

@test "compare_versions: handles date-based versions" {
    run compare_versions "2024-01-01" "2023-12-31"
    [ "$status" -eq 0 ]
}

@test "compare_versions: date version is greater than semantic" {
    run compare_versions "2024-01-01" "1.0.0"
    [ "$status" -eq 0 ]
}

@test "compare_versions: handles complex version comparison" {
    run compare_versions "20.10.0" "20.2.0"
    [ "$status" -eq 0 ]
}

@test "compare_versions: handles patch version differences" {
    run compare_versions "1.2.3" "1.2.2"
    [ "$status" -eq 0 ]
}

@test "compare_versions: handles minor version differences" {
    run compare_versions "1.3.0" "1.2.9"
    [ "$status" -eq 0 ]
}

@test "compare_versions: handles major version differences" {
    run compare_versions "2.0.0" "1.9.9"
    [ "$status" -eq 0 ]
}

@test "compare_versions: zero-padded versions" {
    run compare_versions "1.02.0" "1.2.0"
    [ "$status" -eq 0 ]
}

@test "compare_versions: handles versions with letters" {
    run compare_versions "1.0.0a" "1.0.0"
    [ "$status" -eq 0 ]
}

# ============================================================================
# needs_install() - Installation Checking
# ============================================================================

@test "needs_install: returns 0 when tool does not exist" {
    mock_cmd_exists "missing-tool" "false"

    run needs_install "missing-tool" ""
    [ "$status" -eq 0 ]
}

@test "needs_install: returns 1 when tool exists" {
    mock_cmd_exists "existing-tool" "true"

    run needs_install "existing-tool" ""
    [ "$status" -eq 1 ]
}

@test "needs_install: ignores min_version parameter" {
    mock_cmd_exists "node" "true"

    run needs_install "node" "20.0.0"
    [ "$status" -eq 1 ]
}

# ============================================================================
# check_and_report_version() - Version Reporting
# ============================================================================

@test "check_and_report_version: reports not installed when tool missing" {
    mock_cmd_exists "missing-tool" "false"

    run check_and_report_version "missing-tool" "" "Missing Tool"
    [ "$status" -eq 0 ]
    [[ "$output" == *"not installed"* ]]
}

@test "check_and_report_version: reports installed with version" {
    mock_cmd_exists "node" "true"
    mock_version_output "node" "v20.1.0"

    run check_and_report_version "node" "" "Node.js"
    [ "$status" -eq 1 ]
    [[ "$output" == *"installed"* ]]
    [[ "$output" == *"20.1.0"* ]]
}

@test "check_and_report_version: uses tool name as display name default" {
    mock_cmd_exists "python3" "true"
    mock_version_output "python3" "Python 3.12.0"

    run check_and_report_version "python3" ""
    [[ "$output" == *"python3"* ]]
}

@test "check_and_report_version: handles version extraction failure" {
    mock_cmd_exists "tool" "true"
    mock_command_with_output "tool" "No version info" "0"

    run check_and_report_version "tool" "" "Tool"
    [ "$status" -eq 1 ]
    [[ "$output" == *"installed"* ]]
}

# ============================================================================
# get_missing_tools() - Batch Checking
# ============================================================================

@test "get_missing_tools: returns list of missing tools" {
    mock_cmd_exists "git" "true"
    mock_cmd_exists "node" "false"
    mock_cmd_exists "python" "false"

    local tools=(git node python)
    local min_versions=""

    run get_missing_tools tools min_versions
    [ "$status" -eq 0 ]
    [[ "$output" == *"node"* ]]
    [[ "$output" == *"python"* ]]
    [[ "$output" != *"git"* ]]
}

@test "get_missing_tools: returns empty when all tools present" {
    mock_cmd_exists "git" "true"
    mock_cmd_exists "node" "true"
    mock_cmd_exists "python" "true"

    local tools=(git node python)
    local min_versions=""

    run get_missing_tools tools min_versions
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "get_missing_tools: handles empty tool list" {
    local tools=()
    local min_versions=""

    run get_missing_tools tools min_versions
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

# ============================================================================
# Cross-Platform Tests
# ============================================================================

@test "version-check: works on Linux with Linux tools" {
    # Test Linux-specific patterns
    mock_version_output "apt" "2.4.0"

    run get_version "apt"
    [ "$status" -eq 0 ]
}

@test "version-check: works on Windows with .exe extensions" {
    mock_version_output "gh.exe" "gh version 2.40.0"

    run get_version "gh.exe"
    [ "$status" -eq 0 ]
    [ "$output" = "2.40.0" ]
}

@test "version-check: works on Windows with lazygit.exe" {
    mock_version_output "lazygit.exe" "version=0.40.0"

    run get_version "lazygit.exe"
    [ "$status" -eq 0 ]
    [ "$output" = "0.40.0" ]
}

@test "version-check: works on macOS with Homebrew" {
    mock_version_output "brew" "Homebrew 4.2.0"

    run get_version "brew"
    [ "$status" -eq 0 ]
    [ "$output" = "4.2.0" ]
}

# ============================================================================
# Edge Cases
# ============================================================================

@test "get_version: handles empty version output" {
    mock_command_with_output "empty-tool" "" "0"

    run get_version "empty-tool"
    [ "$status" -eq 1 ]
}

@test "get_version: handles malformed version" {
    mock_command_with_output "bad-tool" "abc" "0"

    run get_version "bad-tool"
    [ "$status" -eq 1 ]
}

@test "compare_versions: handles empty installed version" {
    run compare_versions "" "1.0.0"
    [ "$status" -eq 1 ]
}

@test "compare_versions: handles empty required version" {
    run compare_versions "1.0.0" ""
    [ "$status" -eq 0 ]
}

@test "compare_versions: handles both empty versions" {
    run compare_versions "" ""
    [ "$status" -eq 0 ]
}

@test "compare_versions: handles very large version numbers" {
    run compare_versions "999.999.999" "100.100.100"
    [ "$status" -eq 0 ]
}

@test "compare_versions: handles versions with multiple dots" {
    run compare_versions "1.2.3.4.5" "1.2.3.4"
    [ "$status" -eq 0 ]
}

# ============================================================================
# Package Description Integration (from linux.sh)
# ============================================================================

@test "get_package_description: returns description for git" {
    source "$SCRIPT_DIR/bootstrap/platforms/linux.sh"

    run get_package_description "git"
    [ "$output" = "version control" ]
}

@test "get_package_description: returns description for node" {
    source "$SCRIPT_DIR/bootstrap/platforms/linux.sh"

    run get_package_description "node"
    [ "$output" = "Node.js runtime" ]
}

@test "get_package_description: returns description for clangd" {
    source "$SCRIPT_DIR/bootstrap/platforms/linux.sh"

    run get_package_description "clangd"
    [ "$output" = "C/C++ LSP" ]
}

@test "get_package_description: returns description for gopls" {
    source "$SCRIPT_DIR/bootstrap/platforms/linux.sh"

    run get_package_description "gopls"
    [ "$output" = "Go LSP" ]
}

@test "get_package_description: returns empty for unknown package" {
    source "$SCRIPT_DIR/bootstrap/platforms/linux.sh"

    run get_package_description "unknown-package-xyz"
    [ "$output" = "" ]
}

@test "get_package_description: handles aliases correctly" {
    source "$SCRIPT_DIR/bootstrap/platforms/linux.sh"

    run get_package_description "nodejs"
    [ "$output" = "Node.js runtime" ]
}

@test "get_package_description: handles eza/exa alias" {
    source "$SCRIPT_DIR/bootstrap/platforms/linux.sh"

    run get_package_description "eza"
    [ "$output" = "ls alternative" ]

    run get_package_description "exa"
    [ "$output" = "ls alternative" ]
}

@test "get_package_description: handles fd-find/fd alias" {
    source "$SCRIPT_DIR/bootstrap/platforms/linux.sh"

    run get_package_description "fd-find"
    [ "$output" = "find alternative" ]

    run get_package_description "fd"
    [ "$output" = "find alternative" ]
}

@test "get_package_description: returns LSP descriptions" {
    source "$SCRIPT_DIR/bootstrap/platforms/linux.sh"

    run get_package_description "rust-analyzer"
    [ "$output" = "Rust LSP" ]

    run get_package_description "pyright"
    [ "$output" = "Python LSP" ]

    run get_package_description "lua-language-server"
    [ "$output" = "Lua LSP" ]
}
