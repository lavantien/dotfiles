# Universal Deploy Script for Windows (PowerShell)
# Auto-detects and deploys appropriate configurations

$ErrorActionPreference = 'Continue'

# Colors
$E = [char]27
$R = "$E[0m"
$GREEN = "$E[32m"
$BLUE = "$E[34m"
$YELLOW = "$E[33m"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "${BLUE}Deploying dotfiles for Windows${R}"
Write-Host "${BLUE}Script directory: $ScriptDir${R}"

# ============================================================================
# COMMON DEPLOYMENT
# ============================================================================
function Deploy-Common {
    Write-Host "${GREEN}Deploying common files...${R}"

    # Create directories
    New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.config" | Out-Null

    # Copy bash aliases (for Git Bash/WSL)
    Copy-Item "$ScriptDir\.bash_aliases" "$env:USERPROFILE\" -Force

    # Copy git config
    Copy-Item "$ScriptDir\.gitconfig" "$env:USERPROFILE\" -Force

    # Copy Neovim config
    if (Test-Path "$ScriptDir\init.lua") {
        New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.config\nvim" | Out-Null
        Copy-Item "$ScriptDir\init.lua" "$env:USERPROFILE\.config\nvim\" -Force
    }

    # Copy lua directory if exists
    if (Test-Path "$ScriptDir\lua") {
        New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.config\nvim" | Out-Null
        Copy-Item -Path "$ScriptDir\lua\*" -Destination "$env:USERPROFILE\.config\nvim\lua\" -Recurse -Force
    }

    # Copy Wezterm config
    if (Test-Path "$ScriptDir\wezterm.lua") {
        New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.config\wezterm" | Out-Null
        Copy-Item "$ScriptDir\wezterm.lua" "$env:USERPROFILE\.config\wezterm\" -Force
    }

    # Copy git clone script
    New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\dev" | Out-Null
    if (Test-Path "$ScriptDir\git-clone-all.sh") {
        Copy-Item "$ScriptDir\git-clone-all.sh" "$env:USERPROFILE\dev\" -Force
    }

    # Copy Aider configs
    if (Test-Path "$ScriptDir\.aider.conf.yml.example") {
        Copy-Item "$ScriptDir\.aider.conf.yml.example" "$env:USERPROFILE\.aider.conf.yml" -Force
    }

    # Copy update-all script
    if (Test-Path "$ScriptDir\update-all.ps1") {
        Copy-Item "$ScriptDir\update-all.ps1" "$env:USERPROFILE\dev\" -Force
    }

    Write-Host "${GREEN}Common files deployed.${R}"
}

# ============================================================================
# GIT HOOKS
# ============================================================================
function Deploy-GitHooks {
    Write-Host "${GREEN}Deploying git hooks...${R}"

    $hooksDir = "$env:USERPROFILE\.config\git\hooks"
    New-Item -ItemType Directory -Force -Path $hooksDir | Out-Null

    # Copy PowerShell hooks
    Copy-Item "$ScriptDir\hooks\git\pre-commit.ps1" "$hooksDir\" -Force
    Copy-Item "$ScriptDir\hooks\git\commit-msg.ps1" "$hooksDir\" -Force

    # Copy bash hooks too (for Git Bash/WSL)
    Copy-Item "$ScriptDir\hooks\git\pre-commit" "$hooksDir\" -Force
    Copy-Item "$ScriptDir\hooks\git\commit-msg" "$hooksDir\" -Force

    # Configure git to use the hooks
    git config --global init.templatedir $hooksDir.Replace('\', '/')
    git config --global core.hooksPath $hooksDir.Replace('\', '/')

    Write-Host "${GREEN}Git hooks deployed to: $hooksDir${R}"
}

# ============================================================================
# CLAUDE CODE HOOKS
# ============================================================================
function Deploy-ClaudeHooks {
    Write-Host "${GREEN}Deploying Claude Code hooks...${R}"

    New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude" | Out-Null
    Copy-Item "$ScriptDir\hooks\claude\quality-check.ps1" "$env:USERPROFILE\.claude\" -Force

    # Copy TDD guard if exists in repo
    if (Test-Path "$ScriptDir\.claude\tdd-guard") {
        New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude\tdd-guard" | Out-Null
        Copy-Item -Path "$ScriptDir\.claude\tdd-guard\*" -Destination "$env:USERPROFILE\.claude\tdd-guard\" -Recurse -Force
    }

    Write-Host "${GREEN}Claude Code hooks deployed to: $env:USERPROFILE\.claude${R}"
    Write-Host "${YELLOW}Add to Claude Code settings.json to enable hooks${R}"
}

# ============================================================================
# POWERSHELL PROFILE
# ============================================================================
function Deploy-PowerShellProfile {
    Write-Host "${GREEN}Deploying PowerShell profile...${R}"

    # PowerShell 7 profile path
    $pwshDir = "$env:USERPROFILE\Documents\PowerShell"
    $legacyDir = "$env:USERPROFILE\Documents\WindowsPowerShell"

    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        New-Item -ItemType Directory -Force -Path $pwshDir | Out-Null
        Copy-Item "$ScriptDir\Microsoft.PowerShell_profile.ps1" "$pwshDir\Microsoft.PowerShell_profile.ps1" -Force
        Write-Host "${GREEN}PowerShell 7 profile deployed${R}"
    }

    if (Test-Path $legacyDir) {
        New-Item -ItemType Directory -Force -Path $legacyDir | Out-Null
        Copy-Item "$ScriptDir\Microsoft.PowerShell_profile.ps1" "$legacyDir\Microsoft.PowerShell_profile.ps1" -Force
        Write-Host "${GREEN}Windows PowerShell (legacy) profile deployed${R}"
    }
}

# ============================================================================
# UPDATE GIT CONFIG FOR WINDOWS
# ============================================================================
function Update-GitConfig {
    Write-Host "${GREEN}Updating .gitconfig for Windows...${R}"

    $gitConfigPath = "$env:USERPROFILE\.gitconfig"
    if (Test-Path $gitConfigPath) {
        $content = Get-Content $gitConfigPath -Raw

        # Update gh credential path for Windows
        if ($content -match 'linuxbrew') {
            # Check if gh is installed via scoop
            if (Get-Command gh -ErrorAction SilentlyContinue) {
                $scoopPath = (Get-Command gh).Source.Replace('\', '/').Replace('C:/c/', '/c/')
                $content = $content -replace '!/home/linuxbrew/\.linuxbrew/bin/gh auth git-credential', "!`"$scoopPath`" auth git-credential"
            }
        }

        $content | Set-Content $gitConfigPath -NoNewline
    }
}

# ============================================================================
# MAIN
# ============================================================================
Deploy-Common
Deploy-GitHooks
Deploy-ClaudeHooks
Deploy-PowerShellProfile
Update-GitConfig

Write-Host "${GREEN}=== Deployment Complete ===${R}"
Write-Host "${YELLOW}Reload your shell to apply changes${R}"
