# Bootstrap Script Wrapper - Delegates to the appropriate bootstrap
# On Windows: invokes bootstrap/bootstrap.ps1 (native PowerShell)
# On Unix (via Git Bash): invokes bootstrap.sh (bash script)

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
