# Claude Code StopToolUse Hook
# Runs after tool execution completes to perform quality checks
# This hook is non-blocking - it won't prevent tool execution

param(
    [Parameter(Mandatory=$false)]
    [string]$ToolName,

    [Parameter(Mandatory=$false)]
    [string]$ChangedFile
)

$ErrorActionPreference = "Continue"

# Define which tools to check after (Write, Edit operations)
$relevantTools = @("Write", "Edit", "MultiEdit")

# Only run for file modification tools
if ($ToolName -and $ToolName -notin $relevantTools) {
    exit 0
}

# Get the quality check script
$qualityCheckScript = Join-Path $HOME ".claude/quality-check.ps1"

if (!(Test-Path $qualityCheckScript)) {
    exit 0
}

# Run quality checks
try {
    & $qualityCheckScript -ChangedFile $ChangedFile
} catch {
    # Don't fail the hook, just log
    Write-Host "Quality check hook encountered an error: $_" -ForegroundColor Yellow
}

exit 0
