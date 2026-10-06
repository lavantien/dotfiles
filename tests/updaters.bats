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

@test "update-all.sh installs gup from its real module path, never all@latest" {
	grep -q 'github.com/nao1215/gup@latest' "$REPO_ROOT/scripts/update-all.sh"
	if grep -q 'all@latest' "$REPO_ROOT/scripts/update-all.sh"; then
		fail "all@latest is an invalid module path, go install rejects it"
	fi
	# the go fallback only exists to bootstrap gup, gup update must not run twice
	[ "$(grep -v '^[[:space:]]*#' "$REPO_ROOT/scripts/update-all.sh" | grep -c 'gup update')" -le 2 ]
}

@test "update-all.ps1 installs gup from its real module path, never all@latest" {
	grep -q 'github.com/nao1215/gup@latest' "$REPO_ROOT/scripts/update-all.ps1"
	if grep -q 'all@latest' "$REPO_ROOT/scripts/update-all.ps1"; then
		fail "all@latest is an invalid module path, go install rejects it"
	fi
	[ "$(grep -v '^[[:space:]]*#' "$REPO_ROOT/scripts/update-all.ps1" | grep -c 'gup update')" -le 2 ]
}

@test "pip_install retries with --break-system-packages only on PEP 668 errors" {
	fakebin="$BATS_TEST_TMPDIR/pipbin"
	mkdir -p "$fakebin"
	log="$BATS_TEST_TMPDIR/pip.log"
	cat >"$fakebin/pip" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$log"
if [[ "\$*" == *--break-system-packages* ]]; then
	echo "installed with flag"
	exit 0
fi
echo "error: externally-managed-environment" >&2
echo "hint: PEP 668 blocks system package mutation" >&2
exit 1
EOF
	chmod +x "$fakebin/pip"
	# shellcheck disable=SC1091
	source "$REPO_ROOT/scripts/update-all.sh"
	run pip_install "$fakebin/pip" --upgrade --user requests
	[ "$status" -eq 0 ]
	[ "$(wc -l <"$log")" -eq 2 ]
	grep -q 'install --break-system-packages --upgrade --user requests' "$log"
}

@test "pip_install surfaces other pip errors without the PEP 668 retry" {
	fakebin="$BATS_TEST_TMPDIR/pipbin"
	mkdir -p "$fakebin"
	log="$BATS_TEST_TMPDIR/pip.log"
	cat >"$fakebin/pip" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$log"
echo "error: no space left on device" >&2
exit 2
EOF
	chmod +x "$fakebin/pip"
	# shellcheck disable=SC1091
	source "$REPO_ROOT/scripts/update-all.sh"
	run pip_install "$fakebin/pip" --upgrade pip
	[ "$status" -ne 0 ]
	[ "$(wc -l <"$log")" -eq 1 ]
	grep -q 'no space left on device' <<<"$output"
}

@test "pip_install keeps plain upgrades plain on pip older than 23" {
	fakebin="$BATS_TEST_TMPDIR/pipbin"
	mkdir -p "$fakebin"
	log="$BATS_TEST_TMPDIR/pip.log"
	cat >"$fakebin/pip" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$log"
echo "Requirement already satisfied"
exit 0
EOF
	chmod +x "$fakebin/pip"
	# shellcheck disable=SC1091
	source "$REPO_ROOT/scripts/update-all.sh"
	run pip_install "$fakebin/pip" --upgrade --user requests
	[ "$status" -eq 0 ]
	[ "$(wc -l <"$log")" -eq 1 ]
	if grep -q -- '--break-system-packages' "$log"; then
		fail "old pip has no --break-system-packages flag, it must never see it"
	fi
}
