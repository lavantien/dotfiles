# Restore Script - Restores dotfiles from backup
# Usage: .\restore.ps1 [-BackupDir] "path" [-List] [-DryRun] [-Force] [BackupName]

param(
    [string]$BackupDir = "$env:USERPROFILE\.dotfiles-backup",
    [switch]$List,
    [switch]$DryRun,
    [switch]$Force,
    [Parameter(Position=0)]
    [string]$BackupName
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

# ============================================================================
# RESTORE FUNCTIONS
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

function Show-Backups {
    Write-Host "${CYAN}Available Backups:${R}"
    Write-Host "${CYAN}========================================${R}`n"

    if (-not (Test-Path $BackupDir)) {
        Write-Warning "Backup directory not found: $BackupDir"
        return $false
    }

    $found = $false
    $backups = Get-ChildItem $BackupDir -Directory |
        Where-Object { $_.Name -match '^[0-9]{8}-[0-9]{6}$' } |
        Sort-Object Name -Descending

    foreach ($backup in $backups) {
        $manifestPath = Join-Path $backup.FullName "MANIFEST.txt"
        $found = $true

        Write-Host "`n${BLUE}Backup:${R}   $($backup.Name)"
        Write-Host "${BLUE}Path:${R}     $($backup.FullName)"

        # Show manifest info
        if (Test-Path $manifestPath) {
            Write-Host "${BLUE}Details:${R}"
            Get-Content $manifestPath | ForEach-Object { Write-Host "    $_" }
        }
    }

    if (-not $found) {
        Write-Warning "No backups found in $BackupDir"
        return $false
    }

    return $true
}

function Confirm-Restore {
    param([string]$Target)

    if ($Force) {
        return $true
    }

    Write-Host "${YELLOW}WARNING: This will overwrite your current configurations!${R}"
    Write-Host "${YELLOW}Target: $Target${R}`n"
    $response = Read-Host "Continue? (yes/no)"

    if ($response -match '^[Yy]es$') {
        return $true
    } else {
        Write-Info "Restore cancelled"
        exit 0
    }
}

function Restore-File {
    param(
        [string]$Source,
        [string]$Destination
    )

    if (-not (Test-Path $Source)) {
        Write-Warning "Source not found (skipping): $Source"
        return $false
    }

    if ($DryRun) {
        Write-Host "  ${CYAN}[DRY-RUN]${R} Would restore: $Source → $Destination"
        return $true
    }

    # Create destination directory if needed
    $destDir = Split-Path $Destination -Parent
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    # Backup existing file first
    if (Test-Path $Destination) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupExisting = "$Destination.dotfiles-backup-$timestamp"
        Copy-Item -Path $Destination -Destination $backupExisting -Recurse -Force
        Write-Info "Backed up existing: $Destination → $backupExisting"
    }

    # Restore file
    try {
        Copy-Item -Path $Source -Destination $Destination -Recurse -Force -ErrorAction Stop
        Write-Success "Restored: $Source → $Destination"
        return $true
    } catch {
        Write-Error "Failed to restore: $Source → $Destination - $_"
        return $false
    }
}

# ============================================================================
# MAIN RESTORE PROCESS
# ============================================================================

# List backups and exit if -List
if ($List) {
    Show-Backups
    exit $LASTEXITCODE
}

# If no backup specified, prompt user
if (-not $BackupName) {
    Write-Host "${CYAN}Select a backup to restore:${R}"
    $result = Show-Backups

    if (-not $result) {
        exit 1
    }

    Write-Host "`n"
    $BackupName = Read-Host "Enter backup name (or 'cancel')"

    if ($BackupName -eq "cancel") {
        Write-Info "Restore cancelled"
        exit 0
    }
}

# Validate backup exists
$restorePath = Join-Path $BackupDir $BackupName
if (-not (Test-Path $restorePath)) {
    Write-Error "Backup not found: $restorePath"
    exit 1
}

Write-Host "${CYAN}========================================${R}"
Write-Host "${CYAN}   Dotfiles Restore${R}"
Write-Host "${CYAN}========================================${R}"
Write-Host "${BLUE}From:${R}      $restorePath"
Write-Host "${BLUE}Dry Run:${R}   $($DryRun.IsPresent)"
Write-Host "${BLUE}Force:${R}     $($Force.IsPresent)"
Write-Host "${CYAN}========================================${R}`n"

# Confirm restore
Confirm-Restore $restorePath
Write-Host ""

# Read manifest if available
$manifestPath = Join-Path $restorePath "MANIFEST.txt"
if (Test-Path $manifestPath) {
    Write-Host "${YELLOW}Backup Manifest:${R}"
    Get-Content $manifestPath | ForEach-Object { Write-Host $_ }
    Write-Host ""
}

$restoredCount = 0

# Restore shell configs
Write-Host "${YELLOW}=== Restoring Shell Configs ===${R}"
$bashrcPath = Join-Path $restorePath "bashrc"
if (Test-Path $bashrcPath) {
    if (Restore-File $bashrcPath "$env:USERPROFILE\.bashrc") { $restoredCount++ }
}
$bashAliasesPath = Join-Path $restorePath "bash_aliases"
if (Test-Path $bashAliasesPath) {
    if (Restore-File $bashAliasesPath "$env:USERPROFILE\.bash_aliases") { $restoredCount++ }
}
$zshrcPath = Join-Path $restorePath "zshrc"
if (Test-Path $zshrcPath) {
    if (Restore-File $zshrcPath "$env:USERPROFILE\.zshrc") { $restoredCount++ }
}
$bashProfilePath = Join-Path $restorePath "bash_profile"
if (Test-Path $bashProfilePath) {
    if (Restore-File $bashProfilePath "$env:USERPROFILE\.bash_profile") { $restoredCount++ }
}

