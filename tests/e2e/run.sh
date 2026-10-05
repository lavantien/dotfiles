#!/usr/bin/env bash
# Linux e2e driver. Runs the dotfiles lifecycle inside a throwaway container
# from the image make e2e-linux builds, with the repo bind mounted read only
# at /src and copied to /work so chmods and markers never dirty the host.
# Usage: run.sh [image]. Set FULL=1 to swap the dry-run bootstrap for a real
# convergence pass, which needs network and time.

set -euo pipefail

IMAGE="${1:-dotfiles-e2e}"

case "$(uname -s)" in
MINGW* | MSYS* | CYGWIN*) ROOT="$(pwd -W)" ;;
*) ROOT="$(pwd)" ;;
esac

INNER=$(
	cat <<'EOS'
set -u
cd /work
PASS=0
FAIL=0
FAILED=()

report() {
	local status="$1" name="$2" detail="${3:-}"
	if [ "$status" = pass ]; then
		PASS=$((PASS + 1))
		echo "[PASS] $name${detail:+ - $detail}"
	else
		FAIL=$((FAIL + 1))
		FAILED+=("$name")
		echo "[FAIL] $name${detail:+ - $detail}"
	fi
}

tail_log() { tail -n 6 "$1" | sed 's/^/    | /'; }

echo "=== copying repo into /work ==="
cp -R --preserve=mode,timestamps /src/. /work/

# A real machine carries a git identity; deploy preserves it through the merge
git config --global user.name "E2E Tester"
git config --global user.email "e2e@example.invalid"

echo "=== step 1: bootstrap ==="
if [ "${FULL:-0}" = "1" ]; then
	if bash /work/bootstrap/bootstrap.sh -y >/tmp/step1.log 2>&1; then
		report pass "1 bootstrap -y (FULL)"
	else
		rc=$?
		report fail "1 bootstrap -y (FULL)" "exit $rc"
		tail_log /tmp/step1.log
	fi
else
	if bash /work/bootstrap/bootstrap.sh --dry-run -y >/tmp/step1.log 2>&1; then
		report pass "1 bootstrap --dry-run -y"
	else
		rc=$?
		report fail "1 bootstrap --dry-run -y" "exit $rc"
		tail_log /tmp/step1.log
	fi
fi

echo "=== step 2: deploy ==="
if bash /work/scripts/deploy.sh >/tmp/step2.log 2>&1; then
	report pass "2 deploy.sh"
else
	rc=$?
	report fail "2 deploy.sh" "exit $rc"
	tail_log /tmp/step2.log
fi

echo "=== step 3: deployment assertions ==="
hooks_path="$(git config --global core.hooksPath)"
if [ -f "$HOME/.dotfiles-installed" ] && [ "$hooks_path" = "$HOME/.config/git/hooks" ]; then
	report pass "3 marker and core.hooksPath" "hooksPath=$hooks_path"
else
	report fail "3 marker and core.hooksPath" "marker=$([ -f "$HOME/.dotfiles-installed" ] && echo present || echo missing), hooksPath=$hooks_path"
fi

echo "=== step 4: commit-msg on a real repo ==="
repo="$(mktemp -d)"
(
	cd "$repo"
	git init -q
	echo hi >file.txt
	git add file.txt
) >/tmp/step4.log 2>&1
if (cd "$repo" && git commit -q -m "garbage message that no convention allows") >/tmp/step4a.log 2>&1; then
	report fail "4 commit-msg rejects garbage" "commit was accepted"
else
	report pass "4 commit-msg rejects garbage"
fi
if (cd "$repo" && git commit -q -m "fix: valid conventional subject") >/tmp/step4b.log 2>&1; then
	report pass "4b commit-msg accepts a valid subject"
else
	rc=$?
	report fail "4b commit-msg accepts a valid subject" "exit $rc, so step 4 may have failed in pre-commit instead"
	tail_log /tmp/step4b.log
fi

echo "=== step 5: healthcheck ==="
if bash /work/scripts/healthcheck.sh >/tmp/step5.log 2>&1; then
	report pass "5 healthcheck exit 0 with optional tools missing"
else
	rc=$?
	report fail "5 healthcheck exit 0 with optional tools missing" "exit $rc, optional tools counted as FAIL (defect L9)"
	echo "    $(grep -c '\[FAIL\]' /tmp/step5.log) FAIL lines, first few:"
	grep '\[FAIL\]' /tmp/step5.log | head -n 5 | sed 's/^/    | /'
fi

echo "=== step 6: backup then non-interactive restore ==="
if ! bash /work/scripts/backup.sh >/tmp/step6-backup.log 2>&1; then
	rc=$?
	report fail "6 restore non-interactive" "precondition backup.sh exit $rc"
	tail_log /tmp/step6-backup.log
else
	name="$(ls -1t "$HOME/.dotfiles-backup" | head -n 1)"
	if bash /work/scripts/restore.sh "$name" --force >/tmp/step6.log 2>&1; then
		report pass "6 restore non-interactive" "restored $name with --force"
	else
		rc=$?
		report fail "6 restore non-interactive" "restore.sh $name --force exit $rc"
		tail_log /tmp/step6.log
	fi
fi

echo "=== step 7: uninstall driven with piped y ==="
rc=0
yes y | bash /work/scripts/uninstall.sh >/tmp/step7.log 2>&1 || rc=$?
removed=0
for p in "$HOME/.gitconfig" "$HOME/.bash_aliases" "$HOME/.zshrc"; do
	[ -e "$p" ] || removed=1
done
if [ "$rc" -eq 0 ] && [ "$removed" -eq 1 ]; then
	report pass "7 uninstall with piped y"
else
	report fail "7 uninstall with piped y" "exit $rc, removed_any=$removed, single-char y never matches the ^[Yy]es$ prompt regex (defect L1)"
	tail_log /tmp/step7.log
fi

echo
echo "=== summary: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -ne 0 ]; then
	printf 'failed steps: %s\n' "${FAILED[*]}"
	exit 1
fi
exit 0
EOS
)

echo "=== e2e-linux: image $IMAGE, repo $ROOT ==="
# MSYS_NO_PATHCONV stops Git Bash from rewriting /src and /work into Windows paths
MSYS_NO_PATHCONV=1 docker run --rm \
	-e HOME=/home/tester \
	-e FULL="${FULL:-0}" \
	--user tester \
	--workdir /work \
	-v "${ROOT}:/src:ro" \
	"${IMAGE}" \
	bash -c "${INNER}"
