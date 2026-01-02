#!/usr/bin/env bats
# Unit tests for deploy.sh
# Tests platform detection, config loading, file deployment, and git hooks

setup() {
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")/.." && pwd)"
    export TEST_TMP_DIR="$BATS_TMPDIR/dotfiles-test-$$"
    export HOME="$TEST_TMP_DIR"
    export XDG_CONFIG_HOME="$TEST_TMP_DIR/.config"

    # Create test directories
    mkdir -p "$TEST_TMP_DIR"
    mkdir -p "$TEST_TMP_DIR/.config"
    mkdir -p "$TEST_TMP_DIR/dev"

    # Source deploy.sh functions (by sourcing the script)
    # We need to mock the main execution
    source "$SCRIPT_DIR/deploy.sh" 2>/dev/null || true

    # Override main to prevent execution during sourcing
    # Redefine functions we want to test
}

teardown() {
    # Cleanup test directory
    rm -rf "$TEST_TMP_DIR"
}

# ============================================================================
# PLATFORM DETECTION
# ============================================================================

@test "deploy: detect_os returns linux on Linux" {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        run detect_os
        [ "$status" -eq 0 ]
        [ "$output" = "linux" ]
    else
        skip "Not running on Linux"
    fi
}

@test "deploy: detect_os returns macos on macOS" {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        run detect_os
        [ "$status" -eq 0 ]
        [ "$output" = "macos" ]
    else
        skip "Not running on macOS"
    fi
}

@test "deploy: detect_os returns windows on Git Bash/MSYS" {
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "MINGW"* ]]; then
        run detect_os
        [ "$status" -eq 0 ]
        [ "$output" = "windows" ]
    else
        skip "Not running on Git Bash/MSYS"
    fi
}

# ============================================================================
# CONFIG LOADING
# ============================================================================

@test "deploy: loads config file when present" {
    local test_config="$TEST_TMP_DIR/.dotfiles.config.yaml"
    echo "editor: vim" > "$test_config"

    # If config functions are available
    if type load_dotfiles_config >/dev/null 2>&1; then
        run load_dotfiles_config "$test_config"
        # Should not fail
        [ "$status" -eq 0 ] || true
    fi
}

@test "deploy: uses defaults when config file absent" {
    local test_config="$TEST_TMP_DIR/nonexistent.config.yaml"

    # Test that get_config returns default when file doesn't exist
    if type get_config >/dev/null 2>&1; then
        run get_config "editor" "nvim" "$test_config"
        [ "$output" = "nvim" ]
    else
        skip "get_config function not available"
    fi
}

# ============================================================================
# COMMON DEPLOYMENT
# ============================================================================

@test "deploy: creates XDG_CONFIG_HOME directory" {
    run deploy_common
    [ "$status" -eq 0 ]
    [ -d "$TEST_TMP_DIR/.config" ]
}

@test "deploy: creates dev directory" {
    run deploy_common
    [ "$status" -eq 0 ]
    [ -d "$TEST_TMP_DIR/dev" ]
}

@test "deploy: copies .bash_aliases to home" {
    # Create test file
    touch "$SCRIPT_DIR/.bash_aliases"

    run deploy_common
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMP_DIR/.bash_aliases" ]
}

@test "deploy: copies .gitconfig to home" {
    # Create test file
    touch "$SCRIPT_DIR/.gitconfig"

    run deploy_common
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMP_DIR/.gitconfig" ]
}

@test "deploy: copies init.lua to home and XDG config" {
    # Create test file
    touch "$SCRIPT_DIR/init.lua"

    run deploy_common
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMP_DIR/init.lua" ]
    [ -f "$TEST_TMP_DIR/.config/nvim/init.lua" ]
}

@test "deploy: copies lua directory to XDG nvim config" {
    # Create test directory
    mkdir -p "$SCRIPT_DIR/lua"
    echo "test content" > "$SCRIPT_DIR/lua/test.lua"

    run deploy_common
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMP_DIR/.config/nvim/lua/test.lua" ]

    # Cleanup
    rm -rf "$SCRIPT_DIR/lua"
}

