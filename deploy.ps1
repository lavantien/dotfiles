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
        Copy-Item -Path "$DotfilesDir/.claude/*" -Destination $ClaudeDir -Recurse -Force
        Write-Host "  Claude configs" -ForegroundColor Green
    }

    # Register statusline in Claude Code settings.json
    $SettingsFile = "$HOME/.claude/settings.json"
    if (!(Test-Path $SettingsFile)) {
        "{}" | Set-Content $SettingsFile
    }

    $Settings = Get-Content $SettingsFile -Raw | ConvertFrom-Json
    $StatusLinePath = Join-Path $HOME ".claude\statusline.ps1"
    $Settings | Add-Member -NotePropertyName "statusLine" -NotePropertyValue @{
        type = "command"
        command = "pwsh -NoProfile -ExecutionPolicy Bypass -File $StatusLinePath"
    } -Force
    $Settings | ConvertTo-Json -Depth 10 | Set-Content $SettingsFile
    Write-Host "  Statusline registered" -ForegroundColor Green

    # OpenCode config (merge MCP servers)
    $OpencodeConfigDir = "$ConfigDir/opencode"
    if (!(Test-Path $OpencodeConfigDir)) {
        New-Item -ItemType Directory -Path $OpencodeConfigDir -Force | Out-Null
    }
    $OpencodeConfigFile = "$OpencodeConfigDir/opencode.json"
    $DotfilesOpencodeConfig = "$DotfilesDir/.config/opencode/opencode.windows.json"

    if (!(Test-Path $OpencodeConfigFile)) {
        # No existing config, copy from dotfiles
        Copy-Item $DotfilesOpencodeConfig $OpencodeConfigFile -Force
        Write-Host "  OpenCode config (created)" -ForegroundColor Green
    } else {
        # Existing config found, merge MCP servers
        $ExistingConfig = Get-Content $OpencodeConfigFile -Raw | ConvertFrom-Json
        $DotfilesConfig = Get-Content $DotfilesOpencodeConfig -Raw | ConvertFrom-Json

        # Ensure mcp section exists in existing config
        if ($null -eq $ExistingConfig.mcp) {
            $ExistingConfig | Add-Member -NotePropertyName "mcp" -NotePropertyValue @{}
        }

        # Helper function to compare objects
        function Compare-Property {
            param($Existing, $Dotfiles, $PropertyName)

            $ExistingValue = $Existing.$PropertyName
            $DotfilesValue = $Dotfiles.$PropertyName

            # Handle nested objects
            if ($DotfilesValue -is [PSCustomObject]) {
                if ($null -eq $ExistingValue) { return $false }
                foreach ($Prop in $DotfilesValue.PSObject.Properties) {
                    if (!(Compare-Property -Existing $ExistingValue -Dotfiles $DotfilesValue -PropertyName $Prop.Name)) {
                        return $false
                    }
                }
                return $true
            }

            # Handle arrays
            if ($DotfilesValue -is [Array]) {
                if ($null -eq $ExistingValue) { return $false }
                $ExistingJson = $ExistingValue | ConvertTo-Json -Compress
                $DotfilesJson = $DotfilesValue | ConvertTo-Json -Compress
                return $ExistingJson -eq $DotfilesJson
            }

            # Handle simple values
            return "$ExistingValue" -eq "$DotfilesValue"
        }

        # Merge each MCP server from dotfiles
        $MergedCount = 0
        foreach ($Server in $DotfilesConfig.mcp.PSObject.Properties) {
            $ServerName = $Server.Name
            $ServerConfig = $Server.Value

            if ($null -eq $ExistingConfig.mcp.$ServerName) {
                # Server doesn't exist, add it
                $ExistingConfig.mcp | Add-Member -NotePropertyName $ServerName -NotePropertyValue $ServerConfig -Force
                $MergedCount++
            } else {
                # Server exists, check if update needed
                $NeedsUpdate = $false

                foreach ($Prop in $ServerConfig.PSObject.Properties) {
                    $PropName = $Prop.Name
                    if (!(Compare-Property -Existing $ExistingConfig.mcp.$ServerName -Dotfiles $ServerConfig -PropertyName $PropName)) {
                        $ExistingConfig.mcp.$ServerName.$PropName = $ServerConfig.$PropName
                        $NeedsUpdate = $true
                    }
                }

                if ($NeedsUpdate) {
                    $MergedCount++
                }
            }
        }

        if ($MergedCount -gt 0) {
            $ExistingConfig | ConvertTo-Json -Depth 10 | Set-Content $OpencodeConfigFile
            Write-Host "  OpenCode config (merged $MergedCount server(s))" -ForegroundColor Green
        } else {
            Write-Host "  OpenCode config (up to date)" -ForegroundColor Cyan
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
