#requires -Version 7
# Deploy Script for Windows (Pure PowerShell 7)
# Deploys dotfiles, scripts, and configs to appropriate locations

param(
    [string]$DotfilesDir = "$HOME/dev/github/dotfiles",
    [switch]$SkipConfig,
    [switch]$Backup
)

$ErrorActionPreference = "Stop"

# Load user config for backup_before_deploy
$ConfigLib = Join-Path $DotfilesDir "lib/config.ps1"
if (Test-Path $ConfigLib) {
    . $ConfigLib
    Load-DotfilesConfig
}
$BackupBeforeDeploy = ($CONFIG_BACKUP_BEFORE_DEPLOY -eq "true")

# Pre-deploy backup before any mutation (-Backup flag or backup_before_deploy config)
if ($Backup -or $BackupBeforeDeploy) {
    Write-Host "Running pre-deploy backup..." -ForegroundColor Cyan
    $BackupScript = Join-Path $PSScriptRoot "backup.ps1"
    if (Get-Command bash -ErrorAction SilentlyContinue) {
        & $BackupScript
    }
    else {
        Write-Host "  Git Bash not found, cannot run backup.sh, skipping" -ForegroundColor Yellow
    }
}

$DevDir = "$HOME/dev"
$ConfigDir = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { "$HOME/.config" }

# Ensure config directory exists
if (!(Test-Path $ConfigDir)) {
    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
}

