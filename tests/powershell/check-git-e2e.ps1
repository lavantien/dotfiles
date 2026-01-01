Import-Module Pester
$config = [PesterConfiguration]::Default
$config.Run.Path = 'tests\powershell\e2e\git-hooks_e2e.Tests.ps1'
$config.Output.Verbosity = 'Detailed'
$result = Invoke-Pester -Configuration $config

Write-Host "`n=== Summary ==="
Write-Host "Total: $($result.TotalCount) Passed: $($result.PassedCount) Failed: $($result.FailedCount)"
