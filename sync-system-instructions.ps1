# Sync System Instructions Wrapper - Invokes sync-system-instructions.sh via Git Bash
# Usage: .\sync-system-instructions.ps1 [-BaseDir] "path" [-Commit] [-Push]

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Derive .sh script name
$shScript = Join-Path $ScriptDir "sync-system-instructions.sh"

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
        "-BaseDir" {
            if ($i + 1 -lt $args.Length) {
                $mappedArgs += "--base-dir"
                $mappedArgs += $args[$i + 1]
                $i++
            }
        }
        "-Commit" { $mappedArgs += "--commit" }
        "-Push" { $mappedArgs += "--push" }
        default { $mappedArgs += $args[$i] }
    }
}

# Invoke the bash script with exit code propagation
$exitCode = & bash $shScriptBash $mappedArgs
exit $exitCode
