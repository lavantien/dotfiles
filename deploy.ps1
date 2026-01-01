# Deploy Script Wrapper - Invokes deploy.sh via Git Bash
# This script deploys dotfiles to your home directory

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Derive .sh script name
$shScript = Join-Path $ScriptDir "deploy.sh"

# Convert Windows path to Git Bash format (C:\... -> /c/...)
$shScriptBash = $shScript -replace '\\', '/' -replace '^([A-Z]):', '/$1'
$shScriptBash = '/' + $shScriptBash.Substring(1).ToLower() + $shScriptBash.Substring(2)

# Ensure Git Bash is available
if (-not (Get-Command bash -ErrorAction SilentlyContinue)) {
    Write-Error "Git Bash (bash.exe) not found. Please install Git for Windows."
    Write-Error "Download: https://git-scm.com/download/win"
    exit 1
}

# Invoke the bash script with exit code propagation
# Pass all arguments through (deploy.sh doesn't take parameters currently)
$exitCode = & bash $shScriptBash $args
exit $exitCode
