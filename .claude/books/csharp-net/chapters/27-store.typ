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

The service has run on in-memory maps, which tests love and restarts
hate. This lane's answer is its named infrastructure: Microsoft.Data.Sqlite
over the SQLitePCLRaw e_sqlite3 bundle, the native engine reporting
version 3.53.4, driven through the plain ADO.NET surface the platform
ships. No object relational mapper sits in the graph. EF Core is dated
meta in the suite chapter and nothing here needs it, because the whole
job is schema migrations that append and never edit, parameterized
queries that carry a cancellation token every time, the transaction
idiom in its using-block form, the isolation a wal-mode sqlite actually
gives, the version guard that makes lost updates visible, keyset
pagination as one row-value comparison, and the window-function report
the go book's engine era walked in loops instead.

== ado.net and microsoft.data.sqlite

ADO.NET is a protocol, not a database. A program opens a connection by
connection string, creates commands against it, binds values as
parameters, and reads rows through a data reader, and any provider that
implements the shape can sit underneath. Microsoft.Data.Sqlite is that
provider: SqliteConnection, SqliteCommand, SqliteDataReader, and the
native engine arrives through SQLitePCLRaw.bundle_e_sqlite3, pinned at
3.0.5 alongside the provider at 10.0.12, the same pins the samples and
the capstone carry.

Two platform facts shape every line of this store. First,
SqliteConnection is not thread-safe: instances are never shared across
calls, each operation opens its own connection, and pooling would make
that cheap except the tests turn it off, because a pooled connection
holds the file open on Windows and a temp directory would not delete
clean. Second, the connection string is the one place configuration
lives: data source, Pooling=False, Foreign Keys=True so references
actually bite, and Default Timeout 5 as the busy-retry budget the
provider spends automatically when a lock is contended.

#listing("csharp-net/api/src/CsharpBook.Api/Store/StoreDb.cs", first: 20, last: 44, caption: [the connection string hub and the open that arms wal, foreign keys, and the busy budget]) // PIN: connection string + open

Values ride parameters, never string concatenation, and the parameter
prefix this store standardizes on is the dollar sign, `$id`, `$email`, `$limit`. The
wal pragma is the concurrency decision and it is persistent in the file,
so issuing it per open is idempotent: writers append to the log while
readers keep snapshots of the database file, one writer at a time.

