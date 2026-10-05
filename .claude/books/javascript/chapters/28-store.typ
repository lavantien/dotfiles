#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= store

The service has run so far on in-memory maps, which tests love and
restarts hate. The platform answer is `node:sqlite`, the synchronous
sqlite binding shipped inside the runtime, zero dependencies, one
import. This chapter owns the machinery outright: one connection per
database, prepared statements with placeholders only, migrations as
append-only records, the transaction idiom, the isolation wal actually
gives you, the compare-and-swap that makes lost updates visible, and
analytics in one query.

== node:sqlite from first principles

`DatabaseSync` is synchronous on purpose. `prepare` hands back a
`StatementSync`, the statement answers `run`, `get`, and `all`, and
that is the whole surface the store uses: node 26.3.0 exposes no
source-hash property and no reprepare hooks, so the chapter pins
nothing of the sort. The probe on this machine, 2026-09-26, answers
the stability question empirically: the import prints no
`ExperimentalWarning` on 26.3.0, and `process.features.sqlite` does
not exist here, so the code never cites that flag. Inside one process
the sync shape is the design, one event loop schedules every call,
each call is short, no pool to size, no promise surface to await. The
engine underneath answers `sqlite_version()` as 3.53.4 on node
26.10.0, matching this corpus's pins; it answered 3.53.1 through the
node 26.3.0 era, the known node delta, stated once here.

Values ride placeholders, never concatenation. `exec` runs bare sql
and exists for ddl and transaction control alone, `stmt` prepares once
and binds forever, and the constructor names the two settings that
matter: foreign keys on, and wal for every database that lives in a
file.

#listing("javascript/api/src/store/store.mjs", first: 19, last: 29, caption: [the constructor: one connection, foreign keys on, wal for files])

