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
if (-not (Test-Path variable:Script:Verbose)) { $Script:Verbose = $false }

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

function Write-VerboseInfo {
    param([string]$Message)
    if ($Script:Verbose) {
        Write-Color "[INFO] $Message" Cyan
    }
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
    param(
        [string]$Name,
        [string]$Description = ""
    )
    if ($Description) {
        $Script:InstalledPackages += "$Name ($Description)"
    } else {
        $Script:InstalledPackages += $Name
    }
}

function Track-Skipped {
    param(
        [string]$Name,
        [string]$Description = ""
    )
    if ($Description) {
        $Script:SkippedPackages += "$Name ($Description)"
    } else {
        $Script:SkippedPackages += $Name
    }
}

function Track-Failed {
    param(
        [string]$Name,
        [string]$Description = ""
    )
    if ($Description) {
        $Script:FailedPackages += "$Name ($Description)"
    } else {
        $Script:FailedPackages += $Name
    }
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

    # Guard against null or empty command
    if ([string]::IsNullOrEmpty($Command)) {
        return $false
    }

    # Try Get-Command first (PowerShell native)
    $cmd = Get-Command -Name $Command -ErrorAction SilentlyContinue
    if ($cmd) {
        return $true
    }

    # Fallback: try using where.exe for Windows executables
    if ($IsWindows -or $true) {  # Always true on Windows PowerShell
        $null = where.exe $Command 2>$null
        if ($?) {
            return $true
        }

        # Additional check: Python Scripts directory (common for pip-installed tools)
        # Check both generic and version-specific paths (e.g., Python\Python313\Scripts)
        $pythonBaseDir = Join-Path $env:APPDATA "Python"
        if (Test-Path $pythonBaseDir) {
            # Check version-specific directories first (Python313\Scripts, Python312\Scripts, etc.)
            $pythonScriptsDirs = @()
            Get-ChildItem $pythonBaseDir -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match "^Python\d+" } |
                ForEach-Object { $pythonScriptsDirs += (Join-Path $_.FullName "Scripts") }

            # Also check the generic Scripts directory
            $pythonScriptsDirs += Join-Path $pythonBaseDir "Scripts"

            foreach ($scriptsDir in $pythonScriptsDirs) {
                if (Test-Path $scriptsDir) {
                    $exePath = Join-Path $scriptsDir "$Command.exe"
                    if (Test-Path $exePath) {
                        return $true
                    }
                }
            }
        }

        # Additional check: User's local bin directories
        $localBins = @(
            "$env:USERPROFILE\.cargo\bin",
            "$env:USERPROFILE\.local\bin",
            "$env:USERPROFILE\.dotnet\tools",
            # Coursier (Scala/Clojure/JVM tool installer) - Windows uses LOCALAPPDATA
            "$env:LOCALAPPDATA\Coursier\data\bin"
        )
        foreach ($binDir in $localBins) {
            if (Test-Path $binDir) {
                # Check for both .exe and .bat (Coursier apps on Windows use .bat)
                $exePath = Join-Path $binDir "$Command.exe"
                $batPath = Join-Path $binDir "$Command.bat"
                if ((Test-Path $exePath) -or (Test-Path $batPath)) {
                    return $true
                }
            }
        }
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

        if ($null -ne $response) {
            $response = $response.Trim().ToLower()
        }

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
        Write-Info "Added to PATH ($target): $Path"
    }

    # Always add to current session PATH if the directory exists
    # This ensures tools are available immediately in the current session
    if (Test-Path $Path) {
        if ($env:Path -notlike "*$Path*") {
            $env:Path += ";$Path"
        }
    }
}

function Refresh-Path {
    # Refresh PATH for current session
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

# Initialize user PATH with all common development tool directories
# This ensures tools installed via package managers are discoverable
function Initialize-UserPath {
    [CmdletBinding()]
    param()

    Write-Step "Ensuring development directories are in PATH..."

    $pathsAdded = 0

    # Common user bin directories for development tools
    $userPaths = @(
        # Cargo (Rust)
        "$env:USERPROFILE\.cargo\bin",
        # .NET tools
        "$env:USERPROFILE\.dotnet\tools",
        # Go (if GOPATH not set or using default)
        "$env:USERPROFILE\go\bin",
        # Scoop (Windows package manager)
        "$env:USERPROFILE\scoop\shims",
        # Coursier (Scala/Clojure/JVM tool installer) - Windows uses LOCALAPPDATA
        "$env:LOCALAPPDATA\Coursier\data\bin",
        # pnpm (Node.js package manager)
        "$env:LOCALAPPDATA\pnpm",
        # npm global (may vary by version)
        "$env:APPDATA\npm"
    )

    # Python pip user packages - check version-specific directories
    $pythonBaseDir = Join-Path $env:APPDATA "Python"
    if (Test-Path $pythonBaseDir) {
        # Find all version-specific Python directories (Python313, Python312, etc.)
        $pythonVersionDirs = Get-ChildItem $pythonBaseDir -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match "^Python\d+" }

        foreach ($versionDir in $pythonVersionDirs) {
            $scriptsPath = Join-Path $versionDir.FullName "Scripts"
            if (Test-Path $scriptsPath) {
                $userPaths += $scriptsPath
            }
        }

        # Also check the generic Scripts directory
        $genericScriptsPath = Join-Path $pythonBaseDir "Scripts"
        if (Test-Path $genericScriptsPath) {
            $userPaths += $genericScriptsPath
        }
    }

    $currentUserPath = [Environment]::GetEnvironmentVariable("Path", "User")

    foreach ($path in $userPaths) {
        if (Test-Path $path) {
            if ($currentUserPath -notlike "*$path*") {
                Add-ToPath -Path $path -User
                $pathsAdded++
            }
        }
    }

    # Refresh current session PATH
    Refresh-Path

    if ($pathsAdded -gt 0) {
        Write-Success "Added $pathsAdded director(y/ies) to PATH"
    }
    else {
        Write-VerboseInfo "All development directories already in PATH"
    }
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
