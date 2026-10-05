#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw

= database answers

The database round mixes definitional questions, acid, base,
normal forms, isolation levels, with precision questions, money
types, json, geo, cursors. This chapter's rule is the book's rule:
the points this tree can prove on sqlite 3.53 are demonstrated,
the postgres-specific answers are framed as postgres, honestly,
and the one mongo question is implemented as the predicate it
actually runs. 9 tests in `ch17-go` under `make verify`.

== acid and base [DRILL]

Acid is four guarantees a transaction makes: atomicity, all or
nothing, consistency, invariants hold across the boundary,
isolation, concurrent transactions do not see each other's
intermediate state, durability, a commit survives the crash that
follows it. Base is the eventually consistent counterpart,
basically available, soft state, eventually consistent, the
tradeoff distributed stores make when partitions force a choice
between availability and consistency, the cap theorem's corner.

#diagram([acid's four promises against base's partition trade], length: 13pt, {
  // left: one transaction's guarantees; right: the distributed store's concession
  cdraw.content((6.2, 8.8), [acid], size: 6.5pt)
  cdraw.content((18.0, 8.8), [base], size: 6.5pt)
  cdraw.content((6.2, 7.9), [one transaction, four promises], size: 6pt)
  cdraw.content((18.0, 7.9), [the partitioned store], size: 6pt)
  cdraw.line((13.2, 3.0), (13.2, 9.2), stroke: luma(220))
  cdraw.content((6.2, 6.8), [atomicity: all or nothing], size: 6pt)
  cdraw.content((6.2, 5.7), [consistency: invariants hold], size: 6pt)
  cdraw.content((6.2, 4.6), [isolation: no intermediate state], size: 6pt)
  cdraw.content((6.2, 3.5), [durability: commit survives crash], size: 6pt)
  cdraw.content((18.0, 6.8), [basically available], size: 6pt)
  cdraw.content((18.0, 5.7), [soft state], size: 6pt)
  cdraw.content((18.0, 4.6), [eventually consistent], size: 6pt)
  cdraw.content((18.0, 3.5), [the cap corner's answer], size: 6pt)
  cdraw.content((11.1, 2.0), [a partition forces the c-versus-a choice], size: 6pt)
})

The sqlite framing worth saying: sqlite is acid by default, and
the isolation chapter of #xref-to("infrastructure",
"sqlite-transactions") demonstrates the file-level locking that
buys it. Postgres is acid with configurable isolation, and the
isolation levels question, read committed, repeatable read,
serializable, is really the anomalies question, dirty reads,
non-repeatable reads, phantom rows, each level closing one more.

== money is cents [TDD]

Floating point cannot represent 0.1, so float money accumulates
error at the only place error is unacceptable. The demo needs one
go subtlety narrated: constant arithmetic is exact, so `0.1 + 0.2`
as constants folds to the nearest float64 to 0.3 and the drift
disappears, the drift demo uses variables:

#listing("interview-repertoire/samples/ch17-go/money.go", first: 5, last: 40, caption: [the drift, integer totals, formatting at the edge, lossless splits])

