# Inspect Pester coverage object structure
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

# Examine the object
Write-Host 'CodeCoverage properties:'
$result.CodeCoverage.PSObject.Properties.Name | ForEach-Object { Write-Host "  $_" }

Write-Host ''
Write-Host "CommandsAnalyzedCount: $($result.CodeCoverage.CommandsAnalyzedCount)"
Write-Host "CommandsExecutedCount: $($result.CodeCoverage.CommandsExecutedCount)"
Write-Host "CoveragePercent: $($result.CodeCoverage.CoveragePercent)"

Write-Host ''
Write-Host 'Checking for MissedCommands property...'
$missed = $result.CodeCoverage.MissedCommands
if ($missed) {
    Write-Host "MissedCommands type: $($missed.GetType().Name)"
    Write-Host "MissedCommands count: $($missed.Count)"
} else {
    Write-Host "No MissedCommands property"
}

Write-Host ''
Write-Host 'Checking for FileCoverageMissedCommands property...'
$fileMissed = $result.CodeCoverage.FileCoverageMissedCommands
if ($fileMissed) {
    Write-Host "FileCoverageMissedCommands type: $($fileMissed.GetType().Name)"
    Write-Host "Keys:"
    $fileMissed.Keys | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "No FileCoverageMissedCommands property"
}

# Try to get coverage by file
Write-Host ''
Write-Host 'Attempting to get per-file coverage...'
$coverageByFile = $result.CodeCoverage | Get-Member -MemberType Properties
Write-Host "All member types:"
$coverageByFile | ForEach-Object {
    Write-Host "  $($_.Name) - $($_.MemberType)"
}
