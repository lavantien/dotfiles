# Git Update Repos Wrapper - Invokes git-update-repos.sh via Git Bash
# Usage: .\git-update-repos.ps1 [-Username] "username" [-BaseDir] "path" [-UseSSH] [-NoSync] [-Commit]

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

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

# Change to script directory and invoke bash as login shell
# Using -l (login shell) ensures proper PATH and mount point setup
# Using relative path avoids path conversion issues
$origLocation = Get-Location
try {
    Set-Location $ScriptDir
    $argList = $mappedArgs -join ' '
    $bashArgs = @("-l", "-c", "./git-update-repos.sh $argList")
    & bash @bashArgs
    $exitCode = $LASTEXITCODE
}
finally {
    Set-Location $origLocation
}

exit $exitCode
