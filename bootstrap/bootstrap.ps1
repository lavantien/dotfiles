# Universal Bootstrap Script for Windows
# Installs and configures development environment on Windows 10/11
#
# VERSION POLICY:
#   All packages are installed or updated to their LATEST versions
#   No hardcoded version numbers - always gets the newest stable release
#   Run bootstrap again to update all tools to latest versions
#
# BRIDGE APPROACH:
#   - Works without config file (uses hardcoded defaults - backward compatible)
#   - Loads config file if present (~/.dotfiles.config.yaml) - forward compatible
#   - Config library is optional - scripts work even if it's missing
#   - Defaults: categories="full", interactive=true, no dry-run
#
# Usage:
#   .\bootstrap.ps1 [options]
#
# Options:
#   -Y                Non-interactive mode (accept all prompts)
#   -DryRun           Show what would be installed without installing
#   -Categories       minimal|sdk|full (default: full)
#   -SkipUpdate       Skip updating package managers first
#   -VerboseMode      Show detailed output including skipped items
#   -Help             Show this help

[CmdletBinding()]
param(
    [switch]$Y = $false,
    [switch]$DryRun = $false,
    [string]$Categories = "full",
    [switch]$SkipUpdate = $false,
    [switch]$VerboseMode = $false
)

# ============================================================================
# SCRIPT SETUP
# ============================================================================
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LibDir = Join-Path $ScriptDir "lib"
$PlatformsDir = Join-Path $ScriptDir "platforms"

# Source library functions
. "$LibDir\common.ps1"
. "$LibDir\version-check.ps1"

# Source config library (optional - for custom configuration)
$ConfigLibPath = Join-Path $ScriptDir "..\lib\config.ps1"
if (Test-Path $ConfigLibPath) {
    . "$ConfigLibPath"
}

# Source platform-specific functions
. "$PlatformsDir\windows.ps1"

# Set global options from parameters
$Script:Interactive = -not $Y
$Script:DryRun = $DryRun
$Script:Categories = $Categories
$Script:Verbose = $VerboseMode

# ============================================================================
# SHOW HELP
# ============================================================================
function Show-Help {
    Get-Content $ScriptDir\bootstrap.ps1 | Select-String -Pattern '^#' | Select-Object -First 25 | ForEach-Object {
        $_.Line -replace '^# ', ''
    }
}

# PHP and Composer are not supported on Windows - use Unix/Linux or WSL for PHP development

# ============================================================================
# PHASE 1: FOUNDATION
# ============================================================================
function Install-Foundation {
    Write-Header "Phase 1: Foundation"

    # Ensure git is installed first (needed for Scoop and Git Bash for .sh wrapper scripts)
    # Try winget first since it includes Git Bash which is required for .sh script invocation via .ps1 wrappers
    if (-not (Test-Command git)) {
        Write-Step "Installing git (includes Git Bash for .sh scripts)..."
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would install Git for Windows via winget"
            Track-Installed "git" "version control"
        }
        else {
            $gitInstalled = $false
            # Try winget first (preferred - comes with Windows, includes Git Bash)
            if (Get-Command winget -ErrorAction SilentlyContinue) {
                try {
                    winget install --id Git.Git --accept-source-agreements --accept-package-agreements *> $null
                    if (Test-Command git) {
                        Write-Success "Git installed via winget"
                        Track-Installed "git" "version control"
                        $gitInstalled = $true
                        # Refresh PATH for current session
                        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
                    }
                }
                catch {
                    Write-Warning "winget install failed: $_"
                }
            }

            # Fall back to Scoop if winget failed or wasn't available
            if (-not $gitInstalled) {
                if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
                    Write-Info "Installing Scoop first..."
                    Ensure-Scoop
                }
                Install-ScoopPackage "git" "" "git"
            }
        }
    }
    else {
        Write-VerboseInfo "git already installed"
        Track-Skipped "git" "version control"
    }

    # Ensure Scoop is installed
    Ensure-Scoop

    # Ensure Scoop shims are in PATH for current session
    # Scoop adds shims to PATH in shell profiles, but current session doesn't have it yet
    $scoopShims = Join-Path $env:USERPROFILE "scoop\shims"
    if ((Test-Path $scoopShims) -and ($env:Path -notlike "*$scoopShims*")) {
        $env:Path = "$scoopShims;$env:Path"
    }

    # Configure git and add GitHub to known_hosts
    Configure-GitSettings

    Write-Success "Foundation complete"
    return $true
}

