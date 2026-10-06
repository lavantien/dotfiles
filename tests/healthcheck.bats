#!/usr/bin/env bash
# Slot 2 healthcheck contracts: optional tools warn instead of failing, the
# nvim/vim fallback records one result, and JSON stays valid under quotes.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

bats_require_minimum_version 1.5.0

# Validate a JSON document with whatever parser the host offers
json_ok() {
	if command -v jq >/dev/null 2>&1; then
		jq -e . >/dev/null 2>&1 <<<"$1"
	elif command -v python3 >/dev/null 2>&1; then
		python3 -c 'import json,sys; json.load(sys.stdin)' <<<"$1"
	elif command -v python >/dev/null 2>&1; then
		python -c 'import json,sys; json.load(sys.stdin)' <<<"$1"
	else
		fail "no json validator available (jq or python)"
	fi
}

# Sandbox with a minimal PATH (git, grep, and a vim stub: every optional tool
# is missing) and an isolated HOME carrying the required git configuration
setup_sandbox() {
	SB="$BATS_TEST_TMPDIR/sb"
	SBBIN="$SB/bin"
	SBHOME="$SB/home"
	mkdir -p "$SBBIN" "$SBHOME"
	for tool in git grep; do
		# shebang pinned to the absolute bash: /usr/bin/env would PATH-search
		# the stripped sandbox PATH and find no bash
		printf '#!%s\nexec %q "$@"\n' "$(command -v bash)" "$(command -v "$tool")" >"$SBBIN/$tool"
		chmod +x "$SBBIN/$tool"
	done
	: >"$SBBIN/vim"
	chmod +x "$SBBIN/vim"
	env HOME="$SBHOME" PATH="$SBBIN" "$(command -v git)" config --global user.name "Sandbox User"
	env HOME="$SBHOME" PATH="$SBBIN" "$(command -v git)" config --global user.email "sandbox@example.invalid"
	env HOME="$SBHOME" PATH="$SBBIN" "$(command -v git)" config --global core.editor vim
}

@test "healthcheck exits 0 when only optional tools are missing" {
	setup_sandbox
	run --separate-stderr env HOME="$SBHOME" PATH="$SBBIN" "$(command -v bash)" "$REPO_ROOT/scripts/healthcheck.sh" --format json
	[ "$status" -eq 0 ]
	json_ok "$output"
	jq -e '.failed == 0 and .total > 0' >/dev/null <<<"$output"
	[ -n "$stderr" ]
}

@test "the nvim vim editor fallback records exactly one passing result" {
	setup_sandbox
	run --separate-stderr env HOME="$SBHOME" PATH="$SBBIN" "$(command -v bash)" "$REPO_ROOT/scripts/healthcheck.sh" --format json
	[ "$status" -eq 0 ]
	json_ok "$output"
	jq -e '[.checks[] | select(.name == "Editor (nvim/vim)")] | length == 1' >/dev/null <<<"$output"
	jq -e '.checks[] | select(.name == "Editor (nvim/vim)" and .status == "pass")' >/dev/null <<<"$output"
}

@test "healthcheck json stays valid when a message carries a quote" {
	setup_sandbox
	env HOME="$SBHOME" "$(command -v git)" config --global user.name 'tester with "quotes" inside'
	run --separate-stderr env HOME="$SBHOME" PATH="$SBBIN" "$(command -v bash)" "$REPO_ROOT/scripts/healthcheck.sh" --format json
	[ "$status" -eq 0 ]
	json_ok "$output"
	jq -e '.checks[] | select(.message | contains("tester with"))' >/dev/null <<<"$output"
}
