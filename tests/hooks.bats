#!/usr/bin/env bash
# Hook behavior tests. Each test drives a real git commit in a throwaway
# repo whose core.hooksPath points at this repo's .config/git/hooks, never
# the live deployed set under ~/.config/git/hooks.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.config/git/hooks"
REPO=""

setup_hook_repo() {
	REPO="$(mktemp -d)"
	git -C "$REPO" init -q
	git -C "$REPO" config user.name "Hook Tester"
	git -C "$REPO" config user.email "hook-test@example.invalid"
	if command -v cygpath >/dev/null 2>&1; then
		git -C "$REPO" config core.hooksPath "$(cygpath -m "$HOOKS_DIR")"
	else
		git -C "$REPO" config core.hooksPath "$HOOKS_DIR"
	fi
	echo hi >"$REPO/file.txt"
	git -C "$REPO" add file.txt
}

teardown() {
	[ -z "$REPO" ] || rm -rf "$REPO"
}

# Total subject length $1 chars: "fix: " plus x padding.
subject_of_length() {
	local pad
	pad="$(printf '%*s' "$(( $1 - 5 ))" '' | tr ' ' x)"
	printf 'fix: %s' "$pad"
}

skip_unless_pwsh() {
	command -v pwsh >/dev/null 2>&1 || skip "pwsh not installed"
}

@test "commit-msg rejects a garbage subject" {
	setup_hook_repo
	run git -C "$REPO" commit -q -m "garbage message that no convention allows"
	[ "$status" -ne 0 ]
}

@test "commit-msg accepts a minimal fix subject" {
	setup_hook_repo
	run git -C "$REPO" commit -q -m "fix: ok"
	[ "$status" -eq 0 ]
}

@test "commit-msg rejects a 101 character subject" {
	setup_hook_repo
	local subject
	subject="$(subject_of_length 101)"
	[ "${#subject}" -eq 101 ]
	run git -C "$REPO" commit -q -m "$subject"
	[ "$status" -ne 0 ]
}

@test "commit-msg accepts a 100 character subject" {
	setup_hook_repo
	local subject
	subject="$(subject_of_length 100)"
	[ "${#subject}" -eq 100 ]
	run git -C "$REPO" commit -q -m "$subject"
	[ "$status" -eq 0 ]
}

@test "commit-msg keeps a subject of literally -n intact" {
	setup_hook_repo
	run git -C "$REPO" commit -q -m "-n"
	[ "$status" -ne 0 ]
	[[ "$output" == *"does not follow Conventional Commits"* ]]
	[[ "$output" != *"cannot be empty"* ]]
}

@test "commit-msg counts multibyte subjects in codepoints" {
	setup_hook_repo
	local pad bytes ok_subject over_subject
	pad="$(printf 'é%.0s' $(seq 95))"
	bytes="$(printf '%s' "$pad" | wc -c)"
	[ "$bytes" -eq 190 ] || { echo "setup: pad is $bytes bytes, want 190"; return 1; }
	ok_subject="fix: $pad"
	over_subject="fix: ${pad}é"
	run env LC_ALL=C git -C "$REPO" commit -q -m "$ok_subject"
	[ "$status" -eq 0 ]
	setup_hook_repo
	run env LC_ALL=C git -C "$REPO" commit -q -m "$over_subject"
	[ "$status" -ne 0 ]
}

@test "commit-msg accepts break and bump types" {
	setup_hook_repo
	run git -C "$REPO" commit -q -m "break: remove the legacy api"
	[ "$status" -eq 0 ]
	setup_hook_repo
	run git -C "$REPO" commit -q -m "bump: version 2.0.0"
	[ "$status" -eq 0 ]
}

@test "commit-msg rejects a conventional type buried after leading noise" {
	setup_hook_repo
	run git -C "$REPO" commit -q -m "noise before fix: ok"
	[ "$status" -ne 0 ]
}

@test "commit-msg strips the AI attribution trailer" {
	setup_hook_repo
	run git -C "$REPO" commit -q -m "fix: ok" -m "Co-Authored-By: Claude Code <noreply@anthropic.com>"
	[ "$status" -eq 0 ]
	run git -C "$REPO" log -1 --format=%B
	[[ "$output" != *"Co-Authored-By"* ]]
}

@test "commit-msg rejects a garbage subject over a Merge body line" {
	setup_hook_repo
	run git -C "$REPO" commit -q -m "garbage subject" -m "Merge branch 'feature'"
	[ "$status" -ne 0 ]
}

@test "commit-msg rejects a garbage subject over a Revert body line" {
	setup_hook_repo
	run git -C "$REPO" commit -q -m "garbage subject" -m 'Revert "fix: ok"'
	[ "$status" -ne 0 ]
}

@test "commit-msg strips attribution trailers from merge commits" {
	setup_hook_repo
	local base
	base="$(git -C "$REPO" symbolic-ref --short HEAD)"
	git -C "$REPO" commit -q -m "fix: seed the trunk"
	git -C "$REPO" checkout -q -b feature
	echo feature >"$REPO/feature.txt"
	git -C "$REPO" add feature.txt
	git -C "$REPO" commit -q -m "feat: feature work"
	git -C "$REPO" checkout -q "$base"
	run git -C "$REPO" merge --no-ff feature -m "Merge branch 'feature'

Co-Authored-By: Claude Code <noreply@anthropic.com>"
	[ "$status" -eq 0 ]
	run git -C "$REPO" log -1 --format=%B
	[[ "$output" != *"Co-Authored-By"* ]]
}

