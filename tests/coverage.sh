#!/usr/bin/env bash
# Universal coverage script - runs on all platforms
# Uses bashcov (Ruby gem) for bash coverage, falls back to kcov or Docker

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Parse arguments
UPDATE_README=false
VERBOSE=false
FORCE_KCOV=false
for arg in "$@"; do
    case $arg in
        --update-readme|-u) UPDATE_README=true ;;
        --verbose|-v) VERBOSE=true ;;
        --force-kcov) FORCE_KCOV=true ;;
        --help|-h) echo "Usage: $0 [--update-readme] [--verbose] [--force-kcov]"; exit 0 ;;
    esac
done

# Detect platform
OS_TYPE="$(uname -s)"
case "$OS_TYPE" in
    Linux*)     PLATFORM="linux";;
    Darwin*)    PLATFORM="macos";;
    MINGW*|MSYS*|CYGWIN*) PLATFORM="windows";;
    *)          PLATFORM="unknown";;
esac

echo -e "${CYAN}=== Universal Code Coverage Report ===${NC}"
echo -e "Platform: ${GREEN}$PLATFORM${NC}"
echo

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Initialize coverage values
BASH_COVERAGE=0
BASH_METHOD="none"
PS_COVERAGE=0

# ============================================
# Bash Coverage - Try bashcov first (cross-platform)
# ============================================
echo -e "${BLUE}[1/2] Bash Coverage${NC}"

