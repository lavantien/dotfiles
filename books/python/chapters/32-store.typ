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

The service has run on in-memory dicts, which tests love and restarts
hate. This lane's answer is its named infrastructure: the sqlite3
module as the pinned interpreter bundles it, the engine reporting
version 3.50.4 on this machine's cpython 3.14.7, a real delta beside
the corpus 3.53.4 pin for the c-built engines and the 3.53.1 node
bundles, and the platform test freezes the measured number so an
interpreter change is a red test before it is a surprise here. No
object relational mapper sits in the graph. SQLAlchemy is dated meta
in the suite chapter and nothing here needs it, because the whole job
is schema migrations that append and never edit, parameterized
queries over one connection per operation, the transaction idiom in
its with-block form over explicit begin statements, the isolation a
wal-mode sqlite actually gives, the version guard that makes lost
updates visible, keyset pagination as one row-value comparison, and
the window-function report the go book's engine era walked in loops
instead.

== db-api, the bundled engine, and the connection budget

DB-API 2.0 is a protocol, not a database. A program opens a connection
by path, asks it for cursors, binds values as parameters, and reads
rows back, and any module that implements the shape can sit
underneath. sqlite3 is that module in the standard library, and the
engine arrives inside the interpreter build, no driver to install and
no third party to trust. Version 3.14 removed the module's old
`version` and `version_info` constants, so `sqlite3.sqlite_version`
is the one true answer about the engine, the string the platform test
pins.

Three platform facts shape every line of this store. First, the
legacy default opens transactions implicitly: with the default
`autocommit=LEGACY_TRANSACTION_CONTROL` and a non-None
`isolation_level`, a transaction is implicitly opened before any
insert, update, delete, or replace, and commit is the caller's job to
remember. The vehicle refuses the folklore and passes
`isolation_level=None`, which leaves transaction control to explicit
begin statements, so every boundary in this chapter is a line of code.
The docs recommend `autocommit=False` for PEP 249 behavior and note
the legacy default will change in a future release, so code that
relies on implicit begins is waiting for its interpreter to break it.
Second, `timeout=5.0` is the busy budget, five seconds the connection
spends retrying a locked table before raising, which is why no retry
loop appears anywhere in this store: the platform already wrote it.
Third, a connection is not thread-safe by default and the module
enforces it the hard way, `check_same_thread=True` raises
ProgrammingError the moment a connection is used from the thread that
did not create it, so the store borrows one fresh connection per
operation and opening is cheap.

#listing("python/api/pyapi/store/db.py", first: 131, last: 146, caption: [the connect hub: pragmas armed, row factory set, transactions left to explicit begins]) // PIN: connect hub

The with-block is the trap that bites every beginner. Used as a
context manager, a connection commits on success and rolls back on
exception, and closes nothing: the docs say it plainly, the context
manager neither implicitly opens a new transaction nor closes the
connection, and point at `contextlib.closing()` for the closing scope.
A test that leaves a connection open keeps the file handle alive, and
on Windows the temp directory holding it fails to delete. The first
drafts of this suite hit exactly that, three tests red on
PermissionError until every helper wrapped its connections in closing.

The module ships no pool, unlike the ado.net provider the c\# lane had
to switch off. What pooling would be is a dozen lines over
`queue.Queue`: build a fixed set once, hand one out under a context
manager, take it back at the end, and replace a connection that broke
mid-use instead of returning it to the next borrower. The pool's
connections are built with `check_same_thread=False` because
borrowing crosses threads by design, the docs' price for that is that
write operations may need to be serialized by the user, and the
answer is begin immediate plus the busy budget, the same two
mechanisms every other writer here already passes through.