@test "pre-commit passes --no-install to every npx call" {
	setup_hook_repo
	echo '{}' >"$REPO/package.json"
	echo 'const ok = 1;' >"$REPO/clean.js"
	git -C "$REPO" add package.json clean.js
	local stubbin log
	stubbin="$(mktemp -d)"
	log="$stubbin/npx.log"
	: >"$log"
	printf '#!/usr/bin/env bash\nprintf %%s\\\\n "$*" >> "$NPX_LOG"\nexit 0\n' >"$stubbin/npx"
	chmod +x "$stubbin/npx"
	run env PATH="$stubbin:$PATH" NPX_LOG="$log" \
		git -C "$REPO" commit -q -m "fix: trigger node checks"
	[ "$status" -eq 0 ]
	[ -s "$log" ] || { echo "hook never invoked npx"; return 1; }
	local bad=""
	while IFS= read -r line; do
		case "$line" in
		--no-install\ *) ;;
		*) bad="$bad [$line]" ;;
		esac
	done <"$log"
	[ -z "$bad" ] || { echo "npx called without --no-install:$bad"; return 1; }
	rm -rf "$stubbin"
}

@test "quality-check run_tool passes only real tool arguments" {
	local tmp stubbin
	tmp="$(mktemp -d)"
	stubbin="$(mktemp -d)"
	for tool in shellcheck shfmt; do
		cat >"$stubbin/$tool" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$QC_LOG"
exit 0
STUB
	done
	chmod +x "$stubbin/shellcheck" "$stubbin/shfmt"
	printf '#!/usr/bin/env bash\necho ok\n' >"$tmp/sample.sh"
	run env QC_LOG="$tmp/qc.log" PATH="$stubbin:$PATH" \
		bash "$REPO_ROOT/.claude/quality-check.sh" "$tmp/sample.sh"
	[ "$status" -eq 0 ]
	[ -s "$tmp/qc.log" ] || { echo "no stubbed tool ran"; return 1; }
	# exact argv match catches display names leaking in as arguments
	grep -qx -F "$tmp/sample.sh" "$tmp/qc.log" || {
		echo "shellcheck argv wrong, expected exactly the file path"
		cat "$tmp/qc.log"
		return 1
	}
	grep -qx -F -- "-w $tmp/sample.sh" "$tmp/qc.log" || {
		echo "shfmt argv wrong, expected exactly: -w <file>"
		cat "$tmp/qc.log"
		return 1
	}
	rm -rf "$tmp" "$stubbin"
}

@test "pre-commit blocks shellcheck errors in staged shell files" {
	setup_hook_repo
	printf '#!/usr/bin/env bash\ncat $@\n' >"$REPO/bad.sh"
	git -C "$REPO" add bad.sh
	run git -C "$REPO" commit -q -m "fix: add script"
	[ "$status" -ne 0 ]
}

@test "pre-commit blocks shellcheck errors in a renamed and edited file" {
	setup_hook_repo
	printf '#!/usr/bin/env bash\necho hello\n' >"$REPO/old.sh"
	git -C "$REPO" add old.sh
	git -C "$REPO" commit -q -m "fix: add clean script"
	git -C "$REPO" mv old.sh moved.sh
	printf '#!/usr/bin/env bash\necho hello\ncat $@\n' >"$REPO/moved.sh"
	git -C "$REPO" add moved.sh
	run git -C "$REPO" commit -q -m "fix: rename and edit the script"
	[ "$status" -ne 0 ]
}

@test "pre-commit formats staged shell files with shfmt" {
	setup_hook_repo
	printf '#!/usr/bin/env bash\nif true;then echo hi;fi\n' >"$REPO/good.sh"
	git -C "$REPO" add good.sh
	run git -C "$REPO" commit -q -m "fix: add script"
	[ "$status" -eq 0 ]
	[ -z "$(shfmt -ln bash -d "$REPO/good.sh")" ] || {
		echo "staged file was not shfmt formatted:"
		shfmt -ln bash -d "$REPO/good.sh"
		return 1
	}
}

@test "pre-commit formats staged lua files with stylua" {
	setup_hook_repo
	printf 'local x=1\nprint(x)\n' >"$REPO/t.lua"
	git -C "$REPO" add t.lua
	run git -C "$REPO" commit -q -m "fix: add lua"
	[ "$status" -eq 0 ]
	grep -q 'local x = 1' "$REPO/t.lua" || {
		echo "staged lua file was not stylua formatted"
		return 1
	}
}

@test "absorbed checks skip cleanly when tools are missing" {
	setup_hook_repo
	# bad.sh would fail shellcheck, t.scala wants scalafmt, page.php wants
	# pint, s.ps1 wants PSScriptAnalyzer, none installed on a fresh machine
	printf '#!/usr/bin/env bash\ncat $@\n' >"$REPO/bad.sh"
	printf '// scala source\n' >"$REPO/t.scala"
	printf '<?php echo 1;\n' >"$REPO/page.php"
	printf 'Write-Host "ok"\n' >"$REPO/s.ps1"
	git -C "$REPO" add bad.sh t.scala page.php s.ps1
	local gitdir
	gitdir="$(dirname "$(command -v git)")"
	run env PATH="/usr/bin:$gitdir" git -C "$REPO" commit -q -m "fix: fresh machine commit"
	[ "$status" -eq 0 ]
}

@test "powershell analyzer probe skips when the module is absent" {
	setup_hook_repo
	skip_unless_pwsh
	printf 'Write-Host "ok"\n' >"$REPO/s.ps1"
	git -C "$REPO" add s.ps1
	run git -C "$REPO" commit -q -m "fix: add ps1"
	[ "$status" -eq 0 ]
}
