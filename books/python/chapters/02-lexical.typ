#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= lexical structure

Before a program has objects or functions it is text, and cpython walks a
fixed path from text to bytecode: physical lines become logical lines,
logical lines become a stream of tokens, and the parser consumes that
stream. This chapter covers that front half, plus the two ways source text
names things: identifiers against the keyword lists, and the assignment
expression `:=`. Every claim is pinned by one of the 41 checks across the
four samples, run on cpython 3.14.7 through the gate from
#xref-to("python", "toolchain"), or by a syntax diagnostic captured on
this machine.

== lines, indentation, blocks

A physical line ends at a newline character. A logical line is what the
tokenizer hands the parser, and most of the time the two coincide. Two
constructs join physical lines without ending the logical one: a backslash
as the last character, and anything inside `(`, `[`, or `{`. A third rule
empties lines out: a line that is blank or holds only a comment produces
no logical line at all. The sample pins all of it, and because the book
formats its samples with ruff, which rewrites backslash joins into
bracketed joins and deletes blank lines inside brackets, the join facts
are probed through `compile()` strings so the listings stay stable:

#listing("python/samples/src/Ch02/lines.py", first: 18, last: 33, caption: [bracket joins carry newlines, backslash joins and blank lines survive as compile probes])

The bracket join on line 18 is the spelling the formatter itself emits.
The two probes under it compile source held in strings: a backslash join
produces one 4 character string, and a blank physical line between the
elements of a bracketed list is simply ignored. The backslash is the more
fragile of the two joins because nothing may follow it, not even a
comment:

#listing("python/samples/src/Ch02/lines.py", first: 35, last: 42, caption: [a comment after the continuation backslash is a hard error])

The diagnostic on this build reads `unexpected character after line
continuation character` (probed 2026-09-12). Indentation is the other half
of line structure. The reference fixes no width: any consistent step works,
tabs measure as one to eight spaces advancing to the next multiple of 8,
and the interpreter rejects a layout whose meaning depends on the worth of
a tab with a `TabError`:

#listing("python/samples/src/Ch02/lines.py", first: 44, last: 59, caption: [tab consistent and two space layouts compile, the mixed layout cannot])

The first source uses tabs throughout and returns 7. The second indents
with 2 spaces, proving width is a project choice. The third interleaves
them: the `if` body sits at column 8 via spaces, the nested block at
column 16 via tabs, and the closing `return` at column 8 via spaces again,
so the same column is reached by different mixes and the stack comparison
turns ambiguous.

#callout("pitfall", "the formatter and the join spellings", [
  Running `ruff format` on a file that uses a backslash join or a blank
  line inside brackets rewrites both: the backslash becomes a bracketed
  join, the blank line disappears (probed with ruff 0.16.7 on
  2026-09-24). That is why the samples pin these facts through
  `compile()` probes instead of executable spellings, and why a project
  should pick the bracket join and never mix tabs into indentation.
])

