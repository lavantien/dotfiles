SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c

E2E_IMAGE := dotfiles-e2e
# Wave 1 debt gate carve-outs, format file:SC code. Delete each entry when
# its owning slot lands the fix so the gate never hides new errors.
KNOWN_SHELLCHECK_ERRORS :=

PSSA_LINT := pwsh -NoProfile -Command 'if (-not (Get-Module -ListAvailable PSScriptAnalyzer)) { "skip: PSScriptAnalyzer not installed"; exit 0 }; $$files = @(git ls-files -- "*.ps1"); if ($$files.Count -eq 0) { exit 0 }; $$findings = @(Invoke-ScriptAnalyzer -Path $$files -Severity Error); if ($$findings.Count -gt 0) { foreach ($$x in $$findings) { "{0}:{1}:{2}: {3}" -f $$x.ScriptName, $$x.Line, $$x.Column, $$x.Message }; exit 1 }; "PSScriptAnalyzer: 0 errors in $$($$files.Count) files"'
PSSA_FORMAT := pwsh -NoProfile -Command 'if (-not (Get-Module -ListAvailable PSScriptAnalyzer)) { "skip: PSScriptAnalyzer not installed"; exit 0 }; foreach ($$f in @(git ls-files -- "*.ps1")) { $$c = Get-Content -Raw $$f; $$n = Invoke-Formatter $$c; if ($$n -ne $$c) { Set-Content -NoNewline -Path $$f -Value $$n; "formatted: $$f" } }'

.DEFAULT_GOAL := help

.PHONY: help baseline lint format test check e2e-linux e2e-windows

help: ## list targets
	@printf '%-14s %s\n' target description
	@awk '/^[a-zA-Z][a-zA-Z0-9-]*:.*##/ { t = $$0; sub(/:.*/, "", t); d = $$0; sub(/^[^#]*##[ \t]*/, "", d); printf "  %-12s %s\n", t, d }' $(MAKEFILE_LIST)

baseline: ## print shellcheck error and warning counts per tracked .sh file, read only
	@printf '%-44s %7s %9s\n' file errors warnings
	@te=0; tw=0; \
	while IFS= read -r -d '' f; do \
		out=$$(shellcheck -f gcc "$$f" 2>/dev/null || true); \
		e=$$(printf '%s\n' "$$out" | grep -c 'error:' || true); \
		w=$$(printf '%s\n' "$$out" | grep -c 'warning:' || true); \
		if [ "$$e" != 0 ] || [ "$$w" != 0 ]; then printf '%-44s %7s %9s\n' "$$f" "$$e" "$$w"; fi; \
		te=$$((te + e)); tw=$$((tw + w)); \
	done < <(git ls-files -z -- '*.sh'); \
	printf '%-44s %7s %9s\n' total "$$te" "$$tw"

lint: ## shellcheck error gate, shfmt diff, selene, typos, PSSA when installed
	@echo '== shellcheck (gate on errors, see make baseline for warnings) =='
	@status=0; known=' $(KNOWN_SHELLCHECK_ERRORS) '; \
	while IFS= read -r -d '' f; do \
		while IFS= read -r finding; do \
			[ -n "$$finding" ] || continue; \
			code=$$(printf '%s' "$$finding" | grep -oE 'SC[0-9]+' | head -1); \
			case "$$known" in *" $$f:$$code "*) echo "KNOWN (wave 1 debt): $$finding" ;; *) echo "$$finding"; status=1 ;; esac; \
		done < <(shellcheck --severity=error -f gcc "$$f" 2>/dev/null || true); \
	done < <(git ls-files -z -- '*.sh'); \
	if [ "$$status" -eq 0 ]; then echo 'shellcheck: 0 errors'; else exit 1; fi
	@echo '== shfmt (diff, -ln bash) =='
	@git ls-files -z -- '*.sh' | xargs -0 shfmt -ln bash -d && echo 'shfmt: clean'
	@echo '== selene =='
	@selene .
	@echo '== typos =='
	@typos
	@echo '== PSScriptAnalyzer =='
	@command -v pwsh >/dev/null 2>&1 || { echo 'skip: pwsh not installed'; exit 0; }
	@$(PSSA_LINT)

format: ## shfmt rewrite, typos fix, Invoke-Formatter for .ps1 when installed
	@git ls-files -z -- '*.sh' | xargs -0 shfmt -ln bash -w
	@typos -w
	@command -v pwsh >/dev/null 2>&1 || { echo 'skip: pwsh not installed'; exit 0; }
	@$(PSSA_FORMAT)

test: ## run the bats suite under tests/
	@bats tests/ -r

check: lint test ## lint plus tests, no e2e, fast default gate

e2e-linux: ## docker linux lifecycle harness, skips when the daemon is down
	@command -v timeout >/dev/null 2>&1 && guard='timeout 10 docker info' || guard='docker info'; \
	if $$guard >/dev/null 2>&1; then \
		docker build -q -t $(E2E_IMAGE) tests/e2e >/dev/null; \
		FULL='$(FULL)' bash tests/e2e/run.sh '$(E2E_IMAGE)'; \
	else \
		echo 'skip: docker daemon not running'; \
	fi

e2e-windows: ## bootstrap.ps1 dry run, deploy.ps1 against an isolated HOME, PSSA pass
	@command -v pwsh >/dev/null 2>&1 || { echo 'skip: pwsh not installed'; exit 0; }
	@tmp=$$(mktemp -d); root="$$(pwd -W 2>/dev/null || pwd)"; \
	echo "isolated HOME: $$tmp"; \
	HOME="$$tmp" USERPROFILE="$$tmp" pwsh -NoProfile -File bootstrap/bootstrap.ps1 -DryRun -Y; \
	HOME="$$tmp" USERPROFILE="$$tmp" pwsh -NoProfile -File scripts/deploy.ps1 -DotfilesDir "$$root" -SkipConfig; \
	test -f "$$tmp/dev/git-update-repos.sh"; \
	echo 'deploy.ps1 wrote only inside the isolated HOME'; \
	rm -rf "$$tmp"; \
	echo '== PSScriptAnalyzer =='; \
	$(PSSA_LINT)
