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
    param([string]$Src, [string]$Dst, [switch]$Verbose)
    if (Test-Path $Src) {
        if ($Verbose) {
            $srcTime = (Get-Item $Src).LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
            $dstExisted = Test-Path $Dst
            $dstTime = if ($dstExisted) { (Get-Item $Dst).LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss") } else { "N/A" }
            Write-Host "    Copying: $(Split-Path $Src -Leaf)" -ForegroundColor DarkGray
            Write-Host "      src: $srcTime" -ForegroundColor DarkGray
            Write-Host "      dst: $dstTime" -ForegroundColor DarkGray
        }
        Copy-Item $Src $Dst -Force
        if ($Verbose) {
            $newDstTime = (Get-Item $Dst).LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
            Write-Host "      -> $newDstTime" -ForegroundColor DarkGray
        }
    }
}

function Copy-Files {
    param([string[]]$Files, [string]$DestDir, [switch]$Verbose)
    if (!(Test-Path $DestDir)) {
        New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
    }
    foreach ($f in $Files) {
        $Src = Join-Path $DotfilesDir $f
        $Dst = Join-Path $DestDir (Split-Path $f -Leaf)
        Copy-File $Src $Dst -Verbose:$Verbose
    }
}

function Patch-ClaudeLspMarketplace {
    $MarketplaceJson = "$HOME/.claude/plugins/marketplaces/claude-plugins-official/.claude-plugin/marketplace.json"

    if (!(Test-Path $MarketplaceJson)) {
        Write-Host "  Claude LSP marketplace (not installed, skipping)" -ForegroundColor Cyan
        return
    }

    $Json = Get-Content $MarketplaceJson -Raw
    $Patched = $false

    # LSP servers that need cmd.exe wrapper (installed via npm)
    # We look for the command field and replace it along with the args field
    $NpmLsps = @(
        @{Name = "typescript"; CmdFile = "typescript-language-server.cmd"}
        @{Name = "pyright"; CmdFile = "pyright-langserver.cmd"}
        @{Name = "intelephense"; CmdFile = "intelephense.cmd"}
    )

    foreach ($Lsp in $NpmLsps) {
        # Find the LSP entry: "typescript": { ... "command": "..." ... "args": [...] ... }
        $Pattern = '"' + $Lsp.Name + '"\s*:\s*\{[^}]*?"command"\s*:\s*"[^"]*"[^}]*?"args"\s*:\s*\[([^\]]*(?:\[[^\]]*\][^\]]*)*)*\]'

        if ($Json -match $Pattern) {
            $LspSection = $Matches[0]

            # Check if already patched
            $CmdPattern = '"command"\s*:\s*"cmd\.exe"'
            $ArgsPattern = '"args"\s*:\s*\["/c"\s*,\s*"' + [regex]::Escape($Lsp.CmdFile) + '"'
            if ($LspSection -match $CmdPattern -and $LspSection -match $ArgsPattern) {
                continue
            }

            # Patch: replace command and args
            $PatchedCommand = '"command": "cmd.exe"'
            $PatchedArgs = '"args": ["/c", "' + $Lsp.CmdFile + '", "--stdio"]'
            $NewSection = $LspSection -replace '"command"\s*:\s*"[^"]*"', $PatchedCommand
            $NewSection = $NewSection -replace '"args"\s*:\s*\[.+\]', $PatchedArgs
            $Json = $Json.Replace($LspSection, $NewSection)
            $Patched = $true
        }
    }

    if ($Patched) {
        Set-Content $MarketplaceJson $Json -NoNewline
        Write-Host "  Claude LSP marketplace (patched)" -ForegroundColor Green
    } else {
        Write-Host "  Claude LSP marketplace (up to date)" -ForegroundColor Cyan
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
) $DevDir -Verbose

# Make shell scripts executable (only if running in WSL/Git Bash context)
$shFiles = @(
    "$DevDir/git-update-repos.sh",
    "$DevDir/sync-system-instructions.sh"
)
$chmodCmd = Get-Command chmod -ErrorAction SilentlyContinue
if ($chmodCmd -and $chmodCmd.Source -notmatch "scoop") {
    foreach ($f in $shFiles) {
        if (Test-Path $f) {
            chmod +x $f 2>$null
        }
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

        # Ensure mcp section exists and is an object (not scalar from previous bad merge)
        if ($null -eq $ExistingConfig.mcp) {
            $ExistingConfig | Add-Member -NotePropertyName "mcp" -NotePropertyValue @{}
        } elseif ($ExistingConfig.mcp -isnot [PSCustomObject] -and $ExistingConfig.mcp -isnot [hashtable]) {
            $ExistingConfig.PSObject.Properties.Remove("mcp")
            $ExistingConfig | Add-Member -NotePropertyName "mcp" -NotePropertyValue @{}
        }

        # Helper function to compare objects
        function Compare-Property {
            param($Existing, $Dotfiles, $PropertyName)

            # Guard: if Existing is not an object (e.g., string, int), treat as unequal
            if ($Existing -isnot [PSCustomObject] -and $Existing -isnot [hashtable]) {
                return $false
            }

            $ExistingValue = $Existing.$PropertyName
            $DotfilesValue = $Dotfiles.$PropertyName

            # Handle nested objects
            if ($DotfilesValue -is [PSCustomObject]) {
                if ($null -eq $ExistingValue) { return $false }
                if ($ExistingValue -isnot [PSCustomObject]) { return $false }
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
            } elseif ($ExistingConfig.mcp.$ServerName -isnot [PSCustomObject] -and $ExistingConfig.mcp.$ServerName -isnot [hashtable]) {
                # Existing entry is a scalar (malformed), replace it entirely using Add-Member
                $ExistingConfig.mcp.PSObject.Properties.Remove($ServerName)
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

    # Patch Claude LSP marketplace for Windows npm-installed servers
    Patch-ClaudeLspMarketplace
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "           Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Run from ~/dev:" -ForegroundColor Yellow
Write-Host "  .\sync-system-instructions.ps1"
Write-Host "  .\git-update-repos.ps1"
Write-Host ""
