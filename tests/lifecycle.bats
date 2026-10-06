#!/usr/bin/env bash
# Lifecycle tests: uninstall/restore prompt contract, counters, restore
# non-interactive paths, uninstall inventory, gitconfig merge, and the
# windows deploy ports.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
UNINSTALL="$REPO_ROOT/scripts/uninstall.sh"
RESTORE="$REPO_ROOT/scripts/restore.sh"
DEPLOY="$REPO_ROOT/scripts/deploy.sh"

# Source a guarded script under set -u and run a snippet with the given stdin.
# The snippet sees $script, $input, and $code as plain variables.
drive() {
	local script="$1" input="$2" code="$3"
	printf '%s' "$input" |
		bash -u -c 'script="$1" input="$2" code="$3"; source "$script"; eval "$code"' \
			_ "$script" "$input" "$code"
}

make_backup() {
	local home="$1" name="$2"
	mkdir -p "$home/.dotfiles-backup/$name"
	printf 'Timestamp: %s\n' "$name" >"$home/.dotfiles-backup/$name/MANIFEST.txt"
}

# ============================================================================
# prompt contract
# ============================================================================

@test "classify_reply accepts exactly the y n a bytes" {
	local pair input expected
	for pair in \
		'y:yes' 'Y:yes' 'n:no' 'N:no' 'a:all' 'A:all' \
		':no' 'yes:no' 'no-all:no' 'all:no' ' y:no' 'y :no' 'é:no'; do
		input="${pair%%:*}"
		expected="${pair##*:}"
		run drive "$UNINSTALL" "$input" 'classify_reply "$input" true'
		[ "$output" = "$expected" ] || { echo "input '$input' classified '$output', want '$expected'"; false; }
	done
}

@test "classify_reply without the all option treats a as no" {
	local input
	for input in a A all; do
		run drive "$UNINSTALL" "$input" 'classify_reply "$input" false'
		[ "$output" = "no" ] || { echo "input '$input' classified '$output', want no"; false; }
	done
}

@test "ask_yn confirms on y and Y under set -u" {
	local input
	for input in $'y\n' $'Y\n'; do
		run drive "$UNINSTALL" "$input" \
			'if ask_yn "Remove?"; then echo confirmed; else echo denied; fi'
		[ "$output" = "confirmed" ] || { echo "input '$input' denied"; false; }
	done
}

@test "ask_yn denies on yes, empty, padded, multibyte, and EOF" {
	local input
	for input in $'yes\n' $'n\n' $'\n' $' y\n' $'y \n' $'é\n' ''; do
		run drive "$UNINSTALL" "$input" \
			'if ask_yn "Remove?"; then echo confirmed; else echo denied; fi'
		[ "$output" = "denied" ] || { echo "input '$input' confirmed"; false; }
	done
}

@test "ask_yna returns 2 only for a" {
	run drive "$UNINSTALL" $'a\n' 'rc=0; ask_yna "Remove one?" || rc=$?; echo "rc=$rc"'
	[[ "$output" == *"rc=2"* ]] || { echo "a returned '$output'"; false; }
	run drive "$UNINSTALL" $'y\n' 'rc=0; ask_yna "Remove one?" || rc=$?; echo "rc=$rc"'
	[[ "$output" == *"rc=0"* ]]
	run drive "$UNINSTALL" $'n\n' 'rc=0; ask_yna "Remove one?" || rc=$?; echo "rc=$rc"'
	[[ "$output" == *"rc=1"* ]]
}

@test "safe_remove removes on y and keeps the file on n" {
	local sb
	sb="$(mktemp -d)"
	touch "$sb/.dotfiles-installed" "$sb/target"
	run bash -u -c 'source "$2"; safe_remove "$1/target"' _ "$sb" "$UNINSTALL" <<< $'y\n'
	[ "$status" -eq 0 ]
	[ ! -e "$sb/target" ] || { echo "y did not remove"; false; }
	touch "$sb/target"
	run bash -u -c 'source "$2"; safe_remove "$1/target"' _ "$sb" "$UNINSTALL" <<< $'n\n'
	[ "$status" -eq 0 ]
	[ -e "$sb/target" ] || { echo "n removed the file"; false; }
	rm -rf "$sb"
}

