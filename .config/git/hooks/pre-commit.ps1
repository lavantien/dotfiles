# PowerShell Git pre-commit hook - Runs formatters, linters, and type checkers on staged files
# Supports: Go, Rust, Python, JS/TS, C/C++, C#, PHP, Bash, Scala, Lua

$ErrorActionPreference = "Continue"

# Track if any changes were made or issues found
$changesMade = $false
$issuesFound = $false

# Get list of staged files
$stagedFiles = git diff --cached --name-only --diff-filter=ACM 2>$null | Where-Object {
    $_ -notmatch '^vendor/' -and $_ -notmatch '^node_modules/'
}

if ($null -eq $stagedFiles -or $stagedFiles.Count -eq 0) {
    exit 0
}

Write-Host "Running pre-commit checks..." -ForegroundColor Green

# Function to check if command exists
function Test-Command {
    param([string]$Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

# Function to run formatter and re-stage files
function Invoke-Formatter {
    param(
        [string[]]$Files,
        [string]$Command,
        [string]$Name
    )

    if ($null -eq $Files -or $Files.Count -eq 0) {
        return
    }

    Write-Host "  Running $Name..." -ForegroundColor Yellow

    $cmdParts = $Command -split ' '
    $cmdExe = $cmdParts[0]
    $cmdArgs = $cmdParts[1..($cmdParts.Count - 1)] + $Files

    $process = Start-Process -FilePath $cmdExe -ArgumentList $cmdArgs -NoNewWindow -Wait -PassThru

    if ($process.ExitCode -eq 0) {
        # Re-stage formatted files
        $Files | ForEach-Object { git add $_ 2>$null }
        $script:changesMade = $true
    } else {
        Write-Host "  $Name failed or made changes" -ForegroundColor Red
        $script:issuesFound = $true
    }
}

# Group files by extension
$goFiles = $stagedFiles | Where-Object { $_ -match '\.go$' }
$rsFiles = $stagedFiles | Where-Object { $_ -match '\.rs$' }
$pyFiles = $stagedFiles | Where-Object { $_ -match '\.py$' }
$jsFiles = $stagedFiles | Where-Object { $_ -match '\.(js|ts|tsx|jsx)$' }
$htmlFiles = $stagedFiles | Where-Object { $_ -match '\.(html|htm)$' }
$cssFiles = $stagedFiles | Where-Object { $_ -match '\.(css|scss|sass)$' }
$svelteFiles = $stagedFiles | Where-Object { $_ -match '\.svelte$' }
$cFiles = $stagedFiles | Where-Object { $_ -match '\.(c|cpp|h|hpp)$' }
$csFiles = $stagedFiles | Where-Object { $_ -match '\.cs$' }
$phpFiles = $stagedFiles | Where-Object { $_ -match '\.php$' }
$shFiles = $stagedFiles | Where-Object { $_ -match '\.(sh|bash)$' }
$scalaFiles = $stagedFiles | Where-Object { $_ -match '\.scala$' }
$luaFiles = $stagedFiles | Where-Object { $_ -match '\.lua$' }
$ps1Files = $stagedFiles | Where-Object { $_ -match '\.ps1$' }

# Go files (*.go)
if ($goFiles) {
    if (Test-Command "gofmt") {
        Invoke-Formatter $goFiles "gofmt -w" "gofmt"
    }
    if (Test-Command "goimports") {
        Invoke-Formatter $goFiles "goimports -w" "goimports"
    }
    if (Test-Command "golangci-lint") {
        Write-Host "  Running golangci-lint..." -ForegroundColor Yellow
        $process = Start-Process -FilePath "golangci-lint" -ArgumentList @("run") + $goFiles -NoNewWindow -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            Write-Host "  golangci-lint found issues" -ForegroundColor Red
            $issuesFound = $true
        }
    }
    if (Test-Command "go") {
        Write-Host "  Running go vet..." -ForegroundColor Yellow
        $process = Start-Process -FilePath "go" -ArgumentList @("vet") + $goFiles -NoNewWindow -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            Write-Host "  go vet found issues" -ForegroundColor Red
            $issuesFound = $true
        }
    }
}

