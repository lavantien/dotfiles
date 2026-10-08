
if (-not (Get-Command -Name Test-Command -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\..\lib\common.ps1"
}
if (-not (Get-Command -Name Test-NeedsInstall -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\..\lib\version-check.ps1"
}

function Configure-GitSettings {

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

    $currentAttrs = git config --global core.attributesfile 2>$null
    if ([string]::IsNullOrEmpty($currentAttrs)) {

        Write-Info "Repo .gitattributes will enforce line endings"
    }

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

function Get-PackageDescription {
    param([string]$Package)
    switch ($Package) {

        "scoop" { return "package manager" }
        "winget" { return "Windows package manager" }
        "npm" { return "Node.js package manager" }
        "coursier" { return "JVM dependency manager" }

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

        "clangd" { return "C/C++ LSP" }
        "gopls" { return "Go LSP" }
        "rust-analyzer" { return "Rust LSP" }
        "pyright" { return "Python LSP" }
        "typescript-language-server" { return "TypeScript LSP" }
        "yaml-language-server" { return "YAML LSP" }
        "lua-language-server" { return "Lua LSP" }
        "csharp-ls" { return "C# LSP" }
        "intelephense" { return "PHP LSP" }
        "tombi" { return "TOML LSP" }
        "tinymist" { return "Typst LSP" }

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

    $scoopScript = "$env:USERPROFILE\scoop\apps\scoop\current\bin\scoop.ps1"
    $scoopInstalled = Test-Path $scoopScript

    $scoopCommandAvailable = Get-Command scoop -ErrorAction SilentlyContinue

    function Invoke-Scoop {
        param([string[]]$Arguments)
        if ($scoopInstalled) {
            & $scoopScript @Arguments 2>&1
        }
        elseif ($scoopCommandAvailable) {

            scoop @Arguments 2>&1
        }
    }

    if (-not (Test-NeedsInstall $CheckCmd $MinVersion)) {
        Track-Skipped $CheckCmd (Get-PackageDescription $CheckCmd)
        return $true
    }

    if (-not $scoopInstalled -and -not $scoopCommandAvailable -and -not $DryRun) {
        Write-WarningMsg "Scoop not installed, skipping $Package"
        Track-Failed $Package (Get-PackageDescription $Package)
        return $false
    }

    if (-not $DryRun -and ($scoopInstalled -or $scoopCommandAvailable)) {
        $scoopList = Invoke-Scoop -Arguments "list"
        $scoopHasPackage = $scoopList | Where-Object { $_.Name -eq $Package }

        if ($scoopHasPackage -and (Test-Command $CheckCmd)) {

            $cmdWorks = $false
            try {
                $null = & $CheckCmd --version 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    $cmdWorks = $true
                }
            } catch {

            }

            if ($cmdWorks) {
                Track-Skipped $Package (Get-PackageDescription $Package)
                return $true
            }

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

        $outputString = $output -join "`n"
        if ($outputString -match "already installed") {
            Track-Skipped $Package (Get-PackageDescription $Package)
        }
        else {
            Track-Installed $Package (Get-PackageDescription $Package)
        }

        Refresh-Path
        return $true
    }
    catch {
        Write-WarningMsg ("Failed to install {0}: {1}" -f $Package, $_.Exception.Message)
        Track-Failed $Package (Get-PackageDescription $Package)
        return $false
    }
}

function Install-ScoopPackages {
    param(
        [string[]]$Packages
    )

    if ($null -eq $Packages -or $Packages.Count -eq 0) {
        return $true
    }

    $scoopScript = "$env:USERPROFILE\scoop\apps\scoop\current\bin\scoop.ps1"
    $scoopInstalled = Test-Path $scoopScript

    $scoopCommandAvailable = Get-Command scoop -ErrorAction SilentlyContinue

    function Invoke-ScoopBulk {
        param([string[]]$Arguments)
        if ($scoopInstalled) {
            & $scoopScript @Arguments 2>&1
        }
        elseif ($scoopCommandAvailable) {

            scoop @Arguments 2>&1
        }
    }

    $scoopList = if ($DryRun) { @() } elseif ($scoopInstalled -or $scoopCommandAvailable) { Invoke-ScoopBulk -Arguments "list" } else { @() }

    $toInstall = @()

    foreach ($pkg in $Packages) {

        $alreadyInstalled = $scoopList | Where-Object { $_.Name -eq $pkg }

        if ($alreadyInstalled) {

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

            Refresh-Path

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

function Add-ScoopBucket {
    param([string]$Bucket)

    if ($DryRun) {
        Write-Info "[DRY-RUN] Would add bucket: $Bucket"
        return $true
    }

    $scoopScript = "$env:USERPROFILE\scoop\apps\scoop\current\bin\scoop.ps1"
    if (-not (Test-Path $scoopScript)) {
        return $false
    }

    $bucketPath = "$env:USERPROFILE\scoop\buckets\$Bucket"
    if (-not (Test-Path $bucketPath)) {
        Write-Step "Adding Scoop bucket: $Bucket"
        & $scoopScript bucket add $Bucket *> $null
    }
}

function Ensure-Winget {

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

    if ([string]::IsNullOrEmpty($CheckCmd)) {
        $CheckCmd = ($Id -split '\.')[-1]
    }

    if (-not $DryRun) {
        $wingetList = winget list --id $Id --exact 2>&1
        if ($LASTEXITCODE -eq 0 -and $wingetList -match $Id) {

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

function Test-NerdFontInstalled {

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

        $props = (Get-ItemProperty $fontsReg).PSObject.Properties.Name
        $displayName = $FontFile -replace 'NerdFont', ' Nerd Font'
        if ($props -match "$FontFile" -or $props -match $displayName) {
            return $true
        }
    }

    return $false
}

function Install-NerdFont {

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

    $goPath = if ($DryRun) { "" } else { go env GOPATH }
    if ($goPath) {
        $goPath = $goPath -replace '[\\/]', '\'
        $goPath = $goPath.TrimEnd('\')
        $goPathBin = "$goPath\bin"

        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if (($userPath -split ';') -notcontains $goPathBin) {
            Add-ToPath $goPathBin
        }

        $env:PATH = "$goPathBin;$env:PATH"
    }

    if (Get-Command $CmdName -ErrorAction SilentlyContinue) {
        Track-Skipped $CmdName (Get-PackageDescription $CmdName)
        return $true
    }

    $clean = ($Package -split '@')[0]
    Write-Step "Installing $clean via go..."
    if ($DryRun) {
        Write-Info "[DRY-RUN] Would go install $clean@latest"
        Track-Installed $clean (Get-PackageDescription $clean)
        return $true
    }

    go install "$clean@latest" *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-WarningMsg "Failed to install $clean"
        Track-Failed $clean (Get-PackageDescription $clean)
        return $false
    }

    Track-Installed $clean (Get-PackageDescription $clean)
    return $true
}

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

function Test-CoursierInstalled {

    $scoopShim = Join-Path $env:USERPROFILE "scoop\shims\coursier.cmd"
    if (Test-Path $scoopShim) {
        return $true
    }

    $csBin = Join-Path $env:USERPROFILE ".local\share\coursier\bin\cs.exe"
    if (Test-Path $csBin) {
        return $true
    }

    if (Get-Command cs -ErrorAction SilentlyContinue) {
        return $true
    }

    if (Get-Command coursier -ErrorAction SilentlyContinue) {
        return $true
    }

    return $false
}

function Get-CoursierExe {

    $scoopShim = Join-Path $env:USERPROFILE "scoop\shims\coursier.cmd"
    if (Test-Path $scoopShim) {
        return $scoopShim
    }

    $csBin = Join-Path $env:USERPROFILE ".local\share\coursier\bin\cs.exe"
    if (Test-Path $csBin) {
        return $csBin
    }

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

        $scoopScript = "$env:USERPROFILE\scoop\apps\scoop\current\bin\scoop.ps1"
        if (Test-Path $scoopScript) {
            & $scoopScript install coursier *> $null

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

            $csExe = Get-CoursierExe
            & $csExe install $Package *> $null

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

function Install-Rustup {
    if (Get-Command rustup -ErrorAction SilentlyContinue) {
        Write-Step "Checking Rust..."
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would check Rust version"
            Track-Skipped "rust" (Get-PackageDescription "rust")
            return $true
        }

        try {

            $output = rustup update 2>&1
            $exitCode = $LASTEXITCODE

            if ($exitCode -eq 0) {

                $output | Where-Object { $_ -notmatch '^\s*$' -and $_ -notmatch '^Updating|Downloading|Installing|Installed' } | Select-Object -First 10 | ForEach-Object { Write-Info $_ }
                Write-Success "rust (updated)"
                $script:updated++
            }
            else {

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

        $rustupUrl = "https://win.rustup.rs/x86_64"
        $rustupPath = "$env:TEMP\rustup-init.exe"
        Invoke-WebRequest -Uri $rustupUrl -OutFile $rustupPath
        & $rustupPath -y
        Remove-Item $rustupPath

        Add-ToPath "$env:USERPROFILE\.cargo\bin"

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

function Install-Bun {
    if (Get-Command bun -ErrorAction SilentlyContinue) {
        Write-Step "Checking Bun..."
        if ($DryRun) {
            Write-Success "bun (up to date)"
            Track-Skipped "bun" (Get-PackageDescription "bun")
            return $true
        }

        try {

            $output = bun upgrade 2>&1
            $exitCode = $LASTEXITCODE

            if ($output -match "already on the latest version|up to date") {
                Write-Success "bun (up to date)"
                Track-Skipped "bun" (Get-PackageDescription "bun")
            }
            else {

                $output | Where-Object { $_ -notmatch '^\s*$' } | Select-Object -First 5 | ForEach-Object { Write-Info $_ }
                Write-Success "bun (updated)"

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
