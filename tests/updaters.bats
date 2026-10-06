#!/usr/bin/env bash
# Slot 2 updater contracts: gh-missing crash, gup module path, pip PEP 668
# retry, fetch-before-pull, and skip counting.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

@test "git-update-repos.sh reports a missing gh instead of crashing on unbound colors" {
	empty_bin="$BATS_TEST_TMPDIR/empty-bin"
	mkdir -p "$empty_bin"
	# absolute interpreter: env and the shebang would PATH-search an empty PATH
	run env PATH="$empty_bin" "$(command -v bash)" "$REPO_ROOT/scripts/git-update-repos.sh"
	[ "$status" -eq 1 ]
	grep -q 'gh) not found' <<<"$output"
	if grep -qi 'unbound variable' <<<"$output"; then
		fail "script died on unbound color variables: $output"
	fi
}
