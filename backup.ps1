# Backup Script Wrapper - Invokes backup.sh via Git Bash
# Usage: .\backup.ps1 [-DryRun] [-Keep N] [-BackupDir] "path"

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Derive .sh script name
$shScript = Join-Path $ScriptDir "backup.sh"

# Convert Windows path to Git Bash format (C:\... -> /c/...)
$shScriptBash = $shScript -replace '\\', '/' -replace '^([A-Z]):', '/$1'

# Ensure Git Bash is available
if (-not (Get-Command bash -ErrorAction SilentlyContinue)) {
    Write-Error "Git Bash (bash.exe) not found. Please install Git for Windows."
    Write-Error "Download: https://git-scm.com/download/win"
    exit 1
}

# Convert PowerShell args to bash-friendly format
$bashArgs = $args | ForEach-Object {
    if ($_ -match '\s') { "`"$_`"" } else { $_ }
}

# Map PowerShell parameter names to bash equivalents
$mappedArgs = @()
for ($i = 0; $i -lt $args.Length; $i++) {
    switch ($args[$i]) {
        "-DryRun" { $mappedArgs += "--dry-run" }
        "-Keep" {
            if ($i + 1 -lt $args.Length) {
                $mappedArgs += "--keep"
                $mappedArgs += $args[$i + 1]
                $i++
            }
        }
        "-BackupDir" {
            if ($i + 1 -lt $args.Length) {
                $mappedArgs += "--backup-dir"
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
