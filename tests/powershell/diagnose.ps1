Import-Module Pester

# Test just the failing files
$files = @(
    'tests\powershell\config.Tests.ps1'
    'tests\powershell\git-hooks.Tests.ps1'
    'tests\powershell\e2e\config_e2e.Tests.ps1'
)

foreach ($file in $files) {
    Write-Host "`n=== Testing $file ===" -ForegroundColor Cyan
    $config = [PesterConfiguration]::Default
    $config.Run.Path = $file
    $config.Output.Verbosity = 'Detailed'

    try {
        $result = Invoke-Pester -Configuration $config
        Write-Host "Total: $($result.TotalCount) Passed: $($result.PassedCount) Failed: $($result.FailedCount)"
    } catch {
        Write-Host "Error: $_" -ForegroundColor Red
    }
}
