# Windows-specific installation functions for bootstrap script
# Supports: Scoop (preferred), winget

# Source parent libraries if not already loaded
# . "$PSScriptRoot\..\lib\common.ps1"
# . "$PSScriptRoot\..\lib\version-check.ps1"

# ============================================================================
# GIT CONFIGURATION
# ============================================================================
function Configure-GitSettings {
    # Set core.autocrlf=input to normalize line endings to LF
    # This converts CRLF to LF on commit, but keeps LF on checkout
    # Combined with .gitattributes, this ensures consistent LF endings
    $currentAutocrlf = git config --global core.autocrlf 2>$null
    if ($currentAutocrlf -ne "input") {
        Write-Step "Configuring git line endings (core.autocrlf=input)..."
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would run: git config --global core.autocrlf input"
        }
        else {
            git config --global core.autocrlf input
            Write-Info "Set core.autocrlf=input (LF normalization enabled)"
        }
    }
    else {
        Track-Skipped "git autocrlf already configured"
    }

    # Ensure .gitattributes is respected
    $currentAttrs = git config --global core.attributesfile 2>$null
    if ([string]::IsNullOrEmpty($currentAttrs)) {
        # No global attributes file set - .gitattributes in repo will be used
        Write-Info "Repo .gitattributes will enforce line endings"
    }

    # Add GitHub SSH key to known_hosts to prevent host key verification prompts
    $sshDir = Join-Path $env:USERPROFILE ".ssh"
    $knownHosts = Join-Path $sshDir "known_hosts"
    $needsGitHubKey = $true

    if (Test-Path $knownHosts) {
        $content = Get-Content $knownHosts -Raw
        if ($content -match "github\.com") {
            $needsGitHubKey = $false
        }
    }

    if ($needsGitHubKey) {
        Write-Step "Adding GitHub SSH key to known_hosts..."
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would add GitHub SSH key to $knownHosts"
        }
        else {
            if (-not (Test-Path $sshDir)) {
                New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
            }
            if (Get-Command ssh-keyscan -ErrorAction SilentlyContinue) {
                ssh-keyscan github.com >> $knownHosts 2>$null
                Write-Info "GitHub SSH key added to known_hosts"
            }
            else {
                Write-Info "ssh-keyscan not available, skipping known_hosts setup"
            }
        }
    }
    else {
        Track-Skipped "GitHub SSH key already in known_hosts"
    }
}

# ============================================================================
# PACKAGE DESCRIPTIONS
# ============================================================================
function Get-PackageDescription {
    param([string]$Package)
    switch ($Package) {
        # Package managers
        "scoop" { return "package manager" }
        "winget" { return "Windows package manager" }
        "chocolatey" { return "package manager" }
        "npm" { return "Node.js package manager" }
        "coursier" { return "JVM dependency manager" }

        # Core runtimes
        "git" { return "version control" }
        "llvm" { return "C/C++ toolchain" }
        "node" { return "Node.js runtime" }
        "nodejs" { return "Node.js runtime" }
        "python" { return "Python runtime" }
        "go" { return "Go runtime" }
        "rust" { return "Rust toolchain" }
        "dotnet" { return ".NET SDK" }
        "OpenJDK" { return "Java development" }
        "ruby" { return "Ruby runtime" }

        # Language servers
        "clangd" { return "C/C++ LSP" }
        "gopls" { return "Go LSP" }
        "rust-analyzer" { return "Rust LSP" }
        "pyright" { return "Python LSP" }
        "typescript-language-server" { return "TypeScript LSP" }
        "yaml-language-server" { return "YAML LSP" }
        "lua-language-server" { return "Lua LSP" }
        "csharp-ls" { return "C# LSP" }
        "jdtls" { return "Java LSP" }
        "intelephense" { return "PHP LSP" }
        "docker-langserver" { return "Docker LSP" }
        "tombi" { return "TOML LSP" }
        "tinymist" { return "Nim LSP" }

        # Linters & formatters
        "prettier" { return "code formatter" }
        "eslint" { return "JavaScript linter" }
        "ruff" { return "Python linter" }
        "black" { return "Python formatter" }
        "isort" { return "Python import sorter" }
        "mypy" { return "Python type checker" }
        "goimports" { return "Go import organizer" }
        "golangci-lint" { return "Go linter" }
        "shellcheck" { return "Shell script analyzer" }
        "shfmt" { return "Shell script formatter" }
        "scalafmt" { return "Scala formatter" }

        # CLI tools
        "fzf" { return "fuzzy finder" }
        "zoxide" { return "smart directory navigation" }
        "bat" { return "enhanced cat" }
        "eza" { return "enhanced ls" }
        "lazygit" { return "Git TUI" }
        "gh" { return "GitHub CLI" }
        "rg" { return "text search" }
        "ripgrep" { return "text search" }
        "fd" { return "file finder" }
        "tokei" { return "code stats" }
        "difft" { return "diff viewer" }
        "bats" { return "Bash testing" }

        # Development tools
        "bashcov" { return "code coverage" }
        "Pester" { return "PowerShell testing" }
        "vscode" { return "code editor" }
        "visual-studio" { return "full IDE" }
        "latex" { return "document preparation" }
        "claude-code" { return "AI CLI" }
        "opencode" { return "AI CLI" }

        default { return "" }
    }
}