# Rust files (*.rs)
if ($rsFiles) {
    if (Test-Command "rustfmt") {
        Invoke-Formatter $rsFiles "rustfmt" "rustfmt"
    }
    if (Test-Command "cargo") {
        Write-Host "  Running cargo check..." -ForegroundColor Yellow
        $process = Start-Process -FilePath "cargo" -ArgumentList @("check") -NoNewWindow -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            Write-Host "  cargo check failed" -ForegroundColor Red
            $issuesFound = $true
        }
        Write-Host "  Running clippy..." -ForegroundColor Yellow
        $process = Start-Process -FilePath "cargo" -ArgumentList @("clippy", "--all-targets", "--all-features") -NoNewWindow -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            Write-Host "  clippy found issues" -ForegroundColor Red
            $issuesFound = $true
        }
    }
}

# Python files (*.py)
if ($pyFiles) {
    if (Test-Command "ruff") {
        Invoke-Formatter $pyFiles "ruff format" "ruff format"
        Write-Host "  Running ruff check..." -ForegroundColor Yellow
        $process = Start-Process -FilePath "ruff" -ArgumentList @("check", "--fix") + $pyFiles -NoNewWindow -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            Write-Host "  ruff check found issues" -ForegroundColor Red
            $issuesFound = $true
        }
    }
    if (Test-Command "mypy") {
        Write-Host "  Running mypy..." -ForegroundColor Yellow
        $process = Start-Process -FilePath "mypy" -ArgumentList $pyFiles -NoNewWindow -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            Write-Host "  mypy found type issues (non-blocking)" -ForegroundColor Yellow
        }
    }
}

# JavaScript/TypeScript files (*.js, *.ts, *.tsx, *.jsx)
if ($jsFiles) {
    if (Test-Command "prettier") {
        Invoke-Formatter $jsFiles "prettier --write" "prettier"
    }
    if (Test-Command "eslint") {
        Write-Host "  Running eslint..." -ForegroundColor Yellow
        $process = Start-Process -FilePath "eslint" -ArgumentList @("--fix") + $jsFiles -NoNewWindow -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            Write-Host "  eslint found issues" -ForegroundColor Red
            $issuesFound = $true
        }
    }
    if (Test-Command "tsc") {
        Write-Host "  Running tsc..." -ForegroundColor Yellow
        $process = Start-Process -FilePath "tsc" -ArgumentList @("--noEmit") -NoNewWindow -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            Write-Host "  tsc found type issues (non-blocking)" -ForegroundColor Yellow
        }
    }
}

# HTML files (*.html, *.htm)
if ($htmlFiles) {
    if (Test-Command "prettier") {
        Invoke-Formatter $htmlFiles "prettier --write" "prettier (HTML)"
    }
}

# CSS/SCSS/SASS files (*.css, *.scss, *.sass)
if ($cssFiles) {
    if (Test-Command "prettier") {
        Invoke-Formatter $cssFiles "prettier --write" "prettier (CSS)"
    }
    if (Test-Command "stylelint") {
        Write-Host "  Running stylelint..." -ForegroundColor Yellow
        $process = Start-Process -FilePath "stylelint" -ArgumentList @("--fix") + $cssFiles -NoNewWindow -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            Write-Host "  stylelint found issues" -ForegroundColor Red
            $issuesFound = $true
        }
    }
}

# Svelte files (*.svelte)
if ($svelteFiles) {
    if (Test-Command "prettier") {
        Invoke-Formatter $svelteFiles "prettier --write" "prettier (Svelte)"
    }
    if (Test-Command "svelte-check") {
        Write-Host "  Running svelte-check..." -ForegroundColor Yellow
        $process = Start-Process -FilePath "svelte-check" -NoNewWindow -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            Write-Host "  svelte-check found issues (non-blocking)" -ForegroundColor Yellow
        }
    }
}

