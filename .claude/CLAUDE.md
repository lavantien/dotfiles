# Development Protocol

## Rules

1. Verify first. Check official docs and current syntax/versions before coding -- training data goes stale.
2. Generalize. Never hardcode or manually copy. Every solution must be programmatically coherent, even "quick tests".
3. Fix root causes only. Never modify tests to pass, twist configs to fake success, or dismiss failures as pre-existing. Own every error.
4. Keep it plain. No overcomplicating, decorative comments, emojis, bold, editorializing, or Co-Authored-By watermarks.
5. Never use manual bash commands for editing files to avoid corruption and side effects.
6. No manual migrations. Use `docker compose up -d` exclusively.
7. Max 400 SLOC per file. Conventional Commits: feat, fix, docs, refactor, test, chore.

## Tool Hierarchy

- Built-in first. Use tools, sub-agents, and agent teams. Escalate to external tools only when built-ins cannot do the job efficiently.
- Sub-agents: Always use the latest big model (i.e. GLM-5.1) for sub-agents and agent teams.
- Plugin Skills: Use plugins (feature-dev, frontend-design, planning, diagnostics, etc.) and skills when available instead of reinventing analysis.
- MCPs: WebSearch, WebFetch, Vision, ZRead, Context7, Repomix, Playwright, Serena.
- Last resort: Only use generic bash scripting or brittle regex when the above tools lack the capability.

## Testing

- TDD: Write failing test first, minimal code to pass, refactor.
- Baseline first: Before implementing with TDD, run all the tests and coverage and benchmark first to establish the baseline, so that regression become apparent. Fix any existing failures.
- Unit tests for: input/output pairs, edge cases, error paths.
- Property-based tests for: invariants, commutativity, idempotency, round-trip serialization.
- No skipped tests. Detect and re-enable. Investigate root causes.
- Atomic commits. Include tests and implementation in same commit.

### Verification Chain

Run in order, committing at each green step:
1. Feature-specific tests
2. Formatters
3. Linters
4. Type checkers
5. Full unit test suite
6. Full E2E suite
7. Visual regression (if applicable)

## Workflow

### Before Coding
1. Check current date/year for temporal context.
2. Explore codebase structure and patterns.
3. Define: Goal, Acceptance Criteria, Definition of Done (files off-limits), Non-goals.

### Trivial Edits
For typos or one-line non-logic changes: skip requirements, run linter, commit.

### When Stuck
Write one-off programs in `./playground` to isolate and test intent/hypothesis.

## Language Pitfalls

Go:
- Prefix commands with CGO_ENABLED=1 (required for SQLite and race detection).
- Never edit gen/ directories. Run go generate.

C#:
- Never edit obj/ or bin/.
- Enable nullable reference types.
- Never block on async (no .Result or .Wait()).
- Prefer LINQ except in hot paths.

Windows:
- Use pwsh.exe (v7+), never powershell.exe (v5.1).
