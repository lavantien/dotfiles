# Sync System Instructions to All Repositories (Pure PowerShell 7)
# Transcribed from sync-system-instructions.sh
# Usage: .\sync-system-instructions.ps1 [-BaseDir] "path" [-Commit] [-Push]

param(
    [string]$BaseDir = "$HOME/dev/github",
    [switch]$Commit,
    [switch]$Push
)

# Colors
$C = @{
    R  = "`e[0;31m"   # Red
    G  = "`e[0;32m"   # Green
    Y  = "`e[1;33m"   # Yellow
    B  = "`e[0;34m"   # Blue
    C  = "`e[0;36m"   # Cyan
    N  = "`e[0m"      # No Color
}

function Wc { param($c, $t); Write-Host "$($c)$t$($C.N)" }

# Markdown files to sync
$MdFiles = @(
    @{ Src = ".claude/CLAUDE.md"; Dst = "CLAUDE.md" }
    @{ Src = "AGENTS.md"; Dst = "AGENTS.md" }
    @{ Src = "GEMINI.md"; Dst = "GEMINI.md" }
    @{ Src = "RULES.md"; Dst = "RULES.md" }
)

$DotDir = "$HOME/dev/github/dotfiles"

Wc $C.C "========================================"
Wc $C.C "   System Instructions Sync"
Wc $C.C "========================================"
Wc $C.B "Base Directory: $BaseDir"
Wc $C.B "Commit:         $Commit"
Wc $C.B "Push:           $Push"
Wc $C.C "========================================"
Write-Host ""

if (!(Test-Path $BaseDir)) { Wc $C.R "Error: Directory not found: $BaseDir"; exit 1 }
if (!(Test-Path $DotDir)) { Wc $C.R "Error: Dotfiles directory not found: $DotDir"; exit 1 }

$DotDirAbs = (Resolve-Path $DotDir).Path

function Copy-MdFiles {
    param([string]$RepoPath)

    $RepoName = Split-Path $RepoPath -Leaf

    # Skip dotfiles itself
    try {
        $RepoAbs = (Resolve-Path $RepoPath).Path
    } catch { $RepoAbs = $RepoPath }
    if ($RepoAbs -eq $DotDirAbs) { return @{ N=$RepoName; Ok=$false } }

    # Check if git repo
    $GitDir = Join-Path $RepoPath ".git"
    if (!(Test-Path $GitDir)) { return @{ N=$RepoName; Ok=$false } }

    $Copied = 0
    $Output = @()

    foreach ($f in $MdFiles) {
        $Src = Join-Path $DotDir $f.Src
        $Dst = Join-Path $RepoPath $f.Dst

        if (Test-Path $Src) {
            $NeedCopy = $false
            if (!(Test-Path $Dst)) {
                $NeedCopy = $true
            } else {
                # Compare files using byte comparison (like cmp)
                $SrcHash = (Get-FileHash $Src -Algorithm SHA256).Hash
                $DstHash = (Get-FileHash $Dst -Algorithm SHA256).Hash
                if ($SrcHash -ne $DstHash) { $NeedCopy = $true }
            }

            if ($NeedCopy) {
                try {
                    Copy-Item $Src $Dst -Force
                    $Output += "    synced $($f.Dst)"
                    $Copied++
                } catch {
                    $Output += "    failed to sync $($f.Dst)"
                }
            }
        }
    }

    if ($Copied -gt 0) {
        $Output += "    system instructions updated ($Copied files)"
        return @{ N=$RepoName; Ok=$true; Out=$Output }
    } else {
        return @{ N=$RepoName; Ok=$false; Out="    already up to date" }
    }
}

