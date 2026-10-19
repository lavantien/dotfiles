#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
$DiagramsDir = if ($env:DIAGRAMS_DIR) { $env:DIAGRAMS_DIR } else { Join-Path $RootDir 'docs/diagrams' }

$TotalSw = [System.Diagnostics.Stopwatch]::StartNew()
Write-Host "diagrams: start dir=$DiagramsDir"

if (-not (Test-Path -LiteralPath $DiagramsDir -PathType Container)) { throw "diagrams dir not found: $DiagramsDir" }
$Pumls = @(Get-ChildItem -LiteralPath $DiagramsDir -File | Where-Object { $_.Extension -ceq '.puml' } | Sort-Object Name)
if ($Pumls.Count -eq 0) { throw "no .puml files in $DiagramsDir" }
if (-not (Get-Command plantuml -ErrorAction SilentlyContinue)) {
    $Hint = if ($env:OS -eq 'Windows_NT') { 'scoop install plantuml' } else { 'install plantuml with the system package manager' }
    throw "plantuml not found on PATH, install hint: $Hint"
}

foreach ($P in $Pumls) {
    $FileSw = [System.Diagnostics.Stopwatch]::StartNew()
    Write-Host "diagrams: render $($P.Name)"
    & plantuml -failfast2 -tpng $P.FullName
    if ($LASTEXITCODE -ne 0) { throw "plantuml failed with exit $LASTEXITCODE on $($P.FullName)" }
    Write-Host ("diagrams: ok {0} in {1} ms" -f $P.Name, $FileSw.ElapsedMilliseconds)
}

$Missing = @($Pumls | Where-Object { -not (Test-Path -LiteralPath ([System.IO.Path]::ChangeExtension($_.FullName, '.png')) -PathType Leaf) })
if ($Missing.Count -gt 0) { throw "missing png for: $(@($Missing | ForEach-Object { $_.Name }) -join ', ')" }

Write-Host ("diagrams: done {0} png(s) in {1} ms" -f $Pumls.Count, $TotalSw.ElapsedMilliseconds)
