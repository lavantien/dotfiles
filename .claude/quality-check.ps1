#requires -Version 7

param(
    [Parameter(Mandatory = $false)]
    [string]$ChangedFile
)

$ErrorActionPreference = "Stop"

Write-Host "[quality-check.ps1] entry: changed file '$ChangedFile'" -ForegroundColor Cyan

$gitBashPaths = @(
    "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe",
    "${env:ProgramFiles}\Git\bin\bash.exe",
    "${env:ProgramFiles(x86)}\Git\bin\bash.exe"
)

$gitBash = $gitBashPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $gitBash) {
    Write-Host "[quality-check.ps1] failure: git-bash.exe not found in any known location: $($gitBashPaths -join ', ')" -ForegroundColor Red
    exit 1
}

$qualityCheckScript = Join-Path $PSScriptRoot "quality-check.sh"

if (!(Test-Path $qualityCheckScript)) {
    Write-Host "[quality-check.ps1] failure: quality-check.sh not found at $qualityCheckScript, deploy first or run from the repo" -ForegroundColor Red
    exit 1
}

Write-Host "[quality-check.ps1] running $qualityCheckScript via $gitBash" -ForegroundColor Cyan

$bashScriptPath = $qualityCheckScript -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'

if ([string]::IsNullOrEmpty($ChangedFile)) {
    $bashCommand = $bashScriptPath
} else {
    $bashFilePath = $ChangedFile -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'
    $bashCommand = "$bashScriptPath '$bashFilePath'"
}

& $gitBash -l -c $bashCommand
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    Write-Host "[quality-check.ps1] failure: quality-check.sh exited with code $exitCode" -ForegroundColor Red
} else {
    Write-Host "[quality-check.ps1] exit: ok" -ForegroundColor Green
}

exit $exitCode
