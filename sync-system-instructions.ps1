# Sync System Instructions Wrapper - Invokes sync-system-instructions.sh via Git Bash
# Usage: .\sync-system-instructions.ps1 [-BaseDir] "path" [-Commit] [-Push]

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

# Change to script directory and invoke bash as login shell
# Using -l (login shell) ensures proper PATH and mount point setup
# Using relative path avoids path conversion issues
$origLocation = Get-Location
try {
    Set-Location $ScriptDir
    $argList = $mappedArgs -join ' '
    $bashArgs = @("-l", "-c", "./sync-system-instructions.sh $argList")
    & bash @bashArgs
    $exitCode = $LASTEXITCODE
}
finally {
    Set-Location $origLocation
}

exit $exitCode
