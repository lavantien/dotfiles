# Claude Code Quality Check Script (Windows)
# Wrapper that calls the bash version via git-bash
# The bash script is the source of truth for cross-platform consistency

param(
    [Parameter(Mandatory=$false)]
    [string]$ChangedFile
)

$ErrorActionPreference = "Continue"

# Find git-bash.exe (Git for Windows installation)
$gitBashPaths = @(
    "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe",
    "${env:ProgramFiles}\Git\bin\bash.exe",
    "${env:ProgramFiles(x86)}\Git\bin\bash.exe"
)

$gitBash = $null
foreach ($path in $gitBashPaths) {
    if (Test-Path $path) {
        $gitBash = $path
        break
    }
}

if (-not $gitBash) {
    Write-Host "Git Bash not found. Please install Git for Windows." -ForegroundColor Red
    exit 1
}

# Get the quality check script path
$qualityCheckScript = Join-Path $HOME ".claude/quality-check.sh"

if (!(Test-Path $qualityCheckScript)) {
    Write-Host "Quality check script not found: $qualityCheckScript" -ForegroundColor Red
    exit 1
}

# Convert Windows path to Git Bash path (C:\ -> /c/)
$bashScriptPath = $qualityCheckScript -replace '\\', '/' -replace '^([A-Z]):', '/$1'

# Build the bash command
if ([string]::IsNullOrEmpty($ChangedFile)) {
    $bashArgs = @("-l", "-c", "`"$bashScriptPath`"")
} else {
    # Convert file path for bash
    $bashFilePath = $ChangedFile -replace '\\', '/' -replace '^([A-Z]):', '/$1'
    $bashArgs = @("-l", "-c", "`"$bashScriptPath '$bashFilePath'`"")
}

# Execute bash script
& $gitBash $bashArgs
exit $LASTEXITCODE
