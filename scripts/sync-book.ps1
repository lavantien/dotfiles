#!/usr/bin/env pwsh
# Refresh the repo books publishing front from the private corpus, PowerShell
# twin of sync-book.sh. Mirrors manifest.typ, book.typ, chapters/*.typ,
# coverage/*.typ per volume into .claude/books (the typst corpus agents ground
# on) plus the compiled PDFs into books/ at the root (human reading copies
# only), pruning retired volumes and stale target files. Skips cleanly when
# the corpus is absent.
#
# Usage: ./scripts/sync-book.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
$Corpus = if ($env:BOOKS_CORPUS) { $env:BOOKS_CORPUS } else { Join-Path $HOME 'dev/github/resume/books' }
$PdfSrc = if ($env:BOOKS_PDF_SRC) { $env:BOOKS_PDF_SRC } else { Join-Path $HOME 'dev/github/resume/output/books' }
$TypstTarget = if ($env:BOOKS_TYPO_TARGET) { $env:BOOKS_TYPO_TARGET } else { Join-Path (Split-Path -Parent $ScriptDir) '.claude/books' }
$PdfTarget = if ($env:BOOKS_PDF_TARGET) { $env:BOOKS_PDF_TARGET } else { Join-Path (Split-Path -Parent $ScriptDir) 'books' }
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
		Where-Object { $Excluded -cnotcontains $_.Name } |
		ForEach-Object { $_.Name }
)
[System.Array]::Sort($Included, [System.StringComparer]::Ordinal)

if ($Included.Count -eq 0) { throw "no included volumes found under $Corpus, refusing to touch $TypstTarget" }
$PdfName = @{}
foreach ($dir in $Included) {
	$manifest = Join-Path $Corpus "$dir/manifest.typ"
	if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) { throw "no manifest.typ in $dir" }
	$numLine = Select-String -LiteralPath $manifest -Pattern '^\s*num:\s*(\d+),' | Select-Object -First 1
	if ($null -eq $numLine) { throw "no num in $dir manifest" }
	$PdfName[$dir] = ('{0:d2}' -f [int]$numLine.Matches[0].Groups[1].Value) + "-$dir.pdf"
}

[System.IO.Directory]::CreateDirectory($TypstTarget) | Out-Null
[System.IO.Directory]::CreateDirectory($PdfTarget) | Out-Null

$copied = 0
$deleted = 0
$pdfCount = 0

# Retired volumes: any typst target dir outside the include list goes away
foreach ($path in @(Get-ChildItem -LiteralPath $TypstTarget -Directory)) {
	if ($Included -cnotcontains $path.Name) {
		$deleted += @(Get-ChildItem -LiteralPath $path.FullName -Recurse -File).Count
		Remove-Item -LiteralPath $path.FullName -Recurse -Force
	}
}

# books/ at the root is PDFs only, any directory there is stale typst
foreach ($path in @(Get-ChildItem -LiteralPath $PdfTarget -Directory)) {
	$deleted += @(Get-ChildItem -LiteralPath $path.FullName -Recurse -File).Count
	Remove-Item -LiteralPath $path.FullName -Recurse -Force
}

foreach ($dir in $Included) {
	$src = Join-Path $Corpus $dir
	$dst = Join-Path $TypstTarget $dir
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
		foreach ($f in @(Get-ChildItem -LiteralPath $dst -Recurse -File)) {
			$rel = ([System.IO.Path]::GetRelativePath($dst, $f.FullName)) -replace '\\', '/'
			if ($relTypFiles -notcontains $rel) {
				Remove-Item -LiteralPath $f.FullName -Force
				$deleted++
			}
		}
		Get-ChildItem -LiteralPath $dst -Recurse -Directory |
			Sort-Object { $_.FullName.Length } -Descending |
			ForEach-Object {
				if (-not @(Get-ChildItem -LiteralPath $_.FullName -Force)) { Remove-Item -LiteralPath $_.FullName -Force }
			}
	}
}

$hasPdfSrc = Test-Path -LiteralPath $PdfSrc -PathType Container
foreach ($dir in $Included) {
	$expected = $PdfName[$dir]
	$srcFile = Join-Path $PdfSrc $expected
	if (-not $hasPdfSrc -or -not (Test-Path -LiteralPath $srcFile -PathType Leaf)) {
		[Console]::Error.WriteLine("warning: no pdf for $dir in $PdfSrc")
		continue
	}
	$outFile = Join-Path $PdfTarget $expected
	if (-not (Test-Path -LiteralPath $outFile -PathType Leaf) -or -not (Test-FileEqual $srcFile $outFile)) {
		Copy-Item -LiteralPath $srcFile -Destination $outFile -Force
		$pdfCount++
	}
}

# Only the manifest-numbered PDF of an included volume stays, renumbered and retired names go
$keepNames = @($Included | ForEach-Object { $PdfName[$_] })
foreach ($f in @(Get-ChildItem -LiteralPath $PdfTarget -Filter '*.pdf' -File)) {
	if ($keepNames -cnotcontains $f.Name) {
		Remove-Item -LiteralPath $f.FullName -Force
		$deleted++
	}
}

Write-Host "books sync: $($Included.Count) volumes, $copied files copied, $deleted files deleted, $pdfCount pdfs copied"
