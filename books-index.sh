#!/usr/bin/env bash
# Books corpus index generator
#
# Reads the books corpus manifests at ~/dev/github/resume/books (or $BOOKS_DIR)
# plus curated annotations from books-index.json, then:
#   1. emits .claude/BOOKS.md, the chapter-level grounding index
#   2. splices the compact routing table into .claude/CLAUDE.md between markers
# Both outputs are fully regenerated, never edit them by hand.
#
# Usage: ./books-index.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOKS_DIR="${BOOKS_DIR:-$HOME/dev/github/resume/books}"
# Canonical label printed in the header, identical on every platform
CANON_BOOKS='~/dev/github/resume/books'
ANNOTATIONS="$SCRIPT_DIR/books-index.json"
BOOKS_OUT="$SCRIPT_DIR/.claude/BOOKS.md"
CLAUDE_MD="$SCRIPT_DIR/.claude/CLAUDE.md"
BEGIN_MARK='<!-- BEGIN books index -->'
END_MARK='<!-- END books index -->'

die() { echo "Error: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || die "jq is required (scoop install jq)"
[[ -d "$BOOKS_DIR" ]] || die "books dir not found: $BOOKS_DIR"
[[ -f "$ANNOTATIONS" ]] || die "annotations not found: $ANNOTATIONS"
[[ -f "$CLAUDE_MD" ]] || die "missing $CLAUDE_MD"
grep -qF "$BEGIN_MARK" "$CLAUDE_MD" || die "$BEGIN_MARK not found in .claude/CLAUDE.md"
grep -qF "$END_MARK" "$CLAUDE_MD" || die "$END_MARK not found in .claude/CLAUDE.md"
! grep -q $'\r' "$CLAUDE_MD" || die ".claude/CLAUDE.md has CRLF line endings"

mapfile -t EXCLUDED < <(jq -r '.exclude[]' "$ANNOTATIONS" | tr -d '\r')
mapfile -t ANNOTATED < <(jq -r '.books | keys[]' "$ANNOTATIONS" | tr -d '\r')

is_excluded() {
	local d
	for d in "${EXCLUDED[@]}"; do [[ "$d" == "$1" ]] && return 0; done
	return 1
}

# Collect book metadata: dir -> "num|title|version|subtitle"
declare -A META
ORDER=()
for path in "$BOOKS_DIR"/*/; do
	dir="$(basename "$path")"
	is_excluded "$dir" && continue
	manifest="$path/manifest.typ"
	[[ -f "$manifest" ]] || die "no manifest.typ in $dir"
	num="$(sed -n 's/^[[:space:]]*num: \([0-9][0-9]*\),.*$/\1/p' "$manifest" | head -n1)"
	title="$(sed -n 's/^[[:space:]]*title: "\([^"]*\)",.*$/\1/p' "$manifest" | head -n1)"
	version="$(sed -n 's/^[[:space:]]*version: "\([^"]*\)",.*$/\1/p' "$manifest" | head -n1)"
	subtitle="$(sed -n 's/^[[:space:]]*subtitle: "\([^"]*\)",.*$/\1/p' "$manifest" | head -n1)"
	[[ -n "$num" && -n "$title" && -n "$version" && -n "$subtitle" ]] ||
		die "incomplete manifest meta in $dir (num/title/version/subtitle)"
	jq -e --arg d "$dir" '.books[$d].summary and .books[$d].capstone and .books[$d].capstone_short and .books[$d].walkthroughs' "$ANNOTATIONS" >/dev/null ||
		die "books-index.json is missing summary, capstone, capstone_short, or walkthroughs for $dir"
	META[$dir]="$num|$title|$version|$subtitle"
	ORDER+=("$dir")
done

# Every annotation key must name an included book, catches typos in dir names
for dir in "${ANNOTATED[@]}"; do
	[[ -n "${META[$dir]:-}" ]] || die "books-index.json entry '$dir' matches no included book"
done

# Order books by book num
mapfile -t ORDER < <(for dir in "${ORDER[@]}"; do echo "${META[$dir]%%|*} $dir"; done | sort -n | awk '{print $2}')

exclude_line="$(printf '%s, ' "${EXCLUDED[@]}")"
exclude_line="${exclude_line%, }"
TMP_BOOKS="$(mktemp)"
TMP_TABLE="$(mktemp)"
TMP_CLAUDE="$(mktemp)"
trap 'rm -f "$TMP_BOOKS" "$TMP_TABLE" "$TMP_CLAUDE"' EXIT

{
	echo "# Books corpus index"
	echo
	echo "Generated from the books corpus manifests and books-index.json by books-index.sh or books-index.ps1, do not edit by hand. Grep this file for a topic, note the chapter file, read only that file. Paths are relative to $CANON_BOOKS. Out of scope: $exclude_line."
	echo
} >"$TMP_BOOKS"

TABLE_HDR=(book scope capstone walkthroughs)
T_C1=()
T_C2=()
T_C3=()
T_C4=()

total_chapters=0
for dir in "${ORDER[@]}"; do
	IFS='|' read -r num title version subtitle <<<"${META[$dir]}"
	manifest="$BOOKS_DIR/$dir/manifest.typ"

	summary="$(jq -r --arg d "$dir" '.books[$d].summary' "$ANNOTATIONS" | tr -d '\r')"
	capstone="$(jq -r --arg d "$dir" '.books[$d].capstone' "$ANNOTATIONS" | tr -d '\r')"
	capstone_short="$(jq -r --arg d "$dir" '.books[$d].capstone_short' "$ANNOTATIONS" | tr -d '\r')"
	walkthroughs="$(jq -r --arg d "$dir" '.books[$d].walkthroughs' "$ANNOTATIONS" | tr -d '\r')"

	chapters=()
	missing=()
	while IFS= read -r line; do
		[[ "$line" =~ \(id:[[:space:]]*\"([^\"]+)\",[[:space:]]*num:[[:space:]]*([0-9]+),[[:space:]]*title:[[:space:]]*\"([^\"]+)\" ]] || continue
		chid="${BASH_REMATCH[1]}"
		chnum="${BASH_REMATCH[2]}"
		chtitle="${BASH_REMATCH[3]}"
		printf -v nn '%02d' "$chnum"
		# Resolve by number prefix, a few manifest ids disagree with file names
		shopt -s nullglob
		candidates=("$BOOKS_DIR/$dir/chapters/$nn-"*.typ)
		shopt -u nullglob
		if [[ ${#candidates[@]} -eq 1 ]]; then
			file="$dir/chapters/$(basename "${candidates[0]}")"
			chapters+=("- $nn $chtitle ($file)")
		else
			missing+=("$nn-$chid.typ (${#candidates[@]} candidates)")
		fi
		total_chapters=$((total_chapters + 1))
	done <"$manifest"
	[[ ${#chapters[@]} -gt 0 ]] || die "$dir: no chapters parsed from manifest"
	[[ ${#missing[@]} -eq 0 ]] || die "$dir: chapter files not found: ${missing[*]}"

	for cell in "$title" "$subtitle" "$capstone_short" "$walkthroughs" "$summary" "$capstone"; do
		[[ "$cell" != *"|"* ]] || die "$dir: pipe character breaks the markdown tables: $cell"
	done

	{
		echo "## $title (book $num, v$version, $dir, ${#chapters[@]} chapters)"
		echo
		echo "summary: $summary"
		echo "capstone: $capstone"
		echo "walkthroughs: $walkthroughs"
		echo "toc:"
		echo
		printf '%s\n' "${chapters[@]}"
		echo
	} >>"$TMP_BOOKS"

	T_C1+=("$title ($dir)")
	T_C2+=("$subtitle")
	T_C3+=("$capstone_short")
	T_C4+=("$walkthroughs")
done

# Prettier-stable table: blank lines around it, cells padded to column width
pad() { printf '%-*s' "$2" "$1"; }
dashes() { printf '%*s' "$2" '' | tr ' ' '-'; }
maxw() {
	local w="$1" cell
	shift
	for cell in "$@"; do
		((${#cell} > w)) && w=${#cell}
	done
	echo "$w"
}
widths=($(maxw "${#TABLE_HDR[0]}" "${T_C1[@]}") $(maxw "${#TABLE_HDR[1]}" "${T_C2[@]}") $(maxw "${#TABLE_HDR[2]}" "${T_C3[@]}") $(maxw "${#TABLE_HDR[3]}" "${T_C4[@]}"))
{
	echo
	echo "| $(pad "${TABLE_HDR[0]}" "${widths[0]}") | $(pad "${TABLE_HDR[1]}" "${widths[1]}") | $(pad "${TABLE_HDR[2]}" "${widths[2]}") | $(pad "${TABLE_HDR[3]}" "${widths[3]}") |"
	echo "| $(dashes "" "${widths[0]}") | $(dashes "" "${widths[1]}") | $(dashes "" "${widths[2]}") | $(dashes "" "${widths[3]}") |"
	for i in "${!T_C1[@]}"; do
		echo "| $(pad "${T_C1[$i]}" "${widths[0]}") | $(pad "${T_C2[$i]}" "${widths[1]}") | $(pad "${T_C3[$i]}" "${widths[2]}") | $(pad "${T_C4[$i]}" "${widths[3]}") |"
	done
	echo
} >"$TMP_TABLE"

# Exactly one trailing newline, prettier trims blank lines at EOF
printf '%s\n' "$(cat "$TMP_BOOKS")" >"$TMP_BOOKS"
mv "$TMP_BOOKS" "$BOOKS_OUT"

awk -v begin="$BEGIN_MARK" -v end="$END_MARK" -v table="$TMP_TABLE" '
	$0 == begin { print; while ((getline line < table) > 0) print line; close(table); inblock = 1; next }
	$0 == end { inblock = 0; print; next }
	!inblock { print }
' "$CLAUDE_MD" >"$TMP_CLAUDE"
mv "$TMP_CLAUDE" "$CLAUDE_MD"

echo "books index: ${#ORDER[@]} books, $total_chapters chapters -> .claude/BOOKS.md, table updated in .claude/CLAUDE.md"
