#import "../../theme/lib.typ": cdraw, diagram, listing, snippet, callout, xref-to

= migrations, test driven

The migration runner is the one piece of the capstone built strictly
test first in this book, red, green, refactor, one behavior at a
time, and this chapter is that build order. The runner is not a
sample: `store.Open` calls it on every open, so the capstone's schema
lives or dies with these tests.

The contract, decided before any implementation: migrations are sql
files named `NNNN_name.sql`, embedded in the binary, applied in order,
each inside one transaction together with its version row, tracked in
a table the runner creates, and a failure leaves the database at the
previous version. Six tests encode it.

== discovery, order, and the names that fail loudly

#listing("infrastructure/capstone/internal/migrate/migrate_test.go", first: 28, last: 54, caption: [shuffled files come out ordered, junk names are ignored, a misnamed sql file is an error])

The distinction in the last assertion is deliberate. A `README.md`
among migrations is noise, skip it. A `2_two.sql` is a typo that
would silently skip a migration forever, error. And a gap in the
sequence, 0001 then 0003, is refused, because applied versions must
be a prefix of a gapless sequence or resume logic cannot tell a
missing file from a reordered one:

#listing("infrastructure/capstone/internal/migrate/migrate_test.go", first: 152, last: 162, caption: [gaps are errors, not surprises for later])

The implementation of discovery is one regexp and one sort:

#listing("infrastructure/capstone/internal/migrate/migrate.go", first: 35, last: 70, caption: [plan: read the fs, match names, reject bad sql names, order by version])

