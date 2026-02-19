# Development Protocol

## Prime Directives

1. Verify everything. Check official docs before coding. Query current date first.
2. Never hardcode. Generalize all solutions, even for "quick tests".
3. Never modify tests to pass. Fix root causes only.
4. Never run migrations manually. Use docker compose up -d exclusively.
5. Own your changes. Fix flaky tests and regressions you cause.
6. No bypassing. Never twist configs or tests to fake success.

## Tool Hierarchy

- Default Behavior: Always use built-in tools and actions, including sub-agents and agent team when appropriate, only looking for external tools when the built-in aren't capable of efficiently achieve your goal.
- Plugin Skills: Use plugins (feature-dev, frontend-design, planning, diagnostics, etc.) and skills when available instead of reinventing analysis.
- MCPs: WebSearch, WebFetch, Vision, ZRead, Context7, Repomix, Playwright, Serena.
- Last resort: Only use generic bash scripting or brittle regex when the above tools lack the capability.

## Code Standards

- TDD: Write failing test first, minimal code to pass, refactor.
- Atomic commits. Include tests and implementation in same commit.
- Plain style. No bold, emojis, decorative comments, or editorializing.
- Conventional Commits: feat, fix, docs, refactor, test, chore.
- No Co-Authored-By lines or watermarks.

## Testing Strategy

- Unit Tests for: Specific input/output pairs, edge cases, error paths.
- Property-Based Tests for: Invariants, commutativity, idempotency, round-trip serialization.

## Workflow

### Before Coding
1. Check current date/year for temporal context.
2. Explore codebase structure and patterns.
3. Verify current syntax and versions (do not rely on training data).
4. Define: Goal, Acceptance Criteria, Definition of Done (files off-limits), Non-goals.

### Trivial Edits Exception
For typos or one-line non-logic changes: skip requirements, run linter, commit.

### Verification Chain
Run in order, committing at each green step:
1. Feature-specific tests
2. Formatters
3. Linters
4. Type checkers
5. Full unit test suite
6. Full E2E suite
7. Visual regression (if applicable)

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
