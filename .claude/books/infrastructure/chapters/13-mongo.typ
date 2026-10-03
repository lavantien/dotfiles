#import "../../theme/lib.typ": cdraw, diagram, listing, snippet, callout, xref-to

= mongodb and aggregation pipelines

The stats the history service answers live in mongo, and the reason is the
opposite of the sqlite chapters' reason: chat messages are append-only
documents with shifting query shapes, and the questions asked of them,
top talkers, room volumes, busiest hour, trending words, are group-bys
computed on demand. Mongo's aggregation pipeline is a language for
exactly that, stages flowing left to right, each transforming the
document stream.

== the seam first

The history service never imports the driver in its logic. It
declares what it needs from a store:

#snippet("type Store interface {\n"
  + "    Insert(ctx context.Context, m wire.Message) error\n"
  + "    Stats(ctx context.Context) (wire.Stats, error)\n"
  + "}", lang: "go")

#diagram([the Store interface is the only door, and both gates use it], length: 13pt, {
  cdraw.rect((0.0, 4.4), (6.6, 6.8), fill: luma(235), radius: 0.02)
  cdraw.content((3.3, 6.25), [history logic], size: 6.5pt)
  cdraw.content((3.3, 5.15), [no driver import], size: 6pt)

  cdraw.line((6.6, 5.6), (8.5, 5.6), stroke: luma(100), mark: (end: ">>"))

  cdraw.rect((8.6, 4.4), (15.4, 6.8), fill: luma(205), radius: 0.02)
  cdraw.content((12.0, 6.25), [Store interface], size: 6.5pt)
  cdraw.content((12.0, 5.15), [insert, stats], size: 6pt)

  cdraw.line((15.4, 5.9), (17.1, 6.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((17.2, 5.9), (23.4, 7.1), fill: luma(235), radius: 0.02)
  cdraw.content((20.3, 6.5), [real mongo], size: 6.5pt)
  cdraw.line((15.4, 5.3), (17.1, 4.7), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((17.2, 4.1), (23.4, 5.3), fill: luma(235), radius: 0.02)
  cdraw.content((20.3, 4.7), [in-memory fake], size: 6.5pt)

  cdraw.content((12.0, 2.8), [docker-free gate and docker gate], size: 6pt)
  cdraw.content((12.0, 1.7), [enter through this one door], size: 6pt)
})

Two methods, one for the consumer to feed, one for the stats
responder to answer. The real mongo implementation satisfies it, and
so does the in-memory fake the docker-free gate runs on,
#xref-to("infrastructure", "mocks"). The chapter's pipelines are the
real implementation.

== idempotent writes

The consumer acks after inserting, so a crash between insert and ack
means one redelivery, and the insert must tolerate it:

#listing("infrastructure/capstone/internal/history/mongo.go", first: 59, last: 73, caption: [an upsert keyed on message id, with docOf as the one shaper])

#diagram([one redelivery, two inserts: the plain insert doubles, the upsert lands on the same document], length: 13pt, {
  cdraw.content((4.0, 8.6), [plain insert], size: 6.5pt)
  cdraw.rect((0.0, 6.8), (7.2, 7.8), fill: luma(235), radius: 0.02)
  cdraw.content((3.6, 7.3), [insert, then crash], size: 6.5pt)
  cdraw.line((7.2, 7.3), (8.6, 7.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((8.6, 6.8), (15.2, 7.8), fill: luma(235), radius: 0.02)
  cdraw.content((11.9, 7.3), [one redelivery], size: 6.5pt)
  cdraw.line((15.2, 7.3), (16.6, 7.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((16.6, 6.8), (23.4, 7.8), fill: luma(235), radius: 0.02)
  cdraw.content((20.0, 7.3), [a duplicate row], size: 6.5pt)

  cdraw.content((4.0, 4.8), [upsert on id], size: 6.5pt)
  cdraw.rect((0.0, 3.0), (7.2, 4.0), fill: luma(235), radius: 0.02)
  cdraw.content((3.6, 3.5), [redelivery arrives], size: 6.5pt)
  cdraw.line((7.2, 3.5), (8.6, 3.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((8.6, 3.0), (16.0, 4.0), fill: luma(235), radius: 0.02)
  cdraw.content((12.3, 3.5), [upsert, keyed on id], size: 6.5pt)
  cdraw.line((16.0, 3.5), (17.4, 3.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((17.4, 3.0), (23.4, 4.0), fill: luma(205), radius: 0.02)
  cdraw.content((20.4, 3.5), [same document], size: 6.5pt)

  cdraw.content((10.0, 1.7), [the unique index on id], size: 6pt)
  cdraw.content((10.0, 0.6), [a point lookup, not a scan], size: 6pt)
})

The unique index on `id` is created at connect time. Without it the
upsert is a scan, and with a redelivery it would still be correct,
but correctness by full-collection-scan is not a plan.

== the pipeline vocabulary

The stats answer is four pipelines over the same collection. The
simplest one is parameterized:

#listing("infrastructure/capstone/internal/history/mongo.go", first: 112, last: 135, caption: [group, sort, limit, project: the four stages that answer top talkers and top rooms])

`$group` collapses the stream on an expression, here a field path or
the hour label below, `$sort` orders, `$limit` truncates, `$project`
reshapes into the wire.Stat rows the responder marshals. The sort
carries a tiebreaker on the key so equal counts order deterministically,
the same rule the go fake enforces.

The busiest hour bucket turns a unix millisecond timestamp into a
label inside the pipeline:

#listing("infrastructure/capstone/internal/history/mongo.go", first: 105, last: 110, caption: [`$toDate` then `$dateToString` with a format and timezone])

And the word count is the pipeline with the most moving parts, split,
unwind, trim, filter, then the same group-sort-limit tail:

#listing("infrastructure/capstone/internal/history/mongo.go", first: 139, last: 178, caption: [`$split`, `$unwind`, `$trim`, an `$expr` length filter, then the counting tail])

#diagram([documents flow left to right: the spine, and the words pipeline that multiplies first], length: 13pt, {
  cdraw.content((9.0, 9.0), [the spine], size: 6.5pt)
  cdraw.rect((0.0, 7.0), (4.0, 8.0), fill: luma(235), radius: 0.02)
  cdraw.content((2.0, 7.5), [\$group], size: 6.5pt)
  cdraw.line((4.0, 7.5), (5.4, 7.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((5.4, 7.0), (9.4, 8.0), fill: luma(235), radius: 0.02)
  cdraw.content((7.4, 7.5), [\$sort], size: 6.5pt)
  cdraw.line((9.4, 7.5), (10.8, 7.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((10.8, 7.0), (14.8, 8.0), fill: luma(235), radius: 0.02)
  cdraw.content((12.8, 7.5), [\$limit], size: 6.5pt)
  cdraw.line((14.8, 7.5), (16.2, 7.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((16.2, 7.0), (20.6, 8.0), fill: luma(235), radius: 0.02)
  cdraw.content((18.4, 7.5), [\$project], size: 6.5pt)
  cdraw.content((10.0, 6.3), [talkers, rooms, hours via \$toDate], size: 6pt)

  cdraw.content((9.0, 5.2), [the words pipeline], size: 6.5pt)
  cdraw.rect((0.0, 3.2), (3.8, 4.2), fill: luma(235), radius: 0.02)
  cdraw.content((1.9, 3.7), [\$split], size: 6.5pt)
  cdraw.line((3.8, 3.7), (5.0, 3.7), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((5.0, 3.2), (8.8, 4.2), fill: luma(205), radius: 0.02)
  cdraw.content((6.9, 3.7), [\$unwind], size: 6.5pt)
  cdraw.line((8.8, 3.7), (10.0, 3.7), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((10.0, 3.2), (14.8, 4.2), fill: luma(235), radius: 0.02)
  cdraw.content((12.4, 3.7), [\$trim, \$expr], size: 6.5pt)
  cdraw.line((14.8, 3.7), (16.0, 3.7), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((16.0, 3.2), (22.8, 4.2), fill: luma(235), radius: 0.02)
  cdraw.content((19.4, 3.7), [group, sort, limit], size: 6.5pt)

  cdraw.content((10.0, 2.0), [\$unwind multiplies the stream], size: 6pt)
  cdraw.content((10.0, 0.9), [ruinous for megabyte arrays], size: 6pt)
})

`$unwind` is the stage to respect: it multiplies the stream by the
array length before the group collapses it again, which is fine for
chat lines and ruinous for megabyte arrays.

== proven against the real engine

Every pipeline here is exercised twice, and the chapter is honest
about which test proves what. The docker-free suite proves the
plumbing against the go fake, whose Stats is a deliberate transcription
of these stages. The real pipelines run in the docker gate:

#listing("infrastructure/capstone/integration/stack_test.go", first: 96, last: 109, caption: [the docker-gated walk ends on the stats fragment, answered by real mongo aggregation])

#diagram([the two-gate contract: same questions, both must fill wire.Stats identically], length: 13pt, {
  cdraw.rect((0.0, 6.6), (6.6, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((3.3, 7.1), [docker-free gate], size: 6.5pt)
  cdraw.line((6.6, 7.1), (8.0, 7.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((8.0, 6.6), (16.0, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((12.0, 7.1), [the go fake answers], size: 6.5pt)

  cdraw.rect((0.0, 4.4), (6.6, 5.4), fill: luma(235), radius: 0.02)
  cdraw.content((3.3, 4.9), [docker gate], size: 6.5pt)
  cdraw.line((6.6, 4.9), (8.0, 4.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((8.0, 4.4), (16.0, 5.4), fill: luma(235), radius: 0.02)
  cdraw.content((12.0, 4.9), [real mongo answers], size: 6.5pt)

  cdraw.line((16.0, 7.1), (18.3, 6.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((16.0, 4.9), (18.3, 5.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((18.4, 4.95), (23.4, 7.0), fill: luma(205), radius: 0.02)
  cdraw.content((20.9, 6.5), [wire.Stats], size: 6.5pt)
  cdraw.content((20.9, 5.4), [must match], size: 6pt)

  cdraw.content((9.0, 3.2), [the same questions, both gates], size: 6pt)
  cdraw.content((9.0, 2.1), [a red gate is the diagnosis], size: 6pt)
})

#callout("warning", "schemaless does not mean thoughtless", [
  Mongo will store anything. The first document decides the field
  names every later query must agree with, which is a schema with no
  enforcement, the inverse trade of sqlite's strict tables in
  #xref-to("infrastructure", "sqlite-features"). The capstone keeps
  one shaper, `docOf`, as the single place a message becomes a
  document, so drift has one door to walk through.
])

sources: mongodb.com aggregation manual for the stage semantics,
accessed 2026-09-10, and pkg.go.dev for the v2 driver signatures,
verified against the vendored module source. Verified by the history
suite, 5 tests, under `make verify`, and by the docker-gated stats
assertion under `make verify-infra-docker`, both green 2026-09-10.