# Restore git configs
Write-Host "${YELLOW}=== Restoring Git Configs ===${R}"
$gitconfigPath = Join-Path $restorePath "gitconfig"
if (Test-Path $gitconfigPath) {
    if (Restore-File $gitconfigPath "$env:USERPROFILE\.gitconfig") { $restoredCount++ }
}
$gitignorePath = Join-Path $restorePath "gitignore"
if (Test-Path $gitignorePath) {
    if (Restore-File $gitignorePath "$env:USERPROFILE\.gitignore") { $restoredCount++ }
}
$gitattributesPath = Join-Path $restorePath "gitattributes"
if (Test-Path $gitattributesPath) {
    if (Restore-File $gitattributesPath "$env:USERPROFILE\.gitattributes") { $restoredCount++ }
}

# Restore Neovim configs
Write-Host "${YELLOW}=== Restoring Neovim Configs ===${R}"
$nvimConfigPath = Join-Path $restorePath "nvim-config"
if (Test-Path $nvimConfigPath) {
    if (Restore-File $nvimConfigPath "$env:USERPROFILE\.config\nvim") { $restoredCount++ }
}
$initLuaPath = Join-Path $restorePath "init.lua"
if (Test-Path $initLuaPath) {
    if (Restore-File $initLuaPath "$env:USERPROFILE\.config\nvim\init.lua") { $restoredCount++ }
}
$initLuaRootPath = Join-Path $restorePath "init.lua-root"
if (Test-Path $initLuaRootPath) {
    if (Restore-File $initLuaRootPath "$env:USERPROFILE\init.lua") { $restoredCount++ }
}

# Restore other editor configs
Write-Host "${YELLOW}=== Restoring Editor Configs ===${R}"
$vimrcPath = Join-Path $restorePath "vimrc"
if (Test-Path $vimrcPath) {
    if (Restore-File $vimrcPath "$env:USERPROFILE\.vimrc") { $restoredCount++ }
}
$vimPath = Join-Path $restorePath "vim"
if (Test-Path $vimPath) {
    if (Restore-File $vimPath "$env:USERPROFILE\.vim") { $restoredCount++ }
}

# Restore terminal configs
Write-Host "${YELLOW}=== Restoring Terminal Configs ===${R}"
$weztermLuaPath = Join-Path $restorePath "wezterm.lua"
if (Test-Path $weztermLuaPath) {
    if (Restore-File $weztermLuaPath "$env:USERPROFILE\.config\wezterm\wezterm.lua") { $restoredCount++ }
}
$weztermLuaRootPath = Join-Path $restorePath "wezterm.lua-root"
if (Test-Path $weztermLuaRootPath) {
    if (Restore-File $weztermLuaRootPath "$env:USERPROFILE\wezterm.lua") { $restoredCount++ }
}

# Restore PowerShell configs
Write-Host "${YELLOW}=== Restoring PowerShell Configs ===${R}"
$powerShellPath = Join-Path $restorePath "PowerShell"
if (Test-Path $powerShellPath) {
    $docsPath = [Environment]::GetFolderPath("MyDocuments")
    if (Restore-File $powerShellPath "$docsPath\PowerShell") { $restoredCount++ }
}

# Restore tool configs
Write-Host "${YELLOW}=== Restoring Tool Configs ===${R}"
$aiderConfPath = Join-Path $restorePath "aider.conf.yml"
if (Test-Path $aiderConfPath) {
    if (Restore-File $aiderConfPath "$env:USERPROFILE\.aider.conf.yml") { $restoredCount++ }
}
$editorconfigPath = Join-Path $restorePath "editorconfig"
if (Test-Path $editorconfigPath) {
    if (Restore-File $editorconfigPath "$env:USERPROFILE\.editorconfig") { $restoredCount++ }
}

# Restore SSH config
Write-Host "${YELLOW}=== Restoring SSH Configs ===${R}"
$sshConfigPath = Join-Path $restorePath "ssh-config"
if (Test-Path $sshConfigPath) {
    if (Restore-File $sshConfigPath "$env:USERPROFILE\.ssh\config") { $restoredCount++ }
}

# Restore Claude configs
Write-Host "${YELLOW}=== Restoring Claude Configs ===${R}"
$claudeConfigPath = Join-Path $restorePath "claude-config"
if (Test-Path $claudeConfigPath) {
    if (Restore-File $claudeConfigPath "$env:USERPROFILE\.claude") { $restoredCount++ }
}

# Print summary
Write-Host "`n${CYAN}========================================${R}"
Write-Host "${CYAN}       Restore Summary${R}"
Write-Host "${CYAN}========================================${R}"
Write-Host "${BLUE}From:${R}       $restorePath"
Write-Host "${BLUE}Restored:${R}   $restoredCount files"
Write-Host "${BLUE}Date:${R}       $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "${CYAN}========================================${R}`n"

if (-not $DryRun) {
    Write-Success "Restore complete!"
    Write-Host "${YELLOW}Please restart your shell to apply changes${R}"
} else {
    Write-Host ""
    Write-Info "Dry run complete - no files were actually restored"
    Write-Host "${YELLOW}Run without -DryRun to perform actual restore${R}"
}

exit 0
