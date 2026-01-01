# Update All Script Wrapper - Invokes update-all.sh via Git Bash
# Updates all package managers and tools

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Derive .sh script name
$shScript = Join-Path $ScriptDir "update-all.sh"

# Convert Windows path to Git Bash format
$shScriptBash = $shScript -replace '\\', '/'
$shScriptBash = $shScriptBash -replace '^([A-Z]):/', '/$1/'

# Invoke the bash script with exit code propagation
$exitCode = & bash $shScriptBash @args
exit $exitCode
