# Windows-specific installation functions for bootstrap script
# Supports: Scoop (preferred), winget

# Source parent libraries if not already loaded
# . "$PSScriptRoot\..\lib\common.ps1"
# . "$PSScriptRoot\..\lib\version-check.ps1"

# ============================================================================
# SCOOP
# ============================================================================
function Ensure-Scoop {
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Track-Skipped "scoop"
        return $true
    }

    Write-Step "Installing Scoop..."
    if ($DryRun) {
        Write-Info "[DRY-RUN] Would install Scoop"
        Track-Installed "scoop"
        return $true
    }

    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        irm get.scoop.sh | iex
        Track-Installed "scoop"
        return $true
    }
    catch {
        Write-Warning ("Failed to install Scoop: {0}" -f $_.Exception.Message)
        Track-Failed "scoop"
        return $false
    }
}

function Install-ScoopPackage {
    param(
        [string]$Package,
        [string]$MinVersion = "",
        [string]$CheckCmd = $Package
    )

    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Warning "Scoop not installed, skipping $Package"
        Track-Failed $Package
        return $false
    }

    if (Test-NeedsInstall $CheckCmd $MinVersion) {
        Write-Step "Installing $Package via Scoop..."
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would install: $Package"
            Track-Installed $Package
            return $true
        }

        try {
            scoop install $Package *> $null
            Track-Installed $Package
            return $true
        }
        catch {
            Write-Warning ("Failed to install {0}: {1}" -f $Package, $_.Exception.Message)
            Track-Failed $Package
            return $false
        }
    }
    else {
        Track-Skipped $CheckCmd
        return $true
    }
}

# Install multiple Scoop packages at once
function Install-ScoopPackages {
    param(
        [string[]]$Packages
    )

    $toInstall = @()

    foreach ($pkg in $Packages) {
        if (Test-NeedsInstall $pkg "") {
            $toInstall += $pkg
        }
        else {
            Track-Skipped $pkg
        }
    }

    if ($toInstall.Count -gt 0) {
        Write-Step "Installing $($toInstall.Count) packages via Scoop..."
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would install: $($toInstall -join ', ')"
            foreach ($pkg in $toInstall) {
                Track-Installed $pkg
            }
            return $true
        }

        try {
            scoop install @toInstall *> $null
            foreach ($pkg in $toInstall) {
                Track-Installed $pkg
            }
            return $true
        }
        catch {
            Write-Warning ("Failed to install packages: {0}" -f $_.Exception.Message)
            foreach ($pkg in $toInstall) {
                Track-Failed $pkg
            }
            return $false
        }
    }

    return $true
}

# Add Scoop bucket
function Add-ScoopBucket {
    param([string]$Bucket)

    if ($DryRun) {
        Write-Info "[DRY-RUN] Would add bucket: $Bucket"
        return $true
    }

    $buckets = scoop bucket list 2>$null
    if ($Bucket -notin $buckets) {
        Write-Step "Adding Scoop bucket: $Bucket"
        scoop bucket add $Bucket *> $null
    }
}

# ============================================================================
# WINGET
# ============================================================================
function Ensure-Winget {
    # winget comes with Windows 10/11, check if available
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Track-Skipped "winget"
        return $true
    }

    Write-Warning "winget not available (may need Windows update)"
    Track-Failed "winget"
    return $false
}

function Install-WingetPackage {
    param(
        [string]$Id,
        [string]$DisplayName = $Id,
        [string]$MinVersion = "",
        [string]$CheckCmd = ""
    )

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Warning "winget not available, skipping $DisplayName"
        return $false
    }

    # Extract package name from ID for check command
    if ([string]::IsNullOrEmpty($CheckCmd)) {
        $CheckCmd = ($Id -split '\.')[-1]
    }

    if (Test-NeedsInstall $CheckCmd $MinVersion) {
        Write-Step "Installing $DisplayName via winget..."
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would install: $Id"
            Track-Installed $DisplayName
            return $true
        }

        try {
            winget install --id $Id --accept-source-agreements --accept-package-agreements *> $null
            Track-Installed $DisplayName
            return $true
        }
        catch {
            Write-Warning ("Failed to install {0}: {1}" -f $DisplayName, $_.Exception.Message)
            Track-Failed $DisplayName
            return $false
        }
    }
    else {
        Track-Skipped $CheckCmd
        return $true
    }
}

# ============================================================================
# CHOCOLATEY (Alternative)
# ============================================================================
function Ensure-Choco {
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Track-Skipped "chocolatey"
        return $true
    }

    Write-Step "Installing Chocolatey..."
    if ($DryRun) {
        Write-Info "[DRY-RUN] Would install Chocolatey"
        Track-Installed "chocolatey"
        return $true
    }

    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Track-Installed "chocolatey"
        return $true
    }
    catch {
        Write-Warning ("Failed to install Chocolatey: {0}" -f $_.Exception.Message)
        Track-Failed "chocolatey"
        return $false
    }
}

