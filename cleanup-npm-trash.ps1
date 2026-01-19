# Cleanup Invalid npm Global Packages
# Removes packages with invalid names (starting with dot) that npm can't uninstall itself

$ErrorActionPreference = 'Stop'

# Multiple possible locations for npm global modules
$modulePaths = @(
    (Join-Path $env:APPDATA "npm\node_modules"),
    (Join-Path $env:USERPROFILE "scoop\persist\nodejs\bin\node_modules"),
    (Join-Path $env:USERPROFILE "scoop\apps\nodejs\current\node_modules")
)

Write-Host "Scanning for invalid npm packages..." -ForegroundColor Cyan

$invalidCount = 0
$scannedCount = 0

foreach ($npmGlobalModules in $modulePaths) {
    if (Test-Path $npmGlobalModules) {
        Write-Host "  Checking: $npmGlobalModules" -ForegroundColor Gray
        $scannedCount++

        # Get all directories starting with a dot at root level (not nested)
        Get-ChildItem $npmGlobalModules -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '.*' -and $_.Name -ne '.bin' -and $_.Name -ne '.github' -and $_.Name -ne '.modules.yaml' } | ForEach-Object {
            $pkgName = $_.Name
            Write-Host "  Removing invalid package: $pkgName" -ForegroundColor Yellow

            try {
                Remove-Item $_.FullName -Recurse -Force -ErrorAction Stop
                $invalidCount++
            }
            catch {
                Write-Host "  Failed to remove: $_" -ForegroundColor Red
            }
        }
    }
}

if ($scannedCount -eq 0) {
    Write-Host "No npm module directories found" -ForegroundColor Yellow
}
elseif ($invalidCount -gt 0) {
    Write-Host "`nRemoved $invalidCount invalid package(s)" -ForegroundColor Green
} else {
    Write-Host "No invalid packages found" -ForegroundColor Green
}
