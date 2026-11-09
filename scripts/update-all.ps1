#requires -Version 7
param([switch]$SkipPip)

$PSNativeCommandUseErrorActionPreference = $false
$ErrorActionPreference = 'Continue'

function Write-Step { Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] $args" -ForegroundColor Cyan }
function Write-Success { Write-Host "  $args" -ForegroundColor Green }
function Write-Skip { Write-Host "  Skipped: $args" -ForegroundColor Yellow }
function Write-Fail { Write-Host "  $args" -ForegroundColor Yellow }
function Write-Info { Write-Host "  $args" -ForegroundColor Gray }

$script:updated = 0
$script:skipped = 0
$script:failed = 0

$MinFreeSpaceGB = 10

$WingetLocationUpgrades = @{
    "Blizzard.BattleNet" = "C:\Program Files (x86)\Battle.net"
}

$WingetExitNotes = @{
    -1978335188 = 'upgrade --all completed with failures'
}

function Test-Command {
    param([string]$Name)

    if ($Name -eq "winget") {
        $wingetPath = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\winget.exe"
        if (Test-Path $wingetPath) {
            $result = & $wingetPath --version 2>&1
            return $LASTEXITCODE -eq 0
        }
        return $false
    }

    $null = Get-Command $Name -ErrorAction SilentlyContinue
    return $?
}

function Test-IsElevated {
    $principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-UpdateDriveRoots {
    @($env:TEMP, $env:USERPROFILE) |
        ForEach-Object { [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($_)) } |
        Where-Object { $_ } |
        Sort-Object -Unique
}

function Test-DiskSpace {
    foreach ($root in (Get-UpdateDriveRoots)) {
        $drive = Get-PSDrive -Name ($root.TrimEnd('\', ':')) -ErrorAction SilentlyContinue
        if ($drive -and $null -ne $drive.Free -and $drive.Free -lt $MinFreeSpaceGB * 1GB) {
            return $false
        }
    }
    return $true
}

function Invoke-WingetBatch {
    param(
        [string]$WingetExe,
        [object[]]$Batch
    )

    if (Test-IsElevated) {
        Write-Info "already elevated, running winget batch inline"
        foreach ($cmdArgs in $Batch) {
            $cmdArgs = @($cmdArgs)
            $output = & $WingetExe @cmdArgs 2>&1
            [pscustomobject]@{ Code = $LASTEXITCODE; Output = @($output) }
        }
        return
    }

    $tag = [guid]::NewGuid().ToString('N')
    $batchPath = Join-Path $env:TEMP "winget-batch-$tag.json"
    $logPath = Join-Path $env:TEMP "winget-batch-$tag.log"
    ConvertTo-Json @($Batch) -Compress -Depth 3 | Set-Content -LiteralPath $batchPath -Encoding utf8
    New-Item -ItemType File -Path $logPath -Force | Out-Null

    $child = @'
$ErrorActionPreference = 'Continue'
$batch = @(Get-Content -Raw -LiteralPath '<batch>' | ConvertFrom-Json)
foreach ($cmdArgs in $batch) {
    $cmdArgs = @($cmdArgs)
    $output = & '<winget>' @cmdArgs *>&1
    $code = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 127 }
    if ($output) { $output | Add-Content -LiteralPath '<log>' -Encoding utf8 }
    "WINGET_RESULT|<tag>|$code" | Add-Content -LiteralPath '<log>' -Encoding utf8
}
exit 0
'@
    $child = $child.
        Replace('<batch>', $batchPath.Replace("'", "''")).
        Replace('<winget>', $WingetExe.Replace("'", "''")).
        Replace('<log>', $logPath.Replace("'", "''")).
        Replace('<tag>', $tag)
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($child))

    Write-Info "elevating winget batch, one UAC prompt covers every upgrade"
    try {
        $proc = Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList @('-NoProfile', '-NonInteractive', '-EncodedCommand', $encoded) -Verb RunAs -WindowStyle Hidden -PassThru -Wait
    }
    catch {
        $reason = $_.Exception.Message
        Write-Info "elevation failed: $reason"
        Remove-Item $batchPath, $logPath -Force -ErrorAction SilentlyContinue
        $declined = $reason -match 'cancel'
        $code = if ($declined) { 1223 } else { -1 }
        $message = if ($declined) { 'UAC elevation was declined' } else { "winget batch could not elevate: $reason" }
        foreach ($cmdArgs in $Batch) {
            [pscustomobject]@{ Code = $code; Output = @($message) }
        }
        return
    }

    $logLines = @(Get-Content -LiteralPath $logPath)
    Remove-Item $batchPath, $logPath -Force -ErrorAction SilentlyContinue

    $marker = '^WINGET_RESULT\|' + [regex]::Escape($tag) + '\|(-?\d+)$'
    $outcomes = [System.Collections.Generic.List[object]]::new()
    $pending = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $logLines) {
        if ($line -match $marker) {
            $outcomes.Add([pscustomobject]@{ Code = [int]$matches[1]; Output = @($pending) })
            $pending = [System.Collections.Generic.List[string]]::new()
        }
        else {
            $pending.Add($line)
        }
    }
    if ($outcomes.Count -lt $Batch.Count) {
        Write-Info "elevated batch exited with $($proc.ExitCode), $($Batch.Count - $outcomes.Count) command(s) left no result marker"
    }
    while ($outcomes.Count -lt $Batch.Count) {
        $outcomes.Add([pscustomobject]@{ Code = $proc.ExitCode; Output = @($pending) })
        $pending = [System.Collections.Generic.List[string]]::new()
    }
    $outcomes
}

