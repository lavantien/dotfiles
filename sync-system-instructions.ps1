#!/usr/bin/env pwsh
# Sync System Instructions to All Repositories
# Usage: .\sync-system-instructions.ps1 [-BaseDir] "path" [-Commit] [-Push]

param(
    [string]$BaseDir = "$HOME\dev\github",
    [switch]$Commit,
    [switch]$Push
)

# Colors
$E = [char]27
$R = "$E[0m"
$GREEN = "$E[32m"
$YELLOW = "$E[33m"
$BLUE = "$E[34m"
$CYAN = "$E[36m"
$RED = "$E[31m"

# Markdown files to sync to all repos
$MARKDOWN_FILES = @("CLAUDE.md", "AGENTS.md", "GEMINI.md", "RULES.md")

# Source directory for markdown files (dotfiles repo location)
$DOTFILES_DIR = "$HOME\dev\github\dotfiles"

Write-Host "${CYAN}========================================${R}"
Write-Host "${CYAN}   System Instructions Sync${R}"
Write-Host "${CYAN}========================================${R}"
Write-Host "${BLUE}Base Directory:${R} $BaseDir"
Write-Host "${BLUE}Commit:${R}      $($Commit.IsPresent)"
Write-Host "${BLUE}Push:${R}        $($Push.IsPresent)"
Write-Host "${CYAN}========================================${R}`n"

# Validate base directory exists
if (-not (Test-Path $BaseDir)) {
    Write-Host "${RED}Error: Directory not found: $BaseDir${R}"
    exit 1
}

# Validate dotfiles directory exists
if (-not (Test-Path $DOTFILES_DIR)) {
    Write-Host "${RED}Error: Dotfiles directory not found: $DOTFILES_DIR${R}"
    exit 1
}

# Copy system instruction markdown files to a repository
function Copy-MarkdownFiles {
    param([string]$RepoPath)

    # Skip if dotfiles dir (don't copy to self)
    $dotfilesResolved = (Resolve-Path $DOTFILES_DIR -ErrorAction SilentlyContinue).Path
    $repoResolved = (Resolve-Path $RepoPath -ErrorAction SilentlyContinue).Path

    if ($dotfilesResolved -and $repoResolved -and $dotfilesResolved -eq $repoResolved) {
        return $false
    }

    # Check if it's a git repository
    Push-Location $RepoPath -ErrorAction SilentlyContinue
    if (-not (git rev-parse --git-dir 2>$null)) {
        Pop-Location -ErrorAction SilentlyContinue
        return $false
    }
    Pop-Location -ErrorAction SilentlyContinue

    $copiedCount = 0
    $hasChanges = $false

    foreach ($mdFile in $MARKDOWN_FILES) {
        $sourceFile = Join-Path $DOTFILES_DIR $mdFile
        $targetFile = Join-Path $RepoPath $mdFile

        if (Test-Path $sourceFile) {
            # Check if file is different
            if (-not (Test-Path $targetFile)) {
                try {
                    Copy-Item -Path $sourceFile -Destination $RepoPath -Force -ErrorAction Stop | Out-Null
                    Write-Host "    ${GREEN}synced${R} $mdFile"
                    $copiedCount++
                    $hasChanges = $true
                } catch {
                    # Silently skip errors
                }
            } else {
                # Compare file contents
                $sourceHash = (Get-FileHash $sourceFile -Algorithm SHA256).Hash
                $targetHash = (Get-FileHash $targetFile -Algorithm SHA256).Hash

                if ($sourceHash -ne $targetHash) {
                    try {
                        Copy-Item -Path $sourceFile -Destination $RepoPath -Force -ErrorAction Stop | Out-Null
                        Write-Host "    ${GREEN}synced${R} $mdFile"
                        $copiedCount++
                        $hasChanges = $true
                    } catch {
                        # Silently skip errors
                    }
                }
            }
        }
    }

    if ($copiedCount -gt 0) {
        Write-Host "    ${BLUE}system instructions updated ($copiedCount files)${R}"
        return $true
    } elseif (-not $hasChanges) {
        Write-Host "    ${YELLOW}already up to date${R}"
        return $false
    }
}

