# Root-level bootstrap wrapper
# Delegates to bootstrap/bootstrap.ps1 for actual implementation

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BootstrapDir = Join-Path $ScriptDir "bootstrap"

# Check if bootstrap directory exists
if (-not (Test-Path $BootstrapDir)) {
    Write-Error "Error: Bootstrap directory not found at $BootstrapDir"
    exit 1
}

# Delegate to actual bootstrap script
$BootstrapScript = Join-Path $BootstrapDir "bootstrap.ps1"
& $BootstrapScript @args
exit $LASTEXITCODE
