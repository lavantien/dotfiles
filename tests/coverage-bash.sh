#!/usr/bin/env bash
# Bash code coverage using kcov
# Usage: ./coverage-bash.sh [--update-readme] [--verbose]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
UPDATE_README=false
VERBOSE=false
for arg in "$@"; do
    case $arg in
        --update-readme) UPDATE_README=true ;;
        --verbose) VERBOSE=true ;;
        --help) echo "Usage: $0 [--update-readme] [--verbose]"; exit 0 ;;
    esac
done

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}=== Bash Code Coverage with kcov ===${NC}"
echo

# Check if kcov is installed
if ! command -v kcov &> /dev/null; then
    echo -e "${RED}Error: kcov is not installed.${NC}"
    echo
    echo "Install kcov via bootstrap:"
    echo "  ./bootstrap/bootstrap.sh"
    echo
    echo "Or install manually:"
    echo "  macOS:   brew install kcov"
    echo "  Ubuntu:  sudo apt-get install kcov"
    echo "  Fedora:  sudo dnf install kcov"
    echo "  Arch:    sudo pacman -S kcov"
    echo
    echo "Alternatively, use Docker-based coverage:"
    echo "  ./tests/coverage-docker.sh"
    echo
    exit 1
fi

if [ "$VERBOSE" = true ]; then
    echo -e "${GREEN}kcov version:${NC} $(kcov --version | head -n1)"
fi

# Coverage output directory
COVERAGE_DIR="$REPO_ROOT/coverage/kcov"
rm -rf "$COVERAGE_DIR"
mkdir -p "$COVERAGE_DIR"

# Bash scripts to measure coverage
# We run the test suite with kcov to get coverage of the source scripts
BASH_TEST_FILES=(
    "$SCRIPT_DIR/bash/bootstrap_test.bats"
    "$SCRIPT_DIR/bash/git-hooks_test.bats"
    "$SCRIPT_DIR/bash/update-all_test.bats"
)

# Source files for coverage (passed to kcov --include-pattern)
SOURCE_DIRS=(
    "bootstrap"
    "hooks/git"
    "hooks/claude"
    "lib"
    "deploy.sh"
    "update-all.sh"
    "git-update-repos.sh"
    "backup.sh"
    "restore.sh"
    "healthcheck.sh"
    "uninstall.sh"
    "sync-system-instructions.sh"
)

echo -e "${GREEN}Running tests with kcov...${NC}"

# Run each test file with kcov
# kcov merges results when using the same output directory
for test_file in "${BASH_TEST_FILES[@]}"; do
    if [ -f "$test_file" ]; then
        test_name=$(basename "$test_file" .bats)
        echo "  Running: $test_name"

        # Create a unique subdirectory for each test run
        kcov_output="$COVERAGE_DIR/$test_name"

        # Run kcov with bats
        # --exclude-pattern: exclude test files from coverage
        # --include-pattern: only include source directories
        kcov \
            --exclude-pattern="/*test*,*.bats,*test*,*/tests/*" \
            --include-pattern="bootstrap,hooks,lib,deploy.sh,update-all.sh,git-update-repos.sh,backup.sh,restore.sh,healthcheck.sh,uninstall.sh,sync-system-instructions.sh" \
            "$kcov_output" \
            bats "$test_file" || true
    fi
done

echo
echo -e "${GREEN}Coverage results:${NC}"

# Parse coverage from kcov output
# kcov creates index.json with coverage data
if [ -f "$COVERAGE_DIR/index.json" ]; then
    # Extract coverage using python/jq if available, otherwise use basic parsing
    if command -v python3 &> /dev/null; then
        BASH_COVERAGE=$(python3 -c "
import json
import sys
with open('$COVERAGE_DIR/index.json', 'r') as f:
    data = json.load(f)
    # Get total line coverage
    total_lines = data.get('line_coverable', 0)
    covered_lines = data.get('line_covered', 0)
    if total_lines > 0:
        coverage = (covered_lines / total_lines) * 100
        print(f'{coverage:.1f}')
    else:
        print('0.0')
" 2>/dev/null || echo "0.0")
    else
        # Fallback: parse from index.html
        BASH_COVERAGE=$(grep -oP 'covered.*?(\d+\.\d+)' "$COVERAGE_DIR/index.html" 2>/dev/null | head -n1 | grep -oP '\d+\.\d+' || echo "0.0")
    fi
else
    # Try to get coverage from individual test results
    coverage_sum=0
    count=0
    for dir in "$COVERAGE_DIR"/*; do
        if [ -d "$dir" ] && [ -f "$dir/index.json" ]; then
            # Parse individual coverage
            cov=$(python3 -c "
import json
with open('$dir/index.json', 'r') as f:
    data = json.load(f)
    total = data.get('line_coverable', 0)
    covered = data.get('line_covered', 0)
    print(f'{(covered/total*100):.1f}' if total > 0 else '0.0')
" 2>/dev/null)
            if [ -n "$cov" ]; then
                coverage_sum=$(echo "$coverage_sum + $cov" | bc 2>/dev/null || echo "$coverage_sum")
                count=$((count + 1))
            fi
        fi
    done

    if [ "$count" -gt 0 ]; then
        BASH_COVERAGE=$(echo "scale=1; $coverage_sum / $count" | bc 2>/dev/null || echo "0.0")
    else
        BASH_COVERAGE="0.0"
    fi
fi

echo -e "  Bash: ${BASH_COVERAGE}%"

# Save bash coverage to JSON
bash_coverage_json=$(cat << EOF
{
  "bash_coverage": ${BASH_COVERAGE},
  "timestamp": "$(date -Iseconds 2>/dev/null || date)",
  "tool": "kcov",
  "platform": "$(uname -s)"
}
EOF
)

echo "$bash_coverage_json" > "$REPO_ROOT/coverage-bash.json"
echo -e "${GREEN}Bash coverage saved to: coverage-bash.json${NC}"

# Show HTML report location
echo
echo -e "${BLUE}HTML coverage report:${NC} file://$COVERAGE_DIR/index.html"

# Update README if requested
if [ "$UPDATE_README" = true ]; then
    echo
    echo -e "${YELLOW}README update not implemented in bash script.${NC}"
    echo -e "Use the universal coverage script or run coverage-report.ps1 on Windows."
fi

echo
echo -e "${BLUE}=== Summary ===${NC}"
echo -e "Bash Coverage: ${BASH_COVERAGE}%"

exit 0
