# Backup Script - Creates timestamped backups of dotfiles
# Usage: .\backup.ps1 [-DryRun] [-Keep N] [-BackupDir] "path"

param(
    [switch]$DryRun,
    [int]$Keep = 5,
    [string]$BackupDir = "$env:USERPROFILE\.dotfiles-backup"
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

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$currentBackup = Join-Path $BackupDir $timestamp

# ============================================================================
# BACKUP FUNCTIONS
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

function Backup-File {
    param(
        [string]$Source,
        [string]$Destination
    )

    if (-not (Test-Path $Source)) {
        Write-Warning "File not found (skipping): $Source"
        return $false
    }

    if ($DryRun) {
        Write-Host "  ${CYAN}[DRY-RUN]${R} Would backup: $Source"
        return $true
    }

    # Create destination directory if needed
    $destDir = Split-Path $Destination -Parent
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    # Copy file/directory
    try {
        Copy-Item -Path $Source -Destination $Destination -Recurse -Force -ErrorAction Stop
        Write-Success "Backed up: $Source"
        return $true
    } catch {
        Write-Error "Failed to backup: $Source - $_"
        return $false
    }
}

function Remove-OldBackups {
    if ($Keep -le 0) {
        return
    }

    Write-Info "Cleaning up old backups (keeping $Keep most recent)..."

    if (-not (Test-Path $BackupDir)) {
        return
    }

    # Get list of backup directories, sorted by name (timestamp)
    $backups = Get-ChildItem $BackupDir -Directory |
        Where-Object { $_.Name -match '^[0-9]{8}-[0-9]{6}$' } |
        Sort-Object Name -Descending

    if ($backups.Count -le $Keep) {
        Write-Info "No old backups to remove (have $($backups.Count), keeping $Keep)"
        return
    }

    # Remove old backups
    $toRemove = $backups | Select-Object -Skip $Keep
    foreach ($oldBackup in $toRemove) {
        if ($DryRun) {
            Write-Host "  ${CYAN}[DRY-RUN]${R} Would remove old backup: $($oldBackup.FullName)"
        } else {
            try {
                Remove-Item -Path $oldBackup.FullName -Recurse -Force -ErrorAction Stop
                Write-Success "Removed old backup: $($oldBackup.FullName)"
            } catch {
                Write-Error "Failed to remove: $($oldBackup.FullName) - $_"
            }
        }
    }
}

function Show-BackupSummary {
    param(
        [string]$BackupPath,
        [int]$FileCount
    )

    $size = if (Test-Path $BackupPath) {
        (Get-ChildItem $BackupPath -Recurse | Measure-Object -Property Length -Sum).Sum
    } else {
        0
    }

    $sizeFormatted = if ($size -gt 1GB) {
        "{0:N2} GB" -f ($size / 1GB)
    } elseif ($size -gt 1MB) {
        "{0:N2} MB" -f ($size / 1MB)
    } elseif ($size -gt 1KB) {
        "{0:N2} KB" -f ($size / 1KB)
    } else {
        "{0:N0} bytes" -f $size
    }

    Write-Host "`n${CYAN}========================================${R}"
    Write-Host "${CYAN}       Backup Summary${R}"
    Write-Host "${CYAN}========================================${R}"
    Write-Host "${BLUE}Location:${R}  $BackupPath"
    Write-Host "${BLUE}Files:${R}     $FileCount"
    Write-Host "${BLUE}Date:${R}      $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host "${BLUE}Size:${R}      $sizeFormatted"
    Write-Host "${CYAN}========================================${R}"
}

# ============================================================================
# MAIN BACKUP PROCESS
# ============================================================================

Write-Host "${CYAN}========================================${R}"
Write-Host "${CYAN}   Dotfiles Backup${R}"
Write-Host "${CYAN}========================================${R}"
Write-Host "${BLUE}Backup Dir:${R} $currentBackup"
Write-Host "${BLUE}Dry Run:${R}    $($DryRun.IsPresent)"
Write-Host "${BLUE}Keep:${R}       $Keep backups"
Write-Host "${CYAN}========================================${R}`n"

# Create backup directory
if (-not $DryRun) {
    New-Item -ItemType Directory -Path $currentBackup -Force | Out-Null
    Write-Success "Created backup directory: $currentBackup"
} else {
    Write-Host "${CYAN}[DRY-RUN]${R} Would create backup directory: $currentBackup"
}
Write-Host ""

$backedUpCount = 0

# Backup shell configs
Write-Host "${YELLOW}=== Shell Configs ===${R}"
if (Backup-File "$env:USERPROFILE\.bashrc" (Join-Path $currentBackup "bashrc")) { $backedUpCount++ }
if (Backup-File "$env:USERPROFILE\.bash_aliases" (Join-Path $currentBackup "bash_aliases")) { $backedUpCount++ }
if (Backup-File "$env:USERPROFILE\.zshrc" (Join-Path $currentBackup "zshrc")) { $backedUpCount++ }
if (Backup-File "$env:USERPROFILE\.bash_profile" (Join-Path $currentBackup "bash_profile")) { $backedUpCount++ }

# Backup git configs
Write-Host "${YELLOW}=== Git Configs ===${R}"
if (Backup-File "$env:USERPROFILE\.gitconfig" (Join-Path $currentBackup "gitconfig")) { $backedUpCount++ }
if (Backup-File "$env:USERPROFILE\.gitignore" (Join-Path $currentBackup "gitignore")) { $backedUpCount++ }
if (Backup-File "$env:USERPROFILE\.gitattributes" (Join-Path $currentBackup "gitattributes")) { $backedUpCount++ }

# Backup Neovim configs
Write-Host "${YELLOW}=== Neovim Configs ===${R}"
if (Backup-File "$env:USERPROFILE\.config\nvim" (Join-Path $currentBackup "nvim-config")) { $backedUpCount++ }
if (Backup-File "$env:USERPROFILE\.config\nvim\init.lua" (Join-Path $currentBackup "init.lua")) { $backedUpCount++ }
if (Backup-File "$env:USERPROFILE\init.lua" (Join-Path $currentBackup "init.lua-root")) { $backedUpCount++ }

# Backup other editor configs
Write-Host "${YELLOW}=== Editor Configs ===${R}"
if (Backup-File "$env:USERPROFILE\.vimrc" (Join-Path $currentBackup "vimrc")) { $backedUpCount++ }
if (Backup-File "$env:USERPROFILE\.vim" (Join-Path $currentBackup "vim")) { $backedUpCount++ }

# Backup terminal configs
Write-Host "${YELLOW}=== Terminal Configs ===${R}"
if (Backup-File "$env:USERPROFILE\.config\wezterm\wezterm.lua" (Join-Path $currentBackup "wezterm.lua")) { $backedUpCount++ }
if (Backup-File "$env:USERPROFILE\wezterm.lua" (Join-Path $currentBackup "wezterm.lua-root")) { $backedUpCount++ }

# Backup PowerShell configs
Write-Host "${YELLOW}=== PowerShell Configs ===${R}"
$docsPath = [Environment]::GetFolderPath("MyDocuments")
if (Test-Path "$docsPath\PowerShell") {
    if (Backup-File "$docsPath\PowerShell" (Join-Path $currentBackup "PowerShell")) { $backedUpCount++ }
}
if (Test-Path "$docsPath\WindowsPowerShell") {
    if (Backup-File "$docsPath\WindowsPowerShell" (Join-Path $currentBackup "WindowsPowerShell")) { $backedUpCount++ }
}

# Backup tool configs
Write-Host "${YELLOW}=== Tool Configs ===${R}"
if (Backup-File "$env:USERPROFILE\.aider.conf.yml" (Join-Path $currentBackup "aider.conf.yml")) { $backedUpCount++ }
if (Backup-File "$env:USERPROFILE\.editorconfig" (Join-Path $currentBackup "editorconfig")) { $backedUpCount++ }

# Backup SSH config
Write-Host "${YELLOW}=== SSH Configs ===${R}"
if (Backup-File "$env:USERPROFILE\.ssh\config" (Join-Path $currentBackup "ssh-config")) { $backedUpCount++ }

# Backup Claude configs
Write-Host "${YELLOW}=== Claude Configs ===${R}"
if (Backup-File "$env:USERPROFILE\.claude" (Join-Path $currentBackup "claude-config")) { $backedUpCount++ }

# Create backup manifest
if (-not $DryRun) {
    $manifest = @"
Timestamp: $([System.DateTimeOffset]::UtcNow.ToString("o"))
Hostname: $env:COMPUTERNAME
User: $env:USERNAME
Files backed up: $backedUpCount
"@
    $manifest | Out-File (Join-Path $currentBackup "MANIFEST.txt") -Encoding UTF8
    Write-Success "Created backup manifest"
}

# Clean up old backups
Remove-OldBackups

# Print summary
if (-not $DryRun) {
    Show-BackupSummary $currentBackup $backedUpCount
    Write-Host ""
    Write-Success "Backup complete!"
    Write-Host "${YELLOW}To restore, run: .\restore.ps1 -BackupDir $currentBackup${R}"
} else {
    Write-Host ""
    Write-Info "Dry run complete - no files were actually backed up"
    Write-Host "${YELLOW}Run without -DryRun to create actual backup${R}"
}

exit 0
