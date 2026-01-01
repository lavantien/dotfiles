# Restore Script Wrapper - Invokes restore.sh via Git Bash
# Usage: .\restore.ps1 [-BackupDir] "path" [-List] [-DryRun] [-Force] [BackupName]

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Derive .sh script name
$shScript = Join-Path $ScriptDir "restore.sh"

# Convert Windows path to Git Bash format (C:\... -> /c/...)
$shScriptBash = $shScript -replace '\\', '/' -replace '^([A-Z]):', '/$1'
$shScriptBash = '/' + $shScriptBash.Substring(1).ToLower() + $shScriptBash.Substring(2)

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
        "-BackupDir" {
            if ($i + 1 -lt $args.Length) {
                $mappedArgs += "--backup-dir"
                $mappedArgs += $args[$i + 1]
                $i++
            }
        }
        "-List" { $mappedArgs += "--list" }
        "-DryRun" { $mappedArgs += "--dry-run" }
        "-Force" { $mappedArgs += "--force" }
        default { $mappedArgs += $args[$i] }
    }
}

# Invoke the bash script with exit code propagation
$exitCode = & bash $shScriptBash $mappedArgs
exit $exitCode
