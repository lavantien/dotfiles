# CLAUDE.md

<non-negotiables>

<mandatory-enforcements>

**ALWAYS VERIFY, DO NOT ASSUME: ALWAYS DOUBLE-CHECK AND INDEPENDENTLY VERIFY BEFORE WRITING OR EXECUTING ANYTHING: WE SHOULD'VE NEVER RUN INTO SYNTAX ERRORS OR INCORRECT USAGES IN THIS INTERNET AGE**, always query for the current date and year first to get correct temporal perspective, do not blindly execute scripts without first checking the exact location, nor running/implementing something without first lookup online official sources for the up-to-date information and correct usage, we must avoid outdated commands and code and references at all cost, mostly trust human handouts and intuition because they might have researched themselves and hand you direct commands to use or correct direction

**NEVER HARDCODE ANYTHING HOWEVER SMALL; NEVER OVER COMPLICATING THINGS OR ADDING BLUFF COMMENTS; ALWAYS STICK TO SIMPLE PLAINTEXT AND LISTS WITH MERMAID OR TYPSTAND WITHOUT FANCY FORMATTING OR BOLDENING**, even just for testing, we should always be able to generalize, keep all things as simple as possible, and we should never spam comments in code, and avoid at all cost all AI-generated signs and complex wordings

**NEVER DELETE OR MODIFY SOMETHING JUST TO PASS TESTS**, the tests are there to prevent us from regressing and protect the work we've done. Find the root cause, trace deep, research online if you have to

**NEVER RUN MIGRATION MANUALLY**, it's an indicator of a deeper problem that needs to be resolved, just shut down and reset all and do via our only door, e.g. `docker compose up -d`

**ADDRESS ANY FLAKY ISSUE, WE NEED TO ENSURE IDEMPOTENCY, IT'S ALWAYS YOUR CHANGES AND RELATES TO YOUR WORK**, you have ownership of this repo, so do not shy away from addressing any issue that comes up

</mandatory-enforcements>

<mandatory-verification-loop>

1. pre implement: check online official sources for correct/up-to-date syntaxes and usages, and local repo's documentations and patterns for correct perspective
2. implement: follow strict TDD as instructed in CLAUDE.md
3. verification: run the specific tests and checks -> formatters -> linters -> typecheckers -> atomic commit the checkpoint; also follow the `<verification-minimum>` section
4. anti regression: run full unit test suite -> then run full e2e test flow -> then run content/consolelog check for all pages/endpoints -> then run the full screenshot regeneration

</mandatory-verification-loop>

<mandatory-enforcements>

- Strict TDD is mandatory: Write failing test first (test-as-documentation, one-at-a-time, regression-proof, table-driven, test-doubles) -> minimal code to pass -> refactor -> using linters & formatters.
- Always research the latest and up-to-date information and official documentation before implementing anything to prevent hallucinated syntax.
- Adversarial Cooperation: Rigorously check against linters and hostile unit tests or security exploits. If complexity requires, utilize the built-in Task Management System and parallel Tasks, Consensus Voting, Synthetic and Fuzzy Test Case Generation with high-quality examples and high volume variations.
- Only trust independent verification: Never claim "done" without test output and command evidence. Make sure there are no regressions whatsoever. We need strong foundations and rock-solid iterations.
- Commits & Comments: No watermarks. No Co-Authored-By lines. Only plain simple text, maybe with unordered dash list or numbered list, avoid em/en dashes or bolding or italicizing or emojis. For comments, always in my humble voice and stay as unconfrontational as possible and phrase most things as constructive questions.
  - Conventions: Use Conventional Commits (feat, fix, docs, refactor, test, chore).
  - Granularity: Atomic commits. If the logic changes, the test must be committed in the same SHA.
  - Security: Never commit secrets. If a test requires a secret, it must use environment variables or skipped if the variable is missing.

</mandatory-enforcements>

</non-negotiables>

<core-workflow>

<requirements-contract-non-trivial-tasks>

<before-coding-define>

1. Goal: What are we solving?
2. Acceptance Criteria: Testable conditions for success.
3. Definition of Done: Explicitly state what files will NOT be touched to prevent scope creep.
4. Non-goals & Constraints: What are we avoiding?
5. Verification Plan: How will we prove it works?
6. Security Review: Briefly scan input/output for injection risks or PII leaks.
7. Detailed Tasks Plan: Derive full detailed tasks plans with correct depedencies for parallel sub-agentic tasks execution. 

If you cannot write acceptance criteria, pause and continuously clarify.

</before-coding-define>

</requirements-contract-non-trivial-tasks>

<tool-usage>

Always consider and optimally utilize all built-in tools and available plugins before resorting to more expensive operations.

- Repomix: Use to explore and pack the repository for full-structure views.
- Context7: Use to acquire up-to-date, version-specific documentation for any library/API.
- Vision MCP: Use for image understanding.
- Playwright: Use for interactive browser-based E2E tests and UI debugging.
- Web Search MCP or Web Reader MCP: Use to acquire latest documentation or information.
- ZRead MCP: Use for documentation search, repository structure exploration, and code reading on GitHub.
- GitHub CLI: Use gh for PR/Issue operations.
- Serena MCP: Use for semantic code retrieval, symbol-level editing, find/referencing symbols, and LSP-based code navigation.
- Offline Docs: Use go doc or x --help or man x or equivalents for accurate command references.

</tool-usage>

<file-handling>

For working with diverse files like documents, slideshows, spreadsheets, or PDFs:

