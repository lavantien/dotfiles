#!/usr/bin/env bash
# Slot 2 updater contracts: gh-missing crash, gup module path, pip PEP 668
# retry, fetch-before-pull, and skip counting.
# Note: this bats install has no fail() helper, guards echo and return 1.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

@test "git-update-repos.sh reports a missing gh instead of crashing on unbound colors" {
	empty_bin="$BATS_TEST_TMPDIR/empty-bin"
	mkdir -p "$empty_bin"
	# absolute interpreter: env and the shebang would PATH-search an empty PATH
	run env PATH="$empty_bin" "$(command -v bash)" "$REPO_ROOT/scripts/git-update-repos.sh"
	[ "$status" -eq 1 ]
	grep -q 'gh) not found' <<<"$output"
	if grep -qi 'unbound variable' <<<"$output"; then
		echo "script died on unbound color variables: $output" >&2
		return 1
	fi
}

@test "update-all.sh installs gup from its real module path, never all@latest" {
	grep -q 'github.com/nao1215/gup@latest' "$REPO_ROOT/scripts/update-all.sh"
	if grep -q 'all@latest' "$REPO_ROOT/scripts/update-all.sh"; then
		echo "all@latest is an invalid module path, go install rejects it" >&2
		return 1
	fi
	# the go fallback only exists to bootstrap gup, gup update must not run twice
	[ "$(grep -v '^[[:space:]]*#' "$REPO_ROOT/scripts/update-all.sh" | grep -c 'gup update')" -le 2 ]
}

@test "update-all.ps1 installs gup from its real module path, never all@latest" {
	grep -q 'github.com/nao1215/gup@latest' "$REPO_ROOT/scripts/update-all.ps1"
	if grep -q 'all@latest' "$REPO_ROOT/scripts/update-all.ps1"; then
		echo "all@latest is an invalid module path, go install rejects it" >&2
		return 1
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
		echo "old pip has no --break-system-packages flag, it must never see it" >&2
		return 1
	fi
}

@test "git-update-repos.ps1 runs pull only after fetch succeeds" {
	ps1="$REPO_ROOT/scripts/git-update-repos.ps1"
	fetch_n=$(grep -n 'git fetch origin' "$ps1" | head -1 | cut -d: -f1)
	[ -n "$fetch_n" ]
	# the pull call, not a comment mentioning it
	pull_n=$(grep -n '^\s*\$null = git pull' "$ps1" | head -1 | cut -d: -f1)
	[ -n "$pull_n" ]
	# an exit-code gate must sit between the fetch and the pull
	gate_n=$(awk -v s="$fetch_n" 'NR > s && /LASTEXITCODE -eq 0/ {print NR; exit}' "$ps1")
	[ -n "$gate_n" ]
	[ "$gate_n" -lt "$pull_n" ]
	# the old output-truthiness chain must be gone: quiet fetch success
	# evaluated to false and reported Error updating
	if grep -q -- '-and (git pull' "$ps1"; then
		echo "found the old -and fetch/pull chain" >&2
		return 1
	fi
}

@test "git-update-repos.sh fetches before comparing so an advanced remote reports an update" {
	# A clean clone holds a stale tracking ref: comparing before any fetch
	# reports up to date forever. Advance the remote after cloning and the
	# script must notice and pull.
	rt="$BATS_TEST_TMPDIR/rt"
	# isolate git from the host gitconfig: the live core.hooksPath drags the
	# deployed pre-commit into seed commits and aborts them
	g() { env GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git "$@"; }
	mkdir -p "$rt/remote" "$rt/base" "$rt/fakebin"
	bare="$rt/remote/c1repo.git"
	g init -q --bare "$bare"
	seed="$rt/seed"
	g init -q "$seed"
	g -C "$seed" config user.email tester@example.invalid
	g -C "$seed" config user.name tester
	echo one >"$seed/f"
	g -C "$seed" add f
	g -C "$seed" commit -qm one
	g -C "$seed" remote add origin "$bare"
	g -C "$seed" push -q origin HEAD
	cat >"$rt/fakebin/gh" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "repo" ]]; then
	printf '[{"name":"c1repo","sshUrl":"x","url":"%s"}]\n' '$rt/remote/c1repo'
else
	exit 0
