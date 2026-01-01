# Run all PowerShell tests and count
Import-Module Pester

$config = [PesterConfiguration]::Default
$config.Run.Path = 'tests\powershell'
$config.Output.Verbosity = 'Minimal'
$config.TestResult.Enabled = $false
$config.PassThru = $true

$result = Invoke-Pester -Configuration $config

Write-Host "`n=== TEST SUMMARY ===" -ForegroundColor Cyan
Write-Host "Total tests discovered: $($result.TotalCount)" -ForegroundColor Green
Write-Host "Passed: $($result.PassedCount)" -ForegroundColor Green
Write-Host "Failed: $($result.FailedCount)" -ForegroundColor Red
Write-Host "Skipped: $($result.SkippedCount)" -ForegroundColor Yellow
Write-Host "====================" -ForegroundColor Cyan
Write-Host "Parity with bash (134): $($result.TotalCount -ge 134)" -ForegroundColor $(if ($result.TotalCount -ge 134) { "Green" } else { "Yellow" })