@test "safe_remove a skips this file and every later one without reading stdin" {
	local sb
	sb="$(mktemp -d)"
	touch "$sb/.dotfiles-installed" "$sb/first" "$sb/second"
	run bash -u -c 'source "$2"; safe_remove "$1/first"; safe_remove "$1/second"' \
		_ "$sb" "$UNINSTALL" <<< $'a\n'
	[ "$status" -eq 0 ]
	[ -e "$sb/first" ] && [ -e "$sb/second" ] || { echo "a did not skip both files"; false; }
	rm -rf "$sb"
}

@test "uninstall driven with piped y removes deployed files and exits 0" {
	local sb
	sb="$(mktemp -d)"
	touch "$sb/.dotfiles-installed" "$sb/.bash_aliases" "$sb/.gitconfig"
	run env HOME="$sb" bash "$UNINSTALL" <<< $'y\ny\ny\n'
	[ "$status" -eq 0 ] || { echo "exit $status: $output"; false; }
	[ ! -e "$sb/.bash_aliases" ]
	[ ! -e "$sb/.gitconfig" ]
	[ ! -e "$sb/.dotfiles-installed" ]
	rm -rf "$sb"
}

@test "uninstall --verify-only never removes and exits 0" {
	local sb
	sb="$(mktemp -d)"
	touch "$sb/.dotfiles-installed" "$sb/.bash_aliases"
	run env HOME="$sb" bash "$UNINSTALL" --verify-only </dev/null
	[ "$status" -eq 0 ]
	[ -e "$sb/.bash_aliases" ]
	[ -e "$sb/.dotfiles-installed" ]
	[[ "$output" == *"Would remove: $sb/.bash_aliases"* ]]
	rm -rf "$sb"
}

# ============================================================================
# uninstall inventory (what deploy actually writes)
# ============================================================================

@test "verify-only inventory covers the deploy copy sites" {
	local sb
	sb="$(mktemp -d)"
	mkdir -p "$sb/.config/nvim" "$sb/.config/opencode" "$sb/assets" "$sb/dev" "$sb/.claude"
	touch "$sb/.dotfiles-installed" "$sb/.bash_aliases" "$sb/.zshrc" "$sb/.gitconfig" \
		"$sb/.config/nvim/init.lua" "$sb/.config/opencode/opencode.json" \
		"$sb/assets/bg.png" "$sb/dev/git-clone-all.sh" "$sb/dev/git-update-repos.sh" \
		"$sb/dev/update-all.sh" "$sb/.claude/CLAUDE.md"
	run env HOME="$sb" bash "$UNINSTALL" --verify-only </dev/null
	[ "$status" -eq 0 ]
	local p
	for p in "$sb/.config/nvim" "$sb/.config/opencode/opencode.json" "$sb/assets" \
		"$sb/dev/git-clone-all.sh" "$sb/dev/git-update-repos.sh" "$sb/dev/update-all.sh" \
		"$sb/.claude/CLAUDE.md"; do
		[[ "$output" == *"Would remove: $p"* ]] || { echo "missing from inventory: $p"; false; }
	done
	for p in "$sb/.config/nvim/init.lua" "$sb/.bash_aliases"; do
		[ -e "$p" ]
	done
	rm -rf "$sb"
}

@test "verify-only never offers paths deploy stopped writing" {
	local sb
	sb="$(mktemp -d)"
	touch "$sb/.dotfiles-installed" "$sb/.bashrc" "$sb/.bash_profile" "$sb/init.lua" \
		"$sb/wezterm.lua" "$sb/.editorconfig"
	run env HOME="$sb" bash "$UNINSTALL" --verify-only </dev/null
	[ "$status" -eq 0 ]
	local p
	for p in "$sb/.bashrc" "$sb/.bash_profile" "$sb/init.lua" "$sb/wezterm.lua" "$sb/.editorconfig"; do
		[[ "$output" != *"Would remove: $p"* ]] || { echo "legacy path offered: $p"; false; }
		[ -e "$p" ]
	done
	rm -rf "$sb"
}

@test "uninstall unsets core.hooksPath when the gitconfig survives" {
	local sb
	sb="$(mktemp -d)"
	touch "$sb/.dotfiles-installed" "$sb/.bash_aliases"
	git config --file "$sb/.gitconfig" core.hooksPath "$sb/.config/git/hooks"
	run env HOME="$sb" bash "$UNINSTALL" <<< $'y\nn\n'
	[ "$status" -eq 0 ]
	[ ! -e "$sb/.bash_aliases" ]
	[ -f "$sb/.gitconfig" ]
	run env HOME="$sb" git config --global core.hooksPath
	[ "$status" -ne 0 ]
	rm -rf "$sb"
}

