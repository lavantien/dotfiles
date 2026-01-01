# Bootstrap Script Wrapper - Invokes bootstrap.sh via Git Bash
# Usage: .\bootstrap.ps1 [-Category] "minimal|sdk|full"

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Derive .sh script name (root level bootstrap.sh)
$shScript = Join-Path $ScriptDir "bootstrap.sh"

# Convert Windows path to Git Bash format (C:\... -> /c/...)
# Git Bash expects Unix-style paths
$shScriptBash = $shScript -replace '\\', '/' -replace '^([A-Z]):', '/$1'

# Ensure Git Bash is available
if (-not (Get-Command bash -ErrorAction SilentlyContinue)) {
    Write-Error "Git Bash (bash.exe) not found. Please install Git for Windows."
    Write-Error "Download: https://git-scm.com/download/win"
    exit 1
}

# Map PowerShell parameter names to bash equivalents
$mappedArgs = @()
for ($i = 0; $i -lt $args.Length; $i++) {
    switch ($args[$i]) {
        "-Category" {
            if ($i + 1 -lt $args.Length) {
                $mappedArgs += "--category"
                $mappedArgs += $args[$i + 1]
                $i++
            }
        }
        default { $mappedArgs += $args[$i] }
    }
}

# Invoke the bash script with exit code propagation
$exitCode = & bash $shScriptBash $mappedArgs
exit $exitCode