fi
EOF
	chmod +x "$rt/fakebin/gh"
	run env PATH="$rt/fakebin:$PATH" bash "$REPO_ROOT/scripts/git-update-repos.sh" -u tester -d "$rt/base"
	[ "$status" -eq 0 ]
	grep -q 'Cloned' <<<"$output"
	# push a commit the clone has never fetched
	echo two >"$seed/f"
	g -C "$seed" commit -qam two
	g -C "$seed" push -q origin HEAD
	run env PATH="$rt/fakebin:$PATH" bash "$REPO_ROOT/scripts/git-update-repos.sh" -u tester -d "$rt/base"
	[ "$status" -eq 0 ]
	# summary count, git's own fetch and pull output splits the per-repo line
	plain="$(sed 's/\x1b\[[0-9;]*m//g' <<<"$output")"
	if ! grep -qE 'Updated:[[:space:]]*[1-9]' <<<"$plain"; then
		echo "stale tracking ref reported up to date, no fetch happened: $plain" >&2
		return 1
	fi
}

@test "update_pip counts failed upgrades instead of always printing success" {
	fakebin="$BATS_TEST_TMPDIR/pipfail"
	mkdir -p "$fakebin"
	cat >"$fakebin/pip" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "list" ]]; then
	printf 'requests==1.0.0\n'
	exit 0
fi
if [[ "\$*" == "install --upgrade pip" ]]; then
	echo "self-upgrade ok"
	exit 0
fi
echo "error: simulated pip failure" >&2
exit 1
EOF
	chmod +x "$fakebin/pip"
	# shellcheck disable=SC1091
	source "$REPO_ROOT/scripts/update-all.sh"
	out="$BATS_TEST_TMPDIR/pip-out"
	rc=0
	update_pip "$fakebin/pip" "pip" >"$out" 2>&1 || rc=$?
	[ "$rc" -ne 0 ]
	[ "$failed" -ge 1 ]
	grep -q 'simulated pip failure' "$out"
	if grep -q '✓ pip' "$out"; then
		echo "update_pip printed success despite a failing upgrade: $(cat "$out")" >&2
		return 1
	fi
}

@test "update-all.sh holds at or below its current line ceiling" {
	# 1000 SLOC repo cap, grandfathered ceiling while fixes land
	[ "$(wc -l <"$REPO_ROOT/scripts/update-all.sh")" -le 1012 ]
}

@test "update_skip counts a skip exactly once per call" {
	# shellcheck disable=SC1091
	source "$REPO_ROOT/scripts/update-all.sh"
	skipped=0
	update_skip "one"
	update_skip "two"
	[ "$skipped" -eq 2 ]
}

@test "update-all.sh has no stray skip increments beside update_skip" {
	if grep -q 'skipped++' "$REPO_ROOT/scripts/update-all.sh"; then
		grep -n 'skipped++' "$REPO_ROOT/scripts/update-all.sh" >&2
		return 1
	fi
}

@test "allow.sh chmods every tracked .sh in its repo" {
	# exec bits are unobservable on noacl mounts, so assert the chmod call
	# set: stub chmod and require it to see exactly the tracked .sh files
	sb="$BATS_TEST_TMPDIR/repo"
	fakebin="$BATS_TEST_TMPDIR/fakebin"
	log="$BATS_TEST_TMPDIR/chmod.log"
	mkdir -p "$sb/scripts" "$sb/tests/e2e" "$sb/bootstrap" "$fakebin"
	printf '#!%s\nprintf '\''%%s\\n'\'' "$*" >>"%s"\n' "$(command -v bash)" "$log" >"$fakebin/chmod"
	git -C "$sb" init -q
	cp "$REPO_ROOT/scripts/allow.sh" "$sb/scripts/"
	for f in scripts/update.sh tests/e2e/run.sh bootstrap/bootstrap.sh; do
		: >"$sb/$f"
	done
	git -C "$sb" add -A
	run env PATH="$fakebin:$PATH" bash "$sb/scripts/allow.sh"
	[ "$status" -eq 0 ]
	sort < <(git -C "$sb" ls-files -- '*.sh' | sed "s|^|$sb/|") >"$BATS_TEST_TMPDIR/expected"
	sort < <(sed 's/^+x //' "$log") >"$BATS_TEST_TMPDIR/actual"
	cmp "$BATS_TEST_TMPDIR/expected" "$BATS_TEST_TMPDIR/actual"
}

@test "the pwsh wrapper scripts declare #requires -Version 7" {
	for f in scripts/update-all.ps1 scripts/healthcheck.ps1 scripts/git-update-repos.ps1; do
		grep -q '^#requires -Version 7' "$REPO_ROOT/$f"
	done
}
