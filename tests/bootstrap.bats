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

# Negated greps must be explicit guards: bats runs tests under errexit, which
# exempts `!`-inverted failures, so a bare `! grep` mid-test can be swallowed.
assert_absent() {
	if grep -q "$1" "$2"; then
		echo "unexpected pattern in $2: $1" >&2
		return 1
	fi
}

@test "bootstrap.ps1 installs gup from its real module path" {
	grep -qF 'Install-GoPackage "github.com/nao1215/gup@latest"' "$BOOTSTRAP_PS1"
	assert_absent 'nao\.vi/gup' "$BOOTSTRAP_PS1"
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
	assert_absent 'curl -LO' "$BOOTSTRAP_SH"
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

@test "windows bootstrap installs the iosevka nerd font with a per-user fallback" {
	grep -qF 'Add-ScoopBucket "nerd-fonts"' "$WINDOWS_PS1"
	grep -qF 'Install-ScoopPackage $FontName' "$WINDOWS_PS1"
	# fallback: official release zip, per-user font dir, HKCU registration
	grep -qF 'releases/latest/download/$ZipName.zip' "$WINDOWS_PS1"
	grep -qF 'Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"' "$WINDOWS_PS1"
	grep -qF '"HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"' "$WINDOWS_PS1"
	# wired into the foundation phase after wezterm
	foundation="$(awk '/^function Install-Foundation \{/,/^\}/' "$BOOTSTRAP_PS1")"
	echo "$foundation" | grep -qF 'Install-WezTerm'
	echo "$foundation" | grep -qF 'Install-NerdFont'
}

@test "plain non nerd font iosevka variants do not satisfy the font check" {
	command -v pwsh >/dev/null 2>&1 || skip "pwsh not available"
	run pwsh -NoProfile -Command '
		$ErrorActionPreference = "Stop"
		. "$PWD/bootstrap/platforms/windows.ps1"
		$probe = Join-Path ([IO.Path]::GetTempPath()) "nf-probe-$(Get-Random)"
		$fontsDir = New-Item -ItemType Directory -Force -Path (Join-Path $probe "Microsoft\Windows\Fonts")
		$env:LOCALAPPDATA = $probe
		$fontsReg = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
		function Test-Path {
			param([string]$p)
			$p -eq $fontsReg -or $p -eq $fontsDir.FullName
		}
		function Get-ItemProperty {
			param($Path)
			[pscustomobject]@{ "IosevkaTerm (TrueType)" = "plain" }
		}
		Set-Content (Join-Path $fontsDir.FullName "IosevkaTerm-Regular.ttf") "stub"
		$plain = Test-NerdFontInstalled
		Remove-Item $probe -Recurse -Force
		"plain-file-and-registry=$plain"
	'
	[ "$status" -eq 0 ]
	echo "$output" | grep -q "plain-file-and-registry=False"
}

@test "the font check accepts the nf file and registry shapes" {
	command -v pwsh >/dev/null 2>&1 || skip "pwsh not available"
	run pwsh -NoProfile -Command '
		$ErrorActionPreference = "Stop"
		. "$PWD/bootstrap/platforms/windows.ps1"
		$probe = Join-Path ([IO.Path]::GetTempPath()) "nf-probe-$(Get-Random)"
		$fontsDir = New-Item -ItemType Directory -Force -Path (Join-Path $probe "Microsoft\Windows\Fonts")
		$env:LOCALAPPDATA = $probe
		$fontsReg = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
		function Test-Path {
			param([string]$p)
			$p -eq $fontsReg -or $p -eq $fontsDir.FullName
		}
		function Get-ItemProperty {
			param($Path)
			[pscustomobject]@{}
		}
		# nf file shape: what scoop and the zip fallback copy into the fonts dir
		Set-Content (Join-Path $fontsDir.FullName "IosevkaTermNerdFontMono-Regular.ttf") "stub"
		$nfFile = Test-NerdFontInstalled
		Remove-Item (Join-Path $fontsDir.FullName "*") -Force
		# spaced registry shape: the display name font installs register
		function Get-ItemProperty {
			param($Path)
			[pscustomobject]@{ "IosevkaTerm Nerd Font (TrueType)" = "user" }
		}
		$regDisplay = Test-NerdFontInstalled
		# unspaced registry shape: what the zip fallback itself writes
		function Get-ItemProperty {
			param($Path)
			[pscustomobject]@{ "IosevkaTermNerdFont-Regular (TrueType)" = "user" }
		}
		$regBaseName = Test-NerdFontInstalled
		Remove-Item $probe -Recurse -Force
		"nf-file=$nfFile reg-display=$regDisplay reg-basename=$regBaseName"
	'
	[ "$status" -eq 0 ]
	echo "$output" | grep -q "nf-file=True"
	echo "$output" | grep -q "reg-display=True"
	echo "$output" | grep -q "reg-basename=True"
}

@test "windows bootstrap offers gh login with a non-interactive skip" {
	grep -qF 'gh auth status' "$BOOTSTRAP_PS1"
	grep -qF 'gh auth login' "$BOOTSTRAP_PS1"
	grep -qF "Non-interactive mode: Skipping 'gh auth login'" "$BOOTSTRAP_PS1"
	# the offer lives in the cli phase where gh gets installed on windows
	cli="$(awk '/^function Install-CLITools \{/,/^\}/' "$BOOTSTRAP_PS1")"
	echo "$cli" | grep -qF 'gh auth login'
}

@test "windows bootstrap covers helm kubectl oh-my-posh yamllint hadolint" {
	grep -qF 'Install-WingetPackage -Id "Helm.Helm"' "$BOOTSTRAP_PS1"
	grep -qF 'Install-WingetPackage -Id "Kubernetes.kubectl"' "$BOOTSTRAP_PS1"
	grep -qF 'Install-WingetPackage -Id "JanDeDobbeleer.OhMyPosh"' "$BOOTSTRAP_PS1"
	grep -qF 'Install-PipGlobal "yamllint"' "$BOOTSTRAP_PS1"
	grep -qF 'Install-ScoopPackage "hadolint" "" "hadolint"' "$BOOTSTRAP_PS1"
}

@test "every winget install in the bootstrap scripts passes --exact" {
	for f in "$BOOTSTRAP_PS1" "$WINDOWS_PS1"; do
		total="$(grep -c 'winget install --id' "$f")"
		exact="$(grep 'winget install --id' "$f" | grep -c -- '--exact')"
		[ "$total" -gt 0 ]
		[ "$total" -eq "$exact" ]
	done
}

@test "a failed winget install is tracked as failed, not installed" {
	command -v pwsh >/dev/null 2>&1 || skip "pwsh not available"
	run pwsh -NoProfile -Command '
		$ErrorActionPreference = "Stop"
		. "$PWD/bootstrap/platforms/windows.ps1"
		function winget {
			if ($args[0] -eq "install") {
				"Failed to install package: 0x80070005"
				cmd /c exit 1
			}
			else {
				"No installed package found matching input criteria."
				cmd /c exit 1
			}
		}
		$result = Install-WingetPackage -Id "Fake.Tool" -DisplayName "FakeTool"
		"rc=$result failed=$($Script:FailedPackages.Count) installed=$($Script:InstalledPackages.Count)"
	'
	[ "$status" -eq 0 ]
	echo "$output" | grep -q "rc=False failed=1 installed=0"
	echo "$output" | grep -q "\[WARN\] Failed to install FakeTool"
}

@test "the winget list presence query never runs during dry runs" {
	command -v pwsh >/dev/null 2>&1 || skip "pwsh not available"
	run pwsh -NoProfile -Command '
		$ErrorActionPreference = "Stop"
		. "$PWD/bootstrap/platforms/windows.ps1"
		$log = Join-Path ([IO.Path]::GetTempPath()) "winget-dryrun-$(Get-Random).log"
		function winget {
			Add-Content -Path $log -Value ($args -join " ")
			"stubbed winget output"
			cmd /c exit 0
		}
		$Script:DryRun = $true
		$result = Install-WingetPackage -Id "Fake.Tool" -DisplayName "FakeTool"
		$calls = if (Test-Path $log) { @(Get-Content $log).Count } else { 0 }
		Remove-Item $log -Force -ErrorAction SilentlyContinue
		"rc=$result winget-calls=$calls"
	'
	[ "$status" -eq 0 ]
	echo "$output" | grep -q "rc=True winget-calls=0"
}

@test "winget pins use the current dotnet 10 and jdk 25 ids" {
	grep -q -- '--id Microsoft.DotNet.SDK.10' "$BOOTSTRAP_PS1"
	grep -q -- '--id Microsoft.OpenJDK.25' "$BOOTSTRAP_PS1"
	assert_absent 'DotNet\.SDK\.8\b' "$BOOTSTRAP_PS1"
	assert_absent 'OpenJDK\.21\b' "$BOOTSTRAP_PS1"
}

@test "version-check.sh stays bash 3.2 compatible and its lookups answer" {
	assert_absent '^declare -gA' "$VERSION_CHECK_SH"
	run bash -c '
		set -e
		source bootstrap/lib/common.sh
		source bootstrap/lib/version-check.sh
		[ "$(get_version_flag go)" = "version" ]
		[ "$(get_version_flag cargo)" = "--version" ]
		[ "$(get_version_flag curl)" = "--version" ]
		[ "$(get_version_pattern gh)" = "gh version ([0-9]+\.[0-9]+\.[0-9]+)" ]
		[ "$(get_version_pattern gh.exe)" = "gh version ([0-9]+\.[0-9]+\.[0-9]+)" ]
		[ "$(get_version_pattern python3.12)" = "Python ([0-9]+\.[0-9]+\.[0-9]+)" ]
		[ "$(get_version_pattern lazygit.exe)" = "version=([0-9]+\.[0-9]+\.[0-9]+)" ]
		[ -z "$(get_version_pattern curl)" ]
	'
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "neovim converges on snapless linux hosts and comments say 0.13" {
	# apt/brew fallback replaces the hard failure when snapd is absent
	# (minimal servers, containers)
	grep -q 'install_linux_package neovim "" nvim' "$BOOTSTRAP_SH"
	# the snap edge channel stays: it delivers the 0.13 nightlies
	grep -q 'sudo snap install --edge nvim --classic' "$BOOTSTRAP_SH"
	assert_absent 'Neovim 0\.12' "$BOOTSTRAP_SH"
	assert_absent 'Neovim 0\.12' "$ALIASES"
	grep -q 'Neovim 0\.13' "$BOOTSTRAP_SH"
	grep -q 'prefers Neovim 0\.13' "$ALIASES"
}

@test "tinymist is labeled as the typst lsp" {
	grep -qF '"tinymist" { return "Typst LSP" }' "$WINDOWS_PS1"
	assert_absent 'Nim LSP' "$WINDOWS_PS1"
}

@test "dead windows bootstrap code is gone" {
	assert_absent 'function Ensure-Choco' "$WINDOWS_PS1"
	assert_absent 'function Install-ChocoPackage' "$WINDOWS_PS1"
	assert_absent 'function Install-PHP' "$WINDOWS_PS1"
	[ ! -e "$REPO_ROOT/lib/git-bash.ps1" ]
}

@test "common.ps1 no longer shadows write-warning" {
	grep -q 'function Write-WarningMsg' "$COMMON_PS1"
	assert_absent 'function Write-Warning \{' "$COMMON_PS1"
	assert_absent 'Write-Warning ' "$COMMON_PS1"
	assert_absent 'Write-Warning ' "$BOOTSTRAP_PS1"
	assert_absent 'Write-Warning ' "$WINDOWS_PS1"
}

@test "bootstrap.ps1 enforces powershell 7" {
	head -30 "$BOOTSTRAP_PS1" | grep -q '#requires -Version 7'
}

@test "bootstrap.ps1 dry run walks every new windows step" {
	command -v pwsh >/dev/null 2>&1 || skip "pwsh not available"
	run pwsh -NoProfile -File "$BOOTSTRAP_PS1" -DryRun -Y
	[ "$status" -eq 0 ]
	# the gh auth offer is announced unconditionally in dry run
	echo "$output" | grep -q "Would check gh auth"
	# every newly wired tool must be visited: tracked or skipped, never silent.
	# already installed tools surface under their display name, fresh ones
	# under the winget id, so accept either shape.
	for tool in IosevkaTerm-NF 'Helm.Helm|helm' 'Kubernetes.kubectl|kubectl' 'JanDeDobbeleer.OhMyPosh|oh-my-posh' jq yazi yamllint hadolint difftastic; do
		echo "$output" | grep -qE "$tool"
	done
}
