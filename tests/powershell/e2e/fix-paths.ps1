# Fix paths in E2E test files
$files = Get-ChildItem "$PSScriptRoot\*.ps1"
$oldPattern = 'Split-Path \(Split-Path \$_PSScriptRoot -Parent\) -Parent'
$newPattern = 'Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent'

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw
    $newContent = $content -replace 'Split-Path \(Split-Path \$PSScriptRoot -Parent\) -Parent', 'Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent'
    Set-Content -Path $file.FullName -Value $newContent -NoNewline
}

Write-Host "Paths fixed in E2E test files"
