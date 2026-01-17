# Native Windows Update All Script
# Updates all package managers and tools on Windows (no WSL, no sudo)
# VERSION POLICY: Always updates to LATEST available versions

# Don't treat native command stderr as errors with Stop preference
$PSNativeCommandUseErrorActionPreference = $false
$ErrorActionPreference = 'Continue'

# Colors
function Write-Step { Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] $args" -ForegroundColor Cyan }
function Write-Success { Write-Host "  $args" -ForegroundColor Green }
function Write-Skip { Write-Host "  Skipped: $args" -ForegroundColor Yellow }
function Write-Fail { Write-Host "  Failed: $args" -ForegroundColor Yellow }
function Write-Info { Write-Host "  $args" -ForegroundColor Gray }

# Counters
$script:updated = 0
$script:skipped = 0
$script:failed = 0

# Command exists checker
function Test-Command {
    param([string]$Name)

    # Special handling for winget (Windows Store wrapper)
    if ($Name -eq "winget") {
        $wingetPath = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\winget.exe"
        if (Test-Path $wingetPath) {
            # Verify it actually works by trying to get version
            $result = & $wingetPath --version 2>&1
            return $LASTEXITCODE -eq 0
        }
        return $false
    }

    # Standard command detection
    $null = Get-Command $Name -ErrorAction SilentlyContinue
    return $?
}

# Run command and capture output
function Invoke-Update {
    param(
        [string]$Command,
        [string]$Name
    )

    try {
        $output = Invoke-Expression $Command 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -ne 0) {
            Write-Fail $Name
            $script:failed++
            return $false
        }

        # Check for actual changes (filter out "already up to date" messages)
        $changes = $output | Select-String -Pattern 'changed|removed|added|upgraded|installing|updating' -CaseSensitive:$false | Where-Object {
            $_.Line -notmatch 'already|up to date|nothing|no outdated'
        }

        if ($changes) {
            # Show relevant output
            $output | Where-Object { $_ -notmatch '^\s*$' } | Select-Object -First 20 | ForEach-Object { Write-Info $_ }
            Write-Success $Name
            $script:updated++
        }
        else {
            Write-Success "$Name (up to date)"
            $script:updated++
        }
        return $true
    }
    catch {
        Write-Fail $Name
        $script:failed++
        return $false
    }
}