#diagram([the stack the store sits on], length: 13pt, {
  let stage(y, title, l1, fill) = {
    cdraw.rect((0.9, y), (13.5, y + 1.5), fill: fill, radius: 0.02)
    cdraw.content((7.2, y + 1.0), [#title], size: 6pt)
    cdraw.content((7.2, y + 0.3), [#l1], size: 6pt)
  }
  stage(6.6, [handlers and families], [#"users, analytics, idem over the store"], luma(235))
  cdraw.line((7.2, 6.5), (7.2, 5.9), stroke: luma(100), mark: (end: ">>"))
  stage(4.3, [the Store], [#"stmt cache, tx, migrate"], luma(225))
  cdraw.line((7.2, 4.2), (7.2, 3.6), stroke: luma(100), mark: (end: ">>"))
  stage(2.0, [DatabaseSync], [#"run, get, all, synchronous"], luma(235))
  cdraw.line((7.2, 1.9), (7.2, 1.3), stroke: luma(100), mark: (end: ">>"))
  stage(-0.3, [sqlite 3.53.4 + wal], [#"one file, snapshot reads"], luma(245))
  pane(14.4, 22.6, 6.6, [the discipline], [values ride placeholders,], [exec carries none])
})

== migrations test driven

Schema changes are code changes, so they ship as records, and the
history is append-only by contract: a shipped version is frozen, a
correction is a new numbered version, no record is ever edited. The
registry is a table the database keeps about itself,
`schema_migrations`, and `migrate` applies every pending record at
most once, each inside its own transaction, so a version that fails
halfway leaves nothing durable and can simply be retried.

This wave ships three records. `0001_init` marks the base vocabulary,
users, roles, events, reports, one record for the whole scheme.
`0002_user_versions` adds the `version` column and stands alone
because it is the substrate the compare-and-swap stands on.
`0003_idempotency_keys` adds the table the concurrency chapter fills.
The test drives the runner from an empty directory, proves all three
applied in order, re-runs and proves nothing applies twice, then
closes and reopens to prove the registry came back with it.

#listing("javascript/api/src/store/store.mjs", first: 75, last: 90, caption: [one version, one transaction, one registry row, applied at most once])

#diagram([the version list only grows right], length: 13pt, {
  cdraw.line((0.6, 4.4), (22.0, 4.4), stroke: luma(140))
  cdraw.content((11.3, 5.4), [open time], size: 6.5pt)
  let tick(x, label, l1) = {
    cdraw.line((x, 4.7), (x, 4.1), stroke: luma(100))
    cdraw.rect((x - 3.2, 1.6), (x + 3.2, 4.0), fill: luma(235), radius: 0.02)
    cdraw.content((x, 3.3), [#label], size: 6pt)
    cdraw.content((x, 2.2), [#l1], size: 6pt)
  }
  tick(4.0, [0001_init], [base vocabulary])
  tick(11.3, [0002_user_versions], [the version column])
  tick(18.6, [0003_idempotency_keys], [the key table])
  cdraw.content((11.3, 0.7), [each record in its own transaction, forever append-only], size: 6pt)
})

== one statement, prepared once

Preparing a statement is work: the engine parses the sql, plans it,
and hands back a compiled object. Doing that per call is a tax, and
the idiom is the cache: a `Map` keyed by the exact sql string, first
caller prepares, every later caller receives the same object. The sql
text is a constant in the source, so the same string always means the
same statement. The test holds the cache to its promise, two `stmt`
calls with one string answer one object.

#listing("javascript/api/src/store/store.mjs", first: 34, last: 41, caption: [the statement cache: one prepare per distinct sql string])

#diagram([same string in, same statement out], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.3), (x0 + 5.0, 6.5), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.5, 5.9), [#title], size: 6pt)
    cdraw.content((x0 + 2.5, 4.9), [#l1], size: 6pt)
  }
  step(0.3, [first caller], [#"prepare(sql), map.set"])
  cdraw.line((5.5, 5.4), (5.9, 5.4), stroke: luma(100), mark: (end: ">>"))
  step(5.9, [the Map], [#"sql string to StatementSync"])
  cdraw.line((11.1, 5.4), (11.5, 5.4), stroke: luma(100), mark: (end: ">>"))
  step(11.5, [every caller], [#"map.get, one object"])
  cdraw.content((8.7, 3.4), [parse and plan happen once per statement], size: 6pt)
  cdraw.content((8.7, 2.3), [the sql text is a source constant, the key is stable], size: 6pt)
})

== the transaction idiom

One shape covers every write in the family: `begin immediate`, run,
`commit`, and the `catch` rolls back. Node has no unwinding and no
cancellation context, a synchronous call either returns or throws, so
the catch is the rollback and there is no third exit to guard. The
function never manages its own transaction, the wrapper owns all
three statements, and the discipline pays off twice: a handler that
throws mid-group discards the whole group, and a constraint violation
rolls back and surfaces raw, the caller above decides what it means.
`immediate` takes the write lock up front, so writers serialize on
the engine and the ordering questions never reach the family.

The suite proves the exits. The happy path lands the whole group. The
throwing path discards it and leaves the connection free, the next
write succeeds, a leaked transaction would refuse it. And the error
the caller threw surfaces unwrapped, the marker object the test throws
is the marker object the test catches.

#listing("javascript/api/src/store/store.mjs", first: 53, last: 63, caption: [the idiom: begin immediate, commit on return, rollback on throw])

#diagram([a transaction has exactly two exits], length: 13pt, {
  cdraw.rect((0.4, 5.4), (6.2, 7.2), fill: luma(235), radius: 0.02)
  cdraw.content((3.3, 6.6), [begin immediate], size: 6pt)
  cdraw.content((3.3, 5.8), [the write lock, up front], size: 6pt)
  cdraw.line((3.3, 5.3), (3.3, 4.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((0.4, 3.0), (6.2, 4.5), fill: luma(235), radius: 0.02)
  cdraw.content((3.3, 4.0), [run fn(store)], size: 6pt)
  cdraw.content((3.3, 3.3), [statements, checks], size: 6pt)
  pane(8.6, 14.6, 4.5, [returns], [commit], [the group lands])
  cdraw.line((6.4, 3.7), (8.4, 3.7), stroke: luma(100), mark: (end: ">>"))
  pane(15.8, 21.8, 4.5, [throws], [rollback], [nothing landed])
  cdraw.line((14.8, 3.7), (15.6, 3.7), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((3.3, 1.9), [no cancellation context exists, no third exit to guard], size: 6pt)
  cdraw.content((3.3, 0.8), [fn never manages its own transaction], size: 6pt)
})

== the snapshot sqlite actually gives you

The textbook menu, read uncommitted through serializable, is a menu of
guarantees a general engine picks among. What this engine serves is a
fact about two settings the code states itself: wal journal mode, and
`begin deferred` on the reader. A deferred read transaction pins its
snapshot at the first read, every later read inside it sees the same
view, and the writer commits past it without blocking, which is what
wal buys. No dirty reads, because a reader's view is a state that was
committed. No non-repeatable reads inside one transaction, because
the view never moves. Write skew stays possible, two writers can act
on disjoint stale reads and both commit clean. Writers serialize on
`immediate`. That is snapshot isolation, and no configuration file
stands between the claim and the two statements that make it true.

The demo stays deterministic, and in node the determinism is free: the
interleave is the statement order, one thread, no callbacks, no timers.
The reader opens and reads 1. The writer commits 2. The reader reads
again inside its transaction and still sees 1. A fresh read sees 2.
The reader commits and sees 2:

#listing("javascript/api/test/store/isolation.test.mjs", first: 20, last: 29, caption: [pin a view, commit past it, read again: the statement order is the schedule])

#diagram([one timeline: the reader's view holds], length: 13pt, {
  cdraw.line((0.6, 1.0), (22.4, 1.0), stroke: luma(140))
  cdraw.content((11.5, 6.9), [reader, begin deferred], size: 6.5pt)
  cdraw.line((2.0, 6.3), (6.4, 6.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((4.2, 5.6), [first read: version 1], size: 6pt)
  cdraw.line((6.4, 6.3), (16.2, 6.3), stroke: luma(80))
  cdraw.content((11.3, 5.6), [view pinned], size: 6pt)
  cdraw.line((16.2, 6.3), (21.4, 6.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((18.8, 5.6), [second read: still 1], size: 6pt)
  cdraw.content((11.5, 3.9), [writer], size: 6.5pt)
  cdraw.line((9.6, 3.3), (14.6, 3.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((12.1, 2.6), [commits version 2, no block], size: 6pt)
  cdraw.line((14.6, 3.3), (14.6, 1.2), stroke: luma(120), mark: (end: ">>"))
  cdraw.content((12.1, 1.4), [fresh read outside sees 2], size: 6pt)
  pane(16.9, 22.4, 3.3, [what it is], [snapshot isolation,], [not full serializability])
})

== the lost update and the compare-and-swap answer

Two writers read the same user, both compute, both write, and one
update silently vanishes. The engine reproduces it with two blind
updates: both succeed, the second name is all that survives, and the
`version` column never moved, so nothing anywhere records that
anything was lost. Serialization does not fix this, the write lock
guarantees each write lands whole and says nothing about the stale
read the write was computed from. That invisibility is what makes the
lost update the classic bug, the writer that caused it gets a success
answer.

The version column is the detector and the compare-and-swap is the
fix. The whole exchange runs inside one `begin immediate` transaction:
the update refuses anything but the expected version, bumps and writes
in the same statement, and `changes === 0` means a refusal, the
current version read back so the caller can answer precisely. Of two
writers holding version 1 exactly one wins, and the loser learns the
fact, which over http is exactly the 412 the next chapter stages with
two concurrent PATCHers.

#listing("javascript/api/src/store/users.mjs", first: 78, last: 96, caption: [the cas: refuse, bump, and write in one statement inside one transaction])

#diagram([same race, two outcomes: silent loss versus a refused writer], length: 13pt, {
  pane(0.3, 10.6, 7.4, [before, blind writes], [both read name, version 1], [both write, both succeed], [one write vanished])
  cdraw.line((10.8, 5.5), (11.6, 5.5), stroke: luma(100), mark: (end: ">>"))
  pane(11.8, 22.3, 7.4, [after, the cas], [both read version 1], [one commits version 2], [loser answers refused])
  cdraw.content((5.4, 2.6), [version never moves, loss invisible], size: 6pt)
  cdraw.content((17.0, 2.6), [version bumps, the loss is a 412], size: 6pt)
  cdraw.content((11.3, 0.9), [the write lock holds the window shut, the version check is the fix], size: 6pt)
})

== analytics in one query

Reports are sql's home turf, and the engine answers them natively. The
events table carries the day and the user beside every fact, so the
daily active count is one `group by` over distinct users in day order,
and the frozen report rows fall out exactly: seed the three events the
vector's setup names and the query answers the pair of rows the
contract freezes. The window functions are where one query replaces a
loop, and the probe pinned them on this build's engine, on 3.53.1 at
first measure and again on the 3.53.4 that node 26.10.0 bundles: the
running total is `sum(active) over (order by day)`, and each user's
first day is `row_number() over (partition by user_id)`. Both answered
in the probe, so the chapter promises them.

The queries stay in sql because the engine's own aggregation is the
honest tool, and the rows leave the family as plain objects, the
null-prototype rows `node:sqlite` answers are absorbed at the
boundary.

#listing("javascript/api/src/store/analytics.mjs", first: 32, last: 38, caption: [the window function: a running total across the window in one query])

#diagram([keys to window to the report body], length: 13pt, {
  let step(x0, w, title, l1) = {
    cdraw.rect((x0, 3.9), (x0 + w, 6.4), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + w / 2, 5.7), [#title], size: 6pt)
    cdraw.content((x0 + w / 2, 4.7), [#l1], size: 6pt)
  }
  step(0.3, 4.4, [events rows], [one row per action])
  cdraw.line((4.9, 5.1), (5.3, 5.1), stroke: luma(100), mark: (end: ">>"))
  step(5.3, 4.8, [group by day], [distinct users per day])
  cdraw.line((10.3, 5.1), (10.7, 5.1), stroke: luma(100), mark: (end: ">>"))
  step(10.7, 5.2, [the window], [sum over day order])
  cdraw.line((16.1, 5.1), (16.5, 5.1), stroke: luma(100), mark: (end: ">>"))
  step(16.5, 5.8, [report rows], [the frozen vector bytes])
  cdraw.content((9.0, 2.7), [the frozen rows: two days, actives 1 then 2], size: 6pt)
  cdraw.content((9.0, 1.6), [newcomers: row_number over the user partition], size: 6pt)
})

== store tests without docker

Every test in the family starts the same way: open a store, an
in-memory database or a fresh temp file, migrate, run, close. No
container, no shared server, no ordering between tests, and nothing
sleeps: the api is synchronous, the clock is injected, and the one
clock-dependent path in the family, the idempotency key's 24 hour
window, runs under `mock.timers` with `tick` as the only clock. The
file facts are deterministic by construction, and the recovery
questions the go lane asked its own engine do not exist here because
the engine is sqlite's, not ours.

The property loop rides the prng the book already states, splitmix32,
seed committed in the file. The invariant is named in the source:
paging the keyset scan with arbitrary limits and the previous page's
last row as the cursor concatenates to exactly the single full ordered
scan, and the seed shuffles insertion order and forces timestamp
collisions so the id half of the keyset carries weight. Node has no
native fuzzing, so the loop is the property check and the seed is the
case.

#listing("javascript/api/test/store/property.test.mjs", first: 24, last: 29, caption: [the property loop: fixed seed, named invariant, one store per test])

#diagram([a store test's lifecycle, nothing shared between runs], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.0, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.5, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.5, 5.0), [#l1], size: 6pt)
  }
  step(0.3, [open], [#"in-memory or temp file"])
  cdraw.line((5.5, 5.5), (5.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(5.9, [migrate], [three records, once])
  cdraw.line((11.1, 5.5), (11.5, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(11.5, [seed, act, assert], [injected clock, frozen bytes])
  cdraw.line((16.7, 5.5), (17.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(17.1, [close], [temp dirs removed])
  cdraw.content((9.4, 3.5), [no container, no port, no sleep], size: 6pt)
  cdraw.content((9.4, 2.4), [38 tests, one property loop, seed 0x12345678], size: 6pt)
})

sources: nodejs.org/api/sqlite.html for the `DatabaseSync`
constructor, `StatementSync`, and the run, get, all contracts,
accessed 2026-09-26, nodejs.org/api/test.md for the `mock.timers`
clock the idempotency window rides, accessed 2026-09-26, and
sqlite.org/wal.html with sqlite.org/lang_transaction.html for the
snapshot semantics of wal readers and the begin modes, accessed
2026-09-26. The stability and version facts are the T0b probe on node
26.3.0, 2026-09-26. Verified by the 38 `test/store` tests under
`node --test` in `npm run verify`.
