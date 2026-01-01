# Universal Update All Script - Windows (PowerShell)
# Updates all package managers and tools

$ErrorActionPreference = 'Continue'

# Colors
$E = [char]27
$R = "$E[0m"
$GREEN = "$E[32m"
$YELLOW = "$E[33m"
$BLUE = "$E[34m"
$CYAN = "$E[36m"

function Update-Section {
    param([string]$Message)
    Write-Host "`n${CYAN}[$(Get-Date -Format 'HH:mm:ss')]${R} ${BLUE}$Message${R}"
}

function Update-Success {
    param([string]$Message = "Done")
    Write-Host "${GREEN}✓ $Message${R}"
}

function Update-Skip {
    param([string]$Reason)
    Write-Host "${YELLOW}⊘ Skipped: $Reason${R}"
}

function Update-Fail {
    param([string]$Message)
    Write-Host "${YELLOW}✗ Failed: $Message${R}"
}

# ============================================================================
# ERROR HANDLING & TIMEOUTS
# ============================================================================

# Check if any package managers are available
function Test-Prerequisites {
    $hasManager = $false

    Write-Host "`n${CYAN}Checking prerequisites...${R}"

    # Check for package managers
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        $hasManager = $true
        Write-Host "${GREEN}✓ Scoop found${R}"
    }

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $hasManager = $true
        Write-Host "${GREEN}✓ winget found${R}"
    }

    if (Get-Command choco -ErrorAction SilentlyContinue) {
        $hasManager = $true
        Write-Host "${GREEN}✓ Chocolatey found${R}"
    }

    if (Get-Command npm -ErrorAction SilentlyContinue) {
        $hasManager = $true
        Write-Host "${GREEN}✓ npm found${R}"
    }

    if (Get-Command pip -ErrorAction SilentlyContinue) {
        $hasManager = $true
        Write-Host "${GREEN}✓ pip found${R}"
    }

    if (Get-Command go -ErrorAction SilentlyContinue) {
        $hasManager = $true
        Write-Host "${GREEN}✓ Go found${R}"
    }

    if (Get-Command cargo -ErrorAction SilentlyContinue) {
        $hasManager = $true
        Write-Host "${GREEN}✓ Cargo found${R}"
    }

    if (Get-Command dotnet -ErrorAction SilentlyContinue) {
        $hasManager = $true
        Write-Host "${GREEN}✓ dotnet found${R}"
    }

    if (Get-Command gem -ErrorAction SilentlyContinue) {
        $hasManager = $true
        Write-Host "${GREEN}✓ Gem found${R}"
    }

    if (-not $hasManager) {
        Write-Host "`n${RED}Error: No package managers found!${R}"
        Write-Host "${YELLOW}Please install a package manager (scoop, winget, npm, etc.)${R}"
        exit 1
    }

    Write-Host ""
}

# Run command with timeout
# Usage: Invoke-WithTimeout [-Timeout] 300 -Command "command"
function Invoke-WithTimeout {
    param(
        [int]$Timeout = 300,  # Default 5 minutes
        [string]$Command
    )

    # PowerShell has built-in job-based timeout
    $job = Start-Job -ScriptBlock ([scriptblock]::Create($Command)) -Name "TimeoutJob"

    $completed = Wait-Job $job -Timeout $Timeout

    if (-not $completed) {
        Stop-Job $job
        Remove-Job $job -Force
        Write-Host "${YELLOW}Command timed out after ${Timeout}s${R}"
        return $false
    }

    $output = Receive-Job $job
    Remove-Job $job -Force

    Write-Output $output
    return $?
}

