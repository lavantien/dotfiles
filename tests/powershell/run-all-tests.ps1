Import-Module Pester
$config = [PesterConfiguration]::Default
$config.Run.Path = 'tests\powershell'
$config.Run.Exit = $true
$config.Output.Verbosity = 'Detailed'
$result = Invoke-Pester -Configuration $config

Write-Host "`n=== Summary ==="
Write-Host "Total: $($result.TotalCount) Passed: $($result.PassedCount) Failed: $($result.FailedCount)"

# Exit with proper code
exit $result.FailedCount
