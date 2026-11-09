#!/usr/bin/env bash

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

ps1_section() {
	awk -v s="Write-Step \"$2" '
		/^ *Write-Step "/ {
			if (grab) { exit }
			grab = index($0, s) > 0
			next
		}
		grab { print }
	' "$1"
}

gate_leads_to_success() {
	awk -v g="$2" '
		index($0, g) > 0 {
			found = 1
			nxt = ""
			while ((getline nxt) > 0 && nxt ~ /^[[:space:]]*$/) { }
			if (nxt !~ /Write-Success/) { bad = 1 }
		}
		END { exit ((found && !bad) ? 0 : 1) }
	' <<<"$1"
}

@test "git-update-repos.sh reports a missing gh instead of crashing on unbound colors" {
	empty_bin="$BATS_TEST_TMPDIR/empty-bin"
	mkdir -p "$empty_bin"
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

@test "dotnet tool list and update always run in global scope" {
	for f in scripts/update-all.sh scripts/update-all.ps1; do
		grep -qE '(^|[[:space:]]|=[[:space:]]|\()dotnet tool list --global' "$REPO_ROOT/$f"
		grep -qE '(^|[[:space:]]|=[[:space:]]|\()dotnet tool update --global' "$REPO_ROOT/$f"
		if grep -E '(^|[[:space:]]|=[[:space:]]|\()dotnet tool (list|update)' "$REPO_ROOT/$f" | grep -v -- '--global' | grep -q .; then
			echo "a dotnet tool call without --global resolves to the local manifest scope" >&2
			return 1
		fi
	done
	grep -qF 'dotnet tool update --global "$tool"' "$REPO_ROOT/scripts/update-all.sh"
	grep -qF 'dotnet tool update --global $toolName' "$REPO_ROOT/scripts/update-all.ps1"
}

@test "update-all.ps1 elevates the whole winget batch once instead of per upgrade" {
	ps1="$REPO_ROOT/scripts/update-all.ps1"
	grep -q 'WindowsBuiltInRole]::Administrator' "$ps1"
	grep -q -- '-Verb RunAs' "$ps1"
	[ "$(grep -c 'WingetBatch' "$ps1")" -ge 2 ]
	[ "$(grep -c "'upgrade', '--all'" "$ps1")" -eq 1 ]
	if grep -qE '& \$wingetExe upgrade' "$ps1"; then
		echo "a direct winget upgrade call bypasses the elevated batch" >&2
		return 1
	fi
}

@test "update-all.ps1 gates the run on free disk space before the first manager" {
	ps1="$REPO_ROOT/scripts/update-all.ps1"
	grep -q '^\$MinFreeSpaceGB = 10$' "$ps1"
	grep -q 'function Test-DiskSpace' "$ps1"
	gate_n=$(grep -nF 'if (-not (Test-DiskSpace))' "$ps1" | head -1 | cut -d: -f1)
	[ -n "$gate_n" ]
	scoop_n=$(grep -nF 'Write-Step "SCOOP"' "$ps1" | head -1 | cut -d: -f1)
	[ -n "$scoop_n" ]
	[ "$gate_n" -lt "$scoop_n" ]
	probe="$BATS_TEST_TMPDIR/gate-probe.ps1"
	cat >"$probe" <<'PROBE'
$ErrorActionPreference = 'Stop'
$src = Get-Content -Raw $env:PS1_PATH
$errs = $null
$ast = [System.Management.Automation.Language.Parser]::ParseInput($src, [ref]$null, [ref]$errs)
if ($errs.Count -gt 0) {
	Write-Output 'parse-errors'
	exit 1
}
$funcs = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
$defs = @{}
foreach ($name in @('Get-UpdateDriveRoots', 'Test-DiskSpace')) {
	$def = $funcs | Where-Object { $_.Name -eq $name } | Select-Object -First 1
	if (-not $def) {
		Write-Output "missing:$name"
		exit 1
	}
	$defs[$name] = $def.Extent.Text
}
function Get-PSDrive {
	[CmdletBinding()]
	param([string]$Name)
	[pscustomobject]@{ Free = [long]$env:PROBE_FREE_BYTES }
}
$MinFreeSpaceGB = 10
Invoke-Expression $defs['Get-UpdateDriveRoots']
Invoke-Expression $defs['Test-DiskSpace']
$env:PROBE_FREE_BYTES = '5368709120'
Write-Output "low:$(-not (Test-DiskSpace))"
$env:PROBE_FREE_BYTES = '536870912000'
Write-Output "ample:$(Test-DiskSpace)"
PROBE
	out="$(PS1_PATH="$ps1" TEMP='C:\probe-temp' USERPROFILE='C:\probe-home' pwsh -NoProfile -File "$probe" 2>&1)"
	grep -q '^low:True$' <<<"$out"
	grep -q '^ample:True$' <<<"$out"
}

@test "update-all.ps1 explains the winget upgrade --all aggregate failure code" {
	ps1="$REPO_ROOT/scripts/update-all.ps1"
	grep -q '^\$WingetExitNotes = @{' "$ps1"
	grep -qF -- "-1978335188 = 'upgrade --all completed with failures'" "$ps1"
	[ "$(grep -cF -- '-1978335188' "$ps1")" -eq 1 ]
	grep -qF '$note = $WingetExitNotes[$result.Code]' "$ps1"
	grep -qF 'if ($note) {' "$ps1"
}

@test "update-all.ps1 decides every manager section on LASTEXITCODE" {
	ps1="$REPO_ROOT/scripts/update-all.ps1"
	for section in SCOOP CHOCOLATEY NPM PNPM BUN YARN GUP CARGO RUSTUP POETRY UV PIP; do
		slice="$(ps1_section "$ps1" "$section")"
		if [ -z "$slice" ]; then
			echo "section $section not found in update-all.ps1" >&2
			return 1
		fi
		if ! grep -q 'LASTEXITCODE' <<<"$slice"; then
			echo "section $section never checks \$LASTEXITCODE" >&2
			return 1
		fi
	done
}

@test "update-all.ps1 counts failed pip upgrades instead of always printing success" {
	ps1="$REPO_ROOT/scripts/update-all.ps1"
	slice="$(ps1_section "$ps1" PIP)"
	grep -q 'failedPackages' <<<"$slice"
	grep -q 'LASTEXITCODE' <<<"$slice"
	grep -qF 'pip (failed: $($failedPackages -join' <<<"$slice"
}

@test "update-all.ps1 npm and pip verdicts need every command to succeed" {
	ps1="$REPO_ROOT/scripts/update-all.ps1"
	npm_slice="$(ps1_section "$ps1" NPM)"
	grep -qF 'if ($npmSelf -eq 0 -and $LASTEXITCODE -eq 0) {' <<<"$npm_slice"
	pip_slice="$(ps1_section "$ps1" PIP)"
	grep -qF 'if ($pipSelf -eq 0 -and $freezeOk -and $failedPackages.Count -eq 0) {' <<<"$pip_slice"
}

@test "update-all.ps1 prints success only on the success side of each exit-code gate" {
	ps1="$REPO_ROOT/scripts/update-all.ps1"
	for section in SCOOP CHOCOLATEY PNPM YARN GUP CARGO RUSTUP POETRY UV; do
		slice="$(ps1_section "$ps1" "$section")"
		[ -n "$slice" ]
		if ! gate_leads_to_success "$slice" 'if ($LASTEXITCODE -eq 0) {'; then
			echo "section $section does not follow its exit-code gate with Write-Success" >&2
			return 1
		fi
	done
	if ! gate_leads_to_success "$(ps1_section "$ps1" BUN)" 'if ($bunOk) {'; then
		echo "BUN does not follow its gate with Write-Success" >&2
		return 1
	fi
	if ! gate_leads_to_success "$(ps1_section "$ps1" NPM)" 'if ($npmSelf -eq 0'; then
		echo "NPM does not follow its gate with Write-Success" >&2
		return 1
	fi
	if ! gate_leads_to_success "$(ps1_section "$ps1" PIP)" 'if ($pipSelf -eq 0'; then
		echo "PIP does not follow its gate with Write-Success" >&2
		return 1
	fi
}

@test "update-all.ps1 treats winget outcomes without a result marker as failed" {
	ps1="$REPO_ROOT/scripts/update-all.ps1"
	if grep -qF 'Code = $proc.ExitCode' "$ps1"; then
		echo "the elevated child always exits 0, padding with its exit code fakes success" >&2
		return 1
	fi
	grep -qF 'Code = -1' "$ps1"
	grep -qF 'no result marker in the elevated log, treating this command as failed' "$ps1"
}

@test "update-all.ps1 gates the bun section on the package listing exit code" {
	ps1="$REPO_ROOT/scripts/update-all.ps1"
	slice="$(ps1_section "$ps1" BUN)"
	grep -qF '$pmLs = $LASTEXITCODE' <<<"$slice"
	grep -qE '\$pmLs -ne 0' <<<"$slice"
}

@test "update-all.ps1 carries no Invoke-Expression and no dead Invoke-Command helper" {
	if grep -nE 'Invoke-(Command|Expression)' "$REPO_ROOT/scripts/update-all.ps1"; then
		echo "Invoke-Command and Invoke-Expression hide exit codes" >&2
		return 1
	fi
}

@test "update-all.ps1 holds at or below the 1000 line ceiling" {
	[ "$(wc -l <"$REPO_ROOT/scripts/update-all.ps1")" -le 1000 ]
}

@test "update-all.ps1 and updaters.bats carry no prose comments" {
	ps1="$REPO_ROOT/scripts/update-all.ps1"
	for f in "$ps1" "$BATS_TEST_FILENAME"; do
		if grep '^#' "$f" | grep -vE '^(#!|[[:space:]]*# shellcheck|#requires)' | grep -q .; then
			grep '^#' "$f" | grep -vE '^(#!|[[:space:]]*# shellcheck|#requires)' >&2
			return 1
		fi
		hits="$(grep -nE '(^|[[:space:]])#([[:space:]]|$)' "$f" | grep -vE '^[0-9]+:[[:space:]]*#(!| shellcheck|requires)' || true)"
		if [ -n "$hits" ]; then
			echo "$hits" >&2
			return 1
		fi
	done
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
	pull_n=$(grep -n '^\s*\$null = git pull' "$ps1" | head -1 | cut -d: -f1)
	[ -n "$pull_n" ]
	gate_n=$(awk -v s="$fetch_n" 'NR > s && /LASTEXITCODE -eq 0/ {print NR; exit}' "$ps1")
	[ -n "$gate_n" ]
	[ "$gate_n" -lt "$pull_n" ]
	if grep -q -- '-and (git pull' "$ps1"; then
		echo "found the old -and fetch/pull chain" >&2
		return 1
	fi
}

@test "git-update-repos.sh fetches before comparing so an advanced remote reports an update" {
	rt="$BATS_TEST_TMPDIR/rt"
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
	echo two >"$seed/f"
	g -C "$seed" commit -qam two
	g -C "$seed" push -q origin HEAD
	run env PATH="$rt/fakebin:$PATH" bash "$REPO_ROOT/scripts/git-update-repos.sh" -u tester -d "$rt/base"
	[ "$status" -eq 0 ]
	if grep -q 'Skipped (already up to date)' <<<"$output"; then
		echo "stale tracking ref reported up to date, no fetch happened: $output" >&2
		return 1
	fi
	[ "$(g -C "$rt/base/c1repo" rev-parse HEAD)" = "$(g -C "$seed" rev-parse HEAD)" ]
	grep -q two "$rt/base/c1repo/f"
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

@test "update-all.sh never calls the undefined log_info helper" {
	if grep -n 'log_info' "$REPO_ROOT/scripts/update-all.sh"; then
		echo "log_info is undefined in update-all.sh, use the file's own echo idiom" >&2
		return 1
	fi
}

@test "update-all.sh holds at or below its current line ceiling" {
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

@test "make e2e-linux wraps the docker info guard in a timeout" {
	if ! grep -qE 'timeout( -k [0-9]+ )?[0-9]+ docker info' "$REPO_ROOT/Makefile"; then
		echo "a wedged daemon would block make e2e-linux forever" >&2
		return 1
	fi
}

@test "make e2e-linux degrades to the skip when the docker daemon hangs" {
	fakebin="$BATS_TEST_TMPDIR/hangbin"
	mkdir -p "$fakebin"
	printf '#!%s\nsleep 15\n' "$(command -v bash)" >"$fakebin/docker"
	chmod +x "$fakebin/docker"
	run env PATH="$fakebin:$PATH" make e2e-linux
	[ "$status" -eq 0 ]
	if ! grep -q 'skip: docker daemon' <<<"$output"; then
		echo "wedged daemon did not degrade to the documented skip: $output" >&2
		return 1
	fi
}
