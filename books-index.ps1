#!/usr/bin/env pwsh
# Books corpus index generator, PowerShell twin of books-index.sh.
# Reads the books corpus manifests plus curated annotations from books-index.json,
# then emits .claude/BOOKS.md and splices the compact table into .claude/CLAUDE.md.
# Output is byte-identical to books-index.sh.
#
# Usage: ./books-index.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BooksDir = if ($env:BOOKS_DIR) { $env:BOOKS_DIR } else { Join-Path $HOME 'dev/github/resume/books' }
# Canonical label printed in the header, identical on every platform
$CanonBooks = '~/dev/github/resume/books'
$AnnotationsPath = Join-Path $ScriptDir 'books-index.json'
$BooksOut = Join-Path $ScriptDir '.claude/BOOKS.md'
$ClaudeMd = Join-Path $ScriptDir '.claude/CLAUDE.md'
$BeginMark = '<!-- BEGIN books index -->'
$EndMark = '<!-- END books index -->'
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)

if (-not (Test-Path -LiteralPath $BooksDir -PathType Container)) { throw "books dir not found: $BooksDir" }
if (-not (Test-Path -LiteralPath $AnnotationsPath -PathType Leaf)) { throw "annotations not found: $AnnotationsPath" }
if (-not (Test-Path -LiteralPath $ClaudeMd -PathType Leaf)) { throw "missing $ClaudeMd" }

$Ann = Get-Content -LiteralPath $AnnotationsPath -Raw | ConvertFrom-Json
$Excluded = @($Ann.exclude)
$AnnBooks = $Ann.books

# Collect book metadata from each non-excluded manifest
$Books = @{} # dir -> @{ Num; Title; Version; Subtitle }
foreach ($path in Get-ChildItem -LiteralPath $BooksDir -Directory) {
	$dir = $path.Name
	if ($Excluded -contains $dir) { continue }
	$manifest = Join-Path $path.FullName 'manifest.typ'
	if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) { throw "no manifest.typ in $dir" }

	$num = $null; $title = $null; $version = $null; $subtitle = $null
	$chapters = [System.Collections.Generic.List[string]]::new()
	$missing = [System.Collections.Generic.List[string]]::new()
	foreach ($line in [System.IO.File]::ReadLines($manifest)) {
		if ($null -eq $num -and $line -match '^\s*num:\s*(\d+),') { $num = $Matches[1]; continue }
		if ($null -eq $title -and $line -match '^\s*title:\s*"([^"]*)",') { $title = $Matches[1]; continue }
		if ($null -eq $version -and $line -match '^\s*version:\s*"([^"]*)",') { $version = $Matches[1]; continue }
		if ($null -eq $subtitle -and $line -match '^\s*subtitle:\s*"([^"]*)",') { $subtitle = $Matches[1]; continue }
		if ($line -match '\(\s*id:\s*"([^"]+)",\s*num:\s*(\d+),\s*title:\s*"([^"]+)"') {
			$chId = $Matches[1]; $chNum = [int]$Matches[2]; $chTitle = $Matches[3]
			# Resolve by number prefix, a few manifest ids disagree with file names
			$nn = '{0:d2}' -f $chNum
			$candidates = @(Get-ChildItem -LiteralPath (Join-Path $path.FullName 'chapters') -Filter "$nn-*.typ" -File)
			if ($candidates.Count -eq 1) {
				$file = "chapters/$($candidates[0].Name)"
				$chapters.Add("- $nn $chTitle ($file)")
			} else {
				$missing.Add("$nn-$chId.typ ($($candidates.Count) candidates)")
			}
		}
	}
	if ($null -in @($num, $title, $version, $subtitle)) { throw "incomplete manifest meta in $dir (num/title/version/subtitle)" }
	if ($chapters.Count -eq 0) { throw "${dir}: no chapters parsed from manifest" }
	if ($missing.Count -gt 0) { throw "${dir}: chapter files not found: $($missing -join ', ')" }

	$entry = $AnnBooks.PSObject.Properties[$dir]
	if ($null -eq $entry) { throw "books-index.json has no entry for $dir" }
	$ann = $entry.Value
	foreach ($field in 'summary', 'capstone', 'capstone_short', 'walkthroughs') {
		if (-not $ann.PSObject.Properties[$field] -or [string]::IsNullOrEmpty($ann.$field)) {
			throw "books-index.json is missing $field for $dir"
		}
	}

	$Books[$dir] = @{ Num = [int]$num; Title = $title; Version = $version; Subtitle = $subtitle; Chapters = $chapters; Ann = $ann }
}

