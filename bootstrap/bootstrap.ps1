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
#   -VerboseMode      Show detailed output including skipped items
#   -Help             Show this help

[CmdletBinding()]
param(
    [switch]$Y = $false,
    [switch]$DryRun = $false,
    [string]$Categories = "full",
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

    # Install WezTerm terminal emulator
    Install-WezTerm

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
    Install-ScoopPackage "nodejs" "" "node"

    # Python (always installs latest)
    Install-ScoopPackage "python" "" "python"

    # uv (Python package manager - required for Serena MCP)
    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
        Write-Step "Installing uv (Python package manager)..."
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would install uv via official installer"
            Track-Installed "uv" "Python package manager"
        }
        else {
            # Windows: use PowerShell installation script
            $output = irm https://astral.sh/uv/install.ps1 | iex 2>&1
            if (Test-Command uv) {
                Write-Success "uv installed via official installer"
                Track-Installed "uv" "Python package manager"
                # Refresh PATH for current session
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            }
            else {
                Write-Warning "uv installation failed"
                Track-Failed "uv" "Python package manager"
            }
        }
    }
    else {
        Write-VerboseInfo "uv already installed"
        Track-Skipped "uv" "Python package manager"
    }

    # Go (always installs latest)
    if ($Script:Categories -ne "minimal") {
        if (-not (Test-Command go)) {
            Install-ScoopPackage "go" "" "go"
        }
        else {
            Write-Step "Checking Go..."
            Write-Success "go (up to date)"
            Track-Skipped "go" "Go runtime"
        }
    }

    # Rust
    if ($Script:Categories -eq "full") {
        Install-Rustup
    }

    # dotnet SDK
    if ($Script:Categories -eq "full") {
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
            Write-Step "Checking dotnet SDK..."
            Write-Success "dotnet (up to date)"
            Track-Skipped "dotnet" ".NET SDK"
        }
    }

    # Bun (JavaScript runtime and package manager)
    if ($Script:Categories -eq "full") {
        Install-Bun
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
            Write-Step "Checking OpenJDK..."
            Write-Success "OpenJDK (up to date)"
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
    if (Test-Command clangd) {
        Write-Step "Checking clangd..."
        Write-Success "clangd (up to date)"
        Track-Skipped "clangd" "C++ language server"
    }
    else {
        Install-ScoopPackage "llvm" "" "clangd"
    }

    # gcc (C/C++ toolchain)
    if (Test-Command gcc) {
        Write-Step "Checking gcc..."
        Write-Success "gcc (up to date)"
        Track-Skipped "gcc" "C/C++ toolchain"
    }
    else {
        Install-ScoopPackage "gcc" "" "gcc"
    }

    # gopls (via go install - always latest)
    if ((Test-Command go) -and $Script:Categories -eq "full") {
        if (Test-Command gopls) {
            Write-Step "Checking gopls..."
            Write-Success "gopls (up to date)"
            Track-Skipped "gopls" "Go language server"
        }
        else {
            Install-GoPackage "golang.org/x/tools/gopls@latest" "gopls" ""
        }
    }

    # rust-analyzer (via rustup)
    if ($Script:Categories -eq "full") {
        Install-RustAnalyzerComponent
    }

    # pyright (via npm - always latest)
    if (Test-Command npm) {
        if (Test-Command pyright) {
            Write-Step "Checking pyright..."
            Write-Success "pyright (up to date)"
            Track-Skipped "pyright" "Python language server"
        }
        else {
            Install-NpmGlobal "pyright" "pyright" ""
        }
    }

    # TypeScript language server (via npm - always latest)
    if (Test-Command npm) {
        if (Test-Command typescript-language-server) {
            Write-Step "Checking typescript-language-server..."
            Write-Success "typescript-language-server (up to date)"
            Track-Skipped "typescript-language-server" "TypeScript language server"
        }
        else {
            Install-NpmGlobal "typescript-language-server" "typescript-language-server" ""
        }
    }

    # HTML language server (via npm - always latest)
    if (Test-Command npm) {
        if (Test-Command vscode-html-language-server) {
            Write-Step "Checking vscode-html-language-server..."
            Write-Success "vscode-html-language-server (up to date)"
            Track-Skipped "vscode-html-language-server" "HTML language server"
        }
        else {
            Install-NpmGlobal "vscode-html-languageserver-bin" "vscode-html-language-server" ""
        }
    }

    # CSS language server (via npm - always latest)
    if (Test-Command npm) {
        if (Test-Command vscode-css-language-server) {
            Write-Step "Checking vscode-css-language-server..."
            Write-Success "vscode-css-language-server (up to date)"
            Track-Skipped "vscode-css-language-server" "CSS language server"
        }
        else {
            Install-NpmGlobal "vscode-css-languageserver-bin" "vscode-css-language-server" ""
        }
    }

    # Svelte language server (via npm - full category)
    if ($Script:Categories -eq "full" -and (Test-Command npm)) {
        if (Test-Command svelte-language-server) {
            Write-Step "Checking svelte-language-server..."
            Write-Success "svelte-language-server (up to date)"
            Track-Skipped "svelte-language-server" "Svelte language server"
        }
        else {
            Install-NpmGlobal "svelte-language-server" "svelte-language-server" ""
        }
    }

    # bash-language-server (via npm - always latest)
    if (Test-Command npm) {
        if (Test-Command bash-language-server) {
            Write-Step "Checking bash-language-server..."
            Write-Success "bash-language-server (up to date)"
            Track-Skipped "bash-language-server" "Bash language server"
        }
        else {
            Install-NpmGlobal "bash-language-server" "bash-language-server" ""
        }
    }

    # YAML language server (via npm - always latest)
    if (Test-Command npm) {
        if (Test-Command yaml-language-server) {
            Write-Step "Checking yaml-language-server..."
            Write-Success "yaml-language-server (up to date)"
            Track-Skipped "yaml-language-server" "YAML language server"
        }
        else {
            Install-NpmGlobal "yaml-language-server" "yaml-language-server" ""
        }
    }

    # lua-language-server (via scoop - npm version has issues)
    if ($Script:Categories -eq "full") {
        if (Test-Command lua-language-server) {
            Write-Step "Checking lua-language-server..."
            Write-Success "lua-language-server (up to date)"
            Track-Skipped "lua-language-server" "Lua language server"
        }
        else {
            Install-ScoopPackage "lua-language-server" "" "lua-language-server"
        }
    }

    # csharp-ls (via dotnet tool)
    if ($Script:Categories -eq "full" -and (Test-Command dotnet)) {
        if (Test-Command csharp-ls) {
            Write-Step "Checking csharp-ls..."
            Write-Success "csharp-ls (up to date)"
            Track-Skipped "csharp-ls" "C# language server"
        }
        else {
            Install-DotnetTool "csharp-ls" "csharp-ls" ""
        }
    }

    # intelephense (PHP language server) - not supported on Windows, use Unix/Linux or WSL

    # jdtls (Java Language Server) - not supported on Windows, use Unix/Linux or WSL

    # Docker language servers (via npm - always latest)
    if (Test-Command npm) {
        if (Test-Command docker-langserver) {
            Write-Step "Checking docker-langserver..."
            Write-Success "docker-langserver (up to date)"
            Track-Skipped "docker-langserver" "Dockerfile language server"
        }
        else {
            Install-NpmGlobal "dockerfile-language-server-nodejs" "docker-langserver" ""
        }
        # Note: @microsoft/compose-language-service has no binary, skip version check
    }

    # tombi (TOML language server via npm - always latest)
    if (Test-Command npm) {
        if (Test-Command tombi) {
            Write-Step "Checking tombi..."
            Write-Success "tombi (up to date)"
            Track-Skipped "tombi" "TOML language server"
        }
        else {
            Install-NpmGlobal "tombi" "tombi" ""
        }
    }

    # dartls (Dart language server - requires Dart SDK)
    # Note: Dart SDK must be installed separately from https://dart.dev/get-dart
    # This is optional and not installed by default

    # tinymist (Typst language server via npm - always latest)
    if ($Script:Categories -eq "full" -and (Test-Command npm)) {
        if (Test-Command tinymist) {
            Write-Step "Checking tinymist..."
            Write-Success "tinymist (up to date)"
            Track-Skipped "tinymist" "Typst language server"
        }
        else {
            Install-NpmGlobal "tinymist" "tinymist" ""
        }
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
        if (Test-Command prettier) {
            Write-Step "Checking prettier..."
            Write-Success "prettier (up to date)"
            Track-Skipped "prettier" "Code formatter"
        }
        else {
            Install-NpmGlobal "prettier" "prettier" ""
        }
    }

    # ESLint (via npm - always latest)
    if (Test-Command npm) {
        if (Test-Command eslint) {
            Write-Step "Checking eslint..."
            Write-Success "eslint (up to date)"
            Track-Skipped "eslint" "JavaScript linter"
        }
        else {
            Install-NpmGlobal "eslint" "eslint" ""
        }
    }

    # Stylelint (CSS/SCSS linter via npm - always latest)
    if (Test-Command npm) {
        if (Test-Command stylelint) {
            Write-Step "Checking stylelint..."
            Write-Success "stylelint (up to date)"
            Track-Skipped "stylelint" "CSS linter"
        }
        else {
            Install-NpmGlobal "stylelint" "stylelint" ""
        }
    }

    # svelte-check (Svelte type checker via npm - full category)
    if ($Script:Categories -eq "full" -and (Test-Command npm)) {
        if (Test-Command svelte-check) {
            Write-Step "Checking svelte-check..."
            Write-Success "svelte-check (up to date)"
            Track-Skipped "svelte-check" "Svelte type checker"
        }
        else {
            Install-NpmGlobal "svelte-check" "svelte-check" ""
        }
    }

    # repomix (Pack repositories for AI exploration via npm - full category)
    if ($Script:Categories -eq "full" -and (Test-Command npm)) {
        if (Test-Command repomix) {
            Write-Step "Checking repomix..."
            Write-Success "repomix (up to date)"
            Track-Skipped "repomix" "Repository packager"
        }
        else {
            Install-NpmGlobal "repomix" "repomix" ""
        }
    }

    # mermaid-cli (diagram generation via npm - always available)
    if (Test-Command npm) {
        if (Test-Command mmdc) {
            Write-Step "Checking mermaid-cli..."
            Write-Success "mmdc (up to date)"
            Track-Skipped "mmdc" "Mermaid diagram generator"
        }
        else {
            Install-NpmGlobal "@mermaid-js/mermaid-cli" "mmdc" ""
        }
    }

    # Ruff (via pip - always latest)
    if (Test-Command python) {
        if (Test-Command ruff) {
            Write-Step "Checking ruff..."
            Write-Success "ruff (up to date)"
            Track-Skipped "ruff" "Python linter/formatter"
        }
        else {
            Install-PipGlobal "ruff" "ruff" ""
        }
    }

    # Additional Python tools (for full compatibility with git hooks - always latest)
    if ($Script:Categories -eq "full" -and (Test-Command python)) {
        if (Test-Command black) {
            Write-Step "Checking black..."
            Write-Success "black (up to date)"
            Track-Skipped "black" "Python formatter"
        }
        else {
            Install-PipGlobal "black" "black" ""
        }

        if (Test-Command isort) {
            Write-Step "Checking isort..."
            Write-Success "isort (up to date)"
            Track-Skipped "isort" "Python import sorter"
        }
        else {
            Install-PipGlobal "isort" "isort" ""
        }

        if (Test-Command mypy) {
            Write-Step "Checking mypy..."
            Write-Success "mypy (up to date)"
            Track-Skipped "mypy" "Python type checker"
        }
        else {
            Install-PipGlobal "mypy" "mypy" ""
        }

        if (Test-Command pytest) {
            Write-Step "Checking pytest..."
            Write-Success "pytest (up to date)"
            Track-Skipped "pytest" "Python testing"
        }
        else {
            Install-PipGlobal "pytest" "pytest" ""
        }
    }

    # gup (Go package manager - always latest)
    if ((Test-Command go) -and (-not (Test-Command gup))) {
        Install-GoPackage "nao.vi/gup@latest" "gup" ""
    }
    elseif (Test-Command gup) {
        Write-Step "Checking gup..."
        Write-Success "gup (up to date)"
        Track-Skipped "gup" "Go package updater"
    }

    # goimports (via gup if available, otherwise go install - always latest)
    if (Test-Command go) {
        if (Test-Command goimports) {
            Write-Step "Checking goimports..."
            Write-Success "goimports (up to date)"
            Track-Skipped "goimports" "Go import formatter"
        }
        else {
            Install-GoPackage "golang.org/x/tools/cmd/goimports@latest" "goimports" ""
        }
    }

    # golangci-lint (always latest)
    if (Test-Command go) {
        if (Test-Command golangci-lint) {
            Write-Step "Checking golangci-lint..."
            Write-Success "golangci-lint (up to date)"
            Track-Skipped "golangci-lint" "Go linter"
        }
        else {
            Install-ScoopPackage "golangci-lint" "" "golangci-lint"
        }
    }

    # Shell tools (for Git Bash on Windows)
    if ($Script:Categories -eq "full") {
        if (Test-Command shellcheck) {
            Write-Step "Checking shellcheck..."
            Write-Success "shellcheck (up to date)"
            Track-Skipped "shellcheck" "Shell script linter"
        }
        else {
            Install-ScoopPackage "shellcheck" "" "shellcheck"
        }

        if (Test-Command shfmt) {
            Write-Step "Checking shfmt..."
            Write-Success "shfmt (up to date)"
            Track-Skipped "shfmt" "Shell formatter"
        }
        else {
            Install-ScoopPackage "shfmt" "" "shfmt"
        }
    }

    # cppcheck (C++ static analysis)
    if ($Script:Categories -eq "full") {
        if (Test-Command cppcheck) {
            Write-Step "Checking cppcheck..."
            Write-Success "cppcheck (up to date)"
            Track-Skipped "cppcheck" "C++ static analyzer"
        }
        else {
            Install-ScoopPackage "cppcheck" "" "cppcheck"
        }
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
        Ensure-Coursier
        if (Test-Command scalafmt) {
            Write-Step "Checking scalafmt..."
            Write-Success "scalafmt (up to date)"
            Track-Skipped "scalafmt" "Scala formatter"
        }
        else {
            Install-CoursierPackage "scalafmt" "" "scalafmt"
        }
    }

    # scalafix (Scala linter via coursier)
    if ($Script:Categories -eq "full") {
        Ensure-Coursier
        if (Test-Command coursier) {
            if (Test-Command scalafix) {
                Write-Step "Checking scalafix..."
                Write-Success "scalafix (up to date)"
                Track-Skipped "scalafix" "Scala linter"
            }
            else {
                Install-CoursierPackage "scalafix" "" "scalafix"
            }
        }
    }

    # Metals (Scala language server via coursier)
    if ($Script:Categories -eq "full") {
        Ensure-Coursier
        if (Test-Command coursier) {
            if (Test-Command metals) {
                Write-Step "Checking metals..."
                Write-Success "metals (up to date)"
                Track-Skipped "metals" "Scala language server"
            }
            else {
                Install-CoursierPackage "metals" "" "metals"
            }
        }
    }

    # stylua (Lua formatter)
    if ($Script:Categories -eq "full") {
        if (Test-Command stylua) {
            Write-Step "Checking stylua..."
            Write-Success "stylua (up to date)"
            Track-Skipped "stylua" "Lua formatter"
        }
        else {
            Install-ScoopPackage "stylua" "" "stylua"
        }
    }

    # selene (Lua linter)
    if ($Script:Categories -eq "full") {
        if (Test-Command selene) {
            Write-Step "Checking selene..."
            Write-Success "selene (up to date)"
            Track-Skipped "selene" "Lua linter"
        }
        else {
            Install-ScoopPackage "selene" "" "selene"
        }
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
        @{Package = "fzf"; MinVersion = ""; Cmd = "fzf"; Desc = "Fuzzy finder"},
        @{Package = "zoxide"; MinVersion = ""; Cmd = "zoxide"; Desc = "Smart cd"},
        @{Package = "bat"; MinVersion = ""; Cmd = "bat"; Desc = "Cat alternative"},
        @{Package = "eza"; MinVersion = ""; Cmd = "eza"; Desc = "Ls alternative"},
        @{Package = "lazygit"; MinVersion = ""; Cmd = "lazygit"; Desc = "Git TUI"},
        @{Package = "gh"; MinVersion = ""; Cmd = "gh"; Desc = "GitHub CLI"},
        @{Package = "ripgrep"; MinVersion = ""; Cmd = "rg"; Desc = "Grep alternative"},
        @{Package = "fd"; MinVersion = ""; Cmd = "fd"; Desc = "Find alternative"}
    )

    # Add extra packages for full install
    if ($Script:Categories -eq "full") {
        $scoopPackages += @{Package = "tokei"; MinVersion = ""; Cmd = "tokei"; Desc = "Code stats"}
        $scoopPackages += @{Package = "difftastic"; MinVersion = ""; Cmd = "difft"; Desc = "Diff tool"}
        $scoopPackages += @{Package = "btop-lhm"; MinVersion = ""; Cmd = "btop"; Desc = "System monitor"}
    }

    # Install packages with checking
    foreach ($pkg in $scoopPackages) {
        if (Test-Command $pkg.Cmd) {
            Write-Step "Checking $($pkg.Package)..."
            Write-Success "$($pkg.Package) (up to date)"
            Track-Skipped $pkg.Cmd $pkg.Desc
        }
        else {
            Install-ScoopPackage $pkg.Package $pkg.MinVersion $pkg.Cmd
        }
    }

    # BATS (testing framework via npm - always latest)
    if (Test-Command npm) {
        if (Test-Command bats) {
            Write-Step "Checking bats..."
            Write-Success "bats (up to date)"
            Track-Skipped "bats" "Bash testing"
        }
        else {
            Install-NpmGlobal "bats" "bats" ""
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

        Write-Step "Checking $DisplayName..."
        $needsUpdate = Test-NpmPackageNeedsUpdate -Package $Package
        if ($needsUpdate) {
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
            Write-Success "$DisplayName (up to date)"
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
    Write-Step "Checking repomix..."
    Write-Success "repomix (up to date)"
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
        Write-Step "Checking VS Code..."
        Write-Success "vscode (up to date)"
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
        Write-Step "Checking Visual Studio..."
        Write-Success "visual-studio (up to date)"
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
        Write-Step "Checking LLVM..."
        Write-Success "llvm (up to date)"
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
        Write-Step "Checking LaTeX..."
        Write-Success "latex (up to date)"
        Track-Skipped "latex" "document preparation"
    }

    # Claude Code CLI (via bun on Windows - npm is deprecated, native installer has bugs)
    # First, clean up any old npm or native installer shims
    $npmBin = Join-Path $env:APPDATA "npm"
    $localBin = Join-Path $env:USERPROFILE ".local\bin"
    $oldShims = @("claude", "claude.cmd", "claude.ps1") | ForEach-Object {
        $filePath = Join-Path $npmBin $_
        if (Test-Path $filePath) { $filePath }
        $filePath2 = Join-Path $localBin $_
        if (Test-Path $filePath2) { $filePath2 }
    }

    if ($oldShims) {
        foreach ($shim in $oldShims) {
            Write-Info "Removing old shim: $(Split-Path $shim -Leaf)"
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
            # Use bun on Windows (npm is deprecated, native installer has self-deletion bug)
            if (Test-Command bun) {
                # Remove old npm package if present
                bun pm rm -g @anthropic-ai/claude-code 2>$null

                # Install via bun
                bun add -g @anthropic-ai/claude-code

                # Add bun global bin to PATH
                $bunBin = bun pm bin -g 2>$null
                if ($bunBin) {
                    Add-ToPath -Path $bunBin -User
                    Refresh-Path
                }

                if (Test-Command claude) {
                    Write-Success "Claude Code CLI installed via bun"
                    Track-Installed "claude-code" "AI CLI"
                }
                else {
                    Write-Warning "Claude Code CLI installed but not in PATH yet"
                    Track-Installed "claude-code" "AI CLI - PATH update pending"
                }
            }
            else {
                Write-Warning "bun not found, required for Claude Code installation on Windows"
                Write-Info "Install bun first: scoop install bun"
                Track-Failed "claude-code" "AI CLI - bun required"
            }
        }
        else {
            Write-Info "[DRY-RUN] Would install Claude Code CLI via bun"
        }
    }
    else {
        $versionInfo = if ($currentVersion) { " ($currentVersion)" } else { "" }
        Write-Info "Claude Code CLI already at latest version$versionInfo"
        # Ensure bun global bin is in PATH even when skipping install
        if (Test-Command bun) {
            $bunBin = bun pm bin -g 2>$null
            if ($bunBin) {
                Add-ToPath -Path $bunBin -User
            }
        }
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

    # ComfyUI Desktop (AI image generation via winget - Windows only)
    if ($Script:Categories -eq "full") {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            $wingetList = winget list --id Comfy.ComfyUI-Desktop 2>&1
            if ($LASTEXITCODE -eq 0 -and $wingetList -match "ComfyUI") {
                Write-Step "Checking ComfyUI Desktop..."
                Write-Success "ComfyUI (up to date)"
                Track-Skipped "ComfyUI" "AI image generation"
            }
            else {
                Write-Step "Installing ComfyUI Desktop via winget..."
                if (-not $DryRun) {
                    winget install --id Comfy.ComfyUI-Desktop --accept-source-agreements --accept-package-agreements *> $null
                    Track-Installed "ComfyUI" "AI image generation"
                }
                else {
                    Write-Info "[DRY-RUN] Would install ComfyUI Desktop via winget"
                    Track-Installed "ComfyUI" "AI image generation"
                }
            }
        }
        else {
            Write-VerboseInfo "winget not available, skipping ComfyUI Desktop"
        }
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

    # Patch Claude LSP marketplace for Windows npm-installed servers
    # (in case deploy.ps1 was run with -SkipConfig or marketplace was updated later)
    $MarketplaceJson = "$HOME/.claude/plugins/marketplaces/claude-plugins-official/.claude-plugin/marketplace.json"

    if (Test-Path $MarketplaceJson) {
        Write-Step "Checking Claude LSP marketplace..."

        $Json = Get-Content $MarketplaceJson -Raw
        $Patched = $false

        # LSP servers that need cmd.exe wrapper (installed via npm)
        $NpmLsps = @(
            @{Name = "typescript"; CmdFile = "typescript-language-server.cmd"}
            @{Name = "pyright"; CmdFile = "pyright-langserver.cmd"}
            @{Name = "intelephense"; CmdFile = "intelephense.cmd"}
        )

        foreach ($Lsp in $NpmLsps) {
            # Find the LSP entry
            $Pattern = '"' + $Lsp.Name + '"\s*:\s*\{[^}]*?"command"\s*:\s*"[^"]*"[^}]*?"args"\s*:\s*\[([^\]]*(?:\[[^\]]*\][^\]]*)*)*\]'

            if ($Json -match $Pattern) {
                $LspSection = $Matches[0]

                # Check if already patched
                $CmdPattern = '"command"\s*:\s*"cmd\.exe"'
                $ArgsPattern = '"args"\s*:\s*\["/c"\s*,\s*"' + [regex]::Escape($Lsp.CmdFile) + '"'
                if ($LspSection -match $CmdPattern -and $LspSection -match $ArgsPattern) {
                    continue
                }

                # Patch: replace command and args
                $PatchedCommand = '"command": "cmd.exe"'
                $PatchedArgs = '"args": ["/c", "' + $Lsp.CmdFile + '", "--stdio"]'
                $NewSection = $LspSection -replace '"command"\s*:\s*"[^"]*"', $PatchedCommand
                $NewSection = $NewSection -replace '"args"\s*:\s*\[.+\]', $PatchedArgs
                $Json = $Json.Replace($LspSection, $NewSection)
                $Patched = $true
            }
        }

        if ($Patched) {
            Set-Content $MarketplaceJson $Json -NoNewline
            Write-Success "Claude LSP marketplace patched"
        } else {
            Write-Info "Claude LSP marketplace (up to date)"
        }
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

    # Initialize tracking variables used by windows.ps1 functions
    # (Install-Rustup and others use these to track update statistics)
    $script:updated = 0
    $script:skipped = 0
    $script:failed = 0

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
