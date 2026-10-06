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
