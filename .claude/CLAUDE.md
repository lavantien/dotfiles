# Development Protocol

## Prime Directives

1. Verify everything. Check official docs before coding. Query current date first.
2. Never hardcode. Generalize all solutions, even for "quick tests".
3. Never modify tests to pass. Fix root causes only.
4. Never run migrations manually. Use docker compose up -d exclusively.
5. Own your changes. Fix flaky tests and regressions you cause.
6. No bypassing. Never twist configs or tests to fake success.

## Tool Hierarchy

**For coding tasks (default):** Use Serena MCP for precise searches, edits, refactors, symbol lookups, and large/ongoing work.

**For repository overview:** Use Repomix when full-structure context is needed, then switch to Serena for implementation.

**For specialized operations:**
- Context7 MCP: Version-specific library documentation
- Web Search/Reader: Breaking changes, latest syntax
- ZRead/GitHub CLI: Remote repo exploration
- Vision MCP: Image verification and UI debugging
- Playwright: E2E testing and interaction
- Task tool: Parallel sub-agents for independent work

**Plugin Skills:** Use feature-dev plugins (brainstorming, planning, diagnostics) and project-specific skills when available instead of reinventing analysis.

**Last resort:** Only use generic bash scripting or brittle regex when the above tools lack the capability.

## Code Standards

- TDD: Write failing test first, minimal code to pass, refactor.
- Atomic commits. Include tests and implementation in same commit.
- Plain style. No bold, emojis, decorative comments, or editorializing.
- Conventional Commits: feat, fix, docs, refactor, test, chore.
- No Co-Authored-By lines or watermarks.

## Testing Strategy

Unit Tests for: Specific input/output pairs, edge cases, error paths.

Property-Based Tests for: Invariants, commutativity, idempotency, round-trip serialization.

## Workflow

### Before Coding
1. Check current date/year for temporal context.
2. Serena: Explore codebase structure and patterns.
3. Context7/Web Search: Verify current syntax and versions (do not rely on training data).
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

## When Stuck

After 3 failed attempts:
1. Git reset to last green state.
2. Re-read requirements.
3. Serena: Trace symbols and references to understand dependencies.
4. Create minimal reproduction in ./playground.
5. Decompose to atomic TDD cycles (target &lt;10 lines each).
6. Spawn 2-8 parallel diagnostic tasks via Task tool.
7. Escalate to human with findings.

## Context Hygiene

At 32 turns:
1. Write checkpoint.md: Current Goal, Recent Changes, Next Step, Open Questions.
2. Commit it.
3. Reset context and resume from checkpoint.

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