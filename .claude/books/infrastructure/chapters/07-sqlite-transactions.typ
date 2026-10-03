#import "../../theme/lib.typ": cdraw, diagram, listing, snippet, callout, xref-to

= sqlite: transactions and isolation

Sqlite's concurrency story is small enough to hold in your head and
strict enough to bite anyone who holds it loosely. This chapter pins
the actual behavior with executed probes against the 3.53.4 engine the
repo links, every claim a test that fails if the engine changes its
mind.

== a read transaction is a snapshot

A deferred transaction, what go's `database/sql` gives you with
`Begin`, takes no lock at all until the first statement runs. A read
statement takes the shared lock and, more importantly, fixes the
transaction's view: everything committed after that first read is
invisible until the transaction ends. That is repeatable read, with no
isolation level to configure, and the probe pins both halves:

#listing("infrastructure/samples/ch07/isolation_test.go", first: 70, last: 105, caption: [the snapshot opens at first read and survives another connection's commit])

#diagram([the snapshot interleaving, two connections on one timeline], length: 13pt, {
  cdraw.rect((1.6, 9.0), (6.4, 9.9), fill: luma(205), radius: 0.02)
  cdraw.content((4.0, 9.45), [reader], size: 6.5pt)
  cdraw.rect((13.6, 9.0), (18.4, 9.9), fill: luma(205), radius: 0.02)
  cdraw.content((16.0, 9.45), [writer], size: 6.5pt)
  cdraw.line((4.0, 9.0), (4.0, 0.6), stroke: luma(220))
  cdraw.line((16.0, 9.0), (16.0, 0.6), stroke: luma(220))

  cdraw.rect((3.85, 7.65), (4.15, 7.95), fill: luma(100))
  cdraw.content((6.9, 7.8), [begin, deferred], size: 6pt)
  cdraw.rect((3.85, 6.25), (4.15, 6.55), fill: luma(100))
  cdraw.content((8.6, 6.4), [first read, snapshot opens], size: 6pt)
  cdraw.rect((15.85, 4.85), (16.15, 5.15), fill: luma(100))
  cdraw.content((12.0, 5.0), [insert, commit row 2], size: 6pt)
  cdraw.rect((3.85, 3.45), (4.15, 3.75), fill: luma(100))
  cdraw.content((6.1, 3.6), [count = 1], size: 6pt)
  cdraw.content((10.7, 3.6), [row 2 invisible], size: 6pt)
  cdraw.rect((3.85, 2.05), (4.15, 2.35), fill: luma(100))
  cdraw.content((5.9, 2.2), [rollback], size: 6pt)
  cdraw.rect((3.85, 0.65), (4.15, 0.95), fill: luma(100))
  cdraw.content((7.4, 0.8), [fresh read sees 2], size: 6pt)

  cdraw.content((11.0, -0.6), [repeatable read, with no knob], size: 6.5pt)
})

The reader's open transaction counts one row after the writer
committed a second, and a fresh read after the rollback sees two. The
writer in this probe runs in wal mode, where commits do not wait for
readers, which is the next chapter's whole subject.

== the lock ladder, shared to reserved to exclusive

Rollback journal mode, the non-wal default, walks a ladder. A reader
holds shared. A writer's insert takes reserved, which coexists with
any number of shared locks, so writers really can write while readers
read. The commit is where it ends: committing needs exclusive, and
exclusive waits for every shared lock to release:

#listing("infrastructure/samples/ch07/isolation_test.go", first: 110, last: 147, caption: [the insert lands under readers, the commit does not, until the reader closes])