function Copy-File {
    param([string]$Src, [string]$Dst, [switch]$Verbose)
    if (Test-Path $Src) {
        if ($Verbose) {
            $srcTime = (Get-Item $Src).LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
            $dstExisted = Test-Path $Dst
            $dstTime = if ($dstExisted) { (Get-Item $Dst).LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss") } else { "N/A" }
            Write-Host "    Copying: $(Split-Path $Src -Leaf)" -ForegroundColor DarkGray
            Write-Host "      src: $srcTime" -ForegroundColor DarkGray
            Write-Host "      dst: $dstTime" -ForegroundColor DarkGray
        }
        Copy-Item $Src $Dst -Force
        if ($Verbose) {
            $newDstTime = (Get-Item $Dst).LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
            Write-Host "      -> $newDstTime" -ForegroundColor DarkGray
        }
    }
}

function Copy-Files {
    param([string[]]$Files, [string]$DestDir, [switch]$Verbose)
    if (!(Test-Path $DestDir)) {
        New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
    }
    foreach ($f in $Files) {
        $Src = Join-Path $DotfilesDir $f
        $Dst = Join-Path $DestDir (Split-Path $f -Leaf)
        Copy-File $Src $Dst -Verbose:$Verbose
    }
}

# Port of merge_gitconfig in deploy.sh: replace ~/.gitconfig with the repo
# template while preserving the live user.name and user.email.
function Merge-Gitconfig {
    param([string]$Src, [string]$Dst)

    if (!(Test-Path $Dst)) {
        Copy-Item $Src $Dst
        Write-Host "  Git config (created)" -ForegroundColor Cyan
        return
    }

    $UserName = git config --file $Dst user.name 2>$null
    if ($LASTEXITCODE -ne 0) { $UserName = $null }
    $UserEmail = git config --file $Dst user.email 2>$null
    if ($LASTEXITCODE -ne 0) { $UserEmail = $null }

    $TempFile = "$Dst.dotfiles-new"
    Copy-Item $Src $TempFile -Force
    if ($UserName) { git config --file $TempFile user.name "$UserName" | Out-Null }
    if ($UserEmail) { git config --file $TempFile user.email "$UserEmail" | Out-Null }

    # Fold legacy absolute gh credential helper paths (linuxbrew, gh.exe)
    # into the PATH-resolved form; git runs helpers through sh either way
    $Content = Get-Content $TempFile -Raw
    $Pattern = '(?m)^[ \t]*helper[ \t]*=[ \t]*!?\S*gh(\.exe)?"?[ \t]+auth[ \t]+git-credential[ \t]*\r?$'
    if ($Content -match $Pattern) {
        $Content = $Content -replace $Pattern, 'helper = !gh auth git-credential'
        Set-Content -LiteralPath $TempFile $Content -NoNewline
    }

    Move-Item $TempFile $Dst -Force
    Write-Host "  Git config (updated, user identity preserved)" -ForegroundColor Cyan
}

function Merge-Template([PSCustomObject]$Template, [PSCustomObject]$Live) {
    foreach ($Prop in $Template.PSObject.Properties) {
        $Existing = $Live.PSObject.Properties[$Prop.Name]
        if ($null -eq $Existing) {
            $Live | Add-Member -NotePropertyName $Prop.Name -NotePropertyValue $Prop.Value
        }
        elseif ($Prop.Value -is [PSCustomObject] -and $Existing.Value -is [PSCustomObject]) {
            # Recursion mutates in place; discard its return value or it
            # pollutes the pipeline and the result becomes an array
            $null = Merge-Template $Prop.Value $Existing.Value
        }
        else {
            # Template is the source of truth: overwrite diverging live values
            $Existing.Value = $Prop.Value
        }
    }
    return $Live
}

# Delete dotted paths listed in the retired-keys file from the merged settings.
# The file maps "section.key" paths to the reason and reference for retirement.
function Remove-RetiredKeys([PSCustomObject]$Settings, [string]$RetiredPath) {
    if (!(Test-Path $RetiredPath)) {
        return
    }
    try {
        $Retired = Get-Content $RetiredPath -Raw | ConvertFrom-Json
    }
    catch {
        Write-Host "  Retired-keys file not valid JSON, skipping retirement" -ForegroundColor Yellow
        return
    }
    if ($null -eq $Retired) {
        return
    }
    foreach ($Prop in $Retired.PSObject.Properties) {
        $Segments = $Prop.Name -split '\.'
        $Node = $Settings
        for ($i = 0; $i -lt $Segments.Count - 1; $i++) {
            $Next = $Node.PSObject.Properties[$Segments[$i]]
            if ($null -eq $Next -or $Next.Value -isnot [PSCustomObject]) {
                $Node = $null
                break
            }
            $Node = $Next.Value
        }
        if ($Node -is [PSCustomObject]) {
            $null = $Node.PSObject.Properties.Remove($Segments[-1])
        }
    }
}

function Merge-ClaudeSettings {
    param([string]$TemplatePath, [string]$TargetPath)

    if (!(Test-Path $TemplatePath)) {
        Write-Host "  Settings template not found, skipping" -ForegroundColor Yellow
        return
    }
    if (!(Test-Path $TargetPath)) {
        try {
            $Seeded = Get-Content $TemplatePath -Raw | ConvertFrom-Json
        }
        catch {
            Write-Host "  Claude settings template not valid JSON, skipping" -ForegroundColor Yellow
            return
        }
        # Same concrete-type check as the live guard below: null passes every
        # -is check and scalars pass -is [PSCustomObject] in pwsh
        if ($null -eq $Seeded -or $Seeded.GetType().Name -ne 'PSCustomObject') {
            Write-Host "  Claude settings template not a JSON object, skipping" -ForegroundColor Yellow
            return
        }
        # Seed honors the retirement list so "deleted on every deploy" holds
        Remove-RetiredKeys $Seeded (Join-Path (Split-Path $TemplatePath -Parent) 'settings.retired.json')
        $Seeded | ConvertTo-Json -Depth 100 | Set-Content $TargetPath
        Write-Host "  Claude settings (created from template)" -ForegroundColor Green
        return
    }

    try {
        $Template = Get-Content $TemplatePath -Raw | ConvertFrom-Json
        $Live = Get-Content $TargetPath -Raw | ConvertFrom-Json
    }
    catch {
        Write-Host "  Claude settings not valid JSON, skipping merge" -ForegroundColor Yellow
        return
    }

    # Merge-Template indexes into the live object, so a non-object settings file
    # (empty, null, array, scalar) would abort the whole script under
    # ErrorActionPreference Stop. Null passes every -is check and scalars pass
    # -is [PSCustomObject] in pwsh, so compare the concrete type name.
    if ($null -eq $Live -or $Live.GetType().Name -ne 'PSCustomObject') {
        Write-Host "  Claude settings not a JSON object, skipping merge" -ForegroundColor Yellow
        return
    }

    $Merged = Merge-Template $Template $Live
    Remove-RetiredKeys $Merged (Join-Path (Split-Path $TemplatePath -Parent) 'settings.retired.json')
    # Depth 100: ConvertTo-Json defaults to 2 and would truncate nested objects
    $Merged | ConvertTo-Json -Depth 100 | Set-Content $TargetPath
    Write-Host "  Claude settings (template values applied, local-only keys preserved)" -ForegroundColor Green
}

function Patch-ClaudeLspMarketplace {
    $MarketplaceJson = "$HOME/.claude/plugins/marketplaces/claude-plugins-official/.claude-plugin/marketplace.json"

    if (!(Test-Path $MarketplaceJson)) {
        Write-Host "  Claude LSP marketplace (not installed, skipping)" -ForegroundColor Cyan
        return
    }

    $Json = Get-Content $MarketplaceJson -Raw
    $Patched = $false

    # LSP servers that need cmd.exe wrapper (installed via npm)
    # We look for the command field and replace it along with the args field
    $NpmLsps = @(
        @{Name = "typescript"; CmdFile = "typescript-language-server.cmd"}
        @{Name = "pyright"; CmdFile = "pyright-langserver.cmd"}
        @{Name = "intelephense"; CmdFile = "intelephense.cmd"}
    )

    foreach ($Lsp in $NpmLsps) {
        # Find the LSP entry: "typescript": { ... "command": "..." ... "args": [...] ... }
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
        Write-Host "  Claude LSP marketplace (patched)" -ForegroundColor Green
    } else {
        Write-Host "  Claude LSP marketplace (up to date)" -ForegroundColor Cyan
    }
}

function Test-FileEqual {
    param($PathA, $PathB)
    $bytesA = [System.IO.File]::ReadAllBytes($PathA)
    $bytesB = [System.IO.File]::ReadAllBytes($PathB)
    return [System.Linq.Enumerable]::SequenceEqual($bytesA, $bytesB)
}

# Deploy CLAUDE.md with the corpus root sentence spliced between the markers
# for this machine; everything else in the file stays byte-identical
function Copy-ClaudeMd {
    param([string]$Src, [string]$Dst)

    $Begin = '<!-- BEGIN books corpus root -->'
    $End = '<!-- END books corpus root -->'
    $CorpusRoot = Join-Path $HOME 'dev/github/resume/books'
    $Sentence = if (Test-Path -LiteralPath $CorpusRoot -PathType Container) {
        'The corpus root is ~/dev/github/resume/books.'
    } else {
        'The corpus root is ~/.claude/books.'
    }

    $Content = Get-Content -LiteralPath $Src -Raw
    if ([string]::IsNullOrEmpty($Content) -or
        [regex]::Matches($Content, [regex]::Escape($Begin)).Count -ne 1 -or
        [regex]::Matches($Content, [regex]::Escape($End)).Count -ne 1) {
        throw "corpus root marker pair must appear exactly once in $Src"
    }
    $bi = $Content.IndexOf($Begin)
    $ei = $Content.IndexOf($End)
    $between = if ($ei -ge ($bi + $Begin.Length)) { $Content.Substring($bi + $Begin.Length, $ei - ($bi + $Begin.Length)) } else { $null }
    if ($null -eq $between -or $between -match '\r|\n') {
        throw "malformed corpus root marker pair in $Src"
    }
    $Content.Substring(0, $bi + $Begin.Length) + ' ' + $Sentence + ' ' + $Content.Substring($ei) |
        Set-Content -LiteralPath $Dst -NoNewline
}

# Mirror the shipped typst corpus into ~/.claude/books when the private
# corpus is absent; the shipped corpus is curated, so it mirrors as is
function Copy-ClaudeBooks {
    $CorpusRoot = Join-Path $HOME 'dev/github/resume/books'
    if (Test-Path -LiteralPath $CorpusRoot -PathType Container) {
        Write-Host "  Claude books (private corpus present, skipping copy)" -ForegroundColor Cyan
        return
    }

    $SourceRoot = Join-Path $DotfilesDir '.claude/books'
    if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
        Write-Host "  Claude books (no shipped corpus at $SourceRoot)" -ForegroundColor Yellow
        return
    }
    $Volumes = @(Get-ChildItem -LiteralPath $SourceRoot -Directory)
    if ($Volumes.Count -eq 0) {
        Write-Host "  Claude books (no volumes under $SourceRoot, leaving target untouched)" -ForegroundColor Yellow
        return
    }

    $TargetRoot = Join-Path $HOME '.claude/books'
    $copied = 0
    $deleted = 0

    foreach ($f in @(Get-ChildItem -LiteralPath $SourceRoot -Recurse -File)) {
        $rel = [System.IO.Path]::GetRelativePath($SourceRoot, $f.FullName)
        $outFile = Join-Path $TargetRoot $rel
        [System.IO.Directory]::CreateDirectory((Split-Path -Parent $outFile)) | Out-Null
        if (-not (Test-Path -LiteralPath $outFile -PathType Leaf) -or -not (Test-FileEqual $f.FullName $outFile)) {
            Copy-Item -LiteralPath $f.FullName -Destination $outFile -Force
            $copied++
        }
    }

    # Stale target files outside the shipped corpus go away, empty dirs too
    if (Test-Path -LiteralPath $TargetRoot -PathType Container) {
        foreach ($f in @(Get-ChildItem -LiteralPath $TargetRoot -Recurse -File)) {
            $rel = [System.IO.Path]::GetRelativePath($TargetRoot, $f.FullName)
            if (-not (Test-Path -LiteralPath (Join-Path $SourceRoot $rel) -PathType Leaf)) {
                Remove-Item -LiteralPath $f.FullName -Force
                $deleted++
            }
        }
        Get-ChildItem -LiteralPath $TargetRoot -Recurse -Directory |
            Sort-Object { $_.FullName.Length } -Descending |
            ForEach-Object {
                if (-not @(Get-ChildItem -LiteralPath $_.FullName -Force)) { Remove-Item -LiteralPath $_.FullName -Force }
            }
    }

    Write-Host "  Claude books ($($Volumes.Count) volumes, $copied files copied, $deleted files deleted)" -ForegroundColor Green
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Windows Dotfiles Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Dotfiles: $DotfilesDir" -ForegroundColor Blue
Write-Host ""

# Ensure ~/dev exists
if (!(Test-Path $DevDir)) {
    New-Item -ItemType Directory -Path $DevDir -Force | Out-Null
}

# Deploy scripts to ~/dev
Write-Host "Deploying scripts to ~/dev..." -ForegroundColor Cyan
Copy-Files @(
    "scripts/git-update-repos.sh"
    "scripts/git-update-repos.ps1"
    "scripts/update-all.ps1"
) $DevDir -Verbose

# Make shell scripts executable (only if running in WSL/Git Bash context)
$shFiles = @(
    "$DevDir/git-update-repos.sh"
)
$chmodCmd = Get-Command chmod -ErrorAction SilentlyContinue
if ($chmodCmd -and $chmodCmd.Source -notmatch "scoop") {
    foreach ($f in $shFiles) {
        if (Test-Path $f) {
            chmod +x $f 2>$null
        }
    }
}

Write-Host "  Scripts deployed" -ForegroundColor Green
Write-Host ""

# Deploy configs
if (-not $SkipConfig) {
    Write-Host "Deploying configs..." -ForegroundColor Cyan

    # PowerShell profile
    $PwshProfileDir = if ($env:POWERSHELL_PROFILE_CONFIG) { $env:POWERSHELL_PROFILE_CONFIG } else { "$HOME/Documents/PowerShell" }
    if (Test-Path "$DotfilesDir/home/Microsoft.PowerShell_profile.ps1") {
        $ProfileDir = "$PwshProfileDir"
        if (!(Test-Path $ProfileDir)) {
            New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null
        }
        Copy-File "$DotfilesDir/home/Microsoft.PowerShell_profile.ps1" "$ProfileDir/Microsoft.PowerShell_profile.ps1"
        Write-Host "  PowerShell profile" -ForegroundColor Green
    }

    # Git config (merges the template, preserves the live git identity)
    Merge-Gitconfig -Src "$DotfilesDir/home/.gitconfig" -Dst "$HOME/.gitconfig"

    # Git hooks
    $HooksDir = "$ConfigDir/git/hooks"
    if (!(Test-Path $HooksDir)) {
        New-Item -ItemType Directory -Path $HooksDir -Force | Out-Null
    }
    Copy-Files @(
        ".config/git/hooks/pre-commit.ps1"
        ".config/git/hooks/commit-msg.ps1"
    ) $HooksDir

    # Neovim config
    # Windows uses %LOCALAPPDATA%\nvim (stdpath('config'))
    $NvimConfigDir = Join-Path $env:LOCALAPPDATA "nvim"

    if (Test-Path "$DotfilesDir/.config/nvim/init.lua") {
        if (!(Test-Path $NvimConfigDir)) {
            New-Item -ItemType Directory -Path $NvimConfigDir -Force | Out-Null
        }
        Copy-File "$DotfilesDir/.config/nvim/init.lua" "$NvimConfigDir/init.lua"
        Copy-File "$DotfilesDir/.config/nvim/nvim-pack-lock.json" "$NvimConfigDir/nvim-pack-lock.json"
        Write-Host "  Neovim config" -ForegroundColor Green
    }

    # WezTerm config
    # WezTerm uses $HOME/.config/wezterm/wezterm.lua on all platforms including Windows
    if (Test-Path "$DotfilesDir/.config/wezterm/wezterm.lua") {
        $WeztermConfigDir = "$ConfigDir/wezterm"
        if (!(Test-Path $WeztermConfigDir)) {
            New-Item -ItemType Directory -Path $WeztermConfigDir -Force | Out-Null
        }
        Copy-File "$DotfilesDir/.config/wezterm/wezterm.lua" "$WeztermConfigDir/wezterm.lua"
        Write-Host "  WezTerm config" -ForegroundColor Green
    }

    # WezTerm background assets
    if (Test-Path "$DotfilesDir/assets") {
        $assetsDest = Join-Path $env:USERPROFILE "assets"
        if (!(Test-Path $assetsDest)) {
            New-Item -ItemType Directory -Path $assetsDest -Force | Out-Null
        }
        Copy-Item "$DotfilesDir/assets/*" -Destination $assetsDest -Recurse -Force
        Write-Host "  WezTerm background assets" -ForegroundColor Green
    }

    # Claude configs (explicit list; settings.template.json is injector input,
    # never copied, and hooks/*.disabled + tdd-guard are intentionally excluded)
    $ClaudeDir = "$HOME/.claude"
    if (!(Test-Path $ClaudeDir)) {
        New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null
    }

    # Refresh the repo books front from the private corpus; failure is non-fatal
    $SyncBook = Join-Path $DotfilesDir 'scripts/sync-book.ps1'
    if (Test-Path -LiteralPath $SyncBook) {
        & pwsh -NoProfile -File $SyncBook
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  sync-book.ps1 failed, continuing with shipped books" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  sync-book.ps1 not found, continuing with shipped books" -ForegroundColor Yellow
    }

    # Regenerate the books index from the refreshed front; failure is non-fatal
    $BooksIndex = Join-Path $DotfilesDir 'scripts/books-index.ps1'
    if (Test-Path -LiteralPath $BooksIndex) {
        & pwsh -NoProfile -File $BooksIndex
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  books-index.ps1 failed, continuing with the committed index" -ForegroundColor Yellow
        }
    }

    # CLAUDE.md carries a corpus root spliced for this machine between markers
    if (Test-Path -LiteralPath "$DotfilesDir/.claude/CLAUDE.md") {
        Copy-ClaudeMd "$DotfilesDir/.claude/CLAUDE.md" "$ClaudeDir/CLAUDE.md"
    } else {
        Write-Host "  .claude/CLAUDE.md not found, skipping corpus root splice" -ForegroundColor Yellow
    }
    Copy-Files @(
        ".claude/BOOKS.md"
        ".claude/quality-check.sh"
        ".claude/quality-check.ps1"
        ".claude/statusline.sh"
    ) $ClaudeDir
    Copy-ClaudeBooks
    Write-Host "  Claude configs" -ForegroundColor Green

    # Merge settings template into settings.json (template values win for
    # shared keys, live-only keys and ANTHROPIC_AUTH_TOKEN survive, retired
    # keys are deleted)
    Merge-ClaudeSettings -TemplatePath "$DotfilesDir/.claude/settings.template.json" -TargetPath "$HOME/.claude/settings.json"

    # OpenCode config (merge MCP servers)
    $OpencodeConfigDir = "$ConfigDir/opencode"
    if (!(Test-Path $OpencodeConfigDir)) {
        New-Item -ItemType Directory -Path $OpencodeConfigDir -Force | Out-Null
    }
    $OpencodeConfigFile = "$OpencodeConfigDir/opencode.json"
    $DotfilesOpencodeConfig = "$DotfilesDir/.config/opencode/opencode.windows.json"

    if (!(Test-Path $OpencodeConfigFile)) {
        # No existing config, copy from dotfiles
        Copy-Item $DotfilesOpencodeConfig $OpencodeConfigFile -Force
        Write-Host "  OpenCode config (created)" -ForegroundColor Green
    } else {
        # Existing config found, merge MCP servers
        $ExistingConfig = Get-Content $OpencodeConfigFile -Raw | ConvertFrom-Json
        $DotfilesConfig = Get-Content $DotfilesOpencodeConfig -Raw | ConvertFrom-Json

        # Ensure mcp section exists and is an object (not scalar from previous bad merge)
        if ($null -eq $ExistingConfig.mcp) {
            $ExistingConfig | Add-Member -NotePropertyName "mcp" -NotePropertyValue @{}
        } elseif ($ExistingConfig.mcp -isnot [PSCustomObject] -and $ExistingConfig.mcp -isnot [hashtable]) {
            $ExistingConfig.PSObject.Properties.Remove("mcp")
            $ExistingConfig | Add-Member -NotePropertyName "mcp" -NotePropertyValue @{}
        }

        # Helper function to compare objects
        function Compare-Property {
            param($Existing, $Dotfiles, $PropertyName)

            # Guard: if Existing is not an object (e.g., string, int), treat as unequal
            if ($Existing -isnot [PSCustomObject] -and $Existing -isnot [hashtable]) {
                return $false
            }

            $ExistingValue = $Existing.$PropertyName
            $DotfilesValue = $Dotfiles.$PropertyName

            # Handle nested objects
            if ($DotfilesValue -is [PSCustomObject]) {
                if ($null -eq $ExistingValue) { return $false }
                if ($ExistingValue -isnot [PSCustomObject]) { return $false }
                foreach ($Prop in $DotfilesValue.PSObject.Properties) {
                    if (!(Compare-Property -Existing $ExistingValue -Dotfiles $DotfilesValue -PropertyName $Prop.Name)) {
                        return $false
                    }
                }
                return $true
            }

            # Handle arrays
            if ($DotfilesValue -is [Array]) {
                if ($null -eq $ExistingValue) { return $false }
                $ExistingJson = $ExistingValue | ConvertTo-Json -Compress
                $DotfilesJson = $DotfilesValue | ConvertTo-Json -Compress
                return $ExistingJson -eq $DotfilesJson
            }

            # Handle simple values
            return "$ExistingValue" -eq "$DotfilesValue"
        }

        # Merge each MCP server from dotfiles
        $MergedCount = 0
        foreach ($Server in $DotfilesConfig.mcp.PSObject.Properties) {
            $ServerName = $Server.Name
            $ServerConfig = $Server.Value

            if ($null -eq $ExistingConfig.mcp.$ServerName) {
                # Server doesn't exist, add it
                $ExistingConfig.mcp | Add-Member -NotePropertyName $ServerName -NotePropertyValue $ServerConfig -Force
                $MergedCount++
            } elseif ($ExistingConfig.mcp.$ServerName -isnot [PSCustomObject] -and $ExistingConfig.mcp.$ServerName -isnot [hashtable]) {
                # Existing entry is a scalar (malformed), replace it entirely using Add-Member
                $ExistingConfig.mcp.PSObject.Properties.Remove($ServerName)
                $ExistingConfig.mcp | Add-Member -NotePropertyName $ServerName -NotePropertyValue $ServerConfig -Force
                $MergedCount++
            } else {
                # Server exists, check if update needed
                $NeedsUpdate = $false

                foreach ($Prop in $ServerConfig.PSObject.Properties) {
                    $PropName = $Prop.Name
                    if (!(Compare-Property -Existing $ExistingConfig.mcp.$ServerName -Dotfiles $ServerConfig -PropertyName $PropName)) {
                        $ExistingConfig.mcp.$ServerName.$PropName = $ServerConfig.$PropName
                        $NeedsUpdate = $true
                    }
                }

                if ($NeedsUpdate) {
                    $MergedCount++
                }
            }
        }

        if ($MergedCount -gt 0) {
            $ExistingConfig | ConvertTo-Json -Depth 10 | Set-Content $OpencodeConfigFile
            Write-Host "  OpenCode config (merged $MergedCount server(s))" -ForegroundColor Green
        } else {
            Write-Host "  OpenCode config (up to date)" -ForegroundColor Cyan
        }
    }

    Write-Host "  Configs deployed" -ForegroundColor Green
    Write-Host ""

    # Patch Claude LSP marketplace for Windows npm-installed servers
    Patch-ClaudeLspMarketplace
}

