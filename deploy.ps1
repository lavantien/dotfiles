# Deploy Script Wrapper - Invokes deploy.sh via Git Bash
# This script deploys dotfiles to your home directory

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Import Git Bash finder (avoid WSL bash)
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

# Change to script directory and invoke bash as login shell
# Using -l (login shell) ensures proper PATH and mount point setup
# Using relative path avoids path conversion issues
$origLocation = Get-Location
try {
    Set-Location $ScriptDir
    $argList = $args -join ' '
    $bashArgs = @("-l", "-c", "./deploy.sh $argList")
    & $GitBash @bashArgs
    $exitCode = $LASTEXITCODE
}
finally {
    Set-Location $origLocation
}

exit $exitCode