# ============================================================================
# PHASE 2: CORE SDKS
# ============================================================================
function Install-SDKs {
    if ($Script:Categories -eq "minimal") {
        return $true
    }

    Write-Header "Phase 2: Core SDKs"

    # Node.js (always installs latest LTS)
    Install-ScoopPackage "nodejs-lts" "" "node"

    # Python (always installs latest)
    Install-ScoopPackage "python" "" "python"

    # Go (always installs latest)
    if ($Script:Categories -ne "minimal") {
        Install-ScoopPackage "go" "" "go"
    }

    # Rust
    if ($Script:Categories -eq "full") {
        Install-Rustup
    }

    # dotnet SDK
    if ($Script:Categories -eq "full") {
        # Try winget first (preferred for dotnet)
        if (-not (Test-Command dotnet)) {
            Write-Step "Installing dotnet SDK via winget..."
            if (-not $DryRun) {
                winget install --id Microsoft.DotNet.SDK.8 --accept-source-agreements --accept-package-agreements *> $null
                Track-Installed "dotnet" ".NET SDK"
            }
            else {
                Write-Info "[DRY-RUN] Would install dotnet SDK via winget"
                Track-Installed "dotnet" ".NET SDK"
            }
        }
        else {
            Write-VerboseInfo "dotnet already installed"
            Track-Skipped "dotnet" ".NET SDK"
        }
    }

    # OpenJDK
    if ($Script:Categories -eq "full") {
        # Try winget first (preferred for JDK)
        if (-not (Test-Command javac)) {
            Write-Step "Installing OpenJDK via winget..."
            if (-not $DryRun) {
                winget install --id Microsoft.OpenJDK.21 --accept-source-agreements --accept-package-agreements *> $null
                Track-Installed "OpenJDK" "Java development"
            }
            else {
                Write-Info "[DRY-RUN] Would install OpenJDK via winget"
                Track-Installed "OpenJDK" "Java development"
            }
        }
        else {
            Write-VerboseInfo "OpenJDK already installed"
            Track-Skipped "OpenJDK" "Java development"
        }
    }

    Write-Success "SDKs installation complete"
    return $true
}

# ============================================================================
# PHASE 3: LANGUAGE SERVERS
# ============================================================================
function Install-LanguageServers {
    if ($Script:Categories -eq "minimal") {
        return $true
    }

    Write-Header "Phase 3: Language Servers"

    # clangd (includes clang-format, clang-tidy)
    Install-ScoopPackage "llvm" "" "clangd"

    # gopls (via go install - always latest)
    if ((Test-Command go) -and $Script:Categories -eq "full") {
        Install-GoPackage "golang.org/x/tools/gopls@latest" "gopls" ""
    }

    # rust-analyzer (via rustup)
    if ($Script:Categories -eq "full") {
        Install-RustAnalyzerComponent
    }

    # pyright (via npm - always latest)
    if (Test-Command npm) {
        Install-NpmGlobal "pyright" "pyright" ""
    }

    # TypeScript language server (via npm - always latest)
    if (Test-Command npm) {
        Install-NpmGlobal "typescript-language-server" "typescript-language-server" ""
    }

    # HTML language server (via npm - always latest)
    if (Test-Command npm) {
        Install-NpmGlobal "vscode-html-languageserver-bin" "vscode-html-language-server" ""
    }

    # CSS language server (via npm - always latest)
    if (Test-Command npm) {
        Install-NpmGlobal "vscode-css-languageserver-bin" "vscode-css-language-server" ""
    }

    # Svelte language server (via npm - full category)
    if ($Script:Categories -eq "full" -and (Test-Command npm)) {
        Install-NpmGlobal "svelte-language-server" "svelte-language-server" ""
    }

    # bash-language-server (via npm - always latest)
    if (Test-Command npm) {
        Install-NpmGlobal "bash-language-server" "bash-language-server" ""
    }

    # YAML language server (via npm - always latest)
    if (Test-Command npm) {
        Install-NpmGlobal "yaml-language-server" "yaml-language-server" ""
    }

    # lua-language-server (via scoop - npm version has issues)
    if ($Script:Categories -eq "full") {
        Install-ScoopPackage "lua-language-server" "" "lua-language-server"
    }

    # csharp-ls (via dotnet tool)
    if ($Script:Categories -eq "full" -and (Test-Command dotnet)) {
        Install-DotnetTool "csharp-ls" "csharp-ls" ""
    }

    # jdtls (Java Language Server) - part of eclipse.jdt.ls
    # Note: jdtls is typically installed by IDEs or via scoop
    if ($Script:Categories -eq "full") {
        # Try scoop first
        Install-ScoopPackage "jdtls" "" "jdtls"
    }

    # intelephense (PHP language server) - not supported on Windows, use Unix/Linux or WSL

    # Docker language servers (via npm - always latest)
    if (Test-Command npm) {
        # dockerfile-language-server (binary: docker-langserver)
        if (Test-Command npm) {
            Install-NpmGlobal "dockerfile-language-server-nodejs" "docker-langserver" ""
        }
        # Note: @microsoft/compose-language-service has no binary, skip version check
    }

    # tombi (TOML language server via npm - always latest)
    if (Test-Command npm) {
        Install-NpmGlobal "tombi" "tombi" ""
    }

    # dartls (Dart language server - requires Dart SDK)
    # Note: Dart SDK must be installed separately from https://dart.dev/get-dart
    # This is optional and not installed by default

    # tinymist (Typst language server via npm - always latest)
    if ($Script:Categories -eq "full" -and (Test-Command npm)) {
        Install-NpmGlobal "tinymist" "tinymist" ""
    }

    Write-Success "Language servers installation complete"
    return $true
}

