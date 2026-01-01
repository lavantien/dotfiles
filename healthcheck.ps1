# Health Check Script - Verifies dotfiles setup
# Usage: .\healthcheck.ps1 [-Verbose] [-Format] "table|json"

param(
    [switch]$Verbose,
    [string]$Format = "table"
)

# ============================================================================
# SETUP
# ============================================================================

# Colors
$E = [char]27
$R = "$E[0m"
$GREEN = "$E[32m"
$YELLOW = "$E[33m"
$BLUE = "$E[34m"
$CYAN = "$E[36m"

# Counters
$totalChecks = 0
$passedChecks = 0
$failedChecks = 0
$warningChecks = 0

# Store results
$checkResults = @()

# ============================================================================
# CHECK FUNCTIONS
# ============================================================================

function Write-Check {
    param([string]$Message)
    Write-Host "${BLUE}[CHECK]${R} $Message"
}

function Write-Pass {
    param([string]$Message)
    Write-Host "${GREEN}[PASS]${R} $Message"
}

function Write-Fail {
    param([string]$Message)
    Write-Host "${RED}[FAIL]${R} $Message"
}

function Write-Warn {
    param([string]$Message)
    Write-Host "${YELLOW}[WARN]${R} $Message"
}

# Record check result
function Add-CheckResult {
    param(
        [string]$Name,
        [string]$Status,
        [string]$Message
    )

    $script:checkResults += [PSCustomObject]@{
        Name = $Name
        Status = $Status
        Message = $Message
    }

    $script:totalChecks++

    switch ($Status) {
        "pass" { $script:passedChecks++ }
        "fail" { $script:failedChecks++ }
        "warn" { $script:warningChecks++ }
    }
}

# Check if command exists
function Test-Command {
    param(
        [string]$Name,
        [string]$Command,
        [string]$MinVersion = "",
        [bool]$Required = $false
    )

    $cmdPath = Get-Command $Command -ErrorAction SilentlyContinue

    if ($cmdPath) {
        if ($MinVersion) {
            try {
                $versionOutput = & $Command --version 2>&1
                if ($versionOutput -match '(\d+\.\d+\.\d+)') {
                    $version = [version]$matches[1]
                    if ($version -lt [version]$MinVersion) {
                        Write-Check $Name
                        Write-Fail "Version $version < $MinVersion"
                        Add-CheckResult -Name $Name -Status "fail" -Message "Version $version (min: $MinVersion)"
                        return $false
                    }
                }
            } catch { }
        }
        Write-Check $Name
        Write-Pass "Found: $Command"
        Add-CheckResult -Name $Name -Status "pass" -Message "Found $Command"
        return $true
    } else {
        if ($Required) {
            Write-Check $Name
            Write-Fail "Not found: $Command"
            Add-CheckResult -Name $Name -Status "fail" -Message "Not found"
            return $false
        } else {
            Write-Check $Name
            Write-Warn "Optional: Not found $Command"
            Add-CheckResult -Name $Name -Status "warn" -Message "Not found"
            return $true
        }
    }
}

# Check if file exists
function Test-File {
    param(
        [string]$Name,
        [string]$Path,
        [bool]$Required = $true
    )

    if (Test-Path $Path) {
        Write-Check $Name
        Write-Pass "Found: $Path"
        Add-CheckResult -Name $Name -Status "pass" -Message "Found at $Path"
        return $true
    } else {
        if ($Required) {
            Write-Check $Name
            Write-Fail "Not found: $Path"
            Add-CheckResult -Name $Name -Status "fail" -Message "Required file not found"
            return $false
        } else {
            Write-Check $Name
            Write-Warn "Optional: Not found $Path"
            Add-CheckResult -Name $Name -Status "warn" -Message "Optional file not found"
            return $true
        }
    }
}

# Check git configuration
function Test-GitConfig {
    param(
        [string]$Name,
        [string]$Key
    )

    $value = git config --global $Key 2>$null

    if ($value) {
        Write-Check $Name
        Write-Pass "Set: $Key = $value"
        Add-CheckResult -Name $Name -Status "pass" -Message "$Key = $value"
        return $true
    } else {
        Write-Check $Name
        Write-Fail "Not set: $Key"
        Add-CheckResult -Name $Name -Status "fail" -Message "Not configured"
        return $false
    }
}

# Check if git hook is installed
function Test-GitHook {
    param(
        [string]$HookName,
        [string]$HookPath
    )

    if ((Test-Path $HookPath) -and (Get-Item $HookPath).Attributes -match 'Executable|Archive') {
        Write-Check "$HookName hook"
        Write-Pass "Installed at: $HookPath"
        Add-CheckResult -Name "$HookName hook" -Status "pass" -Message "Installed at $HookPath"
        return $true
    } else {
        Write-Check "$HookName hook"
        Write-Warn "Not found or not executable: $HookPath"
        Add-CheckResult -Name "$HookName hook" -Status "warn" -Message "Not installed"
        return $false
    }
}

# ============================================================================
# HEALTH CHECKS
# ============================================================================

Write-Host "${CYAN}========================================${R}"
Write-Host "${CYAN}   Dotfiles Health Check${R}"
Write-Host "${CYAN}========================================${R}"
Write-Host "${BLUE}Verbose:${R}   $($Verbose.IsPresent)"
Write-Host "${BLUE}Format:${R}    $Format"
Write-Host "${CYAN}========================================${R}`n"

