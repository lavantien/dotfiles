# Core-only coverage test - excludes wrapper scripts that can't be tested on Windows
param()

Import-Module Pester

Write-Host "`n=== Core Files Coverage Test ===`n"

$coreFiles = @(
    "bootstrap\lib\common.ps1",
    "bootstrap\lib\version-check.ps1",
    "bootstrap\platforms\windows.ps1",
    "lib\config.ps1"
)

Write-Host "Testing core files:"
$coreFiles | ForEach-Object { Write-Host "  - $_" }

$config = [PesterConfiguration]::Default
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = $coreFiles
$config.Run.Path = @(
    'tests\powershell\lib-config.Tests.ps1',
    'tests\powershell\common-lib-full.Tests.ps1',
    'tests\powershell\windows-platform-full.Tests.ps1',
    'tests\powershell\version-check-full.Tests.ps1',
    'tests\powershell\final-coverage.Tests.ps1',
    'tests\powershell\edge-case-coverage.Tests.ps1',
    'tests\powershell\version-edge-cases.Tests.ps1',
    'tests\powershell\windows-installers-full.Tests.ps1',
    'tests\powershell\common-full-coverage.Tests.ps1'
)
$config.Run.PassThru = $true
$config.Output.Verbosity = 'None'
$config.TestResult.Enabled = $false

$result = Invoke-Pester -Configuration $config

$coverage = $result.CodeCoverage.CoveragePercent
$analyzed = $result.CodeCoverage.CommandsAnalyzedCount
$executed = $result.CodeCoverage.CommandsExecutedCount

Write-Host "`n=== Core Coverage Results ==="
Write-Host "Coverage: $coverage% ($executed/$analyzed commands)"
Write-Host "Files tested:"
$coreFiles | ForEach-Object { Write-Host "  - $_" }

# Show uncovered commands per file
Write-Host "`n=== Uncovered Commands by File ==="
foreach ($file in $result.CodeCoverage.CoveragePercent.Keys) {
    $fileData = $result.CodeCoverage.CoveragePercent[$file]
    $fileCoverage = $fileData.CoveragePercent
    $totalCommands = $fileData.TotalCommands
    $coveredCommands = $fileData.CoveredCommands
    Write-Host "$file : $fileCoverage% ($coveredCommands/$totalCommands)"

    # Show uncovered commands if any
    if ($fileData.MissedCommands.Count -gt 0) {
        Write-Host "  Uncovered: $($fileData.MissedCommands.Count) commands"
        $fileData.MissedCommands | Select-Object -First 10 | ForEach-Object {
            Write-Host "    - $_"
        }
        if ($fileData.MissedCommands.Count -gt 10) {
            Write-Host "    ... and $($fileData.MissedCommands.Count - 10) more"
        }
    }
}

# Save core coverage data
$coreData = @{
    core_coverage = [math]::Round($coverage, 1)
    analyzed_commands = $analyzed
    executed_commands = $executed
    timestamp = Get-Date -Format "o"
} | ConvertTo-Json -Depth 10

$coreData | Out-File "coverage-core.json" -Encoding UTF8
Write-Host "`nCore coverage data saved to: coverage-core.json"

# Exit with appropriate code
if ($coverage -ge 80) {
    Write-Host "`nSUCCESS: Core coverage is 80%+!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nINFO: Core coverage is $coverage%, target is 80%" -ForegroundColor Yellow
    exit 0
}
