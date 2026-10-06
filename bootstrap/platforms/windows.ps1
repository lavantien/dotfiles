# Windows-specific installation functions for bootstrap script
# Supports: Scoop (preferred), winget

# Source parent libraries if not already loaded
if (-not (Get-Command -Name Test-Command -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\..\lib\common.ps1"
}
if (-not (Get-Command -Name Test-NeedsInstall -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\..\lib\version-check.ps1"
}

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
        "npm" { return "Node.js package manager" }
        "coursier" { return "JVM dependency manager" }

        # Core runtimes
        "git" { return "version control" }
        "llvm" { return "C/C++ toolchain" }
        "gcc" { return "C/C++ toolchain" }
        "node" { return "Node.js runtime" }
        "nodejs" { return "Node.js runtime" }
        "python" { return "Python runtime" }
        "go" { return "Go runtime" }
        "rust" { return "Rust toolchain" }
        "wezterm" { return "terminal emulator" }
        "dotnet" { return ".NET SDK" }
        "bun" { return "JavaScript runtime" }
        "OpenJDK" { return "Java development" }

        # Language servers
        "clangd" { return "C/C++ LSP" }
        "gopls" { return "Go LSP" }
        "rust-analyzer" { return "Rust LSP" }
        "pyright" { return "Python LSP" }
        "typescript-language-server" { return "TypeScript LSP" }
        "yaml-language-server" { return "YAML LSP" }
        "lua-language-server" { return "Lua LSP" }
        "csharp-ls" { return "C# LSP" }
        "intelephense" { return "PHP LSP" }
        "docker-langserver" { return "Docker LSP" }
        "tombi" { return "TOML LSP" }
        "tinymist" { return "Typst LSP" }

        # Linters & formatters
        "prettier" { return "code formatter" }
        "eslint" { return "JavaScript linter" }
        "ruff" { return "Python linter" }
        "black" { return "Python formatter" }
        "isort" { return "Python import sorter" }
        "mypy" { return "Python type checker" }
        "goimports" { return "Go import organizer" }
        "golangci-lint" { return "Go linter" }
        "cargo-update" { return "Cargo package updater" }
        "shellcheck" { return "Shell script analyzer" }
        "shfmt" { return "Shell script formatter" }
        "scalafmt" { return "Scala formatter" }
        "typos" { return "Spell checker" }
        "yamllint" { return "YAML linter" }
        "hadolint" { return "Dockerfile linter" }

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
        "btop-lhm" { return "system monitor" }
        "sqlite" { return "SQL database CLI" }
        "sqlite3" { return "SQL database CLI" }
        "jq" { return "JSON processor" }
        "yazi" { return "file manager" }
        "helm" { return "Kubernetes package manager" }
        "kubectl" { return "Kubernetes CLI" }
        "oh-my-posh" { return "prompt engine" }

        # Development tools
        "vscode" { return "code editor" }
        "visual-studio" { return "full IDE" }
        "latex" { return "document preparation" }
        "claude-code" { return "AI CLI" }
        "opencode" { return "AI CLI" }
        "ComfyUI" { return "AI image generation" }
        "mmdc" { return "Mermaid diagram generator" }

        default { return $Package }
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
        Write-WarningMsg ("Failed to install Scoop: {0}" -f $_.Exception.Message)
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

    # Get Scoop installation path - check both possible locations
    $scoopScript = "$env:USERPROFILE\scoop\apps\scoop\current\bin\scoop.ps1"
    $scoopInstalled = Test-Path $scoopScript

    # Check if scoop command is available
    $scoopCommandAvailable = Get-Command scoop -ErrorAction SilentlyContinue

    # Helper to invoke Scoop directly, bypassing the broken shim
    # The shim passes '-y' as first argument which breaks Scoop's command parsing
    # NOTE: If Get-FileHash is missing (PS 5.1 issue), use: pwsh -NoProfile -Command "& scoop.ps1 install <package>"
    function Invoke-Scoop {
        param([string[]]$Arguments)
        if ($scoopInstalled) {
            & $scoopScript @Arguments 2>&1
        }
        elseif ($scoopCommandAvailable) {
            # Fall back to scoop command
            scoop @Arguments 2>&1
        }
    }

    # Early return if command is already available (for idempotency and efficiency)
    if (-not (Test-NeedsInstall $CheckCmd $MinVersion)) {
        Track-Skipped $CheckCmd (Get-PackageDescription $CheckCmd)
        return $true
    }

    # Check if Scoop is available before attempting installation
    if (-not $scoopInstalled -and -not $scoopCommandAvailable -and -not $DryRun) {
        Write-WarningMsg "Scoop not installed, skipping $Package"
        Track-Failed $Package (Get-PackageDescription $Package)
        return $false
    }

    # Check if scoop already has this package installed (for idempotency)
    # Verify the command actually works by running it, don't just check if it exists
    # This catches cases where the package is "installed" but shim is broken
    if (-not $DryRun -and ($scoopInstalled -or $scoopCommandAvailable)) {
        $scoopList = Invoke-Scoop -Arguments "list"
        $scoopHasPackage = $scoopList | Where-Object { $_.Name -eq $Package }

        if ($scoopHasPackage -and (Test-Command $CheckCmd)) {
            # Verify by actually running the command (most support --version)
            $cmdWorks = $false
            try {
                $null = & $CheckCmd --version 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    $cmdWorks = $true
                }
            } catch {
                # Command doesn't support --version or failed to run
            }

            if ($cmdWorks) {
                Track-Skipped $Package (Get-PackageDescription $Package)
                return $true
            }
            # Command exists but doesn't work - continue to reinstall
        }
    }

    Write-Step "Installing $Package via Scoop..."
    if ($DryRun) {
        Write-Info "[DRY-RUN] Would install: $Package"
        Track-Installed $Package (Get-PackageDescription $Package)
        return $true
    }

    try {
        $output = Invoke-Scoop -Arguments @("install", $Package)
        # Check if scoop reported "already installed"
        $outputString = $output -join "`n"
        if ($outputString -match "already installed") {
            Track-Skipped $Package (Get-PackageDescription $Package)
        }
        else {
            Track-Installed $Package (Get-PackageDescription $Package)
        }
        # Refresh PATH so the newly installed tool can be found in subsequent checks
        Refresh-Path
        return $true
    }
    catch {
        Write-WarningMsg ("Failed to install {0}: {1}" -f $Package, $_.Exception.Message)
        Track-Failed $Package (Get-PackageDescription $Package)
        return $false
    }
}

