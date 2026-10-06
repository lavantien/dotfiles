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
