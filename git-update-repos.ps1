#!/usr/bin/env pwsh
# Update/Clone All GitHub Repositories for a User
# Usage: .\git-update-repos.ps1 [-Username] "username" [-BaseDir] "path" [-UseSSH]

param(
    [string]$Username = "lavantien",
    [string]$BaseDir = "$HOME\dev\github",
    [switch]$UseSSH
)

# Colors
$E = [char]27
$R = "$E[0m"
$GREEN = "$E[32m"
$YELLOW = "$E[33m"
$BLUE = "$E[34m"
$CYAN = "$E[36m"

# Markdown files to sync to all repos
$MARKDOWN_FILES = @("CLAUDE.md", "AGENTS.md", "GEMINI.md", "RULES.md")

# Source directory for markdown files (dotfiles repo location)
$DOTFILES_DIR = "$HOME\dev\github\dotfiles"

Write-Host "${CYAN}========================================${R}"
Write-Host "${CYAN}   GitHub Repos Updater${R}"
Write-Host "${CYAN}========================================${R}"
Write-Host "${BLUE}User:${R}     $Username"
Write-Host "${BLUE}Directory:${R} $BaseDir"
Write-Host "${BLUE}SSH:${R}      $($UseSSH.IsPresent)"
Write-Host "${CYAN}========================================${R}`n"

# Create base directory if it doesn't exist
if (-not (Test-Path $BaseDir)) {
    New-Item -ItemType Directory -Path $BaseDir | Out-Null
    Write-Host "${GREEN}Created directory:${R} $BaseDir`n"
}

Write-Host "${CYAN}Fetching repositories for user: $Username${R}`n"

# Copy system instruction markdown files to a repository
function Copy-MarkdownFiles {
    param([string]$RepoPath)

    # Skip if dotfiles dir (don't copy to self)
    $dotfilesResolved = (Resolve-Path $DOTFILES_DIR -ErrorAction SilentlyContinue).Path
    $repoResolved = (Resolve-Path $RepoPath -ErrorAction SilentlyContinue).Path

    if ($dotfilesResolved -and $repoResolved -and $dotfilesResolved -eq $repoResolved) {
        return
    }

    foreach ($mdFile in $MARKDOWN_FILES) {
        $sourceFile = Join-Path $DOTFILES_DIR $mdFile
        if (Test-Path $sourceFile) {
            Copy-Item -Path $sourceFile -Destination $RepoPath -Force -ErrorAction SilentlyContinue
        }
    }
}

# Commit and push markdown files using Claude CLI
function Commit-WithClaude {
    # Check if claude CLI is available
    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $claudeCmd) {
        return
    }

    Write-Host "${BLUE}Claude CLI detected - committing system instructions...${R}"
    Push-Location $BaseDir
    claude -p --permission-mode bypassPermissions "go into every repo inside this directory, commit the system instructions files, and push to origin"
    Pop-Location
}

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
                # Copy markdown files to existing repo
                Copy-MarkdownFiles $repoPath
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
            # Copy markdown files to newly cloned repo
            Copy-MarkdownFiles $repoPath
        } catch {
            Write-Host "${YELLOW}Error cloning: $_${R}"
            $failed++
        }
    }
}

# Commit and push markdown files using Claude CLI if available
Write-Host "`n"
Commit-WithClaude

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
