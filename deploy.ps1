# Deploy Script Wrapper - Invokes deploy.sh via Git Bash
# This script deploys dotfiles to your home directory

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Derive .sh script name
$shScript = Join-Path $ScriptDir "deploy.sh"

# Ensure Git Bash is available
if (-not (Get-Command bash -ErrorAction SilentlyContinue)) {
    Write-Error "Git Bash (bash.exe) not found. Please install Git for Windows."
    Write-Error "Download: https://git-scm.com/download/win"
    exit 1
}

# Invoke the bash script with exit code propagation
# Pass all arguments through (deploy.sh doesn't take parameters currently)
$exitCode = & bash $shScript $args
exit $exitCode