# ============================================================================
# PHASE 4: LINTERS & FORMATTERS
# ============================================================================
function Install-LintersFormatters {
    if ($Script:Categories -eq "minimal") {
        return $true
    }

    Write-Header "Phase 4: Linters & Formatters"

    # Prettier (via npm - always latest)
    if (Test-Command npm) {
        Install-NpmGlobal "prettier" "prettier" ""
    }

    # ESLint (via npm - always latest)
    if (Test-Command npm) {
        Install-NpmGlobal "eslint" "eslint" ""
    }

    # Stylelint (CSS/SCSS linter via npm - always latest)
    if (Test-Command npm) {
        Install-NpmGlobal "stylelint" "stylelint" ""
    }

    # svelte-check (Svelte type checker via npm - full category)
    if ($Script:Categories -eq "full" -and (Test-Command npm)) {
        Install-NpmGlobal "svelte-check" "svelte-check" ""
    }

    # repomix (Pack repositories for AI exploration via npm - full category)
    if ($Script:Categories -eq "full" -and (Test-Command npm)) {
        Install-NpmGlobal "repomix" "repomix" ""
    }

    # Ruff (via pip - always latest)
    if (Test-Command python) {
        Install-PipGlobal "ruff" "ruff" ""
    }

    # Additional Python tools (for full compatibility with git hooks - always latest)
    if ($Script:Categories -eq "full" -and (Test-Command python)) {
        Install-PipGlobal "black" "black" ""
        Install-PipGlobal "isort" "isort" ""
        Install-PipGlobal "mypy" "mypy" ""
        Install-PipGlobal "pytest" "pytest" ""
    }

    # gup (Go package manager - always latest)
    if ((Test-Command go) -and (-not (Test-Command gup))) {
        Install-GoPackage "nao.vi/gup@latest" "gup" ""
    }

    # goimports (via gup if available, otherwise go install - always latest)
    if (Test-Command go) {
        Install-GoPackage "golang.org/x/tools/cmd/goimports@latest" "goimports" ""
    }

    # golangci-lint (always latest)
    if (Test-Command go) {
        Install-ScoopPackage "golangci-lint" "" "golangci-lint"
    }

    # Shell tools (for Git Bash on Windows)
    if ($Script:Categories -eq "full") {
        Install-ScoopPackage "shellcheck" "" "shellcheck"
        # shfmt via scoop
        Install-ScoopPackage "shfmt" "" "shfmt"
    }

    # cppcheck (C++ static analysis)
    if ($Script:Categories -eq "full") {
        Install-ScoopPackage "cppcheck" "" "cppcheck"
    }

    # catch2 (C++ testing framework)
    if ($Script:Categories -eq "full") {
        # catch2 available via vcpkg, not scoop
        # Skip for now - users can install via vcpkg if needed
    }

    # PHP and Composer tooling (Laravel Pint, PHPStan, Psalm) are not supported on Windows
    # Use Unix/Linux or WSL for PHP development

    # scalafmt (via Coursier - Scala tool, NOT available via cargo)
    if ($Script:Categories -eq "full") {
        # Ensure Coursier is installed first
        Ensure-Coursier
        Install-CoursierPackage "scalafmt" "" "scalafmt"
    }

    # scalafix (Scala linter via coursier)
    if ($Script:Categories -eq "full") {
        Ensure-Coursier
        if (Test-Command coursier) {
            Install-CoursierPackage "scalafix" "" "scalafix"
        }
    }

    # Metals (Scala language server via coursier)
    if ($Script:Categories -eq "full") {
        Ensure-Coursier
        if (Test-Command coursier) {
            Install-CoursierPackage "metals" "" "metals"
        }
    }

    # stylua (Lua formatter)
    if ($Script:Categories -eq "full") {
        Install-ScoopPackage "stylua" "" "stylua"
    }

    # selene (Lua linter)
    if ($Script:Categories -eq "full") {
        Install-ScoopPackage "selene" "" "selene"
    }

    # checkstyle (Java linter)
    if ($Script:Categories -eq "full") {
        # checkstyle not typically installed globally on Windows
        # Use via IDE or build tools (Maven/Gradle)
        # Comment added for documentation purposes
    }

    # clang-tidy (for C/C++) - already installed with LLVM
    # clang-format is also from LLVM

    Write-Success "Linters & formatters installation complete"
    return $true
}

