#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIAGRAMS_DIR="${DIAGRAMS_DIR:-$ROOT_DIR/docs/diagrams}"
START_USEC="${EPOCHREALTIME/./}"

die() {
	echo "Error: $*" >&2
	exit 1
}

elapsed_ms() {
	echo "$(((${EPOCHREALTIME/./} - $1) / 1000))"
}

echo "diagrams: start dir=$DIAGRAMS_DIR"
[ -d "$DIAGRAMS_DIR" ] || die "diagrams dir not found: $DIAGRAMS_DIR"
shopt -s nullglob
pumls=("$DIAGRAMS_DIR"/*.puml)
shopt -u nullglob
[ "${#pumls[@]}" -gt 0 ] || die "no .puml files in $DIAGRAMS_DIR"
case "$(uname -s)" in
MINGW* | MSYS* | CYGWIN*) hint='scoop install plantuml' ;;
*) hint='install plantuml with the system package manager' ;;
esac
command -v plantuml >/dev/null 2>&1 || die "plantuml not found on PATH, install hint: $hint"

missing=()
for puml in "${pumls[@]}"; do
	file_start="${EPOCHREALTIME/./}"
	echo "diagrams: render $(basename "$puml")"
	rc=0
	plantuml -failfast2 -tpng "$puml" || rc=$?
	[ "$rc" -eq 0 ] || die "plantuml failed with exit $rc on $puml"
	png="${puml%.puml}.png"
	if [ ! -f "$png" ]; then
		missing+=("$(basename "$puml")")
	fi
	echo "diagrams: ok $(basename "$puml") in $(elapsed_ms "$file_start") ms"
done
[ "${#missing[@]}" -eq 0 ] || die "missing png for: ${missing[*]}"

echo "diagrams: done ${#pumls[@]} png(s) in $(elapsed_ms "$START_USEC") ms"
