#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= store

The service has run on fixed tables in memory, which tests love and
restarts hate, and the fix is the capstone's own engine: sqlite
3.53.4, loaded at runtime from the dll beside the exe, driven
through its c api with nothing between, no driver, no orm, no query
builder. Above that seat: a pool, migrations that append, statements
bound every time, the transaction shape in plain c, wal isolation,
the version guard, keyset pagination as one row comparison, and the
window-function report.

== the dll, the c api, and the pool

The load is the row cruncher's idiom restated where the service
lives. `LoadLibraryA("sqlite3.dll")` finds the dll beside the exe,
every entry point is a typedefed pointer resolved with one direct
cast, 19 of them in one extern table, and the version string is
compared against 3.53.4 before the table is published, so a stale
dll fails the first call loudly. The pool is built from the
platform's parts: a fixed set of handles, a stack of free slots, one
slim reader-writer lock, one condition variable. Acquire sleeps
while the stack is empty, release pushes and wakes, and every sleeper
re-checks the predicate inside the loop, the lost-wake lesson
carried as the shape itself. Each handle is armed at open with
`journal_mode=WAL`, `foreign_keys=ON`, and the 5000 ms busy budget,
and close refuses while a slot is out.

#listing("c-os-cloud/api/src/store_pool.c", first: 56, last: 75, caption: [the handout: sleep while empty, wake on release, re-check the predicate every time]) // PIN: pool acquire/release