#diagram([the stack the store sits on], length: 13pt, {
  let stage(y, title, l1, fill) = {
    cdraw.rect((0.9, y), (13.5, y + 1.5), fill: fill, radius: 0.02)
    cdraw.content((7.2, y + 1.0), [#title], size: 6pt)
    cdraw.content((7.2, y + 0.3), [#l1], size: 6pt)
  }
  stage(6.6, [handlers and stores], [#"IUserStore, ISessionStore adapters"], luma(235))
  cdraw.line((7.2, 6.5), (7.2, 5.9), stroke: luma(100), mark: (end: ">>"))
  stage(4.3, [ADO.NET + Microsoft.Data.Sqlite], [the provider, parameters only], luma(225))
  cdraw.line((7.2, 4.2), (7.2, 3.6), stroke: luma(100), mark: (end: ">>"))
  stage(2.0, [the sqlite engine], [#"e_sqlite3, reports 3.53.4"], luma(235))
  cdraw.line((7.2, 1.9), (7.2, 1.3), stroke: luma(100), mark: (end: ">>"))
  stage(-0.3, [the database file], [wal journal, snapshot readers], luma(245))
  pane(14.4, 22.6, 6.6, [no orm], [EF Core is dated meta,], [never imported])
})

== migrations test driven

Schema changes are code changes, so they ship as records, and the
history is append-only by contract: a shipped version is frozen, a
correction is a new numbered version, and no record is ever edited. The
registry is the user_version pragma, an integer sqlite keeps in the
database header itself, so no table the database keeps about itself can
drift from the schema it describes.

This wave ships three versions. Version 1 is the whole vocabulary in
one record, users with their email uniqueness index, roles, sessions
with their refresh token history, events as one presence row per user
per day, reports with their idempotency claim. Version 2 adds the user
version column, the substrate the optimistic concurrency sections stand
on, and the keyset index beside it. Version 3 adds the idempotency keys
table the concurrency chapter fills. Each applies inside its own
transaction with the version bump in the same group, so a version that
fails halfway leaves nothing durable and can simply be retried.

#listing("csharp-net/api/src/CsharpBook.Api/Store/StoreDb.cs", first: 90, last: 110, caption: [one version, one transaction, the ddl and the header bump land together, applied at most once]) // PIN: migrate loop

The test drives the runner from an empty directory, proves all three
records applied in order, re-runs and proves nothing applies twice,
reopens the database and proves the registry came back with it, then
reads sqlite_master and asserts every table and index the contract's
vocabulary names, nothing more and nothing less.

#diagram([the version list only grows right], length: 13pt, {
  cdraw.line((0.6, 4.4), (22.0, 4.4), stroke: luma(140))
  cdraw.content((11.3, 5.4), [open time], size: 6.5pt)
  let tick(x, label, l1) = {
    cdraw.line((x, 4.7), (x, 4.1), stroke: luma(100))
    cdraw.rect((x - 3.2, 1.6), (x + 3.2, 4.0), fill: luma(235), radius: 0.02)
    cdraw.content((x, 3.3), [#label], size: 6pt)
    cdraw.content((x, 2.2), [#l1], size: 6pt)
  }
  tick(4.0, [version 1], [the base vocabulary])
  tick(11.3, [version 2], [user version column])
  tick(18.6, [version 3], [idempotency keys])
  cdraw.content((11.3, 0.7), [user_version in the header, one integer, append-only history], size: 6pt)
})

== queries with cancellation every time

Every store method takes a CancellationToken and hands it to every
command, ExecuteReaderAsync with the token, ExecuteNonQueryAsync with
the token, and the surface never drops it. What the provider does with
it is stated plainly because the docs state it: sqlite does not support
asynchronous execution, the async methods run synchronously, and the
provider's own guidance points at write-ahead logging as the real
concurrency lever. The token is honored before a statement runs, a
pre-canceled token answers OperationCanceledException and nothing
reaches the database, which is exactly what the cancellation test
asserts with no clock and no sleep.

The timeout story rides the same budget. On a busy or locked error the
provider retries automatically until the command timeout, Default
Timeout 5 seconds from the connection string, and that is why no retry
loop appears anywhere in this store: the platform already wrote it.

The adapters implement the two ports the earlier chapters froze,
IUserStore and ISessionStore, outcome for outcome, so no handler can
tell sqlite from the in-memory maps the tests grew up on. One read is
one deferred transaction, one parameterized statement, one mapping into
a domain record that carries no provider types, and the roles ride
their own ordered query inside the same snapshot:

#listing("csharp-net/api/src/CsharpBook.Api/Store/SqliteUserStore.cs", first: 182, last: 200, caption: [one read through the adapter: token in, statement bound, domain record out, roles in the same snapshot]) // PIN: read path

#diagram([one read's path from caller to domain record], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.3), (x0 + 5.0, 6.5), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.5, 5.9), [#title], size: 6pt)
    cdraw.content((x0 + 2.5, 4.9), [#l1], size: 6pt)
  }
  step(0.3, [caller's token], [deadline, cancel])
  cdraw.line((5.5, 5.4), (5.9, 5.4), stroke: luma(100), mark: (end: ">>"))
  step(5.9, [deferred read tx], [snapshot pinned at first read])
  cdraw.line((11.1, 5.4), (11.5, 5.4), stroke: luma(100), mark: (end: ">>"))
  step(11.5, [bound command], [#"WHERE email = $email"])
  cdraw.line((16.7, 5.4), (17.1, 5.4), stroke: luma(100), mark: (end: ">>"))
  step(17.1, [the User record], [no provider types])
  cdraw.content((8.7, 3.4), [a pre-canceled token refuses before any statement runs], size: 6pt)
  cdraw.content((8.7, 2.3), [busy retry is the provider's, inside the timeout budget], size: 6pt)
  cdraw.content((8.7, 1.2), [a duplicate email is refused by the unique index itself], size: 6pt)
})

== the transaction idiom

One shape covers every write in the service: take the transaction, run
the body, commit, and let any other exit discard. The provider's
default transaction issues BEGIN IMMEDIATE, the write lock is taken up
front rather than at the first write, so the busy budget is spent where
the caller chose to write. The body stages whatever it likes. Commit
lands the group. Everything else, a thrown exception, a failed
statement, a cancellation, unwinds through the await using, and
DisposeAsync rolls an uncommitted transaction back. That is the deferred
rollback lesson restated for using blocks: the dispose is the rollback,
no finally dance, no manual Rollback call on the error path, and after a
commit the same dispose is a no-op because there is nothing left to
undo.

The tests pin all three exits. A committed group lands. A body that
inserts and then throws leaves nothing, and an earlier committed group
survives the failure beside it. A group whose second statement violates
the email index rolls back its first statement too, because groups are
atomic or they are nothing. The session adapter carries the hardest
case: presenting a superseded refresh token revokes the whole family
inside the same write transaction and the SessionRevoked answer is
returned after the revocation landed, so the family cannot be rolled
back to life.

#listing("csharp-net/api/src/CsharpBook.Api/Store/StoreDb.cs", first: 61, last: 70, caption: [the write shape: begin immediate, body, commit, and the dispose is the deferred rollback]) // PIN: with-tx shape

#diagram([a transaction's exits, every one of them clean], length: 13pt, {
  cdraw.rect((0.4, 5.4), (6.2, 7.2), fill: luma(235), radius: 0.02)
  cdraw.content((3.3, 6.6), [write tx, begin immediate], size: 6pt)
  cdraw.content((3.3, 5.8), [the body stages its writes], size: 6pt)
  cdraw.line((3.3, 5.3), (3.3, 4.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((0.4, 3.0), (6.2, 4.5), fill: luma(235), radius: 0.02)
  cdraw.content((3.3, 4.0), [run the body], size: 6pt)
  cdraw.content((3.3, 3.3), [inserts, updates, checks], size: 6pt)
  pane(8.6, 14.6, 4.5, [body completes], [commit lands the group], [dispose is a no-op])
  cdraw.line((6.4, 3.7), (8.4, 3.7), stroke: luma(100), mark: (end: ">>"))
  pane(15.8, 21.8, 4.5, [any other exit], [dispose rolls it back], [throw, failed statement])
  cdraw.line((14.8, 3.7), (15.6, 3.7), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((3.3, 1.9), [the await using is the deferred rollback, no finally dance], size: 6pt)
  cdraw.content((3.3, 0.8), [a revoked family cannot be rolled back to life], size: 6pt)
})

== isolation levels and what sqlite actually gives you

The textbook menu, read uncommitted through serializable, is a menu of
guarantees a general engine picks among. Microsoft.Data.Sqlite treats
the level passed to BeginTransaction as a minimum and promotes, and the
two levels it actually serves are serializable by default, and read
uncommitted only over a shared cache, which is exactly the dirty-read
mode the transactions documentation demonstrates and exactly what
nobody wants beside a wal. No configuration file stands between the
claim and the mechanism here, the mechanism is wal plus one writer.

What that buys is snapshot isolation. A deferred transaction begins as
nothing and becomes a read transaction at its first statement, pinning
the snapshot it then keeps for its whole life. No dirty reads, because
readers only ever see committed database states. No non-repeatable
reads inside one transaction, because the snapshot never moves. One
writer at a time, because BEGIN IMMEDIATE takes the write lock before
the first write. Write skew stays possible, two writers can act on
disjoint stale snapshots and each commit cleanly, and that boundary is
a fact about the locks, stated where the code states it.

The demo stays deterministic and single threaded, which is the whole
trick. The reader's connection opens a deferred transaction and reads,
capturing its view. A second connection commits past the pinned
snapshot, and wal is what lets it, the reader holds no lock the writer
needs. The reader reads again inside its transaction and still sees the
old value, and a fresh read outside sees the new one. No thread, no
barrier, no sleep, the interleave is the test's own statement order:

#listing("csharp-net/api/tests/CsharpBook.Api.Tests/Store/IsolationTests.cs", first: 31, last: 53, caption: [pin a view, commit past it, read again: the interleave is the statement order]) // PIN: snapshot pin demo

#diagram([one timeline: the reader's view holds], length: 13pt, {
  cdraw.line((0.6, 1.0), (22.4, 1.0), stroke: luma(140))
  cdraw.content((11.5, 6.9), [reader, deferred tx], size: 6.5pt)
  cdraw.line((2.0, 6.3), (6.4, 6.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((4.2, 5.6), [first read pins the view], size: 6pt)
  cdraw.line((6.4, 6.3), (16.2, 6.3), stroke: luma(80))
  cdraw.content((11.3, 5.6), [view pinned at the old value], size: 6pt)
  cdraw.line((16.2, 6.3), (21.4, 6.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((18.8, 5.6), [second read: still old], size: 6pt)
  cdraw.content((11.5, 3.9), [writer], size: 6.5pt)
  cdraw.line((9.6, 3.3), (14.6, 3.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((12.1, 2.6), [commits the new value], size: 6pt)
  cdraw.line((14.6, 3.3), (14.6, 1.2), stroke: luma(120), mark: (end: ">>"))
  cdraw.content((12.1, 1.4), [a fresh read outside sees new], size: 6pt)
  pane(16.9, 22.4, 3.3, [what it is], [snapshot isolation,], [not full serializability])
})

== the lost update demo and the CAS answer

Two writers read the same user, both compute, both write, and one
update silently vanishes. The store reproduces it with two blind
writes, UPDATE with no version guard: both report one row affected,
both succeed, the second name is all that survives, and the version
column never moved, so nothing anywhere records that anything was lost.
Serialization does not fix this, and owning the transaction shape makes
the reason visible: BEGIN IMMEDIATE guarantees each write lands whole
and says nothing about the stale read the write was computed from, so
the serialized blind writers merely lose the update in a tidy order.

The version column is the detector and the guarded update is the fix,
the strong discipline in SQL form. The check, the bump, and the write
share one statement inside one write transaction, so no second writer
can slip between the read and the write. A mismatch answers zero rows
affected, the adapter classifies it against the known id, and the
client learns VersionMismatch, which over http is exactly the 412 the
next chapter's ETag duel stages with two released patchers. Of two
racers holding version 1 exactly one affects a row, and the loser gets
the refusal it must handle:

#listing("csharp-net/api/src/CsharpBook.Api/Store/SqliteUserStore.cs", first: 83, last: 100, caption: [the guarded update: check, bump, and write in one statement, zero rows is the refusal]) // PIN: cas update

#diagram([same race, two outcomes: silent loss versus a refused writer], length: 13pt, {
  pane(0.3, 10.6, 7.4, [before, blind writes], [both read name, version 1], [both write, both succeed], [one write vanished])
  cdraw.line((10.8, 5.5), (11.6, 5.5), stroke: luma(100), mark: (end: ">>"))
  pane(11.8, 22.3, 7.4, [after, the guard], [both read version 1], [one commits version 2], [loser: zero rows, 412])
  cdraw.content((5.4, 2.6), [version never moves, loss invisible], size: 6pt)
  cdraw.content((17.0, 2.6), [version bumps, the loss is a 412], size: 6pt)
  cdraw.content((11.3, 0.9), [begin immediate holds the window shut, the where clause is the fix], size: 6pt)
})

== analytics with window functions

Reports are sql's home turf, and this lane keeps them there. Presence
collapses events to one row per user per day before any counting
happens, because actives count users, not actions: the events primary
key is the pair (day, user_id) and the insert rides ON CONFLICT DO
NOTHING, so a duplicate event is absorbed at write time. From there the
windows do the work. ROW_NUMBER partitioned by user in day order marks
each user's first day in the window as nth = 1, which is the newcomer
split. LAG carries yesterday's count forward with today's as its
default, so the first day's delta is zero by construction, the same
arithmetic without the self-join. Leaders rank by count descending then
user id ascending, a total order, so a replayed report cannot differ
run to run.

Days are ISO text and text comparison is chronological for ISO dates,
so the window bounds are two string parameters. One report reads
inside one deferred transaction, so it always sees one snapshot of the
events, never a torn view of an insert in flight. The wire projection
keeps only day and active, and over the frozen vector's seeded events,
(2026-09-25, ada), (2026-09-26, ada), (2026-09-26, grace), the series
is exactly the golden rows, 1 then 2, asserted against the vector file
itself:

#listing("csharp-net/api/src/CsharpBook.Api/Store/Analytics.cs", first: 29, last: 50, caption: [the report query: presence, row_number for the newcomer split, lag for the delta]) // PIN: daily active sql

#diagram([events rows to windows to the report body], length: 13pt, {
  let step(x0, w, title, l1) = {
    cdraw.rect((x0, 3.9), (x0 + w, 6.4), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + w / 2, 5.7), [#title], size: 6pt)
    cdraw.content((x0 + w / 2, 4.7), [#l1], size: 6pt)
  }
  step(0.3, 4.4, [events rows], [one presence per user per day])
  cdraw.line((4.9, 5.1), (5.3, 5.1), stroke: luma(100), mark: (end: ">>"))
  step(5.3, 4.8, [row_number], [nth = 1 is the first day])
  cdraw.line((10.3, 5.1), (10.7, 5.1), stroke: luma(100), mark: (end: ">>"))
  step(10.7, 5.2, [group and lag], [actives, newcomers, delta])
  cdraw.line((16.1, 5.1), (16.5, 5.1), stroke: luma(100), mark: (end: ">>"))
  step(16.5, 5.8, [report body], [day and active on the wire])
  cdraw.content((9.0, 2.7), [all inside one deferred transaction, one snapshot], size: 6pt)
  cdraw.content((9.0, 1.6), [leaders: count desc then user id asc, replay stable], size: 6pt)
})

== store tests without docker

Every test in the suite starts the same way: a fresh temp directory, a
StoreDb pointed at a file inside it, MigrateAsync, act, dispose, and
the directory deletes clean because Pooling=False means the file
handles die with their connections. No container, no port, no shared
server, no ordering between tests. Nothing in the suite sleeps: the
cancellation test pre-cancels a token, the snapshot interleave is
statement order, the guarded-update duel needs no barrier at the store
layer because BEGIN IMMEDIATE serializes the racers itself. The clock
is never read by the store at all, the session port's lifetime policy
belongs to its callers, and the one golden-body assertion walks up from
the assembly until it finds the frozen vector file under
contract/testdata, so the suite finds the bytes from any harness depth.

The fixtures seed through the schema itself, straight SQL with bound
parameters, because this chapter's tests exercise machinery rather
than handlers, and the foreign keys bite the fixture that forgets its
user row, which is the constraint doing its job. Forty-six store tests
in nine files cover the migrations, the open and its pragmas, the
transaction exits, the isolation trio, the keyset walk, the user and
session adapters against the same behavioral contract the in-memory
suites pin, and the analytics windows against the vector's own rows:

#listing("csharp-net/api/tests/CsharpBook.Api.Tests/Support/TempStore.cs", first: 9, last: 20, caption: [the whole test story: a temp dir, a store at a file inside it, per test]) // PIN: test lifecycle

#diagram([a store test's lifecycle, nothing shared between runs], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.0, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.5, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.5, 5.0), [#l1], size: 6pt)
  }
  step(0.3, [temp dir], [fresh directory])
  cdraw.line((5.5, 5.5), (5.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(5.9, [open + migrate], [wal, pragmas, three versions])
  cdraw.line((11.1, 5.5), (11.5, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(11.5, [seed, act, assert], [bound sql, golden bytes])
  cdraw.line((16.7, 5.5), (17.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(17.1, [dispose], [handles die, dir deletes])
  cdraw.content((9.4, 3.5), [no container, no port, no sleep], size: 6pt)
  cdraw.content((9.4, 2.4), [46 tests, nine files, zero flake surface], size: 6pt)
  cdraw.content((9.4, 1.3), [the vector bytes found by walking up to contract/testdata], size: 6pt)
})

sources: learn.microsoft.com for the sqlite pages under dotnet/standard/data/sqlite,
async, transactions, database errors, and connection strings, and the
api pages for SqliteCommand.ExecuteReaderAsync, SqliteConnection.BeginTransaction,
and SqliteTransaction.Dispose, all accessed 2026-09-26, the
BeginTransaction default of BEGIN IMMEDIATE read from the
SqliteTransaction source in the dotnet runtime repository at the same
date, and the wal and locking model from sqlite.org's write-ahead
logging and result code pages. Verified by
`dotnet test Api.slnx` over the store suite, 46 tests across
MigrationsTests, StoreDbTests, TransactionTests, IsolationTests,
KeysetTests, SqliteUserStoreTests, SqliteSessionStoreTests,
AnalyticsTests, and the reports pair's ReportsEndpointTests, with the engine version 3.53.4 confirmed by
`SELECT sqlite_version()` over the pinned bundle.
