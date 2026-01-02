# Run Pester tests with detailed output
$config = New-PesterConfiguration
$config.Run.Path = 'tests/powershell'
$config.Output.Verbosity = 'Detailed'
$config.Output.StackTraceVerbosity = 'Full'
$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = 'TestResults.xml'
$config.Output.CIFormat = 'Auto'

Invoke-Pester -Configuration $config