# ============================================================================
# gitconfig credential helper
# ============================================================================

@test "shipped gitconfig resolves gh through PATH" {
	run grep -F 'helper = !gh auth git-credential' "$REPO_ROOT/home/.gitconfig"
	[ "$status" -eq 0 ]
	run grep -E 'linuxbrew|gh\.exe' "$REPO_ROOT/home/.gitconfig"
	[ "$status" -ne 0 ]
}

@test "normalize_gh_helpers folds legacy absolute gh paths into the portable form" {
	local f
	f="$(mktemp)"
	cat >"$f" <<'EOF'
[credential "https://github.com"]
	helper =
	helper = !/home/linuxbrew/.linuxbrew/bin/gh auth git-credential
[credential "https://gist.github.com"]
	helper =
	helper = !"C:/Users/u/scoop/apps/gh/current/gh.exe" auth git-credential
EOF
	run bash -c 'source "$1"; normalize_gh_helpers "$2"' _ "$DEPLOY" "$f"
	[ "$status" -eq 0 ]
	[ "$(grep -c '^helper = !gh auth git-credential$' "$f")" -eq 2 ]
	run grep -E 'linuxbrew|gh\.exe' "$f"
	[ "$status" -ne 0 ]
	rm -f "$f"
}

@test "merge_gitconfig preserves live-only keys with template values on top" {
	local sb
	sb="$(mktemp -d)"
	cat >"$sb/live" <<'EOF'
[user]
	name = Old Name
	email = old@example.invalid
	signingkey = ABC123DEF
[commit]
	gpgsign = true
[include]
	path = ~/work/gitconfig.extra
[alias]
	dft = difftool
	custom = !sh -c 'echo hi'
[credential]
	helper = store
[init]
	defaultBranch = master
EOF
	run bash -c 'source "$1"; merge_gitconfig "$3" "$2/live"' \
		_ "$DEPLOY" "$sb" "$REPO_ROOT/home/.gitconfig"
	[ "$status" -eq 0 ] || { echo "$output"; false; }
	[ "$(git config --file "$sb/live" user.name)" = "Old Name" ]
	[ "$(git config --file "$sb/live" user.signingkey)" = "ABC123DEF" ]
	[ "$(git config --file "$sb/live" commit.gpgsign)" = "true" ]
	[ "$(git config --file "$sb/live" include.path)" = "~/work/gitconfig.extra" ]
	[ "$(git config --file "$sb/live" alias.custom)" = "!sh -c 'echo hi'" ]
	[ "$(git config --file "$sb/live" credential.helper)" = "store" ]
	# Managed keys flip back to the template's values
	[ "$(git config --file "$sb/live" init.defaultBranch)" = "main" ]
	[ "$(git config --file "$sb/live" alias.dft)" = "difftool" ]
	run git config --file "$sb/live" --list
	[ "$status" -eq 0 ]
	rm -rf "$sb"
}

@test "merge_gitconfig preserves identity and drops legacy helpers" {
	local sb
	sb="$(mktemp -d)"
	cat >"$sb/existing" <<'EOF'
[user]
	name = Old Name
	email = old@example.invalid
[credential "https://github.com"]
	helper = /home/linuxbrew/.linuxbrew/bin/gh auth git-credential
EOF
	cat >"$sb/template" <<'EOF'
[user]
	name = Template
	email = template@example.invalid
[credential "https://github.com"]
	helper =
	helper = !/home/linuxbrew/.linuxbrew/bin/gh auth git-credential
EOF
	run bash -c 'source "$1"; merge_gitconfig "$2/template" "$2/existing"' _ "$DEPLOY" "$sb"
	[ "$status" -eq 0 ]
	[ "$(git config --file "$sb/existing" user.name)" = "Old Name" ]
	[ "$(git config --file "$sb/existing" user.email)" = "old@example.invalid" ]
	run grep -E 'linuxbrew|gh\.exe' "$sb/existing"
	[ "$status" -ne 0 ]
	rm -rf "$sb"
}

# ============================================================================
# windows deploy ports
# ============================================================================