#diagram([the lock ladder a writer climbs, and what blocks at the top], length: 13pt, {
  cdraw.rect((0.0, 4.4), (8.0, 6.8), fill: luma(235), radius: 0.02)
  cdraw.content((4.0, 6.25), [shared], size: 6.5pt)
  cdraw.content((4.0, 5.15), [any number of readers], size: 6pt)
  cdraw.line((8.0, 5.6), (9.5, 5.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((8.75, 7.5), [the insert lands], size: 6pt)
  cdraw.rect((9.6, 4.4), (17.0, 6.8), fill: luma(235), radius: 0.02)
  cdraw.content((13.3, 6.25), [reserved], size: 6.5pt)
  cdraw.content((13.3, 5.15), [one writer, inserting], size: 6pt)
  cdraw.line((17.0, 5.6), (18.1, 5.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((17.6, 7.5), [commit], size: 6pt)
  cdraw.rect((18.2, 4.4), (24.0, 6.8), fill: luma(205), radius: 0.02)
  cdraw.content((21.1, 6.25), [exclusive], size: 6.5pt)
  cdraw.content((21.1, 5.15), [at commit only], size: 6pt)

  cdraw.content((12.0, 3.2), [reserved coexists with shared], size: 6pt)
  cdraw.content((12.0, 2.1), [exclusive waits for every shared to release], size: 6pt)
})

Two behaviors live in that probe. With `busy_timeout=0` the blocked
commit surfaces as an immediate `SQLITE_BUSY` error, and after the
reader rolls back the same sequence commits. The nuance most people
miss is that the write itself succeeded, only the durability step was
refused, so an application that retries the wrong thing, the insert
instead of the commit, corrupts nothing but duplicates plenty.

== busy_timeout, the difference between error and wait

`busy_timeout` tells sqlite to park instead of failing when a lock is
held, and the probe measures it happening:

#listing("infrastructure/samples/ch07/isolation_test.go", first: 151, last: 181, caption: [the writer's commit parks roughly 400ms until the goroutine releases the reader])

#diagram([one blocked commit, two settings: error at once or a bounded wait], length: 13pt, {
  cdraw.content((4.0, 8.4), [timeout 0], size: 6.5pt)
  cdraw.rect((0.0, 6.0), (5.6, 7.0), fill: luma(235), radius: 0.02)
  cdraw.content((2.8, 6.5), [commit blocked], size: 6pt)
  cdraw.line((5.6, 6.5), (7.1, 6.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((7.2, 6.0), (15.6, 7.0), fill: luma(235), radius: 0.02)
  cdraw.content((11.4, 6.5), [SQLITE_BUSY, immediate], size: 6pt)

  cdraw.content((4.0, 4.8), [timeout 3000], size: 6.5pt)
  cdraw.rect((0.0, 2.4), (7.2, 3.4), fill: luma(235), radius: 0.02)
  cdraw.content((3.6, 2.9), [commit parks ~400ms], size: 6pt)
  cdraw.line((7.2, 2.9), (8.7, 2.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((8.8, 2.4), (14.8, 3.4), fill: luma(235), radius: 0.02)
  cdraw.content((11.8, 2.9), [reader releases], size: 6pt)
  cdraw.line((14.8, 2.9), (16.3, 2.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((16.4, 2.4), (21.2, 3.4), fill: luma(205), radius: 0.02)
  cdraw.content((18.8, 2.9), [commit lands], size: 6pt)

  cdraw.content((10.2, 1.2), [retry the commit, not the insert], size: 6pt)
  cdraw.content((10.2, 0.1), [retrying the insert duplicates work], size: 6pt)
})

The elapsed-time assertion is the honest part: the test would fail if
the commit sneaked in before the reader released, and it would fail if
the wait were unbounded, because the deadline goroutine would leave
the reader open and the test would time out instead.

Writers serialize with each other in every mode, and the last probe
covers both sides of that: a zero-timeout second writer gets the
error, a waiting one gets the lock after the first commits:

#listing("infrastructure/samples/ch07/isolation_test.go", first: 186, last: 235, caption: [immediate busy without a timeout, ordered handoff with one])

That pair is the whole case for the capstone's `store.Open` setting
`busy_timeout=5000`: transient contention between the chat writer and
an occasional administrative write becomes a five second wait, not an
error the user sees.

#callout("warning", "isolation is per transaction, not per connection", [
  A connection with no open transaction sees the latest committed
  state on every query, which is why the probe rolls back before its
  final count. Treating a pooled `*sql.DB` as if it had one
  long-lived snapshot, which go's pool makes it not have anyway, is
  the classic way to be surprised by sqlite's "anomalies" that are
  actually two different transactions doing exactly what they said.
])

sources: sqlite.org lockingv3 for the shared, reserved, exclusive
ladder and the wal comparison, accessed 2026-09-10. Verified by the
ch07 probe suite, 5 tests, executed against the modernc 3.53.4 engine
and cross-checked against the pinned amalgamation binary in
tools/sqlite/build, green under `make verify` 2026-09-10.