# Commit changes using git directly
function Commit-Changes {
    param([string]$RepoPath)

    $repoName = Split-Path $RepoPath -Leaf

    Push-Location $RepoPath -ErrorAction SilentlyContinue
    if (-not $?) {
        return
    }

    # Check if there are changes to commit
    $changes = git diff --quiet CLAUDE.md AGENTS.md GEMINI.md RULES.md 2>$null; $hasChanges = -not $?

    if ($hasChanges) {
        # Add and commit
        git add CLAUDE.md AGENTS.md GEMINI.md RULES.md 2>$null
        $null = git commit -m "chore: sync system instructions" 2>$null
        if ($?) {
            Write-Host "    ${GREEN}committed${R} $repoName"
        }
    }

    Pop-Location -ErrorAction SilentlyContinue
}

# Push changes using git
function Push-Changes {
    param([string]$RepoPath)

    $repoName = Split-Path $RepoPath -Leaf

    Push-Location $RepoPath -ErrorAction SilentlyContinue
    if (-not $?) {
        return
    }

    $null = git push origin 2>$null
    if ($?) {
        Write-Host "    ${GREEN}pushed${R} $repoName"
    } else {
        Write-Host "    ${YELLOW}push failed${R} $repoName"
    }

    Pop-Location -ErrorAction SilentlyContinue
}

# Commit and push using Claude CLI (if available)
function Commit-WithClaude {
    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $claudeCmd) {
        Write-Host "${YELLOW}Claude CLI not found - skipping${R}"
        return
    }

    Write-Host "${BLUE}Committing system instructions via Claude CLI...${R}"
    Write-Host "    ${CYAN}ANTHROPIC_LOG=info${R} enabled (normal session output)"
    $env:ANTHROPIC_LOG = "info"
    Push-Location $BaseDir
    claude -p --permission-mode bypassPermissions "go into every repo inside this directory, commit CLAUDE.md AGENTS.md GEMINI.md RULES.md with message 'chore: sync system instructions', and push to origin"
    Pop-Location
    Remove-Item Env:ANTHROPIC_LOG -ErrorAction SilentlyContinue
}

# Main processing
$repoCount = 0
$syncedCount = 0
$skippedCount = 0

Write-Host "${CYAN}Scanning for repositories in: $BaseDir${R}`n"

$dirs = Get-ChildItem -Directory $BaseDir -ErrorAction SilentlyContinue
foreach ($dir in $dirs) {
    $repoName = $dir.Name
    Write-Host "[$repoName] " -NoNewline

    if (Copy-MarkdownFiles $dir.FullName) {
        $syncedCount++
    } else {
        $skippedCount++
    }
    $repoCount++
}

# Commit and push if requested
if ($Commit.IsPresent) {
    Write-Host "`n${CYAN}Committing changes...${R}"

    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    if ($claudeCmd -and $Push.IsPresent) {
        # Use Claude CLI for commit + push
        Commit-WithClaude
    } else {
        # Use native git
        foreach ($dir in $dirs) {
            Commit-Changes $dir.FullName
            if ($Push.IsPresent) {
                Push-Changes $dir.FullName
            }
        }
    }
}

# Summary
Write-Host "`n${CYAN}========================================${R}"
Write-Host "${CYAN}           Summary${R}"
Write-Host "${CYAN}========================================${R}"
Write-Host " ${GREEN}Synced:${R}   $syncedCount"
Write-Host " ${YELLOW}Skipped:${R}  $skippedCount"
Write-Host " ${CYAN}Total:${R}     $repoCount repositories"
Write-Host "${CYAN}========================================${R}"
