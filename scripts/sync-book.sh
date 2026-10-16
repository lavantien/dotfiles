#!/usr/bin/env bash
# Refresh the repo books publishing front from the private corpus
#
# Mirrors manifest.typ, book.typ, chapters/*.typ, coverage/*.typ per volume
# into .claude/books (the typst corpus agents ground on) plus the compiled
# PDFs into books/ at the root (human reading copies only), pruning retired
# volumes and stale target files. Skips cleanly when the corpus is absent.
#
# Usage: ./scripts/sync-book.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORPUS="${BOOKS_CORPUS:-$HOME/dev/github/resume/books}"
PDF_SRC="${BOOKS_PDF_SRC:-$HOME/dev/github/resume/output/books}"
TYPO_TARGET="${BOOKS_TYPO_TARGET:-$SCRIPT_DIR/../.claude/books}"
PDF_TARGET="${BOOKS_PDF_TARGET:-$SCRIPT_DIR/../books}"
ANNOTATIONS="$SCRIPT_DIR/books-index.json"

die() {
	echo "Error: $*" >&2
	exit 1
}

if [[ ! -d "$CORPUS" ]]; then
	echo "books corpus not found, skipping sync: $CORPUS"
	exit 0
fi

command -v jq >/dev/null 2>&1 || die "jq is required (scoop install jq)"
[[ -f "$ANNOTATIONS" ]] || die "annotations not found: $ANNOTATIONS"
excluded_json="$(jq -r '.exclude[]' "$ANNOTATIONS" 2>/dev/null)" || die "cannot parse $ANNOTATIONS"
excluded_json="${excluded_json//$'\r'/}"
EXCLUDED=()
if [[ -n "$excluded_json" ]]; then
	while IFS= read -r dir; do EXCLUDED+=("$dir"); done <<<"$excluded_json"
fi

list_has() {
	local want="$1" item
	for item in "${@:2}"; do [[ "$item" == "$want" ]] && return 0; done
	return 1
}

INCLUDED=()
while IFS= read -r dir; do INCLUDED+=("$dir"); done < <(
	for path in "$CORPUS"/*/; do
		[[ -d "$path" ]] || continue
		dir="$(basename "$path")"
		list_has "$dir" "${EXCLUDED[@]}" || printf '%s\n' "$dir"
	done | LC_ALL=C sort
)

if [[ ${#INCLUDED[@]} -eq 0 ]]; then
	die "no included volumes found under $CORPUS, refusing to touch $TYPO_TARGET"
fi
declare -A PDF_NAME
for dir in "${INCLUDED[@]}"; do
	manifest="$CORPUS/$dir/manifest.typ"
	[[ -f "$manifest" ]] || die "no manifest.typ in $dir"
	num="$(sed -n 's/^[[:space:]]*num:[[:space:]]*\([0-9][0-9]*\),.*$/\1/p' "$manifest" | head -n1)"
	[[ -n "$num" ]] || die "no num in $dir manifest"
	printf -v nn '%02d' "$((10#$num))"
	PDF_NAME[$dir]="$nn-$dir.pdf"
done

mkdir -p "$TYPO_TARGET" "$PDF_TARGET"

copied=0
deleted=0
pdfs=0

# Retired volumes: any typst target dir outside the include list goes away
for path in "$TYPO_TARGET"/*/; do
	[[ -d "$path" ]] || continue
	dir="$(basename "$path")"
	if ! list_has "$dir" "${INCLUDED[@]}"; then
		deleted=$((deleted + $(find "$path" -type f | wc -l)))
		rm -rf "${path:?}"
	fi
done

# books/ at the root is PDFs only, any directory there is stale typst
for path in "$PDF_TARGET"/*/; do
	[[ -d "$path" ]] || continue
	deleted=$((deleted + $(find "$path" -type f | wc -l)))
	rm -rf "${path:?}"
done

for dir in "${INCLUDED[@]}"; do
	src="$CORPUS/$dir"
	dst="$TYPO_TARGET/$dir"
	[[ -f "$src/manifest.typ" ]] || die "no manifest.typ in $dir"

	rel_typ_files=("manifest.typ")
	if [[ -f "$src/book.typ" ]]; then rel_typ_files+=("book.typ"); fi
	shopt -s nullglob
	for f in "$src/chapters/"*.typ; do rel_typ_files+=("chapters/$(basename "$f")"); done
	for f in "$src/coverage/"*.typ; do rel_typ_files+=("coverage/$(basename "$f")"); done
	shopt -u nullglob

	for rel in "${rel_typ_files[@]}"; do
		in="$src/$rel"
		out="$dst/$rel"
		mkdir -p "$(dirname "$out")"
		if [[ ! -f "$out" ]] || ! cmp -s "$in" "$out"; then
			cp "$in" "$out"
			copied=$((copied + 1))
		fi
	done

	if [[ -d "$dst" ]]; then
		while IFS= read -r -d '' f; do
			rel="${f#"$dst"/}"
			if list_has "$rel" "${rel_typ_files[@]}"; then continue; fi
			rm "$f"
			deleted=$((deleted + 1))
		done < <(find "$dst" -type f -print0)
		find "$dst" -mindepth 1 -type d -empty -delete 2>/dev/null || true
	fi
done

shopt -s nullglob
for dir in "${INCLUDED[@]}"; do
	expected="${PDF_NAME[$dir]}"
	if [[ ! -f "$PDF_SRC/$expected" ]]; then
		echo "warning: no pdf for $dir in $PDF_SRC" >&2
		continue
	fi
	out="$PDF_TARGET/$expected"
	if [[ ! -f "$out" ]] || ! cmp -s "$PDF_SRC/$expected" "$out"; then
		cp "$PDF_SRC/$expected" "$out"
		pdfs=$((pdfs + 1))
	fi
done

# Only the manifest-numbered PDF of an included volume stays, renumbered and retired names go
for f in "$PDF_TARGET"/*.pdf; do
	if ! list_has "$(basename "$f")" "${PDF_NAME[@]}"; then
		rm "$f"
		deleted=$((deleted + 1))
	fi
done
shopt -u nullglob

echo "books sync: ${#INCLUDED[@]} volumes, $copied files copied, $deleted files deleted, $pdfs pdfs copied"
