#import "../../theme/lib.typ": listing, snippet, callout, diagram, flow, cdraw
#import "@preview/fletcher:0.5.8": node, edge

= the standard library by edition

The standard library grows by edition, one approved snapshot each
June, and a runtime implements what it implements. This chapter
reads the library the way a working programmer meets it: by edition
shelf, then by what node 26.3.0 actually runs. Everything below was
measured on this runtime, the ES2026 edition approved on 2026-06-30,
the seventeenth, and the two ES2026 items this runtime does not
carry are named as absent, with the probe that says so.

#diagram([the shelves, what node 26.3.0 runs of each edition], length: 13pt, {
  cdraw.content((5.4, 8.9), [edition], size: 6.5pt, fill: luma(100))
  cdraw.content((17.0, 8.9), [this runtime ships], size: 6.5pt, fill: luma(100))

  let row(y, e, w, dark) = {
    cdraw.rect((0.4, y), (22.8, y + 1.35), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((5.4, y + 0.68), e, size: 6pt)
    cdraw.content((17.0, y + 0.68), w, size: 6pt)
  }
  row(7.0, [es2023], [change by copy: `toSorted`, `with`, `toReversed`], false)
  row(5.4, [es2024], [`Object.groupBy`, `Map.groupBy`, `withResolvers`], true)
  row(3.8, [es2025], [iterator helpers, Set algebra, import attributes, #linebreak() `RegExp.escape`, `Promise.try`, `Float16Array`, `using`], false)
  row(2.2, [es2026], [the seven, five of them live here, two absent], true)
  row(0.6, [es2027 slated], [Temporal, stage 4, already shipped here], false)
  cdraw.content((11.6, -0.7), [chapters 5 through 7 spent the es2025 shelf, this chapter the rest], size: 6.5pt)
})

== change by copy, and grouping

The ES2023 copy family mutates nothing: `toSorted`, `with`, and
`toReversed` return new arrays and leave the source alone, which
removed the spread-then-mutate dance from ordinary code. ES2024's
`groupBy` partitions by a key callback, and its result is a null
prototype object, no `toString`, no inherited anything, which a
spread repairs when a plain object is wanted:

#listing("javascript/samples/src/ch08-edition.mjs", first: 5, last: 30, caption: [the copy family against one original, then groupBy and its null prototype])

#diagram([the copy family, and the grouping it left to repair], length: 13pt, {
  cdraw.content((5.5, 8.4), [the spread then mutate dance], size: 6.5pt, fill: luma(100))
  cdraw.content((17.5, 8.4), [the copy family, es2023], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 6.8), (10.6, 7.9), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 7.35), [`[...a].sort()`], size: 6pt)
  cdraw.rect((12.4, 6.8), (22.6, 7.9), fill: luma(205), radius: 0.02)
  cdraw.content((17.5, 7.35), [`a.toSorted(cmp)`], size: 6pt)
  cdraw.rect((0.4, 5.4), (10.6, 6.5), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 5.95), [a copy made by hand, then mutated], size: 6pt)
  cdraw.rect((12.4, 5.4), (22.6, 6.5), fill: luma(205), radius: 0.02)
  cdraw.content((17.5, 5.95), [`with`, `toReversed`, the same shape], size: 6pt)
  cdraw.rect((4.0, 3.9), (19.2, 5.1), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 4.5), [mutates nothing, the source left alone], size: 6pt)
  cdraw.rect((0.4, 1.6), (11.2, 3.6), fill: luma(205), radius: 0.02)
  cdraw.content((5.8, 2.6), [`Object.groupBy`, es2024: a key callback partitions, #linebreak() the result a null prototype object, #linebreak() no `toString`, no inherited anything], size: 6pt)
  cdraw.rect((11.8, 1.6), (22.8, 3.6), fill: luma(235), radius: 0.02)
  cdraw.content((17.3, 2.6), [a spread repairs it #linebreak() when a plain object is wanted], size: 6pt)
  cdraw.content((11.6, 0.7), [both shelves measured on this runtime], size: 6.5pt)
})

== escaping patterns

`RegExp.escape`, from ES2025, makes any string safe as a literal in
a pattern. The escape rules were measured on this runtime, character
by character: regexp syntax characters take a backslash, characters
that could bind to surrounding context, the hyphen in a class range
for instance, take a two digit hex escape, and letters, digits, and
the underscore pass bare, except in first position. The first
character is always escaped, a leading letter becomes `\x7a`, so an
escaped fragment can follow a backslash in a host pattern without
completing somebody else's escape sequence:

#listing("javascript/samples/src/ch08-edition.mjs", first: 32, last: 47, caption: [the measured escape classes, and the output matching itself literally])

#diagram([the measured rule classes, character by character], length: 13pt, {
  cdraw.content((7.0, 8.5), [the class of character], size: 6.5pt, fill: luma(100))
  cdraw.content((17.5, 8.5), [`RegExp.escape` writes], size: 6.5pt, fill: luma(100))
  let row(y, c, w, dark) = {
    cdraw.rect((0.4, y), (22.8, y + 1.35), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((7.0, y + 0.68), c, size: 6pt)
    cdraw.content((17.5, y + 0.68), w, size: 6pt)
  }
  row(6.6, [regexp syntax characters], [a backslash], false)
  row(5.0, [context binders, #linebreak() the hyphen in a class range], [a two digit hex escape], true)
  row(3.4, [letters, digits, underscore], [bare], false)
  row(1.8, [any of them, in first position], [always escaped, a letter becomes `\x7a`], true)
  cdraw.content((11.6, 0.7), [es2025, so a fragment never completes a host escape], size: 6.5pt)
})

== errors that identify themselves

`Error.isError`, one of the ES2026 seven, answers the question
`instanceof Error` gets wrong the moment an error crosses a realm or
a lookalike object carries the right names. The `cause` option, the
ES2022 neighbor, chains context through every level and the test
walks it to the root:

#listing("javascript/samples/src/ch08-edition.mjs", first: 49, last: 61, caption: [isError against a real error, a lookalike, and a cause chain])

#diagram([the type question, and the chain that carries context], length: 13pt, {
  cdraw.content((11.6, 9.8), [the names on an object are not the type], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.6, 7.8), (9.0, 9.0), fill: luma(235), radius: 0.02)
  cdraw.content((4.8, 8.4), [an error crossing a realm], size: 6pt)
  cdraw.rect((0.6, 6.4), (9.0, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((4.8, 7.0), [a lookalike, `name`, `message`, `stack`], size: 6pt)
  cdraw.line((9.0, 8.4), (12.2, 7.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.0, 7.0), (12.2, 7.4), stroke: luma(100))
  cdraw.rect((12.2, 6.9), (22.6, 8.1), fill: none, stroke: luma(160), radius: 0.02)
  cdraw.content((17.4, 7.5), [`instanceof Error` gets it wrong], size: 6pt)
  cdraw.line((17.4, 6.9), (17.4, 6.1), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((12.2, 4.9), (22.6, 6.1), fill: luma(205), radius: 0.02)
  cdraw.content((17.4, 5.5), [`Error.isError`, one of the es2026 seven, #linebreak() answers], size: 6pt)
  cdraw.content((11.6, 4.0), [the `cause` option, es2022, context through every level], size: 6pt)
  cdraw.rect((2.6, 2.4), (6.6, 3.5), fill: luma(235), radius: 0.02)
  cdraw.content((4.6, 2.95), [`top`], size: 6pt)
  cdraw.line((6.6, 2.95), (8.6, 2.95), stroke: luma(100), mark: (end: ">"))
  cdraw.content((7.6, 3.35), [`cause`], size: 6pt)
  cdraw.rect((8.6, 2.4), (12.6, 3.5), fill: luma(235), radius: 0.02)
  cdraw.content((10.6, 2.95), [`middle`], size: 6pt)
  cdraw.line((12.6, 2.95), (14.6, 2.95), stroke: luma(100), mark: (end: ">"))
  cdraw.content((13.6, 3.35), [`cause`], size: 6pt)
  cdraw.rect((14.6, 2.4), (18.6, 3.5), fill: luma(205), radius: 0.02)
  cdraw.content((16.6, 2.95), [`root`], size: 6pt)
  cdraw.content((11.6, 1.3), [the test walks it to the root, `top.cause.cause.message`], size: 6.5pt)
})

== json that keeps its digits

`JSON.stringify` writes doubles, and doubles past 2^53 round. The
second of the ES2026 seven to live here, `JSON.rawJSON`, pins source
text: an integer embedded as raw JSON serializes to exactly the
digits written, where the same literal as a number loses its trailing
digit on the way out. `JSON.isRawJSON` reports which values carry
the pin. The boundary is honest and the test states it: parsing the
pinned text still produces the double, `9007199254740993` written
and `9007199254740992` parsed, because the parse side of the
source-text proposal is not on this runtime:

#listing("javascript/samples/src/ch08-edition.mjs", first: 63, last: 78, caption: [raw digits surviving stringify, and the double that comes back from parse])

#diagram([the pin against the double, the same digits two ways], length: 13pt, {
  cdraw.content((5.5, 8.4), [the literal as a number], size: 6.5pt, fill: luma(100))
  cdraw.content((17.5, 8.4), [embedded as raw json], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 6.8), (10.6, 7.9), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 7.35), [`JSON.stringify` writes doubles], size: 6pt)
  cdraw.rect((12.4, 6.8), (22.6, 7.9), fill: luma(205), radius: 0.02)
  cdraw.content((17.5, 7.35), [`JSON.rawJSON` pins source text], size: 6pt)
  cdraw.rect((0.4, 5.4), (10.6, 6.5), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 5.95), [past 2^53, doubles round], size: 6pt)
  cdraw.rect((12.4, 5.4), (22.6, 6.5), fill: luma(205), radius: 0.02)
  cdraw.content((17.5, 5.95), [`JSON.isRawJSON` reports the pin], size: 6pt)
  cdraw.rect((0.4, 4.0), (10.6, 5.1), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 4.55), [the trailing digit lost #linebreak() on the way out], size: 6pt)
  cdraw.rect((12.4, 4.0), (22.6, 5.1), fill: luma(205), radius: 0.02)
  cdraw.content((17.5, 4.55), [exactly the digits written], size: 6pt)
  cdraw.rect((2.0, 1.9), (21.2, 3.6), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 2.75), [the honest boundary: parsing the pinned text still returns the double, #linebreak() `9007199254740993` written, `9007199254740992` parsed, #linebreak() the parse side of the proposal is not on this runtime], size: 6pt)
  cdraw.content((11.6, 0.9), [the second of the es2026 seven to live here], size: 6.5pt)
})

#callout("note", "in the ES2026 spec, absent on node 26.3.0", [
  Two ES2026 items do not run here, both probed on 2026-09-13:
  `Math.sumPrecise` is `undefined` on this runtime, and
  `JSON.parse` takes two arguments here, its arity is 2, so the
  spec's third `{ source: true }` argument is silently ignored and
  the reviver never sees source text. Both absences are pinned by
  test, the day this runtime ships them the suite says so.
])