- Transpile them to plain text or markdown first
- Read attached images if present
- Use tools like pandoc for document conversion
- Use python-docx for Word documents
- Use python-pptx for PowerPoint presentations
- Use standard CSV handling for spreadsheets
- Or use Vision capabilities to spot nuances
- The possibilities are endless

</file-handling>

<research-before-implementation>

Before writing any code, always verify current best practices. Never rely on training data for API syntax, library versions, or installation commands.

1. Latest Documentation: Use Context7 MCP to get up-to-date library docs
   - First: find the library
   - Then: get specific info

2. Web Search: for:
   - Latest library versions and syntax
   - Breaking changes in recent releases
   - Current best practices (patterns change over time)

3. Web Reader: for:
   - Reading official documentation pages
   - Checking GitHub repositories for examples
   - Fetching specific documentation URLs

4. ZRead: for:
   - Searching GitHub repositories
   - Reading repository documentation
   - Exploring codebases

5. GitHub CLI: gh for:
   - Searching issues and PRs
   - Reading repository files
   - Checking latest releases

6. Repomix: for:
   - Packing local codebases for analysis
   - Searching packed outputs with grep
   - Creating project skills from code

7. LSP-TreeSitter or Serena: Use built-in LSP tools for:
   - Finding symbol definitions and references
   - Getting hover information and document symbols
   - Understanding code relationships before making changes

</research-before-implementation>

<verification-minimum>

Detect the environment and run the strict verification chain. If a Makefile, Justfile, or Taskfile exists, prioritize the below first and then apply standard targets after (e.g., make check, just test).

E.g. Go Verification

```bash
go mod tidy && golangci-lint fmt && golangci-lint run --no-config --timeout=5m && CGO_ENABLED=1 go test ./... -race -cover --coverprofile=coverage.out && go tool cover -func coverage.out && CGO_ENABLED=1 go test -bench
```

And for UI tasks:

- If there's a make screenshots run it and check the output images in ./assets/ to verify the work with Vision MCP
- If there's no such mechanism for self-verification, make such script using Playwright and do the check with Vision MCP

</verification-minimum>

<context-hygiene>

If a conversation exceeds 32 turns or context becomes stale:

1. Summarize: Create checkpoint.md capturing: Current Goal, Recent Changes, Next Immediate Step, List of Open Questions.
2. Verify: Ensure checkpoint.md is committed.
3. Reset: Instruct user to /compact (or clear context) and read checkpoint.md.

</context-hygiene>

<when-stuck-3-failed-attempts>

1. Stop coding. Return to last green state (git reset).
2. Re-read requirements. Verify you are solving the RIGHT problem.
3. Decompose into atomic TDD increments: Recursively break the feature into smallest testable units - one behavior or assertion per test. Each subtask targets a single red-green-refactor cycle (<10 lines of code), starting from the leaves (e.g., simplest function) and building up, to maintain steady progress and isolate failures.
4. Constraint: You are forbidden from modifying the test logic to force a pass unless the Requirements Contract has changed.
5. Spawn 2-8 parallel diagnostic tasks via Task tool.
6. If still blocked -> escalate to human with findings.

</when-stuck-3-failed-attempts>

<parallel-exploration-task-tool>

Use for: implementing independent tasks, uncertain decisions, codebase surveys, implementing and voting on approaches.

- Cleanup: Use Git Worktree if necessary, but strictly ensure cleanup (git worktree remove and branch deletion) occurs regardless of success/failure via a defer or trap mechanism, or just standard branching if sufficient.
- Independence: Paraphrase prompts for each agent to ensure cognitive diversity.
- Voting: Prefer simpler, more testable proposals.
- Consensus Protocol: When agents disagree, prioritize the solution with the fewest dependencies and highest test coverage. Discard clever solutions in favor of boring standard library usage.

</parallel-exploration-task-tool>

<workflow-exception-trivial-edits>

For simple typo fixes, comment updates, or one-line non-logic changes:

1. Skip the "Requirements Contract."
2. Run the linter/formatter only.
3. Commit immediately.

</workflow-exception-trivial-edits>

<testing-strategy>

<property-based-testing-vs-unit-tests>

Choose the appropriate testing approach based on what you are validating.

Use Unit Tests for:

- Business logic with specific input/output pairs
- Edge cases and boundary conditions
- Error handling paths
- Individual function behavior

Use Property-Based Testing for:

- Invariants that should hold for ANY valid input
- Commutativity, associativity, idempotency properties
- Round-trip serialization/deserialization
- State transitions in state machines

Examples:

Property-based (QuickCheck/propcheck style):

- "For any list, reversing twice returns the original"
- "For any valid JSON string, parse -> stringify -> parse yields the same value"
- "For any two numbers a, b: add(a, b) == add(b, a)"

Unit test:

- "Given empty list, return error"
- "Given user ID 123, return User object with name='John'"
- "Given negative input, throw ValueError"

When implementing features with complex invariants, prefer property-based tests with hundreds of auto-generated cases over manually written unit tests.

</property-based-testing-vs-unit-tests>

</testing-strategy>

<beware-language-specific-pitfalls>

E.g. Go

- CGO_ENABLED=1: Always prefix Go commands with this (SQLite and Race Detection require CGO).
- Gen Directories: Never edit gen/. Run go generate, protoc, or sqlc to regenerate.

</beware-language-specific-pitfalls>

<windows-specific-notes>

- PowerShell: Windows should use pwsh.exe for PowerShell 7+, NOT powershell.exe (Windows PowerShell 5.1) or PowerShell from Git Bash because these are severely outdated and lack modern features.

</windows-specific-notes>

</core-workflow>
