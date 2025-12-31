# Common functions for bootstrap scripts (PowerShell)
# Cross-platform utilities for logging, platform detection, and command execution

# ============================================================================
# GLOBAL VARIABLES
# ============================================================================
$Script:InstalledPackages = @()
$Script:SkippedPackages = @()
$Script:FailedPackages = @()

# Default options (only set if not already set by the caller)
if (-not (Test-Path variable:Script:Interactive)) { $Script:Interactive = $true }
if (-not (Test-Path variable:Script:DryRun)) { $Script:DryRun = $false }
if (-not (Test-Path variable:Script:Categories)) { $Script:Categories = "full" }

# ============================================================================
# COLORS
# ============================================================================
# Note: PowerShell colors work differently - we use Write-Host with -ForegroundColor

function Write-Color {
    param(
        [string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::White
    )
    Write-Host $Message -ForegroundColor $Color
}

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================
function Write-Info {
    param([string]$Message)
    Write-Color "[INFO] $Message" Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Color "[OK] $Message" Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Error-Msg {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Step {
    param([string]$Message)
    Write-Color "[STEP] $Message" Cyan
}

function Write-Header {
    param([string]$Message)
    Write-Host "`n==== $Message ====`n" -ForegroundColor Cyan -NoNewline
    Write-Host ""
}

function Write-Section {
    param([string]$Message)
    Write-Host "`n$Message" -ForegroundColor Cyan
}

# ============================================================================
# PROGRESS TRACKING
# ============================================================================
function Track-Installed {
    param([string]$Package)
    $Script:InstalledPackages += $Package
}

function Track-Skipped {
    param([string]$Package)
    $Script:SkippedPackages += $Package
}

function Track-Failed {
    param([string]$Package)
    $Script:FailedPackages += $Package
}

function Write-Summary {
    Write-Header "Bootstrap Summary"

    Write-Host "Installed: $($Script:InstalledPackages.Count)" -ForegroundColor Green
    foreach ($pkg in $Script:InstalledPackages) {
        Write-Host "  - $pkg"
    }

    Write-Host "`nSkipped: $($Script:SkippedPackages.Count)" -ForegroundColor Yellow
    foreach ($pkg in $Script:SkippedPackages) {
        Write-Host "  - $pkg"
    }

    if ($Script:FailedPackages.Count -gt 0) {
        Write-Host "`nFailed: $($Script:FailedPackages.Count)" -ForegroundColor Red
        foreach ($pkg in $Script:FailedPackages) {
            Write-Host "  - $pkg"
        }
    }

    Write-Host ""
}

# Clear tracking
function Reset-Tracking {
    $Script:InstalledPackages = @()
    $Script:SkippedPackages = @()
    $Script:FailedPackages = @()
}

# ============================================================================
# COMMAND EXISTENCE CHECK
# ============================================================================
function Test-Command {
    param([string]$Command)

    # Try Get-Command first (PowerShell native)
    $cmd = Get-Command -Name $Command -ErrorAction SilentlyContinue
    if ($cmd) {
        return $true
    }

    # Fallback: try using where.exe for Windows executables
    if ($IsWindows -or $true) {  # Always true on Windows PowerShell
        $null = where.exe $Command 2>$null
        return $?
    }

    return $false
}

# Alias for backwards compatibility
function cmd_exists {
    param([string]$Command)
    Test-Command -Command $Command
}

# ============================================================================
# PLATFORM DETECTION
# ============================================================================
function Get-OSPlatform {
    if ($IsWindows -or ($null -eq $IsWindows -and $env:OS -like "*Windows*")) {
        return "windows"
    }
    elseif ($IsMacOS) {
        return "macos"
    }
    elseif ($IsLinux) {
        return "linux"
    }
    return "unknown"
}

function Get-WindowsVersion {
    return [Environment]::OSVersion.Version
}

# ============================================================================
# CONFIRMATION PROMPT
# ============================================================================
function Read-Confirmation {
    param(
        [string]$Prompt,
        [string]$Default = "n"
    )

    if (-not $Script:Interactive) {
        return $true
    }

    $options = if ($Default -eq "y") { "Y/n" } else { "y/N" }

    while ($true) {
        $response = Read-Host "? $Prompt [$options]"
        $response = $response.Trim().ToLower()

        if ([string]::IsNullOrEmpty($response)) {
            $response = $Default
        }

        switch ($response) {
            { $_ -eq "y" -or $_ -eq "yes" } { return $true }
            { $_ -eq "n" -or $_ -eq "no" } { return $false }
            default { Write-Host "Please answer y or n." }
        }
    }
}

# ============================================================================
# COMMAND EXECUTION WRAPPERS
# ============================================================================
function Invoke-CommandSafe {
    param(
        [string]$Command,
        [switch]$NoOutput
    )

    if ($Script:DryRun) {
        Write-Info "[DRY-RUN] Would execute: $Command"
        return $true
    }

    try {
        if ($NoOutput) {
            Invoke-Expression $Command *> $null
        }
        else {
            Invoke-Expression $Command
        }
        return $?
    }
    catch {
        Write-Warning "Command failed: $Command"
        return $false
    }
}

# Safe install wrapper - continues on failure
function Invoke-SafeInstall {
    param(
        [scriptblock]$InstallFunc,
        [string]$PackageName
    )

    try {
        & $InstallFunc
        return $true
    }
    catch {
        Write-Warning ("Installation failed: {0} (exit: {1})" -f $PackageName, $_.Exception.Message)
        Track-Failed $PackageName
        return $false
    }
}

# ============================================================================
# PATH MANAGEMENT
# ============================================================================
function Add-ToPath {
    param(
        [string]$Path,
        [switch]$User = $true
    )

    $target = if ($User) { "User" } else { "Machine" }
    $currentPath = [Environment]::GetEnvironmentVariable("Path", $target)

    if ($currentPath -notlike "*$Path*") {
        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$Path", $target)
        $env:Path += ";$Path"
        Write-Info "Added to PATH ($target): $Path"
    }
}

function Refresh-Path {
    # Refresh PATH for current session
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

# ============================================================================
# STATE MANAGEMENT
# ============================================================================
$StateFile = Join-Path $env:USERPROFILE ".dotfiles-bootstrap-state"

function Save-State {
    param(
        [string]$Tool,
        [string]$Version
    )

    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    "$Tool|$Version|$timestamp" | Add-Content -Path $StateFile
}

function Get-InstalledState {
    param([string]$Tool)

    if (Test-Path $StateFile) {
        $line = Select-String -Path $StateFile -Pattern "^$Tool\|" |
                Select-Object -Last 1
        if ($line) {
            return ($line.Line -split '\|')[1]
        }
    }
    return $null
}

# ============================================================================
# HELPERS
# ============================================================================
function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Restart-ShellPrompt {
    Write-Host ""
    Write-Host "Please restart your shell or run the following to apply changes:" -ForegroundColor Yellow
    Write-Host ". `$PROFILE" -ForegroundColor Cyan
}

# Functions are automatically available when sourced with '.'
# No Export-ModuleMember needed for dot-sourced files