# Main execution
function Main {
    Write-Host "`n========================================" -ForegroundColor Blue
    Write-Host "   Native Windows Update All" -ForegroundColor Blue
    Write-Host "========================================" -ForegroundColor Blue

    $startTime = Get-Date

    # Check prerequisites
    Write-Step "Checking package managers..."
    $hasManager = $false

    if (Test-Command scoop) {
        Write-Success "Scoop"
        $hasManager = $true
    }
    else {
        Write-Skip "Scoop not found"
    }

    if (Test-Command winget) {
        Write-Success "winget"
        $hasManager = $true
    }
    else {
        Write-Skip "winget not found"
    }

    if (Test-Command choco) {
        Write-Success "Chocolatey"
        $hasManager = $true
    }
    else {
        Write-Skip "Chocolatey not found"
    }

    if (-not $hasManager) {
        Write-Host "`nError: No package managers found!" -ForegroundColor Red
        Write-Host "Please install Scoop, winget, or Chocolatey" -ForegroundColor Yellow
        exit 1
    }

    # ============================================================================
    # SCOOP
    # ============================================================================
    Write-Step "SCOOP"
    if (Test-Command scoop) {
        try {
            # Update scoop buckets and all apps in one command (same as manual `scoop update -a`)
            scoop update -a
            Write-Success "scoop"
            $script:updated++
        }
        catch {
            Write-Fail "scoop"
            $script:failed++
        }
    }
    else {
        Write-Skip "Scoop not found"
        $script:skipped++
    }

    # ============================================================================
    # WINGET
    # ============================================================================
    Write-Step "WINGET"
    if (Test-Command winget) {
        try {
            # winget upgrade --all runs interactively with prompts
            # Use --accept-source-agreements --accept-package-agreements to auto-accept
            # Use full path since winget is in WindowsApps which may not be in PATH
            $wingetExe = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\winget.exe"
            Write-Info "Updating all winget packages..."
            $output = & $wingetExe upgrade --all --accept-source-agreements --accept-package-agreements 2>&1

            # Check if anything was updated
            $hasUpdates = $output | Select-String -Pattern 'Installing|Downloading|Successfully installed' -CaseSensitive:$false
            if ($hasUpdates) {
                $output | Where-Object { $_ -match 'Installing|Downloading|Successfully installed' } | Select-Object -First 10 | ForEach-Object { Write-Info $_ }
                Write-Success "winget"
                $script:updated++
            }
            else {
                $noUpdates = $output | Select-String -Pattern 'No updated package|is up to date|No available upgrade' -CaseSensitive:$false
                if ($noUpdates) {
                    Write-Success "winget (up to date)"
                    $script:updated++
                }
                else {
                    Write-Success "winget"
                    $script:updated++
                }
            }
        }
        catch {
            Write-Fail "winget"
            $script:failed++
        }
    }
    else {
        Write-Skip "winget not found"
        $script:skipped++
    }

    # ============================================================================
    # CHOCOLATEY
    # ============================================================================
    Write-Step "CHOCOLATEY"
    if (Test-Command choco) {
        try {
            Write-Info "Updating all Chocolatey packages..."
            $output = choco upgrade all -y 2>&1

            $hasUpdates = $output | Select-String -Pattern 'upgraded|installed|installing' -CaseSensitive:$false | Where-Object {
                $_.Line -notmatch 'can upgrade|packages you can upgrade'
            }

            if ($hasUpdates) {
                $output | Where-Object { $_ -match 'upgraded|installed|installing' } | Select-Object -First 10 | ForEach-Object { Write-Info $_ }
                Write-Success "Chocolatey"
                $script:updated++
            }
            else {
                $noUpdates = $output | Select-String -Pattern 'already installed|up to date|nothing to upgrade' -CaseSensitive:$false
                if ($noUpdates) {
                    Write-Success "choco (up to date)"
                    $script:updated++
                }
                else {
                    Write-Success "Chocolatey"
                    $script:updated++
                }
            }
        }
        catch {
            Write-Fail "Chocolatey"
            $script:failed++
        }
    }
    else {
        Write-Skip "Chocolatey not found"
        $script:skipped++
    }

    # ============================================================================
    # NPM (Node.js global packages)
    # ============================================================================
    Write-Step "NPM (Node.js global packages)"
    if (Test-Command npm) {
        try {
            Write-Info "Updating npm itself..."
            npm install -g npm@latest *> $null

            $output = npm update -g 2>&1
            $hasUpdates = $output | Select-String -Pattern 'added|removed|changed|updated' -CaseSensitive:$false | Where-Object {
                $_.Line -notmatch 'already|audited|checked'
            }

            if ($hasUpdates) {
                $output | Where-Object { $_ -match 'added|removed|changed|updated' } | ForEach-Object { Write-Info $_ }
                Write-Success "npm"
                $script:updated++
            }
            else {
                Write-Success "npm (up to date)"
                $script:updated++
            }
        }
        catch {
            Write-Fail "npm"
            $script:failed++
        }
    }
    else {
        Write-Skip "npm not found"
        $script:skipped++
    }

    # ============================================================================
    # PNPM
    # ============================================================================
    Write-Step "PNPM"
    if (Test-Command pnpm) {
        try {
            Invoke-Update "pnpm update -g" "pnpm"
        }
        catch {
            Write-Fail "pnpm"
            $script:failed++
        }
    }
    else {
        Write-Skip "pnpm not found"
        $script:skipped++
    }

    # ============================================================================
    # BUN (JavaScript runtime and package manager)
    # ============================================================================
    Write-Step "BUN"
    if (Test-Command bun) {
        try {
            # First upgrade bun itself
            $upgradeOutput = & bun upgrade 2>&1
            $exitCode = $LASTEXITCODE

            # Check if there are global packages to update
            $globalPackages = & bun pm ls -g 2>$null | Select-String -Pattern "^\w" | Measure-Object
            $hasGlobalPackages = $globalPackages.Count -gt 0

            if ($hasGlobalPackages) {
                # Only run bun update -g if there are global packages
                $updateOutput = & bun update -g 2>&1
                $updateExitCode = $LASTEXITCODE

                if ($updateExitCode -eq 0) {
                    Write-Success "bun"
                    $script:updated++
                }
                else {
                    # bun update -g can fail if no packages need updating
                    if ($updateOutput -match "No package.json|nothing to update|up to date") {
                        Write-Success "bun (up to date)"
                        $script:updated++
                    }
                    else {
                        Write-Fail "bun" $updateOutput
                        $script:failed++
                    }
                }
            }
            else {
                # No global packages, just report bun upgrade success
                if ($exitCode -eq 0) {
                    Write-Success "bun"
                    $script:updated++
                }
                else {
                    Write-Fail "bun" $upgradeOutput
                    $script:failed++
                }
            }
        }
        catch {
            Write-Fail "bun"
            $script:failed++
        }
    }
    else {
        Write-Skip "bun not found"
        $script:skipped++
    }

    # ============================================================================
    # YARN
    # ============================================================================
    Write-Step "YARN"
    if (Test-Command yarn) {
        try {
            Invoke-Update "yarn global upgrade" "yarn"
        }
        catch {
            Write-Fail "yarn"
            $script:failed++
        }
    }
    else {
        Write-Skip "yarn not found"
        $script:skipped++
    }

    # ============================================================================
    # GUP (Go global packages)
    # ============================================================================
    Write-Step "GUP (Go global packages)"
    if (Test-Command gup) {
        try {
            Invoke-Update "gup update -a" "gup"
        }
        catch {
            Write-Fail "gup"
            $script:failed++
        }
    }
    else {
        Write-Skip "gup not found"
        $script:skipped++
    }

    # ============================================================================
    # GO (direct update)
    # ============================================================================
    Write-Step "GO (update all)"
    if (Test-Command go) {
        if (-not (Test-Command gup)) {
            try {
                Invoke-Update "go install all@latest" "go"
            }
            catch {
                Write-Fail "go"
                $script:failed++
            }
        }
        else {
            Write-Skip "go (using gup instead)"
            $script:skipped++
        }
    }
    else {
        Write-Skip "go not found"
        $script:skipped++
    }

    # ============================================================================
    # CARGO (Rust packages)
    # ============================================================================
    Write-Step "CARGO (Rust packages)"
    if (Test-Command cargo) {
        if (Test-Command cargo-install-update) {
            try {
                Invoke-Update "cargo install-update -a" "cargo"
            }
            catch {
                Write-Fail "cargo"
                $script:failed++
            }
        }
        else {
            Write-Skip "cargo-install-update not found (install: cargo install cargo-update)"
            $script:skipped++
        }
    }
    else {
        Write-Skip "cargo not found"
        $script:skipped++
    }

    # ============================================================================
    # RUSTUP
    # ============================================================================
    Write-Step "RUSTUP"
    if (Test-Command rustup) {
        try {
            Invoke-Update "rustup update" "rustup"
        }
        catch {
            Write-Fail "rustup"
            $script:failed++
        }
    }
    else {
        Write-Skip "rustup not found"
        $script:skipped++
    }

    # ============================================================================
    # DOTNET TOOLS
    # ============================================================================
    Write-Step "DOTNET TOOLS"
    if (Test-Command dotnet) {
        try {
            $tools = dotnet tool list 2>&1 | Select-Object -Skip 2 | Where-Object { $_ -match '^\S+' }
            if ($tools) {
                $changes = 0
                foreach ($tool in $tools) {
                    $toolName = ($tool -split '\s+')[0]
                    if ($toolName -eq 'Package') { continue }

                    $output = dotnet tool update $toolName 2>&1
                    if ($output -match 'successfully|updated|installed') {
                        $changes++
                    }
                }

                if ($changes -gt 0) {
                    Write-Success "dotnet (updated $changes tools)"
                    $script:updated++
                }
                else {
                    Write-Success "dotnet (up to date)"
                    $script:updated++
                }
            }
            else {
                Write-Skip "No dotnet tools installed"
                $script:skipped++
            }
        }
        catch {
            Write-Fail "dotnet"
            $script:failed++
        }
    }
    else {
        Write-Skip "dotnet not found"
        $script:skipped++
    }

    # ============================================================================
    # PIP (Python packages)
    # ============================================================================
    Write-Step "PIP (Python packages)"

    $pythonCmd = $null
    if (Test-Command python) { $pythonCmd = "python" }
    elseif (Test-Command python3) { $pythonCmd = "python3" }
    elseif (Test-Command py) { $pythonCmd = "py" }

    if ($pythonCmd) {
        try {
            # Upgrade pip first
            & $pythonCmd -m pip install --upgrade pip *> $null

            # Get list of user packages
            $packages = & $pythonCmd -m pip list --user --format=freeze 2>&1 | Where-Object { $_ -notmatch '^(pip|setuptools|wheel)==' }

            if ($packages) {
                $changes = 0
                foreach ($pkg in $packages) {
                    $pkgName = ($pkg -split '=')[0]
                    $output = & $pythonCmd -m pip install --upgrade --user $pkgName 2>&1
                    if ($output -match 'installed|upgraded' -and $output -notmatch 'already|Requirement already|up-to-date') {
                        $changes++
                    }
                }

                if ($changes -gt 0) {
                    Write-Success "pip (updated $changes packages)"
                    $script:updated++
                }
                else {
                    Write-Success "pip (up to date)"
                    $script:updated++
                }
            }
            else {
                Write-Skip "No pip packages found"
                $script:skipped++
            }
        }
        catch {
            Write-Fail "pip"
            $script:failed++
        }
    }
    else {
        Write-Skip "Python not found"
        $script:skipped++
    }

    # ============================================================================
    # POETRY
    # ============================================================================
    Write-Step "POETRY"
    if (Test-Command poetry) {
        try {
            Invoke-Update "poetry self update" "poetry"
        }
        catch {
            Write-Fail "poetry"
            $script:failed++
        }
    }
    else {
        Write-Skip "poetry not found"
        $script:skipped++
    }

    # ============================================================================
    # SUMMARY
    # ============================================================================
    $endTime = Get-Date
    $duration = $endTime - $startTime

    Write-Host "`n========================================" -ForegroundColor Blue
    Write-Host "           Summary" -ForegroundColor Blue
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host " Completed: " -NoNewline; Write-Success $script:updated
    Write-Host " Skipped:   " -NoNewline; Write-Skip $script:skipped
    if ($script:failed -gt 0) {
        Write-Host " Failed:    " -NoNewline; Write-Fail $script:failed
    }
    Write-Host " Duration:  " -NoNewline; Write-Info "$($duration.TotalSeconds.ToString('F0'))s"
    Write-Host "========================================" -ForegroundColor Blue

    exit 0
}

# Run main
Main