#diagram([physical lines to logical lines, where each joining rule fires], length: 13pt, {
  let stage(x, w, t) = {
    cdraw.rect((x, 4.7), (x + w, 6.3), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, 5.5), t, wrap: text.with(size: 6pt))
  }
  cdraw.content((2.6, 7.4), [physical lines, one per newline], wrap: text.with(size: 6.5pt))
  stage(0.4, 4.4, [`x = 1 + \ ` #linebreak() backslash ends the line])
  stage(8.6, 4.4, [backslash join #linebreak() or bracket join])
  stage(16.8, 4.4, [`[1,` #linebreak() `2,]`])
  cdraw.line((4.8, 5.5), (8.6, 5.5), stroke: luma(100), mark: (end: ">"))
  cdraw.line((13.0, 5.5), (16.8, 5.5), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.6, 5.5), (8.6, 3.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.8, 5.5), (16.8, 3.9), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((4.2, 2.7), (21.6, 3.9), fill: luma(205), radius: 0.02)
  cdraw.content((12.9, 3.3), [one logical line, comments and blank lines already dropped], wrap: text.with(size: 6pt))
  cdraw.line((12.9, 2.7), (12.9, 1.7), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((6.2, 0.6), (19.6, 1.7), fill: luma(235), radius: 0.02)
  cdraw.content((12.9, 1.15), [indentation becomes INDENT and DEDENT tokens], wrap: text.with(size: 6pt))
})

== the token stream

The `tokenize` module exposes the lexer's actual output. Every lexeme
lands in a category, comments and newlines are tokens like any other, and
the surprising entries are the ones people reach for last:

#listing("python/samples/src/Ch02/tokens.py", first: 22, last: 34, caption: [categories, the comment token, and the NEWLINE count, headers included])

The count is 3 because `if x:` is itself a logical line: the compound
statement header ends in `NEWLINE` like any other. Keywords are not a
token category of their own, `if` arrives as a `NAME`, and the soft
keyword distinction happens later, at the parser. Non-logical newlines get
their own category, and indentation is delivered as paired tokens:

#listing("python/samples/src/Ch02/tokens.py", first: 36, last: 52, caption: [NL against NEWLINE, and INDENT/DEDENT pairs for the nested block])

Blank and comment-only lines end in `NL`, never `NEWLINE`, which is the
tokenizer's way of saying they belong to no logical line. The block probe
counts 2 `INDENT` and 2 `DEDENT` for two nested levels, the stack the
reference describes. Since 3.12 the tokenizer also owns f-strings
(PEP 701), and they arrive as three token kinds, not one string:

#listing("python/samples/src/Ch02/tokens.py", first: 54, last: 61, caption: [an f-string lexes to start, middle, and end tokens])

Before 3.12 the whole literal was pre-digested into one `STRING` token
with the formatting work done by a separate pass. The PEP 701 world means
an f-string can contain quotes matching its own delimiters and nest
arbitrarily, a fact the formatting chapter puts to work. The keyword
lists close the section:

#listing("python/samples/src/Ch02/tokens.py", first: 63, last: 75, caption: [35 hard keywords, 4 soft ones, and soft keywords binding as names])

#callout("note", "soft keywords are parser decisions, not token categories", [
  `match`, `case`, `_`, and `type` act as keywords only inside match and
  type statements. The tokenizer still emits them as `NAME` tokens, which
  is exactly why the compile probe at the bottom can bind `match` and
  `type` as variables. The hard list has 35 entries, and `match` joined
  the soft side when the match statement landed in 3.10, `type` in 3.12.
])

#diagram([the token categories of one small module, with the f-string split open], length: 13pt, {
  let rows = (
    ([`NAME`], [identifiers and keywords alike, `if` is a NAME]),
    ([`NUMBER`], [int, float, complex literals]),
    ([`STRING`], [quoted text, bytes, and prefixed forms]),
    ([`OP`], [operators and delimiters, `:=` included]),
    ([`COMMENT`], [from `#` to end of physical line]),
    ([`NEWLINE`], [ends a logical line, headers included]),
    ([`NL`], [ends blank and comment-only lines]),
    ([`INDENT`/`DEDENT`], [block structure, pushed and popped as a stack]),
    ([`FSTRING_START` #linebreak() `FSTRING_MIDDLE` `FSTRING_END`], [one f-string, three tokens since 3.12]),
  )
  for (i, row) in rows.enumerate() {
    let y = 8.6 - i * 0.98
    cdraw.rect((0.6, y - 0.42), (6.4, y + 0.42), fill: luma(235), radius: 0.02)
    cdraw.content((3.5, y), row.at(0), wrap: text.with(size: 6pt))
    cdraw.rect((6.6, y - 0.42), (21.6, y + 0.42), fill: luma(248), radius: 0.02)
    cdraw.content((14.1, y), row.at(1), wrap: text.with(size: 6pt))
  }
  cdraw.content((12.9, -0.7), [`tokenize.generate_tokens` on a 6 line module #linebreak() yields all of these plus `ENCODING` and `ENDMARKER`], wrap: text.with(size: 6pt))
})

== literals

Numeric literals carry grouping underscores (PEP 515): single underscores
between digits, and, since the grammar was written down this way, one
underscore may also follow a base prefix. The reference's own examples are
`0x_1f` valid against `0_x1f` and `0x__1f` rejected:

#listing("python/samples/src/Ch02/literals.py", first: 19, last: 31, caption: [legal grouping, the base prefix rule, three rejected placements, and the j suffix])

Strings carry prefixes, and the prefixes compose: `r` keeps backslashes as
text, `b` makes bytes, `f` interpolates, `rb` combines the first two, and
3.14 adds `t`, which builds a template instead of a string (PEP 750):

#listing("python/samples/src/Ch02/literals.py", first: 33, last: 42, caption: [prefix behavior, and the new t prefix landing in string.templatelib])

Escapes and adjacency follow. `\xNN` names a byte of text, `\N{...}`
names a character by its unicode name, triple quotes span physical lines,
and two adjacent literals concatenate at compile time, which the sample
again proves through a `compile()` probe so the formatter cannot merge the
demonstration away. Unknown escapes are a warning, not an error, because
they may one day mean something:

#listing("python/samples/src/Ch02/literals.py", first: 44, last: 58, caption: [escapes, adjacency, triple quotes, and the SyntaxWarning for `\q`])

The warning text on this build reads `"\q" is an invalid escape sequence.
Such sequences will not work in the future` (probed 2026-09-12). Treating
it as noise is how code breaks on a future upgrade, the same discipline
the c book applies to its deprecation diagnostics.

#diagram([the anatomy of a literal: prefix, body, and what each prefix produces], length: 13pt, {
  cdraw.rect((0.6, 5.6), (3.0, 7.0), fill: luma(205), radius: 0.02)
  cdraw.content((1.8, 6.3), [prefix], wrap: text.with(size: 6.5pt))
  cdraw.rect((3.2, 5.6), (9.4, 7.0), fill: luma(235), radius: 0.02)
  cdraw.content((6.3, 6.3), [body: digits, escapes, quotes], wrap: text.with(size: 6pt))
  cdraw.rect((9.6, 5.6), (13.2, 7.0), fill: luma(205), radius: 0.02)
  cdraw.content((11.4, 6.3), [suffix], wrap: text.with(size: 6.5pt))
  cdraw.content((11.4, 5.0), [`j` or `J` only, #linebreak() makes a complex], wrap: text.with(size: 6pt))
  let prefixes = (
    ([`r`], [backslashes as text]), ([`b`], [bytes, ascii only]),
    ([`f`], [interpolated str]), ([`rb`], [raw bytes]),
    ([`t`], [template, new 3.14]),
  )
  for (i, p) in prefixes.enumerate() {
    let x = 0.6 + i * 4.4
    cdraw.rect((x, 2.6), (x + 4.0, 4.2), fill: luma(235), radius: 0.02)
    cdraw.content((x + 2.0, 3.9), p.at(0), wrap: text.with(size: 7pt))
    cdraw.content((x + 2.0, 3.2), p.at(1), wrap: text.with(size: 6pt))
  }
  cdraw.content((11.1, 1.6), [digits group with `_`, between digits or after `0x`, `0b`, `0o`], wrap: text.with(size: 6pt))
  cdraw.content((11.1, 0.7), [`1_000.5` ok, `10_`, `1__0`, `1_.5` rejected], wrap: text.with(size: 6pt))
  cdraw.line((1.8, 5.6), (2.6, 4.2), stroke: luma(140), dash: "dashed")
})

== names, keywords, and the walrus

Identifiers follow unicode: any name that reads as an identifier in the
source's script works, so `π` and `é` bind, while `2x` dies with `invalid
decimal literal` because the lexer claims it as a number first (probed
2026-09-12). The walrus operator `:=` (PEP 572) is assignment that lives
inside an expression, and its grammar fences are steep enough that the
sample probes them all through `compile()`:

#listing("python/samples/src/Ch02/walrus.py", first: 18, last: 34, caption: [the condition form and the while next idiom, the two everyday uses])

Both uses do the same job: name a value at the point where it is produced
so the condition and the body share it without a second call. In a
comprehension the walrus binds in the enclosing function scope, not the
comprehension's own scope:

#listing("python/samples/src/Ch02/walrus.py", first: 37, last: 45, caption: [the filter's walrus leaves `y` in `filtered`'s scope, alive after the comprehension])

That rule is the deliberate exception to comprehension scoping, and it is
why the technique pairs with a filter that wants to reuse the computed
value. The fences:

#listing("python/samples/src/Ch02/walrus.py", first: 48, last: 63, caption: [five rejections, each a compile error with a stable message])

Four of the five are old PEP 572 rules: no bare walrus statement, no
attribute target, no unparenthesized chaining, no walrus in a parameter
list. The fifth is new in 3.14: assigning to `__debug__` through a walrus
is now a `SyntaxError` with the message `cannot assign to __debug__`
regardless of the `-O` flag, closing a hole where optimized builds
accepted it. What survives:

#listing("python/samples/src/Ch02/walrus.py", first: 65, last: 71, caption: [parenthesized chains and a lambda body walrus both compile])

The bytecode view backs the source view. The expect-dis file beside the
samples pins five rows against `walrus_limit`, and the assignment compiles
to a `COPY` of the computed length followed by `STORE_FAST`, which is the
whole operator in two opcodes. The rows assert base opnames only, because
specialization warms up per run.

#diagram([where a walrus parses and where it is refused], length: 13pt, {
  cdraw.rect((0.6, 4.2), (6.2, 6.2), fill: luma(205), radius: 0.02)
  cdraw.content((3.4, 5.5), [`:=` seen by the parser], wrap: text.with(size: 6.5pt))
  cdraw.content((3.4, 4.7), [it is an expression, #linebreak() so context decides], wrap: text.with(size: 6pt))
  let reject(x, y, t) = {
    cdraw.rect((x, y), (x + 7.4, y + 1.1), fill: luma(235), radius: 0.02)
    cdraw.content((x + 3.7, y + 0.55), t, wrap: text.with(size: 6pt))
  }
  reject(13.6, 8.0, [bare statement, `n := 1`: invalid])
  reject(13.6, 6.6, [attribute target `a.b := 1`])
  reject(13.6, 5.2, [`x := y := 0` unparenthesized])
  reject(13.6, 3.8, [parameter list, `f(a := 2)`])
  reject(13.6, 2.4, [`__debug__ := 1`, new in 3.14])
  for y in (8.55, 7.15, 5.75, 4.35, 2.95) {
    cdraw.line((6.2, 5.2), (13.6, y), stroke: luma(140), dash: "dashed", mark: (end: ">"))
  }
  let accept(x, y, t) = {
    cdraw.rect((x, y), (x + 7.6, y + 1.1), fill: luma(248), radius: 0.02)
    cdraw.content((x + 3.8, y + 0.55), t, wrap: text.with(size: 6pt))
  }
  accept(0.6, 2.6, [inside an `if` or `while` #linebreak() condition, `(n := f())`])
  accept(0.6, 1.2, [in a comprehension filter, #linebreak() binds the enclosing scope])
  for y in (3.15, 1.75) {
    cdraw.line((6.2, 4.6), (7.0, y), stroke: luma(100), mark: (end: ">"))
  }
  cdraw.content((3.4, 0.4), [chains need parens, lambdas too], wrap: text.with(size: 6pt))
})

#callout("verify", "41 checks, and two red drafts behind them", [
  The first run of the token sample failed its own NEWLINE count: the
  check expected 2 and the interpreter reported 3, because the `if x:`
  header is itself a logical line. The first formatting pass was the
  second red: `ruff format` joined the backslash-continued string and the
  adjacent literals into single literals, silently deleting the very
  constructs the checks demonstrate, so those demonstrations moved into
  `compile()` probes. Both failures are the gate doing its job. The
  expect-dis rows for `walrus_limit` were verified with
  `dis.get_instructions` before landing. Sample behavior verified by
  `make verify-py`, 41 checks in chapter 2 of the samples suite.
])

sources: docs.python.org/3/reference/lexical_analysis.html (line structure,
indentation and the TabError rule, numeric literal grammar including
`0x_1f`, keywords and soft keywords, f-string parenthesization) and
docs.python.org/3/reference/expressions.html (assignment expression
grammar), docs.python.org/3/library/tokenize.html, library/token.html,
library/keyword.html, docs.python.org/3/whatsnew/3.14.html (t prefix,
`__debug__` refusal, incompatible prefix diagnostics),
peps.python.org/pep-0515/, pep-0572/, pep-0701/, and pep-0750/, all
accessed 2026-09-12; the diagnostics for the continuation comment, the
mixed indentation TabError, `2x`, the `\q` warning, and the walrus
rejections were probed on this machine the same day. Sample behavior
verified by `make verify-py`, 41 checks in chapter 2.