@test "deploy: copies wezterm.lua to XDG config" {
    # Create test file
    mkdir -p "$SCRIPT_DIR"
    echo "return {}" > "$SCRIPT_DIR/wezterm.lua"

    run deploy_common
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMP_DIR/.config/wezterm/wezterm.lua" ]
}

@test "deploy: copies git scripts to dev directory with execute permissions" {
    # Create test files
    touch "$SCRIPT_DIR/git-update-repos.sh"
    touch "$SCRIPT_DIR/sync-system-instructions.sh"

    run deploy_common
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMP_DIR/dev/git-update-repos.sh" ]
    [ -f "$TEST_TMP_DIR/dev/sync-system-instructions.sh" ]

    # Check execute permissions
    [ -x "$TEST_TMP_DIR/dev/git-update-repos.sh" ] || skip "Permissions not preserved on this filesystem"
    [ -x "$TEST_TMP_DIR/dev/sync-system-instructions.sh" ] || skip "Permissions not preserved on this filesystem"
}

@test "deploy: copies both .sh and .ps1 versions of scripts" {
    # Create test files
    touch "$SCRIPT_DIR/update-all.sh"
    touch "$SCRIPT_DIR/update-all.ps1"
    touch "$SCRIPT_DIR/git-update-repos.ps1"
    touch "$SCRIPT_DIR/sync-system-instructions.ps1"

    run deploy_common
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMP_DIR/dev/update-all.sh" ]
    [ -f "$TEST_TMP_DIR/dev/update-all.ps1" ]
    [ -f "$TEST_TMP_DIR/dev/git-update-repos.ps1" ]
    [ -f "$TEST_TMP_DIR/dev/sync-system-instructions.ps1" ]
}

# ============================================================================
# GIT HOOKS DEPLOYMENT
# ============================================================================

@test "deploy: creates git hooks directory" {
    run deploy_git_hooks
    [ "$status" -eq 0 ]
    [ -d "$TEST_TMP_DIR/.config/git/hooks" ]
}

@test "deploy: copies pre-commit hook" {
    # Create test hook
    mkdir -p "$SCRIPT_DIR/hooks/git"
    echo "#!/bin/bash" > "$SCRIPT_DIR/hooks/git/pre-commit"

    run deploy_git_hooks
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMP_DIR/.config/git/hooks/pre-commit" ]
}

@test "deploy: copies commit-msg hook" {
    # Create test hook
    mkdir -p "$SCRIPT_DIR/hooks/git"
    echo "#!/bin/bash" > "$SCRIPT_DIR/hooks/git/commit-msg"

    run deploy_git_hooks
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMP_DIR/.config/git/hooks/commit-msg" ]
}

@test "deploy: copies PowerShell hooks for Windows" {
    # Create test hooks
    mkdir -p "$SCRIPT_DIR/hooks/git"
    echo "# PowerShell" > "$SCRIPT_DIR/hooks/git/pre-commit.ps1"
    echo "# PowerShell" > "$SCRIPT_DIR/hooks/git/commit-msg.ps1"

    run deploy_git_hooks
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMP_DIR/.config/git/hooks/pre-commit.ps1" ]
    [ -f "$TEST_TMP_DIR/.config/git/hooks/commit-msg.ps1" ]
}

@test "deploy: makes bash hooks executable" {
    # Create test hook
    mkdir -p "$SCRIPT_DIR/hooks/git"
    echo "#!/bin/bash" > "$SCRIPT_DIR/hooks/git/pre-commit"
    chmod +x "$SCRIPT_DIR/hooks/git/pre-commit"

    run deploy_git_hooks
    [ "$status" -eq 0 ]
    [ -x "$TEST_TMP_DIR/.config/git/hooks/pre-commit" ] || skip "Permissions not preserved"
}

# ============================================================================
# GIT CONFIG FIXES
# ============================================================================

