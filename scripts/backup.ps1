# Backup Script Wrapper - Invokes backup.sh via Git Bash
# Usage: .\backup.ps1 [-DryRun] [-Keep N] [-BackupDir] "path"

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Find Git Bash explicitly (avoid WSL bash from C:\Windows\System32)
$GitBash = & {
    $gitBashPaths = @(
        "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe",
        "${env:ProgramFiles}\Git\bin\bash.exe",
        "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
        "$env:USERPROFILE\scoop\apps\git\current\usr\bin\bash.exe"
    )
    foreach ($path in $gitBashPaths) {
        if (Test-Path $path) { return $path }
    }
    throw "Git Bash (bash.exe) not found. Please install Git for Windows from https://git-scm.com/download/win"
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

# Change to script directory and invoke bash as login shell
# Using -l (login shell) ensures proper PATH and mount point setup
# Using relative path avoids path conversion issues
$origLocation = Get-Location
try {
    Set-Location $ScriptDir
    $argList = $mappedArgs -join ' '
    $bashArgs = @("-l", "-c", "./backup.sh $argList")
    & $GitBash @bashArgs
    $exitCode = $LASTEXITCODE
}
finally {
    Set-Location $origLocation
}

exit $exitCode
