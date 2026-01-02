# Get detailed uncovered commands from coverage report
Import-Module Pester

$coreFiles = @(
    "bootstrap\lib\common.ps1",
    "bootstrap\lib\version-check.ps1",
    "bootstrap\platforms\windows.ps1",
    "lib\config.ps1"
)

$config = [PesterConfiguration]::Default
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = $coreFiles
$config.Run.Path = @(
    'tests\powershell\lib-config.Tests.ps1',
    'tests\powershell\common-lib-full.Tests.ps1',
    'tests\powershell\windows-platform-full.Tests.ps1',
    'tests\powershell\version-check-full.Tests.ps1',
    'tests\powershell\final-coverage.Tests.ps1'
)
$config.Run.PassThru = $true
$config.Output.Verbosity = 'None'
$config.TestResult.Enabled = $false

$result = Invoke-Pester -Configuration $config

Write-Host "`n=== Detailed Coverage Report ===`n"

foreach ($fileEntry in $result.CodeCoverage.CoveragePercent.Keys) {
    $fileInfo = $result.CodeCoverage.CoveragePercent[$fileEntry]
    $coverage = $fileInfo.CoveragePercent
    $total = $fileInfo.TotalCommands
    $covered = $fileInfo.CoveredCommands
    $missed = $total - $covered

    Write-Host "File: $fileEntry"
    Write-Host "  Coverage: $coverage% ($covered/$total commands)"
    Write-Host "  Missed: $missed commands"

    # Get the actual MissedCommands
    $missedCommands = if ($fileInfo.MissedCommands) { $fileInfo.MissedCommands }
                    elseif ($fileInfo.ContainsKey('MissedCommands')) { @($fileInfo.MissedCommands | Select-Object -Unique) }
                    else { @() }

    if ($missedCommands.Count -gt 0) {
        Write-Host "  Uncovered commands:"
        $missedCommands | Select-Object -First 20 | ForEach-Object {
            Write-Host "    - $_"
        }
        if ($missedCommands.Count -gt 20) {
            Write-Host "    ... and $($missedCommands.Count - 20) more"
        }
    }
    Write-Host ""
}

Write-Host "`n=== Overall ==="
Write-Host "Total Coverage: $($result.CodeCoverage.CoveragePercent)%"
Write-Host "Commands Analyzed: $($result.CodeCoverage.CommandsAnalyzedCount)"
Write-Host "Commands Executed: $($result.CodeCoverage.CommandsExecutedCount)"