# Check required tools
Write-Host "${YELLOW}=== Required Tools ===${R}"
Test-Command -Name "Git" -Command "git"
Test-Command -Name "Editor (nvim/vim)" -Command "nvim" -Required $false | Out-Null
if (-not (Get-Command nvim -ErrorAction SilentlyContinue)) {
    Test-Command -Name "Editor (nvim/vim)" -Command "vim" | Out-Null
}

# Check package managers
Write-Host "${YELLOW}=== Package Managers ===${R}"
Test-Command -Name "Scoop" -Command "scoop" -Required $false
Test-Command -Name "npm" -Command "npm" -Required $false
Test-Command -Name "pip" -Command "pip" -Required $false
Test-Command -Name "Go" -Command "go" -Required $false
Test-Command -Name "Cargo" -Command "cargo" -Required $false

# Check CLI tools
Write-Host "${YELLOW}=== CLI Tools ===${R}"
Test-Command -Name "fzf" -Command "fzf" -Required $false
Test-Command -Name "bat" -Command "bat" -Required $false
Test-Command -Name "eza/exa" -Command "eza" -Required $false
if (-not (Get-Command eza -ErrorAction SilentlyContinue)) {
    Test-Command -Name "eza/exa" -Command "exa" -Required $false | Out-Null
}
Test-Command -Name "ripgrep" -Command "rg" -Required $false

# Check configuration files
Write-Host "${YELLOW}=== Configuration Files ===${R}"
Test-File -Name "Bash aliases" -Path "$env:USERPROFILE\.bash_aliases" -Required $false
Test-File -Name "Git config" -Path "$env:USERPROFILE\.gitconfig" -Required $true

# Check git configuration
Write-Host "${YELLOW}=== Git Configuration ===${R}"
Test-GitConfig -Name "Git user.name" -Key "user.name"
Test-GitConfig -Name "Git user.email" -Key "user.email"
Test-GitConfig -Name "Git core.editor" -Key "core.editor"
Test-GitConfig -Name "Git init.defaultBranch" -Key "init.defaultBranch" -Required $false

# Check git hooks
Write-Host "${YELLOW}=== Git Hooks ===${R}"
$hooksDir = Join-Path $env:USERPROFILE ".config\git\hooks"
Test-GitHook -HookName "pre-commit" -HookPath (Join-Path $hooksDir "pre-commit.ps1")
Test-GitHook -HookName "commit-msg" -HookPath (Join-Path $hooksDir "commit-msg.ps1")

# Check language servers
Write-Host "${YELLOW}=== Language Servers ===${R}"
Test-Command -Name "LSP: clangd" -Command "clangd" -Required $false
Test-Command -Name "LSP: gopls" -Command "gopls" -Required $false
Test-Command -Name "LSP: rust-analyzer" -Command "rust-analyzer" -Required $false
Test-Command -Name "LSP: pyright" -Command "pyright" -Required $false
Test-Command -Name "LSP: tsserver" -Command "tsserver" -Required $false

# Check linters/formatters
Write-Host "${YELLOW}=== Linters & Formatters ===${R}"
Test-Command -Name "Prettier" -Command "prettier" -Required $false
Test-Command -Name "ESLint" -Command "eslint" -Required $false
Test-Command -Name "Ruff" -Command "ruff" -Required $false

# ============================================================================
# OUTPUT FORMATS
# ============================================================================

function Show-TableOutput {
    Write-Host "`n${CYAN}========================================${R}"
    Write-Host "${CYAN}       Health Check Results${R}"
    Write-Host "${CYAN}========================================${R}`n"

    Write-Host ("{0,-30} {1,-10} {2}" -f "CHECK", "STATUS", "MESSAGE") -NoNewline
    Write-Host "${CYAN}----------------------------------------------------------------${R}"

    foreach ($result in $script:checkResults) {
        $statusColor = switch ($result.Status) {
            "pass" { $GREEN }
            "fail" { $RED }
            "warn" { $YELLOW }
            default { "" }
        }

        Write-Host ("{0,-30} $statusColor{1,-10}$R {2}" -f $result.Name, $result.Status.ToUpper(), $result.Message)
    }

    Write-Host "`n${CYAN}========================================${R}"
    Write-Host "${CYAN}           Summary${R}"
    Write-Host "${CYAN}========================================${R}"
    Write-Host "${BLUE}Total Checks:${R}   $($script:totalChecks)"
    Write-Host "${GREEN}Passed:${R}        $($script:passedChecks)"
    Write-Host "${RED}Failed:${R}        $($script:failedChecks)"
    Write-Host "${YELLOW}Warnings:${R}      $($script:warningChecks)"
    Write-Host "${CYAN}========================================${R}"
}

function Show-JsonOutput {
    $json = @{
        total = $script:totalChecks
        passed = $script:passedChecks
        failed = $script:failedChecks
        warnings = $script:warningChecks
        checks = $script:checkResults
    } | ConvertTo-Json -Depth 3

    Write-Output $json
}

# Print results
if ($Format -eq "json") {
    Show-JsonOutput
} else {
    Show-TableOutput
}

# Exit with appropriate code
if ($script:failedChecks -gt 0) {
    exit 1
}

exit 0
