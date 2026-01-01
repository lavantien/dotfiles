# Uninstall Script - Safely removes dotfiles deployments
# Usage: .\uninstall.ps1 [-DryRun] [-KeepBackups] [-VerifyOnly]

param(
    [switch]$DryRun,
    [switch]$KeepBackups,
    [switch]$VerifyOnly
)

# ============================================================================
# SETUP
# ============================================================================

# Colors
$E = [char]27
$R = "$E[0m"
$GREEN = "$E[32m"
$YELLOW = "$E[33m"
$BLUE = "$E[34m"
$CYAN = "$E[36m"

$deletedCount = 0
$skippedCount = 0

# ============================================================================
# DOTFILES TRACKING
# ============================================================================

# Dotfiles marker file (created during deploy)
$dotfilesMarker = Join-Path $env:USERPROFILE ".dotfiles-installed"

# Files deployed by dotfiles
$dotfilesFiles = @(
    Join-Path $env:USERPROFILE ".bash_aliases"
    Join-Path $env:USERPROFILE ".bashrc"
    Join-Path $env:USERPROFILE ".zshrc"
    Join-Path $env:USERPROFILE ".bash_profile"
    Join-Path $env:USERPROFILE ".gitconfig"
    Join-Path $env:USERPROFILE ".gitignore"
    Join-Path $env:USERPROFILE ".gitattributes"
    Join-Path $env:USERPROFILE ".config\nvim"
    Join-Path $env:USERPROFILE ".config\wezterm"
    Join-Path $env:USERPROFILE ".config\git"
    Join-Path $env:USERPROFILE ".config\powershell"
    Join-Path $env:USERPROFILE "init.lua"
    Join-Path $env:USERPROFILE "wezterm.lua"
    Join-Path $env:USERPROFILE ".aider.conf.yml"
    Join-Path $env:USERPROFILE ".editorconfig"
    Join-Path $env:USERPROFILE ".claude"
)

# ============================================================================
# UNINSTALL FUNCTIONS
# ============================================================================

function Write-Info {
    param([string]$Message)
    Write-Host "${BLUE}[INFO]${R} $Message"
}

function Write-Success {
    param([string]$Message)
    Write-Host "${GREEN}[OK]${R} $Message"
}

function Write-Warning {
    param([string]$Message)
    Write-Host "${YELLOW}[WARN]${R} $Message"
}

function Write-Error {
    param([string]$Message)
    Write-Host "${RED}[ERROR]${R} $Message"
}

# Check if file is a dotfile deployment
function Test-DotfileDeployment {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return $false
    }

    # Check for dotfiles marker
    if (Test-Path $dotfilesMarker) {
        return $true
    }

    # Check for .dotfiles-backup in same directory
    $dir = Split-Path $Path -Parent
    $backupMarker = Join-Path $dir ".dotfiles-backup"
    if (Test-Path $backupMarker) {
        return $true
    }

    return $false
}

# Safe removal with prompt
function Remove-Dotfile {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        Write-Warning "Not found: $Path"
        $script:skippedCount++
        return $false
    }

    if (-not (Test-DotfileDeployment $Path)) {
        Write-Warning "Skipping (not a verified dotfile): $Path"
        $script:skippedCount++
        return $false
    }

    if ($VerifyOnly) {
        Write-Host "${GREEN}[VERIFY]${R} Would remove: $Path"
        $script:deletedCount++
        return $true
    }

    if ($DryRun) {
        Write-Host "${CYAN}[DRY-RUN]${R} Would remove: $Path"
        $script:deletedCount++
        return $true
    }

    # Prompt before removal
    $response = Read-Host "Remove $Path? (yes/no/no-all)" -n 1
    Write-Host ""

    if ($response -match '^[Yy]es$') {
        try {
            Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
            Write-Success "Removed: $Path"
            $script:deletedCount++
            return $true
        } catch {
            Write-Error "Failed to remove: $Path - $_"
            return $false
        }
    } elseif ($response -eq "no-all") {
        # Skip all remaining prompts
        Write-Info "Skipping all prompts for remaining files..."
        return $false
    } else {
        Write-Info "Skipped: $Path"
        $script:skippedCount++
        return $false
    }
}

