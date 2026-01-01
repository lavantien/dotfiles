# Universal Bootstrap Script for Windows
# Installs and configures development environment on Windows 10/11
#
# BRIDGE APPROACH:
#   - Works without config file (uses hardcoded defaults - backward compatible)
#   - Loads config file if present (~/.dotfiles.config.yaml) - forward compatible
#   - Config library is optional - scripts work even if it's missing
#   - Defaults: categories="full", interactive=true, no dry-run
#
# Usage:
#   .\bootstrap.ps1 [options]
#
# Options:
#   -Y                Non-interactive mode (accept all prompts)
#   -DryRun           Show what would be installed without installing
#   -Categories       minimal|sdk|full (default: full)
#   -SkipUpdate       Skip updating package managers first
#   -Help             Show this help

[CmdletBinding()]
param(
    [switch]$Y = $false,
    [switch]$DryRun = $false,
    [string]$Categories = "full",
    [switch]$SkipUpdate = $false
)

# ============================================================================
# SCRIPT SETUP
# ============================================================================
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LibDir = Join-Path $ScriptDir "lib"
$PlatformsDir = Join-Path $ScriptDir "platforms"

# Source library functions
. "$LibDir\common.ps1"
. "$LibDir\version-check.ps1"

# Source config library (optional - for custom configuration)
$ConfigLibPath = Join-Path $ScriptDir "..\lib\config.ps1"
if (Test-Path $ConfigLibPath) {
    . "$ConfigLibPath"
}

# Source platform-specific functions
. "$PlatformsDir\windows.ps1"

# Set global options from parameters
$Script:Interactive = -not $Y
$Script:DryRun = $DryRun
$Script:Categories = $Categories

# ============================================================================
# SHOW HELP
# ============================================================================
function Show-Help {
    Get-Content $ScriptDir\bootstrap.ps1 | Select-String -Pattern '^#' | Select-Object -First 25 | ForEach-Object {
        $_.Line -replace '^# ', ''
    }
}

# ============================================================================
# PHASE 1: FOUNDATION
# ============================================================================
function Install-Foundation {
    Write-Header "Phase 1: Foundation"

    # Ensure Scoop is installed
    Ensure-Scoop

    # Ensure git is installed
    if (-not (Test-Command git)) {
        Write-Step "Installing git..."
        Install-ScoopPackage "git" "" "git"
    }
    else {
        Write-Info "git already installed"
        Track-Skipped "git"
    }

    Write-Success "Foundation complete"
    return $true
}

# ============================================================================
# PHASE 2: CORE SDKS
# ============================================================================
function Install-SDKs {
    if ($Script:Categories -eq "minimal") {
        return $true
    }

    Write-Header "Phase 2: Core SDKs"

    # Node.js
    Install-ScoopPackage "nodejs-lts" "18.0.0" "node"

    # Python
    Install-ScoopPackage "python" "3.9.0" "python"

    # Go
    if ($Script:Categories -ne "minimal") {
        Install-ScoopPackage "go" "1.20.0" "go"
    }

    # Rust
    if ($Script:Categories -eq "full") {
        Install-Rustup
    }

    Write-Success "SDKs installation complete"
    return $true
}

# ============================================================================
# PHASE 3: LANGUAGE SERVERS
# ============================================================================
function Install-LanguageServers {
    if ($Script:Categories -eq "minimal") {
        return $true
    }

    Write-Header "Phase 3: Language Servers"

    # clangd
    Install-ScoopPackage "llvm" "15.0.0" "clangd"

    # gopls (via go install)
    if ((Test-Command go) -and $Script:Categories -eq "full") {
        Install-GoPackage "golang.org/x/tools/gopls@latest" "gopls" "0.14.0"
    }

    # rust-analyzer (via rustup)
    if ($Script:Categories -eq "full") {
        Install-RustAnalyzerComponent
    }

    # pyright (via npm)
    if (Test-Command npm) {
        Install-NpmGlobal "pyright" "pyright" "1.1.300"
    }

    # TypeScript language server (via npm)
    if (Test-Command npm) {
        Install-NpmGlobal "typescript-language-server" "typescript-language-server" "3.0.0"
    }

    # YAML language server (via npm)
    if (Test-Command npm) {
        Install-NpmGlobal "yaml-language-server" "yaml-language-server" "1.0.0"
    }

    Write-Success "Language servers installation complete"
    return $true
}

# ============================================================================
# PHASE 4: LINTERS & FORMATTERS
# ============================================================================
function Install-LintersFormatters {
    if ($Script:Categories -eq "minimal") {
        return $true
    }

    Write-Header "Phase 4: Linters & Formatters"

    # Prettier (via npm)
    if (Test-Command npm) {
        Install-NpmGlobal "prettier" "prettier" "3.0.0"
    }

    # ESLint (via npm)
    if (Test-Command npm) {
        Install-NpmGlobal "eslint" "eslint" "8.50.0"
    }

    # Ruff (via pip)
    if (Test-Command python) {
        Install-PipGlobal "ruff" "ruff" "0.1.0"
    }

    # gup (Go package manager - install first, then use it for other Go tools)
    if ((Test-Command go) -and (-not (Test-Command gup))) {
        Install-GoPackage "nao.vi/gup@latest" "gup" "0.12.0"
    }

    # goimports (via gup if available, otherwise go install)
    if (Test-Command go) {
        Install-GoPackage "golang.org/x/tools/cmd/goimports@latest" "goimports" "0.10.0"
    }

    # golangci-lint
    if (Test-Command go) {
        Install-ScoopPackage "golangci-lint" "1.55.0" "golangci-lint"
    }

    Write-Success "Linters & formatters installation complete"
    return $true
}

