# Analyze missed commands in detail
Import-Module Pester

$coreFiles = @(
    'bootstrap\lib\common.ps1',
    'bootstrap\lib\version-check.ps1',
    'bootstrap\platforms\windows.ps1',
    'lib\config.ps1'
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

Write-Host "`n=== Coverage Summary ==="
Write-Host "Coverage: $($result.CodeCoverage.CoveragePercent)%"
Write-Host "Commands Analyzed: $($result.CodeCoverage.CommandsAnalyzedCount)"
Write-Host "Commands Executed: $($result.CodeCoverage.CommandsExecutedCount)"
Write-Host "Commands Missed: $($result.CodeCoverage.CommandsMissedCount)"

# Get CommandsMissed
Write-Host "`n=== CommandsMissed Property ==="
$missed = $result.CodeCoverage.CommandsMissed
Write-Host "Type: $($missed.GetType().Name)"
Write-Host "Count: $($missed.Count)"

if ($missed.Count -gt 0) {
    Write-Host "`n=== Missed Commands (first 50) ==="
    $missed | Select-Object -First 50 | ForEach-Object { Write-Host "  $_" }
    if ($missed.Count -gt 50) {
        Write-Host "  ... and $($missed.Count - 50) more"
    }
}

# Get FilesAnalyzed
Write-Host "`n=== FilesAnalyzed Property ==="
$files = $result.CodeCoverage.FilesAnalyzed
Write-Host "Type: $($files.GetType().Name)"
Write-Host "Count: $($files.Count)"

Write-Host "`n=== Files Breakdown ==="
foreach ($file in $files) {
    Write-Host "`nFile: $file"

    # Get executed commands for this file
    $executed = $result.CodeCoverage.CommandsExecuted[$file]
    if ($executed) {
        Write-Host "  Executed: $($executed.Count) commands"
    }

    # Get missed commands for this file
    $missedForFile = $result.CodeCoverage.CommandsMissed[$file]
    if ($missedForFile) {
        Write-Host "  Missed: $($missedForFile.Count) commands"
        Write-Host "  Missed commands:"
        $missedForFile | Select-Object -First 10 | ForEach-Object { Write-Host "    - $_" }
        if ($missedForFile.Count -gt 10) {
            Write-Host "    ... and $($missedForFile.Count - 10) more"
        }
    }

    # Calculate coverage for this file
    $totalExecuted = if ($executed) { $executed.Count } else { 0 }
    $totalMissed = if ($missedForFile) { $missedForFile.Count } else { 0 }
    $totalCommands = $totalExecuted + $totalMissed
    if ($totalCommands -gt 0) {
        $fileCoverage = [math]::Round(($totalExecuted / $totalCommands) * 100, 1)
        Write-Host "  Coverage: $fileCoverage% ($totalExecuted/$totalCommands)"
    }
}