#diagram([the stack the store sits on, one borrowed connection at a time], length: 13pt, {
  let stage(y, t, l1, fill) = {
    cdraw.rect((0.9, y), (13.5, y + 1.5), fill: fill, radius: 0.02)
    cdraw.content((7.2, y + 1.0), [#t], size: 6pt)
    cdraw.content((7.2, y + 0.3), [#l1], size: 6pt)
  }
  stage(6.6, [handlers and stores], [#"UserStore, SessionStore over rows"], luma(235))
  cdraw.line((7.2, 6.5), (7.2, 5.9), stroke: luma(100), mark: (end: ">>"))
  stage(4.3, [db-api 2.0 + sqlite3], [parameters only, one conn per op], luma(225))
  cdraw.line((7.2, 4.2), (7.2, 3.6), stroke: luma(100), mark: (end: ">>"))
  stage(2.0, [the bundled engine], [#"3.50.4, measured and pinned"], luma(235))
  cdraw.line((7.2, 1.9), (7.2, 1.3), stroke: luma(100), mark: (end: ">>"))
  stage(-0.3, [the database file], [wal journal, snapshot readers], luma(245))
  pane(14.4, 22.6, 6.6, [no orm], [SQLAlchemy is dated meta,], [never imported])
})

== migrations test driven

Schema changes are code changes, so they ship as records, and the
history is append-only by contract: a shipped version is frozen, a
correction is a new numbered version, and no record is ever edited.
The registry is the user_version pragma, an integer sqlite keeps in
the database header itself, so no table the database keeps about
itself can drift from the schema it describes.

This wave ships four versions. Version 1 is the whole vocabulary in
one record, users with their email uniqueness index, roles with the
check constraint, sessions with their refresh token history, events as
one presence row per user per day, reports with their idempotency
claim. Version 2 adds the user version column, the substrate the
optimistic concurrency sections stand on, and the keyset index beside
it. Version 3 adds the idempotency keys table the concurrency chapter
fills. Version 4 conforms the session vocabulary to the port the
authn chapter froze, the expiry column in, the creation stamp the
port never carried out, the token hash a blob, and it is its own
record because a new fact is a new record even mid wave. Each applies
inside one explicit transaction with the version
bump in the same group, so a version that fails halfway leaves nothing
durable and can simply be retried. The test drives the runner from an
empty directory, proves all four records applied in order, re-runs
and proves nothing applies twice, reopens the database and proves the
registry came back with it, then reads sqlite_master and asserts every
table and index the contract's vocabulary names.

#listing("python/api/pyapi/store/db.py", first: 162, last: 179, caption: [one version, one transaction, the ddl and the header bump land together, applied at most once]) // PIN: migrate loop

#diagram([the version list only grows right], length: 13pt, {
  cdraw.line((0.6, 4.4), (22.0, 4.4), stroke: luma(140))
  cdraw.content((11.3, 5.4), [open time], size: 6.5pt)
  let tick(x, label, l1) = {
    cdraw.line((x, 4.7), (x, 4.1), stroke: luma(100))
    cdraw.rect((x - 2.6, 1.6), (x + 2.6, 4.0), fill: luma(235), radius: 0.02)
    cdraw.content((x, 3.3), [#label], size: 6pt)
    cdraw.content((x, 2.2), [#l1], size: 6pt)
  }
  tick(3.5, [version 1], [the base vocabulary])
  tick(8.7, [version 2], [user version column])
  tick(13.9, [version 3], [idempotency keys])
  tick(19.1, [version 4], [the session parity])
  cdraw.content((11.3, 0.7), [user_version in the header, one integer, append-only history], size: 6pt)
})

== queries with parameters every time

Values ride parameters, never string concatenation, and the module
enforces the shape in this release: using a sequence of parameters
with named placeholders now raises ProgrammingError, deprecated since
3.12, so the two binding styles cannot be mixed by accident anymore.
Every statement in the store uses positional `?` marks with a tuple,
and the one f-string that appears builds a column list from a module
constant, never a value. The read path pins one snapshot per group:
`read_tx` begins deferred, the wal snapshot is pinned at the group's
first statement and kept for its whole life, so a user and its roles
are read as one state, never a torn view of an insert in flight.

The keyset walk is one row-value comparison. The index covers
`(created_at_ms, id)`, the cursor decodes to that pair, and the where
clause compares both columns in one tuple expression, `(created_at_ms,
id) > (?, ?)`, which sqlite has served as one seek into the index
since 3.15. An offset scan would pay for every skipped row on every
page, the classic pagination trap, and the cursor never asks for
position, only for direction:

#listing("python/api/pyapi/store/users.py", first: 110, last: 125, caption: [the keyset walk: one row-value comparison against the cursor key, ascending, bounded]) // PIN: keyset walk

#diagram([one read's path from caller to dict rows], length: 13pt, {
  let step(x0, t, l1) = {
    cdraw.rect((x0, 4.3), (x0 + 5.0, 6.5), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.5, 5.9), [#t], size: 6pt)
    cdraw.content((x0 + 2.5, 4.9), [#l1], size: 6pt)
  }
  step(0.3, [caller], [limit, cursor pair])
  cdraw.line((5.5, 5.4), (5.9, 5.4), stroke: luma(100), mark: (end: ">>"))
  step(5.9, [deferred read tx], [snapshot pinned at first read])
  cdraw.line((11.1, 5.4), (11.5, 5.4), stroke: luma(100), mark: (end: ">>"))
  step(11.5, [bound statement], [#"(created_at_ms, id) > (?, ?)"])
  cdraw.line((16.7, 5.4), (17.1, 5.4), stroke: luma(100), mark: (end: ">>"))
  step(17.1, [dict rows], [contract field names, roles beside])
  cdraw.content((8.7, 3.4), [one seek into the keyset index, no offset ever paid], size: 6pt)
  cdraw.content((8.7, 2.3), [a duplicate email is refused by the unique index itself], size: 6pt)
})

== the transaction idiom

One shape covers every write in the service: begin immediate, run the
body, and let the platform's with-block be the deferred rollback.
`BEGIN IMMEDIATE` takes the writer lock up front rather than at the
first write, so the busy budget is spent where the caller chose to
write. The body stages whatever it likes. Landing inside `with conn:`
commits the group on success, rolls it back on any exception
unwinding through, and after a commit the same exit is a no-op because
there is nothing left to undo. There is no finally dance and no
manual rollback call on the error path, the dispose lesson of the c\#
lane restated as a with-block. The tests pin all three exits: a
committed group lands, a body that inserts and then raises leaves
nothing, and a group whose second statement violates the email index
rolls back its first statement too, because groups are atomic or they
are nothing. The session adapter carries the hardest case: presenting
a superseded refresh token revokes the whole family inside the same
write transaction and the SessionRevokedError answer is raised after the
commit, so the family cannot be rolled back to life.

#listing("python/api/pyapi/store/db.py", first: 183, last: 192, caption: [the write shape: begin immediate, body, and the with-block is the deferred rollback]) // PIN: with-tx shape

#diagram([a transaction's exits, every one of them clean], length: 13pt, {
  cdraw.rect((0.4, 5.4), (6.2, 7.2), fill: luma(235), radius: 0.02)
  cdraw.content((3.3, 6.6), [write tx, begin immediate], size: 6pt)
  cdraw.content((3.3, 5.8), [the body stages its writes], size: 6pt)
  cdraw.line((3.3, 5.3), (3.3, 4.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((0.4, 3.0), (6.2, 4.5), fill: luma(235), radius: 0.02)
  cdraw.content((3.3, 4.0), [run the body], size: 6pt)
  cdraw.content((3.3, 3.3), [inserts, updates, checks], size: 6pt)
  pane(8.6, 14.6, 4.5, [body completes], [the with-block commits], [after commit, a no-op])
  cdraw.line((6.4, 3.7), (8.4, 3.7), stroke: luma(100), mark: (end: ">>"))
  pane(15.8, 21.8, 4.5, [any other exit], [the with-block rolls back], [raise, failed statement])
  cdraw.content((3.3, 1.9), [no finally dance, the platform wrote the rollback], size: 6pt)
  cdraw.content((3.3, 0.8), [a revoked family cannot be rolled back to life], size: 6pt)
})

== isolation levels and what sqlite actually gives you

The textbook menu, read uncommitted through serializable, is a menu of
guarantees a general engine picks among, and the sqlite menu is
short: everything is serializable by default, and read uncommitted
only exists over a shared cache, exactly the dirty-read mode nobody
wants beside a wal. There is no configuration file standing between
the claim and the mechanism here, the mechanism is wal plus one
writer. What that buys is snapshot isolation. A deferred transaction
pins the snapshot its first statement reads and keeps it for its whole
life. No dirty reads, because readers only ever see committed states.
No non-repeatable reads inside one transaction, because the snapshot
never moves. One writer at a time, because begin immediate takes the
write lock before the first write. Write skew stays possible, two
writers can act on disjoint stale snapshots and each commit cleanly,
and that boundary is a fact about the locks, stated where the code
states it.

The demo stays deterministic and single threaded, which is the whole
trick. The reader's connection begins deferred and reads, capturing
its view. A second connection commits past the pinned snapshot, and
wal is what lets it, the reader holds no lock the writer needs. The
reader reads again inside its transaction and still sees the old
value, and a fresh read outside sees the new one. No thread, no
barrier, no sleep, the interleave is the test's own statement order:

#listing("python/api/tests/test_store_isolation.py", first: 43, last: 64, caption: [pin a view, commit past it, read again: the interleave is the statement order]) // PIN: snapshot pin demo

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

== the lost update demo and the cas answer

Two writers read the same user, both compute, both write, and one
update silently vanishes. The store reproduces it with two blind
writes, update with no version guard: both report one row changed,
both succeed, the second name is all that survives, and the version
column never moved, so nothing anywhere records that anything was
lost. Serialization does not fix this, and owning the transaction
shape makes the reason visible: begin immediate guarantees each write
lands whole and says nothing about the stale read the write was
computed from, so the serialized blind writers merely lose the update
in a tidy order.

The version column is the detector and the guarded update is the fix,
the strong discipline in SQL form. The check, the bump, and the write
share one statement inside one write transaction, so no second writer
can slip between the read and the write. Zero rows changed is the
refusal, and the classifier decides which refusal it is, missing or
stale, against the known id. Of two racers holding version 1 exactly
one changes a row, and the loser gets the VersionError it must
handle, which over http is exactly the 412 the next chapter's duel
stages with two released patchers:

#listing("python/api/pyapi/store/users.py", first: 141, last: 156, caption: [the guarded update: check, bump, and write in one statement, zero rows is the refusal]) // PIN: cas update

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
key is the pair (day, user_id) and the insert rides on conflict do
nothing, so a duplicate event is absorbed at write time. From there
the windows do the work. Row number partitioned by user in day order
marks each user's first day in the window as rn = 1, which is the
newcomer split. Lag carries yesterday's count forward with today's as
its default, so the first day's delta is zero by construction, the
same arithmetic without the self-join. Leaders rank by count
descending then user id ascending, a total order, so a replayed
report cannot differ run to run. Days are iso text and text
comparison is chronological for iso dates, so the window bounds are
two string parameters, and one report reads inside one deferred
transaction, so it always sees one snapshot of the events. Over the
frozen vector's seeded events, (2026-09-25, ada), (2026-09-26, ada),
(2026-09-26, grace), the series is exactly the golden rows, 1 then 2,
asserted against the vector file itself:

#listing("python/api/pyapi/store/analytics.py", first: 19, last: 39, caption: [the report query: presence, row number for the newcomer split, lag for the delta]) // PIN: daily active sql

#diagram([events rows to windows to the report body], length: 13pt, {
  let step(x0, w, t, l1) = {
    cdraw.rect((x0, 3.9), (x0 + w, 6.4), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + w / 2, 5.7), [#t], size: 6pt)
    cdraw.content((x0 + w / 2, 4.7), [#l1], size: 6pt)
  }
  step(0.3, 4.4, [events rows], [one presence per user per day])
  cdraw.line((4.9, 5.1), (5.3, 5.1), stroke: luma(100), mark: (end: ">>"))
  step(5.3, 4.8, [row_number], [rn = 1 is the first day])
  cdraw.line((10.3, 5.1), (10.7, 5.1), stroke: luma(100), mark: (end: ">>"))
  step(10.7, 5.2, [group and lag], [actives, newcomers, delta])
  cdraw.line((16.1, 5.1), (16.5, 5.1), stroke: luma(100), mark: (end: ">>"))
  step(16.5, 5.8, [report body], [day and active on the wire])
  cdraw.content((9.0, 2.7), [all inside one deferred transaction, one snapshot], size: 6pt)
  cdraw.content((9.0, 1.6), [leaders: count desc then user id asc, replay stable], size: 6pt)
})

== store tests without docker

Every test in the family starts the same way: a fresh temp directory,
a store at a file inside it, migrated once in the fixture's
constructor, act, close. No container, no port, no shared server, no
ordering between tests, and the directory deletes clean because every
connection is closed, the lesson the with-block section states and the
first drafts of this very suite relearned. Nothing in the family
sleeps: the snapshot interleave is statement order, the
guarded-update duel needs no barrier at the store layer because begin
immediate serializes the racers itself, and the keyset property walks
seeded random users through the sql and a python-sorted twin and
asserts the same pages, the two implementations that must agree. The
fixtures seed through the schema itself, straight sql with bound
parameters, and the foreign keys bite the fixture that forgets its
user row, which is the constraint doing its job. Fifty-two store
tests across six files cover the migrations and the registry, the
pragmas, the pool, the transaction exits, the isolation pair, the
blind-write demo beside the guard, the user vocabulary with the cursor
codec and the keyset walk, the session family, the analytics windows
against the vector's own rows, and the idempotency backend's round
trip and lazy expiry:

#listing("python/api/tests/test_store_db.py", first: 27, last: 35, caption: [the whole test story: a temp dir, a store at a file inside it, migrated once, per test]) // PIN: test lifecycle

#diagram([a store test's lifecycle, nothing shared between runs], length: 13pt, {
  let step(x0, t, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.0, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.5, 6.0), [#t], size: 6pt)
    cdraw.content((x0 + 2.5, 5.0), [#l1], size: 6pt)
  }
  step(0.3, [temp dir], [fresh directory])
  cdraw.line((5.5, 5.5), (5.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(5.9, [open + migrate], [wal, pragmas, four versions])
  cdraw.line((11.1, 5.5), (11.5, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(11.5, [seed, act, assert], [bound sql, golden bytes])
  cdraw.line((16.7, 5.5), (17.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(17.1, [close], [handles die, dir deletes])
  cdraw.content((9.4, 3.5), [no container, no port, no sleep], size: 6pt)
  cdraw.content((9.4, 2.4), [52 tests, six files, zero flake surface], size: 6pt)
})

sources: docs.python.org for the sqlite3 module page, accessed
2026-09-27, the connect signature and defaults (timeout 5.0,
isolation_level deferred by default, check_same_thread true,
autocommit at LEGACY_TRANSACTION_CONTROL with the promised future
change to False), the connection context manager section quoting that
it "neither implicitly opens a new transaction nor closes the
connection" and pointing at contextlib.closing, the legacy implicit
begin before insert, update, delete, and replace, the autocommit
attribute added in 3.12 with False recommended, sqlite3.Row as the
recommended row factory, the threadsafety levels, and the user_version
pragma example, the 3.14 what's new page for the removal of
sqlite3.version and version_info and the ProgrammingError on sequences
with named placeholders, and sqlite.org for the write-ahead logging
page, all at the same date. Verified by the store family's 52 tests
across the six files named above under the pyapi gate, with the
engine string 3.50.4 read from `SELECT sqlite_version()` on the pinned
interpreter and frozen by tests/test_platform.py before this chapter
was written.