# ============================================================================
# SCOOP
# ============================================================================
function Ensure-Scoop {
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Track-Skipped "scoop" (Get-PackageDescription "scoop")
        return $true
    }

    Write-Step "Installing Scoop..."
    if ($DryRun) {
        Write-Info "[DRY-RUN] Would install Scoop"
        Track-Installed "scoop" (Get-PackageDescription "scoop")
        return $true
    }

    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        irm get.scoop.sh | iex
        Track-Installed "scoop" (Get-PackageDescription "scoop")
        return $true
    }
    catch {
        Write-Warning ("Failed to install Scoop: {0}" -f $_.Exception.Message)
        Track-Failed "scoop" (Get-PackageDescription "scoop")
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
        Track-Failed $Package (Get-PackageDescription $Package)
        return $false
    }

    if (Test-NeedsInstall $CheckCmd $MinVersion) {
        Write-Step "Installing $Package via Scoop..."
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would install: $Package"
            Track-Installed $Package (Get-PackageDescription $Package)
            return $true
        }

        try {
            scoop install $Package *> $null
            Track-Installed $Package (Get-PackageDescription $Package)
            return $true
        }
        catch {
            Write-Warning ("Failed to install {0}: {1}" -f $Package, $_.Exception.Message)
            Track-Failed $Package (Get-PackageDescription $Package)
            return $false
        }
    }
    else {
        Track-Skipped $CheckCmd (Get-PackageDescription $CheckCmd)
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
            Track-Skipped $pkg (Get-PackageDescription $pkg)
        }
    }

    if ($toInstall.Count -gt 0) {
        Write-Step "Installing $($toInstall.Count) packages via Scoop..."
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would install: $($toInstall -join ', ')"
            foreach ($pkg in $toInstall) {
                Track-Installed $pkg (Get-PackageDescription $pkg)
            }
            return $true
        }

        try {
            scoop install @toInstall *> $null
            foreach ($pkg in $toInstall) {
                Track-Installed $pkg (Get-PackageDescription $pkg)
            }
            return $true
        }
        catch {
            Write-Warning ("Failed to install packages: {0}" -f $_.Exception.Message)
            foreach ($pkg in $toInstall) {
                Track-Failed $pkg (Get-PackageDescription $pkg)
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
        Track-Skipped "winget" (Get-PackageDescription "winget")
        return $true
    }

    Write-Warning "winget not available (may need Windows update)"
    Track-Failed "winget" (Get-PackageDescription "winget")
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
            Track-Installed $DisplayName (Get-PackageDescription $DisplayName)
            return $true
        }

        try {
            winget install --id $Id --accept-source-agreements --accept-package-agreements *> $null
            Track-Installed $DisplayName (Get-PackageDescription $DisplayName)
            return $true
        }
        catch {
            Write-Warning ("Failed to install {0}: {1}" -f $DisplayName, $_.Exception.Message)
            Track-Failed $DisplayName (Get-PackageDescription $DisplayName)
            return $false
        }
    }
    else {
        Track-Skipped $CheckCmd (Get-PackageDescription $CheckCmd)
        return $true
    }
}

