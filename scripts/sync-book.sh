#!/usr/bin/env bash
# Refresh the repo books/ publishing front from the private corpus
#
# Mirrors manifest.typ, book.typ, chapters/*.typ, coverage/*.typ per volume
# plus the compiled PDFs from ~/dev/github/resume, pruning retired volumes
# and stale target .typ files. Skips cleanly when the corpus is absent.
#
# Usage: ./scripts/sync-book.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORPUS="$HOME/dev/github/resume/books"
PDF_SRC="$HOME/dev/github/resume/output/books"
TARGET="$SCRIPT_DIR/../books"
ANNOTATIONS="$SCRIPT_DIR/books-index.json"

die() { echo "Error: $*" >&2; exit 1; }

if [[ ! -d "$CORPUS" ]]; then
	echo "books corpus not found, skipping sync: $CORPUS"
	exit 0
fi

command -v jq >/dev/null 2>&1 || die "jq is required (scoop install jq)"
[[ -f "$ANNOTATIONS" ]] || die "annotations not found: $ANNOTATIONS"
excluded_json="$(jq -r '.exclude[]' "$ANNOTATIONS" 2>/dev/null)" || die "cannot parse $ANNOTATIONS"
excluded_json="${excluded_json//$'\r'/}"
EXCLUDED=()
[[ -n "$excluded_json" ]] && mapfile -t EXCLUDED <<<"$excluded_json"

list_has() {
	local want="$1" item
	for item in "${@:2}"; do [[ "$item" == "$want" ]] && return 0; done
	return 1
}

mapfile -t INCLUDED < <(for path in "$CORPUS"/*/; do
	dir="$(basename "$path")"
	list_has "$dir" "${EXCLUDED[@]}" || printf '%s\n' "$dir"
done | LC_ALL=C sort)

mkdir -p "$TARGET"

copied=0
deleted=0
pdfs=0

# Retired volumes: any target dir outside the include list goes away
for path in "$TARGET"/*/; do
	[[ -d "$path" ]] || continue
	dir="$(basename "$path")"
	if ! list_has "$dir" "${INCLUDED[@]}"; then
		deleted=$((deleted + $(find "$path" -type f | wc -l)))
		rm -rf "${path:?}"
	fi
done

for dir in "${INCLUDED[@]}"; do
	src="$CORPUS/$dir"
	dst="$TARGET/$dir"
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
		done < <(find "$dst" -type f -name '*.typ' -print0)
	fi
done

shopt -s nullglob
for dir in "${INCLUDED[@]}"; do
	hits=("$PDF_SRC/"*-"$dir".pdf)
	if [[ ${#hits[@]} -eq 0 ]]; then
		echo "warning: no pdf for $dir in $PDF_SRC" >&2
		continue
	fi
	for f in "${hits[@]}"; do
		out="$TARGET/$(basename "$f")"
		if [[ ! -f "$out" ]] || ! cmp -s "$f" "$out"; then
			cp "$f" "$out"
			pdfs=$((pdfs + 1))
		fi
	done
done
shopt -u nullglob

echo "books sync: ${#INCLUDED[@]} volumes, $copied files copied, $deleted files deleted, $pdfs pdfs copied"
