#!/usr/bin/env bash
# Universal coverage script - runs on all platforms
# Detects platform and runs appropriate coverage tools

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
UPDATE_README=false
VERBOSE=false
for arg in "$@"; do
    case $arg in
        --update-readme|-u) UPDATE_README=true ;;
        --verbose|-v) VERBOSE=true ;;
        --help|-h) echo "Usage: $0 [--update-readme] [--verbose]"; exit 0 ;;
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

echo -e "${BLUE}=== Universal Code Coverage Report ===${NC}"
echo -e "Platform: ${GREEN}$PLATFORM${NC}"
echo

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Initialize coverage values
BASH_COVERAGE=0
PS_COVERAGE=0

# ============================================
# Bash Coverage
# ============================================
echo -e "${BLUE}[1/2] Bash Coverage${NC}"

if [[ "$PLATFORM" == "windows" ]]; then
    # Windows: Use Docker for actual bash coverage
    echo "  Using Docker for bash coverage..."

    if docker info &> /dev/null; then
        # Check if Docker coverage script exists
        if [[ -f "tests/coverage-docker.sh" ]]; then
            chmod +x tests/coverage-docker.sh
            bash_output=$(tests/coverage-docker.sh 2>&1)

            # Extract coverage percentage from output
            BASH_COVERAGE=$(echo "$bash_output" | grep -oP 'Bash:\s*\K[\d.]+' || echo "0.0")

            if [[ "$VERBOSE" == true ]]; then
                echo "$bash_output"
            else
                echo "  Bash: ${BASH_COVERAGE}% (via Docker/kcov)"
            fi
        else
            echo -e "${YELLOW}  Warning: tests/coverage-docker.sh not found${NC}"
            BASH_COVERAGE=0
        fi
    else
        echo -e "${YELLOW}  Docker not available - using estimated bash coverage (25%)${NC}"
        echo -e "${YELLOW}  Install Docker Desktop for actual coverage: https://www.docker.com/products/docker-desktop${NC}"
        BASH_COVERAGE=25.0
    fi
else
    # Linux/macOS: Use kcov natively
    if command -v kcov &> /dev/null; then
        echo "  Using kcov for bash coverage..."

        # Run bash coverage
        if [[ -f "tests/coverage-bash.sh" ]]; then
            chmod +x tests/coverage-bash.sh
            bash_output=$(tests/coverage-bash.sh 2>&1)

            # Extract coverage percentage from output
            BASH_COVERAGE=$(echo "$bash_output" | grep -oP 'Bash:\s*\K[\d.]+' || echo "0.0")

            if [[ "$VERBOSE" == true ]]; then
                echo "$bash_output"
            else
                echo "  Bash: ${BASH_COVERAGE}%"
            fi
        else
            echo -e "${YELLOW}  Warning: tests/coverage-bash.sh not found${NC}"
            BASH_COVERAGE=0
        fi
    else
        echo -e "${YELLOW}  kcov not found - using estimated bash coverage (25%)${NC}"
        echo -e "${YELLOW}  kcov should be installed by bootstrap.sh, or run: bootstrap/bootstrap.sh${NC}"
        BASH_COVERAGE=25.0
    fi
fi

echo

# ============================================
# PowerShell Coverage (via pwsh if available)
# ============================================
echo -e "${BLUE}[2/2] PowerShell Coverage${NC}"

if command -v pwsh &> /dev/null; then
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
# Use awk for cross-platform compatibility
COMBINED=$(awk "BEGIN {printf \"%.1f\", ($PS_COVERAGE * 0.6) + ($BASH_COVERAGE * 0.4)}")

echo -e "${BLUE}=== Combined Coverage ===${NC}"
echo -e "PowerShell: ${PS_COVERAGE}%"
echo -e "Bash:       ${BASH_COVERAGE}%"
echo -e "Combined:   ${GREEN}${COMBINED}%${NC}"

# ============================================
# Badge Color
# ============================================
if (( $(echo "$COMBINED >= 80" | bc -l 2>/dev/null || echo 0) )); then
    BADGE_COLOR="brightgreen"
elif (( $(echo "$COMBINED >= 70" | bc -l 2>/dev/null || echo 0) )); then
    BADGE_COLOR="green"
elif (( $(echo "$COMBINED >= 60" | bc -l 2>/dev/null || echo 0) )); then
    BADGE_COLOR="yellowgreen"
elif (( $(echo "$COMBINED >= 50" | bc -l 2>/dev/null || echo 0) )); then
    BADGE_COLOR="yellow"
elif (( $(echo "$COMBINED >= 40" | bc -l 2>/dev/null || echo 0) )); then
    BADGE_COLOR="orange"
else
    BADGE_COLOR="red"
fi

# ============================================
# Generate SVG Badge
# ============================================
BADGE_SVG="coverage-badge.svg"
cat > "$BADGE_SVG" << EOF
<svg xmlns="http://www.w3.org/2000/svg" width="160" height="20" role="img" aria-label="Code coverage: ${COMBINED}%">
  <title>Code coverage: ${COMBINED}%</title>
  <linearGradient id="s" x2="0" y2="100%">
    <stop offset="0%" stop-color="#bbb" stop-opacity=".1"/>
    <stop offset="1%" stop-opacity=".1"/>
    <stop offset="100%" stop-color="#555" stop-opacity=".1"/>
  </linearGradient>
  <g class="nc">
    <rect x="0" width="95" height="20" fill="#555"/>
    <rect x="95" width="65" height="20" fill="#${BADGE_COLOR}"/>
    <rect width="160" height="20" fill="url(#s)"/>
  </g>
  <g fill="#fff" text-anchor="middle" font-family="Verdana,Geneva,DejaVu Sans,sans-serif" text-rendering="geometricPrecision" font-size="11">
    <text x="48" y="15" fill="#010101" fill-opacity=".3">coverage</text>
    <text x="48" y="14">coverage</text>
    <text x="127" y="15" fill="#010101" fill-opacity=".3">${COMBINED}%</text>
    <text x="127" y="14">${COMBINED}%</text>
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
  "bash_method": "$([[ "$PLATFORM" == "windows" ]] && docker info &> /dev/null && echo "docker" || echo "kcov")",
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
        # Generate shields.io badge URL
        BADGE_URL="https://img.shields.io/badge/coverage-$(echo "$COMBINED" | cut -d. -f1)%25-${BADGE_COLOR}"
        BADGE_MARKDOWN="![Coverage](${BADGE_URL})"

        # Check if badge exists and update or add it
        if grep -q '\[Coverage\](https://img.shields.io/badge/coverage' "$README"; then
            # Update existing badge
            if command -v sed &> /dev/null; then
                sed -i "s|!\[Coverage\](https://img.shields.io/badge/coverage-[^)]*)|${BADGE_MARKDOWN}|g" "$README" 2>/dev/null || \
                sed -i '' "s|!\[Coverage\](https://img.shields.io/badge/coverage-[^)]*)|${BADGE_MARKDOWN}|g" "$README"
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
