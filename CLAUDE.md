# CLAUDE.md

## Non-Negotiables

- Strict TDD is mandatory: Write failing test first (test-as-documentation, one-at-a-time, regression-proof, table-driven, test-doubles) -> minimal code to pass -> refactor -> using linters & formatters.
- Always research the latest and up-to-date information and official documentation before implement any thing to prevent hallucinated syntax.
- Adversarial Cooperation: Rigorously check against linters and hostile unit tests or security exploits. If complexity requires, utilize parallel Tasks, Consensus Voting, Synthetic and Fuzzy Test Case Generation with high-quality examples and high volume variations.
- Only trust independent verification: Never claim "done" without test output and command evidence.
- Commits & Comments: No watermarks. No `Co-Authored-By` lines. Only plain simple text, maybe with unordered dash list or numbered list, avoid em/en dashes or bolting or italicizing or emojis. For comments, always in my humble voice and stay as unconfrontational as possible and phrase most things as constructive questions.
  - Conventions: Use Conventional Commits (feat, fix, docs, refactor, test, chore).
  - Granularity: Atomic commits. If the logic changes, the test must be committed in the same SHA.
  - Security: Never commit secrets. If a test requires a secret, it must use environment variables or skipped if the variable is missing.

## Core Workflow

### Requirements Contract (Non-Trivial Tasks)

#### Before coding, define

1. Goal: What are we solving?
2. Acceptance Criteria: Testable conditions for success.
3. Definition of Done: Explicitly state what files will **NOT** be touched to prevent scope creep.
4. Non-goals & Constraints: What are we avoiding?
5. Verification Plan: How will we prove it works?
6. Security Review: Briefly scan input/output for injection risks or PII leaks.

If you cannot write acceptance criteria, pause and clarify.

#### Tool Usage

- Repomix: Use to explore and pack the repository for full-structure views.
- Context7: Use to acquire up-to-date, version-specific documentation for any library/API.
- Vision MCP: Use for image understanding.
- Playwright: Use for interactive browser-based E2E tests and UI debugging.
- Web Search MCP or Web Reader MCP: Use to acquire latest documentations or information.
- ZRead MCP: Use for documentation search, repository structure exploration, and code reading on GitHub.
- GitHub CLI: Use `gh` for PR/Issue operations.
- Offline Docs: Use `go doc` or `x --help` or `man x` or equivalences for accurate command references.

### Verification Minimum

Detect the environment and run the **strict** verification chain. If a `Makefile`, `Justfile`, or `Taskfile` exists, prioritize the below first and then apply standard targets after (e.g., `make check`, `just test`).

E.g. Go Verification

```bash
go mod tidy && golangci-lint fmt && golangci-lint run --no-config --timeout=5m && CGO_ENABLED=1 go test ./... -race -cover --coverprofile=coverage.out && go tool cover -func coverage.out && CGO_ENABLED=1 go test -bench
```

And for UI tasks:

- If there's a `make screenshots` run it and check the output images in `./assets/` to verify the work with Vision MCP
- If there's no such mechanism for self-verification, make such script using Playwright and do the check with Vision MCP

### Context Hygiene

If a conversation exceeds 64 turns or context becomes stale:

1. Summarize: Create `checkpoint.md` capturing: Current Goal, Recent Changes, Next Immediate Step, List of Open Questions.
2. Verify: Ensure `checkpoint.md` is committed.
3. Reset: Instruct user to `/compact` (or clear context) and read `checkpoint.md`.

### When Stuck (3 Failed Attempts)

1. Stop coding. Return to last green state (git reset).
2. Re-read requirements. Verify you are solving the RIGHT problem.
3. Decompose into atomic TDD increments: Recursively break the feature into smallest testable units—one behavior or assertion per test. Each subtask targets a single red-green-refactor cycle (<10 lines of code), starting from the leaves (e.g., simplest function) and building up, to maintain steady progress and isolate failures.
4. Constraint: You are forbidden from modifying the test logic to force a pass unless the Requirements Contract has changed.
5. Spawn 2-8 parallel diagnostic tasks via Task tool.
6. If still blocked → escalate to human with findings.

### Parallel Exploration (Task Tool)

Use for: uncertain decisions, codebase surveys, implementing and voting on approaches.

- Cleanup: Use Git Worktree if necessary, but strictly ensure cleanup (`git worktree remove` and branch deletion) occurs regardless of success/failure via a `defer` or `trap` mechanism, or just standard branching if sufficient.
- Independence: Paraphrase prompts for each agent to ensure cognitive diversity.
- Voting: Prefer simpler, more testable proposals.
- Consensus Protocol: When agents disagree, prioritize the solution with the fewest dependencies and highest test coverage. Discard "clever" solutions in favor of "boring" standard library usage.

### Workflow Exception: Trivial Edits

For simple typo fixes, comment updates, or one-line non-logic changes:

1. Skip the "Requirements Contract."
2. Run the linter/formatter only.
3. Commit immediately.

## Beware Language Specific Pitfalls

E.g. Go

- CGO_ENABLED=1: Always prefix Go commands with this (SQLite and Race Detection require CGO).
- Gen Directories: Never edit `gen/`. Run `go generate`, `protoc`, or `sqlc` to regenerate.
