# Generate detailed coverage report with missed commands
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

# Export detailed coverage to file
$coverageReportPath = "coverage-detailed.xml"
$result.CodeCoverage | Export-Clixml -Path $coverageReportPath

Write-Host "Coverage report saved to: $coverageReportPath"
Write-Host "`nCoverage: $($result.CodeCoverage.CoveragePercent)%"

# Inspect the coverage object structure
Write-Host "`n=== Coverage Object Structure ==="
Write-Host "CoveragePercent type: $($result.CodeCoverage.CoveragePercent.GetType().Name)"

if ($result.CodeCoverage.CoveragePercent -is [hashtable]) {
    Write-Host "Keys in CoveragePercent:"
    $result.CodeCoverage.CoveragePercent.Keys | ForEach-Object { Write-Host "  - $_" }

    Write-Host "`n=== File-by-File Breakdown ==="
    foreach ($key in $result.CodeCoverage.CoveragePercent.Keys) {
        $value = $result.CodeCoverage.CoveragePercent[$key]
        Write-Host "`nFile: $key"
        Write-Host "  Type: $($value.GetType().Name)"

        if ($value -is [double]) {
            Write-Host "  Coverage: $value%"
        } elseif ($value.PSObject.Properties) {
            $value.PSObject.Properties | ForEach-Object {
                Write-Host "  $($_.Name): $($_.Value)"
            }
        }
    }
}
