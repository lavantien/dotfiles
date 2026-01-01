Import-Module Pester
$config = [PesterConfiguration]::Default
$config.Run.Path = 'tests\powershell'
$config.Output.Verbosity = 'Detailed'
$config.Run.Exit = $false
$result = Invoke-Pester -Configuration $config

Write-Host "`n=== FAILING TESTS ==="
foreach ($test in $result.Failed) {
    Write-Host "[$($test.Result)] $($test.DescribeInfo.Display) - $($test.ContextInfo.Display) - $($test.Name)"
    if ($test.ErrorRecord) {
        Write-Host "  Error: $($test.ErrorRecord.Exception.Message)"
    }
}

Write-Host "`n=== Summary ==="
Write-Host "Total: $($result.TotalCount) Passed: $($result.PassedCount) Failed: $($result.FailedCount)"