#diagram([the stack the store sits on], length: 13pt, {
  let stage(y, title, l1, fill) = {
    cdraw.rect((0.9, y), (13.5, y + 1.5), fill: fill, radius: 0.02)
    cdraw.content((7.2, y + 1.0), [#title], size: 6pt)
    cdraw.content((7.2, y + 0.3), [#l1], size: 6pt)
  }
  stage(6.6, [handlers and adapters], [#"rows, roles, reports over the pool"], luma(235))
  cdraw.line((7.2, 6.5), (7.2, 5.9), stroke: luma(100), mark: (end: ">>"))
  stage(4.3, [the pool], [#"fixed handles, one lock, one cv"], luma(225))
  cdraw.line((7.2, 4.2), (7.2, 3.6), stroke: luma(100), mark: (end: ">>"))
  stage(2.0, [the pointer table], [#"19 typedefed casts, version pinned"], luma(235))
  cdraw.line((7.2, 1.9), (7.2, 1.3), stroke: luma(100), mark: (end: ">>"))
  stage(-0.3, [sqlite3.dll and the file], [#"wal journal, snapshot readers"], luma(245))
})

== migrations test driven

Schema changes are code changes, so they ship as records, append-only
by contract: a shipped version is frozen, a correction is a new
numbered version, no record is ever edited. The registry is the
`user_version` pragma, one integer the engine keeps in the database
header, so nothing the database keeps about itself can drift from
the schema it describes. This wave ships three versions, the whole
vocabulary, then the user version column with the keyset index, then
the idempotency keys the next chapter fills. Each applies inside its
own begin immediate group with the bump in the same group, so a
failed record leaves nothing durable and can simply be retried. The
test re-runs the runner, asks `sqlite_master` for exactly the 7
frozen names, and reopens to prove the registry came back.

#listing("c-os-cloud/api/src/store_schema.c", first: 80, last: 100, caption: [one version, one transaction, the ddl and the header bump land together, applied at most once]) // PIN: migrate loop

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
  tick(11.3, [version 2], [version column, keyset index])
  tick(18.6, [version 3], [idempotency keys])
  cdraw.content((11.3, 0.7), [user_version in the header, append-only history], size: 6pt)
})

== prepared statements, bound every time

Parsing sql is work, and a path that re-parses the same statement per
call pays it every time. The adapter prepares each statement once per
pool slot, on first use, and every call binds every parameter again,
steps, and finishes with reset and clear bindings, the pair that
leaves the object as prepare left it, so a stale parameter can never
survive into the next request. The parameter count is a testable
fact, six binds for the insert. The transient
sentinel carries the capstone's hard lesson: it tells the engine to
copy the bound bytes before the call returns, which is what makes a
caller's stack buffer safe to reuse. Values ride `?1` parameters,
never string building, so an email is data to the engine, never sql.

#listing("c-os-cloud/api/src/store_user.c", first: 37, last: 45, caption: [prepare once per slot, bind through one helper that always passes the transient sentinel]) // PIN: ensure_stmt + bind_str

#diagram([one statement's life, per slot], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.3), (x0 + 4.6, 6.5), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.3, 5.9), [#title], size: 6pt)
    cdraw.content((x0 + 2.3, 4.9), [#l1], size: 6pt)
  }
  step(0.3, [prepare], [first use on a slot])
  cdraw.line((5.1, 5.4), (5.5, 5.4), stroke: luma(100), mark: (end: ">>"))
  step(5.5, [bind, every time], [#"?1 text, transient"])
  cdraw.line((10.3, 5.4), (10.7, 5.4), stroke: luma(100), mark: (end: ">>"))
  step(10.7, [step], [row, done, or error])
  cdraw.line((15.5, 5.4), (15.9, 5.4), stroke: luma(100), mark: (end: ">>"))
  step(15.9, [reset, clear], [as prepare left it])
})

== the transaction idiom

One shape covers every multi-statement write: begin immediate, run
the group, commit, and let every other exit roll back. C has no defer
and no using block, so the shape is stated in full: the begin takes
the write lock up front, the busy budget is spent where the caller
chose to write, and each error exit calls rollback beside the check
that failed, never in a distant cleanup path, which is the deferred
rollback of the go and c sharp idioms restated as control flow
readable top to bottom. The suite pins the exits directly: a
committed group lands whole, and a group whose second statement
violates the email index rolls back its first too.

#listing("c-os-cloud/api/src/store_report.c", first: 70, last: 94, caption: [the write shape in plain c: begin immediate, run, commit, rollback on every other exit]) // PIN: tx group

#diagram([a transaction's exits, every one of them clean], length: 13pt, {
  cdraw.rect((0.4, 5.4), (6.2, 7.2), fill: luma(235), radius: 0.02)
  cdraw.content((3.3, 6.6), [begin immediate], size: 6pt)
  cdraw.content((3.3, 5.8), [the write lock, up front], size: 6pt)
  cdraw.line((3.3, 5.3), (3.3, 4.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((0.4, 3.0), (6.2, 4.5), fill: luma(235), radius: 0.02)
  cdraw.content((3.3, 4.0), [run the group], size: 6pt)
  cdraw.content((3.3, 3.3), [inserts, bumps, checks], size: 6pt)
  pane(8.6, 14.6, 4.5, [every step ok], [commit lands the group], [nothing left to undo])
  cdraw.line((6.4, 3.7), (8.4, 3.7), stroke: luma(100), mark: (end: ">>"))
  pane(15.8, 21.8, 4.5, [any step fails], [rollback, right there], [the file never saw it])
})

== what wal actually gives you

The textbook menu, read uncommitted through serializable, is a menu
of guarantees a general engine picks among, and what this engine
serves with the wal pragma armed is specific: readers hold snapshots,
one writer appends to the log at a time, and the two never block each
other. The pragma is persistent in the file, so issuing it per open
is idempotent. What that buys is snapshot isolation: no dirty reads,
because readers only see committed states, no non-repeatable reads
inside one transaction, because the view never moves, one writer at a
time, because begin immediate takes the lock first. Write skew stays
possible, and that boundary is a fact about the locks. The demo is
deterministic and single threaded, and wal is what makes it legal:
the reader pins a view, a second handle commits past it, and the
reader still reads the old count inside its transaction. No thread,
no sleep, the interleave is the statement order:

#listing("c-os-cloud/api/tests/test_store.c", first: 260, last: 276, caption: [pin a view, commit past it, read again: the interleave is the statement order]) // PIN: snapshot pin demo

#diagram([one timeline: the reader's view holds], length: 13pt, {
  cdraw.line((0.6, 1.0), (22.4, 1.0), stroke: luma(140))
  cdraw.content((11.5, 6.9), [reader, deferred tx], size: 6.5pt)
  cdraw.line((2.0, 6.3), (6.4, 6.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((4.2, 5.6), [first read pins the view], size: 6pt)
  cdraw.line((6.4, 6.3), (16.2, 6.3), stroke: luma(80))
  cdraw.content((11.3, 5.6), [view pinned at one user], size: 6pt)
  cdraw.line((16.2, 6.3), (21.4, 6.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((18.8, 5.6), [second read: still one], size: 6pt)
  cdraw.content((11.5, 3.9), [writer, second handle], size: 6.5pt)
  cdraw.line((9.6, 3.3), (14.6, 3.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((12.1, 2.6), [commits the second user], size: 6pt)
  cdraw.line((14.6, 3.3), (14.6, 1.2), stroke: luma(120), mark: (end: ">>"))
  cdraw.content((12.1, 1.4), [a fresh read outside sees two], size: 6pt)
  pane(16.9, 22.4, 3.3, [what it is], [snapshot isolation,], [not serializability])
})

== the lost update and the cas answer

Two writers read the same user, both compute, both write, and one
update silently vanishes. The store reproduces it with two blind
updates: both succeed, the second name survives, and the version
column never moved, so nothing anywhere records that anything was
lost. Serialization does not fix this, because begin immediate
guarantees each write lands whole and says nothing about the stale
read the write was computed from. The version column is the detector
and the guarded update is the fix: the check, the bump, and the
write share one statement, so exactly one of two racers holding the
same version affects a row. Zero changes is the refusal, and the
adapter probes once: a missing row and a stale version are different
facts, 404 against 412. Over http this is the precondition the next
chapter's etag duel stages, one 200 and one 412, every run:

#listing("c-os-cloud/api/src/store_user.c", first: 156, last: 178, caption: [the guard: check, bump, and write in one statement, zero changes is the refusal]) // PIN: cas update

#diagram([same race, two outcomes: silent loss versus a refused writer], length: 13pt, {
  pane(0.3, 10.6, 7.4, [before, blind writes], [both read name, version 1], [both write, both succeed], [one write vanished])
  cdraw.line((10.8, 5.5), (11.6, 5.5), stroke: luma(100), mark: (end: ">>"))
  pane(11.8, 22.3, 7.4, [after, the guard], [both read version 1], [one commits version 2], [loser: zero changes, a 412])
  cdraw.content((11.3, 0.9), [begin immediate holds the window shut, the where clause is the fix], size: 6pt)
})

== keyset pagination as one row comparison

The list route walks users in creation order, and the cursor the
contract froze is the position pair itself, created_at in unix
milliseconds with the id as the tiebreaker. Offsets count rows
forward on every page and skip or repeat under writes that land
between pages. The keyset walk asks one question per page, which rows
sort strictly after this position, and in sql that is one row-value
comparison, `(created_ms, id) > (?1, ?2)`, matched by the version 2
index in the same order, so the engine never sorts. The first page
needs no special statement: the walk's floor is the smallest time
with an empty id, so one comparison serves the first page and every
continuation with different binds. The limit binds one higher than
asked, and the extra row is the has-more fact. The users family's
cursor codec renders the pair as the base64url shape the contract
froze, and the suite asserts those bytes against vector 13's own
field and walks page two onto linus with no cursor left:

#listing("c-os-cloud/api/src/store_user.c", first: 180, last: 196, caption: [the walk: one row-value comparison, the first page binds the floor, the extra row is has more]) // PIN: keyset walk

#diagram([one comparison per page, the index already in walk order], length: 13pt, {
  let step(x0, w, title, l1) = {
    cdraw.rect((x0, 4.1), (x0 + w, 6.4), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + w / 2, 5.7), [#title], size: 6pt)
    cdraw.content((x0 + w / 2, 4.7), [#l1], size: 6pt)
  }
  step(0.3, 4.6, [the position pair], [#"t, id from the cursor"])
  cdraw.line((5.1, 5.2), (5.5, 5.2), stroke: luma(100), mark: (end: ">>"))
  step(5.5, 5.6, [(t, id) > (?1, ?2)], [one row-value comparison])
  cdraw.line((11.3, 5.2), (11.7, 5.2), stroke: luma(100), mark: (end: ">>"))
  step(11.7, 4.6, [the index walk], [#"users_keyset, no sort"])
  cdraw.line((16.5, 5.2), (16.9, 5.2), stroke: luma(100), mark: (end: ">>"))
  step(16.9, 5.6, [limit + 1 rows], [the extra row is has more])
})

== the analytics report in window functions

Reports are sql's home turf, and this lane keeps them there. Presence
collapses events to one row per user per day before any counting,
because actives count users, not actions, and the events primary key
is the pair itself, so a duplicate event is absorbed at write time.
The windows do the work: `ROW_NUMBER` partitioned by user in day
order marks each user's first day, the newcomer split. `LAG` carries
yesterday's count forward with today's as its default, so the first
day's delta is zero by construction. `RANK` orders the leaders by
days descending then user id ascending, a total order, so a replayed
report cannot differ run to run. The report row lands pending, and
its first read computes the series and flips the row done in one
group, so a replay answers the stored series. The suite seeds the
three events vector 16 names and asserts the frozen numbers: one
active on the 25th, two on the 26th, one newcomer each day, deltas
zero and one, leaders ada then grace.

#listing("c-os-cloud/api/src/store_report.c", first: 21, last: 34, caption: [the window query: presence, row_number for the newcomer split, lag with today as the default]) // PIN: series sql

#diagram([events rows to windows to the report body], length: 13pt, {
  let step(x0, w, title, l1) = {
    cdraw.rect((x0, 3.9), (x0 + w, 6.4), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + w / 2, 5.7), [#title], size: 6pt)
    cdraw.content((x0 + w / 2, 4.7), [#l1], size: 6pt)
  }
  step(0.3, 4.4, [events rows], [one presence per user per day])
  cdraw.line((4.9, 5.1), (5.3, 5.1), stroke: luma(100), mark: (end: ">>"))
  step(5.3, 4.8, [row_number], [first day is the newcomer])
  cdraw.line((10.3, 5.1), (10.7, 5.1), stroke: luma(100), mark: (end: ">>"))
  step(10.7, 5.2, [group and lag], [actives, newcomers, delta])
  cdraw.line((16.1, 5.1), (16.5, 5.1), stroke: luma(100), mark: (end: ">>"))
  step(16.5, 5.8, [the series], [day, active, new, delta])
})

== store tests without docker

Every test in the family starts the same way: a fresh database file
in a temp directory, named by tag, process, and a per-file counter so
two test files in one process never collide, opened as a pool,
migrated, acted on, closed, and removed with its wal and shm sidecars
once the handles die. No container, no port, no shared server, and
nothing sleeps: the pool's blocking acquire is closed by a handoff
the test releases on purpose, the snapshot interleave is statement
order, and the clock never enters the store, because ids, times, and
hashes arrive as values from the callers that own them. The suite is
89 checks in two files, and the lane reruns it under the address
sanitizer.

#listing("c-os-cloud/api/tests/tstore.h", first: 26, last: 42, caption: [the whole test story: a tagged temp file per test, removed with its sidecars once the handles close]) // PIN: test lifecycle

#diagram([a store test's lifecycle, nothing shared between runs], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.0, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.5, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.5, 5.0), [#l1], size: 6pt)
  }
  step(0.3, [temp file], [tag, process, counter])
  cdraw.line((5.5, 5.5), (5.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(5.9, [pool + migrate], [wal armed, 3 versions])
  cdraw.line((11.1, 5.5), (11.5, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(11.5, [seed, act, assert], [frozen ids, vector bytes])
  cdraw.line((16.7, 5.5), (17.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(17.1, [close, remove], [db, wal, shm gone])
})

sources: sqlite.org for the c3ref pages sqlite3_prepare_v2,
sqlite3_bind_text, sqlite3_step, sqlite3_reset,
sqlite3_clear_bindings, sqlite3_changes, sqlite3_busy_timeout, and
sqlite3_close, the pragma page for user_version, journal_mode, and
foreign_keys, the wal page, and the row-values page, all accessed
2026-09-27, learn.microsoft.com for LoadLibraryA,
GetProcAddress, srw locks, and condition variables at the same date,
and the transient sentinel contract quoted from the vendored header
the capstone pins. Verified by the store family suite, 89 checks
across `tests/test_store.c` and `tests/test_store_report.c`, green
in `make verify-capi` with the asan leg, the cursor byte-identical
to vector 13 and the series numbers to vector 16.
