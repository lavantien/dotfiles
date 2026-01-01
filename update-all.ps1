# Update All Script Wrapper - Invokes update-all.sh via Git Bash
# Updates all package managers and tools

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Derive .sh script name
$shScript = Join-Path $ScriptDir "update-all.sh"

# Ensure Git Bash is available
if (-not (Get-Command bash -ErrorAction SilentlyContinue)) {
    Write-Error "Git Bash (bash.exe) not found. Please install Git for Windows."
    Write-Error "Download: https://git-scm.com/download/win"
    exit 1
}

# Invoke the bash script with exit code propagation
$exitCode = & bash $shScript $args
exit $exitCode
