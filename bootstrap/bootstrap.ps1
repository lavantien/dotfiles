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

# Helper function to invoke composer safely (uses Scoop shim path directly)
function Invoke-ComposerSafe {
    param([string[]]$Arguments)
    $scoopShims = Join-Path $env:USERPROFILE "scoop\shims"
    # Scoop creates .cmd shims for most apps (not .exe)
    $composerPath = Join-Path $scoopShims "composer.cmd"
    if (Test-Path $composerPath) {
        & $composerPath @Arguments
        return $?
    }
    # Fallback to standard PATH lookup
    composer @Arguments
    return $?
}

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

    # lua-language-server (via npm - always latest)
    if ($Script:Categories -eq "full" -and (Test-Command npm)) {
        Install-NpmGlobal "lua-language-server" "lua-language-server" ""
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

    # intelephense (PHP language server via npm)
    if ($Script:Categories -eq "full" -and (Test-Command npm)) {
        Install-NpmGlobal "intelephense" "intelephense" ""
    }

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

    # php-nts (PHP runtime - prerequisite for composer)
    if ($Script:Categories -eq "full") {
        Install-ScoopPackage "php-nts" "" "php"
    }

    # composer (PHP package manager - prerequisite for PHP tools)
    if ($Script:Categories -eq "full") {
        Install-ScoopPackage "composer" "" "composer"
        # Ensure Scoop shims are in PATH for current session
        # Scoop installs shims to ~/scoop/shims but they might not be in registry PATH yet
        $scoopShims = Join-Path $env:USERPROFILE "scoop\shims"
        if ((Test-Path $scoopShims) -and ($env:Path -notlike "*$scoopShims*")) {
            $env:Path = "$scoopShims;$env:Path"
        }
    }

    # Enable required PHP extensions (for composer to work)
    if ($Script:Categories -eq "full" -and -not $DryRun) {
        $phpIni = Join-Path $env:USERPROFILE "scoop\persist\php-nts\cli\php.ini"
        if (Test-Path $phpIni) {
            $extensions = @('openssl', 'curl', 'fileinfo', 'mbstring', 'zip')
            $content = Get-Content $phpIni -Raw
            $updated = $false
            foreach ($ext in $extensions) {
                if ($content -match ";extension=$ext") {
                    $content = $content -replace ";extension=$ext", "extension=$ext"
                    $updated = $true
                }
            }
            if ($updated) {
                Set-Content $phpIni -Value $content -NoNewline
                Write-Info "PHP extensions enabled: $($extensions -join ', ')"
            }
        }
    }

    # Laravel Pint (PHP code style via composer global)
    if ($Script:Categories -eq "full") {
        $scoopShims = Join-Path $env:USERPROFILE "scoop\shims"
        $composerShim = Join-Path $scoopShims "composer.cmd"
        if (-not (Test-Path $composerShim)) {
            Write-Warning "Composer not found at $composerShim, skipping Laravel Pint installation"
            Track-Skipped "pint" "PHP code style"
        }
        elseif (-not (Invoke-ComposerSafe @("global", "show", "laravel/pint") 2>$null)) {
            Write-Step "Installing Laravel Pint..."
            if ($DryRun) {
                Write-Info "[DRY-RUN] Would composer global require laravel/pint"
            }
            else {
                Invoke-ComposerSafe @("global", "require", "laravel/pint") 2>$null | Out-Null
                if ($?) {
                    Write-Success "Laravel Pint installed"
                    Track-Installed "pint" "PHP code style"
                }
                else {
                    Track-Failed "pint" "PHP code style"
                }
            }
        }
        else {
            Write-Info "Laravel Pint already installed"
            Track-Skipped "pint" "PHP code style"
        }
    }

    # PHPStan (PHP static analysis via composer global)
    if ($Script:Categories -eq "full") {
        $scoopShims = Join-Path $env:USERPROFILE "scoop\shims"
        $composerShim = Join-Path $scoopShims "composer.cmd"
        if (-not (Test-Path $composerShim)) {
            Write-Warning "Composer not found at $composerShim, skipping PHPStan installation"
            Track-Skipped "phpstan" "PHP static analysis"
        }
        elseif (-not (Invoke-ComposerSafe @("global", "show", "phpstan/phpstan") 2>$null)) {
            Write-Step "Installing PHPStan..."
            if ($DryRun) {
                Write-Info "[DRY-RUN] Would composer global require phpstan/phpstan"
            }
            else {
                Invoke-ComposerSafe @("global", "require", "phpstan/phpstan") 2>$null | Out-Null
                if ($?) {
                    Write-Success "PHPStan installed"
                    Track-Installed "phpstan" "PHP static analysis"
                }
                else {
                    Track-Failed "phpstan" "PHP static analysis"
                }
            }
        }
        else {
            Write-Info "PHPStan already installed"
            Track-Skipped "phpstan" "PHP static analysis"
        }
    }

    # Psalm (PHP static analysis via composer global)
    if ($Script:Categories -eq "full") {
        $scoopShims = Join-Path $env:USERPROFILE "scoop\shims"
        $composerShim = Join-Path $scoopShims "composer.cmd"
        if (-not (Test-Path $composerShim)) {
            Write-Warning "Composer not found at $composerShim, skipping Psalm installation"
            Track-Skipped "psalm" "PHP static analysis"
        }
        elseif (-not (Invoke-ComposerSafe @("global", "show", "vimeo/psalm") 2>$null)) {
            Write-Step "Installing Psalm..."
            if ($DryRun) {
                Write-Info "[DRY-RUN] Would composer global require vimeo/psalm"
            }
            else {
                Invoke-ComposerSafe @("global", "require", "vimeo/psalm") 2>$null | Out-Null
                if ($?) {
                    Write-Success "Psalm installed"
                    Track-Installed "psalm" "PHP static analysis"
                }
                else {
                    Track-Failed "psalm" "PHP static analysis"
                }
            }
        }
        else {
            Write-Info "Psalm already installed"
            Track-Skipped "psalm" "PHP static analysis"
        }
    }

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

    # tree-sitter-cli - Required for nvim-treesitter auto_install to work optimally
    $treeSitterCmd = Get-Command tree-sitter -ErrorAction SilentlyContinue
    if (-not $treeSitterCmd) {
        Write-Step "Installing tree-sitter-cli..."
        if (-not $DryRun) {
            if (npm install -g tree-sitter-cli *> $null) {
                Write-Success "tree-sitter-cli installed"
                Track-Installed "tree-sitter-cli" "Treesitter parser compiler"
            }
            else {
                Write-Warning "Failed to install tree-sitter-cli"
                Track-Failed "tree-sitter-cli" "Treesitter parser compiler"
            }
        }
        else {
            Write-Info "[DRY-RUN] Would npm install -g tree-sitter-cli"
            Track-Installed "tree-sitter-cli" "Treesitter parser compiler"
        }
    }
    else {
        Track-Skipped "tree-sitter-cli" "Treesitter parser compiler"
    }

    # Context7 - Up-to-date library documentation and code examples
    npm list -g @upstash/context7-mcp *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Step "Installing context7 MCP server..."
        if (-not $DryRun) {
            if (npm install -g @upstash/context7-mcp *> $null) {
                Write-Success "context7 MCP server installed"
                Track-Installed "context7-mcp" "documentation lookup"
            }
            else {
                Write-Warning "Failed to install context7 MCP server"
                Track-Failed "context7-mcp" "documentation lookup"
            }
        }
        else {
            Write-Info "[DRY-RUN] Would npm install -g @context7/mcp-server"
            Track-Installed "context7-mcp" "documentation lookup"
        }
    }
    else {
        Track-Skipped "context7-mcp" "documentation lookup"
    }

    # Playwright - Browser automation and E2E testing
    npm list -g @playwright/mcp *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Step "Installing playwright MCP server..."
        if (-not $DryRun) {
            if (npm install -g @playwright/mcp *> $null) {
                Write-Success "playwright MCP server installed"
                Track-Installed "playwright-mcp" "browser automation"
            }
            else {
                Write-Warning "Failed to install playwright MCP server"
                Track-Failed "playwright-mcp" "browser automation"
            }
        }
        else {
            Write-Info "[DRY-RUN] Would npm install -g @executeautomation/playwright-mcp-server"
            Track-Installed "playwright-mcp" "browser automation"
        }
    }
    else {
        Track-Skipped "playwright-mcp" "browser automation"
    }

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

    # Claude Code CLI (via npm)
    if (Test-Command npm) {
        if (-not (Test-Command claude)) {
            Write-Step "Installing Claude Code CLI..."
            if (-not $DryRun) {
                if (Install-NpmGlobal "@anthropic-ai/claude-code" "claude" "") {
                    Write-Success "Claude Code CLI installed"
                }
            }
            else {
                Write-Info "[DRY-RUN] Would install Claude Code CLI"
            }
        }
        else {
            Write-VerboseInfo "Claude Code CLI already installed"
            Track-Skipped "claude-code" "AI CLI"
        }

        # OpenCode AI CLI (via npm)
        if (-not (Test-Command opencode)) {
            Write-Step "Installing OpenCode AI CLI..."
            if (-not $DryRun) {
                if (Install-NpmGlobal "opencode-ai" "opencode" "") {
                    Write-Success "OpenCode AI CLI installed"
                }
            }
            else {
                Write-Info "[DRY-RUN] Would install OpenCode AI CLI"
            }
        }
        else {
            Write-VerboseInfo "OpenCode AI CLI already installed"
            Track-Skipped "opencode" "AI CLI"
        }
    }
    else {
        Write-Warning "npm not found - skipping Claude Code and OpenCode AI CLI"
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
    $updateScript = Join-Path $ScriptDir "..\update-all.ps1"

    if (-not (Test-Path $updateScript)) {
        Write-Warning "update-all.ps1 not found at $updateScript"
        return $true
    }

    if ($DryRun) {
        Write-Info "[DRY-RUN] Would run: $updateScript"
        return $true
    }

    Write-Step "Running update-all script..."
    & $updateScript
    Write-Success "Update complete"
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
    $null = Update-All

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
