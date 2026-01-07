# Version checking utilities for bootstrap scripts (PowerShell)
# Extracts versions from tool output and compares against minimum requirements

# Source common.ps1 first for Test-Command
# . "$PSScriptRoot\common.ps1"

# ============================================================================
# VERSION PATTERNS
# ============================================================================
# Hashtable mapping tool names to regex patterns for version extraction

$Script:VersionPatterns = @{
    # Programming Languages
    "git" = 'git version ([0-9]+\.[0-9]+\.[0-9]+)'
    "node" = 'v?([0-9]+\.[0-9]+\.[0-9]+)'
    "nodejs" = 'v?([0-9]+\.[0-9]+\.[0-9]+)'
    "npm" = 'v?([0-9]+\.[0-9]+\.[0-9]+)'
    "python" = 'Python ([0-9]+\.[0-9]+\.[0-9]+)'
    "python3" = 'Python ([0-9]+\.[0-9]+\.[0-9]+)'
    "go" = 'go version go([0-9]+\.[0-9]+(?:\.[0-9]+)?)'
    "rustc" = 'rustc ([0-9]+\.[0-9]+\.[0-9]+)'
    "cargo" = 'cargo ([0-9]+\.[0-9]+\.[0-9]+)'
    "php" = 'PHP ([0-9]+\.[0-9]+\.[0-9]+)'
    "dotnet" = '([0-9]+\.[0-9]+\.[0-9]+)'

    # Package Managers
    "brew" = 'Homebrew ([0-9]+\.[0-9]+\.[0-9]+)'
    "scoop" = 'Current scoop version:[\s]*v?([0-9]+\.[0-9]+\.[0-9]+)'
    "winget" = 'v([0-9]+\.[0-9]+\.[0-9]+)'
    "choco" = '([0-9]+\.[0-9]+\.[0-9]+)'
    "apt" = '([0-9]+\.[0-9]+\.[0-9]+)'
    "dnf" = '([0-9]+\.[0-9]+\.[0-9]+)'
    "pacman" = 'pacman v([0-9]+\.[0-9]+\.[0-9]+)'
    "zypper" = 'zypper ([0-9]+\.[0-9]+\.[0-9]+)'

    # CLI Tools
    "fzf" = '([0-9]+\.[0-9]+\.[0-9]+)'
    "bat" = 'bat ([0-9]+\.[0-9]+\.[0-9]+)'
    "eza" = 'eza ([0-9]+\.[0-9]+\.[0-9]+)'
    "exa" = 'exa v?([0-9]+\.[0-9]+\.[0-9]+)'
    "lazygit" = 'version,? ([0-9]+\.[0-9]+\.[0-9]+)'
    "gh" = 'gh version ([0-9]+\.[0-9]+\.[0-9]+)'
    "tokei" = 'tokei ([0-9]+\.[0-9]+\.[0-9]+)'
    "zoxide" = 'zoxide v([0-9]+\.[0-9]+\.[0-9]+)'
    "ripgrep" = 'ripgrep ([0-9]+\.[0-9]+\.[0-9]+)'
    "rg" = 'ripgrep ([0-9]+\.[0-9]+\.[0-9]+)'
    "fd" = 'fd ([0-9]+\.[0-9]+\.[0-9]+)'
    "difft" = 'difft ([0-9]+\.[0-9]+\.[0-9]+)'
    "difftastic" = 'difft ([0-9]+\.[0-9]+\.[0-9]+)'

    # Language Servers
    "gopls" = 'golang.org/x/tools/gopls v([0-9]+\.[0-9]+\.[0-9]+)'
    "rust-analyzer" = 'rust-analyzer ([0-9]+\.[0-9]+\.[0-9]+)'
    "rust_analyzer" = 'rust-analyzer ([0-9]+\.[0-9]+\.[0-9]+)'
    "pyright" = 'Pyright ([0-9]+\.[0-9]+\.[0-9]+)'
    "typescript-language-server" = 'typescript-language-server version ([0-9]+\.[0-9]+\.[0-9]+)'
    "ts_ls" = 'typescript-language-server version ([0-9]+\.[0-9]+\.[0-9]+)'
    "clangd" = 'clangd version ([0-9]+\.[0-9]+\.[0-9]+)'
    "lua-language-server" = 'Lua Language Server v?([0-9]+\.[0-9]+\.[0-9]+)'
    "lua_ls" = '([0-9]+\.[0-9]+\.[0-9]+)'
    "jdtls" = 'jdtls ([0-9]+\.[0-9]+)'
    "csharp-ls" = '([0-9]+\.[0-9]+\.[0-9]+)'
    "csharp_ls" = '([0-9]+\.[0-9]+\.[0-9]+)'
    "yaml-language-server" = 'yaml-language-server version ([0-9]+\.[0-9]+\.[0-9]+)'
    "yamlls" = '([0-9]+\.[0-9]+\.[0-9]+)'
    "docker-langserver" = 'docker-langserver ([0-9]+\.[0-9]+\.[0-9]+)'
    "docker_ls" = '([0-9]+\.[0-9]+\.[0-9]+)'

    # Linters & Formatters
    "scalafmt" = 'scalafmt ([0-9]+\.[0-9]+\.[0-9]+)'
    "scalafmt.exe" = 'scalafmt ([0-9]+\.[0-9]+\.[0-9]+)'
    "prettier" = '([0-9]+\.[0-9]+\.[0-9]+)'
    "eslint" = 'v([0-9]+\.[0-9]+\.[0-9]+)'
    "ruff" = 'ruff ([0-9]+\.[0-9]+\.[0-9]+)'
    "black" = 'black, ([0-9]+\.[0-9]+\.[0-9]+)'
    "mypy" = 'mypy ([0-9]+\.[0-9]+\.[0-9]+)'
    "mypy.exe" = 'mypy ([0-9]+\.[0-9]+\.[0-9]+)'
    "goimports" = 'v?([0-9]+\.[0-9]+\.[0-9]+)'
    "golangci-lint" = 'golangci-lint ([0-9]+\.[0-9]+\.[0-9]+)'
    "clang-format" = 'clang-format version ([0-9]+\.[0-9]+\.[0-9]+)'
}