# ============================================================================
# CHOCOLATEY (Alternative)
# ============================================================================
function Ensure-Choco {
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Track-Skipped "chocolatey" (Get-PackageDescription "chocolatey")
        return $true
    }

    Write-Step "Installing Chocolatey..."
    if ($DryRun) {
        Write-Info "[DRY-RUN] Would install Chocolatey"
        Track-Installed "chocolatey" (Get-PackageDescription "chocolatey")
        return $true
    }

    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Track-Installed "chocolatey" (Get-PackageDescription "chocolatey")
        return $true
    }
    catch {
        Write-Warning ("Failed to install Chocolatey: {0}" -f $_.Exception.Message)
        Track-Failed "chocolatey" (Get-PackageDescription "chocolatey")
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
            Track-Installed $Package (Get-PackageDescription $Package)
            return $true
        }

        try {
            choco install $Package -y *> $null
            Track-Installed $Package (Get-PackageDescription $Package)
            return $true
        }
        catch {
            Write-Warning ("Failed to install {0}: {1}" -f $Package, $_.Exception.Message)
            Track-Failed $Package (Get-PackageDescription $Package)
            return $false
        }
    }
    else {
        Track-Skipped $CheckCmd (Get-PackageDescription $CheckCmd)
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
        Track-Failed $Package (Get-PackageDescription $Package)
        return $false
    }

    if (Test-NeedsInstall $CmdName $MinVersion) {
        Write-Step "Installing $Package via npm..."
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would npm install -g $Package"
            Track-Installed $Package (Get-PackageDescription $Package)
            return $true
        }

        try {
            npm install -g $Package *> $null
            Track-Installed $Package (Get-PackageDescription $Package)
            return $true
        }
        catch {
            Write-Warning ("Failed to install {0}: {1}" -f $Package, $_.Exception.Message)
            Track-Failed $Package (Get-PackageDescription $Package)
            return $false
        }
    }
    else {
        Track-Skipped $CmdName (Get-PackageDescription $CmdName)
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
        Track-Failed $Package (Get-PackageDescription $Package)
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
        Track-Skipped $CmdName (Get-PackageDescription $CmdName)
        return $true
    }

    # Try using gup if available
    if (Get-Command gup -ErrorAction SilentlyContinue) {
        Write-Step "Installing $Package via gup..."
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would gup install $Package"
            Track-Installed $Package (Get-PackageDescription $Package)
            return $true
        }

        try {
            gup install $Package *> $null
            Track-Installed $Package (Get-PackageDescription $Package)
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
        Track-Installed $Package (Get-PackageDescription $Package)
        return $true
    }

    try {
        go install ${Package}@latest *> $null
        Track-Installed $Package (Get-PackageDescription $Package)
        return $true
    }
    catch {
        Write-Warning ("Failed to install {0}: {1}" -f $Package, $_.Exception.Message)
        Track-Failed $Package (Get-PackageDescription $Package)
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
        Track-Failed $Package (Get-PackageDescription $Package)
        return $false
    }

    if (Test-NeedsInstall $CmdName $MinVersion) {
        Write-Step "Installing $Package via cargo..."
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would cargo install $Package"
            Track-Installed $Package (Get-PackageDescription $Package)
            return $true
        }

        try {
            cargo install $Package *> $null
            Add-ToPath "$env:USERPROFILE\.cargo\bin"
            Track-Installed $Package (Get-PackageDescription $Package)
            return $true
        }
        catch {
            Write-Warning ("Failed to install {0}: {1}" -f $Package, $_.Exception.Message)
            Track-Failed $Package (Get-PackageDescription $Package)
            return $false
        }
    }
    else {
        Track-Skipped $CmdName (Get-PackageDescription $CmdName)
        return $true
    }
}

