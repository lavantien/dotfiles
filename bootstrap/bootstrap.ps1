#requires -Version 7

[CmdletBinding()]
param(
    [switch]$Y = $false,
    [switch]$DryRun = $false,
    [string]$Categories = "full",
    [switch]$VerboseMode = $false
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LibDir = Join-Path $ScriptDir "lib"
$PlatformsDir = Join-Path $ScriptDir "platforms"

. "$LibDir\common.ps1"
. "$LibDir\version-check.ps1"

$ConfigLibPath = Join-Path $ScriptDir "..\lib\config.ps1"
if (Test-Path $ConfigLibPath) {
    . "$ConfigLibPath"
}

. "$PlatformsDir\windows.ps1"

$Script:Interactive = -not $Y
$Script:DryRun = $DryRun
$Script:Categories = $Categories
$Script:Verbose = $VerboseMode

function Show-Help {
    @'
Universal Bootstrap Script for Windows
Installs and configures development environment on Windows 10/11
#
VERSION POLICY:
  All packages are installed or updated to their LATEST versions
  No hardcoded version numbers - always gets the newest stable release
  Run bootstrap again to update all tools to latest versions
#
BRIDGE APPROACH:
  - Works without config file (uses hardcoded defaults - backward compatible)
  - Loads config file if present (~/.dotfiles.config.yaml) - forward compatible
  - Config library is optional - scripts work even if it's missing
  - Defaults: categories="full", interactive=true, no dry-run
#
Usage:
  .\bootstrap.ps1 [options]
#
Options:
  -Y                Non-interactive mode (accept all prompts)
  -DryRun           Show what would be installed without installing
  -Categories       minimal|sdk|full (default: full)
  -VerboseMode      Show detailed output including skipped items
  -Help             Show this help
============================================================================
'@
}

function Install-Foundation {
    Write-Header "Phase 1: Foundation"

    if (-not (Test-Command git)) {
        Write-Step "Installing git (includes Git Bash for .sh scripts)..."
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would install Git for Windows via winget"
            Track-Installed "git" "version control"
        }
        else {
            $gitInstalled = $false
            if (Get-Command winget -ErrorAction SilentlyContinue) {
                try {
                    winget install --id Git.Git --exact --accept-source-agreements --accept-package-agreements *> $null
                    if (Test-Command git) {
                        Write-Success "Git installed via winget"
                        Track-Installed "git" "version control"
                        $gitInstalled = $true
                        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
                    }
                }
                catch {
                    Write-WarningMsg "winget install failed: $_"
                }
            }

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

    Ensure-Scoop

    $scoopShims = Join-Path $env:USERPROFILE "scoop\shims"
    if ((Test-Path $scoopShims) -and ($env:Path -notlike "*$scoopShims*")) {
        $env:Path = "$scoopShims;$env:Path"
    }

    Configure-GitSettings

    Install-WezTerm

    Install-NerdFont

    Write-Success "Foundation complete"
    return $true
}

function Install-SDKs {
    if ($Script:Categories -eq "minimal") {
        return $true
    }

    Write-Header "Phase 2: Core SDKs"

    Install-ScoopPackage "nodejs" "" "node"

    Install-ScoopPackage "python" "" "python"

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

    if ($Script:Categories -eq "full") {
        Install-Rustup
    }

    if ($Script:Categories -eq "full") {
        if (-not (Test-Command dotnet)) {
            Write-Step "Installing dotnet SDK via winget..."
            if (-not $DryRun) {
                winget install --id Microsoft.DotNet.SDK.10 --exact --accept-source-agreements --accept-package-agreements *> $null
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

    if ($Script:Categories -eq "full") {
        Install-Bun
    }

    if ($Script:Categories -eq "full") {
        if (-not (Test-Command javac)) {
            Write-Step "Installing OpenJDK via winget..."
            if (-not $DryRun) {
                winget install --id Microsoft.OpenJDK.25 --exact --accept-source-agreements --accept-package-agreements *> $null
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

function Install-LanguageServers {
    if ($Script:Categories -eq "minimal") {
        return $true
    }

    Write-Header "Phase 3: Language Servers"

    if (Test-Command clangd) {
        Write-Step "Checking clangd..."
        Write-Success "clangd (up to date)"
        Track-Skipped "clangd" "C++ language server"
    }
    else {
        Install-ScoopPackage "llvm" "" "clangd"
    }

    if (Test-Command gcc) {
        Write-Step "Checking gcc..."
        $gccWorks = $false
        try {
            $null = & gcc --version 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $gccWorks = $true
            }
        } catch {
        }

        if ($gccWorks) {
            Write-Success "gcc (up to date)"
            Track-Skipped "gcc" "C/C++ toolchain"
        }
        else {
            Install-ScoopPackage "gcc" "" "gcc"
        }
    }
    else {
        Install-ScoopPackage "gcc" "" "gcc"
    }

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

    if ($Script:Categories -eq "full") {
        Install-RustAnalyzerComponent
    }

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

    if (Test-Command go) {
        if (Test-Command docker-language-server) {
            Write-Step "Checking docker-language-server..."
            Write-Success "docker-language-server (up to date)"
            Track-Skipped "docker-language-server" "Docker language server"
        }
        else {
            Install-GoPackage "github.com/docker/docker-language-server/cmd/docker-language-server@latest" "docker-language-server" ""
        }
    }

    if ($Script:Categories -eq "full") {
        Add-ScoopBucket "extras"
        Install-ScoopPackage "helm-ls" "" "helm-ls"
    }

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

function Install-LintersFormatters {
    if ($Script:Categories -eq "minimal") {
        return $true
    }

    Write-Header "Phase 4: Linters & Formatters"

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

    if ((Test-Command go) -and (-not (Test-Command gup))) {
        Install-GoPackage "github.com/nao1215/gup@latest" "gup" ""
    }
    elseif (Test-Command gup) {
        Write-Step "Checking gup..."
        Write-Success "gup (up to date)"
        Track-Skipped "gup" "Go package updater"
    }

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

    if ($Script:Categories -eq "full" -and (Test-Command python)) {
        if (Test-Command yamllint) {
            Write-Step "Checking yamllint..."
            Write-Success "yamllint (up to date)"
            Track-Skipped "yamllint" "YAML linter"
        }
        else {
            Install-PipGlobal "yamllint" "yamllint" ""
        }
    }

    if ($Script:Categories -eq "full") {
        if (Test-Command hadolint) {
            Write-Step "Checking hadolint..."
            Write-Success "hadolint (up to date)"
            Track-Skipped "hadolint" "Dockerfile linter"
        }
        else {
            Install-ScoopPackage "hadolint" "" "hadolint"
        }
    }

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

    if ($Script:Categories -eq "full") {
        if (Test-Command typos) {
            Write-Step "Checking typos..."
            Write-Success "typos (up to date)"
            Track-Skipped "typos" "Spell checker"
        }
        else {
            Install-ScoopPackage "typos" "" "typos"
        }
    }

    Write-Success "Linters & formatters installation complete"
    return $true
}

function Install-CLITools {
    Write-Header "Phase 5: CLI Tools"

    $scoopPackages = @(
        @{Package = "fzf"; MinVersion = ""; Cmd = "fzf"; Desc = "Fuzzy finder"},
        @{Package = "zoxide"; MinVersion = ""; Cmd = "zoxide"; Desc = "Smart cd"},
        @{Package = "bat"; MinVersion = ""; Cmd = "bat"; Desc = "Cat alternative"},
        @{Package = "eza"; MinVersion = ""; Cmd = "eza"; Desc = "Ls alternative"},
        @{Package = "lazygit"; MinVersion = ""; Cmd = "lazygit"; Desc = "Git TUI"},
        @{Package = "gh"; MinVersion = ""; Cmd = "gh"; Desc = "GitHub CLI"},
        @{Package = "ripgrep"; MinVersion = ""; Cmd = "rg"; Desc = "Grep alternative"},
        @{Package = "fd"; MinVersion = ""; Cmd = "fd"; Desc = "Find alternative"},
        @{Package = "sqlite"; MinVersion = ""; Cmd = "sqlite3"; Desc = "SQL database CLI"},
        @{Package = "jq"; MinVersion = ""; Cmd = "jq"; Desc = "JSON processor"},
        @{Package = "yazi"; MinVersion = ""; Cmd = "yazi"; Desc = "File manager"},
        @{Package = "unzip"; MinVersion = ""; Cmd = "unzip"; Desc = "Zip extraction for nvim"}
    )

    if ($Script:Categories -eq "full") {
        $scoopPackages += @{Package = "tokei"; MinVersion = ""; Cmd = "tokei"; Desc = "Code stats"}
        $scoopPackages += @{Package = "difftastic"; MinVersion = ""; Cmd = "difft"; Desc = "Diff tool"}
        $scoopPackages += @{Package = "btop-lhm"; MinVersion = ""; Cmd = "btop"; Desc = "System monitor"}
    }

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

    if ($Script:Categories -eq "full") {
        Install-WingetPackage -Id "Helm.Helm" -DisplayName "helm" -CheckCmd "helm"
        Install-WingetPackage -Id "Kubernetes.kubectl" -DisplayName "kubectl" -CheckCmd "kubectl"
        Install-WingetPackage -Id "JanDeDobbeleer.OhMyPosh" -DisplayName "oh-my-posh" -CheckCmd "oh-my-posh"
    }

    if ($DryRun) {
        Write-Info "[DRY-RUN] Would check gh auth and offer 'gh auth login'"
    }
    elseif (Test-Command gh) {
        Write-Step "Checking GitHub authentication..."
        gh auth status *> $null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "GitHub CLI already authenticated"
        }
        elseif ($Script:Interactive) {
            Write-Host "You need to authenticate with GitHub to continue." -ForegroundColor Yellow
            Write-Host "A browser window will open for you to complete authentication." -ForegroundColor Cyan
            if (Read-Confirmation "Authenticate with GitHub now?" "y") {
                Write-Step "Running gh auth login..."
                gh auth login
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "GitHub authentication successful"
                }
                else {
                    Write-WarningMsg "GitHub authentication failed or was cancelled"
                    Write-Info "You can run 'gh auth login' later to authenticate"
                }
            }
            else {
                Write-Info "Skipping GitHub authentication. Run 'gh auth login' later."
            }
        }
        else {
            Write-Info "Non-interactive mode: Skipping 'gh auth login'. Run it manually later."
        }
    }
    else {
        Write-Info "gh not installed yet, skipping GitHub authentication"
    }

    Write-Success "CLI tools installation complete"
    return $true
}

function Install-MCPServers {
    Write-Header "Phase 5.25: MCP Servers"

    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-WarningMsg "npm not found, skipping MCP server installation"
        return $true
    }

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
                    Write-WarningMsg "Failed to install $DisplayName"
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

    Install-NpmPackageWithCheck -Package "tree-sitter-cli" -DisplayName "tree-sitter-cli" -TrackName "tree-sitter-cli" -Description "Treesitter parser compiler"

    Install-NpmPackageWithCheck -Package "@upstash/context7-mcp" -DisplayName "context7 MCP server" -TrackName "context7-mcp" -Description "documentation lookup"

    Install-NpmPackageWithCheck -Package "@playwright/mcp" -DisplayName "playwright MCP server" -TrackName "playwright-mcp" -Description "browser automation"

    Write-Step "Checking repomix..."
    Write-Success "repomix (up to date)"
    Track-Skipped "repomix" "repository packer (uses npx -y repomix --mcp)"

    Write-Success "MCP server installation complete"
    return $true
}

function Install-DevelopmentTools {
    Write-Header "Phase 5.5: Development Tools"

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
                winget install --id Microsoft.VisualStudioCode --exact --accept-package-agreements --accept-source-agreements *> $null
                Refresh-Path
                $wingetList = winget list --id Microsoft.VisualStudioCode 2>&1
                if ($LASTEXITCODE -eq 0 -and $wingetList -match "Microsoft.VisualStudioCode") {
                    Write-Success "VS Code installed system-wide via winget"
                    Track-Installed "vscode" "code editor"
                }
                else {
                    Write-WarningMsg "VS Code installation may have failed - try installing from: https://code.visualstudio.com/"
                    Track-Failed "vscode" "code editor"
                }
            }
            else {
                Write-WarningMsg "winget not available - install VS Code from: https://code.visualstudio.com/"
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

    $vsInstalled = $false
    $vsWherePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vsWherePath) {
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
                    winget install --id Microsoft.VisualStudio.Community --exact --accept-package-agreements --accept-source-agreements --override "--wait --passive --add Microsoft.VisualStudio.Workload.ManagedDesktop --add Microsoft.VisualStudio.Workload.NativeDesktop --add Microsoft.VisualStudio.Workload.NetCoreTools" *> $null

                    if (Test-Path $vsWherePath) {
                        $vsInfo = & $vsWherePath -latest -property displayName 2>$null
                        if ($vsInfo -match "Visual Studio") {
                            Write-Success "Visual Studio Community installed"
                            Track-Installed "visual-studio" "full IDE"
                        }
                        else {
                            Write-WarningMsg "Visual Studio installation may still be in progress (large download)"
                            Track-Installed "visual-studio" "full IDE (installing)"
                        }
                    }
                    else {
                        Write-Info "Visual Studio installation initiated - may require completion/restart"
                        Track-Installed "visual-studio" "full IDE (pending)"
                    }
                }
                catch {
                    Write-WarningMsg "Visual Studio installation failed: $_"
                    Write-Info "Install manually from: https://visualstudio.microsoft.com/downloads/"
                    Track-Failed "visual-studio" "full IDE"
                }
            }
            else {
                Write-WarningMsg "winget not available - install Visual Studio from: https://visualstudio.microsoft.com/downloads/"
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

    if (-not (Test-Command clang)) {
        Write-Step "Installing LLVM (clang toolchain)..."
        if (-not $DryRun) {
            if (Get-Command winget -ErrorAction SilentlyContinue) {
                try {
                    winget install --id LLVM.LLVM --exact --accept-package-agreements --accept-source-agreements *> $null
                    Refresh-Path
                    if (Test-Command clang) {
                        Write-Success "LLVM installed"
                        Track-Installed "llvm" "C/C++ toolchain"
                    }
                    else {
                        Write-WarningMsg "LLVM installation may have failed - try installing from: https://llvm.org/"
                        Track-Failed "llvm" "C/C++ toolchain"
                    }
                }
                catch {
                    Write-WarningMsg "LLVM installation failed: $_"
                    Write-Info "Install manually from: https://llvm.org/"
                    Track-Failed "llvm" "C/C++ toolchain"
                }
            }
            else {
                Write-WarningMsg "winget not available - install LLVM from: https://llvm.org/"
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

    if (-not (Test-Command pdflatex)) {
        Write-Step "Installing LaTeX (TeX Live)..."
        if (-not $DryRun) {
            if (Get-Command scoop -ErrorAction SilentlyContinue) {
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
                Write-WarningMsg "Scoop not available - install LaTeX from: https://tug.org/texlive/"
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
    if (Test-Command bun) {
        bun remove -g @anthropic-ai/claude-code 2>$null
    }
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        npm rm -g @anthropic-ai/claude-code 2>$null
    }

    $currentVersion = ""
    if (Test-Command claude) {
        try {
            $versionOutput = claude --version 2>$null
            if ($versionOutput -match '(\d+\.\d+\.\d+)') {
                $currentVersion = $matches[1]
            }
        }
        catch {
        }
    }

    $needsInstall = -not (Test-Command claude)

    if ($needsInstall) {
        Write-Step "Installing Claude Code CLI..."
        if (-not $DryRun) {
            irm https://claude.ai/install.ps1 | iex

            $claudeBin = Join-Path $env:USERPROFILE ".claude\local\bin"
            if (Test-Path $claudeBin) {
                Add-ToPath -Path $claudeBin -User
                Refresh-Path
            }

            if (Test-Command claude) {
                Write-Success "Claude Code CLI installed via native installer"
                Track-Installed "claude-code" "AI CLI"
            }
            else {
                Write-WarningMsg "Claude Code CLI installed but not in PATH yet"
                Track-Installed "claude-code" "AI CLI - PATH update pending"
            }
        }
        else {
            Write-Info "[DRY-RUN] Would run: irm https://claude.ai/install.ps1 | iex"
        }
    }
    else {
        $versionInfo = if ($currentVersion) { " ($currentVersion)" } else { "" }
        Write-Info "Claude Code CLI already installed$versionInfo"
        Track-Skipped "claude-code" "AI CLI"
    }

    if (Test-Command bun) {
        $needsInstall = $false
        $currentVersion = ""

        if (Test-Command opencode) {
            try {
                $versionOutput = opencode --version 2>$null
                if ($versionOutput -match '(\d+\.\d+\.\d+)') {
                    $currentVersion = $matches[1]
                }
            } catch {}
        }

        $latestVersion = ""
        try {
            $latestVersion = npm view opencode-ai version 2>$null
        } catch {}

        if (-not (Test-Command opencode)) {
            $needsInstall = $true
        }
        elseif ($currentVersion -and $latestVersion -and $currentVersion -ne $latestVersion) {
            Write-Info "OpenCode AI CLI update available: $currentVersion -> $latestVersion"
            $needsInstall = $true
        }

        if ($currentVersion -and $latestVersion -and $currentVersion -eq $latestVersion) {
            Write-Info "OpenCode AI CLI already at latest version ($currentVersion)"
            Track-Skipped "opencode" "AI CLI"
        }
        elseif ($needsInstall) {
            Write-Step "Installing OpenCode AI CLI..."
            if (-not $DryRun) {
                $result = bun install -g opencode-ai 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "OpenCode AI CLI installed"
                    Track-Installed "opencode" "AI CLI"
                }
                else {
                    Write-WarningMsg "OpenCode AI CLI installation failed"
                    Track-Failed "opencode" "AI CLI"
                }
            }
            else {
                Write-Info "[DRY-RUN] Would install OpenCode AI CLI"
            }
        }
        else {
            Write-Step "Installing OpenCode AI CLI..."
            if (-not $DryRun) {
                $result = bun install -g opencode-ai 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "OpenCode AI CLI installed"
                    Track-Installed "opencode" "AI CLI"
                }
                else {
                    Write-WarningMsg "OpenCode AI CLI installation failed"
                    Track-Failed "opencode" "AI CLI"
                }
            }
        }
    }
    else {
        Write-WarningMsg "Bun not found - required for OpenCode AI CLI installation"
        Track-Skipped "opencode" "AI CLI"
    }

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
                    winget install --id Comfy.ComfyUI-Desktop --exact --accept-source-agreements --accept-package-agreements *> $null
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

function Deploy-Configs {
    Write-Header "Phase 6: Deploying Configurations"

    $deployScript = Join-Path $ScriptDir "..\scripts\deploy.ps1"

    if (-not (Test-Path $deployScript)) {
        Write-WarningMsg "deploy.ps1 not found at $deployScript"
        return $true
    }

    if ($DryRun) {
        Write-Info "[DRY-RUN] Would run: $deployScript"
        return $true
    }

    Write-Step "Running deploy script..."
    & $deployScript
    Write-Success "Configurations deployed"

    $MarketplaceJson = "$HOME/.claude/plugins/marketplaces/claude-plugins-official/.claude-plugin/marketplace.json"

    if (Test-Path $MarketplaceJson) {
        Write-Step "Checking Claude LSP marketplace..."

        $Json = Get-Content $MarketplaceJson -Raw
        $Patched = $false

        $NpmLsps = @(
            @{Name = "typescript"; CmdFile = "typescript-language-server.cmd"}
            @{Name = "pyright"; CmdFile = "pyright-langserver.cmd"}
            @{Name = "intelephense"; CmdFile = "intelephense.cmd"}
        )

        foreach ($Lsp in $NpmLsps) {
            $Pattern = '"' + $Lsp.Name + '"\s*:\s*\{[^}]*?"command"\s*:\s*"[^"]*"[^}]*?"args"\s*:\s*\[([^\]]*(?:\[[^\]]*\][^\]]*)*)*\]'

            if ($Json -match $Pattern) {
                $LspSection = $Matches[0]

                $CmdPattern = '"command"\s*:\s*"cmd\.exe"'
                $ArgsPattern = '"args"\s*:\s*\["/c"\s*,\s*"' + [regex]::Escape($Lsp.CmdFile) + '"'
                if ($LspSection -match $CmdPattern -and $LspSection -match $ArgsPattern) {
                    continue
                }

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

function Main {
    Write-Header "Bootstrap Windows Development Environment"

    Write-Host "Options:"
    Write-Host "  Interactive: $(-not $Y)"
    Write-Host "  Dry Run: $DryRun"
    Write-Host "  Categories: $Script:Categories"
    Write-Host ""

    if ($Script:Interactive) {
        if (-not (Read-Confirmation "Proceed with bootstrap?" "n")) {
            Write-Host "Aborted."
            exit 0
        }
    }

    if (-not $DryRun) {
        Initialize-UserPath
    }

    $script:updated = 0
    $script:skipped = 0
    $script:failed = 0

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

if (Get-Command Load-DotfilesConfig -ErrorAction SilentlyContinue) {
    $ConfigFile = "$env:USERPROFILE\.dotfiles.config.yaml"

    if (Test-Path $ConfigFile) {
        try {
            Load-DotfilesConfig -ConfigFile $ConfigFile
            Write-Info "Config loaded from $ConfigFile"

            if ($script:CONFIG_CATEGORIES) {
                $Script:Categories = $script:CONFIG_CATEGORIES
            }
        } catch {
            Write-WarningMsg "Failed to load config file, using defaults"
        }
    }
} else {
    Write-Info "Config library not found, using hardcoded defaults"
}

Main