#snippet(
  "// in the ES2026 spec, not on node 26.3.0 (measured)\n"
  + "Math.sumPrecise([1, 1e100, 1, -1e100]);\n"
  + "// 2, exactly, any order\n"
  + "// [0.1, 0.2] still yields 0.30000000000000004, midpoint tie to even\n"
  + "\n"
  + "// spec: a third argument opts into source text\n"
  + "JSON.parse(\"9007199254740993\", null, { source: true });\n"
  + "// node 26: the third argument is ignored, a plain number back\n",
  lang: "javascript")

The remaining shelves live in their chapters: `Array.fromAsync` in
chapter 6, the `Uint8Array` codecs and `Iterator.concat` and
`getOrInsert` in chapter 5, all three part of the seven. Around the
edges, two older additions keep earning their keep, `structuredClone`
deep copies containers and refuses functions, and numeric collation
sorts `a2` ahead of `a10`, which every lexicographic sort gets
wrong:

#listing("javascript/samples/src/ch08-edition.mjs", first: 92, last: 109, caption: [structuredClone's boundary, and collation that reads numbers as numbers])

== temporal, measured live

Temporal is the largest addition to the library in a decade, and its
status is worth stating plainly: Stage 4 in the tc39 process, slated
for the ES2027 edition, and already shipped unflagged in this
runtime, node 26, measured, and in Firefox 139 and Chrome 144. It
replaces the `Date` object's mutable, ambiguous, local-time API with
types that name what they hold. `Instant` is a point on the utc
line. `PlainDate` is a calendar date with no time and no zone.
`ZonedDateTime` is a wall clock reading pinned to a zone, and
`Temporal.Now` is the one clock reading entry point:

