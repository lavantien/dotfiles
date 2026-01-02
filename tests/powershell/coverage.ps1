# Test PowerShell code coverage with Pester
Import-Module Pester

$config = [PesterConfiguration]::Default

# Enable code coverage
$config.CodeCoverage.Enabled = $true

# Paths to analyze for coverage - all production PowerShell scripts
$config.CodeCoverage.Path = @(
    # Root entry point scripts
    "bootstrap.ps1",
    "deploy.ps1",
    "update-all.ps1",
    "backup.ps1",
    "restore.ps1",
    "healthcheck.ps1",
    "uninstall.ps1",
    "git-update-repos.ps1",
    "sync-system-instructions.ps1",
    "update-all-windows.ps1",
    # Bootstrap internal scripts
    "bootstrap\bootstrap.ps1",
    "bootstrap\lib\common.ps1",
    "bootstrap\lib\version-check.ps1",
    "bootstrap\platforms\windows.ps1",
    # Library scripts
    "lib\config.ps1",
    # Git hooks
    "hooks\git\pre-commit.ps1",
    "hooks\git\commit-msg.ps1",
    "hooks\claude\quality-check.ps1"
)

# Run tests
$config.Run.Path = 'tests\powershell'
$config.Run.PassThru = $true  # Important: returns the result object
$config.Output.Verbosity = 'Normal'

$result = Invoke-Pester -Configuration $config

Write-Host "`n=== Code Coverage Summary ==="
$coveragePercent = [math]::Round($result.CodeCoverage.CoveragePercent, 2)
Write-Host "Coverage: $coveragePercent%"
Write-Host "Commands Executed: $($result.CodeCoverage.CommandsExecutedCount)"
Write-Host "Commands Analyzed: $($result.CodeCoverage.CommandsAnalyzedCount)"

# Show coverage by file
Write-Host "`n=== Coverage by File ==="
foreach ($file in $result.CodeCoverage.CoveragePercent) {
    if ($file.Key) {
        $fileName = Split-Path $file.Key -Leaf
        $percent = [math]::Round($file.Value, 1)
        Write-Host "$fileName : $percent%"
    }
}

# Export coverage for badges
$coverageData = @{
    coverage = [math]::Round($result.CodeCoverage.CoveragePercent, 1)
    timestamp = Get-Date -Format "o"
} | ConvertTo-Json -Depth 10

$coverageData | Out-File "coverage.json" -Encoding UTF8
Write-Host "`nSaved coverage.json with coverage: $coveragePercent%"
