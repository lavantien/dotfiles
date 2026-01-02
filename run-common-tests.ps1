# Direct test execution for uncovered functions
$RepoRoot = "C:\Users\lavantien\dev\github\dotfiles"
$commonLibPath = Join-Path $RepoRoot "bootstrap\lib\common.ps1"

# Source the common library
. $commonLibPath

# Initialize script variables
$Script:DryRun = $false
$Script:Verbose = $false
$Script:Interactive = $false

Write-Host "Testing uncovered functions..." -ForegroundColor Cyan

# Test Write-VerboseInfo
Write-Host "`n1. Testing Write-VerboseInfo..."
$Script:Verbose = $true
Write-VerboseInfo "Test verbose message"
$Script:Verbose = $false
Write-VerboseInfo "Should not show this"

# Test Write-Section
Write-Host "`n2. Testing Write-Section..."
Write-Section "Test Section"

# Test cmd_exists
Write-Host "`n3. Testing cmd_exists..."
$result = cmd_exists "git"
Write-Host "  cmd_exists git: $result"
$result = cmd_exists "nonexistent-xyz-123"
Write-Host "  cmd_exists nonexistent: $result"

# Test Get-WindowsVersion
Write-Host "`n4. Testing Get-WindowsVersion..."
$version = Get-WindowsVersion
Write-Host "  Windows Version: $version"

# Test Read-Confirmation (non-interactive mode)
Write-Host "`n5. Testing Read-Confirmation..."
$Script:Interactive = $false
$result = Read-Confirmation "Continue?"
Write-Host "  Read-Confirmation (non-interactive): $result"

# Test Invoke-CommandSafe
Write-Host "`n6. Testing Invoke-CommandSafe..."
$result = Invoke-CommandSafe "echo test"
Write-Host "  Invoke-CommandSafe success: $result"

# Test Refresh-Path
Write-Host "`n7. Testing Refresh-Path..."
Refresh-Path
Write-Host "  Refresh-Path executed"

# Test Test-Admin
Write-Host "`n8. Testing Test-Admin..."
$isAdmin = Test-Admin
Write-Host "  Is Admin: $isAdmin"

# Test Restart-ShellPrompt
Write-Host "`n9. Testing Restart-ShellPrompt..."
Restart-ShellPrompt

Write-Host "`n=== All tests completed ===" -ForegroundColor Green
