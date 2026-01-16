# Deploy Script for Windows (Pure PowerShell 7)
# Deploys dotfiles, scripts, and configs to appropriate locations

param(
    [string]$DotfilesDir = "$HOME/dev/github/dotfiles",
    [switch]$SkipConfig
)

$ErrorActionPreference = "Stop"

$DevDir = "$HOME/dev"
$ConfigDir = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { "$HOME/.config" }

function Copy-File {
    param([string]$Src, [string]$Dst)
    if (Test-Path $Src) {
        Copy-Item $Src $Dst -Force
    }
}

function Copy-Files {
    param([string[]]$Files, [string]$DestDir)
    if (!(Test-Path $DestDir)) {
        New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
    }
    foreach ($f in $Files) {
        $Src = Join-Path $DotfilesDir $f
        $Dst = Join-Path $DestDir (Split-Path $f -Leaf)
        Copy-File $Src $Dst
    }
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Windows Dotfiles Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Dotfiles: $DotfilesDir" -ForegroundColor Blue
Write-Host ""

# Ensure ~/dev exists
if (!(Test-Path $DevDir)) {
    New-Item -ItemType Directory -Path $DevDir -Force | Out-Null
}

# Deploy scripts to ~/dev
Write-Host "Deploying scripts to ~/dev..." -ForegroundColor Cyan
Copy-Files @(
    "git-update-repos.sh"
    "git-update-repos.ps1"
    "sync-system-instructions.sh"
    "sync-system-instructions.ps1"
    "update-all.ps1"
) $DevDir

# Make shell scripts executable
$shFiles = @(
    "$DevDir/git-update-repos.sh",
    "$DevDir/sync-system-instructions.sh"
)
foreach ($f in $shFiles) {
    if (Test-Path $f) {
        chmod +x $f
    }
}

Write-Host "  Scripts deployed" -ForegroundColor Green
Write-Host ""

# Deploy configs
if (-not $SkipConfig) {
    Write-Host "Deploying configs..." -ForegroundColor Cyan

    # PowerShell profile
    $PwshProfileDir = if ($env:POWERSHELL_PROFILE_CONFIG) { $env:POWERSHELL_PROFILE_CONFIG } else { "$HOME/Documents/PowerShell" }
    if (Test-Path "$DotfilesDir/Microsoft.PowerShell_profile.ps1") {
        $ProfileDir = "$PwshProfileDir"
        if (!(Test-Path $ProfileDir)) {
            New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null
        }
        Copy-File "$DotfilesDir/Microsoft.PowerShell_profile.ps1" "$ProfileDir/Microsoft.PowerShell_profile.ps1"
        Write-Host "  PowerShell profile" -ForegroundColor Green
    }

    # Git hooks
    $HooksDir = "$ConfigDir/git/hooks"
    if (!(Test-Path $HooksDir)) {
        New-Item -ItemType Directory -Path $HooksDir -Force | Out-Null
    }
    Copy-Files @(
        ".config/git/hooks/pre-commit.ps1"
        ".config/git/hooks/commit-msg.ps1"
    ) $HooksDir

    # Claude configs
    if (Test-Path "$DotfilesDir/.claude") {
        $ClaudeDir = "$HOME/.claude"
        if (!(Test-Path $ClaudeDir)) {
            New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null
        }
        Copy-File "$DotfilesDir/.claude/CLAUDE.md" "$ClaudeDir/CLAUDE.md"
        Copy-File "$DotfilesDir/.claude/quality-check.ps1" "$ClaudeDir/quality-check.ps1"
        if (Test-Path "$DotfilesDir/.claude/hooks") {
            $ClaudeHooksDir = "$ClaudeDir/hooks"
            if (!(Test-Path $ClaudeHooksDir)) {
                New-Item -ItemType Directory -Path $ClaudeHooksDir -Force | Out-Null
            }
            Copy-File "$DotfilesDir/.claude/hooks/post-tool-use.ps1" "$ClaudeHooksDir/post-tool-use.ps1"
        }
    }

    Write-Host "  Configs deployed" -ForegroundColor Green
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "           Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Run from ~/dev:" -ForegroundColor Yellow
Write-Host "  .\sync-system-instructions.ps1"
Write-Host "  .\git-update-repos.ps1"
Write-Host ""