# Every annotation key must name an included book, catches typos in dir names
foreach ($prop in $AnnBooks.PSObject.Properties) {
	if (-not $Books.ContainsKey($prop.Name)) { throw "books-index.json entry '$($prop.Name)' matches no included book" }
}

$Order = $Books.GetEnumerator() | Sort-Object { $_.Value.Num } | ForEach-Object { $_.Key }
$ExcludeLine = $Excluded -join ', '

foreach ($cell in @(
			$Books.Values.Title + $Books.Values.Subtitle +
			$Books.Values.Ann.capstone_short + $Books.Values.Ann.walkthroughs +
			$Books.Values.Ann.summary + $Books.Values.Ann.capstone
		)) {
	if ($cell -match '\|') { throw "pipe character breaks the markdown tables: $cell" }
}

$bookLines = [System.Collections.Generic.List[string]]::new()
$bookLines.Add('# Books corpus index')
$bookLines.Add('')
$bookLines.Add("Generated from the books corpus manifests and books-index.json by books-index.sh or books-index.ps1, do not edit by hand. Grep this file for a topic, note the chapter file, read only that file. Paths are relative to $CanonBooks. Out of scope: $ExcludeLine.")
$bookLines.Add('')

$tableLines = [System.Collections.Generic.List[string]]::new()
$tableLines.Add('| book | scope | capstone | walkthroughs |')
$tableLines.Add('|---|---|---|---|')

$totalChapters = 0
foreach ($dir in $Order) {
	$b = $Books[$dir]
	$ann = $b.Ann
	$n = $b.Chapters.Count
	$totalChapters += $n
	$bookLines.Add("## $($b.Title) (book $($b.Num), v$($b.Version), $dir, $n chapters)")
	$bookLines.Add('')
	$bookLines.Add("summary: $($ann.summary)")
	$bookLines.Add("capstone: $($ann.capstone)")
	$bookLines.Add("walkthroughs: $($ann.walkthroughs)")
	$bookLines.Add('toc:')
	$bookLines.AddRange([string[]]$b.Chapters)
	$bookLines.Add('')
	$tableLines.Add("| $($b.Title) ($dir) | $($b.Subtitle) | $($ann.capstone_short) | $($ann.walkthroughs) |")
}

[System.IO.File]::WriteAllText($BooksOut, ($bookLines -join "`n") + "`n", $Utf8NoBom)

$lines = [System.IO.File]::ReadAllLines($ClaudeMd)
$beginIdx = [array]::IndexOf($lines, $BeginMark)
$endIdx = [array]::IndexOf($lines, $EndMark)
if ($beginIdx -lt 0 -or $endIdx -lt 0 -or $endIdx -le $beginIdx) { throw "markers not found or out of order in .claude/CLAUDE.md" }
$spliced = @()
if ($beginIdx -gt 0) { $spliced += $lines[0..($beginIdx - 1)] }
$spliced += $BeginMark
$spliced += $tableLines
$spliced += $lines[$endIdx..($lines.Count - 1)]
[System.IO.File]::WriteAllText($ClaudeMd, ($spliced -join "`n") + "`n", $Utf8NoBom)

Write-Host "books index: $($Books.Count) books, $totalChapters chapters -> .claude/BOOKS.md, table updated in .claude/CLAUDE.md"