#diagram([the temporal types, what each one holds], length: 13pt, {
  cdraw.content((11.6, 9.0), [a type per question], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.6, 7.2), (7.4, 8.4), fill: luma(235), radius: 0.02)
  cdraw.content((4.0, 7.8), [`Instant`], size: 6pt)
  cdraw.content((4.0, 7.5), [a moment, utc only], size: 5.5pt)
  cdraw.rect((8.2, 7.2), (15.0, 8.4), fill: luma(205), radius: 0.02)
  cdraw.content((11.6, 7.8), [`PlainDate`, `PlainTime`], size: 6pt)
  cdraw.content((11.6, 7.5), [calendar facts, no zone], size: 5.5pt)
  cdraw.rect((15.8, 7.2), (22.6, 8.4), fill: luma(235), radius: 0.02)
  cdraw.content((19.2, 7.8), [`ZonedDateTime`], size: 6pt)
  cdraw.content((19.2, 7.5), [wall clock plus zone], size: 5.5pt)
  cdraw.line((11.6, 7.2), (11.6, 6.4), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.6, 5.2), (11.0, 6.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 5.8), [`Temporal.Now`, #linebreak() reads the clock into any of them], size: 6pt)
  cdraw.rect((12.4, 5.2), (22.6, 6.4), fill: luma(205), radius: 0.02)
  cdraw.content((17.5, 5.8), [`Duration`, #linebreak() a span, arithmetic's operand], size: 6pt)
  cdraw.rect((0.6, 3.0), (22.6, 4.2), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 3.6), [serialize at the string boundary: `toJSON` out, `from` in], size: 6pt)
  cdraw.content((11.6, 1.8), [`compare` methods order, relational operators throw], size: 6.5pt)
})