# Reload key functions into Global scope so changes take effect immediately
# PowerShell's scope model prevents child scripts from modifying parent scope,
# so we explicitly redefine critical functions with Global: scope
$profilePath = $PROFILE.CurrentUserCurrentHost
if (Test-Path $profilePath) {
    # Define the Update-AllPackages function in Global scope with @args support
    Set-Item -Path Function:\Global:Update-AllPackages -Value {
        & "$env:USERPROFILE/dev/update-all.ps1" @args
    } -Force

    # Recreate the 'up' alias in Global scope
    Set-Alias -Name up -Value Update-AllPackages -Scope Global -Force

    Write-Host "Profile functions reloaded into Global scope" -ForegroundColor Green
}

# Marker read by uninstall.sh; version comes from the CHANGELOG top entry
$Changelog = Join-Path $DotfilesDir "CHANGELOG.md"
$Version = "unknown"
if (Test-Path $Changelog) {
    $Match = Select-String -Path $Changelog -Pattern '^## \[(.+?)\]' | Select-Object -First 1
    if ($Match) { $Version = $Match.Matches[0].Groups[1].Value }
}
@"
deployed_at=$(Get-Date -AsUTC -Format "yyyy-MM-ddTHH:mm:ssZ")
version=$Version
os=windows
"@ | Set-Content "$HOME/.dotfiles-installed"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "           Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Run from ~/dev:" -ForegroundColor Yellow
Write-Host "  .\git-update-repos.ps1"
Write-Host ""
