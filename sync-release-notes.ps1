# Sync CHANGELOG.md sections to GitHub release notes (Pure PowerShell 7)
# Transcribed from sync-release-notes.sh
# Usage: .\sync-release-notes.ps1 [-DryRun]

param(
    [switch]$DryRun
)

# Colors
$C = @{
    R = "`e[0;31m"   # Red
    G = "`e[0;32m"   # Green
    Y = "`e[1;33m"   # Yellow
    B = "`e[0;34m"   # Blue
    C = "`e[0;36m"   # Cyan
    N = "`e[0m"      # No Color
}

function Wc { param($c, $t); Write-Host "$($c)$t$($script:C.N)" }

$ScriptDir = $PSScriptRoot
$Changelog = Join-Path $ScriptDir "CHANGELOG.md"
if (!(Test-Path $Changelog)) { Wc $C.R "Error: CHANGELOG.md not found: $Changelog"; exit 1 }

$RepoUrl = git -C $ScriptDir remote get-url origin
if ($LASTEXITCODE -ne 0) { Wc $C.R "Error: no origin remote"; exit 1 }
$Repo = $RepoUrl -replace '\.git$', '' -replace '.*github\.com[:/]'

$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("release-notes-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $Tmp | Out-Null

# Split the changelog per version with the same heading pattern deploy.ps1
# uses for the version marker, so the two can never disagree about section
# starts. Non-numeric bracket names (an ## [Unreleased] heading) are skipped.
$script:Versions = [System.Collections.Generic.List[string]]::new()
$script:Current = $null
$script:Body = [System.Collections.Generic.List[string]]::new()

function Flush-Section {
    if ($null -ne $script:Current -and $script:Current -match '^[0-9]') {
        $text = ($script:Body -join "`n").Trim("`n")
        [System.IO.File]::WriteAllText((Join-Path $script:Tmp "$($script:Current).md"), $text + "`n")
        $script:Versions.Add($script:Current)
    }
}

foreach ($Line in Get-Content $Changelog) {
    if ($Line -match '^## \[(.+?)\]') {
        Flush-Section
        $script:Current = $Matches[1]
        $script:Body = [System.Collections.Generic.List[string]]::new()
    } elseif ($Line -match '^## ') {
        Flush-Section
        $script:Current = $null
    } elseif ($null -ne $script:Current) {
        $script:Body.Add($Line)
    }
}
Flush-Section

Wc $C.C "========================================"
Wc $C.C "   Release Notes Sync"
Wc $C.C "========================================"
Wc $C.B "Repo:     $Repo"
Wc $C.B "Dry run:  $DryRun"
Wc $C.C "========================================"
Write-Host ""

$Edited = 0
$Created = 0
$Skipped = 0
$Failed = 0

foreach ($Ver in $script:Versions) {
    $Tag = "v$Ver"
    $Notes = Join-Path $Tmp "$Ver.md"

    gh release view $Tag -R $Repo *> $null
    $HasRelease = ($LASTEXITCODE -eq 0)
    $HasTag = [bool](git -C $ScriptDir tag -l $Tag)

    if ($HasRelease) {
        $Action = "edit"
    } elseif ($HasTag) {
        $Action = "create"
    } else {
        Wc $C.Y "skip     $Tag (no git tag)"
        $Skipped++
        continue
    }

    if ($DryRun) { Wc $C.B "$Action  $Tag"; continue }

    if ($Action -eq "edit") {
        gh release edit $Tag -R $Repo --notes-file $Notes *> $null
        if ($LASTEXITCODE -eq 0) { Wc $C.G "edited   $Tag"; $Edited++ }
        else { Wc $C.R "failed   $Tag (gh release edit)"; $Failed++ }
    } else {
        gh release create $Tag -R $Repo --title $Tag --notes-file $Notes --verify-tag *> $null
        if ($LASTEXITCODE -eq 0) { Wc $C.G "created  $Tag"; $Created++ }
        else { Wc $C.R "failed   $Tag (gh release create)"; $Failed++ }
    }
}

Write-Host ""
if ($DryRun) {
    Write-Host "Dry run complete. Rerun without -DryRun to apply."
} else {
    Wc $C.N "Edited: $Edited  Created: $Created  Skipped: $Skipped  Failed: $Failed"
}

Remove-Item -Recurse -Force $Tmp
if ($Failed -gt 0) { exit 1 }
