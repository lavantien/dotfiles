#!/usr/bin/env bash
# Bootstrap surface tests: content contracts over the install scripts plus
# behavioral checks for the shell helpers that can run standalone.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
BOOTSTRAP_SH="$REPO_ROOT/bootstrap/bootstrap.sh"
BOOTSTRAP_PS1="$REPO_ROOT/bootstrap/bootstrap.ps1"
LINUX_SH="$REPO_ROOT/bootstrap/platforms/linux.sh"
MACOS_SH="$REPO_ROOT/bootstrap/platforms/macos.sh"
WINDOWS_PS1="$REPO_ROOT/bootstrap/platforms/windows.ps1"
COMMON_PS1="$REPO_ROOT/bootstrap/lib/common.ps1"
VERSION_CHECK_SH="$REPO_ROOT/bootstrap/lib/version-check.sh"
ALIASES="$REPO_ROOT/home/.bash_aliases"

@test "bootstrap.ps1 installs gup from its real module path" {
	grep -qF 'Install-GoPackage "github.com/nao1215/gup@latest"' "$BOOTSTRAP_PS1"
	! grep -q 'nao\.vi/gup' "$BOOTSTRAP_PS1"
}

@test "a failed brew install is tracked as failed, not installed" {
	run bash -c '
		set -euo pipefail
		source bootstrap/lib/common.sh
		source bootstrap/lib/version-check.sh
		source bootstrap/platforms/linux.sh
		cmd_exists() { [ "$1" = brew ]; }
		brew() { echo "Error: brew exploded"; return 1; }
		rc=0; install_brew_package zzz || rc=$?
		echo "rc=$rc installed=${#INSTALLED_PACKAGES[@]} failed=${#FAILED_PACKAGES[@]}"
		exit 0
	'
	[ "$status" -eq 0 ]
	echo "$output" | grep -q 'rc=1 installed=0 failed=1'
}

@test "an already installed brew package is still tracked as skipped" {
	run bash -c '
		set -euo pipefail
		source bootstrap/lib/common.sh
		source bootstrap/lib/version-check.sh
		source bootstrap/platforms/linux.sh
		cmd_exists() { [ "$1" = brew ]; }
		brew() { echo "Warning: zzz 1.0 is already installed"; return 1; }
		rc=0; install_brew_package zzz || rc=$?
		echo "rc=$rc skipped=${#SKIPPED_PACKAGES[@]}"
		exit 0
	'
	[ "$status" -eq 0 ]
	echo "$output" | grep -q 'rc=0 skipped=1'
}

@test "the kubectl download fails on http errors instead of saving an error page" {
	grep -qF "curl -fsSL -o kubectl 'https://dl.k8s.io" "$BOOTSTRAP_SH"
	! grep -q 'curl -LO' "$BOOTSTRAP_SH"
}

@test "jq and yazi are installed in the linux cli phase before the deploy phase" {
	local cli_body
	cli_body="$(awk '/^install_cli_tools\(\) \{/,/^\}/' "$BOOTSTRAP_SH")"
	# jq is a hard dependency of the deployed configs (statusline, sync-book,
	# books-index) so it must land before deploy runs those scripts
	echo "$cli_body" | grep -q 'install_brew_package jq "" jq'
	echo "$cli_body" | grep -q 'install_linux_package jq "" jq'
	echo "$cli_body" | grep -q 'install_brew_package yazi "" yazi'
	echo "$cli_body" | grep -q 'install_linux_package yazi "" yazi'
	# phase ordering: cli tools run before deploy in main
	local tab cli_line deploy_line
	tab="$(printf '\t')"
	cli_line="$(grep -n "^${tab}install_cli_tools" "$BOOTSTRAP_SH" | cut -d: -f1)"
	deploy_line="$(grep -n "^${tab}deploy_configs" "$BOOTSTRAP_SH" | cut -d: -f1)"
	[ -n "$cli_line" ] && [ -n "$deploy_line" ]
	[ "$cli_line" -lt "$deploy_line" ]
}

@test "difftastic is installed in the linux cli phase on both platforms" {
	local cli_body
	cli_body="$(awk '/^install_cli_tools\(\) \{/,/^\}/' "$BOOTSTRAP_SH")"
	echo "$cli_body" | grep -q 'install_brew_package difftastic "" difft'
	echo "$cli_body" | grep -q 'install_linux_package difftastic "" difft'
}

@test "linux and macos package descriptions cover the new cli tools" {
	for f in "$LINUX_SH" "$MACOS_SH"; do
		grep -q 'jq) echo "JSON processor"' "$f"
		grep -q 'yazi) echo "file manager"' "$f"
		grep -q 'difftastic | difft) echo "diff viewer"' "$f"
	done
}

@test "bootstrap.ps1 installs jq and yazi in the base scoop package list" {
	local base_list
	base_list="$(awk '/\$scoopPackages = @\(/,/^\s*\)/' "$BOOTSTRAP_PS1")"
	echo "$base_list" | grep -q 'Package = "jq"'
	echo "$base_list" | grep -q 'Package = "yazi"'
	grep -q 'Package = "difftastic"' "$BOOTSTRAP_PS1"
}