`Instant` parses from an iso string, round trips through its string
form at nanosecond precision, reads the epoch count, shifts by a
duration, and compares with a total order:

#listing("javascript/samples/src/ch08-temporal.mjs", first: 5, last: 22, caption: [an instant: parse, round trip, epoch count, shift, total order])

`PlainDate` arithmetic respects the calendar: a day over a month end
lands correctly, differences come in the largest unit asked for, and
`compare` orders dates that relational operators would corrupt:

#listing("javascript/samples/src/ch08-temporal.mjs", first: 24, last: 38, caption: [a calendar date: fields, arithmetic, differences, order])

`ZonedDateTime` carries its offset as part of the value. Converting
the zone keeps the instant, the epoch nanoseconds are equal, and
moves the wall clock, nine in New York is ten in the evening in
Tokyo, and the plain views split the value apart for free:

#listing("javascript/samples/src/ch08-temporal.mjs", first: 40, last: 54, caption: [a zoned wall clock: offset, zone conversion, plain views])

Durations are their own type, constructed from fields, totalled into
a unit as a number, and rounded into larger units. `Temporal.Now`
hands back the full precision types, never a mutable `Date`:

#listing("javascript/samples/src/ch08-temporal.mjs", first: 56, last: 75, caption: [the clock, and a duration across total and round])

Serialization is where teams lose dates, so the advice is one
sentence: keep values in Temporal types in memory, cross boundaries
as strings, `toJSON` writes rfc 9557 text through `JSON.stringify`
with no replacer, `from` revives, and the relational operators are
gone, `<` on two plain dates throws a `TypeError`, `compare` methods
are the ordering:

#listing("javascript/samples/src/ch08-temporal.mjs", first: 77, last: 99, caption: [the string boundary, and the operator that no longer exists])

sources: tc39.es es2025 and es2026 draft clauses for iterator
helpers, set methods, regexp escape, promise.try, error.isError,
json raw json, and the temporal proposal at stage 4,
developer.mozilla.org temporal and standard library pages, v8 and
node release notes for temporal in chrome 144 and node 26, accessed
2026-09-13. Behavior verified live with node v26.3.0 on windows,
117 tests green through `npm run verify` in `javascript/samples`,
20 of them this chapter's.
