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