# ============================================================================
# COURSIER (Scala tool installer)
# ============================================================================
# Helper to check if coursier executable exists (bypasses Get-Command session limitation)
function Test-CoursierInstalled {
    # Check scoop shims for coursier.cmd (main install method)
    $scoopShim = Join-Path $env:USERPROFILE "scoop\shims\coursier.cmd"
    if (Test-Path $scoopShim) {
        return $true
    }

    # Check Coursier bin directory for cs.exe (created after coursier setup)
    $csBin = Join-Path $env:USERPROFILE ".local\share\coursier\bin\cs.exe"
    if (Test-Path $csBin) {
        return $true
    }

    # Fallback to Get-Command (for existing installations in PATH)
    if (Get-Command cs -ErrorAction SilentlyContinue) {
        return $true
    }

    # Also check for coursier command directly
    if (Get-Command coursier -ErrorAction SilentlyContinue) {
        return $true
    }

    return $false
}

# Helper to get the actual coursier executable path
function Get-CoursierExe {
    # Check scoop shims first
    $scoopShim = Join-Path $env:USERPROFILE "scoop\shims\coursier.cmd"
    if (Test-Path $scoopShim) {
        return $scoopShim
    }

    # Check Coursier bin for cs.exe
    $csBin = Join-Path $env:USERPROFILE ".local\share\coursier\bin\cs.exe"
    if (Test-Path $csBin) {
        return $csBin
    }

    # Fallback to command name
    return "coursier"
}

function Ensure-Coursier {
    if (Test-CoursierInstalled) {
        Track-Skipped "coursier" (Get-PackageDescription "coursier")
        return $true
    }

    Write-Step "Installing Coursier (via Scoop)..."
    if ($DryRun) {
        Write-Info "[DRY-RUN] Would install Coursier"
        Track-Installed "coursier" (Get-PackageDescription "coursier")
        return $true
    }

    try {
        # Coursier is available via scoop
        if (Get-Command scoop -ErrorAction SilentlyContinue) {
            scoop install coursier *> $null
            # Refresh PATH for current session
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            Track-Installed "coursier" (Get-PackageDescription "coursier")
            return $true
        }
        else {
            Write-Warning "Scoop not found, cannot install Coursier"
            Track-Failed "coursier" (Get-PackageDescription "coursier")
            return $false
        }
    }
    catch {
        Write-Warning ("Failed to install Coursier: {0}" -f $_.Exception.Message)
        Track-Failed "coursier" (Get-PackageDescription "coursier")
        return $false
    }
}

