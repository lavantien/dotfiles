# Claude Code PostToolUse hook - Runs format/lint/type-check after file writes
# This hook is invoked by Claude Code after any file write operation
# Usage: .claude/hooks/PostToolUse.ps1 should call this script

param(
    [Parameter(Mandatory=$false)]
    [string]$ChangedFile
)

$ErrorActionPreference = "Continue"

# If no specific file provided, check recent git changes
if ([string]::IsNullOrEmpty($ChangedFile)) {
    $ChangedFile = $(git diff --name-only HEAD~1 HEAD 2>$null | Select-Object -First 1)
}

if ([string]::IsNullOrEmpty($ChangedFile) -or !(Test-Path $ChangedFile)) {
    Write-Host "No file to check or file not found: $ChangedFile" -ForegroundColor Yellow
    exit 0
}

$extension = [System.IO.Path]::GetExtension($ChangedFile)
$fileName = Split-Path $ChangedFile -Leaf

Write-Host "Running quality check for: $ChangedFile" -ForegroundColor Cyan

# Function to check if command exists
function Test-Command {
    param([string]$Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

# Function to run a tool and display results
function Invoke-QualityTool {
    param(
        [string]$Command,
        [string[]]$Arguments,
        [string]$ToolName
    )

    if (!(Test-Command $Command)) {
        return
    }

    Write-Host "  Running $ToolName..." -ForegroundColor Yellow

    try {
        $process = Start-Process -FilePath $Command -ArgumentList $Arguments -NoNewWindow -Wait -PassThru -ErrorAction Stop
        if ($process.ExitCode -eq 0) {
            Write-Host "  $ToolName passed" -ForegroundColor Green
        } else {
            Write-Host "  $ToolName found issues (exit code: $($process.ExitCode))" -ForegroundColor Yellow
        }
        return $process.ExitCode
    } catch {
        Write-Host "  $ToolName failed to run: $_" -ForegroundColor Red
        return 1
    }
}

# --- Go files (*.go) ---
if ($extension -eq '.go') {
    Invoke-QualityTool "gofmt" @("-w", $ChangedFile) "gofmt"
    if (Test-Command "goimports") {
        Invoke-QualityTool "goimports" @("-w", $ChangedFile) "goimports"
    }
    if (Test-Command "golangci-lint") {
        Invoke-QualityTool "golangci-lint" @("run", $ChangedFile) "golangci-lint"
    }
    if (Test-Command "go") {
        Invoke-QualityTool "go" @("vet", $ChangedFile) "go vet"
    }
}

# --- Rust files (*.rs) ---
elseif ($extension -eq '.rs') {
    Invoke-QualityTool "rustfmt" @($ChangedFile) "rustfmt"
    if (Test-Command "cargo") {
        Invoke-QualityTool "cargo" @("check") "cargo check"
        Invoke-QualityTool "cargo" @("clippy", "--all-targets") "clippy"
    }
}

# --- Python files (*.py) ---
elseif ($extension -eq '.py') {
    if (Test-Command "ruff") {
        Invoke-QualityTool "ruff" @("format", $ChangedFile) "ruff format"
        Invoke-QualityTool "ruff" @("check", "--fix", $ChangedFile) "ruff check"
    }
    if (Test-Command "mypy") {
        Invoke-QualityTool "mypy" @($ChangedFile) "mypy"
    }
}

# --- JavaScript/TypeScript files (*.js, *.ts, *.tsx, *.jsx) ---
elseif ($extension -match '\.(js|ts|tsx|jsx)$') {
    if (Test-Command "prettier") {
        Invoke-QualityTool "prettier" @("--write", $ChangedFile) "prettier"
    }
    if (Test-Command "eslint") {
        Invoke-QualityTool "eslint" @("--fix", $ChangedFile) "eslint"
    }
    if ($extension -match '\.(ts|tsx)$' -and (Test-Command "tsc")) {
        Invoke-QualityTool "tsc" @("--noEmit") "tsc"
    }
}

# --- C/C++ files (*.c, *.cpp, *.h, *.hpp) ---
elseif ($extension -match '\.(c|cpp|h|hpp)$') {
    if (Test-Command "clang-format") {
        Invoke-QualityTool "clang-format" @("-i", $ChangedFile) "clang-format"
    }
    if (Test-Command "clang-tidy") {
        Invoke-QualityTool "clang-tidy" @($ChangedFile) "clang-tidy"
    }
    if (Test-Command "cppcheck") {
        Invoke-QualityTool "cppcheck" @($ChangedFile) "cppcheck"
    }
}

# --- C# files (*.cs) ---
elseif ($extension -eq '.cs') {
    if (Test-Command "dotnet") {
        Invoke-QualityTool "dotnet" @("format") "dotnet format"
    }
}

# --- PHP files (*.php) ---
elseif ($extension -eq '.php') {
    if (Test-Command "pint") {
        Invoke-QualityTool "pint" @($ChangedFile) "Laravel Pint"
    }
    if (Test-Command "phpstan") {
        Invoke-QualityTool "phpstan" @("analyse", $ChangedFile) "PHPStan"
    }
    if (Test-Command "psalm") {
        Invoke-QualityTool "psalm" @($ChangedFile) "Psalm"
    }
}

# --- Bash/Shell files (*.sh, *.bash) ---
elseif ($extension -match '\.(sh|bash)$') {
    if (Test-Command "shfmt") {
        Invoke-QualityTool "shfmt" @("-w", $ChangedFile) "shfmt"
    }
    if (Test-Command "shellcheck") {
        Invoke-QualityTool "shellcheck" @($ChangedFile) "shellcheck"
    }
}

# --- PowerShell files (*.ps1) ---
elseif ($extension -eq '.ps1') {
    if (Test-Command "Invoke-ScriptAnalyzer") {
        Write-Host "  Running PSScriptAnalyzer..." -ForegroundColor Yellow
        $result = Invoke-ScriptAnalyzer -Path $ChangedFile -ErrorAction SilentlyContinue
        if ($result) {
            Write-Host "  PSScriptAnalyzer found issues:" -ForegroundColor Yellow
            $result | ForEach-Object { Write-Host "    $($_.RuleName): $($_.Message)" -ForegroundColor Gray }
        } else {
            Write-Host "  PSScriptAnalyzer passed" -ForegroundColor Green
        }
    }
}

# --- Scala files (*.scala) ---
elseif ($extension -eq '.scala') {
    if (Test-Command "scalafmt") {
        Invoke-QualityTool "scalafmt" @($ChangedFile) "scalafmt"
    }
    if (Test-Command "scalafix") {
        Invoke-QualityTool "scalafix" @($ChangedFile) "scalafix"
    }
}

# --- Lua files (*.lua) ---
elseif ($extension -eq '.lua') {
    if (Test-Command "stylua") {
        Invoke-QualityTool "stylua" @($ChangedFile) "stylua"
    }
    if (Test-Command "selene") {
        Invoke-QualityTool "selene" @($ChangedFile) "selene"
    }
}

# --- HTML files (*.html, *.htm) ---
elseif ($extension -match '\.(html|htm)$') {
    if (Test-Command "prettier") {
        Invoke-QualityTool "prettier" @("--write", $ChangedFile) "prettier (HTML)"
    }
}

# --- CSS/SCSS/SASS files (*.css, *.scss, *.sass) ---
elseif ($extension -match '\.(css|scss|sass)$') {
    if (Test-Command "prettier") {
        Invoke-QualityTool "prettier" @("--write", $ChangedFile) "prettier (CSS)"
    }
    if (Test-Command "stylelint") {
        Invoke-QualityTool "stylelint" @("--fix", $ChangedFile) "stylelint"
    }
}

# --- Svelte files (*.svelte) ---
elseif ($extension -eq '.svelte') {
    if (Test-Command "prettier") {
        Invoke-QualityTool "prettier" @("--write", $ChangedFile) "prettier (Svelte)"
    }
    if (Test-Command "svelte-check") {
        Invoke-QualityTool "svelte-check" @($ChangedFile) "svelte-check"
    }
}

# --- YAML files (*.yml, *.yaml) ---
elseif ($extension -match '\.(yml|yaml)$') {
    if (Test-Command "prettier") {
        Invoke-QualityTool "prettier" @("--write", $ChangedFile) "prettier"
    }
    if (Test-Command "yamllint") {
        Invoke-QualityTool "yamllint" @($ChangedFile) "yamllint"
    }
}

# --- JSON files (*.json) ---
elseif ($extension -eq '.json') {
    if (Test-Command "prettier") {
        Invoke-QualityTool "prettier" @("--write", $ChangedFile) "prettier"
    }
    if (Test-Command "jq") {
        # Validate JSON syntax
        $null = Get-Content $ChangedFile | jq . 2>$null
        if ($?) {
            Write-Host "  jq validation passed" -ForegroundColor Green
        } else {
            Write-Host "  jq validation failed" -ForegroundColor Red
        }
    }
}

# --- Markdown files (*.md) ---
elseif ($extension -eq '.md') {
    if (Test-Command "prettier") {
        Invoke-QualityTool "prettier" @("--write", $ChangedFile) "prettier"
    }
    if (Test-Command "markdownlint") {
        Invoke-QualityTool "markdownlint" @($ChangedFile) "markdownlint"
    }
}

# --- Typst files (*.typ) ---
elseif ($extension -eq '.typ') {
    if (Test-Command "typst") {
        Invoke-QualityTool "typst" @("check", $ChangedFile) "typst check"
    }
}

# --- TOML files (*.toml) ---
elseif ($extension -eq '.toml') {
    if (Test-Command "taplo") {
        Invoke-QualityTool "taplo" @("format", $ChangedFile) "taplo"
    }
}

else {
    Write-Host "  No quality checker configured for extension: $extension" -ForegroundColor Gray
}

Write-Host "Quality check complete for: $ChangedFile" -ForegroundColor Cyan
exit 0