# ============================================================================
# MAIN UNINSTALL PROCESS
# ============================================================================

Write-Host "${CYAN}========================================${R}"
Write-Host "${CYAN}   Dotfiles Uninstall${R}"
Write-Host "${CYAN}========================================${R}"
Write-Host "${BLUE}Dry Run:${R}        $($DryRun.IsPresent)"
Write-Host "${BLUE}Keep Backups:${R}    $($KeepBackups.IsPresent)"
Write-Host "${BLUE}Verify Only:${R}     $($VerifyOnly.IsPresent)"
Write-Host "${CYAN}========================================${R}`n"

# Verify dotfiles installation
if (-not (Test-Path $dotfilesMarker)) {
    Write-Warning "Dotfiles marker not found: $dotfilesMarker"
    Write-Warning "Cannot verify if files are dotfile deployments"
    Write-Warning "Proceeding with best-effort verification...`n"
}

# Scan for dotfiles deployments
Write-Host "${YELLOW}=== Scanning for Dotfile Deployments ===${R}`n"

foreach ($file in $dotfilesFiles) {
    if (Test-Path $file) {
        Write-Host "${BLUE}Found:${R} $file"
        Remove-Dotfile $file | Out-Null
    }
}

# Remove backup directory (unless -KeepBackups)
if (-not $KeepBackups) {
    $backupDir = Join-Path $env:USERPROFILE ".dotfiles-backup"
    if (Test-Path $backupDir) {
        Write-Host "`n${YELLOW}=== Backup Directory ===${R}"
        if ($VerifyOnly) {
            Write-Host "${GREEN}[VERIFY]${R} Would remove: $backupDir"
            $script:deletedCount++
        } elseif ($DryRun) {
            Write-Host "${CYAN}[DRY-RUN]${R} Would remove: $backupDir"
            $script:deletedCount++
        } else {
            $response = Read-Host "Remove backup directory $backupDir? (yes/no)" -n 1
            Write-Host ""
            if ($response -match '^[Yy]es$') {
                try {
                    Remove-Item -Path $backupDir -Recurse -Force -ErrorAction Stop
                    Write-Success "Removed: $backupDir"
                    $script:deletedCount++
                } catch {
                    Write-Error "Failed to remove: $backupDir - $_"
                }
            } else {
                Write-Info "Kept backup directory"
            }
        }
    }
}

# Remove dotfiles marker if exists
if ((Test-Path $dotfilesMarker) -and (-not $VerifyOnly) -and (-not $DryRun)) {
    Write-Host "`n${YELLOW}=== Cleanup ===${R}"
    try {
        Remove-Item -Path $dotfilesMarker -Force -ErrorAction Stop
        Write-Success "Removed dotfiles marker: $dotfilesMarker"
    } catch {
        Write-Error "Failed to remove marker: $dotfilesMarker - $_"
    }
}

# Print summary
Write-Host "`n${CYAN}========================================${R}"
Write-Host "${CYAN}       Uninstall Summary${R}"
Write-Host "${CYAN}========================================${R}"
Write-Host "${BLUE}Deleted:${R}       $deletedCount"
Write-Host "${YELLOW}Skipped:${R}       $skippedCount"
Write-Host "${BLUE}Date:${R}          $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "${CYAN}========================================${R}`n"

if ((-not $DryRun) -and (-not $VerifyOnly)) {
    Write-Success "Uninstall complete!"
    Write-Host "${YELLOW}Please restart your shell to apply changes${R}"
    Write-Host "${YELLOW}Run .\restore.ps1 to restore from backup if needed${R}"
} else {
    Write-Host ""
    Write-Info "Dry run/verify complete - no files were actually removed"
    Write-Host "${YELLOW}Run without -DryRun and -VerifyOnly to perform actual uninstall${R}"
}

exit 0
