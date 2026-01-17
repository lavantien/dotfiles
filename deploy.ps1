# Deploy Script for Windows (Pure PowerShell 7)
# Deploys dotfiles, scripts, and configs to appropriate locations

param(
    [string]$DotfilesDir = "$HOME/dev/github/dotfiles",
    [switch]$SkipConfig
)

$ErrorActionPreference = "Stop"

$DevDir = "$HOME/dev"
$ConfigDir = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { "$HOME/.config" }

# Ensure config directory exists
if (!(Test-Path $ConfigDir)) {
    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
}

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

    # Neovim config
    # Windows uses %LOCALAPPDATA%\nvim (stdpath('config'))
    $NvimConfigDir = Join-Path $env:LOCALAPPDATA "nvim"

    if (Test-Path "$DotfilesDir/.config/nvim/init.lua") {
        if (!(Test-Path $NvimConfigDir)) {
            New-Item -ItemType Directory -Path $NvimConfigDir -Force | Out-Null
        }
        Copy-File "$DotfilesDir/.config/nvim/init.lua" "$NvimConfigDir/init.lua"
        Write-Host "  Neovim config" -ForegroundColor Green
    }

    # Copy lua directory if exists (for modular nvim config)
    if (Test-Path "$DotfilesDir/.config/nvim/lua") {
        $luaDest = Join-Path $NvimConfigDir "lua"
        if (!(Test-Path $luaDest)) {
            New-Item -ItemType Directory -Path $luaDest -Force | Out-Null
        }
        Copy-Item -Path "$DotfilesDir/.config/nvim/lua/*" -Destination $luaDest -Recurse -Force
    }

    # WezTerm config
    # WezTerm uses $HOME/.config/wezterm/wezterm.lua on all platforms including Windows
    if (Test-Path "$DotfilesDir/.config/wezterm/wezterm.lua") {
        $WeztermConfigDir = "$ConfigDir/wezterm"
        if (!(Test-Path $WeztermConfigDir)) {
            New-Item -ItemType Directory -Path $WeztermConfigDir -Force | Out-Null
        }
        Copy-File "$DotfilesDir/.config/wezterm/wezterm.lua" "$WeztermConfigDir/wezterm.lua"
        Write-Host "  WezTerm config" -ForegroundColor Green
    }

    # WezTerm background assets
    if (Test-Path "$DotfilesDir/assets") {
        $assetsDest = Join-Path $env:USERPROFILE "assets"
        if (!(Test-Path $assetsDest)) {
            New-Item -ItemType Directory -Path $assetsDest -Force | Out-Null
        }
        Copy-Item "$DotfilesDir/assets/*" -Destination $assetsDest -Recurse -Force
        Write-Host "  WezTerm background assets" -ForegroundColor Green
    }

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