# ============================================================================
# PHASE 5: CLI TOOLS
# ============================================================================
function Install-CLITools {
    Write-Header "Phase 5: CLI Tools"

    # Scoop packages to install
    $scoopPackages = @(
        @{Package = "fzf"; MinVersion = "0.40.0"; Cmd = "fzf"},
        @{Package = "zoxide"; MinVersion = "0.9.0"; Cmd = "zoxide"},
        @{Package = "bat"; MinVersion = "0.24.0"; Cmd = "bat"},
        @{Package = "eza"; MinVersion = "0.18.0"; Cmd = "eza"},
        @{Package = "lazygit"; MinVersion = "0.40.0"; Cmd = "lazygit"},
        @{Package = "gh"; MinVersion = "2.40.0"; Cmd = "gh"},
        @{Package = "ripgrep"; MinVersion = "13.0.0"; Cmd = "rg"},
        @{Package = "fd"; MinVersion = "9.0.0"; Cmd = "fd"}
    )

    # Add extra packages for full install
    if ($Script:Categories -eq "full") {
        $scoopPackages += @{Package = "tokei"; MinVersion = "12.0.0"; Cmd = "tokei"}
        $scoopPackages += @{Package = "difftastic"; MinVersion = "0.60.0"; Cmd = "difft"}
    }

    # Install packages
    foreach ($pkg in $scoopPackages) {
        Install-ScoopPackage $pkg.Package $pkg.MinVersion $pkg.Cmd
    }

    Write-Success "CLI tools installation complete"
    return $true
}

# ============================================================================
# PHASE 6: DEPLOY CONFIGURATIONS
# ============================================================================
function Deploy-Configs {
    Write-Header "Phase 6: Deploying Configurations"

    $deployScript = Join-Path $ScriptDir "..\deploy.ps1"

    if (-not (Test-Path $deployScript)) {
        Write-Warning "deploy.ps1 not found at $deployScript"
        return $true
    }

    if ($DryRun) {
        Write-Info "[DRY-RUN] Would run: $deployScript"
        return $true
    }

    Write-Step "Running deploy script..."
    & $deployScript
    Write-Success "Configurations deployed"
    return $true
}

# ============================================================================
# PHASE 7: UPDATE ALL
# ============================================================================
function Update-All {
    Write-Header "Phase 7: Updating All Repositories and Packages"

    $updateScript = Join-Path $ScriptDir "..\update-all.ps1"

    if (-not (Test-Path $updateScript)) {
        Write-Warning "update-all.ps1 not found at $updateScript"
        return $true
    }

    if ($DryRun) {
        Write-Info "[DRY-RUN] Would run: $updateScript"
        return $true
    }

    Write-Step "Running update-all script..."
    & $updateScript
    Write-Success "Update complete"
    return $true
}

# ============================================================================
# MAIN
# ============================================================================
function Main {
    Write-Header "Bootstrap Windows Development Environment"

    Write-Host "Options:"
    Write-Host "  Interactive: $(-not $Y)"
    Write-Host "  Dry Run: $DryRun"
    Write-Host "  Categories: $Script:Categories"
    Write-Host "  Skip Update: $SkipUpdate"
    Write-Host ""

    # Confirm if interactive
    if ($Script:Interactive) {
        if (-not (Read-Confirmation "Proceed with bootstrap?" "n")) {
            Write-Host "Aborted."
            exit 0
        }
    }

    # Run phases
    if (-not (Install-Foundation)) {
        Write-Error-Msg "Foundation installation failed"
        exit 1
    }

    $null = Install-SDKs
    $null = Install-LanguageServers
    $null = Install-LintersFormatters
    $null = Install-CLITools
    $null = Deploy-Configs
    $null = Update-All

    Write-Summary

    if (-not $DryRun) {
        Write-Host "=== Bootstrap Complete ===" -ForegroundColor Green
        Write-Host "Please restart your shell or run: . `$PROFILE" -ForegroundColor Yellow
    }
    else {
        Write-Host "=== Dry Run Complete ===" -ForegroundColor Yellow
        Write-Host "Run without -DryRun to actually install" -ForegroundColor Yellow
    }
}

# ============================================================================
# LOAD USER CONFIGURATION (OPTIONAL)
# ============================================================================

# Only try to load config if the config library was successfully sourced
if (Get-Command Load-DotfilesConfig -ErrorAction SilentlyContinue) {
    $ConfigFile = "$env:USERPROFILE\.dotfiles.config.yaml"

    if (Test-Path $ConfigFile) {
        try {
            Load-DotfilesConfig -ConfigFile $ConfigFile
            Write-Info "Config loaded from $ConfigFile"

            # Override defaults with config values (if config was loaded)
            if ($script:CONFIG_CATEGORIES) {
                $Script:Categories = $script:CONFIG_CATEGORIES
            }
        } catch {
            Write-Warning "Failed to load config file, using defaults"
        }
    }
} else {
    Write-Info "Config library not found, using hardcoded defaults"
}

# Run main
Main