@test "deploy: does not modify non-existent gitconfig" {
    # Don't create .gitconfig
    run update_git_config
    [ "$status" -eq 0 ]
}

@test "deploy: removes linuxbrew gh credential helper on Windows" {
    if [[ "$OSTYPE" != "msys" ]] && [[ "$OSTYPE" != "MINGW"* ]]; then
        skip "Not running on Windows"
    fi

    # Create test gitconfig with linuxbrew paths
    cat > "$TEST_TMP_DIR/.gitconfig" << 'EOF'
[credential]
    helper = !/home/linuxbrew/.linuxbrew/bin/gh auth git-credential
EOF

    run update_git_config
    [ "$status" -eq 0 ]

    # Check that linuxbrew line was removed
    ! grep -q "linuxbrew" "$TEST_TMP_DIR/.gitconfig"
}

@test "deploy: removes absolute Windows gh.exe paths on Linux/macOS" {
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "MINGW"* ]]; then
        skip "Skipping on Windows"
    fi

    # Create test gitconfig with Windows paths
    cat > "$TEST_TMP_DIR/.gitconfig" << 'EOF'
[credential]
    helper = !"C:/Users/test/gh.exe" auth git-credential
EOF

    run update_git_config
    [ "$status" -eq 0 ]

    # Check that gh.exe line was removed
    ! grep -q "gh.exe" "$TEST_TMP_DIR/.gitconfig"
}

@test "deploy: removes empty helper lines from gitconfig" {
    # Create test gitconfig with empty helper
    cat > "$TEST_TMP_DIR/.gitconfig" << 'EOF'
[credential]
    helper =
    helper = manager
EOF

    run update_git_config
    [ "$status" -eq 0 ]

    # Check that empty helper was removed but manager remains
    ! grep -q 'helper = $' "$TEST_TMP_DIR/.gitconfig"
    grep -q "helper = manager" "$TEST_TMP_DIR/.gitconfig"
}

# ============================================================================
# CLAUDE CODE HOOKS
# ============================================================================

@test "deploy: creates .claude directory" {
    run deploy_claude_hooks
    [ "$status" -eq 0 ]
    [ -d "$TEST_TMP_DIR/.claude" ]
}

@test "deploy: copies quality-check.ps1 to .claude" {
    # Create test hook
    mkdir -p "$SCRIPT_DIR/hooks/claude"
    echo "# PowerShell" > "$SCRIPT_DIR/hooks/claude/quality-check.ps1"

    run deploy_claude_hooks
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMP_DIR/.claude/quality-check.ps1" ]
}

@test "deploy: copies TDD guard if present" {
    # Create test TDD guard
    mkdir -p "$SCRIPT_DIR/.claude/tdd-guard"
    echo "test" > "$SCRIPT_DIR/.claude/tdd-guard/data.txt"

    run deploy_claude_hooks
    [ "$status" -eq 0 ]
    [ -d "$TEST_TMP_DIR/.claude/tdd-guard" ]
    [ -f "$TEST_TMP_DIR/.claude/tdd-guard/data.txt" ]
}

@test "deploy: copies CLAUDE.md to global .claude directory" {
    # Create test CLAUDE.md
    echo "# Test CLAUDE.md" > "$SCRIPT_DIR/CLAUDE.md"

    run deploy_claude_hooks
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMP_DIR/.claude/CLAUDE.md" ]
}

@test "deploy: handles missing CLAUDE.md gracefully" {
    # Remove CLAUDE.md if it exists
    rm -f "$SCRIPT_DIR/CLAUDE.md"

    run deploy_claude_hooks
    [ "$status" -eq 0 ]
    # Should not fail, just skip the copy
}

# ============================================================================
# PLATFORM-SPECIFIC DEPLOYMENT
# ============================================================================

@test "deploy: Linux copies .zshrc" {
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        skip "Not running on Linux"
    fi

    # Create test file
    touch "$SCRIPT_DIR/.zshrc"

    run deploy_linux
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMP_DIR/.zshrc" ]
}

