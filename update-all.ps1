# Update All Script Wrapper - Invokes update-all.sh via Git Bash
# Updates all package managers and tools
# On Windows (Git Bash), the bash script detects Windows and skips Linux-only commands

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Find Git Bash explicitly (avoid WSL bash from C:\Windows\System32)
$gitBashPaths = @(
    "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe",
    "${env:ProgramFiles}\Git\bin\bash.exe",
    "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
    "$env:USERPROFILE\scoop\apps\git\current\usr\bin\bash.exe"
)

$GitBash = $null
foreach ($path in $gitBashPaths) {
    if (Test-Path $path) {
        $GitBash = $path
        break
    }
}

if (-not $GitBash) {
    Write-Error "Git Bash (bash.exe) not found. Please install Git for Windows."
    Write-Error "Download: https://git-scm.com/download/win"
    exit 1
}

# Change to script directory and invoke bash as login shell
# Using -l (login shell) ensures proper PATH and mount point setup
# Using relative path avoids path conversion issues
$origLocation = Get-Location
try {
    Set-Location $ScriptDir
    $argList = $args -join ' '
    $bashArgs = @("-l", "-c", "./update-all.sh $argList")
    & $GitBash @bashArgs
    $exitCode = $LASTEXITCODE
}
finally {
    Set-Location $origLocation
}

exit $exitCode
