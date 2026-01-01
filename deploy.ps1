# Deploy Script Wrapper - Invokes deploy.sh via Git Bash
# This script deploys dotfiles to your home directory

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Derive .sh script name
$shScript = Join-Path $ScriptDir "deploy.sh"

# Convert Windows path to Git Bash format
$shScriptBash = $shScript -replace '\\', '/'
$shScriptBash = $shScriptBash -replace '^([A-Z]):/', '/$1/'

# Invoke the bash script with exit code propagation
# Pass all arguments through (deploy.sh doesn't take parameters currently)
$exitCode = & bash $shScriptBash @args
exit $exitCode
