#!/usr/bin/env bash
# Books corpus index generator
#
# Reads the books corpus manifests at the repo's .claude/books dir (or $BOOKS_DIR)
# plus curated annotations from books-index.json, then:
#   1. emits .claude/BOOKS.md, the chapter-level grounding index
#   2. splices the compact routing table into .claude/CLAUDE.md between markers
#   3. splices the reference table into README.md between markers
# All outputs are fully regenerated, never edit them by hand.
#
# Usage: ./books-index.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BOOKS_DIR="${BOOKS_DIR:-$ROOT_DIR/.claude/books}"
# Neutral phrase printed in the header, identical on every platform
PATHS_NOTE='Paths are corpus-relative, resolve them against the corpus root stated in CLAUDE.md principle 13.'
ANNOTATIONS="$SCRIPT_DIR/books-index.json"
BOOKS_OUT="$ROOT_DIR/.claude/BOOKS.md"
CLAUDE_MD="$ROOT_DIR/.claude/CLAUDE.md"
BEGIN_MARK='<!-- BEGIN books index -->'
END_MARK='<!-- END books index -->'
README_MD="$ROOT_DIR/README.md"
README_BEGIN='<!-- BEGIN books readme table -->'
README_END='<!-- END books readme table -->'

die() { echo "Error: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || die "jq is required (scoop install jq)"
[[ -d "$BOOKS_DIR" ]] || die "books dir not found: $BOOKS_DIR"
[[ -f "$ANNOTATIONS" ]] || die "annotations not found: $ANNOTATIONS"
[[ -f "$CLAUDE_MD" ]] || die "missing $CLAUDE_MD"
[[ -f "$README_MD" ]] || die "missing $README_MD"
# Markers must be exact single lines in order, a stray or duplicated marker is fatal
begin_count="$(grep -Fxc "$BEGIN_MARK" "$CLAUDE_MD")"
end_count="$(grep -Fxc "$END_MARK" "$CLAUDE_MD")"
[[ "$begin_count" == 1 && "$end_count" == 1 ]] ||
	die "expected exactly one BEGIN and one END marker line in .claude/CLAUDE.md, got $begin_count and $end_count"
begin_ln="$(grep -Fxn "$BEGIN_MARK" "$CLAUDE_MD" | cut -d: -f1)"
end_ln="$(grep -Fxn "$END_MARK" "$CLAUDE_MD" | cut -d: -f1)"
[[ "$begin_ln" -lt "$end_ln" ]] || die "BEGIN marker must come before END marker in .claude/CLAUDE.md"
readme_begin_count="$(grep -Fxc "$README_BEGIN" "$README_MD")"
readme_end_count="$(grep -Fxc "$README_END" "$README_MD")"
[[ "$readme_begin_count" == 1 && "$readme_end_count" == 1 ]] ||
	die "expected exactly one BEGIN and one END marker line in README.md, got $readme_begin_count and $readme_end_count"
readme_begin_ln="$(grep -Fxn "$README_BEGIN" "$README_MD" | cut -d: -f1)"
readme_end_ln="$(grep -Fxn "$README_END" "$README_MD" | cut -d: -f1)"
[[ "$readme_begin_ln" -lt "$readme_end_ln" ]] || die "BEGIN marker must come before END marker in README.md"
# od is byte-true, MSYS2 grep and gawk are CRLF-transparent in text mode
od -An -c "$CLAUDE_MD" | grep -q '\\r' && die ".claude/CLAUDE.md has CRLF line endings"
od -An -c "$README_MD" | grep -q '\\r' && die "README.md has CRLF line endings"

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

# The corpus root holds volume dirs only, loose files are drift
while IFS= read -r stray; do
	die "loose file at the corpus root: $stray"
done < <(find "$BOOKS_DIR" -mindepth 1 -maxdepth 1 -type f -exec basename {} \;)

for path in "$BOOKS_DIR"/*/; do
	dir="$(basename "$path")"
	is_excluded "$dir" && continue
	manifest="$path/manifest.typ"
	[[ -f "$manifest" ]] || die "no manifest.typ in $dir"
	# The corpus is typst-only, any other file in the tree is drift
	while IFS= read -r -d '' stray; do
		die "non-typst file in corpus: $dir/${stray#"$path"}"
	done < <(find "$path" -type f ! -name '*.typ' -print0)
	num="$(sed -n 's/^[[:space:]]*num:[[:space:]]*\([0-9][0-9]*\),.*$/\1/p' "$manifest" | head -n1)"
	title="$(sed -n 's/^[[:space:]]*title:[[:space:]]*"\([^"]*\)",.*$/\1/p' "$manifest" | head -n1)"
	version="$(sed -n 's/^[[:space:]]*version:[[:space:]]*"\([^"]*\)",.*$/\1/p' "$manifest" | head -n1)"
	subtitle="$(sed -n 's/^[[:space:]]*subtitle:[[:space:]]*"\([^"]*\)",.*$/\1/p' "$manifest" | head -n1)"
	[[ -n "$num" && -n "$title" && -n "$version" && -n "$subtitle" ]] ||
		die "incomplete manifest meta in $dir (num/title/version/subtitle)"
	num="$((10#$num))"
	jq -e --arg d "$dir" '[.books[$d].summary, .books[$d].capstone, .books[$d].capstone_short, .books[$d].walkthroughs | length] | all(. > 0)' "$ANNOTATIONS" >/dev/null ||
		die "books-index.json is missing summary, capstone, capstone_short, or walkthroughs for $dir"
	META[$dir]="$num|$title|$version|$subtitle"
	ORDER+=("$dir")
done

# Every annotation key must name an included book, catches typos in dir names
for dir in "${ANNOTATED[@]}"; do
	[[ -n "${META[$dir]:-}" ]] || die "books-index.json entry '$dir' matches no included book"
done

# Order books by book num, dir name breaks ties deterministically
mapfile -t ORDER < <(for dir in "${ORDER[@]}"; do echo "${META[$dir]%%|*} $dir"; done | LC_ALL=C sort -k1,1n -k2,2 | awk '{print $2}')

exclude_line="$(printf '%s, ' "${EXCLUDED[@]}")"
exclude_line="${exclude_line%, }"
TMP_BOOKS="$(mktemp)"
TMP_TABLE="$(mktemp)"
TMP_CLAUDE="$(mktemp)"
TMP_README="$(mktemp)"
trap 'rm -f "$TMP_BOOKS" "$TMP_TABLE" "$TMP_CLAUDE" "$TMP_README"' EXIT

{
	echo "# Books corpus index"
	echo
	echo "Generated from the books corpus manifests and scripts/books-index.json by scripts/books-index.sh or scripts/books-index.ps1, do not edit by hand. Grep this file for a topic, note the chapter file, read only that file. $PATHS_NOTE Out of scope: $exclude_line."
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
		[[ "$line" =~ \([[:space:]]*id:[[:space:]]*\"([^\"]+)\",[[:space:]]*num:[[:space:]]*([0-9]+),[[:space:]]*title:[[:space:]]*\"([^\"]+)\" ]] || continue
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
		if LC_ALL=C grep -q '[^ -~]' <<<"$cell"; then
			die "$dir: non-ascii or control character breaks twin table parity: $cell"
		fi
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

# Replace the lines between the marker pair with the generated table
splice() {
	local src="$1" out="$2" begin="$3" end="$4"
	awk -v begin="$begin" -v end="$end" -v table="$TMP_TABLE" '
		$0 == begin { print; while ((getline line < table) > 0) print line; close(table); inblock = 1; next }
		$0 == end { inblock = 0; print; next }
		!inblock { print }
	' "$src" >"$out"
}
splice "$CLAUDE_MD" "$TMP_CLAUDE" "$BEGIN_MARK" "$END_MARK"
mv "$TMP_CLAUDE" "$CLAUDE_MD"
splice "$README_MD" "$TMP_README" "$README_BEGIN" "$README_END"
mv "$TMP_README" "$README_MD"
# mktemp hands out 0600, the outputs must stay world-readable
chmod 644 "$BOOKS_OUT" "$CLAUDE_MD" "$README_MD"

echo "books index: ${#ORDER[@]} books, $total_chapters chapters -> .claude/BOOKS.md, tables updated in .claude/CLAUDE.md and README.md"
