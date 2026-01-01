# Git Update Repos Wrapper - Invokes git-update-repos.sh via Git Bash
# Usage: .\git-update-repos.ps1 [-Username] "username" [-BaseDir] "path" [-UseSSH] [-NoSync] [-Commit]

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Derive .sh script name
$shScript = Join-Path $ScriptDir "git-update-repos.sh"

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
        "-Username" {
            if ($i + 1 -lt $args.Length) {
                $mappedArgs += "--username"
                $mappedArgs += $args[$i + 1]
                $i++
            }
        }
        "-BaseDir" {
            if ($i + 1 -lt $args.Length) {
                $mappedArgs += "--base-dir"
                $mappedArgs += $args[$i + 1]
                $i++
            }
        }
        "-UseSSH" { $mappedArgs += "--use-ssh" }
        "-NoSync" { $mappedArgs += "--no-sync" }
        "-Commit" { $mappedArgs += "--commit" }
        default { $mappedArgs += $args[$i] }
    }
}

# Invoke the bash script with exit code propagation
$exitCode = & bash $shScriptBash $mappedArgs
exit $exitCode