# ============================================================================
# PHASE 5: CLI TOOLS
# ============================================================================
function Install-CLITools {
    Write-Header "Phase 5: CLI Tools"

    # Scoop packages to install (always latest versions)
    $scoopPackages = @(
        @{Package = "fzf"; MinVersion = ""; Cmd = "fzf"},
        @{Package = "zoxide"; MinVersion = ""; Cmd = "zoxide"},
        @{Package = "bat"; MinVersion = ""; Cmd = "bat"},
        @{Package = "eza"; MinVersion = ""; Cmd = "eza"},
        @{Package = "lazygit"; MinVersion = ""; Cmd = "lazygit"},
        @{Package = "gh"; MinVersion = ""; Cmd = "gh"},
        @{Package = "ripgrep"; MinVersion = ""; Cmd = "rg"},
        @{Package = "fd"; MinVersion = ""; Cmd = "fd"}
    )

    # Add extra packages for full install
    if ($Script:Categories -eq "full") {
        $scoopPackages += @{Package = "tokei"; MinVersion = ""; Cmd = "tokei"}
        $scoopPackages += @{Package = "difftastic"; MinVersion = ""; Cmd = "difft"}
        $scoopPackages += @{Package = "btop-lhm"; MinVersion = ""; Cmd = "btop"}
    }

    # Install packages
    foreach ($pkg in $scoopPackages) {
        Install-ScoopPackage $pkg.Package $pkg.MinVersion $pkg.Cmd
    }

    # BATS (testing framework via npm - always latest)
    if (Test-Command npm) {
        Install-NpmGlobal "bats" "bats" ""
    }

    # Pester (PowerShell testing framework with code coverage - always latest)
    if (-not (Get-Module -ListAvailable -Name Pester)) {
        Write-Step "Installing Pester for PowerShell testing..."
        if (-not $DryRun) {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
            Install-Module -Name Pester -Force -Scope CurrentUser -SkipPublisherCheck
            Write-Success "Pester installed"
        }
        else {
            Write-Info "[DRY-RUN] Would install Pester"
        }
    }
    else {
        Write-VerboseInfo "Pester already installed"
        Track-Skipped "Pester" "PowerShell testing"
    }

    # Docker (optional - needed for kcov coverage on Windows; kcov is native on Linux/macOS)
    if (-not (Test-Command docker)) {
        Write-Info "Docker not found - kcov via Docker is used for bash coverage on Windows"
        if ($Script:Interactive) {
            $installDocker = Read-Confirmation "Install Docker Desktop (optional, for kcov coverage)?" "n"
            if ($installDocker) {
                Write-Step "Installing Docker Desktop via winget..."
                if (-not $DryRun) {
                    winget install --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements
                    Write-Success "Docker Desktop installed - please restart your shell and start Docker Desktop"
                }
                else {
                    Write-Info "[DRY-RUN] Would install Docker Desktop via winget"
                }
            }
            else {
                Write-Info "Install Docker Desktop from: https://www.docker.com/products/docker-desktop"
            }
        }
        else {
            Write-Info "Install Docker Desktop from: https://www.docker.com/products/docker-desktop"
        }
    }
    else {
        # Verify Docker is running
        $dockerRunning = $false
        try {
            $null = docker info 2>&1
            $dockerRunning = $true
            Write-VerboseInfo "Docker is available for bash coverage"
        }
        catch {
            Write-Warning "Docker is installed but not running - bash coverage will be unavailable"
        }
    }

    Write-Success "CLI tools installation complete"
    return $true
}

# ============================================================================
# PHASE 5.25: MCP SERVERS (Model Context Protocol servers for Claude Code)
# ============================================================================
function Install-MCPServers {
    Write-Header "Phase 5.25: MCP Servers"

    # Skip if npm is not available
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Warning "npm not found, skipping MCP server installation"
        return $true
    }

    # Helper function to install/update npm package with version check
    function Install-NpmPackageWithCheck {
        param(
            [string]$Package,
            [string]$DisplayName,
            [string]$TrackName,
            [string]$Description
        )

        $needsUpdate = Test-NpmPackageNeedsUpdate -Package $Package
        if ($needsUpdate) {
            Write-Step "Installing $DisplayName..."
            if (-not $DryRun) {
                $output = npm install -g $Package 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "$DisplayName installed"
                    Track-Installed $TrackName $Description
                }
                else {
                    Write-Warning "Failed to install $DisplayName"
                    Write-Info "Error output: $output"
                    Track-Failed $TrackName $Description
                }
            }
            else {
                Write-Info "[DRY-RUN] Would npm install -g $Package"
                Track-Installed $TrackName $Description
            }
        }
        else {
            Write-VerboseInfo "$DisplayName already at latest version"
            Track-Skipped $TrackName $Description
        }
    }

    # tree-sitter-cli - Required for nvim-treesitter auto_install to work optimally
    Install-NpmPackageWithCheck -Package "tree-sitter-cli" -DisplayName "tree-sitter-cli" -TrackName "tree-sitter-cli" -Description "Treesitter parser compiler"

    # Context7 - Up-to-date library documentation and code examples
    Install-NpmPackageWithCheck -Package "@upstash/context7-mcp" -DisplayName "context7 MCP server" -TrackName "context7-mcp" -Description "documentation lookup"

    # Playwright - Browser automation and E2E testing
    Install-NpmPackageWithCheck -Package "@playwright/mcp" -DisplayName "playwright MCP server" -TrackName "playwright-mcp" -Description "browser automation"

    # Repomix - Pack repositories for full-context AI exploration
    # Note: repomix MCP mode is invoked via npx -y repomix --mcp
    # The repomix package itself has built-in MCP support via --mcp flag
    # No global installation needed - npx handles it on-demand
    Track-Skipped "repomix" "repository packer (uses npx -y repomix --mcp)"

    Write-Success "MCP server installation complete"
    return $true
}

