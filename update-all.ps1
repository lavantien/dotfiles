# Native Windows Update All Script
# Updates all package managers and tools on Windows (no WSL, no sudo)
# VERSION POLICY: Always updates to LATEST available versions
#
# NOTE: Verbose mode is the default - all package manager output is shown.
# No quiet/silent flags are used.

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

# Run command directly, showing all output
function Invoke-Command {
    param(
        [string]$Command,
        [string]$Name
    )

    try {
        Invoke-Expression $Command
        $exitCode = $LASTEXITCODE

        if ($exitCode -ne 0) {
            Write-Fail $Name
            $script:failed++
            return $false
        }

        Write-Success $Name
        $script:updated++
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
        return
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
            & $wingetExe upgrade --all --accept-source-agreements --accept-package-agreements
            Write-Success "winget"
            $script:updated++
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
            choco upgrade all -y
            Write-Success "Chocolatey"
            $script:updated++
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
            npm install -g npm@latest

            npm update -g
            Write-Success "npm"
            $script:updated++
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
            pnpm update -g
            Write-Success "pnpm"
            $script:updated++
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
            bun upgrade

            # Check if there are global packages to update
            $globalPackages = bun pm ls -g 2>&1 | Select-String -Pattern "^\w" | Measure-Object
            $hasGlobalPackages = $globalPackages.Count -gt 0

            if ($hasGlobalPackages) {
                # Only run bun update -g if there are global packages
                bun update -g
            }

            Write-Success "bun"
            $script:updated++
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
            yarn global upgrade
            Write-Success "yarn"
            $script:updated++
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
            gup update
            Write-Success "gup"
            $script:updated++
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
                go install all@latest
                Write-Success "go"
                $script:updated++
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
                cargo install-update -a
                Write-Success "cargo"
                $script:updated++
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
            rustup update
            Write-Success "rustup"
            $script:updated++
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
                foreach ($tool in $tools) {
                    $toolName = ($tool -split '\s+')[0]
                    if ($toolName -eq 'Package') { continue }
                    dotnet tool update $toolName
                }
                Write-Success "dotnet"
                $script:updated++
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

    if (Test-Command pip) {
        try {
            # Upgrade pip first
            pip install --upgrade pip

            # Update all packages using the simple one-liner
            pip freeze 2>&1 | ForEach-Object { $_.Split('==')[0] } | ForEach-Object { pip install --upgrade $_ }

            Write-Success "pip"
            $script:updated++
        }
        catch {
            Write-Fail "pip"
            $script:failed++
        }
    }
    else {
        Write-Skip "pip not found"
        $script:skipped++
    }

    # ============================================================================
    # POETRY
    # ============================================================================
    Write-Step "POETRY"
    if (Test-Command poetry) {
        try {
            poetry self update
            Write-Success "poetry"
            $script:updated++
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
    # UV (Python package manager)
    # ============================================================================
    Write-Step "UV"
    if (Test-Command uv) {
        try {
            uv self update
            Write-Success "uv"
            $script:updated++
        }
        catch {
            Write-Fail "uv"
            $script:failed++
        }
    }
    else {
        Write-Skip "uv not found"
        $script:skipped++
    }

    # ============================================================================
    # CLAUDE CODE CLI
    # ============================================================================
    Write-Step "CLAUDE CODE CLI"
    if (Test-Command claude) {
        try {
            # Get version before update
            $versionBefore = claude --version 2>&1 | Select-String -Pattern '\d+\.\d+\.\d+' | Select-Object -First 1
            if ($versionBefore) {
                $versionBefore = $versionBefore.Matches.Value
            }

            # Get latest version from npm registry
            $latestVersion = npm view @anthropic-ai/claude-code version 2>&1

            # Skip if already at latest
            if ($versionBefore -eq $latestVersion) {
                Write-Skip "claude-code already at latest version ($versionBefore)"
                $script:skipped++
            }
            else {
                # On Windows, use bun (npm is deprecated, native installer has bugs)
                if (Test-Command bun) {
                    # Remove old npm package if present
                    bun pm rm -g @anthropic-ai/claude-code 2>$null

                    # Install via bun
                    bun add -g @anthropic-ai/claude-code

                    # Add bun global bin to PATH
                    $bunBin = bun pm bin -g 2>$null
                    if ($bunBin) {
                        Add-ToPath -Path $bunBin -User
                    }

                    # Get version after update
                    $versionAfter = claude --version 2>&1 | Select-String -Pattern '\d+\.\d+\.\d+' | Select-Object -First 1
                    if ($versionAfter) {
                        $versionAfter = $versionAfter.Matches.Value
                    }

                    if ($versionBefore -ne $versionAfter -and $versionAfter) {
                        Write-Success "claude-code ($versionBefore -> $versionAfter)"
                        $script:updated++
                    }
                    else {
                        Write-Skip "claude-code already up to date"
                        $script:updated++
                    }
                }
                else {
                    Write-Skip "bun not found, required for Claude Code updates on Windows"
                    $script:skipped++
                }
            }
        }
        catch {
            Write-Fail "claude-code"
            $script:failed++
        }
    }
    else {
        Write-Skip "claude-code not found"
        $script:skipped++
    }

    # ============================================================================
    # OPENCODE AI CLI
    # ============================================================================
    Write-Step "OPENCODE AI CLI"
    # Check binary directly (not via PATH) since it may not be in PATH yet
    $opencodeExe = Join-Path $env:USERPROFILE ".opencode\bin\opencode.exe"
    if ((Test-Path $opencodeExe) -or (Get-Command opencode -ErrorAction SilentlyContinue)) {
        try {
            # Get version before update
            $versionBefore = & $opencodeExe --version 2>&1 | Select-String -Pattern '\d+\.\d+\.\d+' | Select-Object -First 1
            if ($versionBefore) {
                $versionBefore = $versionBefore.Matches.Value
            }

            # Get latest version from npm registry
            $latestVersion = npm view opencode-ai version 2>&1

            # Skip if already at latest
            if ($versionBefore -eq $latestVersion) {
                Write-Skip "opencode already at latest version ($versionBefore)"
                $script:skipped++
            }
            else {
                # Run the official installer via bash (curl method)
                $output = bash -c "curl -fsSL https://opencode.ai/install | bash" 2>&1
                $installerExitCode = $LASTEXITCODE

                # If installer succeeded, try to get version after update
                # Note: After update, the binary might be replaced, so we need to re-find it
                if ($installerExitCode -eq 0) {
                    $versionAfter = & $opencodeExe --version 2>&1 | Select-String -Pattern '\d+\.\d+\.\d+' | Select-Object -First 1
                    if ($versionAfter) {
                        $versionAfter = $versionAfter.Matches.Value
                    }

                    if ($versionBefore -ne $versionAfter -and $versionAfter) {
                        Write-Success "opencode ($versionBefore -> $versionAfter)"
                        $script:updated++
                    }
                    elseif ($versionAfter) {
                        Write-Skip "opencode already up to date ($versionAfter)"
                        $script:updated++
                    }
                    else {
                        # Installer succeeded but version detection failed
                        # This is likely OK - the binary was probably updated
                        if ($versionBefore) {
                            Write-Success "opencode (updated from $versionBefore, version detection unclear)"
                        } else {
                            Write-Success "opencode (installer completed successfully)"
                        }
                        $script:updated++
                    }
                }
                else {
                    Write-Fail "opencode (installer failed with exit code $installerExitCode)"
                    $script:failed++
                }
            }
        }
        catch {
            Write-Fail "opencode"
            $script:failed++
        }
    }
    else {
        Write-Skip "opencode not found"
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

    return
}

# Run main
Main
