[xml]$xml = Get-Content coverage-ps.xml
$counters = $xml.report.package.class.method.counter | Where-Object { $_.type -eq 'LINE' }
$covered = ($counters | Measure-Object -Property covered -Sum).Sum
$missed = ($counters | Measure-Object -Property missed -Sum).Sum
$total = $covered + $missed
$coverage = [math]::Round(($covered / $total) * 100, 1)
Write-Host "PowerShell: $coverage% (covered: $covered, missed: $missed, total: $total)"