function Install-CoursierPackage {
    param(
        [string]$Package,
        [string]$MinVersion = "",
        [string]$CheckCmd = $Package
    )

    if (-not (Test-CoursierInstalled)) {
        Write-Warning "Coursier not installed, skipping $Package"
        Track-Failed $Package (Get-PackageDescription $Package)
        return $false
    }

    if (Test-NeedsInstall $CheckCmd $MinVersion) {
        Write-Step "Installing $Package via Coursier..."
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would coursier install $Package"
            Track-Installed $Package (Get-PackageDescription $Package)
            return $true
        }

        try {
            # Use helper to get the actual coursier executable path
            $csExe = Get-CoursierExe
            & $csExe install $Package *> $null
            # Coursier installs to %LOCALAPPDATA%\Coursier\data\bin on Windows
            $csBin = Join-Path $env:LOCALAPPDATA "Coursier\data\bin"
            if (Test-Path $csBin) {
                Add-ToPath $csBin -User
            }
            Track-Installed $Package (Get-PackageDescription $Package)
            return $true
        }
        catch {
            Write-Warning ("Failed to install {0}: {1}" -f $Package, $_.Exception.Message)
            Track-Failed $Package (Get-PackageDescription $Package)
            return $false
        }
    }
    else {
        Track-Skipped $CheckCmd (Get-PackageDescription $CheckCmd)
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
        Track-Failed $Package (Get-PackageDescription $Package)
        return $false
    }

    if (Test-NeedsInstall $CmdName $MinVersion) {
        Write-Step "Installing $Package via pip..."
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would pip install --user --upgrade $Package"
            Track-Installed $Package (Get-PackageDescription $Package)
            return $true
        }

        try {
            & $pythonCmd -m pip install --user --upgrade $Package *> $null
            # Add Python Scripts directory to PATH for user packages
            $pythonScriptsPath = Join-Path $env:APPDATA "Python\Scripts"
            if (Test-Path $pythonScriptsPath) {
                Add-ToPath $pythonScriptsPath
            }
            Track-Installed $Package (Get-PackageDescription $Package)
            return $true
        }
        catch {
            Write-Warning ("Failed to install {0}: {1}" -f $Package, $_.Exception.Message)
            Track-Failed $Package (Get-PackageDescription $Package)
            return $false
        }
    }
    else {
        Track-Skipped $CmdName (Get-PackageDescription $CmdName)
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
        Track-Failed $Package (Get-PackageDescription $Package)
        return $false
    }

    if (Test-NeedsInstall $CmdName $MinVersion) {
        Write-Step "Installing $Package via dotnet..."
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would dotnet tool install --global $Package"
            Track-Installed $Package (Get-PackageDescription $Package)
            return $true
        }

        try {
            dotnet tool install --global $Package *> $null
            Add-ToPath "$env:USERPROFILE\.dotnet\tools"
            Track-Installed $Package (Get-PackageDescription $Package)
            return $true
        }
        catch {
            # Try update if install failed
            try {
                dotnet tool update --global $Package *> $null
                Track-Installed $Package (Get-PackageDescription $Package)
                return $true
            }
            catch {
                Write-Warning ("Failed to install {0}: {1}" -f $Package, $_.Exception.Message)
                Track-Failed $Package (Get-PackageDescription $Package)
                return $false
            }
        }
    }
    else {
        Track-Skipped $CmdName (Get-PackageDescription $CmdName)
        return $true
    }
}

# ============================================================================
# RUSTUP
# ============================================================================
function Install-Rustup {
    if (Get-Command rustup -ErrorAction SilentlyContinue) {
        Track-Skipped "rust" (Get-PackageDescription "rust")
        return $true
    }

    Write-Step "Installing Rust via rustup..."
    if ($DryRun) {
        Write-Info "[DRY-RUN] Would install rustup"
        Track-Installed "rust" (Get-PackageDescription "rust")
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
        Track-Installed "rust" (Get-PackageDescription "rust")
        return $true
    }
    catch {
        Write-Warning ("Failed to install Rust: {0}" -f $_.Exception.Message)
        Track-Failed "rust" (Get-PackageDescription "rust")
        return $false
    }
}

function Install-RustAnalyzerComponent {
    if (-not (Get-Command rustup -ErrorAction SilentlyContinue)) {
        Write-Warning "rustup not found, skipping rust-analyzer"
        Track-Failed "rust-analyzer" (Get-PackageDescription "rust-analyzer")
        return $false
    }

    if (Test-NeedsInstall rust-analyzer "") {
        Write-Step "Adding rust-analyzer component..."
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would run: rustup component add rust-analyzer"
            Track-Installed "rust-analyzer" (Get-PackageDescription "rust-analyzer")
            return $true
        }

        try {
            rustup component add rust-analyzer *> $null
            Track-Installed "rust-analyzer" (Get-PackageDescription "rust-analyzer")
            return $true
        }
        catch {
            Write-Warning ("Failed to add rust-analyzer: {0}" -f $_.Exception.Message)
            Track-Failed "rust-analyzer" (Get-PackageDescription "rust-analyzer")
            return $false
        }
    }
    else {
        Track-Skipped "rust-analyzer" (Get-PackageDescription "rust-analyzer")
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
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","User") + ";" + [System.Environment]::GetEnvironmentVariable("Path","Machine")
}
