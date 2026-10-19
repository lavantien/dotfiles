#!/usr/bin/env bash
# diagrams twins contract against a fixture dir: render, pwsh twin, syntax error, stale refresh, missing dir, empty dir.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/diagrams.sh"
PWSH_SCRIPT="$REPO_ROOT/scripts/diagrams.ps1"

setup() {
	FIX="$(mktemp -d)"
	DIAGRAMS="$FIX/diagrams"
	mkdir -p "$DIAGRAMS"
	printf '@startmindmap t\n* root\n** k : action\n@endmindmap\n' >"$DIAGRAMS/t.puml"
}

teardown() {
	rm -rf "$FIX"
}

@test "renders a fixture puml to a png beside it when plantuml is available" {
	command -v plantuml >/dev/null 2>&1 || skip 'plantuml not installed'
	run env DIAGRAMS_DIR="$DIAGRAMS" bash "$SCRIPT"
	[ "$status" -eq 0 ]
	[ -f "$DIAGRAMS/t.png" ]
}

@test "renders via the pwsh twin when pwsh and plantuml are available" {
	command -v pwsh >/dev/null 2>&1 || skip 'pwsh not installed'
	command -v plantuml >/dev/null 2>&1 || skip 'plantuml not installed'
	run env DIAGRAMS_DIR="$DIAGRAMS" pwsh -NoProfile -File "$PWSH_SCRIPT"
	[ "$status" -eq 0 ]
	[ -f "$DIAGRAMS/t.png" ]
}

@test "propagates a puml syntax error" {
	command -v plantuml >/dev/null 2>&1 || skip 'plantuml not installed'
	rm "$DIAGRAMS/t.puml"
	printf '@startmindmap t\n* root\n** k : action\n:\n@endmindmap\n' >"$DIAGRAMS/bad.puml"
	run env DIAGRAMS_DIR="$DIAGRAMS" bash "$SCRIPT"
	[ "$status" -ne 0 ]
	grep -q 'plantuml failed with exit' <<<"$output"
}

@test "refreshes a stale png when the puml changes" {
	command -v plantuml >/dev/null 2>&1 || skip 'plantuml not installed'
	run env DIAGRAMS_DIR="$DIAGRAMS" bash "$SCRIPT"
	[ "$status" -eq 0 ]
	before="$(sha256sum "$DIAGRAMS/t.png" | cut -d' ' -f1)"
	printf '@startmindmap t\n* root\n** k : action\n** k2 : action2\n@endmindmap\n' >"$DIAGRAMS/t.puml"
	run env DIAGRAMS_DIR="$DIAGRAMS" bash "$SCRIPT"
	[ "$status" -eq 0 ]
	after="$(sha256sum "$DIAGRAMS/t.png" | cut -d' ' -f1)"
	[ "$before" != "$after" ]
}

@test "fails when the diagrams dir is missing" {
	run env DIAGRAMS_DIR="$FIX/absent" bash "$SCRIPT"
	[ "$status" -ne 0 ]
	grep -q 'diagrams dir not found' <<<"$output"
}

@test "fails when the diagrams dir holds no puml" {
	rm "$DIAGRAMS/t.puml"
	run env DIAGRAMS_DIR="$DIAGRAMS" bash "$SCRIPT"
	[ "$status" -ne 0 ]
	grep -q 'no .puml files' <<<"$output"
}