function Install-ChocoPackage {
    param(
        [string]$Package,
        [string]$MinVersion = "",
        [string]$CheckCmd = $Package
    )

    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Warning "Chocolatey not installed, skipping $Package"
        return $false
    }

    if (Test-NeedsInstall $CheckCmd $MinVersion) {
        Write-Step "Installing $Package via Chocolatey..."
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would install: $Package"
            Track-Installed $Package
            return $true
        }

        try {
            choco install $Package -y *> $null
            Track-Installed $Package
            return $true
        }
        catch {
            Write-Warning ("Failed to install {0}: {1}" -f $Package, $_.Exception.Message)
            Track-Failed $Package
            return $false
        }
    }
    else {
        Track-Skipped $CheckCmd
        return $true
    }
}

# ============================================================================
# LANGUAGE PACKAGE MANAGERS
# ============================================================================

# Install via npm global
function Install-NpmGlobal {
    param(
        [string]$Package,
        [string]$CmdName = "",
        [string]$MinVersion = ""
    )

    if ([string]::IsNullOrEmpty($CmdName)) {
        $CmdName = ($Package -split '/')[-1]
        $CmdName = $CmdName.TrimStart('@')
    }

    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Warning "npm not found, skipping $Package"
        Track-Failed $Package
        return $false
    }

    if (Test-NeedsInstall $CmdName $MinVersion) {
        Write-Step "Installing $Package via npm..."
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would npm install -g $Package"
            Track-Installed $Package
            return $true
        }

        try {
            npm install -g $Package *> $null
            Track-Installed $Package
            return $true
        }
        catch {
            Write-Warning ("Failed to install {0}: {1}" -f $Package, $_.Exception.Message)
            Track-Failed $Package
            return $false
        }
    }
    else {
        Track-Skipped $CmdName
        return $true
    }
}

# Install via go install or gup
function Install-GoPackage {
    param(
        [string]$Package,
        [string]$CmdName = "",
        [string]$MinVersion = ""
    )

    if ([string]::IsNullOrEmpty($CmdName)) {
        $CmdName = ($Package -split '/')[-1]
    }

    if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
        Write-Warning "go not found, skipping $Package"
        Track-Failed $Package
        return $false
    }

    # Get GOPATH and ensure it's in PATH (for current session + persist)
    $goPath = go env GOPATH
    if ($goPath) {
        # Persist to User PATH for future sessions
        if ("$env:PATH" -notlike "*$goPath\bin*") {
            Add-ToPath "$goPath\bin"
        }
        # Also add to current session PATH so we can find commands immediately
        if ("$env:PATH" -notlike "*$goPath\bin*") {
            $env:PATH = "$goPath\bin;$env:PATH"
        }
    }

    # Check if already installed (after ensuring GOPATH/bin in PATH)
    if (Get-Command $CmdName -ErrorAction SilentlyContinue) {
        Track-Skipped "$CmdName (already installed)"
        return $true
    }

    # Try using gup if available
    if (Get-Command gup -ErrorAction SilentlyContinue) {
        Write-Step "Installing $Package via gup..."
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would gup install $Package"
            Track-Installed $Package
            return $true
        }

        try {
            gup install $Package *> $null
            Track-Installed $Package
            return $true
        }
        catch {
            Write-Warning "gup install failed, falling back to go install..."
        }
    }

    # Fallback to go install
    Write-Step "Installing $Package via go..."
    if ($DryRun) {
        Write-Info "[DRY-RUN] Would go install $Package@latest"
        Track-Installed $Package
        return $true
    }

    try {
        go install ${Package}@latest *> $null
        Track-Installed $Package
        return $true
    }
    catch {
        Write-Warning ("Failed to install {0}: {1}" -f $Package, $_.Exception.Message)
        Track-Failed $Package
        return $false
    }
}

# Install via cargo
function Install-CargoPackage {
    param(
        [string]$Package,
        [string]$CmdName = $Package,
        [string]$MinVersion = ""
    )

    if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
        Write-Warning "cargo not found, skipping $Package"
        Track-Failed $Package
        return $false
    }

    if (Test-NeedsInstall $CmdName $MinVersion) {
        Write-Step "Installing $Package via cargo..."
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would cargo install $Package"
            Track-Installed $Package
            return $true
        }

        try {
            cargo install $Package *> $null
            Add-ToPath "$env:USERPROFILE\.cargo\bin"
            Track-Installed $Package
            return $true
        }
        catch {
            Write-Warning ("Failed to install {0}: {1}" -f $Package, $_.Exception.Message)
            Track-Failed $Package
            return $false
        }
    }
    else {
        Track-Skipped $CmdName
        return $true
    }
}

