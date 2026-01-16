# Cleanup Script: Remove individual Scoop app paths from User PATH
# Scoop uses shims directory only - individual app paths are redundant
# EXCEPTION: nodejs-lts is kept for npm compatibility

$ErrorActionPreference = 'Stop'

# Get current User PATH
$currentUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
$pathEntries = $currentUserPath -split ';'

# Find and remove scoop app paths (keep only shims and nodejs-lts)
$scoopPattern = "\\scoop\\apps\\(?!nodejs-lts\\)[^\\]+\\current"
$cleanedPaths = $pathEntries | Where-Object {
    $_ -notmatch $scoopPattern
} | Where-Object {
    $_ -ne ''
}

# Rebuild PATH
$newPath = $cleanedPaths -join ';'

# Show what would be removed
$removedCount = $pathEntries.Count - $cleanedPaths.Count
Write-Host "Found $removedCount scoop app path(s) to remove:" -ForegroundColor Yellow
$pathEntries | Where-Object { $_ -match $scoopPattern } | ForEach-Object {
    Write-Host "  - $_" -ForegroundColor DarkYellow
}

# Confirm
$confirm = Read-Host "Remove these paths? (y/N)"
if ($confirm -eq 'y' -or $confirm -eq 'Y') {
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "Done! Restart your shell for changes to take effect." -ForegroundColor Green
    Write-Host "Removed $removedCount path(s). Added back: scoop\shims (if not present)." -ForegroundColor Cyan
} else {
    Write-Host "Cancelled." -ForegroundColor Yellow
}
