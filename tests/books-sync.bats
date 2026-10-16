#!/usr/bin/env bash
# sync-book.sh contract against a fixture corpus: mirror, prune, renumber.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/sync-book.sh"

setup() {
	FIX="$(mktemp -d)"
	CORPUS="$FIX/corpus"
	PDF_SRC="$FIX/output"
	TYPO_TARGET="$FIX/typst"
	PDF_TARGET="$FIX/pdfs"
	mkdir -p "$CORPUS/alpha/chapters" "$CORPUS/beta" "$PDF_SRC"
	printf 'num: 3,\ntitle: "alpha",\nversion: "1.0",\nsubtitle: "s",\n' >"$CORPUS/alpha/manifest.typ"
	printf 'alpha body\n' >"$CORPUS/alpha/chapters/01-one.typ"
	printf 'num: 4,\ntitle: "beta",\nversion: "1.0",\nsubtitle: "s",\n' >"$CORPUS/beta/manifest.typ"
	printf 'pdf-alpha\n' >"$PDF_SRC/03-alpha.pdf"
	printf 'pdf-beta\n' >"$PDF_SRC/04-beta.pdf"
}

teardown() {
	rm -rf "$FIX"
}

run_sync() {
	run env BOOKS_CORPUS="$CORPUS" BOOKS_PDF_SRC="$PDF_SRC" BOOKS_TYPO_TARGET="$TYPO_TARGET" BOOKS_PDF_TARGET="$PDF_TARGET" \
		bash "$SCRIPT"
}

@test "mirrors typst sources and manifest-numbered pdfs" {
	run_sync
	[ "$status" -eq 0 ]
	[ -f "$TYPO_TARGET/alpha/manifest.typ" ]
	[ -f "$TYPO_TARGET/alpha/chapters/01-one.typ" ]
	[ -f "$TYPO_TARGET/beta/manifest.typ" ]
	[ -f "$PDF_TARGET/03-alpha.pdf" ]
	[ -f "$PDF_TARGET/04-beta.pdf" ]
}

@test "prunes stale renumbered pdfs and stale typst files" {
	run_sync
	printf 'old numbering\n' >"$PDF_TARGET/02-alpha.pdf"
	printf 'stale\n' >"$TYPO_TARGET/alpha/chapters/99-gone.typ"
	run_sync
	[ "$status" -eq 0 ]
	[ ! -e "$PDF_TARGET/02-alpha.pdf" ]
	[ ! -e "$TYPO_TARGET/alpha/chapters/99-gone.typ" ]
	[ -f "$PDF_TARGET/03-alpha.pdf" ]
	[ "$(ls "$PDF_TARGET" | wc -l)" -eq 2 ]
}

@test "prunes retired volumes from the typst target" {
	mkdir -p "$TYPO_TARGET/gamma/chapters"
	printf 'retired\n' >"$TYPO_TARGET/gamma/chapters/01-one.typ"
	run_sync
	[ "$status" -eq 0 ]
	[ ! -e "$TYPO_TARGET/gamma" ]
}

@test "missing source pdf warns but keeps the run green" {
	rm "$PDF_SRC/04-beta.pdf"
	run_sync
	[ "$status" -eq 0 ]
	[ -f "$PDF_TARGET/03-alpha.pdf" ]
	[ ! -f "$PDF_TARGET/04-beta.pdf" ]
}
