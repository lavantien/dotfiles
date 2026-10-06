#!/usr/bin/env bash
# Smoke checks over the tracked shell surface: parseability and presence.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

@test "every tracked .sh file parses with bash -n" {
	failed=()
	while IFS= read -r -d '' f; do
		bash -n "$REPO_ROOT/$f" || failed+=("$f")
	done < <(git -C "$REPO_ROOT" ls-files -z -- '*.sh')
	[ ${#failed[@]} -eq 0 ] || { echo "bash -n failed for: ${failed[*]}" >&3; return 1; }
}

@test "key lifecycle scripts and harness files exist" {
	for f in \
		Makefile \
		bootstrap/bootstrap.sh \
		scripts/deploy.sh \
		scripts/healthcheck.sh \
		scripts/backup.sh \
		scripts/restore.sh \
		scripts/uninstall.sh \
		scripts/update-all.sh \
		scripts/update.sh \
		tests/e2e/Dockerfile \
		tests/e2e/run.sh; do
		[ -f "$REPO_ROOT/$f" ]
	done
}

@test "make gate targets are declared" {
	for t in help baseline lint format test check e2e-linux e2e-windows; do
		grep -qE "^${t}:" "$REPO_ROOT/Makefile"
	done
}
