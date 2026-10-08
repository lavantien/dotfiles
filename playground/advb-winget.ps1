$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent $PSScriptRoot

$Ast = [System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $Repo 'bootstrap\platforms\windows.ps1'), [ref]$null, [ref]$null)
$Fn = $Ast.FindAll({
    param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
    $n.Name -eq 'Install-WingetPackage'
}, $true)[0]
. ([scriptblock]::Create($Fn.Extent.Text))

$script:Log = @()
function Track-Installed { param($n, $d) $script:Log += "INSTALLED:$n" }
function Track-Skipped { param($n, $d) $script:Log += "SKIPPED:$n" }
function Track-Failed { param($n, $d) $script:Log += "FAILED:$n" }
function Get-PackageDescription { param($n) "desc" }
function Test-NeedsInstall { param($c, $v) $true }
function Write-WarningMsg { param($m) $script:Log += "WARN:$m" }
function Write-Step { param($m) $script:Log += "STEP:$m" }
function Write-Info { param($m) $script:Log += "INFO:$m" }

$script:WingetCalls = @()
function winget {
    $script:WingetCalls += ($args -join ' ')
    if ($args[0] -eq 'list') {
        $global:LASTEXITCODE = 1
        "No installed package found matching input criteria."
        return
    }
    if ($args[0] -eq 'install') {
        $global:LASTEXITCODE = -1978335189
        "Installer failed with exit code: 0x8A150109"
        return
    }
    $global:LASTEXITCODE = 0
}

"== case 1: real mode, install fails =="
$Script:DryRun = $false
$rc = Install-WingetPackage -Id 'Helm.Helm' -DisplayName 'helm' -CheckCmd 'helm'
"return=$rc"
$script:Log

"== case 2: dry run =="
$script:Log = @(); $script:WingetCalls = @()
$Script:DryRun = $true
$rc = Install-WingetPackage -Id 'Kubernetes.kubectl' -DisplayName 'kubectl' -CheckCmd 'kubectl'
"return=$rc"
$script:Log
"winget invocations during DRY RUN: $($script:WingetCalls.Count)"
$script:WingetCalls