# Write a pwsh harness that dot-sources one function out of a .ps1 script
# without executing the script, then runs the given body. DF_* environment
# variables carry paths so the body stays argument-free.
write_pwsh_harness() {
	local out="$1" body="$2"
	cat >"$out" <<'PS1'
param([string]$ScriptPath, [string]$FunctionName)
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$tokens, [ref]$errors)
if ($errors.Count -gt 0) { $errors | ForEach-Object { Write-Error $_.Message }; exit 2 }
$fn = $ast.Find({ param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
    $node.Name -eq $FunctionName }, $true)
if ($null -eq $fn) { Write-Error "function $FunctionName not found"; exit 3 }
. ([scriptblock]::Create($fn.Extent.Text))
if ($env:DF_DOTFILESDIR) { $DotfilesDir = $env:DF_DOTFILESDIR }
if ($env:DF_CONFIGDIR) { $ConfigDir = $env:DF_CONFIGDIR }
PS1
	printf '%s\n' "$body" >>"$out"
}

@test "deploy.ps1 requires PowerShell 7" {
	head -n 3 "$REPO_ROOT/scripts/deploy.ps1" | grep -q '#requires -Version 7'
}

@test "update.sh carries a shebang and the shellcheck debt list is empty" {
	[ "$(head -n 1 "$REPO_ROOT/scripts/update.sh")" = "#!/usr/bin/env bash" ]
	grep -qE '^KNOWN_SHELLCHECK_ERRORS := *$' "$REPO_ROOT/Makefile"
}

# ============================================================================
# cosmetics
# ============================================================================

@test "deploy_scripts copies and chmods git-clone-all.sh" {
	local sb fake probe
	sb="$(mktemp -d)"
	fake="$(mktemp -d)"
	# A non-executable source proves the chmod is deploy's job, not cp's
	echo 'echo clone-all' >"$fake/git-clone-all.sh"
	mkdir -p "$fake/scripts"
	echo 'echo update-repos' >"$fake/scripts/git-update-repos.sh"
	echo 'echo update-all' >"$fake/scripts/update-all.sh"
	run bash -c 'source "$1"; HOME="$2"; ROOT_DIR="$3"; SCRIPT_DIR="$3/scripts"; deploy_scripts' \
		_ "$DEPLOY" "$sb" "$fake"
	[ "$status" -eq 0 ]
	[ -f "$sb/dev/git-clone-all.sh" ]
	[ -f "$sb/dev/git-update-repos.sh" ]
	# chmod is a no-op on noacl MSYS mounts, assert the exec bit only where
	# the platform tracks it as metadata
	probe="$(mktemp)"
	chmod +x "$probe" 2>/dev/null
	if [ -x "$probe" ]; then
		[ -x "$sb/dev/git-clone-all.sh" ] || { echo "git-clone-all.sh not executable"; false; }
	fi
	rm -rf "$sb" "$fake" "$probe"
}

@test "deploy.sh final message is shell-agnostic" {
	run bash -c 'source "$1"; print_final_message' _ "$DEPLOY"
	[ "$status" -eq 0 ]
	[[ "$output" != *zshrc* ]] || { echo "message still names zshrc"; false; }
	[[ "$output" == *"Restart your shell"* ]]
}

@test "backup.sh stops trafficking the root wezterm.lua stub" {
	run grep -F '"$HOME/wezterm.lua"' "$REPO_ROOT/scripts/backup.sh"
	[ "$status" -ne 0 ]
	[ ! -e "$REPO_ROOT/home/wezterm.lua" ]
}

@test "deploy.ps1 deploys the bash hooks and wires core.hooksPath" {
	command -v pwsh >/dev/null 2>&1 || skip "pwsh not installed"
	local sb
	sb="$(cd "$(mktemp -d)" && pwd -W)"
	write_pwsh_harness "$sb/harness.ps1" 'Deploy-GitHooks -HooksDir "$env:DF_CONFIGDIR/git/hooks"'
	HOME="$sb" USERPROFILE="$sb" DF_CONFIGDIR="$sb/.config" DF_DOTFILESDIR="$REPO_ROOT" \
		run pwsh -NoProfile -File "$sb/harness.ps1" \
			-ScriptPath "$REPO_ROOT/scripts/deploy.ps1" -FunctionName Deploy-GitHooks
	[ "$status" -eq 0 ] || { echo "$output"; false; }
	[ -f "$sb/.config/git/hooks/pre-commit" ]
	[ -f "$sb/.config/git/hooks/commit-msg" ]
	run env HOME="$sb" git config --global core.hooksPath
	[ "$output" = "$sb/.config/git/hooks" ]
	run env HOME="$sb" git config --global init.templatedir
	[ "$output" = "$sb/.config/git/hooks" ]
	rm -rf "$sb"
}