# Install via pip
function Install-PipGlobal {
    param(
        [string]$Package,
        [string]$CmdName = $Package,
        [string]$MinVersion = ""
    )

    $pythonCmd = $null
    if (Get-Command python -ErrorAction SilentlyContinue) {
        $pythonCmd = "python"
    }
    elseif (Get-Command python3 -ErrorAction SilentlyContinue) {
        $pythonCmd = "python3"
    }
    elseif (Get-Command py -ErrorAction SilentlyContinue) {
        $pythonCmd = "py"
    }

    if (-not $pythonCmd) {
        Write-Warning "Python not found, skipping $Package"
        Track-Failed $Package
        return $false
    }

    if (Test-NeedsInstall $CmdName $MinVersion) {
        Write-Step "Installing $Package via pip..."
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would pip install --user --upgrade $Package"
            Track-Installed $Package
            return $true
        }

        try {
            & $pythonCmd -m pip install --user --upgrade $Package *> $null
            Track-Installed $Package
            return $true
        }
        catch {
            Write-Warning ("Failed to install {0}: {1}" -f $Package, $_.Exception.Message)
            Track-Failed $Package
            return $false
        }
    }
    else {
        Track-Skipped $CmdName
        return $true
    }
}

# Install via dotnet tool
function Install-DotnetTool {
    param(
        [string]$Package,
        [string]$CmdName = $Package,
        [string]$MinVersion = ""
    )

    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        Write-Warning "dotnet not found, skipping $Package"
        Track-Failed $Package
        return $false
    }

    if (Test-NeedsInstall $CmdName $MinVersion) {
        Write-Step "Installing $Package via dotnet..."
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would dotnet tool install --global $Package"
            Track-Installed $Package
            return $true
        }

        try {
            dotnet tool install --global $Package *> $null
            Add-ToPath "$env:USERPROFILE\.dotnet\tools"
            Track-Installed $Package
            return $true
        }
        catch {
            # Try update if install failed
            try {
                dotnet tool update --global $Package *> $null
                Track-Installed $Package
                return $true
            }
            catch {
                Write-Warning ("Failed to install {0}: {1}" -f $Package, $_.Exception.Message)
                Track-Failed $Package
                return $false
            }
        }
    }
    else {
        Track-Skipped $CmdName
        return $true
    }
}

# ============================================================================
# RUSTUP
# ============================================================================
function Install-Rustup {
    if (Get-Command rustup -ErrorAction SilentlyContinue) {
        Track-Skipped "rust"
        return $true
    }

    Write-Step "Installing Rust via rustup..."
    if ($DryRun) {
        Write-Info "[DRY-RUN] Would install rustup"
        Track-Installed "rust"
        return $true
    }

    try {
        # Download and run rustup-init
        $rustupUrl = "https://win.rustup.rs/x86_64"
        $rustupPath = "$env:TEMP\rustup-init.exe"
        Invoke-WebRequest -Uri $rustupUrl -OutFile $rustupPath
        & $rustupPath -y
        Remove-Item $rustupPath

        # Add cargo to PATH
        Add-ToPath "$env:USERPROFILE\.cargo\bin"
        # Refresh PATH for current session
        Refresh-Path
        Track-Installed "rust"
        return $true
    }
    catch {
        Write-Warning ("Failed to install Rust: {0}" -f $_.Exception.Message)
        Track-Failed "rust"
        return $false
    }
}

function Install-RustAnalyzerComponent {
    if (-not (Get-Command rustup -ErrorAction SilentlyContinue)) {
        Write-Warning "rustup not found, skipping rust-analyzer"
        Track-Failed "rust-analyzer"
        return $false
    }

    if (Test-NeedsInstall rust-analyzer "") {
        Write-Step "Adding rust-analyzer component..."
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would run: rustup component add rust-analyzer"
            Track-Installed "rust-analyzer"
            return $true
        }

        try {
            rustup component add rust-analyzer *> $null
            Track-Installed "rust-analyzer"
            return $true
        }
        catch {
            Write-Warning ("Failed to add rust-analyzer: {0}" -f $_.Exception.Message)
            Track-Failed "rust-analyzer"
            return $false
        }
    }
    else {
        Track-Skipped "rust-analyzer"
        return $true
    }
}

# ============================================================================
# PATH MANAGEMENT
# ============================================================================
function Add-ToPath {
    param([string]$Path)

    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -notlike "*$Path*") {
        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$Path", "User")
        $env:Path += ";$Path"
        Write-Info "Added to PATH: $Path"
    }
}

function Refresh-Path {
    # Refresh PATH for current session
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}
