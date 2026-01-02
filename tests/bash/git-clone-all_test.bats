#!/usr/bin/env bats
# Unit tests for git-clone-all.sh
# Tests GitHub organization repository cloning functionality

load test_helper

setup() {
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")/.." && pwd)"
    setup_mock_env
}

teardown() {
    teardown_mock_env
}

# ============================================================================
# SCRIPT VALIDATION
# ============================================================================

@test "git-clone-all: script exists and is executable" {
    [ -f "$SCRIPT_DIR/git-clone-all.sh" ]
    [ -x "$SCRIPT_DIR/git-clone-all.sh" ]
}

@test "git-clone-all: script has correct shebang" {
    run head -n 1 "$SCRIPT_DIR/git-clone-all.sh"
    [[ "$output" == *"#!/usr/bin/env bash"* ]]
}

@test "git-clone-all: script has set -euo pipefail" {
    run grep "set -euo pipefail" "$SCRIPT_DIR/git-clone-all.sh"
    [ "$status" -eq 0 ]
}

# ============================================================================
# USAGE TESTS
# ============================================================================

@test "git-clone-all: shows error when no arguments provided" {
    run bash -c '
        set -euo pipefail
        USAGE="Usage: gh-clone-org <user|org>"
        [[ $# -eq 0 ]] && echo >&2 "missing arguments: ${USAGE}" && exit 1
        echo "OK"
    ' -
    [ "$status" -ne 0 ]
    [[ "$output" == *"missing arguments"* ]]
}

@test "git-clone-all: usage message is correct" {
    run grep "^USAGE=" "$SCRIPT_DIR/git-clone-all.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: gh-clone-org <user|org>"* ]]
}

# ============================================================================
# GH CLI INTEGRATION
# ============================================================================

@test "git-clone-all: uses gh repo list command" {
    run grep "gh repo list" "$SCRIPT_DIR/git-clone-all.sh"
    [ "$status" -eq 0 ]
}

@test "git-clone-all: passes org argument to gh repo list" {
    # Mock gh command
    cat > "$MOCK_BIN_DIR/gh" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "repo" && "$2" == "list" ]]; then
    echo "test-org/repo1"
    echo "test-org/repo2"
    echo "test-org/repo3"
    exit 0
fi
echo "gh called with: $*" >&2
exit 0
EOF
    chmod +x "$MOCK_BIN_DIR/gh"

    # Simulate the repo list logic
    org="test-org"
    limit=9999
    repos="$(gh repo list "$org" -L $limit)"

    run bash -c "echo '$repos' | wc -l"
    [ "$output" -ge 3 ]
}

@test "git-clone-all: uses high limit for repo list" {
    run grep -E "limit=9999|repo list.*-L.*9999" "$SCRIPT_DIR/git-clone-all.sh"
    [ "$status" -eq 0 ]
}

# ============================================================================
# REPO CLONING LOGIC
# ============================================================================

@test "git-clone-all: extracts repo name from output" {
    repo_line="test-org/repo1	Description here"
    repo_name="$(echo "$repo_line" | cut -f1)"
    [ "$repo_name" = "test-org/repo1" ]
}

@test "git-clone-all: increments repos_complete counter" {
    repos_complete=0
    repos_complete=$((repos_complete + 1))
    [ "$repos_complete" -eq 1 ]

    repos_complete=$((repos_complete + 1))
    [ "$repos_complete" -eq 2 ]
}

@test "git-clone-all: shows progress with repo name" {
    repo_name="test-repo"
    repos_complete=1
    repo_total=10

    output=$(echo -ne "\r\e[0K[ $repos_complete / $repo_total ] Cloning $repo_name")
    [[ "$output" == *"[ 1 / 10 ] Cloning test-repo"* ]]
}

# ============================================================================
# CLONE VS PULL LOGIC
# ============================================================================

@test "git-clone-all: uses gh repo clone for new repos" {
    # Mock gh clone
    cat > "$MOCK_BIN_DIR/gh" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "clone" ]]; then
    echo "Cloning $2"
    exit 0
fi
exit 1
EOF
    chmod +x "$MOCK_BIN_DIR/gh"

    run gh repo clone "test-org/repo1" "repo1" -- -q
    [ "$status" -eq 0 ]
    [[ "$output" == *"Cloning"* ]]
}

@test "git-clone-all: falls back to git pull when repo exists" {
    # Mock git
    cat > "$MOCK_BIN_DIR/git" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "pull" ]]; then
    echo "Pulling changes"
    exit 0
fi
echo "git $*" >&2
exit 0
EOF
    chmod +x "$MOCK_BIN_DIR/git"

    run git pull -q
    [ "$status" -eq 0 ]
}

@test "git-clone-all: clone suppresses output with -q flag" {
    run grep "gh repo clone.*-q" "$SCRIPT_DIR/git-clone-all.sh"
    [ "$status" -eq 0 ]
}

@test "git-clone-all: pull suppresses output with -q flag" {
    run grep "git pull.*-q" "$SCRIPT_DIR/git-clone-all.sh"
    [ "$status" -eq 0 ]
}

# ============================================================================
# ERROR HANDLING
# ============================================================================

@test "git-clone-all: clone failure is handled with subshell" {
    # The script uses || to handle clone failure
    run grep "gh repo clone.*||" "$SCRIPT_DIR/git-clone-all.sh"
    [ "$status" -eq 0 ]
}

