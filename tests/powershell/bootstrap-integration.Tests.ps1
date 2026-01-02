# Bootstrap Integration Tests - Verifies correct platform bootstrap is invoked
# These tests use mocks to verify which bootstrap script gets called

Describe "Bootstrap Integration - Platform Detection" {

    BeforeAll {
        $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    }

    Context "Windows Bootstrap Invocation" {

        BeforeEach {
            # Create a temp directory for testing
            $Script:TestDir = Join-Path $env:TEMP "bootstrap-test-$(New-Guid)"
            New-Item -Path $Script:TestDir -ItemType Directory -Force | Out-Null

            # Create bootstrap subdirectory
            $BootstrapDir = Join-Path $Script:TestDir "bootstrap"
            New-Item -Path $BootstrapDir -ItemType Directory -Force | Out-Null

            # Create mock Windows bootstrap that writes a marker when invoked
            $WindowsBootstrapContent = @'
param([switch]$Y, [switch]$DryRun, [string]$Categories, [switch]$SkipUpdate)
# Write marker to prove we were called
"WINDOWS_BOOTSTRAP_INVOKED" | Out-File -FilePath "$env:TEMP\bootstrap-marker.txt" -Encoding utf8
exit 0
'@
            $WindowsBootstrapContent | Out-File -FilePath (Join-Path $BootstrapDir "bootstrap.ps1") -Encoding utf8

            # Create mock Linux bootstrap that writes a different marker
            $LinuxBootstrapContent = @'
#!/bin/bash
echo "LINUX_BOOTSTRAP_INVOKED" > /tmp/bootstrap-marker.txt
exit 0
'@
            $LinuxBootstrapContent | Out-File -FilePath (Join-Path $Script:TestDir "bootstrap.sh") -Encoding utf8

            # Create wrapper script (copy of actual bootstrap.ps1 logic)
            $WrapperContent = @'
$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# On Windows, use the native PowerShell bootstrap
$windowsBootstrap = Join-Path $ScriptDir "bootstrap\bootstrap.ps1"
if (Test-Path $windowsBootstrap) {
    # Build splattable parameters hashtable
    $params = @{}
    $i = 0
    while ($i -lt $args.Length) {
        $arg = $args[$i]
        switch ($arg) {
            { $_ -in "-y", "-Y", "--yes" } {
                $params["Y"] = $true
                $i++
            }
            { $_ -in "-DryRun", "--dry-run" } {
                $params["DryRun"] = $true
                $i++
            }
            { $_ -in "-Categories", "--categories", "-Category" } {
                if ($i + 1 -lt $args.Length) {
                    $params["Categories"] = $args[$i + 1]
                    $i += 2
                } else {
                    $i++
                }
            }
            { $_ -in "-SkipUpdate", "--skip-update" } {
                $params["SkipUpdate"] = $true
                $i++
            }
            { $_ -in "-h", "-?", "--help" } {
                # Show help using PowerShell's built-in mechanism
                Get-Help -Full $windowsBootstrap
                exit 0
            }
            default {
                # Pass through unknown arguments
                $i++
            }
        }
    }
    & $windowsBootstrap @params
    exit $LASTEXITCODE
}

# Fall back to bash script (for Git Bash on Windows or Unix systems)
# Ensure Git Bash is available
if (-not (Get-Command bash -ErrorAction SilentlyContinue)) {
    Write-Error "Git Bash (bash.exe) not found. Please install Git for Windows."
    Write-Error "Download: https://git-scm.com/download/win"
    exit 1
}

# Map PowerShell parameter names to bash equivalents
$mappedArgs = @()
$i = 0
while ($i -lt $args.Length) {
    $arg = $args[$i]
    switch ($arg) {
        { $_ -in "-y", "-Y", "--yes" } {
            $mappedArgs += "--yes"
            $i++
        }
        { $_ -in "-DryRun", "--dry-run" } {
            $mappedArgs += "--dry-run"
            $i++
        }
        { $_ -in "-Categories", "--categories", "-Category" } {
            if ($i + 1 -lt $args.Length) {
                $mappedArgs += "--categories"
                $mappedArgs += $args[$i + 1]
                $i += 2
            } else {
                $i++
            }
        }
        { $_ -in "-SkipUpdate", "--skip-update" } {
            $mappedArgs += "--skip-update"
            $i++
        }
        { $_ -in "-h", "--help" } {
            $mappedArgs += "--help"
            $i++
        }
        default {
            $mappedArgs += $arg
            $i++
        }
    }
}

# Change to script directory and invoke bash as login shell
$origLocation = Get-Location
try {
    Set-Location $ScriptDir
    $argList = $mappedArgs -join ' '
    $bashArgs = @("-l", "-c", "./bootstrap.sh $argList")
    & bash @bashArgs
    $exitCode = $LASTEXITCODE
}
finally {
    Set-Location $origLocation
}

exit $exitCode
'@
            $WrapperContent | Out-File -FilePath (Join-Path $Script:TestDir "bootstrap.ps1") -Encoding utf8

            # Clean up any previous marker
            $MarkerPath = Join-Path $env:TEMP "bootstrap-marker.txt"
            if (Test-Path $MarkerPath) {
                Remove-Item $MarkerPath -Force
            }
        }

        AfterEach {
            # Clean up test directory
            if (Test-Path $Script:TestDir) {
                Remove-Item $Script:TestDir -Recurse -Force
            }
            # Clean up marker
            $MarkerPath = Join-Path $env:TEMP "bootstrap-marker.txt"
            if (Test-Path $MarkerPath) {
                Remove-Item $MarkerPath -Force
            }
        }

        It "When Windows bootstrap exists, wrapper invokes it (not bash)" {
            # Run the wrapper
            $wrapperPath = Join-Path $Script:TestDir "bootstrap.ps1"
            & $wrapperPath -Y

            # Check the marker
            $MarkerPath = Join-Path $env:TEMP "bootstrap-marker.txt"
            Test-Path $MarkerPath | Should -Be $true "Because Windows bootstrap should have been invoked"

            $markerContent = Get-Content $MarkerPath -Raw
            $markerContent.TrimEnd() | Should -Be "WINDOWS_BOOTSTRAP_INVOKED" "Because Windows bootstrap should have been called, not Linux"
        }

        It "When Windows bootstrap is missing, wrapper falls back to bash" {
            # Remove the Windows bootstrap
            $BootstrapDir = Join-Path $Script:TestDir "bootstrap"
            Remove-Item (Join-Path $BootstrapDir "bootstrap.ps1") -Force

            # Run the wrapper
            $wrapperPath = Join-Path $Script:TestDir "bootstrap.ps1"
            & $wrapperPath -Y

            # Check the marker (Linux bootstrap writes to different location on Windows)
            $MarkerPath = Join-Path $env:TEMP "bootstrap-marker.txt"
            Test-Path $MarkerPath | Should -Be $true "Because bash bootstrap should have been invoked as fallback"

            $markerContent = Get-Content $MarkerPath -Raw
            $markerContent.TrimEnd() | Should -Be "LINUX_BOOTSTRAP_INVOKED" "Because bash fallback should have been called"
        }
    }

    Context "Parameter Passing to Windows Bootstrap" {

        BeforeEach {
            $Script:TestDir = Join-Path $env:TEMP "bootstrap-test-$(New-Guid)"
            New-Item -Path $Script:TestDir -ItemType Directory -Force | Out-Null

            $BootstrapDir = Join-Path $Script:TestDir "bootstrap"
            New-Item -Path $BootstrapDir -ItemType Directory -Force | Out-Null

            # Create mock bootstrap that logs parameters
            $MockBootstrap = @'
param([switch]$Y, [switch]$DryRun, [string]$Categories, [switch]$SkipUpdate)
$log = @{
    Y = $Y.IsPresent
    DryRun = $DryRun.IsPresent
    Categories = $Categories
    SkipUpdate = $SkipUpdate.IsPresent
}
$log | ConvertTo-Json | Out-File -FilePath "$env:TEMP\bootstrap-params.txt" -Encoding utf8
exit 0
'@
            $MockBootstrap | Out-File -FilePath (Join-Path $BootstrapDir "bootstrap.ps1") -Encoding utf8

            # Minimal wrapper that just calls Windows bootstrap
            $WrapperContent = @'
$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$windowsBootstrap = Join-Path $ScriptDir "bootstrap\bootstrap.ps1"
if (Test-Path $windowsBootstrap) {
    $params = @{}
    $i = 0
    while ($i -lt $args.Length) {
        $arg = $args[$i]
        switch ($arg) {
            { $_ -in "-y", "-Y", "--yes" } {
                $params["Y"] = $true
                $i++
            }
            { $_ -in "-DryRun", "--dry-run" } {
                $params["DryRun"] = $true
                $i++
            }
            { $_ -in "-Categories", "--categories", "-Category" } {
                if ($i + 1 -lt $args.Length) {
                    $params["Categories"] = $args[$i + 1]
                    $i += 2
                } else {
                    $i++
                }
            }
            { $_ -in "-SkipUpdate", "--skip-update" } {
                $params["SkipUpdate"] = $true
                $i++
            }
            default { $i++ }
        }
    }
    & $windowsBootstrap @params
    exit $LASTEXITCODE
}
exit 1
'@
            $WrapperContent | Out-File -FilePath (Join-Path $Script:TestDir "bootstrap.ps1") -Encoding utf8
        }

        AfterEach {
            if (Test-Path $Script:TestDir) {
                Remove-Item $Script:TestDir -Recurse -Force
            }
            $ParamsPath = Join-Path $env:TEMP "bootstrap-params.txt"
            if (Test-Path $ParamsPath) {
                Remove-Item $ParamsPath -Force
            }
        }

        It "Passes -Y switch correctly to Windows bootstrap" {
            $wrapperPath = Join-Path $Script:TestDir "bootstrap.ps1"
            & $wrapperPath -Y

            $ParamsPath = Join-Path $env:TEMP "bootstrap-params.txt"
            $params = Get-Content $ParamsPath | ConvertFrom-Json
            $params.Y | Should -Be $true
        }

        It "Passes -DryRun switch correctly to Windows bootstrap" {
            $wrapperPath = Join-Path $Script:TestDir "bootstrap.ps1"
            & $wrapperPath -DryRun

            $ParamsPath = Join-Path $env:TEMP "bootstrap-params.txt"
            $params = Get-Content $ParamsPath | ConvertFrom-Json
            $params.DryRun | Should -Be $true
        }

        It "Passes -Categories parameter correctly to Windows bootstrap" {
            $wrapperPath = Join-Path $Script:TestDir "bootstrap.ps1"
            & $wrapperPath -Categories "dev,tools"

            $ParamsPath = Join-Path $env:TEMP "bootstrap-params.txt"
            $params = Get-Content $ParamsPath | ConvertFrom-Json
            $params.Categories | Should -Be "dev,tools"
        }
    }

    Context "Native Windows Verification - Bash as Single Source of Truth" {
        # These tests verify that update-all.sh properly handles Windows (Git Bash)
        # by detecting Windows and skipping Linux-only commands (sudo, apt, etc.)

        BeforeAll {
            $Script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        }

        It "update-all.sh has Windows detection function" {
            $bashScriptPath = Join-Path $Script:RepoRoot "update-all.sh"
            Test-Path $bashScriptPath | Should -Be $true "Because update-all.sh should exist"

            $content = Get-Content $bashScriptPath -Raw

            # Should have is_windows() function
            $content | Should -Match 'is_windows\(\)' "Because script should detect Windows environment"

            # Should check for MSYSTEM or MINGW/MSYS/CYGWIN in uname
            $content | Should -Match '\$MSYSTEM|MINGW|MSYS|CYGWIN' "Because Windows detection should check for Git Bash environment"
        }

        It "update-all.sh skips Linux package managers on Windows (apt, dnf, pacman, zypper)" {
            $bashScriptPath = Join-Path $Script:RepoRoot "update-all.sh"
            $content = Get-Content $bashScriptPath -Raw

            # Each Linux package manager section should have is_windows check BEFORE sudo
            # This ensures they are skipped on Windows even if available via WSL

            # Check for is_windows function existence
            $content | Should -Match 'is_windows\(\)' "Because script should have is_windows detection"

            # Check for Windows skip messages (using [\s\S]* to match across newlines)
            $content | Should -Match 'is_windows[\s\S]*?apt \(skipped on Windows\)' "Because APT should be skipped on Windows"
            $content | Should -Match 'is_windows[\s\S]*?dnf \(skipped on Windows\)' "Because DNF should be skipped on Windows"
            $content | Should -Match 'is_windows[\s\S]*?pacman \(skipped on Windows\)' "Because pacman should be skipped on Windows"
            $content | Should -Match 'is_windows[\s\S]*?zypper \(skipped on Windows\)' "Because zypper should be skipped on Windows"
            $content | Should -Match 'is_windows[\s\S]*?snap \(skipped on Windows\)' "Because snap should be skipped on Windows"
            $content | Should -Match 'is_windows[\s\S]*?tlmgr \(skipped on Windows\)' "Because tlmgr should be skipped on Windows"
        }

        It "update-all.sh preserves cross-platform package managers (npm, cargo, pip, etc.)" {
            $bashScriptPath = Join-Path $Script:RepoRoot "update-all.sh"
            $content = Get-Content $bashScriptPath -Raw

            # Cross-platform package managers should NOT be skipped on Windows
            # npm section should not have is_windows guard
            $npmSectionStart = $content.IndexOf("NPM (Node.js global packages)")
            $npmSectionEnd = $content.IndexOf("YARN (global packages)")
            if ($npmSectionStart -gt 0 -and $npmSectionEnd -gt $npmSectionStart) {
                $npmSection = $content.Substring($npmSectionStart, $npmSectionEnd - $npmSectionStart)
                $npmSection | Should -Not -Match 'if is_windows.*update_skip.*npm' "Because npm should work on Windows"
            }

            # Similar checks for cargo, pip, etc.
            $content | Should -Match 'update_and_report "npm update -g"' "Because npm should be available on Windows"
            $content | Should -Match 'update_and_report "rustup update"' "Because rustup should work on Windows"
        }

        It "Windows bootstrap calls update-all.ps1 wrapper (which calls bash script)" {
            $bootstrapPath = Join-Path $Script:RepoRoot "bootstrap\bootstrap.ps1"
            $content = Get-Content $bootstrapPath -Raw

            # Should call the wrapper, not a Windows-specific script
            $updateAllBlock = $content -split 'function Update-All' | Select-Object -Last 1
            $updateAllBlock = $updateAllBlock -split 'function Main' | Select-Object -First 1

            $updateAllBlock | Should -Match 'update-all\.ps1' "Because Windows bootstrap should call the bash wrapper"
        }

        It "update-all.ps1 wrapper does not block Windows execution" {
            $wrapperPath = Join-Path $Script:RepoRoot "update-all.ps1"
            $content = Get-Content $wrapperPath -Raw

            # Should NOT have a guard that prevents running on Windows
            $content | Should -Not -Match 'This script is for Unix.*Windows|Windows_NT.*exit 1' "Because wrapper should run on Windows via Git Bash"
        }
    }
}