# ============================================================================
# PHASE 5.5: DEVELOPMENT TOOLS (Editors, LaTeX, AI Coding Assistants)
# ============================================================================
function Install-DevelopmentTools {
    Write-Header "Phase 5.5: Development Tools"

    # VS Code (via winget for system-wide installation - avoids plugin auth issues)
    $vscodeAlreadyInstalled = $false
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $wingetList = winget list --id Microsoft.VisualStudioCode 2>&1
        if ($LASTEXITCODE -eq 0 -and $wingetList -match "Microsoft.VisualStudioCode") {
            $vscodeAlreadyInstalled = $true
        }
    }

    if (-not $vscodeAlreadyInstalled -and -not (Test-Command code)) {
        Write-Step "Installing VS Code (system-wide via winget)..."
        if (-not $DryRun) {
            if (Get-Command winget -ErrorAction SilentlyContinue) {
                winget install --id Microsoft.VisualStudioCode --accept-package-agreements --accept-source-agreements *> $null
                Refresh-Path  # Refresh PATH to pick up newly installed VS Code
                # Check winget list to verify installation (more reliable than Test-Command for PATH issues)
                $wingetList = winget list --id Microsoft.VisualStudioCode 2>&1
                if ($LASTEXITCODE -eq 0 -and $wingetList -match "Microsoft.VisualStudioCode") {
                    Write-Success "VS Code installed system-wide via winget"
                    Track-Installed "vscode" "code editor"
                }
                else {
                    Write-Warning "VS Code installation may have failed - try installing from: https://code.visualstudio.com/"
                    Track-Failed "vscode" "code editor"
                }
            }
            else {
                Write-Warning "winget not available - install VS Code from: https://code.visualstudio.com/"
                Track-Failed "vscode" "code editor"
            }
        }
        else {
            Write-Info "[DRY-RUN] Would install VS Code via winget"
        }
    }
    else {
        Write-VerboseInfo "VS Code already installed"
        Track-Skipped "vscode" "code editor"
    }

    # Visual Studio Community (via winget - full IDE for C#, C++, etc.)
    # Check for VS using vswhere or devenv
    $vsInstalled = $false
    $vsWherePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vsWherePath) {
        # vswhere can detect VS installations
        $vsInfo = & $vsWherePath -latest -property displayName 2>$null
        if ($vsInfo -match "Visual Studio") {
            $vsInstalled = $true
        }
    }
    elseif (Test-Command devenv) {
        $vsInstalled = $true
    }

    if (-not $vsInstalled) {
        Write-Step "Installing Visual Studio Community (latest)..."
        if (-not $DryRun) {
            if (Get-Command winget -ErrorAction SilentlyContinue) {
                try {
                    # Install VS Community with core workloads
                    # --add Microsoft.VisualStudio.Workload.ManagedDesktop (C#, VB.NET)
                    # --add Microsoft.VisualStudio.Workload.NativeDesktop (C++)
                    # --add Microsoft.VisualStudio.Workload.NetCoreTools (modern .NET)
                    # --add Microsoft.VisualStudio.Workload.Node (Node.js development)
                    winget install --id Microsoft.VisualStudio.Community --accept-package-agreements --accept-source-agreements --override "--wait --passive --add Microsoft.VisualStudio.Workload.ManagedDesktop --add Microsoft.VisualStudio.Workload.NativeDesktop --add Microsoft.VisualStudio.Workload.NetCoreTools" *> $null

                    # Verify installation
                    if (Test-Path $vsWherePath) {
                        $vsInfo = & $vsWherePath -latest -property displayName 2>$null
                        if ($vsInfo -match "Visual Studio") {
                            Write-Success "Visual Studio Community installed"
                            Track-Installed "visual-studio" "full IDE"
                        }
                        else {
                            Write-Warning "Visual Studio installation may still be in progress (large download)"
                            Track-Installed "visual-studio" "full IDE (installing)"
                        }
                    }
                    else {
                        Write-Info "Visual Studio installation initiated - may require completion/restart"
                        Track-Installed "visual-studio" "full IDE (pending)"
                    }
                }
                catch {
                    Write-Warning "Visual Studio installation failed: $_"
                    Write-Info "Install manually from: https://visualstudio.microsoft.com/downloads/"
                    Track-Failed "visual-studio" "full IDE"
                }
            }
            else {
                Write-Warning "winget not available - install Visual Studio from: https://visualstudio.microsoft.com/downloads/"
                Track-Failed "visual-studio" "full IDE"
            }
        }
        else {
            Write-Info "[DRY-RUN] Would install Visual Studio Community via winget"
            Track-Installed "visual-studio" "full IDE"
        }
    }
    else {
        Write-VerboseInfo "Visual Studio already installed"
        Track-Skipped "visual-studio" "full IDE"
    }

    # LLVM (via winget - includes clang, clangd, lldb, etc.)
    # LLVM is the backbone for many dev tools and Windows features
    if (-not (Test-Command clang)) {
        Write-Step "Installing LLVM (clang toolchain)..."
        if (-not $DryRun) {
            if (Get-Command winget -ErrorAction SilentlyContinue) {
                try {
                    winget install --id LLVM.LLVM --accept-package-agreements --accept-source-agreements *> $null
                    Refresh-Path  # Refresh PATH to pick up newly installed LLVM
                    if (Test-Command clang) {
                        Write-Success "LLVM installed"
                        Track-Installed "llvm" "C/C++ toolchain"
                    }
                    else {
                        Write-Warning "LLVM installation may have failed - try installing from: https://llvm.org/"
                        Track-Failed "llvm" "C/C++ toolchain"
                    }
                }
                catch {
                    Write-Warning "LLVM installation failed: $_"
                    Write-Info "Install manually from: https://llvm.org/"
                    Track-Failed "llvm" "C/C++ toolchain"
                }
            }
            else {
                Write-Warning "winget not available - install LLVM from: https://llvm.org/"
                Track-Failed "llvm" "C/C++ toolchain"
            }
        }
        else {
            Write-Info "[DRY-RUN] Would install LLVM via winget"
            Track-Installed "llvm" "C/C++ toolchain"
        }
    }
    else {
        Write-VerboseInfo "LLVM already installed"
        Track-Skipped "llvm" "C/C++ toolchain"
    }

    # LaTeX (via scoop extras-plus bucket)
    if (-not (Test-Command pdflatex)) {
        Write-Step "Installing LaTeX (TeX Live)..."
        if (-not $DryRun) {
            # Check if scoop is available
            if (Get-Command scoop -ErrorAction SilentlyContinue) {
                # Add extras-plus bucket for texlive (if not already added)
                $buckets = scoop bucket list 2>$null
                if ($buckets -notmatch "extras-plus") {
                    Write-Info "Adding extras-plus bucket for TeX Live..."
                    scoop bucket add extras-plus https://github.com/Scoopforge/Extras-Plus *> $null
                }
                if (Install-ScoopPackage "texlive" "" "pdflatex") {
                    Write-Success "LaTeX (TeX Live) installed"
                }
            }
            else {
                Write-Warning "Scoop not available - install LaTeX from: https://tug.org/texlive/"
                Track-Failed "latex" "document preparation"
            }
        }
        else {
            Write-Info "[DRY-RUN] Would install LaTeX (TeX Live)"
        }
    }
    else {
        Write-VerboseInfo "LaTeX already installed"
        Track-Skipped "latex" "document preparation"
    }

    # Claude Code CLI (via official PowerShell installer)
    # First, clean up any old npm shims that might shadow the official binary
    $npmBin = Join-Path $env:APPDATA "npm"
    $oldShims = @("claude", "claude.cmd", "claude.ps1") | ForEach-Object {
        $filePath = Join-Path $npmBin $_
        if (Test-Path $filePath) { $filePath }
    }

    if ($oldShims) {
        foreach ($shim in $oldShims) {
            Write-Info "Removing old npm shim: $(Split-Path $shim -Leaf)"
            Remove-Item $shim -Force -ErrorAction SilentlyContinue
        }
    }

    # Get current version if claude is installed
    $currentVersion = ""
    if (Test-Command claude) {
        try {
            $versionOutput = claude --version 2>$null
            if ($versionOutput -match '(\d+\.\d+\.\d+)') {
                $currentVersion = $matches[1]
            }
        }
        catch {
            # Ignore errors
        }
    }

    # Get latest version from npm registry
    $latestVersion = ""
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        try {
            $latestVersion = npm view @anthropic-ai/claude-code version 2>$null
        }
        catch {
            # Ignore errors
        }
    }

    # Install if not found or version differs
    $needsInstall = $false
    if (-not (Test-Command claude)) {
        $needsInstall = $true
    }
    elseif ($currentVersion -and $latestVersion -and $currentVersion -ne $latestVersion) {
        Write-Info "Claude Code CLI update available: $currentVersion -> $latestVersion"
        $needsInstall = $true
    }

    if ($needsInstall) {
        Write-Step "Installing Claude Code CLI..."
        if (-not $DryRun) {
            # Prepare ~/.local/bin location and ensure it's in PATH
            $localBin = Join-Path $env:USERPROFILE ".local\bin"
            if (-not (Test-Path $localBin)) {
                New-Item -ItemType Directory -Path $localBin -Force | Out-Null
            }
            Add-ToPath -Path $localBin -User

            # Run official installer script
            $scriptContent = Invoke-RestMethod -Uri "https://claude.ai/install.ps1" -UseBasicParsing
            $scriptBlock = [ScriptBlock]::Create($scriptContent)
            & $scriptBlock

            # Refresh PATH to pick up the newly installed claude command
            Refresh-Path

            if (Test-Command claude) {
                Write-Success "Claude Code CLI installed"
                Track-Installed "claude-code" "AI CLI"
            }
            else {
                Write-Warning "Claude Code CLI installed but not in PATH yet"
                Track-Installed "claude-code" "AI CLI - PATH update pending"
            }
        }
        else {
            Write-Info "[DRY-RUN] Would install Claude Code CLI"
        }
    }
    else {
        $versionInfo = if ($currentVersion) { " ($currentVersion)" } else { "" }
        Write-Info "Claude Code CLI already at latest version$versionInfo"
        # Ensure PATH is set even when skipping install
        $localBin = Join-Path $env:USERPROFILE ".local\bin"
        Add-ToPath -Path $localBin -User
        Track-Skipped "claude-code" "AI CLI"
    }

    # OpenCode AI CLI (via official installer)
    $opencodeBin = Join-Path $env:USERPROFILE ".opencode\bin"
    $opencodeExe = Join-Path $opencodeBin "opencode.exe"

    # First, clean up any old npm shims that might shadow the official binary
    # This prevents confusion where `opencode --version` returns old version
    $npmBin = Join-Path $env:APPDATA "npm"
    $oldShims = @("opencode", "opencode.cmd", "opencode.ps1") | ForEach-Object {
        $filePath = Join-Path $npmBin $_
        if (Test-Path $filePath) { $filePath }
    }

    if ($oldShims) {
        foreach ($shim in $oldShims) {
            Write-Info "Removing old npm shim: $(Split-Path $shim -Leaf)"
            Remove-Item $shim -Force -ErrorAction SilentlyContinue
        }
    }

    # Check if opencode needs install/update
    $needsInstall = $false

    # Check if binary exists
    if (Test-Path $opencodeExe) {
        # Get current version from official binary
        $currentVersion = ""
        try {
            $versionOutput = & $opencodeExe --version 2>$null
            if ($versionOutput -match '(\d+\.\d+\.\d+)') {
                $currentVersion = $matches[1]
            }
        }
        catch {
            # If we can't get version, treat as needs install
            $needsInstall = $true
        }

        # Get latest version from npm registry
        $latestVersion = ""
        if (Get-Command npm -ErrorAction SilentlyContinue) {
            try {
                $latestVersion = npm view opencode-ai version 2>$null
            }
            catch {
                # If npm check fails, assume we need to install
                $needsInstall = $true
            }
        }

        # Only install if versions differ or we couldn't determine versions
        if ($currentVersion -and $latestVersion -and $currentVersion -eq $latestVersion) {
            Write-Info "OpenCode AI CLI already at latest version ($currentVersion)"
            # Ensure PATH is set even when skipping install
            Add-ToPath -Path $opencodeBin -User
            Track-Skipped "opencode" "AI CLI"
            $needsInstall = $false
        }
        elseif ($currentVersion -and $latestVersion -and $currentVersion -ne $latestVersion) {
            Write-Info "OpenCode AI CLI update available: $currentVersion -> $latestVersion"
            $needsInstall = $true
        }
        else {
            # Couldn't determine versions, install to be safe
            $needsInstall = $true
        }
    }
    else {
        # Binary doesn't exist
        $needsInstall = $true
    }

    if ($needsInstall) {
        Write-Step "Installing OpenCode AI CLI..."
        if (-not $DryRun) {
            # Prepare ~/.opencode/bin location
            if (-not (Test-Path $opencodeBin)) {
                New-Item -ItemType Directory -Path $opencodeBin -Force | Out-Null
            }
            Add-ToPath -Path $opencodeBin -User

            # Run official installer script via Git Bash
            if (Get-Command bash -ErrorAction SilentlyContinue) {
                bash.exe -c "curl -fsSL https://opencode.ai/install | bash"

                # Refresh PATH
                Refresh-Path

                if (Test-Command opencode) {
                    Write-Success "OpenCode AI CLI installed"
                    Track-Installed "opencode" "AI CLI"
                }
                else {
                    Write-Warning "OpenCode AI CLI installed but not in PATH yet"
                    Track-Installed "opencode" "AI CLI - PATH update pending"
                }
            }
            else {
                Write-Warning "Git Bash not found - required for OpenCodeAI installation"
                Track-Failed "opencode" "AI CLI"
            }
        }
        else {
            Write-Info "[DRY-RUN] Would install OpenCode AI CLI"
        }
    }
    else {
        # Already checked and skipped above
    }

    Write-Success "Development tools installation complete"
    return $true
}