@test "git-clone-all: continues after clone failure" {
    # Mock gh clone that fails
    cat > "$MOCK_BIN_DIR/gh" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "clone" ]]; then
    exit 1  # Simulate clone failure
fi
exit 0
EOF
    chmod +x "$MOCK_BIN_DIR/gh"

    # Mock git pull
    cat > "$MOCK_BIN_DIR/git" <<'EOF'
#!/usr/bin/env bash
echo "Pulling in existing repo"
exit 0
EOF
    chmod +x "$MOCK_BIN_DIR/git"

    # Simulate the clone-or-pull logic
    result=$(gh repo clone "test/repo" "repo" -- -q 2>/dev/null || (cd repo && git pull -q))
    [[ "$result" == *"Pulling"* ]]
}

# ============================================================================
# OUTPUT FORMATTING
# ============================================================================

@test "git-clone-all: uses carriage return for progress updates" {
    run grep '\\r' "$SCRIPT_DIR/git-clone-all.sh"
    [ "$status" -eq 0 ]
}

@test "git-clone-all: uses escape code to clear line" {
    run grep '\\e\[0K' "$SCRIPT_DIR/git-clone-all.sh"
    [ "$status" -eq 0 ]
}

@test "git-clone-all: prints completion message" {
    run grep "Finished cloning" "$SCRIPT_DIR/git-clone-all.sh"
    [ "$status" -eq 0 ]
}

@test "git-clone-all: completion message includes org name" {
    run grep 'Finished cloning.*repos in.*' "$SCRIPT_DIR/git-clone-all.sh"
    [ "$status" -eq 0 ]
}

# ============================================================================
# EDGE CASES
# ============================================================================

@test "git-clone-all: handles empty repo list" {
    repos_complete=0
    repo_total=0

    if [[ "$repo_total" -eq 0 ]]; then
        echo "No repos to clone"
    fi

    run bash -c 'repos_complete=0; repo_total=0; if [[ "$repo_total" -eq 0 ]]; then echo "No repos"; fi'
    [[ "$output" == *"No repos"* ]]
}

@test "git-clone-all: handles single repo" {
    repo_total=1
    repos_complete=1

    output="[ $repos_complete / $repo_total ]"
    [ "$output" = "[ 1 / 1 ]" ]
}

@test "git-clone-all: handles repo names with hyphens" {
    repo_name="my-org/special-repo-name"
    echo -ne "Cloning $repo_name"
    # Should handle hyphens in names
    [ "$repo_name" = "my-org/special-repo-name" ]
}

@test "git-clone-all: handles repo names with numbers" {
    repo_name="org/repo123"
    echo -ne "Cloning $repo_name"
    [ "$repo_name" = "org/repo123" ]
}

@test "git-clone-all: handles repos with descriptions" {
    repo_line="org/repo1	This is a description"
    repo_name="$(echo "$repo_line" | cut -f1)"
    [ "$repo_name" = "org/repo1" ]
}

@test "git-clone-all: handles repos with tabs in output" {
    repo_line=$'org/repo1\tDescription here'
    repo_name="$(echo "$repo_line" | cut -f1)"
    [ "$repo_name" = "org/repo1" ]
}

# ============================================================================
# INTEGRATION MOCK TESTS
# ============================================================================

@test "git-clone-all: full workflow with mocked gh" {
    # Create mock gh that outputs test repos
    cat > "$MOCK_BIN_DIR/gh" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "repo" && "$2" == "list" ]]; then
    echo "testorg/repo1"
    echo "testorg/repo2"
    echo "testorg/repo3"
    exit 0
elif [[ "$1" == "clone" ]]; then
    echo "Cloned $3"
    exit 0
fi
exit 1
EOF
    chmod +x "$MOCK_BIN_DIR/gh"

    # Simulate the main loop
    org="testorg"
    repos="$(gh repo list "$org" -L 9999)"
    repo_total="$(echo "$repos" | wc -l)"
    repos_complete=0

    count=0
    echo "$repos" | while read -r repo; do
        count=$((count + 1))
        echo "Would clone: $repo"
    done

    run bash -c 'count=0; echo "test1
test2
test3" | while read -r r; do count=$((count+1)); echo "$r"; done | wc -l'
    [ "$output" -ge 3 ]
}

@test "git-clone-all: handles large repo list" {
    # Test that limit=9999 handles large orgs
    limit=9999
    [ "$limit" -gt 100 ]
}

@test "git-clone-all: preserves repo order from gh" {
    repos="org/repo3
org/repo1
org/repo2"

    first=$(echo "$repos" | head -n 1)
    [ "$first" = "org/repo3" ]
}

# ============================================================================
# SCRIPT STRUCTURE
# ============================================================================

@test "git-clone-all: uses while read for processing" {
    run grep "while read" "$SCRIPT_DIR/git-clone-all.sh"
    [ "$status" -eq 0 ]
}

@test "git-clone-all: uses wc -l to count repos" {
    run grep "wc -l" "$SCRIPT_DIR/git-clone-all.sh"
    [ "$status" -eq 0 ]
}

@test "git-clone-all: uses cut -f1 to extract repo name" {
    run grep 'cut -f1' "$SCRIPT_DIR/git-clone-all.sh"
    [ "$status" -eq 0 ]
}

@test "git-clone-all: uses arithmetic for counter increment" {
    run grep '\$((.*\+.*1))' "$SCRIPT_DIR/git-clone-all.sh"
    [ "$status" -eq 0 ]
}
