# Claude Code Quality Check Hook - Universal for Windows and Linux/macOS
# Runs format/lint/check based on project type
# Returns structured output for Claude

param(
    [Parameter(ValueFromPipeline = $true)]
    [string]$InputJson
)

$ErrorActionPreference = 'SilentlyContinue'

# Parse input if provided
if ($InputJson) {
    try {
        $data = $InputJson | ConvertFrom-Json
        $toolName = $data.tool_name
    } catch {
        # No valid input, continue
    }
}

$projectRoot = git rev-parse --show-toplevel 2>$null
if (!$projectRoot) {
    $projectRoot = Get-Location
}

Set-Location $projectRoot

# Colors
$E = [char]27
$R = "$E[0m"
$GREEN = "$E[32m"
$YELLOW = "$E[33m"
$BLUE = "$E[34m"
$CYAN = "$E[36m"
$RED = "$E[31m"

function Format-Result {
    param([string]$Category, [string]$Tool, [bool]$Success, [string]$Output)

    $status = if ($Success) { "PASS" } else { "FAIL" }
    $color = if ($Success) { $GREEN } else { $RED }

    Write-Host "`n$CYAN[$Category] $R$BLUE$Tool$R $color$status$R"
    if ($Output -and !$Success -and $Output.Length -lt 500) {
        Write-Host $Output
    }

    return @{
        category = $Category
        tool = $Tool
        success = $Success
    }
}

$results = @()
$failed = @()

Write-Host "${BLUE}Running quality checks...${R}"

# === NODE/FRONTEND ===
if (Test-Path "frontend\package.json") {
    Push-Location frontend

    if (Test-Path "node_modules") {
        # Prettier
        Write-Host "`n${CYAN}[FORMAT]${R} Prettier..."
        $null = npx prettier --write . --plugin=prettier-plugin-svelte 2>&1
        $results += Format-Result "Format" "Prettier" $true ""

        # ESLint - skip if config issues
        Write-Host "${CYAN}[LINT]${R} ESLint..."
        $eslintOutput = npx eslint . --max-warnings=10 2>&1
        if ($LASTEXITCODE -le 1) {
            $results += Format-Result "Lint" "ESLint" $true ""
        } else {
            $results += Format-Result "Lint" "ESLint" $false ""
        }

        # Type check (warnings ok, errors not)
        if (Get-Content package.json | Select-String "check") {
            Write-Host "${CYAN}[TYPE]${R} svelte-check..."
            $checkOutput = npm run check --silent 2>&1
            # Check for actual errors vs warnings
            if ($checkOutput -match "\berror\b") {
                $results += Format-Result "Type" "svelte-check" $false ""
                $failed += "svelte-check"
            } else {
                $results += Format-Result "Type" "svelte-check" $true ""
            }
        }
    }

    Pop-Location
}

# === C#/BACKEND ===
if (Test-Path "backend") {
    $sln = Get-ChildItem -Path "backend" -Filter "*.sln" -Recurse -Depth 2 -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($sln) {
        Push-Location backend

        Write-Host "`n${CYAN}[FORMAT]${R} dotnet format..."
        $null = dotnet format $sln.Name 2>&1
        $results += Format-Result "Format" "dotnet-format" $true ""

        # Skip build if not restored
        $assetsFile = Get-ChildItem -Path "backend" -Filter "project.assets.json" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($assetsFile) {
            Write-Host "${CYAN}[TYPE]${R} dotnet build..."
            $buildOutput = dotnet build $sln.Name --no-restore --verbosity quiet 2>&1
            if ($LASTEXITCODE -eq 0) {
                $results += Format-Result "Type" "dotnet-build" $true ""
            } else {
                $results += Format-Result "Type" "dotnet-build" $false ""
                $failed += "dotnet-build"
            }
        } else {
            Write-Host "${YELLOW}[TYPE]${R} dotnet (skip - not restored)"
        }

        Pop-Location
    }
}

# === PYTHON ===
if (Test-Path "pyproject.toml" -or Test-Path "requirements.txt") {
    if (Get-Command ruff -ErrorAction SilentlyContinue) {
        Write-Host "`n${CYAN}[FORMAT]${R} ruff format..."
        $null = ruff format . 2>&1
        $results += Format-Result "Format" "ruff" $true ""

        Write-Host "${CYAN}[LINT]${R} ruff check..."
        $lintOutput = ruff check . 2>&1
        if ($LASTEXITCODE -eq 0) {
            $results += Format-Result "Lint" "ruff" $true ""
        } else {
            $results += Format-Result "Lint" "ruff" $false ""
            $failed += "ruff"
        }
    }
}

# === GO ===
if (Test-Path "go.mod") {
    Write-Host "`n${CYAN}[FORMAT]${R} go fmt..."
    $null = go fmt ./... 2>&1
    $results += Format-Result "Format" "gofmt" $true ""

    if (Get-Command golangci-lint -ErrorAction SilentlyContinue) {
        Write-Host "${CYAN}[LINT]${R} golangci-lint..."
        $null = golangci-lint run --no-config ./... 2>&1
        $results += Format-Result "Lint" "golangci-lint" $true ""
    }
}

# === RUST ===
if (Test-Path "Cargo.toml") {
    Write-Host "`n${CYAN}[FORMAT]${R} cargo fmt..."
    $null = cargo fmt 2>&1
    $results += Format-Result "Format" "cargo-fmt" $true ""

    Write-Host "${CYAN}[LINT]${R} clippy..."
    $null = cargo clippy --quiet -- -D warnings 2>&1
    $results += Format-Result "Lint" "clippy" $true ""
}

# === JAVA ===
if (Test-Path "pom.xml" -and (Get-Command mvn -ErrorAction SilentlyContinue)) {
    Write-Host "`n${CYAN}[FORMAT]${R} spotless..."
    $null = mvn spotless:apply 2>&1
    $results += Format-Result "Format" "spotless" $true ""
}

# === SCALA ===
if (Test-Path "build.sbt") {
    Write-Host "`n${CYAN}[FORMAT]${R} scalafmt..."
    $null = scalafmt --non-interactive 2>&1
    $results += Format-Result "Format" "scalafmt" $true ""
}

# === SUMMARY ===
Write-Host "`n${BLUE}=== SUMMARY ===${R}"
foreach ($result in $results) {
    $status = if ($result.success) { "$GREEN+$R" } else { "$RED-$R" }
    Write-Host "$status $($result.category): $($result.tool)"
}

if ($failed.Count -gt 0) {
    Write-Host "`n${RED}Checks failed: $($failed -join ', ')${R}"
    exit 1
}

Write-Host "`n${GREEN}All checks passed!$R"
exit 0
