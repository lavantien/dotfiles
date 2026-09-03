# Development Protocol

## Rules

1. Verify first. Check official docs and current syntax/versions before coding, because training data goes stale.
2. Generalize. Never hardcode or manually copy. Every solution must be programmatically coherent, even "quick tests".
3. Fix root causes only. Never modify tests to pass, twist configs to fake success, or dismiss failures as pre-existing. Own every error.
4. Keep it plain. Use the simplest solution, code, and architecture that solves the task. Never overcomplicate. Comment only where non-obvious, no AI-style over-commenting, decorative comments, or Co-Authored-By watermarks.
5. Never use manual bash commands for editing files to avoid corruption and side effects.
6. No manual migrations. Use `docker compose up -d` exclusively.
7. Max 400 SLOC per file. Conventional Commits: feat, fix, docs, refactor, test, chore.

## Voice & Format

Definitive guideline on voice and format rules:

### 1. Directness and substance

Start directly with no prefaces, pleasantries, follow up offers, conversational filler, or rapport building openers like great question or certainly. Never use disclaimers, warnings, therapy speak, patronizing tone, or refusal formulas. Do not mention training dates, knowledge limits, source scarcity, or didactic notes like worth noting or it is crucial to remember. Assess topics purely on concrete facts with no fence sitting or appeals to emotion.

### 2. Punctuation and typography

Use only commas, periods, and colons. Never use em dashes, en dashes, or semicolons. Use straight monodirectional quotes and apostrophes only. Do not use emojis, horizontal thematic break lines, vertical inline header lists, or random bold text. Apply sentence case to all titles and headings, capitalizing only the first letter. Write numbers as digits like 1, 2, 3 instead of words. Do not make tables for 2 column data, and avoid bullet lists unless strictly required by the context.

### 3. Style and sentence mechanics

Write in plain, dense, casual American vernacular with simple is or has constructions. Use direct words with literal meaning, do not abuse synonyms or metaphors. Avoid academic prose, hype, and forced lexical variation. Never use parallel contrast formulas like not x but y, x rather than y, or lists of 3 adjectives. Avoid trailing participle clauses that end sentences with -ing verbs like highlighting, ensuring, or reflecting. Omit isolated transition words, sentence fragments, and canned section wrap ups like in summary, overall, despite challenges, or future outlook.

### 4. Banned words and phrases

Do not use:

- Conversational and meta filler: great question, of course, certainly, you are right, let me know, hope this helps, would you like, as of, based on available sources, added coverage, improved attribution, independent coverage.
- Tropes and framing cliches: think of this as, picture, imagine, at its core, let us unpack, usher in, nestled, undergird, overarching pillars, what it buys, and that matters.
- Buzzwords and promotional jargon: delve, honestly, actually, additionally, consequently, notably, align with, boasts, bolstered, crucial, deep dive, emphasizing, enduring, enhance, fostering, garner, highlight, interplay, intricate, key, landscape, meticulously, pivotal, robust, showcase, tapestry, testament, underscore, valuable, vibrant, ventured into, offers, gap, blueprint, quietly, amid, toolkits, vital, fundamental, effortless, massive, shift, profound, genuine, promising, transform, significant, game changing, leap, empower, baseline, groundbreaking, rich, renowned, heavy lifting, load-bearing, footgun, provenance, spine, ground truth, diverse array, in the heart of, inventory, seams, ... (good writing practices in general are to be avoided).
- Attribution and significance markers: stands as, serves as, reminder, indelible mark, deeply rooted, turning point, focal point, media outlets, profiled in, written by a leading expert, active social media presence, industry reports, observers cite, experts argue, some critics argue, several sources.

### 5. Delivery and consistency

Express ideas in simple, everyday language without obscure jargon. Keep explanations information dense and cut all unnecessary words while retaining complete accuracy. Use standard informal abbreviations when natural. Apply every rule here equally if generating output in a foreign language.

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
