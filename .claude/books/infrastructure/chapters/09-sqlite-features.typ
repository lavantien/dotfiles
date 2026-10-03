#import "../../theme/lib.typ": cdraw, diagram, listing, snippet, callout, xref-to

= sqlite: the 3.53 feature set

This book pins one engine, 3.53.4, across every runtime that touches
it, and this chapter is what that pin buys: a tour of the feature set
where every capability is asserted present and the absent ones are
asserted absent. Each probe ran against both the modernc driver and
the amalgamation binary in `tools/sqlite/build`, and where the two
could disagree they did not: same version string, same behavior.

== json in sql

Json is a first class type in sql, not a blob the application parses.
Extraction, patching, pretty printing, and the `json_each` table
valued function:

#listing("infrastructure/samples/ch09/features_test.go", first: 40, last: 74, caption: [extract, pretty, patch, and json_each, all plain queries])

The pattern that earns its keep is the path into a column. An events
table that grew a json payload column answers structural questions
without a schema change and without unmarshalling in go:

#listing("infrastructure/samples/ch09/features_test.go", first: 78, last: 103, caption: [a where clause that reaches inside a json column])

#diagram([json stays in sql: paths and streams, no unmarshalling in go], length: 13pt, {
  cdraw.rect((0.0, 6.6), (5.0, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((2.5, 7.1), [json column], size: 6.5pt)
  cdraw.line((5.0, 7.1), (6.4, 7.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((6.4, 6.6), (14.6, 7.6), fill: luma(205), radius: 0.02)
  cdraw.content((10.5, 7.1), [extract, patch, pretty], size: 6pt)
  cdraw.line((14.6, 7.1), (15.9, 7.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((16.0, 6.6), (21.8, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((18.9, 7.1), [plain queries], size: 6.5pt)
  cdraw.content((10.0, 5.5), [a where clause reaches inside the column], size: 6pt)

  cdraw.rect((0.0, 2.4), (6.0, 3.4), fill: luma(235), radius: 0.02)
  cdraw.content((3.0, 2.9), [one json array], size: 6.5pt)
  cdraw.line((6.0, 2.9), (7.4, 2.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((6.7, 4.0), [json_each], size: 6pt)
  cdraw.rect((7.6, 2.4), (15.0, 3.4), fill: luma(235), radius: 0.02)
  cdraw.content((11.3, 2.9), [one row per element], size: 6.5pt)

  cdraw.content((10.0, 1.1), [no schema change], size: 6pt)
  cdraw.content((10.0, 0.0), [no unmarshalling in go], size: 6pt)
})

== alter column constraints, the 3.53.1 addition

Before 3.53, editing a column's constraints meant the twelve step
table rebuild from the sqlite documentation. Now the not null
constraint is editable in place, and the probe exercises the whole
life: set, enforced rejection, drop:

#listing("infrastructure/samples/ch09/features_test.go", first: 109, last: 150, caption: [set not null, feel it reject a null, drop it again, and watch the default variant fail])

#diagram([the constraint life cycle in place, and the one edit this engine refuses], length: 13pt, {
  cdraw.rect((0.0, 5.4), (5.2, 6.4), fill: luma(235), radius: 0.02)
  cdraw.content((2.6, 5.9), [set not null], size: 6.5pt)
  cdraw.line((5.2, 5.9), (6.6, 5.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((6.6, 5.4), (14.4, 6.4), fill: luma(235), radius: 0.02)
  cdraw.content((10.5, 5.9), [null insert rejected], size: 6.5pt)
  cdraw.line((14.4, 5.9), (15.8, 5.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((15.8, 5.4), (21.4, 6.4), fill: luma(235), radius: 0.02)
  cdraw.content((18.6, 5.9), [drop restores], size: 6.5pt)
  cdraw.content((9.8, 4.3), [pragma_table_info flips notnull 0, 1, 0], size: 6pt)

  cdraw.rect((0.0, 1.6), (6.0, 2.6), fill: white, stroke: (paint: luma(100), dash: "dashed"), radius: 0.02)
  cdraw.content((3.0, 2.1), [set default], size: 6.5pt)
  cdraw.content((13.6, 2.1), [syntax error in 3.53.4], size: 6pt)
  cdraw.content((13.6, 1.0), [the twelve-step rebuild instead], size: 6pt)
})

The last assertion is the honest one. `ALTER COLUMN ... SET DEFAULT`
is a syntax error in this exact engine, probed in both runtimes, so a
migration needing it must fall back to the rebuild, and the chapter
says so rather than hoping. The pragma readback through
`pragma_table_info` shows the constraint flipping, and the column is
addressed as `"notnull"` quoted, because 3.53 makes the bare word a
keyword again in these statements.

== reindex

Index rebuilding runs by index name and by collation name:

#listing("infrastructure/samples/ch09/features_test.go", first: 154, last: 172, caption: [reindex by name and by collation, with the expression form pinned absent])

#diagram([reindex, one row of the feature matrix: what runs and what this engine refuses], length: 13pt, {
  cdraw.content((5.0, 7.3), [reindex by name], size: 6.5pt)
  cdraw.rect((16.4, 6.9), (19.8, 7.7), fill: luma(235), radius: 0.02)
  cdraw.content((18.1, 7.3), [present], size: 6pt)
  cdraw.line((0.6, 6.5), (22.0, 6.5), stroke: luma(220))
  cdraw.content((5.0, 5.5), [reindex by collation], size: 6.5pt)
  cdraw.rect((16.4, 5.1), (19.8, 5.9), fill: luma(235), radius: 0.02)
  cdraw.content((18.1, 5.5), [present], size: 6pt)
  cdraw.line((0.6, 4.7), (22.0, 4.7), stroke: luma(220))
  cdraw.content((5.0, 3.7), [reindex by expression], size: 6.5pt)
  cdraw.rect((16.4, 3.3), (19.8, 4.1), fill: white, stroke: (paint: luma(100), dash: "dashed"), radius: 0.02)
  cdraw.content((18.1, 3.7), [absent], size: 6pt)

  cdraw.content((11.0, 1.9), [present and absent, as measured], size: 6.5pt)
  cdraw.content((11.0, 0.8), [absences are asserted by tests too], size: 6pt)
})

== money as integer cents

Binary floating point cannot hold a tenth, so money in floats drifts,
and the drift is one query long:

#listing("infrastructure/samples/ch09/features_test.go", first: 205, last: 228, caption: [one hundred espressos at 19.99: the float sum misses, the cent sum is exact])

#diagram([the same hundred espressos, summed as floats and as cents], length: 13pt, {
  cdraw.content((4.0, 8.6), [floats], size: 6.5pt)
  cdraw.rect((0.0, 6.8), (6.6, 7.8), fill: luma(235), radius: 0.02)
  cdraw.content((3.3, 7.3), [100 x 19.99], size: 6.5pt)
  cdraw.line((6.6, 7.3), (8.0, 7.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((8.0, 6.8), (14.6, 7.8), fill: luma(235), radius: 0.02)
  cdraw.content((11.3, 7.3), [sum misses 1999], size: 6.5pt)

  cdraw.content((4.0, 4.8), [integer cents], size: 6.5pt)
  cdraw.rect((0.0, 3.0), (6.6, 4.0), fill: luma(235), radius: 0.02)
  cdraw.content((3.3, 3.5), [100 x 1999], size: 6.5pt)
  cdraw.line((6.6, 3.5), (8.0, 3.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((8.0, 3.0), (15.2, 4.0), fill: luma(205), radius: 0.02)
  cdraw.content((11.6, 3.5), [sum = 199900 exactly], size: 6.5pt)

  cdraw.content((10.0, 1.7), [store cents, compute in integers], size: 6pt)
  cdraw.content((10.0, 0.6), [format for humans at the edge], size: 6pt)
})

The probe asserts the float sum is not exactly 1999, the drift premise
is real and not folklore, then asserts the integer cent sum is exact.
The rule it backs: store cents, add and compare in integers, format
for humans at the edge where the decimal point is a display concern.
The game shop in book 13 prices stock in whole gold for the same
reason, no rounding anywhere near a balance.

== strict tables

`STRICT` turns affinity coercion, sqlite's silent type massage, into
an error at the boundary:

#listing("infrastructure/samples/ch09/features_test.go", first: 235, last: 254, caption: [strict rejects what affinity would have coerced, with one nuance pinned])

#diagram([strict against affinity, same inserts, opposite outcomes], length: 13pt, {
  cdraw.content((4.0, 8.6), [affinity], size: 6.5pt)
  cdraw.rect((0.0, 6.8), (9.2, 7.8), fill: luma(235), radius: 0.02)
  cdraw.content((4.6, 7.3), ['not a number' inserted], size: 6.5pt)
  cdraw.line((9.2, 7.3), (10.6, 7.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((10.6, 6.8), (18.8, 7.8), fill: luma(235), radius: 0.02)
  cdraw.content((14.7, 7.3), [stored as text], size: 6.5pt)

  cdraw.content((4.0, 4.8), [strict], size: 6.5pt)
  cdraw.rect((0.0, 3.0), (9.2, 4.0), fill: luma(235), radius: 0.02)
  cdraw.content((4.6, 3.5), ['not a number' inserted], size: 6.5pt)
  cdraw.line((9.2, 3.5), (10.6, 3.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((10.6, 3.0), (18.8, 4.0), fill: luma(205), radius: 0.02)
  cdraw.content((14.7, 3.5), [rejected, an error], size: 6.5pt)

  cdraw.content((10.0, 1.7), ['1999' still lands as 1999], size: 6pt)
  cdraw.content((10.0, 0.6), [a type gate, not a format gate], size: 6pt)
})

The nuance is in the test on purpose: strict integer columns still
convert text that looks like an integer, `'1999'` lands as 1999. The
gate is on type families, not on string formatting, and a probe that
claimed otherwise would be describing a different database.

#callout("note", "why assert the absences", [
  The build that links into this book's tests is fixed, but the one
  that links into a reader's next job is not. Tests that pin rejected
  syntax, `SET DEFAULT`, expression `REINDEX`, document the boundary
  of the feature set as measured, so upgrading the pin in
  #xref-to("infrastructure", "toolchain") reruns these probes and any
  new capability shows up as a deliberate test change, not a silent
  drift.
])

sources: sqlite.org changes for the 3.53.x timeline, json1, lang/
altertable, lang/reindex, pragma, and stricttables pages, all
accessed 2026-09-10 and probed against the pinned 3.53.4 binary the
same day. Verified by the ch09 probe suite, 8 tests, green under
`make verify` 2026-09-10.