# Update helper: captures output, detects changes, reports appropriately
function Update-AndReport {
    param([string]$Cmd, [string]$Name)

    $output = Invoke-Expression "$Cmd 2>&1"
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        Update-Fail $Name
        $script:failed++
        return
    }

    # Detect actual changes by looking for indicators and filtering out "already up to date" messages
    $hasChanges = $output | Select-String -Pattern "changed|removed|added|upgraded|updating|installed" | Select-String -Pattern "already|up to date|nothing|no outdated|not in" -NotMatch

    if ($hasChanges) {
        # Show relevant output lines (filter out noisy parts)
        $output | Where-Object { $_ -notmatch '^(npm warn|)$' } | Select-Object -First 20 | ForEach-Object { Write-Host $_ }
        Update-Success $Name
        $script:updated++
    } else {
        Write-Host "${GREEN}✓ Up to date${R}"
        $script:updated++
    }
}

# Update helper for pip (handles list and update loop)
function Update-Pip {
    param([string]$PipCmd, [string]$Name)

    $output = ""
    $changes = 0

    # Upgrade pip first
    $pipOutput = Invoke-Expression "$PipCmd install --upgrade pip 2>&1"
    $output += $pipOutput + "`n"

    # Update user packages only
    $packages = Invoke-Expression "$PipCmd list --user --format=freeze 2>&1" | Where-Object { $_ -notmatch '^(pip|setuptools|wheel)==' }
    foreach ($pkg in $packages) {
        if ($pkg -match '^([^=]+)==') {
            $packageName = $matches[1]
            $pkgOutput = Invoke-Expression "$PipCmd install --upgrade --user $packageName 2>&1"
            $output += $pkgOutput + "`n"
            # Check if package was actually upgraded
            if ($pkgOutput -match "installed|upgraded" -and $pkgOutput -notmatch "already|up to date|not installed|not a satisfied|Requirement already") {
                $changes++
            }
        }
    }

    if ($changes -gt 0) {
        $output | Where-Object { $_ -notmatch '^(Requirement already|)$' } | Select-Object -First 20 | ForEach-Object { Write-Host $_ }
        Update-Success $Name
        $script:updated++
    } else {
        Write-Host "${GREEN}✓ Up to date${R}"
        $script:updated++
    }
}

# Update helper for dotnet tools (handles list and update loop)
function Update-DotnetTools {
    $output = ""
    $changes = 0

    $tools = dotnet tool list 2>&1 | Select-Object -Skip 2 | Where-Object { $_ -match '\S' } | ForEach-Object {
        if ($_ -match '^\s*(\S+)') { $matches[1] }
    }

    foreach ($tool in $tools) {
        if ($tool -and $tool -ne 'Package Id') {
            $toolOutput = dotnet tool update $tool 2>&1
            $output += $toolOutput + "`n"
            # Check if tool was actually upgraded
            if ($toolOutput -match "successfully|updated|installed" -and $toolOutput -notmatch "already|up to date") {
                $changes++
            }
        }
    }

    if ($changes -gt 0) {
        $output | Where-Object { $_ -notmatch 'already up to date' } | Select-Object -First 20 | ForEach-Object { Write-Host $_ }
        Update-Success "dotnet"
        $script:updated++
    } else {
        Write-Host "${GREEN}✓ Up to date${R}"
        $script:updated++
    }
}

Write-Host "${BLUE}========================================${R}"
Write-Host "${BLUE}   Universal Update All - Windows${R}"
Write-Host "${BLUE}========================================${R}"

$startTime = Get-Date
$updated = 0
$skipped = 0
$failed = 0

# Run prerequisite checks
Test-Prerequisites

# NPM (Node.js global packages)
Update-Section "NPM (Node.js global packages)"
if (Get-Command npm -ErrorAction SilentlyContinue) {
    # Clean up invalid packages (names starting with dot from failed installs)
    $npmList = npm list -g --depth=0 2>&1
    if ($npmList -match '\.opencode-ai-') {
        Write-Host "${YELLOW}Cleaning up invalid npm packages...${R}"
        # Get invalid package names and uninstall them
        $invalidPackages = $npmList | Select-String -Pattern '^[\+\`]?\s*\.opencode-ai-\S+' | ForEach-Object {
            $_.ToString().Trim() -replace '^[\+\`]?\s*', ''
        }
        foreach ($pkg in $invalidPackages) {
            if ($pkg -match '\.opencode-ai-') {
                npm uninstall -g "$pkg" *> $null
            }
        }
    }
    Update-AndReport "npm update -g" "npm"
} else {
    Update-Skip "npm not found"
    $skipped++
}

