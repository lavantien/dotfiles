Import-Module Pester
$config = [PesterConfiguration]::Default
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = @(
    'bootstrap.ps1',
    'deploy.ps1',
    'update-all.ps1',
    'backup.ps1',
    'restore.ps1',
    'healthcheck.ps1',
    'uninstall.ps1',
    'git-update-repos.ps1',
    'sync-system-instructions.ps1',
    'update-all-windows.ps1',
    'bootstrap\bootstrap.ps1',
    'bootstrap\lib\common.ps1',
    'bootstrap\lib\version-check.ps1',
    'bootstrap\platforms\windows.ps1',
    'lib\config.ps1',
    'Microsoft.PowerShell_profile.ps1',
    'hooks\git\pre-commit.ps1',
    'hooks\git\commit-msg.ps1',
    'hooks\claude\quality-check.ps1'
)
$config.Run.Path = 'tests\powershell'
$config.Output.Verbosity = 'None'
$config.Run.PassThru = $true
$result = Invoke-Pester -Configuration $config
$coverage = [math]::Round($result.CodeCoverage.CoveragePercent, 1)
Write-Host "PowerShell Coverage: $($coverage)%"
Write-Host "Commands covered: $($result.CodeCoverage.CommandsExecutedCount)"
Write-Host "Commands total: $($result.CodeCoverage.CommandsAnalyzedCount)"
