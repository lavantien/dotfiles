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

Write-Host "${BLUE}========================================${R}"
Write-Host "${BLUE}   Universal Update All - Windows${R}"
Write-Host "${BLUE}========================================${R}"

$startTime = Get-Date
$updated = 0
$skipped = 0
$failed = 0

# NPM (Node.js global packages)
Update-Section "NPM (Node.js global packages)"
if (Get-Command npm -ErrorAction SilentlyContinue) {
    try {
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
        npm update -g *> $null
        Update-Success
        $updated++
    } catch {
        Update-Fail "npm"
        $failed++
    }
} else {
    Update-Skip "npm not found"
    $skipped++
}

# YARN (global packages)
Update-Section "YARN (global packages)"
if (Get-Command yarn -ErrorAction SilentlyContinue) {
    try {
        yarn global upgrade
        Update-Success
        $updated++
    } catch {
        Update-Fail "yarn"
        $failed++
    }
} else {
    Update-Skip "yarn not found"
    $skipped++
}

# GUP (Go global packages)
Update-Section "GUP (Go global packages)"
if (Get-Command gup -ErrorAction SilentlyContinue) {
    try {
        gup update
        Update-Success
        $updated++
    } catch {
        Update-Fail "gup"
        $failed++
    }
} else {
    Update-Skip "gup not found"
    $skipped++
}

# CARGO (Rust packages)
Update-Section "CARGO (Rust packages)"
if (Get-Command cargo -ErrorAction SilentlyContinue) {
    if (Get-Command cargo-install-update -ErrorAction SilentlyContinue) {
        try {
            cargo install-update -a
            Update-Success
            $updated++
        } catch {
            Update-Fail "cargo-install-update"
            $failed++
        }
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
    try {
        $tools = dotnet tool list 2>&1 | Select-Object -Skip 2 | Where-Object { $_ -match '\S' } | ForEach-Object {
            if ($_ -match '^\s*(\S+)') {
                $matches[1]
            }
        }
        foreach ($tool in $tools) {
            if ($tool -and $tool -ne 'Package Id') {
                dotnet tool update $tool 2>$null
            }
        }
        Update-Success
        $updated++
    } catch {
        Update-Fail "dotnet tools"
        $failed++
    }
} else {
    Update-Skip "dotnet not found"
    $skipped++
}

# PYTHON PIP
Update-Section "PYTHON PIP"
if (Get-Command pip -ErrorAction SilentlyContinue) {
    try {
        pip install --upgrade pip 2>$null
        $packages = pip list --user --format=freeze 2>$null
        if ($packages) {
            $packages | ForEach-Object {
                if ($_ -match '^([^=]+)==') {
                    $pkg = $matches[1]
                    if ($pkg -notmatch '^(pip|setuptools|wheel)$') {
                        pip install --upgrade --user $pkg 2>$null
                    }
                }
            }
        }
        Update-Success
        $updated++
    } catch {
        Update-Fail "pip"
        $failed++
    }
} else {
    Update-Skip "pip not found"
    $skipped++
}

# PIP3 (alternative)
if (Get-Command pip3 -ErrorAction SilentlyContinue) {
    Update-Section "PYTHON PIP3"
    try {
        pip3 install --upgrade pip 2>$null
        Update-Success
        $updated++
    } catch {
        Update-Fail "pip3"
        $failed++
    }
}

# SCOOP (Windows package manager)
Update-Section "SCOOP"
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    try {
        scoop update *
        Update-Success
        $updated++
    } catch {
        Update-Fail "scoop"
        $failed++
    }
} else {
    Update-Skip "scoop not found"
    $skipped++
}

# WINGET (Windows package manager)
Update-Section "WINGET"
if (Get-Command winget -ErrorAction SilentlyContinue) {
    try {
        winget upgrade --all --accept-source-agreements --accept-package-agreements 2>$null
        Update-Success
        $updated++
    } catch {
        Update-Fail "winget"
        $failed++
    }
} else {
    Update-Skip "winget not found"
    $skipped++
}

# CHOCO (Chocolatey alternative)
Update-Section "CHOCOLATEY"
if (Get-Command choco -ErrorAction SilentlyContinue) {
    try {
        choco upgrade all -y
        Update-Success
        $updated++
    } catch {
        Update-Fail "choco"
        $failed++
    }
} else {
    Update-Skip "choco not found"
    $skipped++
}

# GEM (Ruby packages)
Update-Section "RUBY GEM"
if (Get-Command gem -ErrorAction SilentlyContinue) {
    try {
        gem update --user 2>$null
        Update-Success
        $updated++
    } catch {
        Update-Fail "gem"
        $failed++
    }
} else {
    Update-Skip "gem not found"
    $skipped++
}

# COMPOSER (PHP packages)
Update-Section "COMPOSER (PHP global packages)"
if (Get-Command composer -ErrorAction SilentlyContinue) {
    try {
        composer global update 2>$null
        Update-Success
        $updated++
    } catch {
        Update-Fail "composer"
        $failed++
    }
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
