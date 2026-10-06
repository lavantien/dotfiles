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