# ============================================================================
# PHASE 6: DEPLOY CONFIGURATIONS
# ============================================================================
function Deploy-Configs {
    Write-Header "Phase 6: Deploying Configurations"

    $deployScript = Join-Path $ScriptDir "..\deploy.ps1"

    if (-not (Test-Path $deployScript)) {
        Write-Warning "deploy.ps1 not found at $deployScript"
        return $true
    }

    if ($DryRun) {
        Write-Info "[DRY-RUN] Would run: $deployScript"
        return $true
    }

    Write-Step "Running deploy script..."
    & $deployScript
    Write-Success "Configurations deployed"
    return $true
}

# ============================================================================
# PHASE 7: UPDATE ALL
# ============================================================================
function Update-All {
    Write-Header "Phase 7: Updating All Repositories and Packages"

    # Use the bash update-all script via PowerShell wrapper
    # The bash script has Windows detection and will skip Linux-only commands
    # and provides detailed progress output for each package manager
    $updateScript = Join-Path $ScriptDir "..\update-all.ps1"

    if (-not (Test-Path $updateScript)) {
        Write-Warning "update-all.ps1 not found at $updateScript"
        return $true
    }

    if ($DryRun) {
        Write-Info "[DRY-RUN] Would run: $updateScript"
        return $true
    }

    Write-Info "Running update-all script (this may take several minutes)..."
    # Invoke script and stream output directly to host
    & $updateScript | Out-Host
    $exitCode = $LASTEXITCODE
    if ($exitCode -eq 0) {
        Write-Success "Update complete"
    }
    else {
        Write-Warning "Update completed with exit code: $exitCode"
    }
    return $true
}

