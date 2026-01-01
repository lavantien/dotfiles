# Uninstall Script Wrapper - Invokes uninstall.sh via Git Bash
# Usage: .\uninstall.ps1 [-DryRun] [-KeepBackups] [-VerifyOnly]

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Derive .sh script name
$shScript = Join-Path $ScriptDir "uninstall.sh"

# Convert Windows path to Git Bash format (C:\... -> /c/...)
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
        "-DryRun" { $mappedArgs += "--dry-run" }
        "-KeepBackups" { $mappedArgs += "--keep-backups" }
        "-VerifyOnly" { $mappedArgs += "--verify-only" }
        default { $mappedArgs += $args[$i] }
    }
}

# Invoke the bash script with exit code propagation
$exitCode = & bash $shScriptBash $mappedArgs
exit $exitCode
