# Generate code coverage report and badge for the repository
# Automatically runs both bash and PowerShell coverage
param(
    [switch]$UpdateReadme,
    [switch]$Verbose,
    [switch]$SkipBash,
    [TimeSpan]$BashCacheTimeout = [TimeSpan]::FromHours(1)
)

Import-Module Pester

$RepoRoot = Split-Path $PSScriptRoot -Parent

Write-Host "`n=== Code Coverage Report ===`n"

#region Bash Coverage

function Invoke-BashCoverage {
    <#
    .SYNOPSIS
        Runs bash coverage measurement appropriate for the current platform
    .OUTPUTS
        [decimal] The bash coverage percentage
    #>
    Write-Host "Running Bash coverage..."

    # Check if we have recent cached data
    $bashJsonPath = Join-Path $RepoRoot "coverage-bash.json"
    if (Test-Path $bashJsonPath) {
        $bashData = Get-Content $bashJsonPath -Raw | ConvertFrom-Json
        $timestamp = [DateTime]::Parse($bashData.timestamp, [System.Globalization.CultureInfo]::InvariantCulture)
        $age = (Get-Date) - $timestamp

        if ($age -lt $BashCacheTimeout) {
            $coverage = [decimal]$bashData.bash_coverage
            $tool = $bashData.tool
            Write-Host "  Bash: $coverage% (cached from $([math]::Round($age.TotalMinutes)) minutes ago via $tool)"
            return $coverage
        }
        else {
            Write-Host "  Cache expired ($([math]::Round($age.TotalMinutes)) minutes old), re-running..."
        }
    }

    # Determine platform and run appropriate coverage
    # $IsWindows/$IsLinux/$IsMacOS are readonly automatic vars in PS 7+
    $platformIsWindows = if ($PSVersionTable.PSVersion.Major -ge 6) { $IsWindows } else { $true }
    $platformIsLinux = if ($PSVersionTable.PSVersion.Major -ge 6) { $IsLinux } else { $false }
    $platformIsMacOS = if ($PSVersionTable.PSVersion.Major -ge 6) { $IsMacOS } else { $false }

    $coverageScript = if ($platformIsWindows) {
        "coverage-docker.sh"
    }
    elseif ($platformIsLinux -or $platformIsMacOS) {
        "coverage.sh"
    }
    else {
        throw "Unsupported platform"
    }

    $coverageScriptPath = Join-Path $PSScriptRoot $coverageScript

    if (-not (Test-Path $coverageScriptPath)) {
        throw "Coverage script not found: $coverageScriptPath"
    }

    # On Windows, check for Docker
    if ($platformIsWindows) {
        Write-Host "  Checking Docker availability..."
        $dockerCheck = & docker info 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Docker is not running. Please start Docker Desktop to measure bash coverage."
        }
        Write-Host "  Docker is available"
    }

    # Run the bash coverage script
    Write-Host "  Executing: $coverageScript..."
    $bashExe = Get-Command bash -ErrorAction SilentlyContinue
    if (-not $bashExe) {
        throw "bash not found. Please install Git for Windows or WSL."
    }

    $output = & $bashExe.Path $coverageScriptPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Bash coverage failed with exit code $LASTEXITCODE"
    }

    # Parse the output or read the generated JSON
    if (Test-Path $bashJsonPath) {
        $bashData = Get-Content $bashJsonPath -Raw | ConvertFrom-Json
        $coverage = [decimal]$bashData.bash_coverage
        $tool = $bashData.tool
        Write-Host "  Bash: $coverage% (measured via $tool)"
        return $coverage
    }
    else {
        throw "Bash coverage completed but coverage-bash.json was not generated"
    }
}

# Run bash coverage
$bashCoverage = 0.0
$bashMethod = "none"

if ($SkipBash) {
    Write-Host "Bash coverage skipped (use -SkipBash to omit)"
    $bashCoverage = 0.0
    $bashMethod = "skipped"
}
else {
    try {
        $bashCoverage = Invoke-BashCoverage
        $bashMethod = "kcov"
    }
    catch {
        Write-Warning "Bash coverage failed: $_"
        Write-Warning "Proceeding with PowerShell coverage only..."
        $bashCoverage = 0.0
        $bashMethod = "failed"
    }
}

#endregion

#region PowerShell Coverage

Write-Host "Calculating PowerShell coverage..."

$config = [PesterConfiguration]::Default
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = @(
    # Root entry point scripts
    "bootstrap.ps1",
    "deploy.ps1",
    "update-all.ps1",
    "backup.ps1",
    "restore.ps1",
    "healthcheck.ps1",
    "uninstall.ps1",
    "git-update-repos.ps1",
    "sync-system-instructions.ps1",
    "update-all-windows.ps1",
    # Bootstrap internal scripts
    "bootstrap\bootstrap.ps1",
    "bootstrap\lib\common.ps1",
    "bootstrap\lib\version-check.ps1",
    "bootstrap\platforms\windows.ps1",
    # Library scripts
    "lib\config.ps1",
    # Git hooks
    "hooks\git\pre-commit.ps1",
    "hooks\git\commit-msg.ps1",
    "hooks\claude\quality-check.ps1"
)
$config.Run.Path = Join-Path $RepoRoot "tests\powershell"
$config.Run.PassThru = $true
$config.Output.Verbosity = 'None'

$psResult = Invoke-Pester -Configuration $config
$psCoverage = [math]::Round($psResult.CodeCoverage.CoveragePercent, 1)
$commandsExecuted = $psResult.CodeCoverage.CommandsExecutedCount
$commandsAnalyzed = $psResult.CodeCoverage.CommandsAnalyzedCount