@test "deploy.ps1 Merge-Gitconfig preserves identity and normalizes helpers" {
	command -v pwsh >/dev/null 2>&1 || skip "pwsh not installed"
	local sb
	sb="$(cd "$(mktemp -d)" && pwd -W)"
	cat >"$sb/existing" <<'EOF'
[user]
	name = Old Name
	email = old@example.invalid
[credential "https://github.com"]
	helper = /home/linuxbrew/.linuxbrew/bin/gh auth git-credential
EOF
	cp "$REPO_ROOT/home/.gitconfig" "$sb/template"
	write_pwsh_harness "$sb/harness.ps1" 'Merge-Gitconfig -Src $env:DF_SRC -Dst $env:DF_DST'
	DF_SRC="$sb/template" DF_DST="$sb/existing" run pwsh -NoProfile -File "$sb/harness.ps1" \
		-ScriptPath "$REPO_ROOT/scripts/deploy.ps1" -FunctionName Merge-Gitconfig
	[ "$status" -eq 0 ] || { echo "$output"; false; }
	[ "$(git config --file "$sb/existing" user.name)" = "Old Name" ]
	[ "$(git config --file "$sb/existing" user.email)" = "old@example.invalid" ]
	run grep -E 'linuxbrew|gh\.exe' "$sb/existing"
	[ "$status" -ne 0 ]
	rm -rf "$sb"
}

# ============================================================================
# restore non-interactive paths
# ============================================================================

@test "restore confirm accepts y and rejects yes and EOF" {
	local sb
	sb="$(mktemp -d)"
	run bash -u -c 'source "$2"; FORCE=false; if confirm_restore "$1"; then echo go; else echo stop; fi' \
		_ "$sb" "$RESTORE" <<< $'y\n'
	[[ "$output" == *"go"* ]]
	run bash -u -c 'source "$2"; FORCE=false; if confirm_restore "$1"; then echo go; else echo stop; fi' \
		_ "$sb" "$RESTORE" <<< $'yes\n'
	[[ "$output" == *"stop"* ]]
	run bash -u -c 'source "$2"; FORCE=false; if confirm_restore "$1"; then echo go; else echo stop; fi' \
		_ "$sb" "$RESTORE" </dev/null
	[[ "$output" == *"stop"* ]]
	rm -rf "$sb"
}

@test "restore --force without a name picks the newest backup non-interactively" {
	local sb
	sb="$(mktemp -d)"
	make_backup "$sb" 20260101-000000
	echo old >"$sb/.dotfiles-backup/20260101-000000/gitconfig"
	make_backup "$sb" 20260202-000000
	echo new >"$sb/.dotfiles-backup/20260202-000000/gitconfig"
	run env HOME="$sb" bash "$RESTORE" --force </dev/null
	[ "$status" -eq 0 ] || { echo "exit $status: $output"; false; }
	[ "$(cat "$sb/.gitconfig")" = "new" ]
	rm -rf "$sb"
}

@test "restore --list with no backups prints a clean message and exits 0" {
	local sb
	sb="$(mktemp -d)"
	mkdir -p "$sb/.dotfiles-backup"
	run env HOME="$sb" bash "$RESTORE" --list </dev/null
	[ "$status" -eq 0 ] || { echo "exit $status: $output"; false; }
	[[ "$output" == *"No backups found"* ]]
	rm -rf "$sb"
}

@test "bare restore with no backups exits deliberately instead of dying" {
	local sb
	sb="$(mktemp -d)"
	run env HOME="$sb" bash "$RESTORE" </dev/null
	[ "$status" -eq 1 ]
	[[ "$output" == *"No backups found"* ]]
	[[ "$output" != *"read error"* ]]
	rm -rf "$sb"
}

@test "bare restore with no backup dir exits deliberately" {
	local sb
	sb="$(mktemp -d)"
	run env HOME="$sb" bash "$RESTORE" --list </dev/null
	[ "$status" -eq 0 ]
	[[ "$output" == *"Backup directory not found"* ]]
	rm -rf "$sb"
}
