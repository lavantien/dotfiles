#!/usr/bin/env pwsh
# Refresh the repo books/ publishing front from the private corpus, PowerShell
# twin of sync-book.sh. Mirrors manifest.typ, book.typ, chapters/*.typ,
# coverage/*.typ per volume plus the compiled PDFs from ~/dev/github/resume,
# pruning retired volumes and stale target .typ files. Skips cleanly when the
# corpus is absent.
#
# Usage: ./scripts/sync-book.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
$Corpus = Join-Path $HOME 'dev/github/resume/books'
$PdfSrc = Join-Path $HOME 'dev/github/resume/output/books'
$Target = Join-Path (Split-Path -Parent $ScriptDir) 'books'
$AnnotationsPath = Join-Path $ScriptDir 'books-index.json'

function Test-FileEqual {
	param($PathA, $PathB)
	$bytesA = [System.IO.File]::ReadAllBytes($PathA)
	$bytesB = [System.IO.File]::ReadAllBytes($PathB)
	return [System.Linq.Enumerable]::SequenceEqual($bytesA, $bytesB)
}

if (-not (Test-Path -LiteralPath $Corpus -PathType Container)) {
	Write-Host "books corpus not found, skipping sync: $Corpus"
	exit 0
}

if (-not (Test-Path -LiteralPath $AnnotationsPath -PathType Leaf)) { throw "annotations not found: $AnnotationsPath" }
try {
	$Ann = Get-Content -LiteralPath $AnnotationsPath -Raw | ConvertFrom-Json
} catch {
	throw "cannot parse $AnnotationsPath"
}
if ($null -eq $Ann.PSObject.Properties['exclude']) { throw "no exclude array in $AnnotationsPath" }
$Excluded = @($Ann.exclude)

$Included = @(
	Get-ChildItem -LiteralPath $Corpus -Directory |
		Where-Object { $Excluded -notcontains $_.Name } |
		ForEach-Object { $_.Name }
)
[System.Array]::Sort($Included, [System.StringComparer]::Ordinal)

if ($Included.Count -eq 0) { throw "no included volumes found under $Corpus, refusing to touch $Target" }
foreach ($dir in $Included) {
	if (-not (Test-Path -LiteralPath (Join-Path $Corpus "$dir/manifest.typ") -PathType Leaf)) { throw "no manifest.typ in $dir" }
}

[System.IO.Directory]::CreateDirectory($Target) | Out-Null

$copied = 0
$deleted = 0
$pdfCount = 0

# Retired volumes: any target dir outside the include list goes away
foreach ($path in @(Get-ChildItem -LiteralPath $Target -Directory)) {
	if ($Included -notcontains $path.Name) {
		$deleted += @(Get-ChildItem -LiteralPath $path.FullName -Recurse -File).Count
		Remove-Item -LiteralPath $path.FullName -Recurse -Force
	}
}

foreach ($dir in $Included) {
	$src = Join-Path $Corpus $dir
	$dst = Join-Path $Target $dir
	if (-not (Test-Path -LiteralPath (Join-Path $src 'manifest.typ') -PathType Leaf)) { throw "no manifest.typ in $dir" }

	$relTypFiles = [System.Collections.Generic.List[string]]::new()
	$relTypFiles.Add('manifest.typ')
	if (Test-Path -LiteralPath (Join-Path $src 'book.typ') -PathType Leaf) { $relTypFiles.Add('book.typ') }
	foreach ($sub in 'chapters', 'coverage') {
		$subDir = Join-Path $src $sub
		if (Test-Path -LiteralPath $subDir -PathType Container) {
			foreach ($f in @(Get-ChildItem -LiteralPath $subDir -Filter '*.typ' -File)) {
				$relTypFiles.Add("$sub/$($f.Name)")
			}
		}
	}

	foreach ($rel in $relTypFiles) {
		$inFile = Join-Path $src $rel
		$outFile = Join-Path $dst $rel
		[System.IO.Directory]::CreateDirectory((Split-Path -Parent $outFile)) | Out-Null
		if (-not (Test-Path -LiteralPath $outFile -PathType Leaf) -or -not (Test-FileEqual $inFile $outFile)) {
			Copy-Item -LiteralPath $inFile -Destination $outFile -Force
			$copied++
		}
	}

	if (Test-Path -LiteralPath $dst -PathType Container) {
		foreach ($f in @(Get-ChildItem -LiteralPath $dst -Recurse -Filter '*.typ' -File)) {
			$rel = ([System.IO.Path]::GetRelativePath($dst, $f.FullName)) -replace '\\', '/'
			if ($relTypFiles -notcontains $rel) {
				Remove-Item -LiteralPath $f.FullName -Force
				$deleted++
			}
		}
	}
}

$hasPdfSrc = Test-Path -LiteralPath $PdfSrc -PathType Container
foreach ($dir in $Included) {
	$hits = @()
	if ($hasPdfSrc) { $hits = @(Get-ChildItem -LiteralPath $PdfSrc -Filter "*-$dir.pdf" -File) }
	if ($hits.Count -eq 0) {
		[Console]::Error.WriteLine("warning: no pdf for $dir in $PdfSrc")
		continue
	}
	foreach ($f in $hits) {
		$outFile = Join-Path $Target $f.Name
		if (-not (Test-Path -LiteralPath $outFile -PathType Leaf) -or -not (Test-FileEqual $f.FullName $outFile)) {
			Copy-Item -LiteralPath $f.FullName -Destination $outFile -Force
			$pdfCount++
		}
	}
}

# Retired volumes leave no orphan PDF behind at the top level
foreach ($f in @(Get-ChildItem -LiteralPath $Target -Filter '*.pdf' -File)) {
	$keep = $false
	foreach ($dir in $Included) {
		if ($f.Name.EndsWith("-$dir.pdf", [System.StringComparison]::Ordinal)) { $keep = $true; break }
	}
	if (-not $keep) {
		Remove-Item -LiteralPath $f.FullName -Force
		$deleted++
	}
}

Write-Host "books sync: $($Included.Count) volumes, $copied files copied, $deleted files deleted, $pdfCount pdfs copied"
