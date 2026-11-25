#!/usr/bin/env bash

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.config/git/hooks"
REPO=""

setup_hook_repo() {
	[ -z "$REPO" ] || rm -rf "$REPO"
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

subject_of_length() {
	local pad
	pad="$(printf '%*s' "$(( $1 - 5 ))" '' | tr ' ' x)"
	printf 'fix: %s' "$pad"
}

skip_unless_pwsh() {
	command -v pwsh >/dev/null 2>&1 || skip "pwsh not installed"
}

assert_summary_reached() {
	[[ "$output" == *"Pre-commit checks failed"* ]] || {
		echo "the hook stopped before its summary:"
		printf '%s\n' "$output"
		return 1
	}
}

commit_with_stubbed_tools() {
	local gitdir
	gitdir="$(dirname "$(command -v git)")"
	env PATH="$1:/usr/bin:$gitdir" git -C "$REPO" commit -q -m "fix: run the hook with stubbed tools"
}

comment_lines() {
	awk '
		{
			line = $0
			for (i = 1; i <= length(line); i++) {
				c = substr(line, i, 1)
				if (quote == "\047") {
					if (c == "\047") quote = ""
				} else if (quote == "\042") {
					if (c == "\\") i++
					else if (c == "\042") quote = ""
				} else if (c == "\047" || c == "\042") {
					quote = c
				} else if (c == "\\") {
					i++
				} else if (c == "#" && !(FNR == 1 && i == 1 && substr(line, 2, 1) == "!") && (i == 1 || substr(line, i - 1, 1) ~ /[ \t;()&|<>]/)) {
					print FNR ":" line
					next
				}
			}
		}' "$1"
}

write_formatter_stub() {
	mkdir -p "$1"
	printf '%s\n' \
		'#!/usr/bin/env bash' \
		'name="${0##*/}"' \
		'check=0' \
		'if [ "$name" = ruff ]; then' \
		'	[ "$1" = format ] || exit 0' \
		'	shift' \
		'elif [ "$1" = --check ] || [ "$1" = --check-only ]; then' \
		'	check=1' \
		'fi' \
		'for arg in "$@"; do' \
		'	if [ "$arg" = -- ]; then' \
		'		list=1' \
		'	elif [ -n "$list" ]; then' \
		'		files+=("$arg")' \
		'	elif [ "$arg" != --check ] && [ "$arg" != --check-only ]; then' \
		'		echo "stub $name received $arg before --" >&2' \
		'		exit 3' \
		'	fi' \
		'done' \
		'for f in "${files[@]}"; do' \
		'	if [ "$check" = 1 ]; then' \
		'		grep -q "^$name = 1$" "$f" || exit 1' \
		'	else' \
		'		[ -z "$STUB_FAIL" ] || exit 2' \
		'		printf "%s = 1\\n" "$name" >>"$f"' \
		'	fi' \
		'done' \
		>"$1/$2"
	chmod +x "$1/$2"
}

assert_fallback_failure_blocks() {
	local tool=$1 message=$2 stubbin
	setup_hook_repo
	: >"$REPO/requirements.txt"
	printf 'print("hi")\n' >"$REPO/app.py"
	git -C "$REPO" add app.py
	stubbin="$BATS_TEST_TMPDIR/fmtbin-$tool"
	write_formatter_stub "$stubbin" "$tool"
	export STUB_FAIL=1
	run commit_with_stubbed_tools "$stubbin"
	[ "$status" -ne 0 ] || { echo "the commit passed although $tool failed"; false; }
	[[ "$output" == *"$message"* ]] || {
		echo "the hook did not report: $message"
		printf '%s\n' "$output"
		return 1
	}
	assert_summary_reached
}

@test "tracked hook files carry the executable bit" {
	local mode
	mode="$(git -C "$REPO_ROOT" ls-files -s .config/git/hooks/pre-commit | awk '{print $1}')"
	[ "$mode" = "100755" ] || { echo "pre-commit index mode is $mode, want 100755"; return 1; }
	mode="$(git -C "$REPO_ROOT" ls-files -s .config/git/hooks/commit-msg | awk '{print $1}')"
	[ "$mode" = "100755" ] || { echo "commit-msg index mode is $mode, want 100755"; return 1; }
}

@test "setup_hook_repo removes the repo it replaces" {
	local first
	setup_hook_repo
	first="$REPO"
	setup_hook_repo
	[ ! -d "$first" ] || { echo "the first repo is still on disk: $first"; return 1; }
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
		printf '%s\n' \
			'#!/usr/bin/env bash' \
			'printf "%s\n" "$*" >> "$QC_LOG"' \
			'exit 0' \
			>"$stubbin/$tool"
	done
	chmod +x "$stubbin/shellcheck" "$stubbin/shfmt"
	printf '#!/usr/bin/env bash\necho ok\n' >"$tmp/sample.sh"
	run env QC_LOG="$tmp/qc.log" PATH="$stubbin:$PATH" \
		bash "$REPO_ROOT/.claude/quality-check.sh" "$tmp/sample.sh"
	[ "$status" -eq 0 ]
	[ -s "$tmp/qc.log" ] || { echo "no stubbed tool ran"; return 1; }
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

@test "pre-commit skips cargo gates for staged rust files with no manifest" {
	setup_hook_repo
	printf 'fn main() {}\n' >"$REPO/notebook.rs"
	git -C "$REPO" add notebook.rs
	local stubbin
	stubbin="$(mktemp -d)"
	printf '#!/usr/bin/env bash\necho cargo must not run >&2\nexit 99\n' >"$stubbin/cargo"
	chmod +x "$stubbin/cargo"
	run env PATH="$stubbin:$PATH" git -C "$REPO" commit -q -m "fix: add teaching rust"
	[ "$status" -eq 0 ]
	rm -rf "$stubbin"
}

@test "pre-commit runs cargo check inside the nearest manifest" {
	command -v cargo >/dev/null 2>&1 || skip "cargo not installed"
	setup_hook_repo
	mkdir -p "$REPO/crate/src"
	cat >"$REPO/crate/Cargo.toml" <<'EOF'
[package]
name = "hookprobe"
version = "0.1.0"
edition = "2021"
EOF
	printf 'fn main( {}\n' >"$REPO/crate/src/main.rs"
	git -C "$REPO" add crate
	run git -C "$REPO" commit -q -m "fix: add broken crate"
	[ "$status" -ne 0 ]
	[[ "$output" == *"Cargo check failed (crate)."* ]] || {
		echo "commit failed without the manifest-scoped cargo check message"
		return 1
	}
}

@test "absorbed checks skip cleanly when tools are missing" {
	setup_hook_repo
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

@test "pre-commit omits the spell check header when nothing is staged" {
	setup_hook_repo
	git -C "$REPO" commit -q -m "fix: seed the trunk"
	run git -C "$REPO" commit -q --allow-empty -m "chore: empty"
	[ "$status" -eq 0 ]
	[[ "$output" != *"Spell check"* ]]
}

@test "powershell analyzer probe skips when the module is absent" {
	setup_hook_repo
	skip_unless_pwsh
	printf 'Write-Host "ok"\n' >"$REPO/s.ps1"
	git -C "$REPO" add s.ps1
	run git -C "$REPO" commit -q -m "fix: add ps1"
	[ "$status" -eq 0 ]
}

@test "pre-commit never passes pyproject.toml to the python tools" {
	setup_hook_repo
	printf '[project]\nname = "probe"\n' >"$REPO/pyproject.toml"
	printf 'print("hi")\n' >"$REPO/app.py"
	git -C "$REPO" add pyproject.toml app.py
	local stubbin log tool
	stubbin="$BATS_TEST_TMPDIR/pybin"
	mkdir -p "$stubbin"
	log="$BATS_TEST_TMPDIR/py.log"
	: >"$log"
	for tool in ruff black isort mypy; do
		printf '#!/usr/bin/env bash\nprintf %%s\\\\n "%s $*" >> "$PY_LOG"\nexit 0\n' "$tool" >"$stubbin/$tool"
		chmod +x "$stubbin/$tool"
	done
	export PY_LOG="$log"
	run commit_with_stubbed_tools "$stubbin"
	[ "$status" -eq 0 ] || { echo "exit $status: $output"; false; }
	[ -s "$log" ] || { echo "hook never invoked a python tool"; return 1; }
	if grep -q 'pyproject.toml' "$log"; then
		echo "a python tool received the manifest:"
		cat "$log"
		return 1
	fi
	grep -qx 'ruff check --no-fix -- app.py' "$log" || { echo "ruff never received the python file after --:"; cat "$log"; return 1; }
	grep -qx 'ruff format -- app.py' "$log" || { echo "ruff format never received the python file after --:"; cat "$log"; return 1; }
	grep -qx 'mypy -- app.py' "$log" || { echo "mypy never received the python file after --:"; cat "$log"; return 1; }
}

@test "pre-commit stages the files that ruff check --fix rewrote" {
	command -v ruff >/dev/null 2>&1 || skip "ruff not installed"
	setup_hook_repo
	: >"$REPO/requirements.txt"
	printf 'import sys\nimport os\n\n\ndef main():\n    print("hi")\n    sys.exit(0)\n' >"$REPO/app.py"
	git -C "$REPO" add app.py
	run git -C "$REPO" commit -q -m "fix: stage an unused import"
	[ "$status" -eq 0 ] || { echo "exit $status: $output"; false; }
	run git -C "$REPO" show HEAD:app.py
	if [[ "$output" == *"import os"* ]]; then
		echo "the committed file still holds the unused import:"
		printf '%s\n' "$output"
		return 1
	fi
	run git -C "$REPO" status --porcelain -- app.py
	[ -z "$output" ] || { echo "the hook left the ruff fix unstaged: $output"; return 1; }
}

@test "pre-commit blocks the commit when ruff errors remain after the fix" {
	command -v ruff >/dev/null 2>&1 || skip "ruff not installed"
	setup_hook_repo
	: >"$REPO/requirements.txt"
	printf 'import sys\nimport os\n\n\ndef main():\n    print(missing)\n    sys.exit(0)\n' >"$REPO/app.py"
	git -C "$REPO" add app.py
	run git -C "$REPO" commit -q -m "fix: stage a fixable and an unfixable ruff error"
	[ "$status" -ne 0 ] || { echo "the commit passed with a remaining ruff error"; false; }
	[[ "$output" == *"Ruff found errors in staged python files"* ]] || {
		echo "the hook failed without naming the ruff errors:"
		printf '%s\n' "$output"
		return 1
	}
	run git -C "$REPO" show :app.py
	[[ "$output" != *"import os"* ]] || { echo "the index does not hold the ruff fix"; return 1; }
}

@test "pre-commit commits a formatted file after ruff check --fix rewrote it" {
	command -v ruff >/dev/null 2>&1 || skip "ruff not installed"
	setup_hook_repo
	: >"$REPO/requirements.txt"
	printf 'import os\n\n\ndef main():\n    print("hi")\n' >"$REPO/app.py"
	git -C "$REPO" add app.py
	run git -C "$REPO" commit -q -m "fix: stage an unused import"
	[ "$status" -eq 0 ] || { echo "exit $status: $output"; false; }
	run git -C "$REPO" show HEAD:app.py
	[[ "$output" == "def main():"* ]] || {
		echo "the committed file does not start at its first statement:"
		printf '%s\n' "$output"
		return 1
	}
}

@test "pre-commit leaves an unstaged edit out of a blocked commit" {
	command -v ruff >/dev/null 2>&1 || skip "ruff not installed"
	setup_hook_repo
	: >"$REPO/requirements.txt"
	git -C "$REPO" commit -q -m "fix: seed the trunk"
	printf 'def main():\n    print(missing)\n' >"$REPO/app.py"
	git -C "$REPO" add app.py
	printf 'UNSTAGED = 1\n' >>"$REPO/app.py"
	run git -C "$REPO" commit -q -m "fix: stage an unfixable error and keep an edit unstaged"
	[ "$status" -ne 0 ] || { echo "the commit passed with a remaining ruff error"; false; }
	[[ "$output" == *"Ruff found errors in staged python files"* ]] || {
		echo "the hook blocked the commit without running the ruff fix:"
		printf '%s\n' "$output"
		return 1
	}
	run git -C "$REPO" show :app.py
	[[ "$output" != *"UNSTAGED"* ]] || { echo "the blocked commit staged an edit that was never staged"; return 1; }
	run git -C "$REPO" diff -- app.py
	[[ "$output" == *"UNSTAGED"* ]] || { echo "the unstaged edit is no longer unstaged"; return 1; }
}

@test "pre-commit stages only the file that the ruff fix rewrote" {
	command -v ruff >/dev/null 2>&1 || skip "ruff not installed"
	setup_hook_repo
	: >"$REPO/requirements.txt"
	printf 'print("clean")\n' >"$REPO/a.py"
	git -C "$REPO" add a.py
	printf 'UNSTAGED = 1\n' >>"$REPO/a.py"
	printf 'import os\n\n\ndef main():\n    print("hi")\n' >"$REPO/b.py"
	git -C "$REPO" add b.py
	run git -C "$REPO" commit -q -m "fix: stage a clean file with an unstaged edit and a file with an unused import"
	[ "$status" -eq 0 ] || { echo "exit $status: $output"; false; }
	run git -C "$REPO" show HEAD:a.py
	[[ "$output" != *"UNSTAGED"* ]] || { echo "the commit holds an edit that was never staged"; return 1; }
	run git -C "$REPO" show HEAD:b.py
	[[ "$output" != *"import os"* ]] || { echo "the committed file still holds the unused import"; return 1; }
	run git -C "$REPO" diff --name-only
	[[ "$output" == *"a.py"* ]] || { echo "the unstaged edit on a.py is gone: $output"; return 1; }
}

@test "pre-commit blocks a commit when ruff fixes a file that holds unstaged edits" {
	command -v ruff >/dev/null 2>&1 || skip "ruff not installed"
	setup_hook_repo
	: >"$REPO/requirements.txt"
	printf 'import os\n\n\ndef main():\n    print("hi")\n' >"$REPO/app.py"
	git -C "$REPO" add app.py
	printf 'UNSTAGED = 1\n' >>"$REPO/app.py"
	run git -C "$REPO" commit -q -m "fix: stage an unused import and keep an edit unstaged"
	[ "$status" -ne 0 ] || { echo "the commit passed although ruff fixed a file with unstaged edits"; false; }
	[[ "$output" == *"unstaged edits"* ]] || {
		echo "the hook did not name the unstaged edits:"
		printf '%s\n' "$output"
		return 1
	}
	run git -C "$REPO" show :app.py
	[[ "$output" == *"import os"* ]] || { echo "the index lost its staged content"; return 1; }
}

@test "pre-commit stages the ruff fix when the project config turns fixing on" {
	command -v ruff >/dev/null 2>&1 || skip "ruff not installed"
	setup_hook_repo
	printf '[tool.ruff]\nfix = true\n' >"$REPO/pyproject.toml"
	printf 'import sys\nimport os\n\n\ndef main():\n    print("hi")\n    sys.exit(0)\n' >"$REPO/app.py"
	git -C "$REPO" add pyproject.toml app.py
	run git -C "$REPO" commit -q -m "fix: stage an unused import under a config that fixes on check"
	[ "$status" -eq 0 ] || { echo "exit $status: $output"; false; }
	run git -C "$REPO" show HEAD:app.py
	[[ "$output" != *"import os"* ]] || { echo "the committed file still holds the unused import"; return 1; }
	run git -C "$REPO" status --porcelain -- app.py
	[ -z "$output" ] || { echo "the hook left the ruff fix unstaged: $output"; return 1; }
}

@test "pre-commit ends with its summary when ruff cannot format a staged file" {
	command -v ruff >/dev/null 2>&1 || skip "ruff not installed"
	setup_hook_repo
	: >"$REPO/requirements.txt"
	printf 'def main(:\n    print("hi")\n' >"$REPO/app.py"
	git -C "$REPO" add app.py
	run git -C "$REPO" commit -q -m "fix: stage a file with a syntax error"
	[ "$status" -ne 0 ] || { echo "the commit passed with a syntax error"; false; }
	[[ "$output" == *"Ruff format failed on staged python files"* ]] || {
		echo "the hook blocked the commit without running ruff format:"
		printf '%s\n' "$output"
		return 1
	}
	assert_summary_reached
}

@test "pre-commit runs the python checks once for a project with several marker files" {
	setup_hook_repo
	printf '[project]\nname = "probe"\n' >"$REPO/pyproject.toml"
	: >"$REPO/requirements.txt"
	printf 'print("marker")\n' >"$REPO/setup.py"
	printf 'print("hi")\n' >"$REPO/app.py"
	git -C "$REPO" add pyproject.toml requirements.txt setup.py app.py
	local stubbin log
	stubbin="$BATS_TEST_TMPDIR/ruffbin"
	mkdir -p "$stubbin"
	log="$BATS_TEST_TMPDIR/ruff.log"
	: >"$log"
	printf '#!/usr/bin/env bash\nprintf %%s\\\\n "$*" >> "$RUFF_LOG"\nexit 0\n' >"$stubbin/ruff"
	chmod +x "$stubbin/ruff"
	export RUFF_LOG="$log"
	run commit_with_stubbed_tools "$stubbin"
	[ "$status" -eq 0 ] || { echo "exit $status: $output"; false; }
	[ "$(grep -c '^check ' "$log")" -eq 1 ] || {
		echo "the python checks did not run exactly once:"
		cat "$log"
		return 1
	}
}

@test "pre-commit checks a staged python file whose path holds a space" {
	command -v ruff >/dev/null 2>&1 || skip "ruff not installed"
	setup_hook_repo
	: >"$REPO/requirements.txt"
	printf 'import sys\nimport os\n\n\ndef main():\n    print("hi")\n    sys.exit(0)\n' >"$REPO/my app.py"
	git -C "$REPO" add "my app.py"
	run git -C "$REPO" commit -q -m "fix: stage an unused import under a path with a space"
	[ "$status" -eq 0 ] || { echo "exit $status: $output"; false; }
	run git -C "$REPO" show "HEAD:my app.py"
	[[ "$output" != *"import os"* ]] || { echo "the committed file still holds the unused import"; return 1; }
}

@test "pre-commit skips the python tools when only pyproject.toml is staged" {
	setup_hook_repo
	printf '[project]\nname = "probe"\n' >"$REPO/pyproject.toml"
	printf 'print("hi")\n' >"$REPO/app.py"
	git -C "$REPO" add pyproject.toml
	local stubbin log
	stubbin="$BATS_TEST_TMPDIR/ruffbin"
	mkdir -p "$stubbin"
	log="$BATS_TEST_TMPDIR/ruff.log"
	: >"$log"
	printf '#!/usr/bin/env bash\nprintf %%s\\\\n "$*" >> "$RUFF_LOG"\nexit 0\n' >"$stubbin/ruff"
	chmod +x "$stubbin/ruff"
	export RUFF_LOG="$log"
	run commit_with_stubbed_tools "$stubbin"
	[ "$status" -eq 0 ] || { echo "exit $status: $output"; false; }
	[[ "$output" == *"=== Python ==="* ]] || {
		echo "the hook never reached its python section:"
		printf '%s\n' "$output"
		return 1
	}
	[ ! -s "$log" ] || {
		echo "a python tool ran without a staged python file:"
		cat "$log"
		return 1
	}
}

@test "pre-commit ends with its summary when ruff format fails" {
	setup_hook_repo
	: >"$REPO/requirements.txt"
	printf 'print("hi")\n' >"$REPO/app.py"
	git -C "$REPO" add app.py
	local stubbin="$BATS_TEST_TMPDIR/ruffbin"
	write_formatter_stub "$stubbin" ruff
	export STUB_FAIL=1
	run commit_with_stubbed_tools "$stubbin"
	[ "$status" -ne 0 ] || { echo "the commit passed although ruff format failed"; false; }
	[[ "$output" == *"Ruff format failed on staged python files"* ]] || {
		echo "the hook did not name the ruff format failure:"
		printf '%s\n' "$output"
		return 1
	}
	assert_summary_reached
}

@test "pre-commit stages only the clean files that black and isort rewrote" {
	setup_hook_repo
	: >"$REPO/requirements.txt"
	printf 'print("clean")\n' >"$REPO/a.py"
	git -C "$REPO" add a.py
	printf 'print("edited")\n' >"$REPO/b.py"
	git -C "$REPO" add b.py
	printf 'UNSTAGED = 1\n' >>"$REPO/b.py"
	local stubbin="$BATS_TEST_TMPDIR/fmtbin"
	write_formatter_stub "$stubbin" black
	write_formatter_stub "$stubbin" isort
	run commit_with_stubbed_tools "$stubbin"
	[ "$status" -ne 0 ] || { echo "the commit passed although a formatter rewrote a file with unstaged edits"; false; }
	[[ "$output" == *"b.py holds unstaged edits"* ]] || {
		echo "the hook did not name the file with unstaged edits:"
		printf '%s\n' "$output"
		return 1
	}
	run git -C "$REPO" show :a.py
	[[ "$output" == *"black = 1"* && "$output" == *"isort = 1"* ]] || {
		echo "the index does not hold the formatter rewrites of the clean file:"
		printf '%s\n' "$output"
		return 1
	}
	run git -C "$REPO" show :b.py
	[[ "$output" != *" = 1"* && "$output" != *"UNSTAGED"* ]] || {
		echo "the index holds content that was never staged:"
		printf '%s\n' "$output"
		return 1
	}
	run git -C "$REPO" diff -- b.py
	[[ "$output" == *"UNSTAGED"* ]] || { echo "the unstaged edit is no longer unstaged"; return 1; }
}

@test "pre-commit ends with its summary when black fails" {
	assert_fallback_failure_blocks black "Black failed on staged python files"
}

@test "pre-commit ends with its summary when isort fails" {
	assert_fallback_failure_blocks isort "isort failed on staged python files"
}

@test "pre-commit commits a fixed file whose index keeps CRLF" {
	command -v ruff >/dev/null 2>&1 || skip "ruff not installed"
	setup_hook_repo
	: >"$REPO/requirements.txt"
	printf 'import sys\r\nimport os\r\n\r\n\r\ndef main():\r\n    print("hi")\r\n    sys.exit(0)\r\n' >"$REPO/app.py"
	git -C "$REPO" config core.autocrlf false
	git -C "$REPO" add app.py
	git -C "$REPO" config core.autocrlf input
	run git -C "$REPO" show :app.py
	[[ "$output" == *$'\r'* ]] || { echo "setup: the index lost the CRLF line endings"; return 1; }
	run git -C "$REPO" diff --quiet -- app.py
	[ "$status" -eq 0 ] || { echo "setup: git reports the staged CRLF file as modified: $output"; return 1; }
	run git -C "$REPO" commit -q -m "fix: stage a CRLF file with an unused import"
	[ "$status" -eq 0 ] || { echo "exit $status: $output"; false; }
	run git -C "$REPO" show HEAD:app.py
	[[ "$output" != *"import os"* ]] || { echo "the committed file still holds the unused import"; return 1; }
}

@test "pre-commit checks a staged python file whose name starts with a dash" {
	command -v ruff >/dev/null 2>&1 || skip "ruff not installed"
	setup_hook_repo
	: >"$REPO/requirements.txt"
	printf 'import sys\nimport os\n\n\ndef main():\n    print("hi")\n    sys.exit(0)\n' >"$REPO/-n.py"
	git -C "$REPO" add -- -n.py
	run git -C "$REPO" commit -q -m "fix: stage a python file whose name starts with a dash"
	[ "$status" -eq 0 ] || { echo "exit $status: $output"; false; }
	run git -C "$REPO" show HEAD:-n.py
	[[ "$output" != *"import os"* ]] || { echo "the committed file still holds the unused import"; return 1; }
}

@test "pre-commit stages a rewritten file whose name holds glob characters" {
	setup_hook_repo
	: >"$REPO/requirements.txt"
	printf 'print("clean")\n' >"$REPO/a1.py"
	git -C "$REPO" add a1.py
	printf 'UNSTAGED = 1\n' >>"$REPO/a1.py"
	printf 'print("glob")\n' >"$REPO/a[1].py"
	git --literal-pathspecs -C "$REPO" add -- 'a[1].py'
	run git -C "$REPO" show :a1.py
	[[ "$output" != *"UNSTAGED"* ]] || { echo "setup: staging a[1].py also staged the edit on a1.py"; return 1; }
	local stubbin="$BATS_TEST_TMPDIR/fmtbin"
	write_formatter_stub "$stubbin" ruff
	run commit_with_stubbed_tools "$stubbin"
	[ "$status" -ne 0 ] || { echo "the commit passed although a formatter rewrote a file with unstaged edits"; false; }
	[[ "$output" == *"a1.py holds unstaged edits"* ]] || {
		echo "the hook did not name the file with unstaged edits:"
		printf '%s\n' "$output"
		return 1
	}
	run git -C "$REPO" show ':a[1].py'
	[[ "$output" == *"ruff = 1"* ]] || { echo "the index does not hold the rewrite of the clean file"; return 1; }
	run git -C "$REPO" show :a1.py
	[[ "$output" != *"ruff = 1"* && "$output" != *"UNSTAGED"* ]] || {
		echo "the index holds content that was never staged:"
		printf '%s\n' "$output"
		return 1
	}
	run git -C "$REPO" diff -- a1.py
	[[ "$output" == *"UNSTAGED"* ]] || { echo "the unstaged edit is no longer unstaged"; return 1; }
}

stage_with_refused_add() {
	local dir=$1 arg
	cd "$dir" || exit 1
	source "$REPO_ROOT/.config/git/hooks/pre-commit"
	set +e
	git() {
		for arg in "$@"; do
			[ "$arg" != add ] || return 1
		done
		command git "$@"
	}
	FAILED=0
	snapshot_rewrites app.py
	printf 'print("fixed")\n' >app.py
	stage_rewrites "ruff format" app.py
	[ "$FAILED" -eq 1 ] || { echo "FAILED stayed 0 after the failed staging step"; return 1; }
}

@test "stage_rewrites reports a failed staging step" {
	local dir="$BATS_TEST_TMPDIR/unit"
	mkdir -p "$dir"
	git -C "$dir" init -q
	git -C "$dir" config user.name "Hook Tester"
	git -C "$dir" config user.email "hook-test@example.invalid"
	printf 'print("hi")\n' >"$dir/app.py"
	git -C "$dir" add app.py
	run stage_with_refused_add "$dir"
	[ "$status" -eq 0 ] || { echo "exit $status: $output"; false; }
	[[ "$output" == *"Could not stage app.py after ruff format rewrote it."* ]] || {
		echo "the hook did not report the failed staging step:"
		printf '%s\n' "$output"
		return 1
	}
	[[ "$output" != *"Staged app.py"* ]] || { echo "the hook reported a staging step that never happened"; return 1; }
	run git -C "$dir" show :app.py
	[[ "$output" == *'print("hi")'* ]] || { echo "the index changed although the staging step failed"; return 1; }
}

@test "the pre-commit hook is shfmt formatted" {
	command -v shfmt >/dev/null 2>&1 || skip "shfmt not installed"
	run shfmt -ln bash -d "$REPO_ROOT/.config/git/hooks/pre-commit"
	[ "$status" -eq 0 ] || {
		printf '%s\n' "$output"
		return 1
	}
}

@test "comment_lines flags each hash that starts a word outside quotes" {
	local fixture="$BATS_TEST_TMPDIR/probe.sh" want n
	local fixture_lines=(
		'#!/usr/bin/env bash'
		'echo ${#arr[@]} $# a#b $x#y'
		'echo "# no" \# no'
		"echo \"don't # no\""
		'#!/usr/bin/env bash'
		'# comment'
		'echo hi # comment'
		'echo hi;# comment'
		$'\techo hi # comment'
		'echo hi &&# comment'
		'echo hi |# comment'
		'echo hi ># comment'
		"echo '# no' # but this is"
		"printf 'a"
		'# inside quotes'
		"b' # comment"
		'echo after'
	)
	printf '%s\n' "${fixture_lines[@]}" >"$fixture"
	run comment_lines "$fixture"
	for n in 5 6 7 8 9 10 11 12 13 16; do
		want+="${want:+$'\n'}$n:${fixture_lines[n - 1]}"
	done
	[ "$output" = "$want" ] || {
		printf 'want:\n%s\ngot:\n%s\n' "$want" "$output"
		return 1
	}
}

@test "pre-commit and hooks.bats carry no prose comments" {
	local f
	for f in "$REPO_ROOT/.config/git/hooks/pre-commit" "$BATS_TEST_FILENAME"; do
		run comment_lines "$f"
		[ -z "$output" ] || {
			printf '%s\n%s\n' "$f" "$output" >&2
			return 1
		}
	done
}
