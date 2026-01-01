#!/usr/bin/env pwsh
# Update/Clone All GitHub Repositories for a User
# Usage: .\git-update-repos.ps1 [-Username] "username" [-BaseDir] "path" [-UseSSH] [-NoSync] [-Commit]

param(
    [string]$Username,
    [string]$BaseDir,
    [switch]$UseSSH,
    [switch]$NoSync,
    [switch]$Commit
    )

# Set defaults with environment variable fallback
if (-not $Username) {
    $Username = if ($env:GITHUB_USERNAME) { $env:GITHUB_USERNAME }
                 elseif (git config user.name 2>$null) { git config user.name }
                 else { "lavantien" }
}

if (-not $BaseDir) {
    $BaseDir = if ($env:GIT_BASE_DIR) { $env:GIT_BASE_DIR } else { "$HOME\dev\github" }
}

# Colors
$E = [char]27
$R = "$E[0m"
$GREEN = "$E[32m"
$YELLOW = "$E[33m"
$BLUE = "$E[34m"
$CYAN = "$E[36m"

# Path to sync script (relative to this script)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SyncScript = Join-Path $ScriptDir "sync-system-instructions.ps1"

Write-Host "${CYAN}========================================${R}"
Write-Host "${CYAN}   GitHub Repos Updater${R}"
Write-Host "${CYAN}========================================${R}"
Write-Host "${BLUE}User:${R}       $Username"
Write-Host "${BLUE}Directory:${R}   $BaseDir"
Write-Host "${BLUE}SSH:${R}        $($UseSSH.IsPresent)"
Write-Host "${BLUE}Sync:${R}       $(-not $NoSync.IsPresent)"
Write-Host "${BLUE}Auto-commit:${R} $($Commit.IsPresent)"
Write-Host "${CYAN}========================================${R}`n"

# Create base directory if it doesn't exist
if (-not (Test-Path $BaseDir)) {
    New-Item -ItemType Directory -Path $BaseDir | Out-Null
    Write-Host "${GREEN}Created directory:${R} $BaseDir`n"
}

Write-Host "${CYAN}Fetching repositories for user: $Username${R}`n"

# Fetch all repositories (including private if you have a token)
$apiUrl = "https://api.github.com/users/$Username/repos?per_page=100&type=all"

try {
    $repos = Invoke-RestMethod -Uri $apiUrl
} catch {
    Write-Host "${YELLOW}Error fetching repos: $_${R}"
    exit 1
}

# Handle pagination if more than 100 repos
$page = 2
while ($repos.Count -gt 0 -and $repos.Count % 100 -eq 0) {
    try {
        $moreRepos = Invoke-RestMethod -Uri "$apiUrl&page=$page"
        if ($moreRepos) {
            $repos += $moreRepos
            $page++
        } else {
            break
        }
    } catch {
        break
    }
}

Write-Host "${GREEN}Found $($repos.Count) repositories${R}`n"

$cloned = 0
$updated = 0
$skipped = 0
$failed = 0

foreach ($repo in $repos) {
    $repoName = $repo.name
    $repoPath = Join-Path $BaseDir $repoName

    # Choose clone URL based on SSH flag
    if ($UseSSH) {
        $cloneUrl = $repo.ssh_url
    } else {
        $cloneUrl = $repo.clone_url
    }

    if (Test-Path $repoPath) {
        # Repo exists, update it
        Write-Host "[$repoName] " -NoNewline
        try {
            Push-Location $repoPath

            # Check if we're in a git repo
            $isGitRepo = git rev-parse --git-dir 2>$null

            if ($isGitRepo) {
                # Fetch and pull
                git fetch origin --quiet 2>$null
                $pullResult = git pull --quiet 2>$null

                Pop-Location
                Write-Host "${YELLOW}Updated${R}"
                $updated++
            } else {
                Pop-Location
                Write-Host "${YELLOW}Skipped (not a git repo)${R}"
                $skipped++
            }
        } catch {
            Pop-Location
            Write-Host "${YELLOW}Error updating: $_${R}"
            $failed++
        }
    } else {
        # Repo doesn't exist, clone it
        Write-Host "[$repoName] " -NoNewline
        try {
            git clone --quiet $cloneUrl $repoPath 2>$null
            Write-Host "${GREEN}Cloned${R}"
            $cloned++
        } catch {
            Write-Host "${YELLOW}Error cloning: $_${R}"
            $failed++
        }
    }
}

# Sync system instructions to all repos
if (-not $NoSync.IsPresent) {
    Write-Host "`n${CYAN}========================================${R}"
    Write-Host "${CYAN}   Syncing System Instructions${R}"
    Write-Host "${CYAN}========================================${R}"

    if (Test-Path $SyncScript) {
        if ($Commit.IsPresent) {
            & $SyncScript -BaseDir $BaseDir -Commit
        } else {
            & $SyncScript -BaseDir $BaseDir
        }
    } else {
        Write-Host "${YELLOW}Warning: Sync script not found: $SyncScript${R}"
    }
}

# Summary
Write-Host "`n${CYAN}========================================${R}"
Write-Host "${CYAN}           Summary${R}"
Write-Host "${CYAN}========================================${R}"
Write-Host " ${GREEN}Cloned:${R}  $cloned"
Write-Host " ${YELLOW}Updated:${R} $updated"
Write-Host " ${BLUE}Skipped:${R} $skipped"
if ($failed -gt 0) {
    Write-Host " ${YELLOW}Failed:${R}   $failed"
}
Write-Host " ${CYAN}Total:${R}    $($repos.Count) repositories"
Write-Host "${CYAN}========================================${R}"