function Commit-Repo {
    param([string]$RepoPath)

    $RepoName = Split-Path $RepoPath -Leaf
    Push-Location $RepoPath -ErrorAction SilentlyContinue
    if (!$?) { return @{ N=$RepoName; Ok=$false; Out="" } }

    try {
        # Check for changes
        $Status = git status --porcelain CLAUDE.md AGENTS.md GEMINI.md RULES.md 2>$null
        if ([string]::IsNullOrWhiteSpace($Status)) {
            Pop-Location
            return @{ N=$RepoName; Ok=$false; Out="    already up to date (no changes to commit)" }
        }

        # Stage files
        $null = git add CLAUDE.md AGENTS.md GEMINI.md RULES.md 2>$null

        # Get git config from dotfiles
        $UserName = git -C $DotDir config user.name 2>$null
        $UserEmail = git -C $DotDir config user.email 2>$null

        # Commit with config override
        if ($UserName -and $UserEmail) {
            $env:GIT_AUTHOR_NAME = $UserName
            $env:GIT_AUTHOR_EMAIL = $UserEmail
            $env:GIT_COMMITTER_NAME = $UserName
            $env:GIT_COMMITTER_EMAIL = $UserEmail
        }

        $null = git commit -m "chore: sync system instructions" 2>$null

        if ($UserName -and $UserEmail) {
            $env:GIT_AUTHOR_NAME = $null
            $env:GIT_AUTHOR_EMAIL = $null
            $env:GIT_COMMITTER_NAME = $null
            $env:GIT_COMMITTER_EMAIL = $null
        }

        if ($LASTEXITCODE -eq 0) {
            Pop-Location
            return @{ N=$RepoName; Ok=$true; Out="    committed $RepoName" }
        } else {
            Pop-Location
            return @{ N=$RepoName; Ok=$false; Out="    commit failed $RepoName" }
        }
    } catch {
        Pop-Location
        return @{ N=$RepoName; Ok=$false; Out="    commit failed: $_" }
    }
}

function Push-Repo {
    param([string]$RepoPath)

    $RepoName = Split-Path $RepoPath -Leaf
    Push-Location $RepoPath -ErrorAction SilentlyContinue
    if (!$?) { return @{ N=$RepoName; Ok=$false; Out="" } }

    try {
        $Branch = git rev-parse --abbrev-ref HEAD 2>$null
        if (!$Branch) { $Branch = "main" }

        # Check if ahead
        $Ahead = git rev-list --count "origin/$Branch..HEAD" 2>$null
        if ($Ahead -eq 0) {
            Pop-Location
            return @{ N=$RepoName; Ok=$false; Out="    already up to date (nothing to push)" }
        }

        $null = git push origin $Branch 2>$null
        if ($LASTEXITCODE -eq 0) {
            Pop-Location
            return @{ N=$RepoName; Ok=$true; Out="    pushed $RepoName" }
        } else {
            Pop-Location
            return @{ N=$RepoName; Ok=$false; Out="    push failed $RepoName" }
        }
    } catch {
        Pop-Location
        return @{ N=$RepoName; Ok=$false; Out="    push failed: $_" }
    }
}

# Main processing
Wc $C.C "Scanning for repositories in: $BaseDir"
Write-Host ""

$Dirs = Get-ChildItem -Directory $BaseDir
$RepoCount = 0
$SyncedCount = 0
$SkippedCount = 0

foreach ($d in $Dirs) {
    $RepoCount++
    $Result = Copy-MdFiles -RepoPath $d.FullName
    Write-Host -NoNewline "[$($Result.N)] "

    if ($Result.Ok) {
        foreach ($line in $Result.Out) { Wc $C.G $line }
        Wc $C.B "    system instructions updated ($($Result.Out.Count - 1) files)"
        $SyncedCount++
    } else {
        Wc $C.Y $Result.Out
        $SkippedCount++
    }
}

# Commit phase
if ($Commit) {
    Write-Host ""
    Wc $C.C "Committing changes..."

    foreach ($d in $Dirs) {
        $Result = Commit-Repo -RepoPath $d.FullName
        if ($Result.Out -ne "") {
            if ($Result.Ok) { Wc $C.G $Result.Out }
            else { Wc $C.Y $Result.Out }
        }

        if ($Push) {
            $PushResult = Push-Repo -RepoPath $d.FullName
            if ($PushResult.Out -ne "") {
                if ($PushResult.Ok) { Wc $C.G $PushResult.Out }
                else { Wc $C.Y $PushResult.Out }
            }
        }
    }
}

# Summary
Write-Host ""
Wc $C.C "========================================"
Wc $C.C "           Summary"
Wc $C.C "========================================"
Wc $C.G " Synced:   $SyncedCount"
Wc $C.Y " Skipped:  $SkippedCount"
Wc $C.C " Total:     $RepoCount repositories"
Wc $C.C "========================================"