# Version flags for tools that don't use --version
$Script:VersionFlags = @{
    "go" = "version"
    "cargo" = "--version"
    "scoop" = "--version"
}

# ============================================================================
# VERSION EXTRACTION
# ============================================================================

function Get-ToolVersion {
    param(
        [string]$Tool,
        [string]$VersionFlag = ""
    )

    # Check if tool exists
    if (-not (Test-Command $Tool)) {
        return $null
    }

    # Determine version flag
    if ([string]::IsNullOrEmpty($VersionFlag)) {
        $VersionFlag = if ($Script:VersionFlags.ContainsKey($Tool)) {
            $Script:VersionFlags[$Tool]
        }
        else {
            "--version"
        }
    }

    # Try to get version output
    $versionOutput = & $Tool $VersionFlag 2>&1
    if ($LASTEXITCODE -ne 0 -and -not $?) {
        return $null
    }

    # Get version pattern for this tool
    $versionPattern = if ($Script:VersionPatterns.ContainsKey($Tool)) {
        $Script:VersionPatterns[$Tool]
    }
    else {
        $null
    }

    # Extract version using pattern if available
    if ($versionPattern) {
        if ($versionOutput -match $versionPattern -and $matches.Count -gt 1) {
            return $matches[1]
        }
    }

    # Fallback: try to extract first version-like string
    if ($versionOutput -match '([0-9]+\.[0-9]+\.?[0-9]*)' -and $matches.Count -gt 1) {
        return $matches[1]
    }

    return $null
}

# ============================================================================
# VERSION COMPARISON
# ============================================================================

function Compare-Versions {
    param(
        [string]$Installed,
        [string]$Required
    )

    # Handle date-based versions (e.g., 2023-01-01) BEFORE cleaning
    # The cleaning step removes hyphens which are part of date format
    if ($Installed -match '^\d{4}-\d{2}-\d{2}$' -and $Required -match '^\d{4}-\d{2}-\d{2}$') {
        return [datetime]::Parse($Installed) -ge [datetime]::Parse($Required)
    }

    # Clean version strings - remove 'v' prefix and suffixes
    $Installed = $Installed -replace '^v', '' -replace '[-+].*$', ''
    $Required = $Required -replace '^v', '' -replace '[-+].*$', ''

    # Split into arrays
    $installedParts = $Installed -split '\.'
    $requiredParts = $Required -split '\.'

    # Determine max length
    $maxParts = [Math]::Max($installedParts.Count, $requiredParts.Count)

    # Compare each part
    for ($i = 0; $i -lt $maxParts; $i++) {
        $instPart = if ($i -lt $installedParts.Count) { $installedParts[$i] -replace '\D', '' } else { "0" }
        $reqPart = if ($i -lt $requiredParts.Count) { $requiredParts[$i] -replace '\D', '' } else { "0" }

        # Handle empty parts
        if ([string]::IsNullOrEmpty($instPart)) { $instPart = "0" }
        if ([string]::IsNullOrEmpty($reqPart)) { $reqPart = "0" }

        try {
            $instNum = [int]$instPart
            $reqNum = [int]$reqPart

            if ($instNum -lt $reqNum) {
                return $false  # Installed < Required
            }
            elseif ($instNum -gt $reqNum) {
                return $true  # Installed > Required
            }
        }
        catch {
            # If conversion fails, assume equal
            continue
        }
    }

    return $true  # Versions are equal or installed has more parts
}

# ============================================================================
# INSTALLATION CHECKING
# ============================================================================

function Test-NeedsInstall {
    param(
        [string]$Tool,
        [string]$MinVersion = ""
    )

    # Check if tool exists
    # We don't check versions - just existence
    # This ensures we always get the latest installed version
    if (-not (Test-Command $Tool)) {
        return $true  # Needs install
    }

    # Tool exists, no need to reinstall
    return $false
}

# Alias for Bash compatibility
function needs_install {
    param(
        [string]$Tool,
        [string]$MinVersion = ""
    )
    Test-NeedsInstall -Tool $Tool -MinVersion $MinVersion
}

# Check and report version status
function Show-VersionStatus {
    param(
        [string]$Tool,
        [string]$MinVersion = "",
        [string]$DisplayName = $null
    )

    if ([string]::IsNullOrEmpty($DisplayName)) {
        $DisplayName = $Tool
    }

    if (-not (Test-Command $Tool)) {
        Write-Info "$DisplayName`: not installed"
        return $true  # needs install
    }

    $installedVersion = Get-ToolVersion -Tool $Tool
    # Simplified: just report installed status without version
    if ([string]::IsNullOrEmpty($installedVersion)) {
        Write-Info "$DisplayName`: installed"
        return $false
    }

    Write-Info "$DisplayName`: installed (version $installedVersion)"
    return $false
}

# Alias for Bash compatibility
function check_and_report_version {
    param(
        [string]$Tool,
        [string]$MinVersion = "",
        [string]$DisplayName = $null
    )
    Show-VersionStatus -Tool $Tool -MinVersion $MinVersion -DisplayName $DisplayName
}

# Functions are automatically available when sourced with '.'
# No Export-ModuleMember needed for dot-sourced files