Write-Host "  PowerShell: $psCoverage% ($commandsExecuted/$commandsAnalyzed commands)"

#endregion

#region Combined Coverage

# Combined coverage (weighted average by script count)
# Count actual bash scripts and PowerShell scripts for weighting
$bashScriptCount = (Get-ChildItem -Path $RepoRoot -Filter "*.sh" -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch "tests/" -and $_.FullName -notmatch "coverage/" -and $_.FullName -notmatch "\.git" }).Count
$psScriptCount = $config.CodeCoverage.Path.Count

# Calculate weights based on actual script counts
$totalScriptCount = $bashScriptCount + $psScriptCount
if ($totalScriptCount -gt 0) {
    $bashWeight = $bashScriptCount / $totalScriptCount
    $psWeight = $psScriptCount / $totalScriptCount
}
else {
    # Fallback to equal weights if unable to count
    $bashWeight = 0.4
    $psWeight = 0.6
}

$combinedCoverage = [math]::Round(($psCoverage * $psWeight) + ($bashCoverage * $bashWeight), 1)
Write-Host "`n  Combined: $combinedCoverage% (weighted: bash $([math]::Round($bashWeight * 100))%, ps $([math]::Round($psWeight * 100))%)"

#endregion

#region Badge Generation

# Determine badge color (shields.io named colors)
if ($combinedCoverage -ge 80) { $badgeColor = "brightgreen" }
elseif ($combinedCoverage -ge 70) { $badgeColor = "green" }
elseif ($combinedCoverage -ge 60) { $badgeColor = "yellowgreen" }
elseif ($combinedCoverage -ge 50) { $badgeColor = "yellow" }
elseif ($combinedCoverage -ge 40) { $badgeColor = "orange" }
else { $badgeColor = "red" }

# Generate SVG badge
$badgeSvg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="160" height="20" role="img" aria-label="Code coverage: $combinedCoverage%">
  <title>Code coverage: $combinedCoverage%</title>
  <linearGradient id="s" x2="0" y2="100%">
    <stop offset="0%" stop-color="#bbb" stop-opacity=".1"/>
    <stop offset="1%" stop-opacity=".1"/>
    <stop offset="100%" stop-color="#555" stop-opacity=".1"/>
  </linearGradient>
  <g class="nc">
    <rect x="0" width="95" height="20" fill="#555"/>
    <rect x="95" width="65" height="20" fill="#$badgeColor"/>
    <rect width="160" height="20" fill="url(#s)"/>
  </g>
  <g fill="#fff" text-anchor="middle" font-family="Verdana,Geneva,DejaVu Sans,sans-serif" text-rendering="geometricPrecision" font-size="11">
    <text x="48" y="15" fill="#010101" fill-opacity=".3">coverage</text>
    <text x="48" y="14">coverage</text>
    <text x="127" y="15" fill="#010101" fill-opacity=".3">$combinedCoverage%</text>
    <text x="127" y="14">$combinedCoverage%</text>
  </g>
</svg>
"@

# Save badge
$badgePath = Join-Path $RepoRoot "coverage-badge.svg"
$badgeSvg | Out-File $badgePath -Encoding UTF8
Write-Host "`nBadge saved to: $badgePath"

# Save coverage data with actual measured values
$coverageData = @{
    ps_coverage = $psCoverage
    ps_commands_executed = $commandsExecuted
    ps_commands_analyzed = $commandsAnalyzed
    bash_coverage = $bashCoverage
    bash_method = $bashMethod
    combined_coverage = $combinedCoverage
    bash_weight = [math]::Round($bashWeight, 2)
    ps_weight = [math]::Round($psWeight, 2)
    timestamp = Get-Date -Format "o"
} | ConvertTo-Json -Depth 10

$coverageJsonPath = Join-Path $RepoRoot "coverage.json"
$coverageData | Out-File $coverageJsonPath -Encoding UTF8
Write-Host "Coverage data saved to: coverage.json"

#endregion

#region README Update

if ($UpdateReadme) {
    $readmePath = Join-Path $RepoRoot "README.md"
    if (Test-Path $readmePath) {
        $readmeContent = Get-Content $readmePath -Raw

        # Generate shields.io badge URL
        $badgeUrl = "https://img.shields.io/badge/coverage-$([math]::Floor($combinedCoverage))%25-$badgeColor"
        $badgeMarkdown = "![Coverage]($badgeUrl)"

        # Check if coverage badge already exists
        $badgePattern = '!\[Coverage\]\(https://img\.shields\.io/badge/coverage-[^)]+\)'

        if ($readmeContent -match $badgePattern) {
            # Update existing badge
            $readmeContent = $readmeContent -replace $badgePattern, "![Coverage]($badgeUrl)"
            Write-Host "`nUpdated coverage badge in README.md"
        }
        else {
            # Add badge after the title
            $readmeContent = $readmeContent -replace "(# Universal Dotfiles)`n", "`$1`n$badgeMarkdown `n"
            Write-Host "`nAdded coverage badge to README.md"
        }

        $readmeContent | Out-File $readmePath -Encoding UTF8 -NoNewline
    }
    else {
        Write-Warning "README.md not found at $readmePath"
    }
}

#endregion

Write-Host "`n=== Summary ==="
Write-Host "PowerShell: $psCoverage% ($commandsExecuted/$commandsAnalyzed commands)"
Write-Host "Bash: $bashCoverage% (via $bashMethod)"
Write-Host "Combined: $combinedCoverage%"
