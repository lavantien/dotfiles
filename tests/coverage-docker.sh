#!/usr/bin/env bash
# Docker-based bash coverage for Windows (and cross-platform consistency)
# Usage: ./coverage-docker.sh [--update-readme]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
UPDATE_README=false
for arg in "$@"; do
    case $arg in
        --update-readme|-u) UPDATE_README=true ;;
        --help|-h) echo "Usage: $0 [--update-readme]"; exit 0 ;;
    esac
done

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}=== Bash Coverage via Docker ===${NC}"
echo

# Check if Docker is available
if ! docker info &> /dev/null; then
    echo -e "${RED}Error: Docker is not running or not installed.${NC}"
    echo
    echo "To use Docker-based bash coverage:"
    echo "  1. Install Docker Desktop: https://www.docker.com/products/docker-desktop"
    echo "  2. Start Docker Desktop"
    echo "  3. Run this script again"
    echo
    echo "Alternatively, run coverage natively on Linux/macOS with kcov installed."
    exit 1
fi

echo -e "${GREEN}Docker is available${NC}"

# Determine Docker image
DOCKER_IMAGE="dotfiles-test:latest"

# Check if image exists, build if not
if ! docker image inspect "$DOCKER_IMAGE" &> /dev/null; then
    echo -e "${YELLOW}Image not found, building...${NC}"

    # Create Dockerfile
    cat > "$REPO_ROOT/Dockerfile.test" << 'EOF'
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    git curl build-essential cmake libcurl4-openssl-dev \
    libelf-dev libdw-dev binutils-dev libssl-dev \
    python3 bc dos2unix \
    && rm -rf /var/lib/apt/lists/*

# Install kcov from source
RUN git clone https://github.com/SimonKagstrom/kcov.git /tmp/kcov && \
    cd /tmp/kcov && mkdir build && cd build && \
    cmake .. && make && make install && ldconfig && rm -rf /tmp/kcov

# Install bats
RUN curl -L https://github.com/bats-core/bats-core/archive/v1.10.0.tar.gz | tar -xz && \
    cd bats-core-1.10.0 && ./install.sh /usr/local && rm -rf /tmp/bats-core-1.10.0

WORKDIR /workspace
EOF

    echo -e "${YELLOW}Building Docker image...${NC}"
    docker build -f "$REPO_ROOT/Dockerfile.test" -t "$DOCKER_IMAGE" "$REPO_ROOT"
fi

# Coverage output directory
COVERAGE_DIR="$REPO_ROOT/coverage/kcov"
rm -rf "$COVERAGE_DIR"
mkdir -p "$COVERAGE_DIR"

# Convert path to Windows format for Docker volume mount
# Docker on Windows needs the Windows path, not Git Bash path
if command -v pwd &> /dev/null && pwd -W &> /dev/null 2>&1; then
    # Git Bash on Windows - convert to Windows path
    WIN_REPO_ROOT="$(cd "$REPO_ROOT" && pwd -W 2>/dev/null || echo "/c$REPO_ROOT")"
else
    WIN_REPO_ROOT="$REPO_ROOT"
fi

# Convert /c/Users/... to C:/Users/... format for Docker
WIN_REPO_ROOT="$(echo "$WIN_REPO_ROOT" | sed 's|^/\([a-z]\)/|\1:/|')"

echo -e "${GREEN}Running bash coverage in Docker...${NC}"

# Run coverage in Docker (just generate the data)
# Use Windows path for volume mount on Windows
docker run --rm \
    -v "${WIN_REPO_ROOT}:/workspace" \
    -v "${WIN_REPO_ROOT}/coverage:/coverage" \
    "$DOCKER_IMAGE" \
    bash -c '
        set -e
        # Convert ALL text files (hooks, scripts) from CRLF to LF
        find /workspace \( -name "*.sh" -o -name "pre-commit" -o -name "commit-msg" -o -name "*.bats" \) -type f -print0 | xargs -0 dos2unix -q 2>/dev/null || true
        rm -rf /coverage/kcov/*
        mkdir -p /coverage/kcov
        for test_file in /workspace/tests/bash/*_test.bats; do
            if [[ -f "$test_file" ]]; then
                test_name=$(basename "$test_file" .bats)
                echo "  Running: $test_name"
                kcov --exclude-pattern="/usr/*,/tmp/*,/opt/*" "/coverage/kcov/$test_name" bats "$test_file" || true
            fi
        done
    ' 2>&1 | grep -E "Running:|kcov" || true

# Parse coverage on host (Docker for Windows has path issues)
echo "Calculating coverage for workspace files..."

# Convert COVERAGE_DIR to Windows path for PowerShell
if command -v pwd -W &> /dev/null 2>&1; then
    # Convert /c/Users/... to C:/Users/... for PowerShell
    PS_COVERAGE_DIR="$(cd "$COVERAGE_DIR" && pwd -W 2>/dev/null | sed 's|^/\([a-z]\)/|\1:/|')"
else
    PS_COVERAGE_DIR="$COVERAGE_DIR"
fi

# Find all coverage.json files
COVERAGE_JSON_FILES=$(find "$COVERAGE_DIR" -name "coverage.json" 2>/dev/null)

if [[ -z "$COVERAGE_JSON_FILES" ]]; then
    echo -e "${RED}No coverage data found${NC}"
    BASH_COVERAGE="0.0"
else
    # Extract covered and total lines for workspace files using PowerShell or grep
    if command -v pwsh &> /dev/null; then
        # Use PowerShell for better JSON parsing on Windows
        # Use Windows path format for PowerShell
        BASH_COVERAGE=$(pwsh -NoProfile -Command "
            \$files = Get-ChildItem -Path '$PS_COVERAGE_DIR' -Recurse -Filter 'coverage.json'
            \$covered = 0
            \$total = 0
            foreach (\$file in \$files) {
                \$content = Get-Content \$file.FullName -Raw
                \$lines = \$content -split '\\n'
                foreach (\$line in \$lines) {
                    if (\$line -match '/workspace/') {
                        if (\$line -match '\"covered_lines\":\s*\"(\d+)\"') {
                            \$covered += [int]\$matches[1]
                        }
                        if (\$line -match '\"total_lines\":\s*\"(\d+)\"') {
                            \$total += [int]\$matches[1]
                        }
                    }
                }
            }
            if (\$total -gt 0) {
                [math]::Round((\$covered / \$total) * 100, 1)
            } else {
                0.0
            }
        ")
    else
        # Fallback to grep/awk on Git Bash
        COVERED=$(find "$COVERAGE_DIR" -name "coverage.json" -exec cat {} \; | grep /workspace/ | sed 's/.*"covered_lines": "\([0-9]*\)".*/\1/' | awk '{s+=$1} END {print s}')
        TOTAL=$(find "$COVERAGE_DIR" -name "coverage.json" -exec cat {} \; | grep /workspace/ | sed 's/.*"total_lines": "\([0-9]*\)".*/\1/' | awk '{s+=$1} END {print s}')
        BASH_COVERAGE=$(awk "BEGIN {printf \"%.1f\", ($COVERED / $TOTAL) * 100}")
    fi
fi

echo
echo -e "${BLUE}=== Bash Coverage Result ===${NC}"
echo -e "Bash: ${BASH_COVERAGE}% (measured via kcov in Docker)"

# Save to JSON
cat > "$REPO_ROOT/coverage-bash.json" << EOF
{
  "bash_coverage": ${BASH_COVERAGE},
  "timestamp": "$(date -Iseconds 2>/dev/null || date)",
  "tool": "kcov",
  "platform": "docker",
  "docker_image": "$DOCKER_IMAGE"
}
EOF

echo -e "${GREEN}Coverage data saved to: coverage-bash.json${NC}"

# Show HTML report location
if [[ -f "$COVERAGE_DIR/bootstrap/index.html" ]]; then
    echo
    echo -e "${BLUE}HTML coverage report:${NC} file://$COVERAGE_DIR/bootstrap/index.html"
fi

exit 0