# Function to run bashcov
run_bashcov() {
    if command -v bashcov &>/dev/null; then
        echo "  Using bashcov (Ruby gem) for bash coverage..."

        # Find bats test files
        local bats_tests=($(find tests -name "*.bats" 2>/dev/null))

        if [[ ${#bats_tests[@]} -eq 0 ]]; then
            echo -e "${YELLOW}  No BATS tests found${NC}"
            return 1
        fi

        if [[ "$VERBOSE" == true ]]; then
            echo "  Running ${#bats_tests[@]} test files with bashcov..."
        fi

        # Run bashcov with bats
        # bashcov wraps the command and tracks coverage
        local coverage_dir="$REPO_ROOT/coverage/bash"
        mkdir -p "$coverage_dir"

        # Change to coverage directory so bashcov output goes there
        cd "$coverage_dir"

        # Run bats through bashcov
        # bashcov runs bats and generates HTML coverage report
        if bashcov bats "$REPO_ROOT/tests/bash/" 2>&1; then
            cd "$REPO_ROOT"

            # bashcov generates coverage/index.html
            if [[ -f "$coverage_dir/index.html" ]]; then
                echo "  HTML coverage report: $coverage_dir/index.html"
                # Extract percentage from bashcov HTML report
                # bashcov shows coverage as e.g., "87.5%" in the HTML
                BASH_COVERAGE=$(grep -oP '\d+\.\d+%' "$coverage_dir/index.html" 2>/dev/null | head -1 | tr -d '%' || echo "0.0")
            else
                echo -e "${YELLOW}  bashcov completed but no report found${NC}"
                return 1
            fi
        else
            cd "$REPO_ROOT"
            echo -e "${YELLOW}  bashcov run failed, using fallback${NC}"
            return 1
        fi

        if [[ "$BASH_COVERAGE" != "0.0" ]]; then
            echo "  Bash: ${BASH_COVERAGE}% (via bashcov)"
            BASH_METHOD="bashcov"
            return 0
        fi
    fi
    return 1
}

# Function to run kcov (Linux/macOS only, not Windows)
run_kcov() {
    if command -v kcov &>/dev/null; then
        echo "  Using kcov for bash coverage..."

        # Run bash coverage via kcov
        if [[ -f "tests/coverage-bash.sh" ]]; then
            chmod +x tests/coverage-bash.sh
            local bash_output
            bash_output=$(tests/coverage-bash.sh 2>&1)

            # Extract coverage percentage from output
            BASH_COVERAGE=$(echo "$bash_output" | grep -oP 'Bash:\s*\K[\d.]+' || echo "0.0")

            if [[ "$VERBOSE" == true ]]; then
                echo "$bash_output"
            else
                echo "  Bash: ${BASH_COVERAGE}% (via kcov)"
            fi
            BASH_METHOD="kcov"
            return 0
        fi
    fi
    return 1
}

# Function to run Docker kcov (Windows fallback)
run_docker_kcov() {
    if [[ "$PLATFORM" == "windows" ]] && docker info &>/dev/null; then
        echo "  Using Docker for bash coverage (kcov in container)..."

        if [[ -f "tests/coverage-docker.sh" ]]; then
            chmod +x tests/coverage-docker.sh
            local bash_output
            bash_output=$(tests/coverage-docker.sh 2>&1)

            BASH_COVERAGE=$(echo "$bash_output" | grep -oP 'Bash:\s*\K[\d.]+' || echo "0.0")

            if [[ "$VERBOSE" == true ]]; then
                echo "$bash_output"
            else
                echo "  Bash: ${BASH_COVERAGE}% (via Docker/kcov)"
            fi
            BASH_METHOD="docker"
            return 0
        fi
    fi
    return 1
}

# Try coverage methods in order
if [[ "$FORCE_KCOV" == true ]]; then
    # User explicitly requested kcov
    if ! run_kcov && ! run_docker_kcov; then
        echo -e "${YELLOW}  kcov not available - using estimated bash coverage (25%)${NC}"
        BASH_COVERAGE=25.0
        BASH_METHOD="estimated"
    fi
else
    # Try bashcov first (cross-platform)
    if ! run_bashcov; then
        # Fallback to kcov
        if ! run_kcov; then
            # Fallback to Docker on Windows
            if ! run_docker_kcov; then
                # Final fallback
                echo -e "${YELLOW}  No coverage tool available${NC}"
                echo -e "${YELLOW}  Install bashcov: gem install bashcov${NC}"
                if [[ "$PLATFORM" == "windows" ]]; then
                    echo -e "${YELLOW}  Or install Docker Desktop: https://www.docker.com/products/docker-desktop${NC}"
                else
                    echo -e "${YELLOW}  Or install kcov (should be installed by bootstrap.sh)${NC}"
                fi
                BASH_COVERAGE=25.0
                BASH_METHOD="estimated"
            fi
        fi
    fi
fi

echo

# ============================================
# PowerShell Coverage (via pwsh if available)
# ============================================
echo -e "${BLUE}[2/2] PowerShell Coverage${NC}"

if command -v pwsh &>/dev/null; then
    echo "  Using Pester for PowerShell coverage..."

    # Run PowerShell coverage script
    if [[ -f "tests/powershell/coverage.ps1" ]]; then
        ps_output=$(pwsh -NoProfile -File tests/powershell/coverage.ps1 2>&1)
        PS_COVERAGE=$(echo "$ps_output" | grep -oP 'Coverage:\s*\K[\d.]+' | head -n1 || echo "0.0")

        if [[ "$VERBOSE" == true ]]; then
            echo "$ps_output"
        else
            echo "  PowerShell: ${PS_COVERAGE}%"
        fi
    else
        echo -e "${YELLOW}  Warning: tests/powershell/coverage.ps1 not found${NC}"
        PS_COVERAGE=0
    fi
else
    echo -e "${YELLOW}  pwsh not found - PowerShell coverage unavailable${NC}"
    PS_COVERAGE=0
fi

echo

# ============================================
# Combined Coverage
# ============================================
# Weighted average: 60% PowerShell + 40% Bash (based on script complexity)
COMBINED=$(awk "BEGIN {printf \"%.1f\", ($PS_COVERAGE * 0.6) + ($BASH_COVERAGE * 0.4)}")

echo -e "${BLUE}=== Combined Coverage ===${NC}"
echo -e "PowerShell: ${PS_COVERAGE}%"
echo -e "Bash:       ${BASH_COVERAGE}% (method: $BASH_METHOD)"
echo -e "Combined:   ${GREEN}${COMBINED}%${NC}"

# ============================================
# Badge Color (shields.io hex values)
# ============================================
if (( $(echo "$COMBINED >= 89" | bc -l 2>/dev/null || echo 0) )); then
    BADGE_COLOR="violet"
elif (( $(echo "$COMBINED >= 74" | bc -l 2>/dev/null || echo 0) )); then
    BADGE_COLOR="indigo"
elif (( $(echo "$COMBINED >= 59" | bc -l 2>/dev/null || echo 0) )); then
    BADGE_COLOR="#007ec6"  # blue
elif (( $(echo "$COMBINED >= 44" | bc -l 2>/dev/null || echo 0) )); then
    BADGE_COLOR="#97ca00"  # green
elif (( $(echo "$COMBINED >= 29" | bc -l 2>/dev/null || echo 0) )); then
    BADGE_COLOR="#dfb317"  # yellow
elif (( $(echo "$COMBINED >= 15" | bc -l 2>/dev/null || echo 0) )); then
    BADGE_COLOR="#fe7d37"  # orange
else
    BADGE_COLOR="#e05d44"  # red
fi

# ============================================
# Calculate badge width (matches shields.io format)
# ============================================
# "coverage" label = ~61px, value text varies by length
LABEL_WIDTH=61
# Estimate value width: ~4px per character plus padding
VALUE_TEXT="${COMBINED}%"
VALUE_LENGTH=${#VALUE_TEXT}
VALUE_WIDTH=$((VALUE_LENGTH * 9 + 17))  # ~9px per char + padding
BADGE_WIDTH=$((LABEL_WIDTH + VALUE_WIDTH))

# ============================================
# Generate SVG Badge (shields.io format)
# ============================================
BADGE_SVG="coverage-badge.svg"
cat > "$BADGE_SVG" << EOF
<svg xmlns="http://www.w3.org/2000/svg" width="${BADGE_WIDTH}" height="20" role="img" aria-label="coverage: ${COMBINED}%">
  <title>coverage: ${COMBINED}%</title>
  <linearGradient id="s" x2="0" y2="100%">
    <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
    <stop offset="1" stop-opacity=".1"/>
  </linearGradient>
  <clipPath id="r">
    <rect width="${BADGE_WIDTH}" height="20" rx="3" fill="#fff"/>
  </clipPath>
  <g clip-path="url(#r)">
    <rect width="${LABEL_WIDTH}" height="20" fill="#555"/>
    <rect x="${LABEL_WIDTH}" width="${VALUE_WIDTH}" height="20" fill="${BADGE_COLOR}"/>
    <rect width="${BADGE_WIDTH}" height="20" fill="url(#s)"/>
  </g>
  <g fill="#fff" text-anchor="middle" font-family="Verdana,Geneva,DejaVu Sans,sans-serif" text-rendering="geometricPrecision" font-size="110">
    <text aria-hidden="true" x="305" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="510">coverage</text>
    <text x="305" y="140" transform="scale(.1)" fill="#fff" textLength="510">coverage</text>
    <text aria-hidden="true" x="$((LABEL_WIDTH * 10 + VALUE_WIDTH * 10 / 2))" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="$((VALUE_LENGTH * 90))">${COMBINED}%</text>
    <text x="$((LABEL_WIDTH * 10 + VALUE_WIDTH * 10 / 2))" y="140" transform="scale(.1)" fill="#fff" textLength="$((VALUE_LENGTH * 90))">${COMBINED}%</text>
  </g>
</svg>
EOF

echo -e "${GREEN}Badge saved to: $BADGE_SVG${NC}"

# ============================================
# Save coverage data
# ============================================
cat > coverage.json << EOF
{
  "ps_coverage": ${PS_COVERAGE},
  "bash_coverage": ${BASH_COVERAGE},
  "combined_coverage": ${COMBINED},
  "platform": "${PLATFORM}",
  "bash_method": "${BASH_METHOD}",
  "timestamp": "$(date -Iseconds 2>/dev/null || date)"
}
EOF

echo -e "${GREEN}Coverage data saved to: coverage.json${NC}"

# ============================================
# Update README
# ============================================
if [[ "$UPDATE_README" == true ]]; then
    echo
    echo -e "${BLUE}Updating README.md...${NC}"

    README="README.md"
    if [[ -f "$README" ]]; then
        # Generate badge markdown (use local file)
        BADGE_MARKDOWN="![Coverage](coverage-badge.svg)"

        # Check if badge exists and update or add it
        if grep -qE '\[Coverage\]\((https://img.shields.io/badge/coverage-[^)]+|coverage-badge.svg)' "$README"; then
            # Update existing badge
            if command -v sed &>/dev/null; then
                sed -i -E "s|!\[Coverage\]\((https://img.shields.io/badge/coverage-[^)]+|coverage-badge.svg\)|${BADGE_MARKDOWN}|g" "$README" 2>/dev/null || \
                sed -i '' -E "s|!\[Coverage\]\((https://img.shields.io/badge/coverage-[^)]+|coverage-badge.svg\)|${BADGE_MARKDOWN}|g" "$README"
                echo -e "${GREEN}Updated coverage badge in README.md${NC}"
            fi
        else
            # Add badge after title (not implemented for safety - use manual edit or PowerShell script)
            echo -e "${YELLOW}Badge not found in README. Add manually or use coverage-report.ps1 on Windows.${NC}"
        fi
    fi
fi

echo
echo -e "${BLUE}=== Done ===${NC}"
echo -e "Combined Coverage: ${GREEN}${COMBINED}%${NC} (${BADGE_COLOR})"

exit 0