# YARN (global packages)
Update-Section "YARN (global packages)"
if (Get-Command yarn -ErrorAction SilentlyContinue) {
    Update-AndReport "yarn global upgrade" "yarn"
} else {
    Update-Skip "yarn not found"
    $skipped++
}

# GUP (Go global packages)
Update-Section "GUP (Go global packages)"
if (Get-Command gup -ErrorAction SilentlyContinue) {
    Update-AndReport "gup update" "gup"
} else {
    Update-Skip "gup not found"
    $skipped++
}

# CARGO (Rust packages)
Update-Section "CARGO (Rust packages)"
if (Get-Command cargo -ErrorAction SilentlyContinue) {
    if (Get-Command cargo-install-update -ErrorAction SilentlyContinue) {
        Update-AndReport "cargo install-update -a" "cargo"
    } else {
        Update-Skip "cargo-install-update not found (install: cargo install cargo-update)"
        $skipped++
    }
} else {
    Update-Skip "cargo not found"
    $skipped++
}

# DOTNET TOOLS
Update-Section "DOTNET TOOLS"
if (Get-Command dotnet -ErrorAction SilentlyContinue) {
    Update-DotnetTools
} else {
    Update-Skip "dotnet not found"
    $skipped++
}

# PYTHON PIP
Update-Section "PYTHON PIP"
if (Get-Command pip -ErrorAction SilentlyContinue) {
    Update-Pip "pip" "pip"
} else {
    Update-Skip "pip not found"
    $skipped++
}

# PIP3 (alternative)
if (Get-Command pip3 -ErrorAction SilentlyContinue) {
    Update-Section "PYTHON PIP3"
    Update-Pip "pip3" "pip3"
}

# SCOOP (Windows package manager)
Update-Section "SCOOP"
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    Update-AndReport "scoop update *" "scoop"
} else {
    Update-Skip "scoop not found"
    $skipped++
}

# WINGET (Windows package manager)
Update-Section "WINGET"
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Update-AndReport "winget upgrade --all --accept-source-agreements --accept-package-agreements" "winget"
} else {
    Update-Skip "winget not found"
    $skipped++
}

# CHOCO (Chocolatey alternative)
Update-Section "CHOCOLATEY"
if (Get-Command choco -ErrorAction SilentlyContinue) {
    Update-AndReport "choco upgrade all -y" "choco"
} else {
    Update-Skip "choco not found"
    $skipped++
}

# GEM (Ruby packages)
Update-Section "RUBY GEM"
if (Get-Command gem -ErrorAction SilentlyContinue) {
    Update-AndReport "gem update --user 2>&1; if (`$LASTEXITCODE -ne 0) { gem update 2>&1 }" "gem"
} else {
    Update-Skip "gem not found"
    $skipped++
}

# COMPOSER (PHP packages)
Update-Section "COMPOSER (PHP global packages)"
if (Get-Command composer -ErrorAction SilentlyContinue) {
    Update-AndReport "composer global update" "composer"
} else {
    Update-Skip "composer not found"
    $skipped++
}

# SUMMARY
$duration = (Get-Date) - $startTime
Write-Host "`n${BLUE}========================================${R}"
Write-Host "${BLUE}           Summary${R}"
Write-Host "${BLUE}========================================${R}"
Write-Host " ${GREEN}Completed:$R $updated"
Write-Host " ${YELLOW}Skipped:$R $skipped"
if ($failed -gt 0) {
    Write-Host " ${YELLOW}Failed:$R   $failed"
}
Write-Host " ${CYAN}Duration:$R $($duration.ToString('mm\:ss'))"
Write-Host "${BLUE}========================================${R}"

exit 0
