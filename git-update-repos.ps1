# Update/Clone All GitHub Repositories (Pure PowerShell 7)
# Transcribed from git-update-repos.sh
# Usage: .\git-update-repos.ps1 [-Username] "user" [-BaseDir] "path" [-UseSSH] [-NoSync] [-Commit]

param(
    [string]$Username = (git config user.name 2>$null ?? "lavantien"),
    [string]$BaseDir = "$HOME/dev/github",
    [switch]$UseSSH,
    [switch]$NoSync,
    [switch]$Commit
)

# Colors
$C = @{
    R  = "`e[0;31m"
    G  = "`e[0;32m"
    Y  = "`e[1;33m"
    B  = "`e[0;34m"
    C  = "`e[0;36m"
    N  = "`e[0m"
}

function Wc { param($c, $t); Write-Host "$($c)$t$($script:C.N)" }

# Check for GitHub CLI
$ghCmd = Get-Command gh -ErrorAction SilentlyContinue
if (!$ghCmd) {
    Wc $C.R "Error: GitHub CLI (gh) not found"
    Wc $C.Y "Install it from: https://cli.github.com/"
    Wc $C.Y "Or run your bootstrap script"
    exit 1
}

# Check gh auth
$null = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Wc $C.R "Error: gh not authenticated. Run: gh auth login"
    exit 1
}

Wc $C.C "========================================"
Wc $C.C "   GitHub Repos Updater"
Wc $C.C "========================================"
Wc $C.B "User:           $Username"
Wc $C.B "Directory:      $BaseDir"
Wc $C.B "SSH:            $UseSSH"
Wc $C.B "Sync:           $(-not $NoSync)"
Wc $C.B "Auto-commit:    $Commit"
Wc $C.C "========================================"
Write-Host ""

# Create base directory if needed
if (!(Test-Path $BaseDir)) {
    New-Item -ItemType Directory -Path $BaseDir -Force | Out-Null
    Wc $C.G "Created directory: $BaseDir"
    Write-Host ""
}

Wc $C.C "Fetching repositories via GitHub CLI..."
Write-Host ""

# Fetch repos
$ReposJson = gh repo list --json name,sshUrl,url --limit 1000 2>&1
if ($LASTEXITCODE -ne 0) {
    Wc $C.R "Error fetching repositories"
    exit 1
}

# Parse JSON
$Repos = $ReposJson | ConvertFrom-Json
Wc $C.G "Found $($Repos.Count) repositories"
Write-Host ""

$Cloned = 0
$Updated = 0
$Skipped = 0
$Failed = 0

foreach ($Repo in $Repos) {
    $RepoName = $Repo.name
    $RepoPath = Join-Path $BaseDir $RepoName

    # Choose URL
    $CloneUrl = if ($UseSSH) { $Repo.sshUrl } else { "$($Repo.url).git" }

    if (Test-Path $RepoPath) {
        # Update existing repo
        Write-Host -NoNewline "[$RepoName] "

        Push-Location $RepoPath -ErrorAction SilentlyContinue
        if ($?) {
            if (git rev-parse --git-dir 2>$null) {
                # Check if already up to date
                $Local = git rev-parse HEAD 2>$null
                $Remote = git rev-parse "@{u}" 2>$null

                if ($Local -and $Remote -and $Local -eq $Remote) {
                    Wc $C.B "Skipped (already up to date)"
                    $Skipped++
                } elseif ((git fetch origin 2>&1) -and (git pull 2>&1)) {
                    Wc $C.Y "Updated"
                    $Updated++
                } else {
                    Wc $C.R "Error updating"
                    $Failed++
                }
            } else {
                Wc $C.Y "Skipped (not a git repo)"
                $Skipped++
            }
            Pop-Location
        } else {
            Wc $C.Y "Error accessing"
            $Failed++
        }
    } else {
        # Clone new repo
        Write-Host -NoNewline "[$RepoName] "

        $null = git clone $CloneUrl $RepoPath 2>&1
        if ($LASTEXITCODE -eq 0) {
            Wc $C.G "Cloned"
            $Cloned++
        } else {
            Wc $C.Y "Error cloning"
            $Failed++
        }
    }
}

# Sync system instructions
if (-not $NoSync) {
    Write-Host ""
    Wc $C.C "========================================"
    Wc $C.C "   Syncing System Instructions"
    Wc $C.C "========================================"
    Write-Host ""

    $SyncScript = Join-Path $PSScriptRoot "sync-system-instructions.ps1"
    if (Test-Path $SyncScript) {
        $Args = @("-BaseDir", $BaseDir)
        if ($Commit) { $Args += "-Commit" }
        & $SyncScript @Args
    } else {
        Wc $C.Y "Warning: Sync script not found: $SyncScript"
    }
}

# Summary
Write-Host ""
Wc $C.C "========================================"
Wc $C.C "           Summary"
Wc $C.C "========================================"
Wc $C.G " Cloned:  $Cloned"
Wc $C.Y " Updated: $Updated"
Wc $C.B " Skipped: $Skipped"
if ($Failed -gt 0) { Wc $C.Y " Failed:  $Failed" }
Wc $C.C " Total:   $($Repos.Count) repositories"
Wc $C.C "========================================"