# ============================================================================
# MAIN
# ============================================================================
function Main {
    Write-Header "Bootstrap Windows Development Environment"

    Write-Host "Options:"
    Write-Host "  Interactive: $(-not $Y)"
    Write-Host "  Dry Run: $DryRun"
    Write-Host "  Categories: $Script:Categories"
    Write-Host "  Skip Update: $SkipUpdate"
    Write-Host ""

    # Confirm if interactive
    if ($Script:Interactive) {
        if (-not (Read-Confirmation "Proceed with bootstrap?" "n")) {
            Write-Host "Aborted."
            exit 0
        }
    }

    # CRITICAL: Initialize PATH first before any installations
    # This ensures:
    # 1. User PATH is restored if tests wiped it
    # 2. Already-installed tools are detected correctly
    # 3. Current session PATH is refreshed from registry
    if (-not $DryRun) {
        Initialize-UserPath
    }

    # Run phases
    if (-not (Install-Foundation)) {
        Write-Error-Msg "Foundation installation failed"
        exit 1
    }

    $null = Install-SDKs
    $null = Install-LanguageServers
    $null = Install-LintersFormatters
    $null = Install-CLITools
    if ($Categories -ne "minimal") {
        $null = Install-MCPServers
    }
    $null = Install-DevelopmentTools
    $null = Deploy-Configs
    if (-not $SkipUpdate) {
        $null = Update-All
    }
    else {
        Write-Info "Skipping update phase (SkipUpdate specified)"
    }

    Write-Summary

    if (-not $DryRun) {
        Write-Host "=== Bootstrap Complete ===" -ForegroundColor Green
        Write-Host "All tools are available in the current session." -ForegroundColor Green
        Write-Host "For new shells, PATH has been updated automatically." -ForegroundColor Cyan
    }
    else {
        Write-Host "=== Dry Run Complete ===" -ForegroundColor Yellow
        Write-Host "Run without -DryRun to actually install" -ForegroundColor Yellow
    }
}

# ============================================================================
# LOAD USER CONFIGURATION (OPTIONAL)
# ============================================================================

# Only try to load config if the config library was successfully sourced
if (Get-Command Load-DotfilesConfig -ErrorAction SilentlyContinue) {
    $ConfigFile = "$env:USERPROFILE\.dotfiles.config.yaml"

    if (Test-Path $ConfigFile) {
        try {
            Load-DotfilesConfig -ConfigFile $ConfigFile
            Write-Info "Config loaded from $ConfigFile"

            # Override defaults with config values (if config was loaded)
            if ($script:CONFIG_CATEGORIES) {
                $Script:Categories = $script:CONFIG_CATEGORIES
            }
        } catch {
            Write-Warning "Failed to load config file, using defaults"
        }
    }
} else {
    Write-Info "Config library not found, using hardcoded defaults"
}

# Run main
Main