#diagram([what plan does to each file: two of the four verdicts are errors], length: 13pt, {
  cdraw.content((5.0, 9.0), [one entry, four verdicts], size: 6.5pt)

  cdraw.rect((0.0, 7.1), (8.0, 8.1), fill: luma(235), radius: 0.02)
  cdraw.content((4.0, 7.6), [NNNN_name.sql], size: 6.5pt)
  cdraw.line((8.0, 7.6), (9.4, 7.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((9.4, 7.1), (19.8, 8.1), fill: luma(205), radius: 0.02)
  cdraw.content((14.6, 7.6), [applied, ordered by version], size: 6pt)

  cdraw.rect((0.0, 5.7), (8.0, 6.7), fill: luma(235), radius: 0.02)
  cdraw.content((4.0, 6.2), [README, non-sql], size: 6.5pt)
  cdraw.line((8.0, 6.2), (9.4, 6.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((9.4, 5.7), (16.0, 6.7), fill: luma(235), radius: 0.02)
  cdraw.content((12.7, 6.2), [skipped as noise], size: 6pt)

  cdraw.rect((0.0, 4.3), (8.0, 5.3), fill: luma(235), radius: 0.02)
  cdraw.content((4.0, 4.8), [2_two.sql], size: 6.5pt)
  cdraw.line((8.0, 4.8), (9.4, 4.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((9.4, 4.3), (16.0, 5.3), fill: white, stroke: (paint: luma(100), dash: "dashed"), radius: 0.02)
  cdraw.content((12.7, 4.8), [error: bad name], size: 6pt)

  cdraw.rect((0.0, 2.9), (8.0, 3.9), fill: luma(235), radius: 0.02)
  cdraw.content((4.0, 3.4), [0001, then 0003], size: 6.5pt)
  cdraw.line((8.0, 3.4), (9.4, 3.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((9.4, 2.9), (18.6, 3.9), fill: white, stroke: (paint: luma(100), dash: "dashed"), radius: 0.02)
  cdraw.content((14.0, 3.4), [error: gap breaks prefix], size: 6pt)

  cdraw.content((11.0, 1.7), [applied versions must be a prefix], size: 6pt)
  cdraw.content((11.0, 0.6), [of a gapless sequence], size: 6pt)
})

== apply, record, and the atomicity that matters

#listing("infrastructure/capstone/internal/migrate/migrate.go", first: 93, last: 147, caption: [up: the tracking table, the applied set, each migration and its version row in one transaction])

The transaction holds two things at once, the schema change and the
version insert. That pairing is the entire correctness claim, and the
failure test is where it earns belief:

#listing("infrastructure/capstone/internal/migrate/migrate_test.go", first: 129, last: 150, caption: [a broken migration leaves one version row and the first migration's table durable])

#diagram([one transaction holds both writes, so failure leaves no half state], length: 13pt, {
  cdraw.rect((3.0, 4.4), (20.0, 8.0), fill: luma(205), radius: 0.02)
  cdraw.content((11.5, 7.4), [one transaction], size: 6.5pt)
  cdraw.rect((4.0, 4.9), (11.4, 6.3), fill: luma(235), radius: 0.02)
  cdraw.content((7.7, 5.6), [the schema change], size: 6pt)
  cdraw.rect((11.8, 4.9), (19.2, 6.3), fill: luma(235), radius: 0.02)
  cdraw.content((15.5, 5.6), [the version row], size: 6pt)

  cdraw.content((11.5, 3.3), [a broken second migration rolls back whole], size: 6pt)
  cdraw.content((11.5, 2.2), [one version row, the first table durable], size: 6pt)
  cdraw.content((11.5, 1.1), [record-before-execute fails this loudly], size: 6pt)
})

A runner that recorded the version before executing, or executed
outside the transaction, fails this test in the loudest way: the
second run would skip a migration that never landed. Idempotence and
resumption are the two remaining behaviors, one second call applying
nothing, one partial database applying only the tail, and their tests
drive the applied-set read at the top of `Up`.

== why not a library

Go has migration libraries with more features, down migrations,
checksums, dry runs. The capstone carries its own runner for the
reason the chapter is in this book: schema evolution is a handful of
policy rules, the rules are the interesting part, and the parts a
library would add are the parts this system decided against. Down
migrations, because forward-only with a copy-and-swap rebuild for the
rare undo is safer than generated reverse sql. Checksums on applied
files, because the gap rule plus the version table already answer the
questions the schema asks.

#diagram([own runner versus library: the ledger of declined features], length: 13pt, {
  cdraw.rect((0.0, 7.0), (6.6, 8.0), fill: luma(235), radius: 0.02)
  cdraw.content((3.3, 7.5), [down migrations], size: 6.5pt)
  cdraw.line((6.6, 7.5), (7.9, 7.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((8.0, 6.5), (18.6, 8.5), fill: luma(235), radius: 0.02)
  cdraw.content((13.3, 8.0), [declined: forward-only,], size: 6pt)
  cdraw.content((13.3, 6.9), [a copy-and-swap undo], size: 6pt)

  cdraw.rect((0.0, 3.5), (6.6, 4.5), fill: luma(235), radius: 0.02)
  cdraw.content((3.3, 4.0), [checksums], size: 6.5pt)
  cdraw.line((6.6, 4.0), (7.9, 4.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((8.0, 3.0), (18.6, 5.0), fill: luma(235), radius: 0.02)
  cdraw.content((13.3, 4.5), [declined: the gap rule], size: 6pt)
  cdraw.content((13.3, 3.4), [plus the version table], size: 6pt)

  cdraw.content((11.0, 1.7), [the policy is the interesting part], size: 6.5pt)
  cdraw.content((11.0, 0.6), [the rules fit in one file], size: 6pt)
})

#callout("warning", "the migration is the deployment", [
  `store.Open` runs `Up` on every open, which means every service
  start is a migration attempt. That is safe exactly because Up is
  idempotent and transactional, and it removes an entire class of
  "forgot to run migrations on the new node" incidents. The cost is
  that migrations must stay additive and fast, the discipline
  #xref-to("infrastructure", "sqlite-schema") already argued for.
])

sources: no external sources, the design follows from the sqlite
transaction semantics probed in #xref-to("infrastructure",
"sqlite-transactions"). Verified by the migrate suite, 6 tests, red
first then green, under `make verify` 2026-09-10.