# C/C++ files (*.c, *.cpp, *.h, *.hpp)
if ($cFiles) {
    if (Test-Command "clang-format") {
        Invoke-Formatter $cFiles "clang-format -i" "clang-format"
    }
    if (Test-Command "clang-tidy") {
        Write-Host "  Running clang-tidy..." -ForegroundColor Yellow
        foreach ($file in $cFiles) {
            if (Test-Path $file) {
                $process = Start-Process -FilePath "clang-tidy" -ArgumentList $file -NoNewWindow -Wait -PassThru
                if ($process.ExitCode -ne 0) {
                    Write-Host "  clang-tidy found issues in $file (non-blocking)" -ForegroundColor Yellow
                }
            }
        }
    }
}

# C# files (*.cs)
if ($csFiles) {
    if (Test-Command "dotnet") {
        Write-Host "  Running dotnet format..." -ForegroundColor Yellow
        $process = Start-Process -FilePath "dotnet" -ArgumentList @("format") -NoNewWindow -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            Write-Host "  dotnet format made changes or had issues" -ForegroundColor Yellow
        }
    }
}

# PHP files (*.php)
if ($phpFiles) {
    if (Test-Command "pint") {
        Invoke-Formatter $phpFiles "pint" "pint"
    }
    if (Test-Command "phpstan") {
        Write-Host "  Running phpstan..." -ForegroundColor Yellow
        $process = Start-Process -FilePath "phpstan" -ArgumentList @("analyse") + $phpFiles -NoNewWindow -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            Write-Host "  phpstan found issues (non-blocking)" -ForegroundColor Yellow
        }
    }
}

# Bash/Shell files (*.sh, *.bash)
if ($shFiles) {
    if (Test-Command "shfmt") {
        Invoke-Formatter $shFiles "shfmt -w" "shfmt"
    }
    if (Test-Command "shellcheck") {
        Write-Host "  Running shellcheck..." -ForegroundColor Yellow
        $process = Start-Process -FilePath "shellcheck" -ArgumentList $shFiles -NoNewWindow -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            Write-Host "  shellcheck found issues" -ForegroundColor Red
            $issuesFound = $true
        }
    }
}

# PowerShell files (*.ps1) - Windows-specific
if ($ps1Files) {
    if (Test-Command "Invoke-Formatter") {
        Write-Host "  Running PSScriptAnalyzer..." -ForegroundColor Yellow
        foreach ($file in $ps1Files) {
            $result = Invoke-ScriptAnalyzer -Path $file -ErrorAction SilentlyContinue
            if ($result) {
                Write-Host "  PSScriptAnalyzer found issues in $file" -ForegroundColor Yellow
            }
        }
    }
}

# Scala files (*.scala)
if ($scalaFiles) {
    if (Test-Command "scalafmt") {
        Invoke-Formatter $scalaFiles "scalafmt" "scalafmt"
    }
    if (Test-Command "scalafix") {
        Write-Host "  Running scalafix..." -ForegroundColor Yellow
        $process = Start-Process -FilePath "scalafix" -ArgumentList $scalaFiles -NoNewWindow -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            Write-Host "  scalafix found issues (non-blocking)" -ForegroundColor Yellow
        }
    }
}

# Lua files (*.lua)
if ($luaFiles) {
    if (Test-Command "stylua") {
        Invoke-Formatter $luaFiles "stylua" "stylua"
    }
    if (Test-Command "selene") {
        Write-Host "  Running selene..." -ForegroundColor Yellow
        $process = Start-Process -FilePath "selene" -ArgumentList $luaFiles -NoNewWindow -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            Write-Host "  selene found issues (non-blocking)" -ForegroundColor Yellow
        }
    }
}

# Summary
if ($changesMade) {
    Write-Host "Formatters applied and files re-staged." -ForegroundColor Green
}

if ($issuesFound) {
    Write-Host "Pre-commit checks found issues. Please fix them before committing." -ForegroundColor Red
    exit 1
}

Write-Host "Pre-commit checks passed!" -ForegroundColor Green
exit 0