# Install multiple Scoop packages at once
function Install-ScoopPackages {
    param(
        [string[]]$Packages
    )

    # Handle empty packages list
    if ($null -eq $Packages -or $Packages.Count -eq 0) {
        return $true
    }

    # Get Scoop installation path
    $scoopScript = "$env:USERPROFILE\scoop\apps\scoop\current\bin\scoop.ps1"
    $scoopInstalled = Test-Path $scoopScript

    # Check if scoop command is available
    $scoopCommandAvailable = Get-Command scoop -ErrorAction SilentlyContinue

    # Helper to invoke Scoop directly, bypassing the broken shim
    function Invoke-ScoopBulk {
        param([string[]]$Arguments)
        if ($scoopInstalled) {
            & $scoopScript @Arguments 2>&1
        }
        elseif ($scoopCommandAvailable) {
            # Fall back to scoop command
            scoop @Arguments 2>&1
        }
    }

    # Get list of packages already installed by scoop (for idempotency)
    # Skip this check in dry-run mode or when Scoop isn't actually installed
    $scoopList = if ($DryRun) { @() } elseif ($scoopInstalled -or $scoopCommandAvailable) { Invoke-ScoopBulk -Arguments "list" } else { @() }

    $toInstall = @()

    foreach ($pkg in $Packages) {
        # Check if scoop already has this package
        # Scoop list returns objects with Name property - check directly
        $alreadyInstalled = $scoopList | Where-Object { $_.Name -eq $pkg }

        if ($alreadyInstalled) {
            # Package installed by scoop - trust scoop's state and skip
            # Some packages (like TeX Live) don't create traditional shims
            Track-Skipped $pkg (Get-PackageDescription $pkg)
        }
        elseif (Test-NeedsInstall $pkg "") {
            $toInstall += $pkg
        }
        else {
            Track-Skipped $pkg (Get-PackageDescription $pkg)
        }
    }

    if ($toInstall.Count -gt 0) {
        # Check if Scoop is available before attempting installation
        if (-not $scoopInstalled -and -not $scoopCommandAvailable -and -not $DryRun) {
            Write-WarningMsg "Scoop not installed"
            foreach ($pkg in $toInstall) {
                Track-Failed $pkg (Get-PackageDescription $pkg)
            }
            return $false
        }

        Write-Step "Installing $($toInstall.Count) packages via Scoop..."
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would install: $($toInstall -join ', ')"
            foreach ($pkg in $toInstall) {
                Track-Installed $pkg (Get-PackageDescription $pkg)
            }
            return $true
        }

        try {
            $output = Invoke-ScoopBulk -Arguments (@("install") + $toInstall)
            # Refresh PATH so the newly installed tools can be found in subsequent checks
            Refresh-Path

            # Parse output to determine which packages were actually installed vs skipped
            foreach ($pkg in $toInstall) {
                if ($output -match "$pkg.*already installed" -or $output -match "'$pkg' is already installed") {
                    Track-Skipped $pkg (Get-PackageDescription $pkg)
                }
                else {
                    Track-Installed $pkg (Get-PackageDescription $pkg)
                }
            }
            return $true
        }
        catch {
            Write-WarningMsg ("Failed to install packages: {0}" -f $_.Exception.Message)
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

    # Get Scoop installation path
    $scoopScript = "$env:USERPROFILE\scoop\apps\scoop\current\bin\scoop.ps1"
    if (-not (Test-Path $scoopScript)) {
        return $false
    }

    $buckets = & $scoopScript bucket list 2>&1
    if ($Bucket -notin $buckets) {
        Write-Step "Adding Scoop bucket: $Bucket"
        & $scoopScript bucket add $Bucket *> $null
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

    Write-WarningMsg "winget not available (may need Windows update)"
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
        Write-WarningMsg "winget not available, skipping $DisplayName"
        return $false
    }

    # Extract package name from ID for check command
    if ([string]::IsNullOrEmpty($CheckCmd)) {
        $CheckCmd = ($Id -split '\.')[-1]
    }

    # Check if winget already has this package installed (for idempotency)
    # Skip the query in dry-run mode so no real winget invocation happens
    if (-not $DryRun) {
        $wingetList = winget list --id $Id --exact 2>&1
        if ($LASTEXITCODE -eq 0 -and $wingetList -match $Id) {
            # Package already installed by winget - trust winget's state
            Track-Skipped $DisplayName (Get-PackageDescription $DisplayName)
            return $true
        }
    }

    if (Test-NeedsInstall $CheckCmd $MinVersion) {
        Write-Step "Installing $DisplayName via winget..."
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would install: $Id"
            Track-Installed $DisplayName (Get-PackageDescription $DisplayName)
            return $true
        }

        try {
            $output = winget install --id $Id --exact --accept-source-agreements --accept-package-agreements 2>&1
            # winget exits nonzero without throwing on real failures
            if ($output -match "already installed") {
                Track-Skipped $DisplayName (Get-PackageDescription $DisplayName)
                return $true
            }
            if ($LASTEXITCODE -eq 0) {
                Track-Installed $DisplayName (Get-PackageDescription $DisplayName)
                return $true
            }
            Write-WarningMsg ("Failed to install {0}: {1}" -f $DisplayName, ($output -join " "))
            Track-Failed $DisplayName (Get-PackageDescription $DisplayName)
            return $false
        }
        catch {
            Write-WarningMsg ("Failed to install {0}: {1}" -f $DisplayName, $_.Exception.Message)
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
# WEZTERM
# ============================================================================
function Install-WezTerm {
    if (Test-Command wezterm) {
        Track-Skipped "wezterm" "terminal emulator"
        return $true
    }

    Write-Step "Installing WezTerm via winget..."
    if ($DryRun) {
        Write-Info "[DRY-RUN] Would install WezTerm"
        Track-Installed "wezterm" "terminal emulator"
        return $true
    }

    try {
        $output = winget install --id wez.wezterm --exact --accept-source-agreements --accept-package-agreements 2>&1
        if ($LASTEXITCODE -eq 0 -or $output -match "already installed") {
            Track-Installed "wezterm" "terminal emulator"
            Write-Success "WezTerm installed"
            return $true
        }
        else {
            Write-WarningMsg "winget output: $output"
            Track-Failed "wezterm" "terminal emulator"
            return $false
        }
    }
    catch {
        Write-WarningMsg "Failed to install WezTerm: $_"
        Track-Failed "wezterm" "terminal emulator"
        return $false
    }
}

# ============================================================================
# NERD FONT (IosevkaTerm for WezTerm)
# ============================================================================
function Test-NerdFontInstalled {
    # NF file names carry the NerdFont infix (IosevkaTermNerdFont-Regular.ttf,
    # IosevkaTermNerdFontMono-*.ttf). Plain IosevkaTerm variants have no nerd
    # glyphs and must not satisfy the check, or WezTerm keeps rendering tofu.
    param([string]$FontFile = "IosevkaTermNerdFont")

    $fontDirs = @(
        (Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"),
        "$env:WINDIR\Fonts"
    )
    foreach ($dir in $fontDirs) {
        if (Test-Path $dir) {
            if (Get-ChildItem $dir -Filter "$FontFile*.ttf" -ErrorAction SilentlyContinue) {
                return $true
            }
        }
    }

    $fontsReg = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
    if (Test-Path $fontsReg) {
        # Registry names use the spaced display name ("IosevkaTerm Nerd Font"),
        # file-backed entries keep the unspaced base name
        $props = (Get-ItemProperty $fontsReg).PSObject.Properties.Name
        $displayName = $FontFile -replace 'NerdFont', ' Nerd Font'
        if ($props -match "$FontFile" -or $props -match $displayName) {
            return $true
        }
    }

    return $false
}

function Install-NerdFont {
    # WezTerm's config expects IosevkaTerm Nerd Font glyphs; without them the
    # terminal renders tofu. Primary: scoop nerd-fonts bucket (the live alias
    # for matthewjberger/scoop-nerd-fonts, no winget package exists).
    # Fallback: per-user copy from the official release plus HKCU registration.
    param(
        [string]$FontName = "IosevkaTerm-NF",
        [string]$ZipName = "IosevkaTerm"
    )

    if (Test-NerdFontInstalled) {
        Write-VerboseInfo "IosevkaTerm Nerd Font already installed"
        Track-Skipped $FontName "Nerd Font"
        return $true
    }

    Write-Step "Installing $FontName Nerd Font..."
    if ($DryRun) {
        Write-Info "[DRY-RUN] Would install: $FontName"
        Track-Installed $FontName "Nerd Font"
        return $true
    }

    Add-ScoopBucket "nerd-fonts"
    $null = Install-ScoopPackage $FontName "" ""
    if (Test-NerdFontInstalled) {
        Track-Installed $FontName "Nerd Font"
        return $true
    }

    try {
        $url = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$ZipName.zip"
        $zipPath = Join-Path $env:TEMP "$ZipName.zip"
        $extractDir = Join-Path $env:TEMP "$ZipName-fonts"
        Invoke-WebRequest -Uri $url -OutFile $zipPath
        Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

        $userFontDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
        New-Item -ItemType Directory -Path $userFontDir -Force | Out-Null
        $fontsReg = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
        if (-not (Test-Path $fontsReg)) {
            New-Item -Path $fontsReg -Force | Out-Null
        }
        Get-ChildItem $extractDir -Filter "*.ttf" | ForEach-Object {
            $dest = Join-Path $userFontDir $_.Name
            Copy-Item $_.FullName $dest -Force
            New-ItemProperty -Path $fontsReg -Name "$($_.BaseName) (TrueType)" -Value $dest -PropertyType String -Force | Out-Null
        }
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue

        if (Test-NerdFontInstalled) {
            Track-Installed $FontName "Nerd Font"
            Write-Info "Restart WezTerm to pick up the new font"
            return $true
        }
        Write-WarningMsg "$FontName install finished but the font is still not detectable"
        Write-Info "Install IosevkaTerm Nerd Font manually from: https://www.nerdfonts.com/font-downloads"
        Track-Failed $FontName "Nerd Font"
        return $false
    }
    catch {
        Write-WarningMsg ("Failed to install {0}: {1}" -f $FontName, $_.Exception.Message)
        Write-Info "Install IosevkaTerm Nerd Font manually from: https://www.nerdfonts.com/font-downloads"
        Track-Failed $FontName "Nerd Font"
        return $false
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
        Write-WarningMsg "npm not found, skipping $Package"
        Track-Failed $Package (Get-PackageDescription $Package)
        return $false
    }

    # Check if package needs install or update using version check
    $needsUpdate = Test-NpmPackageNeedsUpdate -Package $Package
    if ($needsUpdate) {
        Write-Step "Installing $Package via npm..."
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would npm install -g $Package"
            Track-Installed $Package (Get-PackageDescription $Package)
            return $true
        }

        try {
            $output = npm install -g $Package 2>&1
            if ($LASTEXITCODE -eq 0) {
                Track-Installed $Package (Get-PackageDescription $Package)
                return $true
            }
            else {
                Write-WarningMsg ("Failed to install {0}: {1}" -f $Package, $output)
                Track-Failed $Package (Get-PackageDescription $Package)
                return $false
            }
        }
        catch {
            Write-WarningMsg ("Failed to install {0}: {1}" -f $Package, $_.Exception.Message)
            Track-Failed $Package (Get-PackageDescription $Package)
            return $false
        }
    }
    else {
        Write-VerboseInfo "$Package already at latest version"
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
        Write-WarningMsg "go not found, skipping $Package"
        Track-Failed $Package (Get-PackageDescription $Package)
        return $false
    }

    # Get GOPATH and ensure it's in PATH (for current session + persist)
    # Skip in DryRun mode to avoid calling external go command
    $goPath = if ($DryRun) { "" } else { go env GOPATH }
    if ($goPath) {
        # Normalize path (convert forward slashes to backslashes, remove trailing slashes)
        $goPath = $goPath -replace '[\\/]', '\'
        $goPath = $goPath.TrimEnd('\')
        $goPathBin = "$goPath\bin"

        # Persist to User PATH for future sessions (check if already in registry PATH)
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if (($userPath -split ';') -notcontains $goPathBin) {
            Add-ToPath $goPathBin
        }

        # Always add to current session PATH so we can find commands immediately
        $env:PATH = "$goPathBin;$env:PATH"
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
            Write-WarningMsg "gup install failed, falling back to go install..."
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
        Write-WarningMsg ("Failed to install {0}: {1}" -f $Package, $_.Exception.Message)
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
        Write-WarningMsg "cargo not found, skipping $Package"
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
            Write-WarningMsg ("Failed to install {0}: {1}" -f $Package, $_.Exception.Message)
            Track-Failed $Package (Get-PackageDescription $Package)
            return $false
        }
    }
    else {
        Track-Skipped $CmdName (Get-PackageDescription $CmdName)
        return $true
    }
}

# Install cargo-update (package manager for cargo-installed tools)
function Install-CargoUpdate {
    if (Get-Command cargo-install-update -ErrorAction SilentlyContinue) {
        Track-Skipped "cargo-update" (Get-PackageDescription "cargo-update")
        return $true
    }

    if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
        Write-WarningMsg "cargo not found, skipping cargo-update"
        Track-Failed "cargo-update" (Get-PackageDescription "cargo-update")
        return $false
    }

    Write-Step "Installing cargo-update..."
    if ($DryRun) {
        Write-Info "[DRY-RUN] Would cargo install cargo-update"
        Track-Installed "cargo-update" (Get-PackageDescription "cargo-update")
        return $true
    }

    try {
        cargo install cargo-update *> $null
        Add-ToPath "$env:USERPROFILE\.cargo\bin"
        Track-Installed "cargo-update" (Get-PackageDescription "cargo-update")
        return $true
    }
    catch {
        Write-WarningMsg ("Failed to install cargo-update: {0}" -f $_.Exception.Message)
        Track-Failed "cargo-update" (Get-PackageDescription "cargo-update")
        return $false
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

    # Fallback to command name (may be in PATH)
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
        # Coursier is available via scoop - use direct path to avoid broken shim
        $scoopScript = "$env:USERPROFILE\scoop\apps\scoop\current\bin\scoop.ps1"
        if (Test-Path $scoopScript) {
            & $scoopScript install coursier *> $null
            # Refresh PATH for current session (uses safe Refresh-Path from common.ps1)
            Refresh-Path
            Track-Installed "coursier" (Get-PackageDescription "coursier")
            return $true
        }
        else {
            Write-WarningMsg "Scoop not found, cannot install Coursier"
            Track-Failed "coursier" (Get-PackageDescription "coursier")
            return $false
        }
    }
    catch {
        Write-WarningMsg ("Failed to install Coursier: {0}" -f $_.Exception.Message)
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
        Write-WarningMsg "Coursier not installed, skipping $Package"
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
            Write-WarningMsg ("Failed to install {0}: {1}" -f $Package, $_.Exception.Message)
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
        Write-WarningMsg "Python not found, skipping $Package"
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
            Write-WarningMsg ("Failed to install {0}: {1}" -f $Package, $_.Exception.Message)
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
        Write-WarningMsg "dotnet not found, skipping $Package"
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
                Write-WarningMsg ("Failed to install {0}: {1}" -f $Package, $_.Exception.Message)
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
        Write-Step "Checking Rust..."
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would check Rust version"
            Track-Skipped "rust" (Get-PackageDescription "rust")
            return $true
        }

        try {
            # Check for rustup update
            $output = rustup update 2>&1
            $exitCode = $LASTEXITCODE

            if ($exitCode -eq 0) {
                # Show relevant output
                $output | Where-Object { $_ -notmatch '^\s*$' -and $_ -notmatch '^Updating|Downloading|Installing|Installed' } | Select-Object -First 10 | ForEach-Object { Write-Info $_ }
                Write-Success "rust (updated)"
                $script:updated++
            }
            else {
                # Already up to date or error
                if ($output -match 'is up to date|already installed') {
                    Write-Success "rust (up to date)"
                    $script:updated++
                }
                else {
                    Write-Success "rust"
                    $script:updated++
                }
            }
            return $true
        }
        catch {
            Write-Success "rust"
            $script:updated++
            return $true
        }
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
        Write-WarningMsg ("Failed to install Rust: {0}" -f $_.Exception.Message)
        Track-Failed "rust" (Get-PackageDescription "rust")
        return $false
    }
}

function Install-RustAnalyzerComponent {
    if (-not (Get-Command rustup -ErrorAction SilentlyContinue)) {
        Write-WarningMsg "rustup not found, skipping rust-analyzer"
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
            Write-WarningMsg ("Failed to add rust-analyzer: {0}" -f $_.Exception.Message)
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
# BUN
# ============================================================================
function Install-Bun {
    if (Get-Command bun -ErrorAction SilentlyContinue) {
        Write-Step "Checking Bun..."
        if ($DryRun) {
            Write-Success "bun (up to date)"
            Track-Skipped "bun" (Get-PackageDescription "bun")
            return $true
        }

        try {
            # Check for bun upgrade
            $output = bun upgrade 2>&1
            $exitCode = $LASTEXITCODE

            if ($output -match "already on the latest version|up to date") {
                Write-Success "bun (up to date)"
                Track-Skipped "bun" (Get-PackageDescription "bun")
            }
            else {
                # Show relevant output
                $output | Where-Object { $_ -notmatch '^\s*$' } | Select-Object -First 5 | ForEach-Object { Write-Info $_ }
                Write-Success "bun (updated)"
                # Refresh PATH after upgrade
                Add-ToPath "$env:USERPROFILE\.bun\bin"
                Refresh-Path
                Track-Skipped "bun" (Get-PackageDescription "bun")
            }
            return $true
        }
        catch {
            Write-Success "bun (up to date)"
            Track-Skipped "bun" (Get-PackageDescription "bun")
            return $true
        }
    }

    Write-Step "Installing Bun..."
    if ($DryRun) {
        Write-Info "[DRY-RUN] Would install Bun via official script"
        Track-Installed "bun" (Get-PackageDescription "bun")
        return $true
    }

    try {
        pwsh -c "irm bun.sh/install.ps1|iex"
        # Bun installs to %USERPROFILE%\.bun\bin
        Add-ToPath "$env:USERPROFILE\.bun\bin"
        Refresh-Path
        Track-Installed "bun" (Get-PackageDescription "bun")
        return $true
    }
    catch {
        Write-WarningMsg ("Failed to install Bun: {0}" -f $_.Exception.Message)
        Track-Failed "bun" (Get-PackageDescription "bun")
        return $false
    }
}

# ============================================================================
# PATH MANAGEMENT
# ============================================================================
# Add-ToPath is now sourced from common.ps1 with safety checks for empty User PATH
# Refresh-Path is now sourced from common.ps1 with safety checks