#diagram([float drifts, cents stay exact, splits sum back], length: 13pt, {
  // left: variables in float64; right: the same arithmetic in integer cents
  cdraw.content((5.75, 8.8), [float64], size: 6.5pt)
  cdraw.content((17.25, 8.8), [integer cents], size: 6.5pt)
  cdraw.rect((2.0, 7.3), (9.5, 8.2), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((5.75, 7.75), [a, b := 0.1, 0.2], size: 6pt)
  cdraw.line((5.75, 7.3), (5.75, 6.75), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((1.5, 5.75), (10.0, 6.65), fill: luma(205), stroke: luma(120), radius: 0.02)
  cdraw.content((5.75, 6.2), [0.30000000000000004], size: 6pt)
  cdraw.content((5.75, 4.5), [the drift compounds], size: 6pt)
  cdraw.content((5.75, 3.4), [with every sum], size: 6pt)
  cdraw.rect((13.5, 7.3), (21.0, 8.2), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((17.25, 7.75), [10 + 20 cents], size: 6pt)
  cdraw.line((17.25, 7.3), (17.25, 6.75), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((13.5, 5.75), (21.0, 6.65), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((17.25, 6.2), [30 cents, exact], size: 6pt)
  cdraw.content((17.25, 4.5), [1000 split three ways:], size: 6pt)
  cdraw.content((17.25, 3.4), [334 + 333 + 333 = 1000], size: 6pt)
  cdraw.content((11.5, 2.2), [money is cents, division only at the format edge], size: 6pt)
})

The split function is the interview favorite hidden in here:
dividing 1000 cents three ways sums back to exactly 1000 because
the remainder spreads over the first shares. The postgres framing:
`numeric` for money in postgres, never `float4` or `float8`, and
integer cents is the sqlite-native answer this tree uses
everywhere, demonstrated across the capstones of books 12 and 14.

== normalization, proven on both shapes [TDD]

The demo database stores the same facts twice, once as a wide
denormalized row, once as customers and orders with a reference:
the wide table:

#listing("interview-repertoire/samples/ch17-go/indexes.go", first: 28, last: 55, caption: [both schemas side by side, the wide row and the normalized pair])

#diagram([the same facts as one wide row against customers plus orders], length: 13pt, {
  // left: city repeated per order row; right: city stored once, referenced
  cdraw.content((5.75, 9.9), [one wide row], size: 6.5pt)
  cdraw.content((17.25, 9.9), [customers + orders], size: 6.5pt)
  cdraw.rect((1.5, 8.2), (10.0, 9.0), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((5.75, 8.6), [o1 mug hanoi 1200], size: 6pt)
  cdraw.rect((1.5, 7.1), (10.0, 7.9), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((5.75, 7.5), [o2 pen hanoi 300], size: 6pt)
  cdraw.content((5.75, 5.9), [city repeats with every order], size: 6pt)
  cdraw.content((5.75, 4.8), [the update anomaly], size: 6pt)
  cdraw.rect((13.5, 8.4), (21.0, 9.2), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((17.25, 8.8), [customers: c1 hanoi], size: 6pt)
  cdraw.rect((13.5, 5.9), (21.0, 7.7), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((17.25, 7.05), [orders: o1 mug, c1], size: 6pt)
  cdraw.content((17.25, 6.05), [o2 pen, c1], size: 6pt)
  cdraw.line((14.2, 7.7), (14.2, 8.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((17.25, 4.8), [city stored once, joined], size: 6pt)
  cdraw.content((17.25, 3.7), [back per query], size: 6pt)
  cdraw.content((11.5, 2.3), [3nf fails on the wide row: city depends on the customer], size: 6pt)
  cdraw.content((11.5, 1.3), [read speed is what denormalization buys], size: 6pt)
})

#listing("interview-repertoire/samples/ch17-go/indexes.go", first: 88, last: 107, caption: [the wide scan and the join, the same question answered twice])

Both answer "orders in hanoi" and the tests demand the same
number from both. The spoken normalization ladder: first normal
form, atomic values, second, no non-key dependencies on part of a
key, third, none on any non-key attribute, and the wide table
fails third when city depends on customer, not on order. The
tradeoff sentence that finishes the answer: normalization removes
update anomalies, denormalization buys read speed, and mature
systems normalize the source of truth and denormalize deliberately
at materialized edges.

== indexing, proven without a stopwatch [TDD]

The index question is answered with `EXPLAIN QUERY PLAN`, not with
timing:

#listing("interview-repertoire/samples/ch17-go/indexes.go", first: 109, last: 139, caption: [the plan query, and the index matcher over the plan text])

#diagram([the plan text is the proof, not the timing], length: 13pt, {
  // the query, the plan, and the two deterministic outcomes
  cdraw.rect((6.5, 8.7), (14.0, 9.6), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((10.25, 9.15), [lookup by sku], size: 6.5pt)
  cdraw.line((10.25, 8.7), (10.25, 8.1), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((6.0, 7.1), (14.5, 8.0), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((10.25, 7.55), [EXPLAIN QUERY PLAN], size: 6pt)
  cdraw.line((8.0, 7.1), (4.6, 6.75), stroke: luma(100), mark: (end: ">"))
  cdraw.line((12.5, 7.1), (17.8, 6.75), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.2, 4.9), (9.0, 6.7), fill: luma(205), stroke: luma(120), radius: 0.02)
  cdraw.content((4.6, 6.1), [USING COVERING INDEX], size: 6pt)
  cdraw.content((4.6, 5.1), [indexed, proven], size: 6pt)
  cdraw.rect((13.0, 4.9), (22.6, 6.7), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((17.8, 6.1), [no covering index in plan], size: 6pt)
  cdraw.content((17.8, 5.1), [quantity: full scan], size: 6pt)
  cdraw.content((11.4, 3.6), [no stopwatch: deterministic, immune to cache warmth], size: 6pt)
  cdraw.content((11.4, 2.6), [postgres: EXPLAIN ANALYZE, same discipline], size: 6pt)
})

The suite asserts the sku lookup's plan says `USING COVERING
INDEX` and that the unindexed quantity lookup's plan says nothing
of the kind. That is the deterministic version of "the index is
used", immune to cache warmth and machine load, and the postgres
equivalent, `EXPLAIN ANALYZE`, is the same discipline with real
row counts.

== optimistic versus pessimistic locking [TDD]

Pessimistic locks first, writers queue, the database is the
referee. Optimistic writes anyway and checks at commit, the
conflicting loser retries. The demo runs the pessimistic story on
sqlite: one connection holds a write transaction, a second's
`BEGIN IMMEDIATE` fails busy after the timeout:

#listing("interview-repertoire/samples/ch17-go/locking.go", first: 8, last: 45, caption: [two connections, one held write lock, the busy error and its translation])

#diagram([the second writer waits out the timeout, then fails busy], length: 13pt, {
  // two lanes over one time axis: a holds, b waits and fails at the timeout
  cdraw.content((2.2, 6.9), [conn a], size: 6.5pt)
  cdraw.content((2.2, 4.7), [conn b], size: 6.5pt)
  cdraw.rect((5.5, 6.5), (22.0, 7.3), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((13.75, 6.9), [write txn held], size: 6pt)
  cdraw.rect((12.0, 4.3), (19.5, 5.1), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((15.75, 4.7), [BEGIN IMMEDIATE], size: 6pt)
  cdraw.content((18.8, 3.55), [busy, error], size: 6pt)
  cdraw.line((3.5, 2.6), (22.0, 2.6), stroke: luma(100), mark: (end: ">"))
  for x in (5.5, 12.0, 19.5) {
    cdraw.circle((x, 2.6), radius: 0.1, fill: luma(60))
  }
  cdraw.content((5.5, 2.1), [lock won], size: 6pt)
  cdraw.content((12.0, 2.1), [second writer], size: 6pt)
  cdraw.content((19.5, 2.1), [busy timeout], size: 6pt)
  cdraw.content((11.75, 1.0), [postgres mvcc: writers never block readers], size: 6pt)
})

The postgres framing to volunteer: postgres mvcc, multi-version
concurrency control, readers work from a snapshot, is optimistic at
the storage layer, writers never block readers, and explicit
`SELECT FOR UPDATE` is the pessimistic opt-in. The choice rule:
high contention on hot rows favors pessimistic, low contention
with many readers favors optimistic, and retries belong at the
caller.

== cursors, limit offset, and json [DRILL]

Deep `LIMIT OFFSET` pagination degrades linearly, the database
walks and discards the offset, and the fix is keyset pagination,
`WHERE id > $last ORDER BY id LIMIT n`, an index range scan.
Cursors are the database's wire-protocol version of the same idea,
postgres cursor gives streaming fetches without materializing the
whole result, and the interview answer is the tradeoff, offset is
stateless and positionally inconsistent under concurrent writes,
keyset and cursors are stable and bounded. Jsonb in postgres is
for queryable semi-structured data with GIN indexes, the inverted
index over json paths, the sqlite counterpart is the json1
extension book 12 demonstrates on 3.53, and both books agree on
the boundary: structured columns for what you filter and join,
json for what you store and return.

#diagram([offset cost grows with depth; keyset stays constant], length: 13pt, {
  // work per page against page depth: a rising line against a flat one
  cdraw.line((3.2, 2.4), (3.2, 8.8), stroke: luma(120))
  cdraw.line((3.2, 2.4), (20.5, 2.4), stroke: luma(120), mark: (end: ">"))
  cdraw.content((3.2, 9.2), [work], size: 6pt)
  cdraw.content((19.5, 1.9), [page depth], size: 6pt)
  cdraw.line((3.7, 2.9), (17.5, 7.8), stroke: luma(60))
  cdraw.content((16.0, 8.5), [limit offset: walks and discards], size: 6pt)
  cdraw.line((3.7, 5.2), (17.5, 5.2), stroke: luma(150))
  cdraw.content((15.0, 4.5), [keyset: constant per page], size: 6pt)
  cdraw.content((14.0, 3.6), [cursors: streamed on the wire], size: 6pt)
  cdraw.content((9.5, 1.5), [the json boundary: columns filter, json stores], size: 6pt)
})

== mongo geo: the predicate underneath [TDD]

Point in polygon is ray casting: cast east from the point, count
edge crossings, odd is inside, and points exactly on an edge count
as inside because every geo library says so:

#listing("interview-repertoire/samples/ch17-go/geo.go", first: 5, last: 48, caption: [ray casting with the on-edge rule, and the bbox prefilter])

#diagram([ray casting east: odd crossings inside; the bbox prunes first], length: 13pt, {
  // a square polygon, one ray crossing once, one crossing zero, bbox dashed
  cdraw.rect((3.4, 3.4), (11.6, 9.1), stroke: (paint: luma(180), dash: "dashed"))
  cdraw.content((2.6, 9.1), [bbox], size: 6pt)
  cdraw.rect((4.0, 4.0), (11.0, 8.5), stroke: luma(120))
  cdraw.circle((6.0, 6.0), radius: 0.12, fill: luma(60))
  cdraw.line((6.15, 6.0), (12.4, 6.0), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.circle((11.0, 6.0), radius: 0.18, stroke: luma(60))
  cdraw.content((17.3, 6.0), [1 crossing: odd, inside], size: 6pt)
  cdraw.circle((8.0, 3.0), radius: 0.12, fill: luma(60))
  cdraw.line((8.15, 3.0), (10.5, 3.0), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((5.5, 2.2), [0 crossings: outside], size: 6pt)
  cdraw.content((17.3, 4.9), [\$geoWithin and ST_Contains], size: 6pt)
  cdraw.content((17.3, 3.9), [run this exact predicate], size: 6pt)
  cdraw.content((12.5, 1.2), [the bbox prunes, then the ray walk], size: 6pt)
})

The tests cover the square, the concave L, and the boundary
points, then the framing: mongo's `$geoWithin` with `$polygon` and
postgis's `ST_Contains` run this predicate with spatial indexes,
R-trees that prune the search with bounding boxes, which is
exactly what `InBBox` models before the expensive walk.

sources: sqlite behavior verified on 3.53.x through modernc.org
v1.58.0, `go test`, 9 tests in `ch17-go`. Postgres and mongo
claims framed as such, floored to #xref-to("infrastructure",
"sqlite-features") and #xref-to("infrastructure", "mongo") for the
demonstrated versions.