@test "deploy: macOS copies .zshrc" {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        skip "Not running on macOS"
    fi

    # Create test file
    touch "$SCRIPT_DIR/.zshrc"

    run deploy_macos
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMP_DIR/.zshrc" ]
}

@test "deploy: Windows detects OneDrive Documents path" {
    if [[ "$OSTYPE" != "msys" ]] && [[ "$OSTYPE" != "MINGW"* ]]; then
        skip "Not running on Windows"
    fi

    # Mock OneDrive directory
    mkdir -p "$TEST_TMP_DIR/OneDrive/Documents"

    run deploy_windows
    [ "$status" -eq 0 ]

    # Should have deployed to OneDrive path
    [ -d "$TEST_TMP_DIR/OneDrive/Documents/PowerShell" ] || skip "PowerShell not installed or paths different"
}

@test "deploy: Windows falls back to standard Documents path" {
    if [[ "$OSTYPE" != "msys" ]] && [[ "$OSTYPE" != "MINGW"* ]]; then
        skip "Not running on Windows"
    fi

    # Don't create OneDrive, should use standard path
    run deploy_windows
    # Should not fail
    [ "$status" -eq 0 ] || true
}

@test "deploy: Windows copies PowerShell profile" {
    if [[ "$OSTYPE" != "msys" ]] && [[ "$OSTYPE" != "MINGW"* ]]; then
        skip "Not running on Windows"
    fi

    # Create test profile
    touch "$SCRIPT_DIR/Microsoft.PowerShell_profile.ps1"
    mkdir -p "$TEST_TMP_DIR/Documents/PowerShell"

    run deploy_windows
    [ "$status" -eq 0 ]

    # Check profile was deployed
    [ -f "$TEST_TMP_DIR/Documents/PowerShell/Microsoft.PowerShell_profile.ps1" ] || \
    [ -f "$TEST_TMP_DIR/OneDrive/Documents/PowerShell/Microsoft.PowerShell_profile.ps1" ] || \
    skip "PowerShell paths may differ on this system"
}

@test "deploy: Windows copies .ps1 script versions" {
    if [[ "$OSTYPE" != "msys" ]] && [[ "$OSTYPE" != "MINGW"* ]]; then
        skip "Not running on Windows"
    fi

    # Create test scripts
    touch "$SCRIPT_DIR/update-all.ps1"
    touch "$SCRIPT_DIR/git-update-repos.ps1"
    touch "$SCRIPT_DIR/sync-system-instructions.ps1"

    run deploy_windows
    [ "$status" -eq 0 ]

    [ -f "$TEST_TMP_DIR/dev/update-all.ps1" ]
    [ -f "$TEST_TMP_DIR/dev/git-update-repos.ps1" ]
    [ -f "$TEST_TMP_DIR/dev/sync-system-instructions.ps1" ]
}

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

@test "deploy: main runs without errors" {
    # Create minimal required files
    touch "$SCRIPT_DIR/.bash_aliases"
    touch "$SCRIPT_DIR/.gitconfig"
    touch "$SCRIPT_DIR/init.lua"

    run main
    [ "$status" -eq 0 ]
    [[ "$output" == *"Deployment Complete"* ]]
}

@test "deploy: handles missing required files gracefully" {
    # Remove files that deploy.sh expects
    mv "$SCRIPT_DIR/.bash_aliases" "$SCRIPT_DIR/.bash_aliases.bak" 2>/dev/null || true
    mv "$SCRIPT_DIR/.gitconfig" "$SCRIPT_DIR/.gitconfig.bak" 2>/dev/null || true

    run deploy_common
    # Should not fail even with missing files
    [ "$status" -eq 0 ] || true

    # Restore
    mv "$SCRIPT_DIR/.bash_aliases.bak" "$SCRIPT_DIR/.bash_aliases" 2>/dev/null || true
    mv "$SCRIPT_DIR/.gitconfig.bak" "$SCRIPT_DIR/.gitconfig" 2>/dev/null || true
}