function Main {
    Write-Host "`n========================================" -ForegroundColor Blue
    Write-Host "   Native Windows Update All" -ForegroundColor Blue
    Write-Host "========================================" -ForegroundColor Blue

    $startTime = Get-Date

    if (-not (Test-DiskSpace)) {
        foreach ($root in (Get-UpdateDriveRoots)) {
            $drive = Get-PSDrive -Name ($root.TrimEnd('\', ':')) -ErrorAction SilentlyContinue
            if ($drive -and $null -ne $drive.Free -and $drive.Free -lt $MinFreeSpaceGB * 1GB) {
                $freeGB = [math]::Round($drive.Free / 1GB, 1)
                Write-Host "Error: $root has $freeGB GB free, an update run needs at least $MinFreeSpaceGB GB." -ForegroundColor Red
            }
        }
        Write-Host "Free disk space on the temp or profile drive, then rerun update-all." -ForegroundColor Yellow
        return
    }

    Write-Step "Checking package managers..."
    $hasManager = $false

    if (Test-Command scoop) {
        Write-Success "Scoop"
        $hasManager = $true
    }
    else {
        Write-Skip "Scoop not found"
    }

    if (Test-Command winget) {
        Write-Success "winget"
        $hasManager = $true
    }
    else {
        Write-Skip "winget not found"
    }

    if (Test-Command choco) {
        Write-Success "Chocolatey"
        $hasManager = $true
    }
    else {
        Write-Skip "Chocolatey not found"
    }

    if ($SkipPip) {
        Write-Skip "PIP (skipped by -SkipPip flag)"
    }

    if (-not $hasManager) {
        Write-Host "`nError: No package managers found!" -ForegroundColor Red
        Write-Host "Please install Scoop, winget, or Chocolatey" -ForegroundColor Yellow
        return
    }

    Write-Step "SCOOP"
    if (Test-Command scoop) {
        try {
            $LASTEXITCODE = 0
            scoop update -a
            if ($LASTEXITCODE -eq 0) {
                Write-Success "scoop"
                $script:updated++
            }
            else {
                Write-Fail "scoop"
                $script:failed++
            }
        }
        catch {
            Write-Fail "scoop"
            $script:failed++
        }
    }
    else {
        Write-Skip "Scoop not found"
        $script:skipped++
    }

    Write-Step "WINGET"
    if (Test-Command winget) {
        $wingetExe = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\winget.exe"

        $wingetBatch = @()
        foreach ($pkg in $WingetLocationUpgrades.GetEnumerator()) {
            $installed = & $wingetExe list --id $pkg.Key --exact --accept-source-agreements 2>$null |
                Select-String -SimpleMatch $pkg.Key
            if (-not $installed) { continue }

            & $wingetExe pin add --id $pkg.Key --exact --accept-source-agreements 2>$null
            $wingetBatch += , @('upgrade', '--id', $pkg.Key, '--exact', '--include-unknown', '--location', $pkg.Value, '--accept-source-agreements', '--accept-package-agreements')
        }

        $wingetBatch += , @('upgrade', '--all', '--include-unknown', '--accept-source-agreements', '--accept-package-agreements')

        $results = @(Invoke-WingetBatch -WingetExe $wingetExe -Batch $wingetBatch)
        for ($i = 0; $i -lt $wingetBatch.Count; $i++) {
            $cmdArgs = $wingetBatch[$i]
            $idIndex = [array]::IndexOf($cmdArgs, '--id')
            $label = if ($idIndex -ge 0) { $cmdArgs[$idIndex + 1] } else { 'winget' }
            $result = $results[$i]

            if ($result.Output) {
                $result.Output | ForEach-Object { Write-Host "  $_" }
            }
            if ($result.Code -eq 0) {
                Write-Success $label
                $script:updated++
            }
            elseif (($result.Output -join "`n") -match 'No available upgrade') {
                Write-Skip "$label (up to date)"
                $script:skipped++
            }
            else {
                Write-Fail "$label (exit $($result.Code))"
                $note = $WingetExitNotes[$result.Code]
                if ($note) {
                    Write-Info $note
                }
                $script:failed++
            }
        }
    }
    else {
        Write-Skip "winget not found"
        $script:skipped++
    }

    Write-Step "CHOCOLATEY"
    if (Test-Command choco) {
        try {
            choco upgrade all -y
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Chocolatey"
                $script:updated++
            }
            else {
                Write-Fail "Chocolatey"
                $script:failed++
            }
        }
        catch {
            Write-Fail "Chocolatey"
            $script:failed++
        }
    }
    else {
        Write-Skip "Chocolatey not found"
        $script:skipped++
    }

    Write-Step "NPM (Node.js global packages)"
    if (Test-Command npm) {
        try {
            Write-Info "Updating npm itself..."
            npm install -g npm@latest
            $npmSelf = $LASTEXITCODE
            npm update -g
            if ($npmSelf -eq 0 -and $LASTEXITCODE -eq 0) {
                Write-Success "npm"
                $script:updated++
            }
            else {
                Write-Fail "npm"
                $script:failed++
            }
        }
        catch {
            Write-Fail "npm"
            $script:failed++
        }
    }
    else {
        Write-Skip "npm not found"
        $script:skipped++
    }

    Write-Step "PNPM"
    if (Test-Command pnpm) {
        try {
            pnpm update -g
            if ($LASTEXITCODE -eq 0) {
                Write-Success "pnpm"
                $script:updated++
            }
            else {
                Write-Fail "pnpm"
                $script:failed++
            }
        }
        catch {
            Write-Fail "pnpm"
            $script:failed++
        }
    }
    else {
        Write-Skip "pnpm not found"
        $script:skipped++
    }

    Write-Step "BUN (JavaScript runtime and package manager)"
    if (Test-Command bun) {
        try {
            $bunOk = $true
            bun upgrade
            if ($LASTEXITCODE -ne 0) { $bunOk = $false }

            $globalPackages = bun pm ls -g 2>&1 | Select-String -Pattern "^\w" | Measure-Object
            $hasGlobalPackages = $globalPackages.Count -gt 0

            if ($hasGlobalPackages) {
                bun update -g
                if ($LASTEXITCODE -ne 0) { $bunOk = $false }
            }

            if ($bunOk) {
                Write-Success "bun"
                $script:updated++
            }
            else {
                Write-Fail "bun"
                $script:failed++
            }
        }
        catch {
            Write-Fail "bun"
            $script:failed++
        }
    }
    else {
        Write-Skip "bun not found"
        $script:skipped++
    }

    Write-Step "YARN"
    if (Test-Command yarn) {
        try {
            yarn global upgrade
            if ($LASTEXITCODE -eq 0) {
                Write-Success "yarn"
                $script:updated++
            }
            else {
                Write-Fail "yarn"
                $script:failed++
            }
        }
        catch {
            Write-Fail "yarn"
            $script:failed++
        }
    }
    else {
        Write-Skip "yarn not found"
        $script:skipped++
    }

    Write-Step "GUP (Go global packages)"
    if (Test-Command gup) {
        try {
            gup update
            if ($LASTEXITCODE -eq 0) {
                Write-Success "gup"
                $script:updated++
            }
            else {
                Write-Fail "gup"
                $script:failed++
            }
        }
        catch {
            Write-Fail "gup"
            $script:failed++
        }
    }
    elseif (Test-Command go) {
        try {
            go install github.com/nao1215/gup@latest && gup update
            if ($LASTEXITCODE -eq 0) {
                Write-Success "gup"
                $script:updated++
            }
            else {
                Write-Fail "gup"
                $script:failed++
            }
        }
        catch {
            Write-Fail "gup"
            $script:failed++
        }
    }
    else {
        Write-Skip "gup not found"
        $script:skipped++
    }

    Write-Step "CARGO (Rust packages)"
    if (Test-Command cargo) {
        if (Test-Command cargo-install-update) {
            try {
                cargo install-update -a
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "cargo"
                    $script:updated++
                }
                else {
                    Write-Fail "cargo"
                    $script:failed++
                }
            }
            catch {
                Write-Fail "cargo"
                $script:failed++
            }
        }
        else {
            Write-Skip "cargo-install-update not found (install: cargo install cargo-update)"
            $script:skipped++
        }
    }
    else {
        Write-Skip "cargo not found"
        $script:skipped++
    }

    Write-Step "RUSTUP"
    if (Test-Command rustup) {
        try {
            rustup update
            if ($LASTEXITCODE -eq 0) {
                Write-Success "rustup"
                $script:updated++
            }
            else {
                Write-Fail "rustup"
                $script:failed++
            }
        }
        catch {
            Write-Fail "rustup"
            $script:failed++
        }
    }
    else {
        Write-Skip "rustup not found"
        $script:skipped++
    }

    Write-Step "DOTNET TOOLS"
    if (Test-Command dotnet) {
        $list = @(dotnet tool list --global)
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "dotnet tool list"
            $script:failed++
        }
        else {
            $sepIndex = -1
            for ($i = 0; $i -lt $list.Count; $i++) {
                if ($list[$i] -match '^-+$') { $sepIndex = $i }
            }
            $tools = if ($sepIndex -ge 0) { $list | Select-Object -Skip ($sepIndex + 1) | Where-Object { $_ -match '^\S+' } }
            if ($tools) {
                $failedTools = @()
                foreach ($tool in $tools) {
                    $toolName = ($tool -split '\s+')[0]
                    dotnet tool update --global $toolName
                    if ($LASTEXITCODE -ne 0) {
                        $failedTools += $toolName
                    }
                }
                if ($failedTools.Count -eq 0) {
                    Write-Success "dotnet"
                    $script:updated++
                }
                else {
                    Write-Fail "dotnet (failed: $($failedTools -join ', '))"
                    $script:failed++
                }
            }
            else {
                Write-Skip "No dotnet tools installed"
                $script:skipped++
            }
        }
    }
    else {
        Write-Skip "dotnet not found"
        $script:skipped++
    }

    if (-not $SkipPip) {
        Write-Step "PIP (Python packages)"

        if (Test-Command pip) {
            try {
                python -m pip install --upgrade pip
                $pipSelf = $LASTEXITCODE
                $failedPackages = @()
                $packages = @(pip freeze 2>$null | ForEach-Object { $_.Split('==')[0] })
                $freezeOk = $LASTEXITCODE -eq 0
                if ($freezeOk) {
                    foreach ($package in $packages) {
                        python -m pip install --upgrade $package
                        if ($LASTEXITCODE -ne 0) {
                            $failedPackages += $package
                        }
                    }
                }
                if ($pipSelf -eq 0 -and $freezeOk -and $failedPackages.Count -eq 0) {
                    Write-Success "pip"
                    $script:updated++
                }
                else {
                    if ($failedPackages.Count -gt 0) {
                        Write-Fail "pip (failed: $($failedPackages -join ', '))"
                    }
                    else {
                        Write-Fail "pip"
                    }
                    $script:failed++
                }
            }
            catch {
                Write-Fail "pip"
                $script:failed++
            }
        }
        else {
            Write-Skip "pip not found"
            $script:skipped++
        }
    }
    else {
        Write-Skip "pip (skipped by -SkipPip flag)"
        $script:skipped++
    }

    Write-Step "POETRY"
    if (Test-Command poetry) {
        try {
            poetry self update
            if ($LASTEXITCODE -eq 0) {
                Write-Success "poetry"
                $script:updated++
            }
            else {
                Write-Fail "poetry"
                $script:failed++
            }
        }
        catch {
            Write-Fail "poetry"
            $script:failed++
        }
    }
    else {
        Write-Skip "poetry not found"
        $script:skipped++
    }

    Write-Step "UV (Python package manager)"
    if (Test-Command uv) {
        try {
            $LASTEXITCODE = 0
            irm https://astral.sh/uv/install.ps1 | iex
            if ($LASTEXITCODE -eq 0) {
                Write-Success "uv"
                $script:updated++
            }
            else {
                Write-Fail "uv"
                $script:failed++
            }
        }
        catch {
            Write-Fail "uv"
            $script:failed++
        }
    }
    else {
        Write-Skip "uv not found"
        $script:skipped++
    }

    Write-Step "NEOVIM (plugins and parsers)"
    if (Test-Command nvim) {
        & nvim --headless "+lua vim.pack.update(nil, { force = true })" "+qa"
        if ($LASTEXITCODE -eq 0) {
            Write-Success "nvim plugins"
            $script:updated++
        }
        else {
            Write-Fail "nvim plugins"
            $script:failed++
        }

        & nvim --headless "+lua require('nvim-treesitter.install').update():wait()" "+qa"
        if ($LASTEXITCODE -eq 0) {
            Write-Success "nvim treesitter parsers"
            $script:updated++
        }
        else {
            Write-Fail "nvim treesitter parsers"
            $script:failed++
        }
    }
    else {
        Write-Skip "nvim not found"
        $script:skipped++
    }

    Write-Step "CLAUDE CODE CLI"
    if (Test-Command claude) {
        $claudeWorks = $false
        try {
            $null = & claude --version 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $claudeWorks = $true
            }
        }
        catch {
        }

        if ($claudeWorks) {
            $versionBefore = ""
            try {
                $versionOutput = claude --version 2>$null
                if ($versionOutput -match '(\d+\.\d+\.\d+)') {
                    $versionBefore = $matches[1]
                }
            }
            catch {
            }

            if (Test-Command bun) {
                bun remove -g @anthropic-ai/claude-code 2>$null
            }
            if (Test-Command npm) {
                npm rm -g @anthropic-ai/claude-code 2>$null
            }

            Write-Info "claude-code updating via native installer..."
            irm https://claude.ai/install.ps1 | iex

            $claudeBin = Join-Path $env:USERPROFILE ".claude\local\bin"
            if (Test-Path $claudeBin) {
                $envPath = [Environment]::GetEnvironmentVariable("Path", "User")
                if ($envPath -notlike "*$claudeBin*") {
                    [Environment]::SetEnvironmentVariable("Path", "$envPath;$claudeBin", "User")
                }
            }

            $versionAfter = ""
            $updateWorks = $false
            try {
                $null = & claude --version 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    $updateWorks = $true
                    $versionOutput = claude --version 2>$null
                    if ($versionOutput -match '(\d+\.\d+\.\d+)') {
                        $versionAfter = $matches[1]
                    }
                }
            }
            catch {
            }

            if ($updateWorks -and $versionAfter -and $versionAfter -ne $versionBefore) {
                Write-Success "claude-code ($versionBefore -> $versionAfter)"
                $script:updated++
            }
            elseif ($updateWorks) {
                Write-Skip "claude-code already up to date"
                $script:updated++
            }
            else {
                Write-Fail "claude-code (update verification failed)"
                $script:failed++
            }
        }
        else {
            Write-Fail "claude-code found but not functional"
            $script:failed++
        }
    }
    else {
        Write-Skip "claude-code not found"
        $script:skipped++
    }

    Write-Step "OPENCODE AI CLI"

    if (Test-Command bun) {
        $currentVersion = ""
        if (Test-Command opencode) {
            try {
                $versionOutput = opencode --version 2>$null
                if ($versionOutput -match '(\d+\.\d+\.\d+)') {
                    $currentVersion = $matches[1]
                }
            }
            catch {
            }
        }

        $latestVersion = ""
        try {
            $latestVersion = npm view opencode-ai version 2>$null
        }
        catch {
        }

        if ($currentVersion -and $latestVersion -and $currentVersion -eq $latestVersion) {
            Write-Skip "opencode already at latest version ($currentVersion)"
            $script:skipped++
        }
        else {
            if ($currentVersion -and $latestVersion) {
                Write-Info "opencode update available: $currentVersion -> $latestVersion"
            }

            $result = bun install -g opencode-ai 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Success "opencode ($currentVersion -> $latestVersion)"
                $script:updated++
            }
            else {
                Write-Fail "opencode (bun install failed)"
                $script:failed++
            }
        }
    }
    else {
        Write-Skip "opencode (bun not found)"
        $script:skipped++
    }

    $endTime = Get-Date
    $duration = $endTime - $startTime

    Write-Host "`n========================================" -ForegroundColor Blue
    Write-Host "           Summary" -ForegroundColor Blue
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host " Completed: " -NoNewline; Write-Success $script:updated
    Write-Host " Skipped:   " -NoNewline; Write-Skip $script:skipped
    if ($script:failed -gt 0) {
        Write-Host " Failed:    " -NoNewline; Write-Fail $script:failed
    }
    Write-Host " Duration:  " -NoNewline; Write-Info "$($duration.TotalSeconds.ToString('F0'))s"
    Write-Host "========================================" -ForegroundColor Blue

    return
}

Main
